#!/usr/bin/env python3
"""Validate the synthetic DataLoader Olympic repeat fixture."""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
import sys
from pathlib import Path


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate the synthetic DataLoader Olympic fixture.")
    parser.add_argument(
        "--fixture",
        default="tests/fixtures/dataloader/olympic-repeat",
        help="Fixture directory relative to the repo root. Default: tests/fixtures/dataloader/olympic-repeat.",
    )
    return parser


def load_renderer(root: Path):
    module_path = root / "scripts" / "report" / "render-dataloader-report.py"
    sys.path.insert(0, str(module_path.parent))
    spec = importlib.util.spec_from_file_location("render_dataloader_report", module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"could not load {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def close(name: str, observed, expected_value) -> None:
    if not math.isclose(float(observed), float(expected_value), rel_tol=0.0, abs_tol=1e-9):
        raise SystemExit(f"{name}: observed {observed}, expected {expected_value}")


def main() -> int:
    args = build_parser().parse_args()
    root = repo_root()
    fixture = Path(args.fixture)
    if not fixture.is_absolute():
        fixture = root / fixture
    metadata_path = fixture / "metadata.json"
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    expected = metadata["expected"]
    renderer = load_renderer(root)

    summaries = sorted(fixture.glob(metadata["input_summary_glob"]))
    if not summaries:
        raise SystemExit(f"no summary.json files matched {metadata['input_summary_glob']} under {fixture}")
    rows = [renderer.row_from_summary(path, renderer.load_json(path)) for path in summaries]
    summary_rows = renderer.aggregate_dataloader_repeat_rows(rows, expected["aggregation"])

    if len(summary_rows) != expected["aggregated_config_count"]:
        raise SystemExit(
            f"aggregated config count: observed {len(summary_rows)}, "
            f"expected {expected['aggregated_config_count']}"
        )
    row = summary_rows[0]
    if row["repeat_passed_count"] != expected["repeat_sample_count"]:
        raise SystemExit("unexpected repeat passed count")
    if row["repeat_included_count"] != expected["repeat_included_count"]:
        raise SystemExit("unexpected repeat included count")

    close("samples_per_second", row["samples_per_second"], expected["olympic_samples_per_second"])
    close("rank_imbalance_percent", row["rank_imbalance_percent"], expected["olympic_rank_imbalance_percent"])
    close(
        "estimated_vast_read_gb_per_second",
        row["estimated_vast_read_gb_per_second"],
        expected["olympic_vast_read_gb_per_second"],
    )

    expected_drops = "/".join(f"{value:.2f}" for value in expected["dropped_samples_per_second"])
    if row["repeat_dropped_samples_per_second"] != expected_drops:
        raise SystemExit(
            f"dropped samples/s: observed {row['repeat_dropped_samples_per_second']}, "
            f"expected {expected_drops}"
        )

    print(f"fixture={metadata['fixture_id']}")
    print(f"aggregated_config_count={len(summary_rows)}")
    print(f"olympic_samples_per_second={row['samples_per_second']:.2f}")
    print(f"rank_imbalance_percent={row['rank_imbalance_percent']:.2f}")
    print(f"dropped_samples_per_second={row['repeat_dropped_samples_per_second']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
