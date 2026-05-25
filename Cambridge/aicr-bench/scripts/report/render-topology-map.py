#!/usr/bin/env python3
"""Render a single-node AICR topology graph as static SVG/HTML."""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "parse"))
import topology_graph
import topology_intelligence


WIDTH = 1180
BASE_HEIGHT = 600
LEFT = 88
RIGHT = 1090
NUMA_Y = 116
GPU_Y = 310
NIC_Y = 510
BOX_W = 104
BOX_H = 58


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render a report-only GPU topology map from AICR topology evidence.")
    parser.add_argument("--summary", help="Path to a parsed gpu-topology summary.json.")
    parser.add_argument("--results-root", default="results", help="Results root for --date/--cluster/--node lookup. Default: results.")
    parser.add_argument("--date", help="Date for lookup mode, e.g. 2026-05-24.")
    parser.add_argument("--cluster", choices=["b200", "rtxpro6000"], help="Cluster for lookup mode.")
    parser.add_argument("--node", help="Node for lookup mode.")
    parser.add_argument("--output-dir", default="results/reports/topology-map", help="Directory for rendered outputs.")
    parser.add_argument("--format", choices=["html", "svg", "both"], default="html", help="Output format. Default: html.")
    return parser


def load_summary_path(args: argparse.Namespace) -> Path:
    if args.summary:
        path = Path(args.summary)
        if not path.exists():
            raise SystemExit(f"summary not found: {path}")
        return path
    missing = [name for name in ("date", "cluster", "node") if not getattr(args, name)]
    if missing:
        raise SystemExit("--summary or --date/--cluster/--node is required")
    root = Path(args.results_root) / "by-date" / args.date / "parsed" / args.cluster / "nodes" / args.node / "gpu-topology"
    if not root.exists():
        raise SystemExit(f"topology parsed directory not found: {root}")
    runs = sorted(path for path in root.iterdir() if path.is_dir())
    if not runs:
        raise SystemExit(f"no topology runs found under {root}")
    summary = runs[-1] / "summary.json"
    if not summary.exists():
        raise SystemExit(f"summary not found: {summary}")
    return summary


def esc(value: Any) -> str:
    return html.escape("" if value is None else str(value), quote=True)


def safe_slug(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "-", value).strip("-") or "topology-map"


def node_items(graph: dict[str, Any], node_type: str) -> list[dict[str, Any]]:
    return [item for item in graph.get("nodes", []) if item.get("type") == node_type]


def svg_nic_items(graph: dict[str, Any]) -> list[dict[str, Any]]:
    """Return only resolved IB-fabric NIC devices for the public SVG map."""
    items = []
    for item in node_items(graph, "nic"):
        node_id = str(item.get("id", ""))
        netdevs = [str(netdev) for netdev in item.get("netdevs", [])]
        if node_id.startswith("NIC"):
            continue
        if not any(netdev.startswith("ib") for netdev in netdevs):
            continue
        items.append(item)
    return items


def gpu_key(item: dict[str, Any]) -> int:
    return topology_graph.natural_gpu_key(item.get("id", ""))


def nic_key(item: dict[str, Any]) -> int:
    return topology_intelligence.natural_mlx5_key(item.get("id", ""))


def positions(items: list[dict[str, Any]], y: int, key_fn) -> dict[str, tuple[float, float]]:
    ordered = sorted(items, key=key_fn)
    count = max(len(ordered), 1)
    step = (RIGHT - LEFT) / count
    out = {}
    for index, item in enumerate(ordered):
        x = LEFT + step * index + (step - BOX_W) / 2
        out[item["id"]] = (x, y)
    return out


def color_for_link(link: str) -> str:
    return {
        "NV": "#1d6f42",
        "PIX": "#2563eb",
        "PXB": "#6d28d9",
        "PHB": "#b45309",
        "NODE": "#7c2d12",
        "SYS": "#6b7280",
    }.get(link, "#475569")


def edge_label(edge: dict[str, Any]) -> str:
    link = edge.get("link")
    edge_type = edge.get("type", "")
    if link:
        return str(link)
    if edge_type in {"gpu_numa_locality", "nic_numa_locality"}:
        return "NUMA"
    return edge_type.replace("_", " ")


def center(pos: dict[str, tuple[float, float]], node_id: str, upper: bool = False) -> tuple[float, float] | None:
    if node_id not in pos:
        return None
    x, y = pos[node_id]
    return x + BOX_W / 2, y if upper else y + BOX_H


def svg_line(parts: list[str], source: tuple[float, float], target: tuple[float, float], edge: dict[str, Any], dashed: bool = False) -> None:
    color = color_for_link(edge.get("link", ""))
    dash = ' stroke-dasharray="7 5"' if dashed else ""
    parts.append(
        f'<line x1="{source[0]:.1f}" y1="{source[1]:.1f}" x2="{target[0]:.1f}" y2="{target[1]:.1f}" '
        f'stroke="{color}" stroke-width="2"{dash} />'
    )
    mx = (source[0] + target[0]) / 2
    my = (source[1] + target[1]) / 2
    label = esc(edge_label(edge))
    if label:
        parts.append(f'<text x="{mx:.1f}" y="{my - 5:.1f}" class="edge-label">{label}</text>')


def svg_box(parts: list[str], x: float, y: float, title: str, lines: list[str], class_name: str) -> None:
    parts.append(f'<g class="{class_name}">')
    parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{BOX_W}" height="{BOX_H}" rx="6" />')
    parts.append(f'<text x="{x + BOX_W / 2:.1f}" y="{y + 21:.1f}" class="box-title">{esc(title)}</text>')
    for index, line in enumerate(lines[:2]):
        parts.append(f'<text x="{x + BOX_W / 2:.1f}" y="{y + 39 + index * 14:.1f}" class="box-line">{esc(line)}</text>')
    parts.append("</g>")


def render_svg(graph: dict[str, Any]) -> str:
    source = graph.get("source", {})
    numas = node_items(graph, "numa_domain")
    gpus = sorted(node_items(graph, "gpu"), key=gpu_key)
    nics = sorted(svg_nic_items(graph), key=nic_key)
    pos: dict[str, tuple[float, float]] = {}
    pos.update(positions(numas, NUMA_Y, lambda item: int(str(item.get("id", "numa999")).replace("numa", ""))))
    pos.update(positions(gpus, GPU_Y, gpu_key))
    pos.update(positions(nics, NIC_Y, nic_key))

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{BASE_HEIGHT}" viewBox="0 0 {WIDTH} {BASE_HEIGHT}" role="img" aria-label="AICR topology map">',
        "<style>",
        ".bg{fill:#f8fafc}.title{font:700 24px system-ui, sans-serif;fill:#111827}.subtitle{font:13px system-ui, sans-serif;fill:#475569}",
        ".section{font:700 13px system-ui, sans-serif;fill:#334155}.edge-label{font:11px system-ui, sans-serif;fill:#334155;text-anchor:middle}",
        ".box-title{font:700 13px system-ui, sans-serif;fill:#111827;text-anchor:middle}.box-line{font:11px system-ui, sans-serif;fill:#475569;text-anchor:middle}",
        ".numa rect{fill:#e0f2fe;stroke:#0369a1}.gpu rect{fill:#dcfce7;stroke:#15803d}.nic rect{fill:#fef3c7;stroke:#b45309}",
        "</style>",
        '<rect class="bg" x="0" y="0" width="100%" height="100%" />',
        f'<text x="40" y="44" class="title">Topology Map: {esc(source.get("cluster"))} {esc(source.get("node"))}</text>',
        f'<text x="40" y="68" class="subtitle">Run {esc(source.get("run_id"))} on {esc(source.get("date"))}; report-only view from parsed topology evidence</text>',
        '<text x="40" y="102" class="section">NUMA domains and CPU ranges</text>',
        '<text x="40" y="296" class="section">GPUs</text>',
        '<text x="40" y="496" class="section">IB fabric mlx5 devices</text>',
    ]

    for edge in graph.get("edges", []):
        edge_type = edge.get("type")
        if edge_type == "gpu_gpu_link":
            source_name = edge.get("source", "")
            target_name = edge.get("target", "")
            if abs(topology_graph.natural_gpu_key(source_name) - topology_graph.natural_gpu_key(target_name)) != 1:
                continue
            source_pt = center(pos, source_name, upper=True)
            target_pt = center(pos, target_name, upper=True)
            if source_pt and target_pt:
                svg_line(parts, (source_pt[0], source_pt[1] - 18), (target_pt[0], target_pt[1] - 18), edge)
        elif edge_type == "gpu_numa_locality":
            source_pt = center(pos, edge.get("target", ""), upper=False)
            target_pt = center(pos, edge.get("source", ""), upper=True)
            if source_pt and target_pt:
                svg_line(parts, source_pt, target_pt, edge, dashed=True)
        elif edge_type == "nic_numa_locality":
            source_pt = center(pos, edge.get("source", ""), upper=True)
            target_pt = center(pos, edge.get("target", ""), upper=False)
            if source_pt and target_pt:
                svg_line(parts, source_pt, target_pt, edge, dashed=True)
        elif edge_type == "gpu_nic_nearest":
            source_pt = center(pos, edge.get("source", ""), upper=False)
            target_pt = center(pos, edge.get("target", ""), upper=True)
            if source_pt and target_pt:
                svg_line(parts, source_pt, target_pt, edge, dashed=edge.get("link") == "SYS")

    for item in numas:
        x, y = pos[item["id"]]
        svg_box(parts, x, y, item["label"], [f"CPU {item.get('cpu_range') or '-'}"], "numa")
    for item in gpus:
        x, y = pos[item["id"]]
        svg_box(parts, x, y, item["label"], [f"NUMA {item.get('numa') or '-'}", f"CPU {item.get('cpu_affinity') or '-'}"], "gpu")
    for item in nics:
        x, y = pos[item["id"]]
        svg_box(parts, x, y, item["label"], [f"NUMA {item.get('numa') or '-'}", f"CPU {item.get('cpu_affinity') or '-'}"], "nic")

    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def render_html(graph: dict[str, Any], svg: str) -> str:
    source = graph.get("source", {})
    warnings = graph.get("warnings") or []
    observations = graph.get("summary", {}).get("topology_observations") or []
    graph_json = json.dumps(graph, indent=2, sort_keys=True)
    warning_items = "\n".join(f"<li>{esc(item)}</li>" for item in warnings) or "<li>No parser warnings.</li>"
    observation_items = "\n".join(f"<li>{esc(item)}</li>" for item in observations) or "<li>No observations recorded.</li>"
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Topology Map {esc(source.get("cluster"))} {esc(source.get("node"))}</title>
  <style>
    body {{ margin: 0; font: 14px system-ui, sans-serif; color: #111827; background: #f8fafc; }}
    main {{ max-width: 1220px; margin: 0 auto; padding: 24px; }}
    h1 {{ font-size: 24px; margin: 0 0 4px; }}
    p {{ color: #475569; }}
    .map {{ overflow-x: auto; border: 1px solid #cbd5e1; background: white; }}
    .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-top: 20px; }}
    section {{ background: white; border: 1px solid #cbd5e1; padding: 16px; }}
    h2 {{ font-size: 16px; margin: 0 0 10px; }}
    li {{ margin: 4px 0; }}
    pre {{ overflow-x: auto; background: #0f172a; color: #e2e8f0; padding: 16px; }}
  </style>
</head>
<body>
<main>
  <h1>Topology Map: {esc(source.get("cluster"))} {esc(source.get("node"))}</h1>
  <p>Static view from AICR GPU topology evidence. It shows CPU, NUMA, GPU, PCIe/NVLink, and resolved IB fabric mlx5 locality.</p>
  <div class="map">
{svg}
  </div>
  <div class="grid">
    <section>
      <h2>Warnings And Limits</h2>
      <ul>
{warning_items}
      </ul>
    </section>
    <section>
      <h2>Parsed Observations</h2>
      <ul>
{observation_items}
      </ul>
    </section>
  </div>
  <section style="margin-top:20px">
    <h2>Graph JSON</h2>
    <pre>{esc(graph_json)}</pre>
  </section>
</main>
</body>
</html>
"""


def write_outputs(graph: dict[str, Any], output_dir: Path, fmt: str) -> list[Path]:
    source = graph.get("source", {})
    stem = safe_slug(f"topology-map-{source.get('cluster')}-{source.get('node')}-{source.get('run_id')}")
    output_dir.mkdir(parents=True, exist_ok=True)
    svg = render_svg(graph)
    written: list[Path] = []
    graph_path = output_dir / f"{stem}.json"
    graph_path.write_text(json.dumps(graph, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    written.append(graph_path)
    if fmt in {"svg", "both"}:
        svg_path = output_dir / f"{stem}.svg"
        svg_path.write_text(svg, encoding="utf-8")
        written.append(svg_path)
    if fmt in {"html", "both"}:
        html_path = output_dir / f"{stem}.html"
        html_path.write_text(render_html(graph, svg), encoding="utf-8")
        written.append(html_path)
    return written


def main() -> int:
    args = build_parser().parse_args()
    summary_path = load_summary_path(args)
    graph = topology_graph.build_graph(summary_path, Path(args.results_root))
    for path in write_outputs(graph, Path(args.output_dir), args.format):
        print(f"Wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
