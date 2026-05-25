#!/usr/bin/env python3
"""Render topology-map fixtures and assert graph/report shape."""

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
    parser = argparse.ArgumentParser(description="Validate GPU topology map fixture rendering.")
    parser.add_argument(
        "--fixture",
        default="tests/fixtures/gpu-topology/topology-map",
        help="Fixture directory relative to the repo root.",
    )
    return parser


def load_module(name: str, path: Path):
    sys.path.insert(0, str(path.parent))
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"could not load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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


def assert_warning(graph: dict, expected: list[str]) -> None:
    warnings = graph.get("warnings") or []
    for pattern in expected:
        if not any(pattern in item for item in warnings):
            raise SystemExit(f"missing expected warning {pattern!r}; warnings={warnings}")


def validate_case(renderer, graph_mod, fixture: Path, case: dict, out_dir: Path) -> None:
    summary = fixture / case["summary"]
    graph = graph_mod.build_graph(summary, None)
    assert graph["schema"] == "aicr.topology_graph.v1"
    assert graph["source"]["cluster"] == case["cluster"]
    assert graph["derived_affinity"]["policy"] == "reviewed-derived-nps4"
    assert len([item for item in graph["nodes"] if item["type"] == "gpu"]) == 8
    assert len([item for item in graph["nodes"] if item["type"] == "numa_domain"]) == 8
    assert any(edge["type"] == "gpu_nic_nearest" for edge in graph["edges"])
    assert any(edge["type"] == "gpu_gpu_link" for edge in graph["edges"])
    assert_warning(graph, case.get("expected_warnings", []))

    written = renderer.write_outputs(graph, out_dir, "both")
    suffixes = {path.suffix for path in written}
    if suffixes != {".json", ".svg", ".html"}:
        raise SystemExit(f"unexpected outputs for {case['cluster']}: {written}")
    for path in written:
        assert_nonempty(path)
    html_path = next(path for path in written if path.suffix == ".html")
    svg_path = next(path for path in written if path.suffix == ".svg")
    json_path = next(path for path in written if path.suffix == ".json")
    assert_contains(html_path, ["Topology Map:", "Static view", "Graph JSON"])
    assert_contains(svg_path, ["AICR topology map", "NUMA domains and CPU ranges", "IB fabric mlx5 devices"])
    assert_not_contains(svg_path, case.get("expected_svg_absent", []))
    rendered_graph = json.loads(json_path.read_text(encoding="utf-8"))
    if rendered_graph["source"]["cluster"] != case["cluster"]:
        raise SystemExit(f"{json_path}: rendered graph cluster mismatch")


def main() -> int:
    args = build_parser().parse_args()
    root = repo_root()
    fixture = Path(args.fixture)
    if not fixture.is_absolute():
        fixture = root / fixture
    metadata = json.loads((fixture / "metadata.json").read_text(encoding="utf-8"))
    renderer = load_module("render_topology_map", root / "scripts" / "report" / "render-topology-map.py")
    graph_mod = load_module("topology_graph", root / "scripts" / "parse" / "topology_graph.py")

    with tempfile.TemporaryDirectory(prefix="aicr-topology-map-") as tmp:
        out_dir = Path(tmp)
        for case in metadata["cases"]:
            validate_case(renderer, graph_mod, fixture, case, out_dir)

    print(f"fixture={metadata['fixture_id']}")
    print("topology_map_shape=passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
