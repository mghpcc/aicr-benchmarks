#!/usr/bin/env python3
"""Build a report-only topology graph from AICR GPU topology evidence."""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import topology_intelligence


SCHEMA = "aicr.topology_graph.v1"
GPU_AFFINITY = "0:1:2:3:4:5:6:7"
CPU_AFFINITY = "16-31:32-47:48-63:0-15:80-95:96-111:112-127:64-79"
MEM_AFFINITY = "1:2:3:0:5:6:7:4"
UCX_AFFINITY = {
    "b200": "mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_6:mlx5_11",
    "rtxpro6000": "mlx5_0:mlx5_0:mlx5_0:mlx5_0:mlx5_3:mlx5_3:mlx5_3:mlx5_3",
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def natural_gpu_key(value: str) -> int:
    match = re.search(r"GPU(\d+)$", str(value))
    if match:
        return int(match.group(1))
    return 10_000


def artifact_path(summary_path: Path, relpath: str | None, results_root: Path | None = None) -> Path | None:
    if not relpath:
        return None
    path = Path(relpath)
    candidates = [path] if path.is_absolute() else []
    if results_root is not None:
        candidates.append(results_root / relpath)
        candidates.append(results_root.parent / relpath)
    candidates.append(summary_path.parent / relpath)
    candidates.append(Path.cwd() / relpath)
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0] if candidates else None


def read_text(path: Path | None) -> str:
    if path is None or not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def normalize_cells(raw_line: str) -> list[str]:
    if "\t" in raw_line:
        return [cell.strip() for cell in raw_line.split("\t")]
    return raw_line.split()


def parse_topology_matrix(text: str) -> dict[str, Any]:
    header: list[str] = []
    rows: dict[str, dict[str, str]] = {}
    nic_legend: dict[str, str] = {}
    in_legend = False

    for raw_line in topology_intelligence.strip_ansi(text).splitlines():
        if not raw_line.strip():
            continue
        cells = normalize_cells(raw_line)
        if cells and cells[0] == "" and any(cell.startswith("GPU") for cell in cells):
            header = cells[1:]
            continue
        row_name = cells[0] if cells else ""
        if header and re.match(r"^(GPU|NIC)\d+$", row_name):
            values = topology_intelligence.normalize_topology_row_values(header, cells[1:])
            rows[row_name] = dict(zip(header, values))
            continue
        if raw_line.startswith("NIC Legend:"):
            in_legend = True
            continue
        if in_legend:
            match = re.match(r"\s+(NIC\d+):\s+(mlx5_\d+)\s*$", raw_line)
            if match:
                nic_legend[match.group(1)] = match.group(2)

    gpu_links: list[dict[str, str]] = []
    gpu_names = sorted([name for name in rows if name.startswith("GPU")], key=natural_gpu_key)
    seen_pairs: set[tuple[str, str]] = set()
    for left in gpu_names:
        for right in gpu_names:
            if left == right:
                continue
            pair = tuple(sorted((left, right), key=natural_gpu_key))
            if pair in seen_pairs:
                continue
            link = rows.get(left, {}).get(right, "")
            if link:
                gpu_links.append({"source": pair[0], "target": pair[1], "link": link})
                seen_pairs.add(pair)

    return {"rows": rows, "nic_legend": nic_legend, "gpu_links": gpu_links}


def split_affinity(value: str | None) -> list[str]:
    if not value:
        return []
    return [item for item in str(value).split(":") if item != ""]


def derived_affinity(cluster: str) -> dict[str, Any]:
    cpu = split_affinity(CPU_AFFINITY)
    mem = split_affinity(MEM_AFFINITY)
    gpu = split_affinity(GPU_AFFINITY)
    ucx = split_affinity(UCX_AFFINITY.get(cluster, ""))
    ranks = []
    for index, gpu_id in enumerate(gpu):
        ranks.append({
            "rank": index,
            "gpu": f"GPU{gpu_id}",
            "cpu": cpu[index] if index < len(cpu) else "",
            "memory": mem[index] if index < len(mem) else "",
            "ucx": ucx[index] if index < len(ucx) else "",
        })
    return {
        "policy": "reviewed-derived-nps4",
        "report_only": True,
        "gpu_affinity": GPU_AFFINITY,
        "cpu_affinity": CPU_AFFINITY,
        "mem_affinity": MEM_AFFINITY,
        "ucx_affinity": UCX_AFFINITY.get(cluster, ""),
        "ranks": ranks,
    }


def graph_nodes(summary: dict[str, Any]) -> list[dict[str, Any]]:
    nodes: list[dict[str, Any]] = []
    numa_cpu = summary.get("lscpu_numa_cpu_affinity") or {}
    sockets = summary.get("lscpu_socket_count")
    if sockets not in (None, ""):
        try:
            socket_count = int(sockets)
        except (TypeError, ValueError):
            socket_count = 0
        for socket_id in range(socket_count):
            nodes.append({"id": f"socket{socket_id}", "type": "cpu_socket", "label": f"Socket {socket_id}"})

    for numa_id, cpus in sorted(numa_cpu.items(), key=lambda item: int(item[0])):
        nodes.append({
            "id": f"numa{numa_id}",
            "type": "numa_domain",
            "label": f"NUMA {numa_id}",
            "cpu_range": cpus,
        })

    gpu_models = summary.get("gpu_models") or []
    gpu_model = summary.get("gpu_model_summary") or (gpu_models[0] if gpu_models else "")
    for gpu in sorted((summary.get("gpu_numa_affinity") or {}).keys(), key=natural_gpu_key):
        nodes.append({
            "id": gpu,
            "type": "gpu",
            "label": gpu,
            "model": gpu_model,
            "numa": (summary.get("gpu_numa_affinity") or {}).get(gpu, ""),
            "cpu_affinity": (summary.get("gpu_cpu_affinity") or {}).get(gpu, ""),
        })

    nic_devices = set((summary.get("nic_numa_affinity") or {}).keys())
    nic_devices.update((summary.get("ib_device_numa_affinity") or {}).keys())
    for nic in sorted(nic_devices, key=topology_intelligence.natural_mlx5_key):
        nodes.append({
            "id": nic,
            "type": "nic",
            "label": nic,
            "numa": (summary.get("ib_device_numa_affinity") or {}).get(nic, (summary.get("nic_numa_affinity") or {}).get(nic, "")),
            "cpu_affinity": (summary.get("ib_device_cpu_affinity") or {}).get(nic, (summary.get("nic_cpu_affinity") or {}).get(nic, "")),
            "netdevs": (summary.get("ib_device_netdevs") or {}).get(nic, []),
        })

    return nodes


def graph_edges(summary: dict[str, Any], topo_matrix: dict[str, Any]) -> list[dict[str, Any]]:
    edges: list[dict[str, Any]] = []
    for numa_id, cpus in sorted((summary.get("lscpu_numa_cpu_affinity") or {}).items(), key=lambda item: int(item[0])):
        edges.append({"source": f"numa{numa_id}", "target": f"cpus:{cpus}", "type": "contains_cpu_range"})

    for gpu, numa in sorted((summary.get("gpu_numa_affinity") or {}).items(), key=lambda item: natural_gpu_key(item[0])):
        if numa not in (None, ""):
            edges.append({"source": gpu, "target": f"numa{numa}", "type": "gpu_numa_locality"})
    for nic, numa in sorted((summary.get("ib_device_numa_affinity") or {}).items(), key=lambda item: topology_intelligence.natural_mlx5_key(item[0])):
        if numa not in (None, ""):
            edges.append({"source": nic, "target": f"numa{numa}", "type": "nic_numa_locality"})

    for item in topo_matrix.get("gpu_links", []):
        edges.append({"source": item["source"], "target": item["target"], "type": "gpu_gpu_link", "link": item["link"]})

    for gpu, nearest in sorted((summary.get("gpu_nearest_nics") or {}).items(), key=lambda item: natural_gpu_key(item[0])):
        link = nearest.get("link", "")
        for nic in nearest.get("nics") or []:
            edges.append({"source": gpu, "target": nic, "type": "gpu_nic_nearest", "link": link})
    for gpu, nics in sorted((summary.get("gpu_pix_nics") or {}).items(), key=lambda item: natural_gpu_key(item[0])):
        for nic in nics or []:
            edges.append({"source": gpu, "target": nic, "type": "gpu_nic_pix", "link": "PIX"})

    for rank in derived_affinity(summary.get("cluster", "")).get("ranks", []):
        edges.append({
            "source": f"rank{rank['rank']}",
            "target": rank["gpu"],
            "type": "derived_rank_gpu_binding",
            "policy": "reviewed-derived-nps4",
        })
    return edges


def evidence_paths(summary_path: Path, summary: dict[str, Any], results_root: Path | None) -> dict[str, str]:
    keys = {
        "summary": str(summary_path),
        "nvidia_smi_l": summary.get("nvidia_smi_l_file") or "",
        "nvidia_smi_topo": summary.get("nvidia_smi_topo_file") or "",
        "lscpu": summary.get("lscpu_file") or "",
        "mlx5_topology": summary.get("mlx5_topology_file") or "",
        "storage_topology": summary.get("storage_topology_file") or "",
    }
    resolved: dict[str, str] = {"summary": str(summary_path)}
    for key, relpath in keys.items():
        if key == "summary":
            continue
        path = artifact_path(summary_path, relpath, results_root)
        resolved[key] = str(path) if path else ""
    return resolved


def graph_warnings(summary: dict[str, Any], paths: dict[str, str]) -> list[str]:
    warnings: list[str] = []
    if summary.get("status") != "passed":
        warnings.append(f"topology summary status is {summary.get('status') or 'missing'}")
    for key in ("nvidia_smi_topo", "lscpu", "mlx5_topology"):
        path = paths.get(key)
        if not path or not Path(path).exists():
            warnings.append(f"{key} raw artifact is unavailable; using parsed summary fields only")
    for nic in sorted((summary.get("nic_numa_affinity") or {}).keys(), key=topology_intelligence.natural_mlx5_key):
        if str(nic).startswith("NIC"):
            warnings.append(f"{nic} was not resolved to an mlx5 device in NIC legend")
    for gpu, nearest in sorted((summary.get("gpu_nearest_nics") or {}).items(), key=lambda item: natural_gpu_key(item[0])):
        nics = nearest.get("nics") or []
        if len(nics) > 1 and nearest.get("link") == "SYS":
            warnings.append(f"{gpu} has multiple SYS-nearest NICs; UCX placement remains policy-derived")
    if summary.get("lscpu_numa_node_count") not in (8, "8"):
        warnings.append(f"expected NPS4-style 8 NUMA domains for current AICR maps, found {summary.get('lscpu_numa_node_count') or '-'}")
    return warnings


def build_graph(summary_path: Path, results_root: Path | None = None) -> dict[str, Any]:
    summary = load_json(summary_path)
    paths = evidence_paths(summary_path, summary, results_root)
    topo_path = Path(paths["nvidia_smi_topo"]) if paths.get("nvidia_smi_topo") else None
    topo_matrix = parse_topology_matrix(read_text(topo_path))
    cluster = summary.get("cluster", "")
    return {
        "schema": SCHEMA,
        "schema_version": 1,
        "source": {
            "cluster": cluster,
            "node": summary.get("host") or summary.get("node") or "",
            "date": summary.get("date") or "",
            "run_id": summary.get("run_id") or "",
            "summary_path": str(summary_path),
            "artifact_paths": paths,
            "evidence_complete": all(Path(paths[key]).exists() for key in ("nvidia_smi_topo", "lscpu", "mlx5_topology") if paths.get(key)),
            "topology_profile_status": summary.get("topology_profile_status") or "",
            "topology_profile_notes": summary.get("topology_profile_notes") or "",
            "topology_signature": summary.get("topology_signature") or "",
        },
        "nodes": graph_nodes(summary),
        "edges": graph_edges(summary, topo_matrix),
        "derived_affinity": derived_affinity(cluster),
        "warnings": graph_warnings(summary, paths),
        "summary": {
            "gpu_count": summary.get("gpu_count"),
            "gpu_model_summary": summary.get("gpu_model_summary") or "",
            "lscpu_numa_node_count": summary.get("lscpu_numa_node_count"),
            "topology_observations": summary.get("topology_observations") or [],
        },
    }

