#!/usr/bin/env python3
"""Render the DDP fixture and assert the report shape."""

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
    parser = argparse.ArgumentParser(description="Validate DDP fixture report shape.")
    parser.add_argument(
        "--fixture",
        default="tests/fixtures/ddp/report-shape",
        help="Fixture directory relative to the repo root. Default: tests/fixtures/ddp/report-shape.",
    )
    return parser


def load_renderer(root: Path):
    module_path = root / "scripts" / "report" / "render-ddp-resnet50-report.py"
    sys.path.insert(0, str(module_path.parent))
    spec = importlib.util.spec_from_file_location("render_ddp_resnet50_report", module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"could not load {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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


def assert_nonempty(path: Path) -> None:
    if not path.exists() or path.stat().st_size <= 0:
        raise SystemExit(f"{path}: missing or empty")


def write_summary(path: Path, metadata: dict, row: dict) -> None:
    backend = row["input_backend"]
    summary = {
        "date": metadata["date"],
        "cluster": metadata["cluster"],
        "run_id": row["run_id"],
        "job_id": row["job_id"],
        "status": "passed",
        "launcher": "torchrun",
        "input_backend": backend,
        "input_gpu_resident": False,
        "node_count": 1,
        "world_size": 8,
        "precision": "bf16",
        "dataset_size": 1281167,
        "global_batch_size": 6144,
        "batch_size_per_rank": 768,
        "num_workers": 16,
        "prefetch_factor": 4,
        "dali_num_threads": 8 if backend == "dali-gpu-decode" else None,
        "dali_prefetch_queue_depth": 1 if backend == "dali-gpu-decode" else None,
        "dali_decode_mode": "random-crop" if backend == "dali-gpu-decode" else None,
        "dali_hw_decoder_load": 0.65 if backend == "dali-gpu-decode" else None,
        "pin_memory": True,
        "persistent_workers": True,
        "warmup_iters": 100,
        "measured_iters": 500,
        "samples_per_second": row["samples_per_second"],
        "estimated_epoch_time_minutes": 1281167 / row["samples_per_second"] / 60,
        "rank_imbalance_percent": 1.5,
        "step_mean_seconds_max_rank": 0.2,
        "data_wait_mean_seconds_max_rank": row["data_wait_mean_seconds_max_rank"],
        "h2d_mean_seconds_max_rank": 0.003,
        "input_prepare_mean_seconds_max_rank": 0.01,
        "train_mean_seconds_max_rank": 0.18,
        "node_list": ["b0001"],
        "per_rank": [],
    }
    summary.update(row.get("summary_overrides", {}))
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

    with tempfile.TemporaryDirectory(prefix="aicr-ddp-report-shape-") as tmp:
        tmp_root = Path(tmp)
        results_root = tmp_root / "results"
        for row in metadata["rows"]:
            summary_path = (
                results_root
                / "by-date"
                / metadata["date"]
                / "parsed"
                / metadata["cluster"]
                / "multi-node"
                / "ddp-resnet50"
                / row["run_id"]
                / "summary.json"
            )
            write_summary(summary_path, metadata, row)

        rows = renderer.load_rows(results_root, metadata["date"], metadata["cluster"])
        df = renderer.add_derived_fields(renderer.pd.DataFrame(rows))
        aggregate_df = renderer.aggregate_repeat_rows(df)
        output_dir = tmp_root / "reports"
        output_dir.mkdir(parents=True, exist_ok=True)
        csv_path = output_dir / "ddp-resnet50-summary-b200-2026-05-24.csv"
        aggregate_csv_path = output_dir / "ddp-resnet50-repeat-aggregation-b200-2026-05-24.csv"
        md_path = output_dir / "ddp-resnet50-b200-2026-05-24.md"
        meta_path = output_dir / "ddp-resnet50-report-b200-2026-05-24.json"
        throughput_path = output_dir / "ddp-resnet50-throughput-b200-2026-05-24.png"
        scaling_path = output_dir / "ddp-resnet50-scaling-b200-2026-05-24.png"

        df.to_csv(csv_path, index=False)
        aggregate_df.to_csv(aggregate_csv_path, index=False)
        meta_path.write_text(json.dumps({"fixture": metadata["fixture_id"]}) + "\n", encoding="utf-8")
        throughput_written = renderer.write_throughput_plot(df, throughput_path)
        scaling_written = renderer.write_scaling_plot(df, scaling_path)
        renderer.write_markdown(
            df,
            aggregate_df,
            md_path,
            csv_path,
            aggregate_csv_path,
            meta_path,
            throughput_path,
            throughput_written,
            scaling_path,
            scaling_written,
            0,
        )

        for path in [csv_path, aggregate_csv_path, md_path, meta_path, throughput_path, scaling_path]:
            assert_nonempty(path)

        assert_contains(
            md_path,
            [
                "## Training-Throughput Validation",
                "## Prepared-Tensor DDP Transport Pilot",
                "## Repeat Aggregation",
                "Olympic img/s",
                "DALI NumPy GPU/cuFile path",
                "synthetic GPU labels",
                "not canonical ImageNet JPEG evidence",
                "cuFile logs",
                "Logical batch/GPU",
                "File batch/GPU",
                "Scaling plot",
                "Mean timing fields follow [Stats Explained]",
                "[Stats Explained](../../../../docs/stats-explained.md)",
            ],
        )
        assert_not_contains(
            md_path,
            [
                "../../..... /../docs/stats-explained.md",
                "DDP " + chr(71) + "ate",
                chr(71) + "ate note",
                "Passed DDP " + chr(103) + "ate",
                "Not " + "pro" + "moted",
                "pro" + "moted evidence",
            ],
        )

    print(f"fixture={metadata['fixture_id']}")
    print("markdown_shape=passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
