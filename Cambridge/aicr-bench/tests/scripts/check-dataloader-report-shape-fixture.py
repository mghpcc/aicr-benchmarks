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
    rows = [renderer.row_from_summary(path, renderer.load_json(path)) for path in summaries]
    summary_rows = renderer.aggregate_dataloader_repeat_rows(rows, expected["aggregation"])

    with tempfile.TemporaryDirectory(prefix="aicr-dataloader-report-shape-") as tmp:
        output_dir = Path(tmp)
        date_value = metadata["date"]
        cluster = metadata["cluster"]
        csv_path = output_dir / f"dataloader-summary-{cluster}-{date_value}.csv"
        summary_csv_path = output_dir / f"dataloader-aggregated-summary-{cluster}-{date_value}.csv"
        md_path = output_dir / f"dataloader-{cluster}-{date_value}.md"
        png_path = output_dir / f"dataloader-throughput-{cluster}-{date_value}.png"
        throughput_matrix_path = output_dir / f"dataloader-throughput-matrix-{cluster}-{date_value}.png"
        imbalance_matrix_path = output_dir / f"dataloader-imbalance-matrix-{cluster}-{date_value}.png"
        candidate_scatter_path = output_dir / f"dataloader-candidate-scatter-{cluster}-{date_value}.png"
        interactive_html_path = output_dir / f"dataloader-matrix-{cluster}-{date_value}.html"

        renderer.write_csv(csv_path, rows)
        renderer.write_csv(summary_csv_path, summary_rows)
        interactive_html_path.write_text(
            renderer.build_interactive_html_page(
                cluster,
                date_value,
                "Synthetic fixture dashboard shape check, not benchmark certification evidence.",
                ["Synthetic fixture takeaway."],
                "<table><tbody><tr><td>candidate</td></tr></tbody></table>",
                "<script>Plotly.newPlot('fixture')</script>",
            ),
            encoding="utf-8",
        )
        md_path.write_text(
            renderer.build_markdown(
                rows,
                summary_rows,
                date_value,
                cluster,
                csv_path,
                summary_csv_path,
                png_path,
                throughput_matrix_path,
                imbalance_matrix_path,
                candidate_scatter_path,
                interactive_html_path,
                expected["aggregation"],
            ),
            encoding="utf-8",
        )

        for path in [
            csv_path,
            summary_csv_path,
            md_path,
            interactive_html_path,
        ]:
            assert_nonempty(path)

        assert_contains(
            md_path,
            [
                "## Aggregated Configuration Summary",
                "Repeated configuration rows are summarized before plotting.",
                "dataloader-aggregated-summary",
                "## Detailed Rows",
            ],
        )
        assert_contains(
            interactive_html_path,
            [
                "What To Take Away",
                "Top Balanced Candidates",
                "not benchmark certification evidence",
                "Plotly.newPlot",
            ],
        )

    print(f"fixture={metadata['fixture_id']}")
    print("markdown_shape=passed")
    print("interactive_html_shape=passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
