#!/usr/bin/env python3
"""Run executable Markdown examples for the public AICR-Bench docs."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


COMMENT_RE = re.compile(r"<!--\s*aicr-test\s*\n(?P<body>.*?)\n-->", re.DOTALL)
FENCE_RE = re.compile(r"```(?P<lang>[A-Za-z0-9_-]+)?[^\n]*\n(?P<body>.*?)\n```", re.DOTALL)

DEFAULT_DOCS = (
    "docs/modules/gds",
    "docs/modules/nccl",
    "docs/modules/dataloader",
    "docs/modules/ddp",
    "docs/modules/hpl-mxp",
)
DEFAULT_KINDS = ("local", "slurm-dry-run")
ALLOWED_KINDS = {"local", "slurm-dry-run", "slurm-apply"}
ALLOWED_SAFETY = {"help", "inspect", "dry-run", "one-node", "two-node"}
ALLOWED_EXPECT = {"exit-zero", "contains", "regex"}
FORBIDDEN_RE = re.compile(
    r"(^|\s)(rm\s+-rf|git\s+clean|git\s+reset|mkfs|dd\s+|sudo\s+|scontrol\s+|scancel\s+|squeue\s+--clear)",
    re.MULTILINE,
)
COMMANDS = {"plan", "run"}


@dataclass
class DocTest:
    id: str
    suite: str
    kind: str
    safety: str
    cwd: str
    expect: dict[str, Any]
    command: str
    source: str
    line: int


@dataclass
class TestResult:
    id: str
    source: str
    line: int
    kind: str
    safety: str
    status: str
    returncode: int | None
    command: str
    stdout_path: str | None = None
    stderr_path: str | None = None
    message: str = ""


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def load_doc_tests(path: Path) -> list[DocTest]:
    text = path.read_text(encoding="utf-8")
    tests: list[DocTest] = []
    seen_ids: set[str] = set()
    fence_spans = [match.span() for match in FENCE_RE.finditer(text)]
    for match in COMMENT_RE.finditer(text):
        if in_spans(match.start(), fence_spans):
            continue
        body = match.group("body")
        meta = parse_metadata(body, path)

        if not isinstance(meta, dict):
            raise SystemExit(f"{path}: aicr-test metadata must be a mapping")
        fence = FENCE_RE.search(text, match.end())
        if not fence:
            raise SystemExit(f"{path}: aicr-test block is not followed by a fenced command block")
        lang = (fence.group("lang") or "").lower()
        if lang not in {"bash", "sh", "shell"}:
            raise SystemExit(f"{path}: aicr-test command block must be bash/sh, found {lang or '-'}")

        test_id = required_str(meta, "id", path)
        if test_id in seen_ids:
            raise SystemExit(f"{path}: duplicate aicr-test id in file: {test_id}")
        seen_ids.add(test_id)
        source_line = text.count("\n", 0, match.start()) + 1
        test = DocTest(
            id=test_id,
            suite=required_str(meta, "suite", path),
            kind=required_str(meta, "kind", path),
            safety=required_str(meta, "safety", path),
            cwd=required_str(meta, "cwd", path),
            expect=expect_dict(meta.get("expect"), path, test_id),
            command=fence.group("body").strip(),
            source=str(path),
            line=source_line,
        )
        validate_test_shape(test)
        tests.append(test)
    return tests


def in_spans(position: int, spans: list[tuple[int, int]]) -> bool:
    return any(start <= position < end for start, end in spans)


def required_str(meta: dict[str, Any], key: str, path: Path) -> str:
    value = meta.get(key)
    if not isinstance(value, str) or not value.strip():
        raise SystemExit(f"{path}: aicr-test missing string field {key!r}")
    return value.strip()


def parse_metadata(body: str, path: Path) -> dict[str, Any]:
    """Parse the small YAML-like subset used by public aicr-test blocks."""
    meta: dict[str, Any] = {}
    current_map: str | None = None
    current_list: str | None = None
    for raw_line in body.splitlines():
        if not raw_line.strip():
            continue
        indent = len(raw_line) - len(raw_line.lstrip(" "))
        line = raw_line.strip()
        if line.startswith("#"):
            continue
        if indent == 0:
            current_map = None
            current_list = None
            if ":" not in line:
                raise SystemExit(f"{path}: invalid aicr-test metadata line: {raw_line}")
            key, value = split_meta_pair(line)
            if value == "":
                meta[key] = {}
                current_map = key
            else:
                meta[key] = unquote(value)
        elif indent == 2 and current_map:
            if ":" not in line:
                raise SystemExit(f"{path}: invalid nested aicr-test metadata line: {raw_line}")
            key, value = split_meta_pair(line)
            if value == "":
                meta[current_map][key] = []
                current_list = key
            else:
                meta[current_map][key] = unquote(value)
                current_list = None
        elif indent == 4 and current_map and current_list and line.startswith("- "):
            meta[current_map][current_list].append(unquote(line[2:].strip()))
        else:
            raise SystemExit(f"{path}: unsupported aicr-test metadata shape: {raw_line}")
    return meta


def split_meta_pair(line: str) -> tuple[str, str]:
    key, value = line.split(":", 1)
    return key.strip(), value.strip()


def unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def expect_dict(value: Any, path: Path, test_id: str) -> dict[str, Any]:
    if value is None:
        return {"mode": "exit-zero"}
    if not isinstance(value, dict):
        raise SystemExit(f"{path}: {test_id}: expect must be a mapping")
    mode = value.get("mode", "exit-zero")
    if mode not in ALLOWED_EXPECT:
        raise SystemExit(f"{path}: {test_id}: unsupported expect.mode: {mode}")
    patterns = value.get("patterns", [])
    if mode in {"contains", "regex"}:
        if not isinstance(patterns, list) or not all(isinstance(item, str) for item in patterns):
            raise SystemExit(f"{path}: {test_id}: expect.patterns must be a list of strings")
    return value


def validate_test_shape(test: DocTest) -> None:
    if test.kind not in ALLOWED_KINDS:
        raise SystemExit(f"{test.source}:{test.line}: unsupported kind: {test.kind}")
    if test.safety not in ALLOWED_SAFETY:
        raise SystemExit(f"{test.source}:{test.line}: unsupported safety: {test.safety}")
    if test.cwd != "install-root":
        raise SystemExit(f"{test.source}:{test.line}: unsupported cwd: {test.cwd}")
    if test.kind == "slurm-apply" and test.safety not in {"one-node", "two-node"}:
        raise SystemExit(f"{test.source}:{test.line}: slurm-apply must use one-node or two-node safety")


def discover_tests(root: Path, doc_paths: list[str]) -> list[DocTest]:
    tests: list[DocTest] = []
    ids: dict[str, str] = {}
    for item in doc_paths:
        path = root / item
        if not path.exists():
            raise SystemExit(f"documentation path not found: {item}")
        if path.is_dir():
            files = sorted(path.rglob("*.md"))
        else:
            files = [path]
        for file_path in files:
            for test in load_doc_tests(file_path):
                if test.id in ids:
                    raise SystemExit(f"duplicate aicr-test id {test.id!r} in {test.source} and {ids[test.id]}")
                ids[test.id] = test.source
                tests.append(test)
    return tests


def selected_tests(tests: list[DocTest], args: argparse.Namespace) -> list[DocTest]:
    suite = args.suite
    selected = [test for test in tests if suite == "all" or test.suite == suite]
    allowed_kinds = set(DEFAULT_KINDS)
    if args.apply:
        allowed_kinds.add("slurm-apply")
    selected = [test for test in selected if test.kind in allowed_kinds]
    if args.test_id:
        wanted = set(args.test_id)
        selected = [test for test in selected if test.id in wanted]
    return selected


def substitute(command: str, args: argparse.Namespace) -> str:
    values = {
        "cluster": args.cluster,
        "node": first_node(args.nodelist),
        "nodes2": first_two_nodes(args.nodelist),
        "date": args.date,
        "runtime_root": args.runtime_root,
    }
    out = command
    for key, value in values.items():
        out = out.replace("{{" + key + "}}", value or "")
    unresolved = re.findall(r"{{[^}]+}}", out)
    if unresolved:
        raise ValueError(f"unresolved placeholders: {', '.join(sorted(set(unresolved)))}")
    return out


def first_node(nodelist: str) -> str:
    return split_nodes(nodelist)[0] if split_nodes(nodelist) else ""


def first_two_nodes(nodelist: str) -> str:
    nodes = split_nodes(nodelist)
    return ",".join(nodes[:2]) if len(nodes) >= 2 else ""


def split_nodes(nodelist: str) -> list[str]:
    return [item.strip() for item in nodelist.split(",") if item.strip()]


def validate_command_safety(test: DocTest, command: str, args: argparse.Namespace) -> None:
    if FORBIDDEN_RE.search(command):
        raise ValueError("command contains a forbidden operation")
    if "APPLY=1" in command and not args.apply:
        raise ValueError("APPLY=1 command requires DOCS_APPLY=1 or --apply")
    if "--apply" in shlex.split(command) and not args.apply:
        raise ValueError("--apply command requires DOCS_APPLY=1 or --apply")
    if test.safety in {"one-node", "two-node"}:
        required = 1 if test.safety == "one-node" else 2
        if len(split_nodes(args.nodelist)) < required:
            raise ValueError(f"{test.safety} test requires NODELIST with at least {required} node(s)")
    if "make verify-gds" in command and "NODELIST=" not in command:
        raise ValueError("GDS doc tests must include NODELIST to avoid accidental fleet runs")
    if "make verify-nccl-suite" in command and "NODELIST=" not in command:
        raise ValueError("NCCL doc tests must include NODELIST to avoid accidental fleet runs")
    if "make benchmark-dataloader" in command and "NODELIST=" not in command:
        raise ValueError("DataLoader doc tests must include NODELIST to avoid accidental broad runs")
    if "make benchmark-ddp-resnet50" in command and "NODELIST=" not in command:
        raise ValueError("DDP doc tests must include NODELIST to avoid accidental broad runs")
    if "make benchmark-hpl-mxp" in command and "NODELIST=" not in command:
        raise ValueError("HPL-MxP doc tests must include NODELIST to avoid accidental broad runs")


def run_one(test: DocTest, root: Path, out_dir: Path, args: argparse.Namespace) -> TestResult:
    try:
        command = substitute(test.command, args)
        validate_command_safety(test, command, args)
    except ValueError as exc:
        return TestResult(test.id, test.source, test.line, test.kind, test.safety, "blocked", None, test.command, message=str(exc))

    test_dir = out_dir / safe_name(test.id)
    test_dir.mkdir(parents=True, exist_ok=True)
    stdout_path = test_dir / "stdout.txt"
    stderr_path = test_dir / "stderr.txt"
    env = os.environ.copy()
    if test.kind != "slurm-apply":
        env.setdefault("AICR_ALLOW_SYSTEM_PYTHON", "1")
    proc = subprocess.run(
        ["bash", "-lc", command],
        cwd=root,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    stdout_path.write_text(proc.stdout, encoding="utf-8")
    stderr_path.write_text(proc.stderr, encoding="utf-8")
    status, message = evaluate_expectation(test, proc)
    return TestResult(
        test.id,
        test.source,
        test.line,
        test.kind,
        test.safety,
        status,
        proc.returncode,
        command,
        str(stdout_path.relative_to(root)),
        str(stderr_path.relative_to(root)),
        message,
    )


def evaluate_expectation(test: DocTest, proc: subprocess.CompletedProcess[str]) -> tuple[str, str]:
    if proc.returncode != 0:
        return "failed", f"command exited {proc.returncode}"
    mode = test.expect.get("mode", "exit-zero")
    text = proc.stdout + "\n" + proc.stderr
    if mode == "exit-zero":
        return "passed", ""
    if mode == "contains":
        missing = [pattern for pattern in test.expect.get("patterns", []) if pattern not in text]
        if missing:
            return "failed", "missing expected text: " + ", ".join(missing)
        return "passed", ""
    if mode == "regex":
        missing = [pattern for pattern in test.expect.get("patterns", []) if not re.search(pattern, text, re.MULTILINE)]
        if missing:
            return "failed", "missing expected regex: " + ", ".join(missing)
        return "passed", ""
    return "failed", f"unsupported expectation mode: {mode}"


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", value).strip("-") or "test"


def write_summary(root: Path, out_dir: Path, results: list[TestResult], tests: list[DocTest], args: argparse.Namespace) -> None:
    obj = {
        "schema_version": 1,
        "created_at_utc": utc_now().isoformat().replace("+00:00", "Z"),
        "suite": args.suite,
        "apply": args.apply,
        "cluster": args.cluster,
        "nodelist": args.nodelist,
        "results": [asdict(result) for result in results],
        "discovered": [asdict(test) for test in tests],
    }
    (out_dir / "summary.json").write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# AICR Documentation Test Summary",
        "",
        f"- Created: `{obj['created_at_utc']}`",
        f"- Suite: `{args.suite}`",
        f"- Apply: `{args.apply}`",
        f"- Cluster: `{args.cluster}`",
        f"- Node list: `{args.nodelist or '-'}`",
        "",
        "| Test | Kind | Safety | Status | Return | Source |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for result in results:
        src = f"{Path(result.source).name}:{result.line}"
        lines.append(f"| `{result.id}` | `{result.kind}` | `{result.safety}` | `{result.status}` | `{result.returncode if result.returncode is not None else '-'}` | `{src}` |")
    failures = [result for result in results if result.status != "passed"]
    if failures:
        lines.extend(["", "## Findings", ""])
        for result in failures:
            lines.append(f"- `{result.id}`: {result.status}: {result.message}")
    (out_dir / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def command_plan(args: argparse.Namespace) -> int:
    root = repo_root()
    tests = discover_tests(root, args.docs)
    chosen = selected_tests(tests, args)
    for test in chosen:
        print(f"{test.id}\t{test.kind}\t{test.safety}\t{test.source}:{test.line}")
    print(f"Discovered {len(tests)} tests; selected {len(chosen)}.")
    return 0


def command_run(args: argparse.Namespace) -> int:
    root = repo_root()
    tests = discover_tests(root, args.docs)
    chosen = selected_tests(tests, args)
    if not chosen:
        print("No documentation tests selected.")
        return 0
    run_id = utc_now().strftime("%H%M%SZ")
    date = utc_now().strftime("%Y-%m-%d")
    out_dir = root / "results" / "doc-tests" / date / run_id
    out_dir.mkdir(parents=True, exist_ok=True)
    results = [run_one(test, root, out_dir, args) for test in chosen]
    write_summary(root, out_dir, results, chosen, args)
    summary_rel = out_dir.relative_to(root)
    passed = sum(1 for result in results if result.status == "passed")
    print(f"Documentation tests: {passed}/{len(results)} passed")
    print(f"Summary: {summary_rel}/summary.md")
    return 0 if passed == len(results) else 1


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Run executable AICR-Bench Markdown examples.",
        usage="aicr-doctest.py [options] {plan,run}",
    )
    p.add_argument("--suite", default="gds", help="Suite to run, or 'all'. Default: gds.")
    p.add_argument("--docs", nargs="*", default=list(DEFAULT_DOCS), help="Markdown files or directories to scan.")
    p.add_argument("--cluster", default=os.environ.get("CLUSTER", "b200"))
    p.add_argument("--nodelist", default=os.environ.get("NODELIST", ""))
    p.add_argument("--date", default=os.environ.get("DATE", "today"))
    p.add_argument("--runtime-root", default=os.environ.get("AICR_RUNTIME_ROOT", ""))
    p.add_argument("--test-id", action="append", help="Run only a specific test id. May be repeated.")
    p.add_argument("--apply", action="store_true", default=os.environ.get("DOCS_APPLY", "0") == "1")
    return p


def split_command(argv: list[str]) -> tuple[list[str], str]:
    command = "run"
    for index in range(len(argv) - 1, -1, -1):
        if argv[index] in COMMANDS:
            command = argv[index]
            return argv[:index] + argv[index + 1 :], command
    return argv, command


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    argv, command = split_command(argv)
    args = build_parser().parse_args(argv)
    args.command = command
    if args.command == "plan":
        return command_plan(args)
    return command_run(args)


if __name__ == "__main__":
    sys.exit(main())
