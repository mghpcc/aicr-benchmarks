#!/usr/bin/env python3
"""Check public documentation hygiene beyond man-page link inventory."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


FORBIDDEN_STATS_REF = "wi" + "ki/" + "stats-explained" + ".md"
WARMUP_ONE = "warmup" + "=1"
MEASURED_TWO = "measured" + "=2"

FORBIDDEN_PATTERNS = (
    (re.compile(re.escape(FORBIDDEN_STATS_REF)), f"link docs/stats-explained.md instead of {FORBIDDEN_STATS_REF}"),
    (re.compile(r"--warmup-batches\s+1(?![0-9])"), "published DataLoader examples must not use warmup-batches=1"),
    (re.compile(r"--measured-batches\s+2(?![0-9])"), "published DataLoader examples must not use measured-batches=2"),
    (re.compile(r"--warmup-iters\s+1(?![0-9])"), "published DDP examples must not use warmup-iters=1"),
    (re.compile(r"--measured-iters\s+2(?![0-9])"), "published DDP examples must not use measured-iters=2"),
    (re.compile(re.escape(WARMUP_ONE) + r"(?![0-9])"), f"published examples must not describe {WARMUP_ONE}"),
    (re.compile(re.escape(MEASURED_TWO) + r"(?![0-9])"), f"published examples must not describe {MEASURED_TWO}"),
)
STUDY_STATUS_RE = re.compile(r"<!--\s*aicr-study-status:\s*(published|scaffold|plan|draft|appendix)\s*-->")
STUDY_LINK_RE = re.compile(r"\]\((studies/[^)#]+\.md)(?:#[^)]+)?\)")
INDEX_NON_EVIDENCE_RE = re.compile(r"\b(pending|scaffold|planned|plan|draft|context|run sheet)\b", re.IGNORECASE)
INDEX_APPENDIX_RE = re.compile(r"\b(appendix|reference|supporting)\b", re.IGNORECASE)
NON_EVIDENCE_BANNERS = {
    "scaffold": ("Publication Scaffold - Not Evidence",),
    "plan": ("Campaign Plan - Not Evidence",),
    "draft": ("Draft Context - Not Published Evidence",),
    "appendix": (
        "Appendix - Supporting Reference, Not A Standalone Study",
        "Appendix - Decode-Path Detail",
    ),
}
PENDING_STUDY_RE = re.compile(r"\b(TODO|Pending publication|Pending artifact review|Pending run)\b")
REQUIRED_FIXTURE_METADATA = {
    "schema_version",
    "fixture_id",
    "fixture_type",
    "purpose",
}
NODE_TOKEN_RE = re.compile(r"\b([a-z]+)([0-9]{4})\b")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def markdown_files(root: Path) -> list[Path]:
    skip_dirs = {".git", "graphify-out", "results", "scratch"}
    paths: list[Path] = []
    for path in root.rglob("*.md"):
        parts = set(path.relative_to(root).parts)
        if parts & skip_dirs:
            continue
        paths.append(path)
    return sorted(paths)


def check_public_docs(root: Path) -> list[str]:
    failures: list[str] = []
    for path in markdown_files(root):
        rel = path.relative_to(root)
        text = path.read_text(encoding="utf-8")
        for line_number, line in enumerate(text.splitlines(), start=1):
            for pattern, message in FORBIDDEN_PATTERNS:
                if pattern.search(line):
                    failures.append(f"{rel}:{line_number}: {message}")
    failures.extend(check_study_statuses(root))
    failures.extend(check_fixture_hygiene(root))
    failures.extend(check_node_name_examples(root))
    return failures


def check_node_name_examples(root: Path) -> list[str]:
    failures: list[str] = []
    for path in markdown_files(root):
        rel = path.relative_to(root)
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            for match in NODE_TOKEN_RE.finditer(line):
                prefix = match.group(1)
                number = int(match.group(2))
                token = match.group(0)
                if len(prefix) > 3:
                    continue
                if prefix == "a" and 1 <= number <= 19:
                    continue
                if prefix == "b" and 1 <= number <= 31:
                    continue
                if prefix == "w" and 1 <= number <= 9999:
                    continue
                failures.append(
                    f"{rel}:{line_number}: node examples must use a0001-a0019, b0001-b0031, or w CPU nodes, "
                    f"found {token}"
                )
    return failures


def study_status(text: str) -> str | None:
    match = STUDY_STATUS_RE.search(text)
    return match.group(1) if match else None


def study_page_files(root: Path) -> list[Path]:
    return sorted((root / "docs" / "modules").glob("*/studies/*.md"))


def check_study_statuses(root: Path) -> list[str]:
    failures: list[str] = []
    statuses: dict[Path, str | None] = {}
    for path in study_page_files(root):
        rel = path.relative_to(root)
        text = path.read_text(encoding="utf-8")
        status = study_status(text)
        statuses[rel] = status
        if status in {"draft", "appendix"} and not has_status_banner(text, status):
            banners = "', '".join(NON_EVIDENCE_BANNERS[status])
            failures.append(f"{rel}: {status} page must include one visible banner from '{banners}'")
        if PENDING_STUDY_RE.search(text):
            if status not in {"scaffold", "plan", "draft"}:
                failures.append(f"{rel}: pending/TODO study page must declare scaffold, plan, or draft status")
                continue
            if not has_status_banner(text, status):
                banners = "', '".join(NON_EVIDENCE_BANNERS[status])
                failures.append(f"{rel}: {status} study page must include one visible banner from '{banners}'")

    for index_path in sorted((root / "docs" / "modules").glob("*/studies.md")):
        index_rel = index_path.relative_to(root)
        for line_number, line in enumerate(index_path.read_text(encoding="utf-8").splitlines(), start=1):
            for match in STUDY_LINK_RE.finditer(line):
                target = (index_path.parent / match.group(1)).resolve()
                try:
                    target_rel = target.relative_to(root.resolve())
                except ValueError:
                    continue
                target_status = statuses.get(target_rel)
                if target_status in {"scaffold", "plan", "draft"} and not INDEX_NON_EVIDENCE_RE.search(line):
                    failures.append(
                        f"{index_rel}:{line_number}: link to {target_status} page {target_rel} "
                        "must be labeled pending/scaffold/planned/plan/draft/context"
                    )
                if target_status == "appendix" and not INDEX_APPENDIX_RE.search(line):
                    failures.append(
                        f"{index_rel}:{line_number}: link to appendix page {target_rel} "
                        "must be labeled appendix/reference/supporting"
                    )
    return failures


def has_status_banner(text: str, status: str) -> bool:
    return any(banner in text for banner in NON_EVIDENCE_BANNERS[status])


def metadata_has_input(metadata: dict) -> bool:
    return any(key.startswith("input") for key in metadata)


def check_fixture_hygiene(root: Path) -> list[str]:
    failures: list[str] = []
    fixtures_root = root / "tests" / "fixtures"
    if not fixtures_root.exists():
        return failures
    for path in sorted(fixtures_root.rglob("*")):
        if "results" in path.relative_to(fixtures_root).parts:
            failures.append(f"{path.relative_to(root)}: fixtures must not use runtime results/ directories")
    for metadata_path in sorted(fixtures_root.rglob("metadata.json")):
        rel = metadata_path.relative_to(root)
        try:
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            failures.append(f"{rel}: metadata JSON is invalid: {exc}")
            continue
        missing = sorted(REQUIRED_FIXTURE_METADATA - set(metadata))
        if missing:
            failures.append(f"{rel}: missing required fixture metadata fields: {', '.join(missing)}")
        if not metadata_has_input(metadata):
            failures.append(f"{rel}: fixture metadata must include at least one input* field")
        fixture_type = str(metadata.get("fixture_type", ""))
        if "synthetic" in fixture_type and metadata.get("not_benchmark_evidence") is not True:
            failures.append(f"{rel}: synthetic fixtures must set not_benchmark_evidence: true")
    return failures


def main() -> int:
    root = repo_root()
    failures = check_public_docs(root)
    if failures:
        print("Public-docs check failed:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print("Public-docs check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
