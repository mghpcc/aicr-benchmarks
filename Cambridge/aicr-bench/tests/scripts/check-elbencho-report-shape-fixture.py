#!/usr/bin/env python3
"""Render the Elbencho fixture and assert the report shape."""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
import tempfile
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate Elbencho fixture report shape.")
    parser.add_argument(
        "--fixture",
        default="tests/fixtures/elbencho/report-shape",
        help="Fixture directory relative to the repo root. Default: tests/fixtures/elbencho/report-shape.",
    )
    return parser


def load_renderer(root: Path):
    module_path = root / "scripts" / "report" / "render-elbencho-report.py"
    sys.path.insert(0, str(module_path.parent))
    spec = importlib.util.spec_from_file_location("render_elbencho_report", module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"could not load {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def assert_contains(text: str, patterns: list[str]) -> None:
    for pattern in patterns:
        if pattern not in text:
            raise SystemExit(f"missing expected text: {pattern}")


def assert_not_contains(text: str, patterns: list[str]) -> None:
    for pattern in patterns:
        if pattern in text:
            raise SystemExit(f"unexpected text: {pattern}")


def write_summary(path: Path, metadata: dict, row: dict) -> None:
    summary = {
        "status": "passed",
        "cluster": metadata["cluster"],
        "date": metadata["date"],
        "run_id": row["run_id"],
        "profile": row["profile"],
        "workload": row["workload"],
        "node": row["peer_nodes"][0],
        "peer_nodes": row["peer_nodes"],
        "node_count": row["node_count"],
        "job_id": row["job_id"],
        "partition": "b200-batch",
        "command": "fixture elbencho command with RUN_ROOT --size 20G --block 1M --threads 64 --iodepth 16 --direct --dryrun --delfiles --deldirs --hostsfile --service --quit",
        "return_code": 0,
        "stdout_file": "fixture/stdout.txt",
        "stderr_file": "fixture/stderr.txt",
        "metrics": row["metrics"],
        "command_review": {
            "status": "reviewed-shape",
            "missing": [],
        },
        "evidence_label": row["evidence_label"],
        "notes": "",
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    args = build_parser().parse_args()
    root = repo_root()
    fixture = Path(args.fixture)
    if not fixture.is_absolute():
        fixture = root / fixture
    metadata = json.loads((fixture / "metadata.json").read_text(encoding="utf-8"))
    renderer = load_renderer(root)

    with tempfile.TemporaryDirectory(prefix="aicr-elbencho-report-shape-") as tmp:
        results_root = Path(tmp) / "results"
        for row in metadata["rows"]:
            summary_path = (
                results_root
                / "by-date"
                / metadata["date"]
                / "parsed"
                / metadata["cluster"]
                / "multi-node"
                / "elbencho"
                / row["run_id"]
                / "summary.json"
            )
            write_summary(summary_path, metadata, row)

        paths = renderer.collect_summaries(results_root, metadata["date"], metadata["cluster"])
        rows = renderer.rows_from_summaries(paths)
        text = renderer.render_markdown(rows, metadata["date"], metadata["cluster"])

        assert_contains(
            text,
            [
                "## Campaign Evidence Rows",
                "small-block",
                "metadata",
                "peak-cluster",
                "non-cache-neutral-rehearsal",
                "reviewed-shape",
                "57751.7",
                "b0002,b0003,b0004",
            ],
        )
        assert_not_contains(
            text,
            [
                "No elbencho summaries were found",
                "## Command Review Follow-Up",
            ],
        )

    print(f"fixture={metadata['fixture_id']}")
    print("markdown_shape=passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
