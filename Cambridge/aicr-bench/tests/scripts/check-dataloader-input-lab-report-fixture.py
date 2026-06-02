#!/usr/bin/env python3
"""Render the DataLoader input-lab fixture and assert output shape."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate the DataLoader input-lab renderer fixture.")
    parser.add_argument(
        "--fixture",
        default="tests/fixtures/dataloader/input-lab-report",
        help="Fixture directory relative to the repo root.",
    )
    return parser


def assert_nonempty(path: Path) -> None:
    if not path.exists() or path.stat().st_size <= 0:
        raise SystemExit(f"{path}: missing or empty")


def assert_contains(path: Path, patterns: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    for pattern in patterns:
        if pattern not in text:
            raise SystemExit(f"{path}: missing expected text: {pattern}")


def assert_not_contains(path: Path, patterns: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    for pattern in patterns:
        if pattern in text:
            raise SystemExit(f"{path}: unexpected text: {pattern}")


def main() -> int:
    args = build_parser().parse_args()
    root = repo_root()
    fixture = Path(args.fixture)
    if not fixture.is_absolute():
        fixture = root / fixture
    metadata = json.loads((fixture / "metadata.json").read_text(encoding="utf-8"))
    expected = metadata["expected"]

    with tempfile.TemporaryDirectory(prefix="aicr-dataloader-input-lab-") as tmp:
        output_dir = Path(tmp)
        command = [
            sys.executable,
            str(root / "scripts" / "report" / "render-dataloader-input-lab-report.py"),
            "--date",
            metadata["date"],
            "--cluster",
            metadata["cluster"],
            "--results-root",
            str(fixture / "input"),
            "--output-dir",
            str(output_dir),
            "--baseline-samples-per-second",
            str(expected["baseline_samples_per_second"]),
        ]
        subprocess.run(command, cwd=root, check=True)

        date_value = metadata["date"]
        cluster = metadata["cluster"]
        md_path = output_dir / f"dataloader-input-lab-{cluster}-{date_value}.md"
        csv_path = output_dir / f"dataloader-input-lab-summary-{cluster}-{date_value}.csv"
        json_path = output_dir / f"dataloader-input-lab-summary-{cluster}-{date_value}.json"
        aggregate_csv_path = output_dir / f"dataloader-input-lab-aggregate-{cluster}-{date_value}.csv"
        aggregate_json_path = output_dir / f"dataloader-input-lab-aggregate-{cluster}-{date_value}.json"
        top_png = output_dir / f"dataloader-input-lab-throughput-{cluster}-{date_value}.png"
        image_size_png = output_dir / f"dataloader-input-lab-image-size-{cluster}-{date_value}.png"
        original_speedup_png = output_dir / f"dataloader-input-lab-speedup-original-{cluster}-{date_value}.png"
        same_size_speedup_png = output_dir / f"dataloader-input-lab-speedup-same-size-{cluster}-{date_value}.png"

        for path in [
            md_path,
            csv_path,
            json_path,
            aggregate_csv_path,
            aggregate_json_path,
            top_png,
            image_size_png,
            original_speedup_png,
            same_size_speedup_png,
        ]:
            assert_nonempty(path)

        rows = json.loads(json_path.read_text(encoding="utf-8"))
        aggregate_rows = json.loads(aggregate_json_path.read_text(encoding="utf-8"))
        if len(rows) != expected["row_count"]:
            raise SystemExit(f"row count: observed {len(rows)}, expected {expected['row_count']}")
        if len(aggregate_rows) != expected["aggregate_row_count"]:
            raise SystemExit(
                f"aggregate row count: observed {len(aggregate_rows)}, "
                f"expected {expected['aggregate_row_count']}"
            )
        observed_backends = sorted({row["input_backend"] for row in rows})
        if observed_backends != sorted(expected["input_backends"]):
            raise SystemExit(f"input backends: observed {observed_backends}")

        assert_contains(
            md_path,
            [
                "DataLoader Input Pipeline Lab",
                "DALI",
                "NumPy uint8",
                "NumPy fp16",
                "Speedup vs original",
                "Same-size speedup",
                "DDP Validation Threshold",
            ],
        )
        assert_not_contains(
            md_path,
            [
                "Decision Gate For DDP",
                "Carry a DataLoader-only candidate",
                "closeout",
            ],
        )

    print(f"fixture={metadata['fixture_id']}")
    print("input_lab_report_shape=passed")
    print(f"aggregate_row_count={expected['aggregate_row_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
