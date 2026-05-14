#!/usr/bin/env python3
import argparse
import json
import math
import os
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "parse"))
import topology_intelligence

from repeat_aggregation import aggregate_values, normalize_repeat_aggregation


GDS_DETAIL_PHASES = (
    "platform",
    "sequential-write",
    "sequential-read",
    "random-write",
    "random-read",
    "async-stream-write",
    "async-stream-read",
    "cpu-gpu-read",
)
STATS_DOCS_PATH = "docs/stats-explained.md"


def repo_root():
    return Path(__file__).resolve().parents[2]


def stats_docs_link(output_path=None):
    if not output_path:
        return STATS_DOCS_PATH
    base = Path(output_path)
    base_dir = base.parent if base.suffix else base
    try:
        return os.path.relpath(repo_root() / STATS_DOCS_PATH, base_dir.resolve()).replace(os.sep, "/")
    except OSError:
        return STATS_DOCS_PATH


def build_parser():
    p = argparse.ArgumentParser(description="Render verify dashboards from canonical AICR artifacts.")
    p.add_argument("--results-root", default="results")
    p.add_argument("--date", required=True, help="ISO date for day dashboard, e.g. 2026-04-21")
    p.add_argument("--cluster", required=True, choices=["rtxpro6000", "b200"])
    p.add_argument("--check", default="gds", choices=["gds", "gpu-topology", "nccl-local", "nccl-rdma"])
    p.add_argument("--node")
    p.add_argument("--ascii", action="store_true")
    p.add_argument("--markdown", action="store_true")
    p.add_argument("--both", action="store_true")
    p.add_argument("--write", action="store_true")
    p.add_argument("--fleet-manifest")
    p.add_argument("--nodes-per-job", type=int, choices=[2, 4, 8, 16], help="Filter NCCL RDMA summaries by node group size.")
    p.add_argument("--no-stats", action="store_true", help="Suppress GDS/NCCL statistics and anomaly sections.")
    return p


def load_json(path):
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def load_manifest(path):
    if not path:
        return {}
    manifest_path = Path(path)
    if not manifest_path.exists():
        return {}
    return load_json(manifest_path)


def latest_summaries(results_root, date, cluster, check, node=None):
    if check == "nccl-rdma":
        root = results_root / "by-date" / date / "parsed" / cluster / "multi-node" / check
        if not root.exists():
            return []
        summaries = []
        for run_dir in sorted(p for p in root.iterdir() if p.is_dir()):
            summary = run_dir / "summary.json"
            if summary.exists():
                summaries.append(summary)
        return summaries

    root = results_root / "by-date" / date / "parsed" / cluster / "nodes"
    if not root.exists():
        return []

    summaries = []
    node_dirs = [root / node] if node else sorted(p for p in root.iterdir() if p.is_dir())
    for node_dir in node_dirs:
        check_dir = node_dir / check
        if not check_dir.exists():
            continue
        runs = sorted(p for p in check_dir.iterdir() if p.is_dir())
        if not runs:
            continue
        latest = runs[-1] / "summary.json"
        if latest.exists():
            summaries.append(latest)
    return summaries


def manifest_repeat_count(manifest):
    try:
        return int(manifest.get("repeat_count", 1) or 1)
    except (TypeError, ValueError):
        return 1


def manifest_repeat_aggregation(manifest):
    try:
        return normalize_repeat_aggregation((manifest or {}).get("repeat_aggregation"))
    except ValueError:
        return "standard"


def repeat_center_label(aggregation):
    return "Olympic avg" if aggregation == "olympic" else "Median"


def repeat_center_suffix(aggregation):
    return "olympic avg" if aggregation == "olympic" else "med"


def fmt_dropped(summary):
    if not summary.get("olympic_available"):
        return "-"
    return f"{fmt_stat(summary.get('dropped_low'))}/{fmt_stat(summary.get('dropped_high'))}"


def aggregation_notes(summaries):
    notes = []
    for label, summary in summaries:
        note = summary.get("note") or ""
        if summary.get("fallback_used"):
            notes.append(f"{label}: {note}")
    return "; ".join(notes) if notes else "-"


def iter_manifest_jobs(manifest):
    jobs = manifest.get("submitted_jobs") or []
    if jobs:
        for item in jobs:
            yield item
        return
    for round_item in manifest.get("rounds") or []:
        for item in round_item.get("submitted_jobs") or []:
            merged = dict(item)
            merged.setdefault("round", round_item.get("round"))
            yield merged


def resolve_results_path(results_root, relpath):
    if not relpath:
        return None
    path = Path(relpath)
    candidates = [path] if path.is_absolute() else [
        results_root.parent / path,
        results_root / path,
        Path.cwd() / path,
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0] if candidates else None


def index_rows_by_job(results_root, date, cluster, check):
    index_path = results_root / "by-date" / date / "index.jsonl"
    rows = {}
    if not index_path.exists():
        return rows
    with index_path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                continue
            if item.get("cluster") != cluster or item.get("check") != check:
                continue
            job_id = str(item.get("job_id") or "")
            if job_id:
                rows[job_id] = item
    return rows


def summary_paths_from_manifest(results_root, date, cluster, check, manifest, nodes_per_job=None):
    if not manifest:
        return []
    by_job = index_rows_by_job(results_root, date, cluster, check)
    paths = []
    seen = set()
    for job in iter_manifest_jobs(manifest):
        job_id = str(job.get("job_id") or "")
        item = by_job.get(job_id)
        if not item:
            continue
        if check == "nccl-rdma" and nodes_per_job is not None:
            try:
                if int(item.get("node_count")) != int(nodes_per_job):
                    continue
            except (TypeError, ValueError):
                pass
        for relpath in item.get("parsed_artifact_paths") or []:
            if not str(relpath).endswith("summary.json"):
                continue
            path = resolve_results_path(results_root, relpath)
            if path and path.exists() and path not in seen:
                paths.append(path)
                seen.add(path)
    return paths


def sample_context_by_run_id(results_root, date, cluster, check, manifest):
    if not manifest:
        return {}
    by_job = index_rows_by_job(results_root, date, cluster, check)
    context = {}
    for job in iter_manifest_jobs(manifest):
        job_id = str(job.get("job_id") or "")
        item = by_job.get(job_id)
        if not item:
            continue
        run_id = item.get("run_id")
        if not run_id:
            continue
        merged = dict(job)
        merged.update({
            "job_id": job_id,
            "run_id": run_id,
            "index_status": item.get("status"),
            "record_path": item.get("record_path"),
        })
        context[run_id] = merged
    return context


def fmt_float(value):
    if value is None:
        return "-"
    try:
        return f"{float(value):.3f}"
    except (TypeError, ValueError):
        return "-"


def fmt_stat(value):
    if value is None:
        return "-"
    try:
        value = float(value)
    except (TypeError, ValueError):
        return "-"
    if math.isnan(value) or math.isinf(value):
        return "-"
    return f"{value:.3f}"


def fmt_pct(value):
    if value is None:
        return "-"
    try:
        value = float(value)
    except (TypeError, ValueError):
        return "-"
    if math.isnan(value) or math.isinf(value):
        return "-"
    return f"{value:.1f}%"


def parse_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def profile_status(summary, prefix):
    explicit_key = f"{prefix}_status"
    if explicit_key in summary:
        return summary.get(explicit_key) or "-"
    profiles = summary.get("profiles", {})
    return (profiles.get(prefix.replace("_", "-"), {}) or {}).get("status") or "-"


def phase_status(summary, phase):
    phases = summary.get("phases") or {}
    if phases:
        return (phases.get(phase) or {}).get("status") or "-"
    legacy_map = {
        "platform": "platform",
        "sequential-write": "throughput_write",
        "sequential-read": "throughput_read",
    }
    legacy = legacy_map.get(phase)
    if legacy:
        return profile_status(summary, legacy)
    return "-"


def phase_metric(summary, phase, field):
    phases = summary.get("phases") or {}
    item = phases.get(phase) or {}
    return fmt_float(item.get(field))


def phase_pair(left, right):
    if left == "-" and right == "-":
        return "-"
    return f"{left}/{right}"


def gds_phase_details(summary):
    phases = summary.get("phases") or {}
    details = []
    for phase in GDS_DETAIL_PHASES:
        item = phases.get(phase)
        if not item:
            continue
        details.append({
            "phase": phase,
            "status": item.get("status") or "-",
            "throughput_gib_s": fmt_float(item.get("throughput_gib_s")),
            "avg_latency_usecs": fmt_float(item.get("avg_latency_usecs")),
            "ops": item.get("ops") if item.get("ops") is not None else "-",
            "total_time_s": fmt_float(item.get("total_time_s")),
            "note": item.get("note") or "",
        })
    return details


def discovery_state_from_manifest(manifest):
    discovered_state = {}
    for node in manifest.get("idle_nodes", []):
        discovered_state[node] = "idle"
    for item in manifest.get("submitted_jobs", []):
        node = item.get("node")
        if node:
            discovered_state[node] = "idle"
    return discovered_state


def append_missing_and_skipped_rows(rows, manifest, row_factory):
    by_node = {row["node"]: row for row in rows}
    discovered_state = discovery_state_from_manifest(manifest)

    for item in manifest.get("submitted_jobs", []):
        node = item.get("node")
        if node and node in by_node:
            by_node[node]["job_id"] = item.get("job_id") or "-"
        elif node:
            row = row_factory(
                node=node,
                discovery_state=discovered_state.get(node, "idle"),
                job_id=item.get("job_id") or "-",
                status="missing",
            )
            rows.append(row)
            by_node[node] = row

    skipped = manifest.get("skipped_nodes_by_state", {}) or {}
    for state, nodes in sorted(skipped.items()):
        for node in nodes:
            if node in by_node:
                continue
            rows.append(row_factory(
                node=node,
                discovery_state=state,
                job_id="-",
                status="skipped",
            ))

    return rows


def empty_gds_row(node, discovery_state, job_id, status):
    return {
        "node": node,
        "discovery_state": discovery_state,
        "job_id": job_id,
        "run_id": "-",
        "profile": "-",
        "status": status,
        "platform_status": "-",
        "throughput_read_status": "-",
        "throughput_write_status": "-",
        "sequential_status_pair": "-",
        "random_status_pair": "-",
        "extra_phase_statuses": "-",
        "throughput_read_throughput_gib_s": "-",
        "throughput_write_throughput_gib_s": "-",
        "random_read_throughput_gib_s": "-",
        "random_write_throughput_gib_s": "-",
        "phase_details": [],
        "notes": "",
    }


def gds_rows_from_summaries(paths, manifest):
    rows = []
    discovered_state = discovery_state_from_manifest(manifest)

    for path in paths:
        summary = load_json(path)
        node = summary.get("host") or path.parts[-4]
        sequential_write_status = phase_status(summary, "sequential-write")
        sequential_read_status = phase_status(summary, "sequential-read")
        random_write_status = phase_status(summary, "random-write")
        random_read_status = phase_status(summary, "random-read")
        async_write_status = phase_status(summary, "async-stream-write")
        async_read_status = phase_status(summary, "async-stream-read")
        cpu_gpu_read_status = phase_status(summary, "cpu-gpu-read")
        extra_statuses = []
        if async_write_status != "-" or async_read_status != "-":
            extra_statuses.append(f"async {phase_pair(async_write_status, async_read_status)}")
        if cpu_gpu_read_status != "-":
            extra_statuses.append(f"cpu {cpu_gpu_read_status}")
        rows.append({
            "node": node,
            "cluster": summary.get("cluster", "-"),
            "discovery_state": discovered_state.get(node, "-"),
            "job_id": "-",
            "run_id": summary.get("run_id") or "-",
            "profile": summary.get("profile") or "-",
            "status": summary.get("status") or "-",
            "platform_status": phase_status(summary, "platform"),
            "throughput_read_status": profile_status(summary, "throughput_read"),
            "throughput_write_status": profile_status(summary, "throughput_write"),
            "sequential_status_pair": phase_pair(sequential_write_status, sequential_read_status),
            "random_status_pair": phase_pair(random_write_status, random_read_status),
            "extra_phase_statuses": "; ".join(extra_statuses) if extra_statuses else "-",
            "throughput_read_throughput_gib_s": fmt_float(summary.get("throughput_read_throughput_gib_s")),
            "throughput_write_throughput_gib_s": fmt_float(summary.get("throughput_write_throughput_gib_s")),
            "random_read_throughput_gib_s": phase_metric(summary, "random-read", "throughput_gib_s"),
            "random_write_throughput_gib_s": phase_metric(summary, "random-write", "throughput_gib_s"),
            "phase_details": gds_phase_details(summary),
            "notes": summary.get("notes") or "",
        })

    rows = append_missing_and_skipped_rows(rows, manifest, empty_gds_row)

    return sorted(rows, key=lambda r: r["node"])


GDS_PRIMARY_METRICS = (
    ("throughput_read_throughput_gib_s", "Sequential Read GiB/s"),
    ("throughput_write_throughput_gib_s", "Sequential Write GiB/s"),
)

GDS_OPTIONAL_METRICS = (
    ("random_read_throughput_gib_s", "Random Read GiB/s"),
    ("random_write_throughput_gib_s", "Random Write GiB/s"),
)

GDS_METRICS = GDS_PRIMARY_METRICS + GDS_OPTIONAL_METRICS


def percentile(values, pct):
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    rank = (len(ordered) - 1) * (pct / 100)
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return ordered[int(rank)]
    return ordered[lower] * (upper - rank) + ordered[upper] * (rank - lower)


def median_absolute_deviation(values, med):
    if not values:
        return None
    return statistics.median(abs(value - med) for value in values)


def stats_for_values(values):
    if not values:
        return None
    med = statistics.median(values)
    mad = median_absolute_deviation(values, med)
    avg = statistics.mean(values)
    sample_stddev = statistics.stdev(values) if len(values) > 1 else 0.0
    return {
        "n": len(values),
        "mean": avg,
        "median": med,
        "stddev": sample_stddev,
        "min": min(values),
        "p10": percentile(values, 10),
        "p25": percentile(values, 25),
        "p75": percentile(values, 75),
        "p90": percentile(values, 90),
        "max": max(values),
        "mad": mad,
        "cv": (sample_stddev / avg) if avg else None,
    }


def robust_z(value, med, mad):
    if mad in (None, 0):
        return None
    return 0.6745 * (value - med) / mad


def classify_low_anomaly(value, stats):
    if not stats:
        return None
    med = stats["median"]
    rz = robust_z(value, med, stats["mad"])
    below_median = ((med - value) / med) if med else 0.0

    if below_median >= 0.30 or (below_median >= 0.20 and rz is not None and rz <= -6.0):
        return "severe_low"
    if below_median >= 0.10 and (rz is not None and rz <= -3.5):
        return "warning_low"
    if value <= stats["p10"] and below_median > 0:
        return "low_tail"
    return None


def classify_high_anomaly(value, stats):
    if not stats:
        return None
    med = stats["median"]
    rz = robust_z(value, med, stats["mad"])
    above_median = ((value - med) / med) if med else 0.0
    if above_median >= 0.30 or (rz is not None and rz >= 6.0):
        return "high_info"
    return None


def gds_numeric_rows(rows, metrics=GDS_PRIMARY_METRICS):
    numeric = []
    for row in rows:
        if row.get("status") != "passed" and not (row.get("repeat_campaign") and row.get("status") == "degraded"):
            continue
        item = {"node": row.get("node", "-")}
        ok = True
        for key, _ in metrics:
            value = parse_float(row.get(key))
            if value is None:
                ok = False
                break
            item[key] = value
        if ok:
            numeric.append(item)
    return numeric


def gds_metric_rows(rows, key):
    numeric = []
    for row in rows:
        if row.get("status") != "passed" and not (row.get("repeat_campaign") and row.get("status") == "degraded"):
            continue
        value = parse_float(row.get(key))
        if value is None:
            continue
        numeric.append({"node": row.get("node", "-"), key: value})
    return numeric


def build_gds_stats(rows):
    numeric = gds_numeric_rows(rows, GDS_PRIMARY_METRICS)
    numeric_nodes = {row["node"] for row in numeric}
    stats = {}
    anomalies = []
    for key, label in GDS_METRICS:
        metric_rows = gds_metric_rows(rows, key)
        metric_values = [row[key] for row in metric_rows]
        metric_stats = stats_for_values(metric_values)
        if not metric_stats:
            continue
        stats[key] = {"label": label, **metric_stats}
        for row in metric_rows:
            value = row[key]
            low_severity = classify_low_anomaly(value, metric_stats)
            high_severity = classify_high_anomaly(value, metric_stats)
            severity = low_severity or high_severity
            if not severity:
                continue
            med = metric_stats["median"]
            delta_pct = ((value - med) / med * 100) if med else None
            anomalies.append({
                "node": row["node"],
                "metric": label,
                "value": value,
                "median": med,
                "delta_pct": delta_pct,
                "robust_z": robust_z(value, med, metric_stats["mad"]),
                "severity": severity,
            })
    severity_order = {"severe_low": 0, "warning_low": 1, "low_tail": 2, "high_info": 3}
    anomalies.sort(key=lambda item: (severity_order.get(item["severity"], 99), item["metric"], item["node"]))
    operational = []
    for row in rows:
        status = row.get("status")
        if status in {"missing", "skipped"} or status != "passed":
            operational.append(row)
        elif row.get("node") not in numeric_nodes:
            incomplete = dict(row)
            incomplete["status"] = "incomplete"
            operational.append(incomplete)
    return stats, anomalies, operational


def empty_topology_row(node, discovery_state, job_id, status):
    return {
        "node": node,
        "discovery_state": discovery_state,
        "job_id": job_id,
        "run_id": "-",
        "status": status,
        "gpu_count": "-",
        "expected_gpu_count": "-",
        "gpu_model_summary": "-",
        "gpu_count_status": "-",
        "gpu_model_status": "-",
        "nvidia_smi_topo_status": "-",
        "lscpu_status": "-",
        "topology_profile_status": "-",
        "topology_profile_notes": "",
        "topology_signature": "",
        "gpu_cpu_affinity": {},
        "gpu_numa_affinity": {},
        "gpu_pix_nics": {},
        "gpu_nearest_nics": {},
        "nic_cpu_affinity": {},
        "nic_numa_affinity": {},
        "ib_device_cpu_affinity": {},
        "ib_device_numa_affinity": {},
        "gds_storage_source": "",
        "gds_storage_fstype": "",
        "gds_storage_route_dev": "",
        "gds_storage_route_mlx5": "",
        "lscpu_numa_node_count": "-",
        "lscpu_numa_cpu_affinity": {},
        "topology_observations": [],
        "notes": "",
    }


def resolve_artifact_path(results_root, artifact_path):
    if not artifact_path:
        return None
    path = Path(artifact_path)
    candidates = []
    if path.is_absolute():
        candidates.append(path)
    else:
        candidates.extend([
            results_root / path,
            results_root.parent / path,
            Path.cwd() / path,
        ])
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0] if candidates else None


def enrich_topology_summary(summary, results_root):
    if summary.get("topology_signature"):
        return summary
    topo_path = resolve_artifact_path(results_root, summary.get("nvidia_smi_topo_file", ""))
    lscpu_path = resolve_artifact_path(results_root, summary.get("lscpu_file", ""))
    mlx5_path = resolve_artifact_path(results_root, summary.get("mlx5_topology_file", ""))
    storage_path = resolve_artifact_path(results_root, summary.get("storage_topology_file", ""))
    if not topo_path or not lscpu_path:
        return summary
    fields = topology_intelligence.topology_intelligence_from_files(
        topo_path,
        lscpu_path,
        summary.get("cluster", ""),
        storage_path=storage_path,
        mlx5_path=mlx5_path,
    )
    enriched = dict(summary)
    enriched.update(fields)
    return enriched


def topology_rows_from_summaries(paths, manifest, results_root):
    rows = []
    discovered_state = discovery_state_from_manifest(manifest)

    for path in paths:
        summary = enrich_topology_summary(load_json(path), results_root)
        node = summary.get("host") or path.parts[-4]
        rows.append({
            "node": node,
            "discovery_state": discovered_state.get(node, "-"),
            "job_id": "-",
            "run_id": summary.get("run_id") or "-",
            "status": summary.get("status") or "-",
            "gpu_count": summary.get("gpu_count", "-"),
            "expected_gpu_count": summary.get("expected_gpu_count", "-"),
            "gpu_model_summary": summary.get("gpu_model_summary") or "-",
            "gpu_count_status": summary.get("gpu_count_status") or "-",
            "gpu_model_status": summary.get("gpu_model_status") or "-",
            "nvidia_smi_topo_status": summary.get("nvidia_smi_topo_status") or "-",
            "lscpu_status": summary.get("lscpu_status") or "-",
            "topology_profile_status": summary.get("topology_profile_status") or "-",
            "topology_profile_notes": summary.get("topology_profile_notes") or "",
            "topology_signature": summary.get("topology_signature") or "",
            "gpu_cpu_affinity": summary.get("gpu_cpu_affinity") or {},
            "gpu_numa_affinity": summary.get("gpu_numa_affinity") or {},
            "gpu_pix_nics": summary.get("gpu_pix_nics") or {},
            "gpu_nearest_nics": summary.get("gpu_nearest_nics") or {},
            "nic_cpu_affinity": summary.get("nic_cpu_affinity") or {},
            "nic_numa_affinity": summary.get("nic_numa_affinity") or {},
            "ib_device_cpu_affinity": summary.get("ib_device_cpu_affinity") or {},
            "ib_device_numa_affinity": summary.get("ib_device_numa_affinity") or {},
            "gds_storage_source": summary.get("gds_storage_source") or "",
            "gds_storage_fstype": summary.get("gds_storage_fstype") or "",
            "gds_storage_route_dev": summary.get("gds_storage_route_dev") or "",
            "gds_storage_route_mlx5": summary.get("gds_storage_route_mlx5") or "",
            "lscpu_numa_node_count": summary.get("lscpu_numa_node_count", "-"),
            "lscpu_numa_cpu_affinity": summary.get("lscpu_numa_cpu_affinity") or {},
            "topology_observations": summary.get("topology_observations") or [],
            "notes": summary.get("notes") or "",
        })

    rows = append_missing_and_skipped_rows(rows, manifest, empty_topology_row)
    return sorted(rows, key=lambda r: r["node"])


NCCL_TESTS = (
    ("all_reduce_perf", "AR"),
    ("reduce_scatter_perf", "RS"),
    ("all_gather_perf", "AG"),
    ("alltoall_perf", "A2A"),
)

NCCL_METRICS = tuple((f"{test_name}_busbw", f"{label} busbw (GB/s)") for test_name, label in NCCL_TESTS)
ANOMALY_MIN_ABS_DELTA_PCT = 1.0


def nccl_test_busbw(summary, test_name):
    item = (summary.get("tests") or {}).get(test_name) or {}
    return fmt_float(item.get("largest_message_busbw"))


def nccl_tests_passed(summary):
    passed = summary.get("tests_passed")
    total = summary.get("tests_total")
    if passed is None or total is None:
        tests = summary.get("tests") or {}
        total = len(tests)
        passed = sum(1 for item in tests.values() if item.get("status") == "passed")
    return f"{passed}/{total}" if total is not None else "-"


def empty_nccl_local_row(node, discovery_state, job_id, status):
    row = {
        "node": node,
        "discovery_state": discovery_state,
        "job_id": job_id,
        "run_id": "-",
        "status": status,
        "tests_passed": "-",
        "wrong_count": "-",
        "notes": "",
    }
    for test_name, _ in NCCL_TESTS:
        row[f"{test_name}_busbw"] = "-"
    return row


def nccl_local_rows_from_summaries(paths, manifest, sample_context=None):
    rows = []
    sample_context = sample_context or {}
    discovered_state = discovery_state_from_manifest(manifest)
    for path in paths:
        summary = load_json(path)
        node = summary.get("host") or path.parts[-4]
        run_id = summary.get("run_id") or path.parts[-2]
        context = sample_context.get(run_id, {})
        row = {
            "node": node,
            "discovery_state": discovered_state.get(node, "-"),
            "job_id": context.get("job_id") or "-",
            "round": context.get("round"),
            "run_id": run_id,
            "status": summary.get("status") or "-",
            "tests_passed": nccl_tests_passed(summary),
            "wrong_count": summary.get("total_wrong_count", "-"),
            "notes": summary.get("notes") or "",
            "test_details": summary.get("tests") or {},
        }
        for test_name, _ in NCCL_TESTS:
            row[f"{test_name}_busbw"] = nccl_test_busbw(summary, test_name)
        rows.append(row)

    rows = append_missing_and_skipped_rows(rows, manifest, empty_nccl_local_row)
    return sorted(rows, key=lambda r: r["node"])


def node_group_string(value):
    if isinstance(value, list):
        return ",".join(str(item) for item in value if str(item))
    return str(value) if value not in (None, "") else ""


def nodes_from_group(value):
    if isinstance(value, list):
        return [str(item) for item in value if str(item)]
    return [item for item in str(value).split(",") if item] if value not in (None, "") else []


def nccl_rdma_summary_group(summary, path):
    group = (
        summary.get("node_group")
        or summary.get("node_pair")
        or summary.get("peer_nodes_csv")
        or node_group_string(summary.get("peer_nodes", []))
    )
    return group or path.parts[-2]


def nccl_rdma_summary_node_count(summary, group):
    value = summary.get("node_count")
    try:
        return int(value)
    except (TypeError, ValueError):
        return len(nodes_from_group(group)) or "-"


def nccl_rdma_summary_gpu_count(summary, node_count):
    value = summary.get("gpu_count")
    try:
        return int(value)
    except (TypeError, ValueError):
        return node_count * 8 if isinstance(node_count, int) else "-"


def nccl_rdma_job_map(manifest):
    mapping = {}
    for item in manifest.get("submitted_jobs", []):
        group = item.get("group") or item.get("pair")
        if not group and item.get("nodes"):
            group = node_group_string(item.get("nodes") or [])
        if group:
            mapping[group] = item
    return mapping


def nccl_rdma_selected_groups(manifest):
    selected = manifest.get("selected_node_groups")
    if selected is None:
        selected = manifest.get("selected_node_pairs", [])
    return [node_group_string(group) for group in selected if node_group_string(group)]


def empty_nccl_rdma_row(group, job, status):
    nodes = nodes_from_group(group)
    node_count = len(nodes) or job.get("node_count", "-")
    gpu_count = job.get("gpu_count")
    if gpu_count is None:
        gpu_count = node_count * 8 if isinstance(node_count, int) else "-"
    row = {
        "node_group": group,
        "node_count": node_count,
        "gpu_count": gpu_count,
        "job_id": job.get("job_id") or "-",
        "run_id": "-",
        "status": status,
        "tests_passed": "-",
        "wrong_count": "-",
        "notes": "",
    }
    for test_name, _ in NCCL_TESTS:
        row[f"{test_name}_busbw"] = "-"
    return row


def nccl_rdma_rows_from_summaries(paths, manifest, nodes_per_job=None, sample_context=None):
    sample_context = sample_context or {}
    rows = []
    by_group = {}
    jobs = nccl_rdma_job_map(manifest)
    for path in paths:
        summary = load_json(path)
        group = nccl_rdma_summary_group(summary, path)
        node_count = nccl_rdma_summary_node_count(summary, group)
        if nodes_per_job is not None and node_count != nodes_per_job:
            continue
        gpu_count = nccl_rdma_summary_gpu_count(summary, node_count)
        run_id = summary.get("run_id") or path.parts[-2]
        context = sample_context.get(run_id, {})
        job = jobs.get(group, {})
        row = {
            "node_group": group,
            "node_count": node_count,
            "gpu_count": gpu_count,
            "job_id": context.get("job_id") or job.get("job_id") or "-",
            "round": context.get("round"),
            "run_id": run_id,
            "status": summary.get("status") or "-",
            "tests_passed": nccl_tests_passed(summary),
            "wrong_count": summary.get("total_wrong_count", "-"),
            "notes": summary.get("notes") or "",
            "test_details": summary.get("tests") or {},
        }
        for test_name, _ in NCCL_TESTS:
            row[f"{test_name}_busbw"] = nccl_test_busbw(summary, test_name)
        rows.append(row)
        by_group[group] = row

    if manifest_repeat_count(manifest) <= 1:
        rows = list(by_group.values())
    selected_groups = nccl_rdma_selected_groups(manifest)
    for group in selected_groups:
        if group in by_group:
            continue
        node_count = len(nodes_from_group(group))
        if nodes_per_job is not None and node_count != nodes_per_job:
            continue
        job = jobs.get(group, {})
        rows.append(empty_nccl_rdma_row(group, job, "missing" if group in jobs else "selected"))

    return sorted(rows, key=lambda r: r["node_group"])


def fmt_range(values):
    if not values:
        return "-"
    return f"{fmt_stat(min(values))}..{fmt_stat(max(values))}"


def aggregate_status(samples, passes, expected):
    if samples <= 0:
        return "missing"
    if passes == expected and samples == expected:
        return "passed"
    if passes > 0:
        return "degraded"
    return "failed"


def expected_node_counts(manifest):
    counts = {}
    for job in iter_manifest_jobs(manifest):
        node = job.get("node")
        if node:
            counts[node] = counts.get(node, 0) + 1
    if counts:
        return counts
    repeat_count = manifest_repeat_count(manifest)
    return {node: repeat_count for node in manifest.get("idle_nodes", [])}


def expected_rdma_group_counts(manifest):
    counts = {}
    for job in iter_manifest_jobs(manifest):
        group = job.get("group") or job.get("pair")
        if not group and job.get("nodes"):
            group = node_group_string(job.get("nodes") or [])
        if group:
            counts[group] = counts.get(group, 0) + 1
    if counts:
        return counts
    repeat_count = manifest_repeat_count(manifest)
    return {group: repeat_count for group in nccl_rdma_selected_groups(manifest)}


def aggregate_gds_repeat_rows(rows, manifest):
    if manifest_repeat_count(manifest) <= 1:
        return rows

    aggregation = manifest_repeat_aggregation(manifest)
    expected = expected_node_counts(manifest)
    by_node = {}
    skipped = {}
    for row in rows:
        node = row.get("node", "-")
        if row.get("status") == "skipped":
            skipped[node] = row
        else:
            by_node.setdefault(node, []).append(row)

    out = []
    for node in sorted(set(expected) | set(by_node) | set(skipped)):
        if node in skipped and node not in expected and node not in by_node:
            item = dict(skipped[node])
            item["samples"] = "0/0"
            item["passes"] = "0/0"
            item["repeat_campaign"] = True
            out.append(item)
            continue

        node_rows = [row for row in by_node.get(node, []) if row.get("run_id") != "-" or row.get("status") != "missing"]
        sample_count = len(node_rows)
        pass_count = sum(1 for row in node_rows if row.get("status") == "passed")
        expected_count = expected.get(node, manifest_repeat_count(manifest))
        aggregate = {
            "node": node,
            "discovery_state": (node_rows[0].get("discovery_state") if node_rows else skipped.get(node, {}).get("discovery_state", "idle")),
            "job_id": "-",
            "run_id": "-",
            "profile": ",".join(sorted({row.get("profile", "-") for row in node_rows if row.get("profile", "-") != "-"})) or "-",
            "status": aggregate_status(sample_count, pass_count, expected_count),
            "samples": f"{sample_count}/{expected_count}",
            "passes": f"{pass_count}/{expected_count}",
            "aggregation": "olympic" if aggregation == "olympic" else "standard",
            "repeat_campaign": True,
        }
        summaries = []
        for key, label in GDS_METRICS:
            values = [value for value in (parse_float(row.get(key)) for row in node_rows if row.get("status") == "passed") if value is not None]
            summary = aggregate_values(values, aggregation, standard_center="median")
            if values:
                summaries.append((label, summary))
            med = summary.get("median")
            aggregate[key] = fmt_stat(summary.get("center"))
            aggregate[f"{key}_range"] = fmt_range(values)
            aggregate[f"{key}_dropped"] = fmt_dropped(summary)
            aggregate[f"{key}_mad"] = fmt_stat(median_absolute_deviation(values, med)) if med is not None else "-"
        aggregate["aggregation_notes"] = aggregation_notes(summaries)
        out.append(aggregate)

    return sorted(out, key=lambda r: r["node"])


def aggregate_nccl_repeat_rows(rows, manifest, check):
    if manifest_repeat_count(manifest) <= 1:
        return rows

    aggregation = manifest_repeat_aggregation(manifest)
    entity_key = nccl_entity_key(check)
    if check == "nccl-rdma":
        expected = expected_rdma_group_counts(manifest)
    else:
        expected = expected_node_counts(manifest)

    by_entity = {}
    skipped = {}
    for row in rows:
        entity = row.get(entity_key, "-")
        if row.get("status") == "skipped":
            skipped[entity] = row
        else:
            by_entity.setdefault(entity, []).append(row)

    out = []
    for entity in sorted(set(expected) | set(by_entity) | set(skipped)):
        if entity in skipped and entity not in expected and entity not in by_entity:
            item = dict(skipped[entity])
            item["samples"] = "0/0"
            item["passes"] = "0/0"
            item["repeat_campaign"] = True
            out.append(item)
            continue

        entity_rows = [row for row in by_entity.get(entity, []) if row.get("run_id") != "-" or row.get("status") != "missing"]
        sample_count = len(entity_rows)
        pass_count = sum(1 for row in entity_rows if row.get("status") == "passed")
        expected_count = expected.get(entity, manifest_repeat_count(manifest))
        wrong_total = sum((parse_float(row.get("wrong_count")) or 0) for row in entity_rows)
        sample_findings = nccl_repeat_sample_findings(entity_rows, expected_count)
        aggregate = {
            entity_key: entity,
            "job_id": "-",
            "run_id": "-",
            "status": aggregate_status(sample_count, pass_count, expected_count),
            "samples": f"{sample_count}/{expected_count}",
            "passes": f"{pass_count}/{expected_count}",
            "tests_passed": "-",
            "wrong_count": int(wrong_total) if float(wrong_total).is_integer() else fmt_stat(wrong_total),
            "notes": "",
            "sample_findings": sample_findings,
            "aggregation": "olympic" if aggregation == "olympic" else "standard",
            "repeat_campaign": True,
        }
        if check == "nccl-rdma":
            nodes = nodes_from_group(entity)
            aggregate["node_count"] = len(nodes)
            aggregate["gpu_count"] = len(nodes) * 8 if nodes else "-"
        else:
            aggregate["discovery_state"] = entity_rows[0].get("discovery_state") if entity_rows else skipped.get(entity, {}).get("discovery_state", "idle")
        summaries = []
        for key, label in NCCL_METRICS:
            values = [value for value in (parse_float(row.get(key)) for row in entity_rows if row.get("status") == "passed") if value is not None]
            summary = aggregate_values(values, aggregation, standard_center="median")
            if values:
                summaries.append((label, summary))
            med = summary.get("median")
            aggregate[key] = fmt_stat(summary.get("center"))
            aggregate[f"{key}_range"] = fmt_range(values)
            aggregate[f"{key}_dropped"] = fmt_dropped(summary)
            aggregate[f"{key}_mad"] = fmt_stat(median_absolute_deviation(values, med)) if med is not None else "-"
        aggregate["aggregation_notes"] = aggregation_notes(summaries)
        out.append(aggregate)

    return sorted(out, key=lambda r: r[entity_key])


def nccl_test_label(test_name):
    for name, label in NCCL_TESTS:
        if name == test_name:
            return label
    return test_name


def nccl_repeat_sample_findings(sample_rows, expected_count):
    findings = []
    sample_count = len(sample_rows)
    if sample_count < expected_count:
        findings.append(f"incomplete samples {sample_count}/{expected_count}")

    for row in sorted(sample_rows, key=lambda item: (item.get("round") or 0, item.get("run_id", ""))):
        row_status = row.get("status", "-")
        tests = row.get("test_details") or {}
        test_findings = []
        for test_name, item in tests.items():
            status = item.get("status") or "-"
            return_code = item.get("return_code")
            wrong_count = item.get("wrong_count")
            warn_hits = item.get("warn_error_hits")
            transport_hits = item.get("transport_warning_hits")
            should_report = (
                status != "passed"
                or (return_code not in (None, 0))
                or (wrong_count not in (None, 0))
                or (warn_hits not in (None, 0))
                or (transport_hits not in (None, 0))
            )
            if not should_report:
                continue
            bits = [f"{nccl_test_label(test_name)}:{status}"]
            if return_code is not None:
                bits.append(f"rc={return_code}")
            if wrong_count is not None:
                bits.append(f"wrong={wrong_count}")
            if warn_hits is not None:
                bits.append(f"warn={warn_hits}")
            if transport_hits is not None:
                bits.append(f"transport={transport_hits}")
            busbw = item.get("largest_message_busbw")
            if busbw is not None:
                bits.append(f"busbw={fmt_stat(busbw)}")
            notes = item.get("notes") or ""
            if notes:
                bits.append(f"notes={notes}")
            test_findings.append(" ".join(bits))

        if row_status != "passed" or test_findings:
            prefix_parts = []
            if row.get("round") not in (None, ""):
                prefix_parts.append(f"r{row.get('round')}")
            if row.get("job_id") not in (None, "", "-"):
                prefix_parts.append(f"job {row.get('job_id')}")
            if row.get("run_id") not in (None, "", "-"):
                prefix_parts.append(f"run {row.get('run_id')}")
            if row_status != "passed":
                prefix_parts.append(f"sample={row_status}")
            prefix = " ".join(prefix_parts) if prefix_parts else "sample"
            detail = "; ".join(test_findings) if test_findings else (row.get("notes") or row_status)
            findings.append(f"{prefix}: {detail}")

    return " | ".join(findings) if findings else ""


def rows_from_summaries(paths, manifest, check, results_root, nodes_per_job=None, sample_context=None):
    if check == "gpu-topology":
        return topology_rows_from_summaries(paths, manifest, results_root)
    if check == "nccl-local":
        rows = nccl_local_rows_from_summaries(paths, manifest, sample_context)
        return aggregate_nccl_repeat_rows(rows, manifest, check)
    if check == "nccl-rdma":
        rows = nccl_rdma_rows_from_summaries(paths, manifest, nodes_per_job, sample_context)
        return aggregate_nccl_repeat_rows(rows, manifest, check)
    rows = gds_rows_from_summaries(paths, manifest)
    return aggregate_gds_repeat_rows(rows, manifest)


def table_columns(check, repeated=False, repeat_aggregation="standard"):
    center_suffix = repeat_center_suffix(repeat_aggregation)
    if check == "gpu-topology":
        return [
            ("node", "Node"),
            ("discovery_state", "Slurm"),
            ("job_id", "Job"),
            ("run_id", "Run"),
            ("status", "Status"),
            ("gpu_count", "GPUs"),
            ("expected_gpu_count", "Expected"),
            ("gpu_model_summary", "Model"),
            ("gpu_count_status", "Count"),
            ("gpu_model_status", "Model OK"),
            ("nvidia_smi_topo_status", "Topo"),
            ("lscpu_status", "CPU"),
            ("notes", "Notes"),
        ]
    if repeated and check == "nccl-local":
        columns = [
            ("node", "Node"),
            ("discovery_state", "Slurm"),
            ("samples", "Samples"),
            ("passes", "Passes"),
            ("status", "Status"),
            ("all_reduce_perf_busbw", f"AR {center_suffix} (GB/s)"),
            ("all_reduce_perf_busbw_range", "AR min..max (GB/s)"),
        ]
        if repeat_aggregation == "olympic":
            columns.append(("all_reduce_perf_busbw_dropped", "AR drop min/max (GB/s)"))
        columns.extend([
            ("reduce_scatter_perf_busbw", f"RS {center_suffix} (GB/s)"),
            ("reduce_scatter_perf_busbw_range", "RS min..max (GB/s)"),
        ])
        if repeat_aggregation == "olympic":
            columns.append(("reduce_scatter_perf_busbw_dropped", "RS drop min/max (GB/s)"))
        columns.extend([
            ("all_gather_perf_busbw", f"AG {center_suffix} (GB/s)"),
            ("all_gather_perf_busbw_range", "AG min..max (GB/s)"),
        ])
        if repeat_aggregation == "olympic":
            columns.append(("all_gather_perf_busbw_dropped", "AG drop min/max (GB/s)"))
        columns.extend([
            ("alltoall_perf_busbw", f"A2A {center_suffix} (GB/s)"),
            ("alltoall_perf_busbw_range", "A2A min..max (GB/s)"),
        ])
        if repeat_aggregation == "olympic":
            columns.append(("alltoall_perf_busbw_dropped", "A2A drop min/max (GB/s)"))
        columns.extend([
            ("wrong_count", "Wrong"),
            ("aggregation_notes", "Aggregation"),
        ])
        return columns
    if check == "nccl-local":
        return [
            ("node", "Node"),
            ("discovery_state", "Slurm"),
            ("job_id", "Job"),
            ("run_id", "Run"),
            ("status", "Status"),
            ("tests_passed", "Tests"),
            ("all_reduce_perf_busbw", "AR busbw (GB/s)"),
            ("reduce_scatter_perf_busbw", "RS busbw (GB/s)"),
            ("all_gather_perf_busbw", "AG busbw (GB/s)"),
            ("alltoall_perf_busbw", "A2A busbw (GB/s)"),
            ("wrong_count", "Wrong"),
            ("notes", "Notes"),
        ]
    if repeated and check == "nccl-rdma":
        columns = [
            ("node_group", "Node Group"),
            ("node_count", "Nodes"),
            ("gpu_count", "GPUs"),
            ("samples", "Samples"),
            ("passes", "Passes"),
            ("status", "Status"),
            ("all_reduce_perf_busbw", f"AR {center_suffix} (GB/s)"),
            ("all_reduce_perf_busbw_range", "AR min..max (GB/s)"),
        ]
        if repeat_aggregation == "olympic":
            columns.append(("all_reduce_perf_busbw_dropped", "AR drop min/max (GB/s)"))
        columns.extend([
            ("reduce_scatter_perf_busbw", f"RS {center_suffix} (GB/s)"),
            ("reduce_scatter_perf_busbw_range", "RS min..max (GB/s)"),
        ])
        if repeat_aggregation == "olympic":
            columns.append(("reduce_scatter_perf_busbw_dropped", "RS drop min/max (GB/s)"))
        columns.extend([
            ("all_gather_perf_busbw", f"AG {center_suffix} (GB/s)"),
            ("all_gather_perf_busbw_range", "AG min..max (GB/s)"),
        ])
        if repeat_aggregation == "olympic":
            columns.append(("all_gather_perf_busbw_dropped", "AG drop min/max (GB/s)"))
        columns.extend([
            ("alltoall_perf_busbw", f"A2A {center_suffix} (GB/s)"),
            ("alltoall_perf_busbw_range", "A2A min..max (GB/s)"),
        ])
        if repeat_aggregation == "olympic":
            columns.append(("alltoall_perf_busbw_dropped", "A2A drop min/max (GB/s)"))
        columns.extend([
            ("wrong_count", "Wrong"),
            ("aggregation_notes", "Aggregation"),
        ])
        return columns
    if check == "nccl-rdma":
        return [
            ("node_group", "Node Group"),
            ("node_count", "Nodes"),
            ("gpu_count", "GPUs"),
            ("job_id", "Job"),
            ("run_id", "Run"),
            ("status", "Status"),
            ("tests_passed", "Tests"),
            ("all_reduce_perf_busbw", "AR busbw (GB/s)"),
            ("reduce_scatter_perf_busbw", "RS busbw (GB/s)"),
            ("all_gather_perf_busbw", "AG busbw (GB/s)"),
            ("alltoall_perf_busbw", "A2A busbw (GB/s)"),
            ("wrong_count", "Wrong"),
            ("notes", "Notes"),
        ]

    if repeated:
        columns = [
            ("node", "Node"),
            ("discovery_state", "Slurm"),
            ("samples", "Samples"),
            ("passes", "Passes"),
            ("status", "Status"),
            ("throughput_read_throughput_gib_s", f"Sequential Read {center_suffix}"),
            ("throughput_read_throughput_gib_s_range", "Sequential Read min..max"),
        ]
        if repeat_aggregation == "olympic":
            columns.append(("throughput_read_throughput_gib_s_dropped", "Sequential Read drop min/max"))
        columns.extend([
            ("throughput_write_throughput_gib_s", f"Sequential Write {center_suffix}"),
            ("throughput_write_throughput_gib_s_range", "Sequential Write min..max"),
        ])
        if repeat_aggregation == "olympic":
            columns.append(("throughput_write_throughput_gib_s_dropped", "Sequential Write drop min/max"))
        columns.extend([
            ("random_read_throughput_gib_s", f"Random Read {center_suffix}"),
            ("random_read_throughput_gib_s_range", "Random Read min..max"),
        ])
        if repeat_aggregation == "olympic":
            columns.append(("random_read_throughput_gib_s_dropped", "Random Read drop min/max"))
        columns.extend([
            ("random_write_throughput_gib_s", f"Random Write {center_suffix}"),
            ("random_write_throughput_gib_s_range", "Random Write min..max"),
        ])
        if repeat_aggregation == "olympic":
            columns.append(("random_write_throughput_gib_s_dropped", "Random Write drop min/max"))
        columns.append(("aggregation_notes", "Aggregation"))
        return columns

    return [
        ("node", "Node"),
        ("discovery_state", "Slurm"),
        ("job_id", "Job"),
        ("run_id", "Run"),
        ("profile", "Profile"),
        ("status", "Status"),
        ("platform_status", "Platform"),
        ("sequential_status_pair", "Sequential W/R"),
        ("throughput_read_throughput_gib_s", "Sequential Read GiB/s"),
        ("throughput_write_throughput_gib_s", "Sequential Write GiB/s"),
        ("random_read_throughput_gib_s", "Random Read GiB/s"),
        ("random_write_throughput_gib_s", "Random Write GiB/s"),
        ("notes", "Notes"),
    ]


def rows_are_repeated(rows):
    return any(row.get("repeat_campaign") for row in rows)


def render_ascii(rows, title, check, manifest=None):
    repeated = rows_are_repeated(rows)
    repeat_aggregation = manifest_repeat_aggregation(manifest or {})
    columns = table_columns(check, repeated, repeat_aggregation)
    text = render_table(rows, columns, title=title)
    if check in {"nccl-local", "nccl-rdma"}:
        text = f"{text}\n\nBandwidth columns are largest-message busbw in GB/s."
        if repeated:
            center = repeat_center_label(repeat_aggregation)
            text = f"{text} {center} columns aggregate passed samples for each node or node group."
    return text


def render_table(rows, columns, title=None):
    widths = {}
    for key, label in columns:
        widths[key] = max(len(label), *(len(str(row.get(key, ""))) for row in rows)) if rows else len(label)

    lines = [title] if title else []
    header = "  ".join(label.ljust(widths[key]) for key, label in columns)
    sep = "  ".join("-" * widths[key] for key, _ in columns)
    lines.extend([header, sep])
    for row in rows:
        lines.append("  ".join(str(row.get(key, "")).ljust(widths[key]) for key, _ in columns))
    if not rows:
        lines.append("(no rows)")
    return "\n".join(lines)


def markdown_table(rows, columns):
    lines = []
    lines.append("| " + " | ".join(label for _, label in columns) + " |")
    lines.append("| " + " | ".join("---" for _ in columns) + " |")
    if rows:
        for row in rows:
            lines.append("| " + " | ".join(str(row.get(key, "")) for key, _ in columns) + " |")
    else:
        lines.append("| " + " | ".join(["-"] * len(columns)) + " |")
    return lines


def gds_stats_rows(stats):
    rows = []
    for key, label in GDS_METRICS:
        metric_stats = stats.get(key)
        if not metric_stats:
            continue
        rows.append({
            "metric": label,
            "n": metric_stats["n"],
            "mean": fmt_stat(metric_stats["mean"]),
            "median": fmt_stat(metric_stats["median"]),
            "stddev": fmt_stat(metric_stats["stddev"]),
            "min": fmt_stat(metric_stats["min"]),
            "p10": fmt_stat(metric_stats["p10"]),
            "p25": fmt_stat(metric_stats["p25"]),
            "p75": fmt_stat(metric_stats["p75"]),
            "p90": fmt_stat(metric_stats["p90"]),
            "max": fmt_stat(metric_stats["max"]),
            "mad": fmt_stat(metric_stats["mad"]),
            "cv": fmt_stat(metric_stats["cv"]),
        })
    return rows


def gds_anomaly_rows(anomalies):
    return [
        {
            "severity": item["severity"],
            "node": item["node"],
            "metric": item["metric"],
            "value": fmt_stat(item["value"]),
            "median": fmt_stat(item["median"]),
            "delta_pct": fmt_pct(item["delta_pct"]),
            "robust_z": fmt_stat(item["robust_z"]),
        }
        for item in anomalies
    ]


def visible_anomalies(anomalies):
    visible = []
    suppressed = 0
    for item in anomalies:
        delta_pct = item.get("delta_pct")
        try:
            delta_abs = abs(float(delta_pct))
        except (TypeError, ValueError):
            delta_abs = None
        if delta_abs is not None and delta_abs < ANOMALY_MIN_ABS_DELTA_PCT:
            suppressed += 1
            continue
        visible.append(item)
    return visible, suppressed


def anomaly_suppression_note(count):
    if count <= 0:
        return ""
    return f"Suppressed {count} anomaly rows below {ANOMALY_MIN_ABS_DELTA_PCT:.1f}% absolute delta."


def gds_operational_rows(rows):
    _, _, operational = build_gds_stats(rows)
    return [
        {
            "node": row.get("node", "-"),
            "slurm": row.get("discovery_state", "-"),
            "job": row.get("job_id", "-"),
            "run": row.get("run_id", "-"),
            "samples": row.get("samples", "-"),
            "passes": row.get("passes", "-"),
            "status": row.get("status", "-"),
        }
        for row in sorted(operational, key=lambda item: (item.get("node", ""), item.get("status", "")))
    ]


def gds_phase_detail_rows(rows):
    out = []
    for row in rows:
        if row.get("repeat_campaign"):
            continue
        for item in row.get("phase_details") or []:
            out.append({
                "node": row.get("node", "-"),
                "profile": row.get("profile", "-"),
                "phase": item.get("phase", "-"),
                "status": item.get("status", "-"),
                "throughput": item.get("throughput_gib_s", "-"),
                "latency": item.get("avg_latency_usecs", "-"),
                "ops": item.get("ops", "-"),
                "time": item.get("total_time_s", "-"),
                "note": item.get("note", ""),
            })
    return out


def gds_stats_columns():
    return [
        ("metric", "Metric"),
        ("n", "n"),
        ("mean", "Mean"),
        ("median", "Median"),
        ("stddev", "StdDev"),
        ("min", "Min"),
        ("p10", "P10"),
        ("p25", "P25"),
        ("p75", "P75"),
        ("p90", "P90"),
        ("max", "Max"),
        ("mad", "MAD"),
        ("cv", "CV"),
    ]


def gds_phase_detail_columns():
    return [
        ("node", "Node"),
        ("profile", "Profile"),
        ("phase", "Phase"),
        ("status", "Status"),
        ("throughput", "GiB/s"),
        ("latency", "Latency us"),
        ("ops", "Ops"),
        ("time", "Time s"),
        ("note", "Note"),
    ]


def gds_anomaly_columns():
    return [
        ("severity", "Severity"),
        ("node", "Node"),
        ("metric", "Metric"),
        ("value", "Value"),
        ("median", "Median"),
        ("delta_pct", "Delta"),
        ("robust_z", "Robust Z"),
    ]


def gds_operational_columns():
    return [
        ("node", "Node"),
        ("slurm", "Slurm"),
        ("job", "Job"),
        ("run", "Run"),
        ("samples", "Samples"),
        ("passes", "Passes"),
        ("status", "Status"),
    ]


def nccl_entity_key(check):
    return "node_group" if check == "nccl-rdma" else "node"


def nccl_entity_label(check):
    return "Node Group" if check == "nccl-rdma" else "Node"


def build_nccl_stats(rows, check):
    entity_key = nccl_entity_key(check)
    stats = {}
    anomalies = []
    for key, label in NCCL_METRICS:
        values = []
        for row in rows:
            if row.get("status") != "passed" and not (row.get("repeat_campaign") and row.get("status") == "degraded"):
                continue
            value = parse_float(row.get(key))
            if value is None:
                continue
            values.append((row.get(entity_key, "-"), value))

        metric_stats = stats_for_values([value for _, value in values])
        if not metric_stats:
            continue
        stats[key] = {"label": label, **metric_stats}
        for entity, value in values:
            low_severity = classify_low_anomaly(value, metric_stats)
            high_severity = classify_high_anomaly(value, metric_stats)
            severity = low_severity or high_severity
            if not severity:
                continue
            med = metric_stats["median"]
            anomalies.append({
                "entity": entity,
                "metric": label,
                "value": value,
                "median": med,
                "delta_pct": ((value - med) / med * 100) if med else None,
                "robust_z": robust_z(value, med, metric_stats["mad"]),
                "severity": severity,
            })

    severity_order = {"severe_low": 0, "warning_low": 1, "low_tail": 2, "high_info": 3}
    anomalies.sort(key=lambda item: (severity_order.get(item["severity"], 99), item["metric"], item["entity"]))
    operational = [row for row in rows if row.get("status") != "passed"]
    return stats, anomalies, operational


def nccl_stats_rows(stats):
    rows = []
    for key, label in NCCL_METRICS:
        metric_stats = stats.get(key)
        if not metric_stats:
            continue
        rows.append({
            "metric": label,
            "n": metric_stats["n"],
            "mean": fmt_stat(metric_stats["mean"]),
            "median": fmt_stat(metric_stats["median"]),
            "stddev": fmt_stat(metric_stats["stddev"]),
            "min": fmt_stat(metric_stats["min"]),
            "p10": fmt_stat(metric_stats["p10"]),
            "p25": fmt_stat(metric_stats["p25"]),
            "p75": fmt_stat(metric_stats["p75"]),
            "p90": fmt_stat(metric_stats["p90"]),
            "max": fmt_stat(metric_stats["max"]),
            "mad": fmt_stat(metric_stats["mad"]),
            "cv": fmt_stat(metric_stats["cv"]),
        })
    return rows


def nccl_anomaly_rows(anomalies, check):
    entity_key = "node_group" if check == "nccl-rdma" else "node"
    return [
        {
            "severity": item["severity"],
            entity_key: item["entity"],
            "metric": item["metric"],
            "value": fmt_stat(item["value"]),
            "median": fmt_stat(item["median"]),
            "delta_pct": fmt_pct(item["delta_pct"]),
            "robust_z": fmt_stat(item["robust_z"]),
        }
        for item in anomalies
    ]


def nccl_operational_rows(rows, check):
    _, _, operational = build_nccl_stats(rows, check)
    entity_key = nccl_entity_key(check)
    return [
        {
            entity_key: row.get(entity_key, "-"),
            "job": row.get("job_id", "-"),
            "run": row.get("run_id", "-"),
            "samples": row.get("samples", "-"),
            "passes": row.get("passes", "-"),
            "status": row.get("status", "-"),
            "tests": row.get("tests_passed", "-"),
            "wrong": row.get("wrong_count", "-"),
            "findings": row.get("sample_findings", ""),
        }
        for row in sorted(operational, key=lambda item: (item.get(entity_key, ""), item.get("status", "")))
    ]


def nccl_anomaly_columns(check):
    entity_key = nccl_entity_key(check)
    return [
        ("severity", "Severity"),
        (entity_key, nccl_entity_label(check)),
        ("metric", "Metric"),
        ("value", "Value"),
        ("median", "Median"),
        ("delta_pct", "Delta"),
        ("robust_z", "Robust Z"),
    ]


def nccl_operational_columns(check):
    entity_key = nccl_entity_key(check)
    return [
        (entity_key, nccl_entity_label(check)),
        ("job", "Job"),
        ("run", "Run"),
        ("samples", "Samples"),
        ("passes", "Passes"),
        ("status", "Status"),
        ("tests", "Tests"),
        ("wrong", "Wrong"),
        ("findings", "Sample Findings"),
    ]


def render_gds_stats_ascii(rows):
    stats, anomalies, _ = build_gds_stats(rows)
    parts = []

    detail_rows = gds_phase_detail_rows(rows)
    if detail_rows:
        parts.append("GDS Phase Details")
        parts.append(render_table(detail_rows, gds_phase_detail_columns()))

    parts.append("GDS Statistics")
    parts.append(f"Stats definitions: {STATS_DOCS_PATH}")
    parts.append(render_table(gds_stats_rows(stats), gds_stats_columns()))

    parts.append("GDS Anomalies")
    visible, suppressed = visible_anomalies(anomalies)
    anomaly_rows = gds_anomaly_rows(visible)
    parts.append(render_table(anomaly_rows, gds_anomaly_columns()) if anomaly_rows else "(none)")
    note = anomaly_suppression_note(suppressed)
    if note:
        parts.append(note)

    parts.append("Missing/Skipped Jobs")
    operational_rows = gds_operational_rows(rows)
    parts.append(render_table(operational_rows, gds_operational_columns()) if operational_rows else "(none)")

    return "\n\n".join(parts)


def render_gds_stats_markdown(rows, stats_link):
    stats, anomalies, _ = build_gds_stats(rows)
    lines = []

    detail_rows = gds_phase_detail_rows(rows)
    if detail_rows:
        lines.extend([
            "## GDS Phase Details",
            "",
            "Phase rows are emitted by the selected GDS profile. GiB/s, latency, ops, and time come from parsed `gdsio` output when the phase produces those fields.",
            "",
        ])
        lines.extend(markdown_table(detail_rows, gds_phase_detail_columns()))
        lines.append("")

    lines.extend([
        "## GDS Statistics",
        "",
        "Only passed rows with numeric throughput values are included. Mean shows the overall level; median and MAD are preferred for anomaly detection because severe outliers can distort standard deviation.",
        f"See [Stats Explained]({stats_link}) for definitions of Mean, Median, StdDev, percentiles, MAD, CV, Delta, and Robust Z.",
        "",
    ])
    lines.extend(markdown_table(gds_stats_rows(stats), gds_stats_columns()))
    lines.append("")

    lines.extend([
        "## GDS Anomalies",
        "",
        f"Anomalies are report evidence only and do not change canonical `status.json` pass/fail. Rows below `{ANOMALY_MIN_ABS_DELTA_PCT:.1f}%` absolute delta are suppressed from this table. See [Stats Explained]({stats_link}) for `Delta` and `Robust Z` definitions.",
        "",
    ])
    visible, suppressed = visible_anomalies(anomalies)
    anomaly_rows = gds_anomaly_rows(visible)
    lines.extend(markdown_table(anomaly_rows, gds_anomaly_columns()) if anomaly_rows else ["(none)"])
    note = anomaly_suppression_note(suppressed)
    if note:
        lines.extend(["", note])
    lines.append("")

    lines.extend(["## Missing/Skipped Jobs", ""])
    operational_rows = gds_operational_rows(rows)
    lines.extend(markdown_table(operational_rows, gds_operational_columns()) if operational_rows else ["(none)"])
    lines.append("")

    return "\n".join(lines)


def render_nccl_stats_ascii(rows, check):
    stats, anomalies, _ = build_nccl_stats(rows, check)
    title = "NCCL RDMA" if check == "nccl-rdma" else "NCCL Local"
    parts = []

    parts.append(f"{title} Statistics")
    parts.append("Bandwidth values are largest-message busbw in GB/s.")
    parts.append(f"Stats definitions: {STATS_DOCS_PATH}")
    parts.append(render_table(nccl_stats_rows(stats), gds_stats_columns()))

    parts.append(f"{title} Anomalies")
    visible, suppressed = visible_anomalies(anomalies)
    anomaly_rows = nccl_anomaly_rows(visible, check)
    parts.append(render_table(anomaly_rows, nccl_anomaly_columns(check)) if anomaly_rows else "(none)")
    note = anomaly_suppression_note(suppressed)
    if note:
        parts.append(note)

    parts.append("Missing/Skipped/Failed Jobs")
    operational_rows = nccl_operational_rows(rows, check)
    parts.append(render_table(operational_rows, nccl_operational_columns(check)) if operational_rows else "(none)")

    return "\n\n".join(parts)


def render_nccl_stats_markdown(rows, check, stats_link):
    stats, anomalies, _ = build_nccl_stats(rows, check)
    title = "NCCL RDMA" if check == "nccl-rdma" else "NCCL Local"
    lines = []

    lines.extend([
        f"## {title} Statistics",
        "",
        "Only passed rows with numeric largest-message `busbw` values are included. All bandwidth values in this section are GB/s. Mean shows the overall level; median and MAD are preferred for fleet comparison because outliers can distort standard deviation.",
        f"See [Stats Explained]({stats_link}) for definitions of Mean, Median, StdDev, percentiles, MAD, CV, Delta, and Robust Z.",
        "",
    ])
    lines.extend(markdown_table(nccl_stats_rows(stats), gds_stats_columns()))
    lines.append("")

    lines.extend([
        f"## {title} Anomalies",
        "",
        f"Anomalies are report evidence only and do not change canonical `status.json` pass/fail. Rows below `{ANOMALY_MIN_ABS_DELTA_PCT:.1f}%` absolute delta are suppressed from this table. See [Stats Explained]({stats_link}) for `Delta` and `Robust Z` definitions.",
        "",
    ])
    visible, suppressed = visible_anomalies(anomalies)
    anomaly_rows = nccl_anomaly_rows(visible, check)
    lines.extend(markdown_table(anomaly_rows, nccl_anomaly_columns(check)) if anomaly_rows else ["(none)"])
    note = anomaly_suppression_note(suppressed)
    if note:
        lines.extend(["", note])
    lines.append("")

    lines.extend(["## Missing/Skipped/Failed Jobs", ""])
    operational_rows = nccl_operational_rows(rows, check)
    lines.extend(markdown_table(operational_rows, nccl_operational_columns(check)) if operational_rows else ["(none)"])
    lines.append("")

    return "\n".join(lines)


def topology_join(values):
    if isinstance(values, list):
        return ", ".join(values) if values else "-"
    return str(values) if values not in (None, "") else "-"


def topology_sort_key(value):
    text = str(value)
    if "mlx5_" in text or text.startswith("NIC"):
        return f"{topology_intelligence.natural_mlx5_key(text):04d}"
    return text


def topology_compact_map(mapping, prefix=""):
    if not mapping:
        return "-"
    parts = []
    for key in sorted(mapping, key=topology_sort_key):
        label = str(key)
        if prefix and label.startswith(prefix):
            label = label[len(prefix):]
        value = mapping.get(key)
        if isinstance(value, list):
            value = "+".join(value)
        parts.append(f"{label}:{value if value not in (None, '') else '-'}")
    return ",".join(parts)


def topology_nearest_nic(row, gpu):
    item = (row.get("gpu_nearest_nics") or {}).get(gpu) or {}
    link = item.get("link") or "-"
    nics = item.get("nics") or []
    return f"{link}:{topology_join(nics)}"


def topology_row_summary(row):
    gpu_numa = row.get("gpu_numa_affinity") or {}
    gpu_pix = row.get("gpu_pix_nics") or {}
    nic_numa = row.get("nic_numa_affinity") or {}
    ib_numa = row.get("ib_device_numa_affinity") or {}
    display_nic_numa = nic_numa
    if ib_numa and not any(str(value).strip() for value in nic_numa.values()):
        display_nic_numa = ib_numa
    return {
        "node": row.get("node", "-"),
        "profile": row.get("topology_profile_status", "-"),
        "gpu_numa": topology_compact_map(gpu_numa, "GPU"),
        "nic_numa": topology_compact_map(display_nic_numa),
        "gpu0_nics": topology_nearest_nic(row, "GPU0"),
        "gpu7_nics": topology_nearest_nic(row, "GPU7"),
        "gpu7_pix": topology_join(gpu_pix.get("GPU7", [])),
        "storage": f"{row.get('gds_storage_fstype') or '-'}:{row.get('gds_storage_source') or '-'}",
        "route": row.get("gds_storage_route_dev") or "-",
        "route_mlx5": row.get("gds_storage_route_mlx5") or "-",
        "notes": row.get("topology_profile_notes", ""),
    }


def topology_profile_rows(rows):
    return [
        topology_row_summary(row)
        for row in rows
        if row.get("status") not in {"missing", "skipped"} and row.get("topology_signature")
    ]


def topology_profile_columns(rows=None):
    rows = rows or []
    columns = [
        ("node", "Node"),
        ("profile", "Profile"),
        ("gpu_numa", "GPU NUMA"),
        ("nic_numa", "mlx5 NUMA"),
        ("gpu0_nics", "GPU0 nearest NICs"),
        ("gpu7_nics", "GPU7 nearest NICs"),
        ("gpu7_pix", "GPU7 PIX NICs"),
    ]
    if any(row.get("storage") != "-:-" or row.get("route") != "-" or row.get("route_mlx5") != "-" for row in rows):
        columns.extend([
            ("storage", "GDS storage"),
            ("route", "Storage route"),
            ("route_mlx5", "Storage mlx5"),
        ])
    columns.append(("notes", "Notes"))
    return columns


def topology_consistency(rows):
    structured = [row for row in rows if row.get("topology_signature")]
    signature, count = topology_intelligence.majority_signature(structured)
    outliers = []
    if signature:
        outliers = [
            row.get("node", "-")
            for row in structured
            if row.get("topology_signature") != signature
        ]
    missing_structured = [
        row.get("node", "-")
        for row in rows
        if row.get("status") not in {"missing", "skipped"} and not row.get("topology_signature")
    ]
    return {
        "structured_count": len(structured),
        "row_count": len([row for row in rows if row.get("status") not in {"missing", "skipped"}]),
        "majority_signature": signature or "",
        "majority_count": count,
        "outliers": outliers,
        "missing_structured": missing_structured,
    }


def render_topology_intelligence_ascii(rows):
    profile_rows = topology_profile_rows(rows)
    consistency = topology_consistency(rows)
    parts = [
        "GPU Topology Intelligence",
        "Topology and mlx5 affinity intelligence is report-only and does not change status.json.",
        render_table(profile_rows, topology_profile_columns(profile_rows)) if profile_rows else "(no structured topology rows)",
        "Fleet Consistency",
        "\n".join([
            f"Structured rows: {consistency['structured_count']}/{consistency['row_count']}",
            f"Majority signature count: {consistency['majority_count']}/{consistency['structured_count']}",
            f"Outlier nodes: {', '.join(consistency['outliers']) if consistency['outliers'] else '(none)'}",
            f"Missing structured topology: {', '.join(consistency['missing_structured']) if consistency['missing_structured'] else '(none)'}",
            f"Majority topology signature: {consistency['majority_signature'] or '-'}",
        ]),
    ]
    return "\n\n".join(parts)


def render_topology_intelligence_markdown(rows):
    profile_rows = topology_profile_rows(rows)
    consistency = topology_consistency(rows)
    lines = [
        "## GPU Topology Intelligence",
        "",
        "Topology and mlx5 affinity intelligence is report-only and does not change canonical `status.json` pass/fail.",
        "",
    ]
    lines.extend(markdown_table(profile_rows, topology_profile_columns(profile_rows)) if profile_rows else ["(no structured topology rows)"])
    lines.extend([
        "",
        "### Fleet Consistency",
        "",
        f"- Structured rows: `{consistency['structured_count']}/{consistency['row_count']}`",
        f"- Majority signature count: `{consistency['majority_count']}/{consistency['structured_count']}`",
        f"- Outlier nodes: `{', '.join(consistency['outliers']) if consistency['outliers'] else '(none)'}`",
        f"- Missing structured topology: `{', '.join(consistency['missing_structured']) if consistency['missing_structured'] else '(none)'}`",
        "",
        "Majority topology signature:",
        "",
        "```text",
        consistency["majority_signature"] or "-",
        "```",
        "",
    ])
    return "\n".join(lines)


def render_markdown(rows, title, manifest, check, include_stats=True, cluster=None, stats_link=None):
    stats_link = stats_link or STATS_DOCS_PATH
    repeated = rows_are_repeated(rows)
    repeat_aggregation = manifest_repeat_aggregation(manifest or {})
    columns = table_columns(check, repeated, repeat_aggregation)
    lines = [f"# {title}", ""]
    if manifest:
        manifest_lines = [
            f"- Check: `{manifest.get('check', check)}`",
            f"- Cluster: `{manifest.get('cluster', '')}`",
            f"- Partition: `{manifest.get('partition', '')}`",
            f"- Discovery time: `{manifest.get('discovered_at_utc', '')}`",
            f"- Mode: `{manifest.get('mode', '')}`",
        ]
        if check == "gds" and manifest.get("profile"):
            manifest_lines.append(f"- GDS profile: `{manifest.get('profile')}`")
        if check == "gds" and manifest.get("time_limit"):
            manifest_lines.append(f"- Time limit: `{manifest.get('time_limit')}`")
        if check == "nccl-rdma" and manifest.get("nodes_per_job"):
            manifest_lines.append(f"- Nodes per job: `{manifest.get('nodes_per_job')}`")
        if check == "nccl-rdma" and manifest.get("gpus_per_job"):
            manifest_lines.append(f"- GPUs per job: `{manifest.get('gpus_per_job')}`")
        if manifest_repeat_count(manifest) > 1:
            manifest_lines.append(f"- Repeat count: `{manifest_repeat_count(manifest)}`")
            manifest_lines.append(f"- Repeat aggregation: `{repeat_aggregation}`")
            manifest_lines.append(f"- Round stagger seconds: `{manifest.get('round_stagger_seconds', 0)}`")
        if manifest.get("gpu_preflight_filter_enabled"):
            excluded = manifest.get("gpu_preflight_excluded_nodes") or []
            manifest_lines.append("- GPU preflight filter: `enabled`")
            manifest_lines.append(f"- GPU preflight source: `{manifest.get('gpu_preflight_source', '')}`")
            manifest_lines.append(f"- GPU preflight expected count: `{manifest.get('gpu_preflight_expected_count', '')}`")
            manifest_lines.append(f"- GPU preflight excluded nodes: `{len(excluded)}`")
        lines.extend(manifest_lines)
        lines.append("")

    lines.extend(markdown_table(rows, columns))
    lines.append("")
    if check in {"nccl-local", "nccl-rdma"}:
        lines.extend(["Bandwidth columns are largest-message `busbw` in GB/s.", ""])
        if repeated:
            center = repeat_center_label(repeat_aggregation)
            lines.extend([f"{center} columns aggregate passed samples for each node or node group.", ""])
    elif check == "gds" and repeated:
        center = repeat_center_label(repeat_aggregation)
        lines.extend([f"{center} columns aggregate passed numeric samples for each node.", ""])

    if check == "gds" and include_stats:
        lines.append(render_gds_stats_markdown(rows, stats_link))
    elif check in {"nccl-local", "nccl-rdma"} and include_stats:
        lines.append(render_nccl_stats_markdown(rows, check, stats_link))
    elif check == "gpu-topology":
        lines.append(render_topology_intelligence_markdown(rows))

    skipped = manifest.get("skipped_nodes_by_state", {}) if manifest else {}
    if skipped:
        lines.extend(["## Skipped Nodes", ""])
        for state, nodes in sorted(skipped.items()):
            lines.append(f"- `{state}`: {', '.join(nodes)}")
        lines.append("")

    return "\n".join(lines)


def markdown_output_path(results_root, date, cluster, check, nodes_per_job=None):
    report_dir = results_root / "reports" / date
    suffix = ""
    if check == "nccl-rdma" and nodes_per_job not in (None, 2):
        suffix = f"-{nodes_per_job}n"
    return report_dir / f"{check}-{cluster}{suffix}.md"


def write_markdown(results_root, date, cluster, check, text, nodes_per_job=None):
    path = markdown_output_path(results_root, date, cluster, check, nodes_per_job)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def check_title(check):
    if check == "gpu-topology":
        return "GPU Topology"
    if check == "nccl-local":
        return "NCCL Local"
    if check == "nccl-rdma":
        return "NCCL RDMA"
    return check.upper()


def main():
    args = build_parser().parse_args()
    results_root = Path(args.results_root)
    manifest = load_manifest(args.fleet_manifest)
    effective_nodes_per_job = args.nodes_per_job
    if args.check == "nccl-rdma" and effective_nodes_per_job is None:
        manifest_nodes = manifest.get("nodes_per_job")
        try:
            effective_nodes_per_job = int(manifest_nodes)
        except (TypeError, ValueError):
            effective_nodes_per_job = None
    summaries = summary_paths_from_manifest(
        results_root,
        args.date,
        args.cluster,
        args.check,
        manifest,
        effective_nodes_per_job,
    )
    if not summaries:
        summaries = latest_summaries(results_root, args.date, args.cluster, args.check, args.node)
    sample_context = sample_context_by_run_id(results_root, args.date, args.cluster, args.check, manifest)
    rows = rows_from_summaries(summaries, manifest, args.check, results_root, effective_nodes_per_job, sample_context)
    title = f"{check_title(args.check)} {args.cluster} {args.date}"
    if args.check == "nccl-rdma" and effective_nodes_per_job is not None:
        title = f"{title} {effective_nodes_per_job}n"

    want_ascii = args.ascii or args.both or not args.markdown
    want_markdown = args.markdown or args.both

    if want_ascii:
        ascii_text = render_ascii(rows, title, args.check, manifest)
        if args.check == "gds" and not args.no_stats:
            ascii_text = f"{ascii_text}\n\n{render_gds_stats_ascii(rows)}"
        elif args.check in {"nccl-local", "nccl-rdma"} and not args.no_stats:
            ascii_text = f"{ascii_text}\n\n{render_nccl_stats_ascii(rows, args.check)}"
        elif args.check == "gpu-topology":
            ascii_text = f"{ascii_text}\n\n{render_topology_intelligence_ascii(rows)}"
        print(ascii_text)

    if want_markdown:
        output_path = markdown_output_path(results_root, args.date, args.cluster, args.check, effective_nodes_per_job) if args.write else None
        markdown = render_markdown(
            rows,
            title,
            manifest,
            args.check,
            include_stats=not args.no_stats,
            cluster=args.cluster,
            stats_link=stats_docs_link(output_path),
        )
        if args.write:
            path = write_markdown(results_root, args.date, args.cluster, args.check, markdown, effective_nodes_per_job)
            print(f"Wrote {path}")
        else:
            print(markdown)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
