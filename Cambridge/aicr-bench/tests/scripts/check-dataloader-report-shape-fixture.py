#!/usr/bin/env python3
"""Render the DataLoader fixture and assert the report/dashboard shape."""

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
    parser = argparse.ArgumentParser(description="Validate DataLoader fixture report shape.")
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


def assert_contains(path: Path, patterns: list[str]) -> None:
    text = path.read_text(encoding="utf-8")
    for pattern in patterns:
        if pattern not in text:
            raise SystemExit(f"{path}: missing expected text: {pattern}")


def assert_nonempty(path: Path) -> None:
    if not path.exists() or path.stat().st_size <= 0:
        raise SystemExit(f"{path}: missing or empty")


def row_from_fixture_summary(renderer, summary_path: Path, fixture: Path, metadata: dict):
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    return renderer.row_from_summary(
        summary,
        summary_path,
        fixture / "input",
        metadata["date"],
        metadata["cluster"],
        "node",
        summary.get("host"),
    )


def main() -> int:
    args = build_parser().parse_args()
    root = repo_root()
    fixture = Path(args.fixture)
    if not fixture.is_absolute():
        fixture = root / fixture
    metadata = json.loads((fixture / "metadata.json").read_text(encoding="utf-8"))
    expected = metadata["expected"]
    renderer = load_renderer(root)

    summaries = sorted(fixture.glob(metadata["input_summary_glob"]))
    if not summaries:
        raise SystemExit(f"no summary.json files matched {metadata['input_summary_glob']} under {fixture}")
    rows = [row_from_fixture_summary(renderer, path, fixture, metadata) for path in summaries]
    df = renderer.pd.DataFrame(rows)

    with tempfile.TemporaryDirectory(prefix="aicr-dataloader-report-shape-") as tmp:
        output_dir = Path(tmp)
        date_value = metadata["date"]
        cluster = metadata["cluster"]
        csv_path = output_dir / f"dataloader-summary-{cluster}-{date_value}.csv"
        metadata_path = output_dir / f"dataloader-report-{cluster}-{date_value}.json"
        md_path = output_dir / f"dataloader-{cluster}-{date_value}.md"
        png_path = output_dir / f"dataloader-throughput-{cluster}-{date_value}.png"
        imbalance_path = output_dir / f"dataloader-rank-imbalance-{cluster}-{date_value}.png"

        df.to_csv(csv_path, index=False)
        metadata_path.write_text(json.dumps({"fixture": metadata["fixture_id"]}) + "\n", encoding="utf-8")
        renderer.write_markdown_report(
            df,
            md_path,
            csv_path,
            metadata_path,
            False,
            png_path,
            False,
            imbalance_path,
            [],
            0,
            date_value,
            cluster,
            expected["aggregation"],
        )

        for path in [
            csv_path,
            md_path,
            metadata_path,
        ]:
            assert_nonempty(path)

        assert_contains(
            md_path,
            [
                "## Repeated Config Summary",
                "Grouped rows use the same sampler",
                "Olympic avg images/sec",
                "## Detailed Rows",
                "[Stats Explained](../../../../docs/stats-explained.md)",
            ],
        )
        text = md_path.read_text(encoding="utf-8")
        if "../../..... /../docs/stats-explained.md" in text:
            raise SystemExit(f"{md_path}: emitted malformed Stats Explained link")

    print(f"fixture={metadata['fixture_id']}")
    print("markdown_shape=passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
