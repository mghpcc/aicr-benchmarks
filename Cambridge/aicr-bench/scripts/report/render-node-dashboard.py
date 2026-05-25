#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from statistics import median

from report_index import write_reports_index

REPORT_STATS_LINK = "../../../docs/stats-explained.md"


STATUS_ORDER = {
    "failed": 5,
    "degraded": 4,
    "unknown": 3,
    "missing": 2,
    "passed": 1,
    "skipped": 0,
}

DIRECT_STATUS_ORDER = {
    "failed": 4,
    "degraded": 3,
    "missing": 2,
    "unknown": 2,
    "passed": 1,
    "skipped": 0,
}

SUPPORTED_CLUSTERS = ("b200", "rtxpro6000")

CHECK_LABELS = {
    "gpu-topology": "GPU topology",
    "gds": "GDS",
    "nccl-suite": "NCCL suite",
}


def build_parser():
    parser = argparse.ArgumentParser(description="Render AICR by-node dashboards from committed artifacts.")
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--date", required=True, help="ISO date, today, or yesterday")
    parser.add_argument("--cluster", required=True, choices=SUPPORTED_CLUSTERS)

    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--ascii", action="store_true")
    modes.add_argument("--markdown", action="store_true")
    modes.add_argument("--both", action="store_true")

    parser.add_argument("--write", action="store_true")
    return parser


def evidence_files(cluster):
    files = {
        "campaign": f"campaign-{cluster}" + "-{date}.json",
        "gpu-topology": f"gpu-topology-{cluster}.md",
        "gds": f"gds-{cluster}.md",
        "nccl-suite": f"nccl-suite-{cluster}.md",
    }
    return files


def cluster_supports_node_debug(cluster):
    return cluster in {"b200", "rtxpro6000"}


def resolve_date(value):
    if value == "today":
        return datetime.now(timezone.utc).date().isoformat()
    if value == "yesterday":
        return (datetime.now(timezone.utc).date() - timedelta(days=1)).isoformat()
    if not re.match(r"^\d{4}-\d{2}-\d{2}$", value):
        raise ValueError(f"--date must be YYYY-MM-DD, today, or yesterday: {value}")
    return value


def utc_now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def repo_root_from_results_root(results_root):
    resolved = results_root.resolve()
    if resolved.name == "results":
        return resolved.parent
    return resolved.parent


def load_json(path):
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def markdown_escape(value):
    return str(value or "").replace("|", "\\|")


def relpath(path, repo_root):
    if not path:
        return None
    try:
        return str(path.resolve().relative_to(repo_root.resolve()))
    except ValueError:
        return str(path)


def split_markdown_row(line):
    line = line.strip()
    if not line.startswith("|") or not line.endswith("|"):
        return None
    return [cell.strip() for cell in line.strip("|").split("|")]


def is_separator_row(cells):
    return bool(cells) and all(re.match(r"^:?-{3,}:?$", cell.strip()) for cell in cells)


def markdown_tables(text):
    lines = text.splitlines()
    tables = []
    index = 0
    while index + 1 < len(lines):
        header = split_markdown_row(lines[index])
        separator = split_markdown_row(lines[index + 1])
        if header and separator and is_separator_row(separator):
            rows = []
            index += 2
            while index < len(lines):
                cells = split_markdown_row(lines[index])
                if cells is None:
                    break
                if len(cells) == len(header):
                    rows.append(dict(zip(header, cells)))
                index += 1
            tables.append({"header": header, "rows": rows})
        index += 1
    return tables


def first_primary_table(text):
    for table in markdown_tables(text):
        header = set(table["header"])
        if "Status" in header and ({"Node", "Node Group", "Entity"} & header):
            return table
    return None


def nccl_suite_table(text):
    return table_after_heading(text, "## Detailed Rows") or first_primary_table(text)


def table_after_heading(text, heading):
    lines = text.splitlines()
    in_section = False
    section_lines = []
    for line in lines:
        if line.startswith("## "):
            if in_section:
                break
            in_section = line.strip() == heading
            continue
        if in_section:
            section_lines.append(line)
    tables = markdown_tables("\n".join(section_lines))
    return tables[0] if tables else None


def normalize_status(value):
    value = (value or "").strip().strip("`").strip().lower()
    if value in {"pass", "ok"}:
        return "passed"
    if value in {"fail", "error"}:
        return "failed"
    if value in {"incomplete", "partial"}:
        return "degraded"
    if value in STATUS_ORDER:
        return value
    return "unknown"


def choose_status(current, candidate, ordering):
    if ordering.get(candidate, -1) > ordering.get(current, -1):
        return candidate
    return current


def parse_ratio(value):
    value = (value or "").strip()
    match = re.match(r"^(\d+)\s*/\s*(\d+)$", value)
    if not match:
        return None
    return int(match.group(1)), int(match.group(2))


def split_nodes(group):
    nodes = []
    for item in (group or "").split(","):
        node = item.strip().strip("`").strip()
        if node:
            nodes.append(node)
    return nodes


def unique_sorted(values):
    return sorted(set(values))


def node_record(node):
    return {
        "node": node,
        "status": "passed",
        "checks": {
            "gpu-topology": {"status": "missing"},
            "gds": {"status": "missing"},
            "nccl-suite": {"status": "missing", "groups": []},
        },
        "headlines": [],
        "findings": [],
        "operator_notes": [],
        "evidence_paths": [],
        "slurm_states": [],
    }


def ensure_node(nodes, node):
    if node not in nodes:
        nodes[node] = node_record(node)
    return nodes[node]


def add_headline(item, text):
    if text and text not in item["headlines"]:
        item["headlines"].append(text)


def add_finding(item, text):
    if text and text not in item["findings"]:
        item["findings"].append(text)


def add_note(item, text):
    if text and text not in item["operator_notes"]:
        item["operator_notes"].append(text)


def add_evidence(item, path):
    if path and path not in item["evidence_paths"]:
        item["evidence_paths"].append(path)


def add_slurm_state(item, state):
    if state and state not in item["slurm_states"]:
        item["slurm_states"].append(state)


def fmt_check_summary(check):
    status = check.get("status", "missing")
    samples = check.get("samples")
    passes = check.get("passes")
    if status == "missing":
        return "missing"
    if status == "skipped":
        return "skipped"
    if samples and passes:
        return f"{status} {passes}"
    return status


def analyze_gds_anomalies(text):
    table = table_after_heading(text, "## GDS Anomalies")
    out = {}
    if not table:
        return out
    for row in table["rows"]:
        node = row.get("Node")
        if not node:
            continue
        item = out.setdefault(node, {"count": 0, "severe": 0, "metrics": [], "rows": []})
        item["count"] += 1
        severity = (row.get("Severity") or "").strip()
        if severity == "severe_low":
            item["severe"] += 1
        metric = row.get("Metric") or "-"
        item["metrics"].append(metric)
        item["rows"].append({
            "severity": severity,
            "metric": metric,
            "delta": row.get("Delta") or "-",
        })
    return out


def load_markdown(path):
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8")


def parse_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def telemetry_metric_label(field):
    return {
        "temperature.gpu": "GPU temperature",
        "clocks.current.graphics": "graphics clock",
        "clocks.current.memory": "memory clock",
        "power.draw": "power draw",
    }.get(field, field)


def telemetry_phase_label(artifact_name):
    phase = artifact_name.removeprefix("gds-replay-gpu-telemetry-")
    return phase.replace("-", " ")


def replay_phase_label(phase_name, phase_label=None):
    if phase_label:
        return phase_label
    return str(phase_name or "").replace("_", "-")


def strongest_compare_breadcrumb(compare_obj, compare_relpath):
    performance = (compare_obj.get("differences") or {}).get("gds_replay_performance") or {}
    performance_phases = performance.get("phases") or []
    good_node = compare_obj.get("good_node") or "peer"

    best_phase = None
    for phase in performance_phases:
        throughput = (phase.get("metrics") or {}).get("throughput_gib_s") or {}
        delta_pct = parse_float(throughput.get("delta_pct"))
        if delta_pct is None:
            continue
        score = abs(delta_pct)
        if best_phase is None or score > best_phase["score"]:
            best_phase = {
                "score": score,
                "phase": phase,
                "throughput_delta_pct": delta_pct,
                "latency_delta_pct": parse_float(((phase.get("metrics") or {}).get("avg_latency_usecs") or {}).get("delta_pct")),
            }

    if best_phase is not None:
        phase = best_phase["phase"]
        phase_text = replay_phase_label(phase.get("phase"), phase.get("label"))
        throughput_delta_pct = best_phase["throughput_delta_pct"]
        throughput_direction = "higher" if throughput_delta_pct > 0 else "lower"
        breadcrumb = (
            f"A/B diagnostic compare vs {good_node}: {phase_text} "
            f"{abs(throughput_delta_pct):.1f}% {throughput_direction} throughput"
        )
        latency_delta_pct = best_phase["latency_delta_pct"]
        if latency_delta_pct is not None:
            latency_direction = "higher" if latency_delta_pct > 0 else "lower"
            breadcrumb += f" and {abs(latency_delta_pct):.1f}% {latency_direction} latency"
        breadcrumb += f"; see {compare_relpath}"
        return breadcrumb

    artifacts = (compare_obj.get("differences") or {}).get("structured_artifacts", {}).get("artifacts") or []
    telemetry_artifacts = [item for item in artifacts if (item.get("artifact") or "").startswith("gds-replay-gpu-telemetry-")]
    if not telemetry_artifacts:
        return None

    best = None
    for artifact in telemetry_artifacts:
        for diff in artifact.get("differences") or []:
            bad_value = parse_float(diff.get("bad_value"))
            good_value = parse_float(diff.get("good_value"))
            if bad_value is None or good_value is None:
                continue
            score = abs(bad_value - good_value)
            if best is None or score > best["score"]:
                best = {
                    "score": score,
                    "artifact": artifact["artifact"],
                    "field": diff.get("field") or "",
                    "bad_value": bad_value,
                    "good_value": good_value,
                }

    if best is None:
        if compare_obj.get("comparison_status") == "no-material-differences":
            return f"A/B diagnostic compare vs {good_node}: no material replay or GPU telemetry delta detected; see {compare_relpath}"
        for artifact in telemetry_artifacts:
            differences = artifact.get("differences") or []
            if differences:
                first = differences[0]
                return (
                    f"A/B diagnostic compare vs {good_node}: "
                    f"{telemetry_phase_label(artifact['artifact'])} telemetry differs at {first.get('field')}; "
                    f"see {compare_relpath}"
                )
        return None

    field = best["field"]
    metric_field, _, stat_name = field.rpartition(".")
    stat_label = "mean" if stat_name == "mean" else "peak"
    delta = best["bad_value"] - best["good_value"]
    direction = "higher" if delta > 0 else "lower"
    return (
        f"A/B diagnostic compare vs {good_node}: "
        f"{telemetry_phase_label(best['artifact'])} {telemetry_metric_label(metric_field)} {stat_label} "
        f"{abs(delta):.1f} {direction} ({best['bad_value']:.1f} vs {best['good_value']:.1f}); "
        f"see {compare_relpath}"
    )


def ingest_node_debug_compares(nodes, report_dir, repo_root, cluster):
    for path in sorted(report_dir.glob(f"diagnostic-compare-{cluster}-*-vs-*.json")):
        try:
            compare_obj = load_json(path)
        except Exception:
            continue
        bad_node = compare_obj.get("bad_node")
        if not bad_node or bad_node not in nodes:
            continue
        compare_relpath = relpath(path, repo_root)
        note = strongest_compare_breadcrumb(compare_obj, compare_relpath)
        if not note:
            continue
        item = ensure_node(nodes, bad_node)
        add_note(item, note)
        add_evidence(item, compare_relpath)


def ingest_topology(nodes, path, repo_root):
    text = load_markdown(path)
    if not text:
        return
    table = first_primary_table(text)
    if not table:
        return

    rel = relpath(path, repo_root)
    for row in table["rows"]:
        node = row.get("Node")
        if not node:
            continue
        item = ensure_node(nodes, node)
        status = normalize_status(row.get("Status"))
        item["checks"]["gpu-topology"] = {
            "status": status,
            "slurm": row.get("Slurm") or "-",
            "gpus": row.get("GPUs") or "-",
            "expected": row.get("Expected") or "-",
            "notes": row.get("Notes") or "",
            "dashboard_path": rel,
        }
        add_evidence(item, rel)
        add_slurm_state(item, row.get("Slurm") or "")
        if status not in {"passed", "skipped"}:
            add_headline(item, "topology issue")
            add_finding(item, f"GPU topology is {status}.")
            add_note(item, "Inspect GPU inventory, topology capture, CPU affinity, and NIC consistency.")


def ingest_gds(nodes, path, repo_root):
    text = load_markdown(path)
    if not text:
        return
    table = first_primary_table(text)
    if not table:
        return

    rel = relpath(path, repo_root)
    anomalies = analyze_gds_anomalies(text)
    for row in table["rows"]:
        node = row.get("Node")
        if not node:
            continue
        item = ensure_node(nodes, node)
        status = normalize_status(row.get("Status"))
        item["checks"]["gds"] = {
            "status": status,
            "slurm": row.get("Slurm") or "-",
            "samples": row.get("Samples") or "-",
            "passes": row.get("Passes") or "-",
            "read_med": (
                row.get("Sequential Read med")
                or row.get("Read med")
                or row.get("Sequential Read GiB/s")
                or row.get("Read GiB/s")
                or "-"
            ),
            "write_med": (
                row.get("Sequential Write med")
                or row.get("Write med")
                or row.get("Sequential Write GiB/s")
                or row.get("Write GiB/s")
                or "-"
            ),
            "dashboard_path": rel,
            "anomaly_count": anomalies.get(node, {}).get("count", 0),
            "severe_count": anomalies.get(node, {}).get("severe", 0),
        }
        add_evidence(item, rel)
        add_slurm_state(item, row.get("Slurm") or "")
        if status not in {"passed", "skipped"}:
            add_headline(item, f"GDS {status}")
            add_finding(item, f"GDS row is {status} ({row.get('Passes') or '-'} passes).")
            add_note(item, "Inspect storage path, filesystem contention, local NVMe path, NUMA placement, and kernel logs.")

    for node, anomaly in anomalies.items():
        item = ensure_node(nodes, node)
        if anomaly["severe"] > 0:
            add_headline(item, "severe GDS outlier")
            add_finding(item, f"GDS has {anomaly['severe']} severe-low anomaly row(s).")
            add_note(item, "Inspect storage path, local NVMe path, filesystem jitter, NUMA placement, and kernel logs.")
        elif anomaly["count"] >= 2:
            add_headline(item, "repeated GDS anomaly")
            add_finding(item, f"GDS has {anomaly['count']} anomaly rows across {len(unique_sorted(anomaly['metrics']))} metric(s).")
            add_note(item, "Inspect storage throughput consistency and filesystem contention.")


def ingest_nccl_suite(nodes, path, repo_root):
    text = load_markdown(path)
    if not text:
        return
    table = nccl_suite_table(text)
    if not table:
        return

    rel = relpath(path, repo_root)
    for row in table["rows"]:
        group = (row.get("Entity") or "").strip().strip("`").strip()
        group_nodes = split_nodes(group)
        if not group_nodes:
            continue
        status = normalize_status(row.get("Status"))
        scale = (row.get("Scale") or "-").strip().strip("`").strip()
        op = (row.get("Op") or "-").strip().strip("`").strip()
        record = {
            "scale": scale,
            "group": group,
            "op": op,
            "status": status,
            "profile": (row.get("Profile") or "-").strip().strip("`").strip(),
            "largest_busbw": row.get("Largest busbw") or "-",
            "wrong": row.get("Wrong") or "-",
            "dashboard_path": rel,
        }
        for node in group_nodes:
            item = ensure_node(nodes, node)
            suite = item["checks"]["nccl-suite"]
            suite.setdefault("groups", []).append(record)
            add_evidence(item, rel)
            if status not in {"passed", "skipped"}:
                add_headline(item, f"NCCL suite {scale} {status}")
                add_finding(item, f"NCCL suite `{scale}` `{op}` group `{group}` is {status}.")
                add_note(item, "Inspect NCCL rank-per-GPU scale evidence, GPU/NIC affinity, transport warnings, and kernel logs.")


def finalize_nccl_suite(nodes):
    for item in nodes.values():
        groups = item["checks"]["nccl-suite"].get("groups", [])
        if not groups:
            if all(
                item["checks"][key].get("status") == "skipped"
                for key in ("gpu-topology", "gds")
            ):
                item["checks"]["nccl-suite"]["status"] = "skipped"
            else:
                item["checks"]["nccl-suite"]["status"] = "missing"
            item["checks"]["nccl-suite"]["summary"] = "-"
            continue

        status = "passed"
        scales = []
        passed = 0
        for group in groups:
            group_status = "degraded" if group["status"] == "missing" else group["status"]
            status = choose_status(status, group_status, DIRECT_STATUS_ORDER)
            scales.append(group["scale"])
            if group["status"] == "passed":
                passed += 1
        item["checks"]["nccl-suite"]["status"] = status
        item["checks"]["nccl-suite"]["summary"] = ",".join(unique_sorted(scales))
        item["checks"]["nccl-suite"]["samples"] = str(len(groups))
        item["checks"]["nccl-suite"]["passes"] = f"{passed}/{len(groups)}"


def finalize_node_status(item, cluster):
    direct_status = "skipped"
    saw_active = False
    saw_missing = False
    direct_keys = ["gpu-topology", "gds", "nccl-suite"]

    for key in direct_keys:
        status = item["checks"][key].get("status", "missing")
        if status not in {"skipped", "missing"}:
            saw_active = True
        if status == "missing":
            saw_missing = True
        else:
            direct_status = choose_status(direct_status, status, DIRECT_STATUS_ORDER)

    if not saw_active and all(item["checks"][key].get("status") == "skipped" for key in direct_keys):
        item["status"] = "skipped"
        return

    item["status"] = "passed"
    if direct_status == "failed":
        item["status"] = "failed"
        return
    if direct_status in {"degraded", "unknown"}:
        item["status"] = "degraded" if direct_status == "degraded" else "unknown"
        return
    if saw_missing:
        item["status"] = "degraded"
        return

    gds = item["checks"]["gds"]
    if gds.get("severe_count", 0) > 0:
        item["status"] = "degraded"
        return
    if gds.get("anomaly_count", 0) >= 2:
        item["status"] = "degraded"
        return


def final_headline(item):
    if item["headlines"]:
        return item["headlines"][0]
    if item["status"] == "skipped":
        return "skipped today"
    if item["status"] == "passed":
        return "no node-level concerns"
    return item["status"]


def recommended_debug_profiles(item, cluster):
    profiles = []
    reasons = []

    topology = item["checks"]["gpu-topology"]
    if topology.get("status") not in {"passed", "skipped", "missing"}:
        profiles.append("topology")
        reasons.append("topology evidence is non-passing")

    gds = item["checks"]["gds"]
    if gds.get("status") not in {"passed", "skipped", "missing"} or gds.get("severe_count", 0) > 0 or gds.get("anomaly_count", 0) >= 2:
        profiles.append("storage")
        if gds.get("severe_count", 0) > 0:
            reasons.append("GDS has severe-low anomaly evidence")
        elif gds.get("anomaly_count", 0) >= 2:
            reasons.append("GDS has repeated anomaly evidence")
        else:
            reasons.append("GDS evidence is non-passing")

    nccl_suite = item["checks"]["nccl-suite"]
    if nccl_suite.get("status") not in {"passed", "skipped", "missing"}:
        groups = nccl_suite.get("groups") or []
        actionable_groups = [
            group
            for group in groups
            if group.get("status") not in {"passed", "skipped", "missing"}
        ]
        if not actionable_groups:
            return unique_sorted(profiles), reasons
        bad_scales = {
            str(group.get("scale") or "-")
            for group in actionable_groups
        }
        if not bad_scales or "1n" in bad_scales:
            profiles.append("gpu-local")
            reasons.append("NCCL suite 1-node rank-per-GPU evidence is non-passing")
        if not bad_scales or any(scale != "1n" for scale in bad_scales):
            profiles.append("rdma")
            reasons.append("NCCL suite multi-node rank-per-GPU evidence is non-passing")

    return unique_sorted(profiles), reasons


def profile_candidate_ok(item, profile):
    if item["status"] != "passed":
        return False

    if profile == "storage":
        gds = item["checks"]["gds"]
        return (
            gds.get("status") == "passed"
            and gds.get("severe_count", 0) == 0
            and gds.get("anomaly_count", 0) < 2
        )

    if profile == "gpu-local":
        nccl_suite = item["checks"]["nccl-suite"]
        return nccl_suite.get("status") == "passed"

    if profile == "rdma":
        nccl_suite = item["checks"]["nccl-suite"]
        return nccl_suite.get("status") == "passed"

    if profile == "topology":
        topology = item["checks"]["gpu-topology"]
        return topology.get("status") == "passed"

    return False


def profile_rank_metric(item, profile):
    if profile == "storage":
        gds = item["checks"]["gds"]
        return float(gds.get("anomaly_count", 0))
    if profile == "gpu-local":
        return 0.0
    if profile in {"rdma", "topology"}:
        return 0.0
    return 0.0


def profile_metric_label(profile):
    return {
        "storage": "GDS anomaly count",
        "gpu-local": "NCCL suite health",
        "rdma": "NCCL suite health",
        "topology": "topology health",
    }.get(profile, profile)


def median_metric(candidates, profile):
    values = [profile_rank_metric(item, profile) for item in candidates if profile_candidate_ok(item, profile)]
    if not values:
        return 0.0
    return float(median(values))


def assign_peer_recommendations(nodes):
    healthy_pool = [
        item for item in nodes
        if item["status"] == "passed" and not item.get("recommended_debug_profiles")
    ]

    for item in nodes:
        item.pop("recommended_peer_nodes", None)
        item.pop("recommended_peer_reasons", None)

    profile_medians = {
        profile: median_metric(healthy_pool, profile)
        for profile in ("storage", "gpu-local", "rdma", "topology")
    }

    for item in nodes:
        profiles = item.get("recommended_debug_profiles") or []
        if item["status"] not in {"failed", "degraded", "unknown"} or not profiles:
            continue

        candidates = []
        for candidate in healthy_pool:
            if candidate["node"] == item["node"]:
                continue
            if not all(profile_candidate_ok(candidate, profile) for profile in profiles):
                continue
            score_parts = [abs(profile_rank_metric(candidate, profile) - profile_medians[profile]) for profile in profiles]
            candidates.append((sum(score_parts), max(score_parts) if score_parts else 0.0, candidate["node"], candidate))

        candidates.sort(key=lambda entry: (entry[0], entry[1], entry[2]))
        item["recommended_peer_nodes"] = [candidate["node"] for _, _, _, candidate in candidates]

        if item["recommended_peer_nodes"]:
            metric_labels = unique_sorted(profile_metric_label(profile) for profile in profiles)
            profile_list = ", ".join(profiles)
            item["recommended_peer_reasons"] = [
                f"same-day passed peers for {profile_list}, ordered by distance to healthy median across {', '.join(metric_labels)}"
            ]
        else:
            item["recommended_peer_reasons"] = [
                f"no same-day passed peers satisfied profiles {', '.join(profiles)}"
            ]


def report_status(nodes):
    statuses = [item["status"] for item in nodes]
    if "failed" in statuses:
        return "failed"
    if "degraded" in statuses:
        return "degraded"
    if "unknown" in statuses:
        return "unknown"
    if statuses and all(status == "skipped" for status in statuses):
        return "skipped"
    return "passed"


def build_report(results_root, date_value, cluster):
    repo_root = repo_root_from_results_root(results_root)
    report_dir = results_root / "reports" / date_value
    files = evidence_files(cluster)
    campaign_path = report_dir / files["campaign"].format(date=date_value)
    campaign = load_json(campaign_path) if campaign_path.exists() else None

    nodes = {}
    ingest_topology(nodes, report_dir / files["gpu-topology"], repo_root)
    ingest_gds(nodes, report_dir / files["gds"], repo_root)
    ingest_nccl_suite(nodes, report_dir / files["nccl-suite"], repo_root)
    if cluster_supports_node_debug(cluster):
        ingest_node_debug_compares(nodes, report_dir, repo_root, cluster)

    if not nodes:
        raise RuntimeError(f"no committed node evidence found for date={date_value} cluster={cluster}")

    finalize_nccl_suite(nodes)
    ordered = []
    for node in sorted(nodes):
        item = nodes[node]
        finalize_node_status(item, cluster)
        profiles, reasons = recommended_debug_profiles(item, cluster)
        item["recommended_debug_profiles"] = profiles
        item["recommended_debug_reasons"] = reasons
        item["headline"] = final_headline(item)
        ordered.append(item)

    assign_peer_recommendations(ordered)
    node_debug_followup = build_node_debug_followup(results_root, date_value, cluster, repo_root, ordered)
    candidate_report = campaign is None
    if candidate_report and node_debug_followup.get("supported"):
        node_debug_followup = {
            **node_debug_followup,
            "required": False,
            "closeout_status": "not-required",
            "suspect_nodes": [],
            "missing_compare_suspects": [],
            "suspect_profiles": {},
            "suspect_top_peers": {},
        }

    findings = []
    next_actions = []
    for item in ordered:
        if item["status"] in {"failed", "degraded", "unknown"}:
            findings.append(f"{item['node']} is {item['status']}: {item['headline']}.")
        for finding in item["findings"]:
            if finding not in findings:
                findings.append(f"{item['node']}: {finding}")
        for note in item["operator_notes"]:
            if note.startswith("A/B diagnostic compare "):
                continue
            if note not in next_actions:
                next_actions.append(note)

    if not next_actions:
        next_actions.append("No node-level follow-up required from committed evidence.")

    if node_debug_followup["required"]:
        suspects_csv = ", ".join(node_debug_followup["suspect_nodes"])
        closeout_status = node_debug_followup["closeout_status"]
        if closeout_status == "pending":
            next_actions.insert(
                0,
                f"Run same-day diagnostic closeout for suspect nodes: {suspects_csv}. Collect from the by-node report, render diagnostic, write compare pages, archive diagnostic, and re-render nodes/campaign dashboards.",
            )
        elif closeout_status == "partial":
            missing = node_debug_followup["missing_compare_suspects"]
            if missing:
                next_actions.insert(
                    0,
                    f"Finish same-day diagnostic closeout for suspect nodes: {suspects_csv}. Missing compare coverage for: {', '.join(missing)}.",
                )
            else:
                next_actions.insert(
                    0,
                    f"Finish same-day diagnostic closeout for suspect nodes: {suspects_csv}. Refresh summary, archive, or dashboard links before closing the day.",
                )

    benchmark_candidates = [item["node"] for item in ordered if item["status"] == "passed"]
    campaign_exclusions = [
        {
            "node": item["node"],
            "status": item["status"],
            "reason": item["headline"],
        }
        for item in ordered
        if item["status"] != "passed"
    ]
    overall_status = report_status([item for item in ordered])
    if candidate_report and benchmark_candidates:
        overall_status = "passed-filtered"

    return {
        "schema_version": 2,
        "report_id": f"{cluster}-nodes-{date_value}",
        "report_type": "benchmark candidates" if candidate_report else "verification nodes",
        "cluster": cluster,
        "date": date_value,
        "generated_at_utc": utc_now(),
        "status": overall_status,
        "campaign_path": relpath(campaign_path, repo_root) if campaign_path.exists() else None,
        "node_debug_followup": node_debug_followup,
        "acceptable_candidates": benchmark_candidates,
        "benchmark_candidates": benchmark_candidates,
        "benchmark_exclusions": campaign_exclusions,
        "campaign_exclusions": campaign_exclusions,
        "nodes": ordered,
        "findings": findings,
        "next_actions": next_actions,
    }


def truncate(value, max_len):
    value = str(value or "")
    if len(value) <= max_len:
        return value
    return value[: max_len - 3] + "..."


def render_ascii(report):
    rows = []
    for item in report["nodes"]:
        row = {
            "node": item["node"],
            "status": item["status"],
            "peer": (item.get("recommended_peer_nodes") or ["-"])[0],
            "topology": item["checks"]["gpu-topology"].get("status", "missing"),
            "gds": item["checks"]["gds"].get("status", "missing"),
            "nccl_suite": item["checks"]["nccl-suite"].get("status", "missing"),
            "headline": truncate(item["headline"], 34),
        }
        rows.append(row)

    columns = [
        ("node", "Node"),
        ("status", "Status"),
        ("peer", "Top Peer"),
        ("topology", "Topology"),
        ("gds", "GDS"),
        ("nccl_suite", "NCCL Suite"),
        ("headline", "Headline"),
    ]
    widths = {
        key: max(len(label), *(len(str(row.get(key, ""))) for row in rows)) if rows else len(label)
        for key, label in columns
    }
    lines = [
        f"AICR Node Summary  {report['cluster']}  {report['date']}",
        f"Type: {report.get('report_type', 'verification nodes')}",
        f"Status: {report['status'].upper()}   Nodes: {len(report['nodes'])}",
        f"Acceptable candidates: {len(report.get('acceptable_candidates') or report.get('benchmark_candidates') or [])}",
    ]
    followup = report.get("node_debug_followup") or {}
    if followup.get("supported"):
        lines.append(
            f"Diagnostic follow-up: {followup.get('closeout_status', 'unknown').upper()}   Suspects: {len(followup.get('suspect_nodes') or [])}"
        )
    lines.extend([
        "",
        "  ".join(label.ljust(widths[key]) for key, label in columns),
        "  ".join("-" * widths[key] for key, _ in columns),
    ])
    for row in rows:
        lines.append("  ".join(str(row.get(key, "")).ljust(widths[key]) for key, _ in columns))

    candidates = report.get("acceptable_candidates") or report.get("benchmark_candidates") or []
    exclusions = report.get("benchmark_exclusions") or report.get("campaign_exclusions") or []
    lines.extend(["", f"Acceptable candidates: {len(candidates)}"])
    lines.append(", ".join(candidates) if candidates else "- none")
    exclusion_label = "Retest / exclude before benchmark" if report.get("report_type") == "benchmark candidates" else "Retest / exclude for campaign"
    lines.extend(["", f"{exclusion_label}: {len(exclusions)}"])
    if exclusions:
        lines.extend(f"- {item['node']}: {item['status']} ({item['reason']})" for item in exclusions[:12])
        if len(exclusions) > 12:
            lines.append(f"- ... {len(exclusions) - 12} more")
    else:
        lines.append("- none")

    lines.extend(["", "Findings:"])
    if report["findings"]:
        lines.extend(f"- {finding}" for finding in report["findings"][:10])
    else:
        lines.append("- none")

    lines.extend(["", "Next actions:"])
    lines.extend(f"- {item}" for item in report["next_actions"])
    return "\n".join(lines)


def relative_link(target_path, report_dir, repo_root, label):
    if not target_path:
        return "-"
    target_abs = repo_root / target_path
    rel = os.path.relpath(target_abs.resolve(), report_dir.resolve()).replace(os.sep, "/")
    href = rel if rel.startswith("..") else f"./{rel}"
    return f"[{label}]({href})"


def node_debug_archive_manifest_path(results_root, date_value, cluster, repo_root):
    if not cluster_supports_node_debug(cluster):
        return None
    path = results_root / "archives" / date_value / f"aicr-results-{date_value}-{cluster}-diagnostic.json"
    if path.exists():
        return relpath(path, repo_root)
    return None


def node_debug_summary_paths(results_root, date_value, cluster, repo_root):
    if not cluster_supports_node_debug(cluster):
        return {"markdown": None, "json": None}
    report_dir = results_root / "reports" / date_value
    markdown_path = report_dir / f"diagnostic-{cluster}-{date_value}.md"
    json_path = report_dir / f"diagnostic-{cluster}-{date_value}.json"
    return {
        "markdown": relpath(markdown_path, repo_root) if markdown_path.exists() else None,
        "json": relpath(json_path, repo_root) if json_path.exists() else None,
    }


def node_debug_compare_paths(results_root, date_value, cluster, repo_root):
    if not cluster_supports_node_debug(cluster):
        return []
    report_dir = results_root / "reports" / date_value
    paths = []
    for path in sorted(report_dir.glob(f"diagnostic-compare-{cluster}-*-vs-*.md")):
        paths.append(relpath(path, repo_root))
    return paths


def parse_compare_suspect_node(compare_path, cluster):
    stem = Path(compare_path).stem
    prefix = f"diagnostic-compare-{cluster}-"
    if not stem.startswith(prefix):
        return None
    remainder = stem[len(prefix):]
    bad_node, _, _ = remainder.partition("-vs-")
    return bad_node or None


def build_node_debug_followup(results_root, date_value, cluster, repo_root, nodes):
    if not cluster_supports_node_debug(cluster):
        return {
            "supported": False,
            "required": False,
            "closeout_status": "unsupported",
            "suspect_nodes": [],
            "summary_markdown_path": None,
            "summary_json_path": None,
            "compare_markdown_paths": [],
            "archive_manifest_path": None,
            "missing_compare_suspects": [],
            "suspect_profiles": {},
            "suspect_top_peers": {},
        }

    suspect_nodes = []
    suspect_profiles = {}
    suspect_top_peers = {}
    for item in nodes:
        profiles = item.get("recommended_debug_profiles") or []
        if item["status"] in {"failed", "degraded", "unknown"} and profiles:
            suspect_nodes.append(item["node"])
            suspect_profiles[item["node"]] = profiles
            suspect_top_peers[item["node"]] = (item.get("recommended_peer_nodes") or [None])[0]

    summary_paths = node_debug_summary_paths(results_root, date_value, cluster, repo_root)
    compare_paths = node_debug_compare_paths(results_root, date_value, cluster, repo_root)
    archive_path = node_debug_archive_manifest_path(results_root, date_value, cluster, repo_root)
    compared_suspects = {
        suspect
        for suspect in (parse_compare_suspect_node(path, cluster) for path in compare_paths)
        if suspect
    }
    missing_compare_suspects = [node for node in suspect_nodes if node not in compared_suspects]

    required = bool(suspect_nodes)
    summary_present = bool(summary_paths["markdown"] and summary_paths["json"])
    archive_present = bool(archive_path)
    compare_complete = not missing_compare_suspects

    if not required:
        closeout_status = "not-needed"
    elif summary_present and compare_complete and archive_present:
        closeout_status = "complete"
    elif summary_present or compare_paths or archive_present:
        closeout_status = "partial"
    else:
        closeout_status = "pending"

    return {
        "supported": True,
        "required": required,
        "closeout_status": closeout_status,
        "suspect_nodes": suspect_nodes,
        "summary_markdown_path": summary_paths["markdown"],
        "summary_json_path": summary_paths["json"],
        "compare_markdown_paths": compare_paths,
        "archive_manifest_path": archive_path,
        "missing_compare_suspects": missing_compare_suspects,
        "suspect_profiles": suspect_profiles,
        "suspect_top_peers": suspect_top_peers,
    }


def render_markdown(report, results_root):
    repo_root = repo_root_from_results_root(results_root)
    report_dir = results_root / "reports" / report["date"]
    files = evidence_files(report["cluster"])
    node_debug_archive_path = node_debug_archive_manifest_path(results_root, report["date"], report["cluster"], repo_root)
    node_debug_summary = node_debug_summary_paths(results_root, report["date"], report["cluster"], repo_root)
    node_debug_compare = node_debug_compare_paths(results_root, report["date"], report["cluster"], repo_root)
    followup = report.get("node_debug_followup") or {}
    campaign_link_path = None
    if report.get("campaign_path"):
        campaign_json_abs = repo_root / report["campaign_path"]
        if campaign_json_abs.exists():
            campaign_md_abs = campaign_json_abs.with_suffix(".md")
            if campaign_md_abs.exists():
                campaign_link_path = relpath(campaign_md_abs, repo_root)
            else:
                campaign_link_path = report["campaign_path"]
    campaign_link = relative_link(campaign_link_path, report_dir, repo_root, "campaign")
    lines = [
        f"# AICR Node Summary: {report['cluster']} {report['date']}",
        "",
        "## Related Reports",
        "",
        f"- Campaign summary: {campaign_link}",
        f"- Report type: `{report.get('report_type', 'verification nodes')}`",
    ]
    if cluster_supports_node_debug(report["cluster"]):
        if node_debug_archive_path:
            lines.append(f"- Diagnostic archive manifest: {relative_link(node_debug_archive_path, report_dir, repo_root, 'manifest')}")
        if node_debug_summary["markdown"]:
            lines.append(f"- Diagnostic summary: {relative_link(node_debug_summary['markdown'], report_dir, repo_root, 'dashboard')}")
    else:
        lines.append("- Diagnostic: not yet supported for this cluster.")
    lines.extend([
        "",
        "## Node Status",
        "",
    ])
    lines.extend([
        "| Node | Status | Top peer | Topology | GDS | NCCL suite | Headline |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ])
    for item in report["nodes"]:
        cells = [
            markdown_escape(item["node"]),
            markdown_escape(item["status"]),
            markdown_escape((item.get("recommended_peer_nodes") or ["-"])[0]),
            markdown_escape(fmt_check_summary(item["checks"]["gpu-topology"])),
            markdown_escape(fmt_check_summary(item["checks"]["gds"])),
            markdown_escape(fmt_check_summary(item["checks"]["nccl-suite"])),
        ]
        cells.append(markdown_escape(item["headline"]))
        lines.append("| " + " | ".join(cells) + " |")

    candidates = report.get("acceptable_candidates") or report.get("benchmark_candidates") or []
    lines.extend(["", "## Acceptable Candidates", ""])
    lines.append(f"- Count: `{len(candidates)}`")
    if candidates:
        lines.append(f"- Strict passed nodes: `{', '.join(candidates)}`")
    else:
        lines.append("- Strict passed nodes: none")
    lines.append("- Source: by-node JSON entries whose overall status is `passed`.")
    lines.append("- Use: candidate pool for rerunning full benchmark deliverables.")

    exclusions = report.get("benchmark_exclusions") or report.get("campaign_exclusions") or []
    exclusion_heading = "Retest / Exclude Before Benchmark" if report.get("report_type") == "benchmark candidates" else "Retest / Exclude For Campaign"
    lines.extend(["", f"## {exclusion_heading}", ""])
    if exclusions:
        lines.extend([
            "| Node | Status | Reason |",
            "| --- | --- | --- |",
        ])
        for item in exclusions:
            lines.append(
                f"| `{markdown_escape(item['node'])}` | `{markdown_escape(item['status'])}` | {markdown_escape(item['reason'])} |"
            )
    else:
        lines.append("- none")

    lines.extend(["", "## Major Findings", ""])
    if report["findings"]:
        lines.extend(f"- {finding}" for finding in report["findings"])
    else:
        lines.append("- none")

    if followup.get("supported"):
        lines.extend(["", "## Diagnostic Follow-Up", ""])
        lines.append(f"- Closeout status: `{followup.get('closeout_status', 'unknown')}`")
        if followup.get("required"):
            lines.append(f"- Suspect nodes: `{', '.join(followup.get('suspect_nodes') or [])}`")
            if followup.get("missing_compare_suspects"):
                lines.append(f"- Missing compare coverage: `{', '.join(followup['missing_compare_suspects'])}`")
        else:
            lines.append("- No same-day suspect nodes currently require diagnostic collection.")

    investigate = [item for item in report["nodes"] if item["status"] in {"failed", "degraded", "unknown"}]
    lines.extend(["", "## Nodes To Investigate", ""])
    if investigate:
        for item in investigate:
            lines.append(f"- `{item['node']}` is `{item['status']}`: {item['headline']}.")
    else:
        lines.append("- none")

    lines.extend(["", "## Operator Notes", ""])
    if investigate:
        for item in investigate:
            notes = list(item["operator_notes"])
            if item.get("recommended_peer_nodes"):
                peer_preview = ", ".join(item["recommended_peer_nodes"][:3])
                notes.append(
                    f"Peer candidates start with: {peer_preview}."
                )
            elif item.get("recommended_peer_reasons"):
                notes.append(item["recommended_peer_reasons"][0] + ".")
            if notes:
                lines.append(f"- `{item['node']}`: {' '.join(notes)}")
    else:
        lines.append("- none")

    lines.extend(["", "## Evidence Links", ""])
    lines.append(f"- Campaign: {campaign_link}")
    if cluster_supports_node_debug(report["cluster"]):
        if node_debug_archive_path:
            lines.append(f"- Diagnostic archive manifest: {relative_link(node_debug_archive_path, report_dir, repo_root, 'manifest')}")
        if node_debug_summary["markdown"]:
            lines.append(f"- Diagnostic summary: {relative_link(node_debug_summary['markdown'], report_dir, repo_root, 'dashboard')}")
    for label, file_name in (
        ("GPU topology", files["gpu-topology"]),
        ("GDS", files["gds"]),
        ("NCCL suite", files["nccl-suite"]),
    ):
        path = results_root / "reports" / report["date"] / file_name
        if path.exists():
            lines.append(f"- {label}: {relative_link(relpath(path, repo_root), report_dir, repo_root, 'dashboard')}")

    lines.extend(["", "## Debug Artifacts", ""])
    if cluster_supports_node_debug(report["cluster"]) and node_debug_summary["markdown"]:
        lines.append(f"- Diagnostic summary: {relative_link(node_debug_summary['markdown'], report_dir, repo_root, 'dashboard')}")
    elif cluster_supports_node_debug(report["cluster"]):
        lines.append("- Diagnostic summary: none")
    else:
        lines.append("- Diagnostic is not yet supported for this cluster.")
    if cluster_supports_node_debug(report["cluster"]):
        if node_debug_summary["json"]:
            lines.append(f"- Diagnostic JSON: {relative_link(node_debug_summary['json'], report_dir, repo_root, 'json')}")
        if node_debug_compare:
            for compare_path in node_debug_compare:
                compare_name = Path(compare_path).stem.replace(f"diagnostic-compare-{report['cluster']}-", "")
                lines.append(f"- Diagnostic compare `{compare_name}`: {relative_link(compare_path, report_dir, repo_root, 'report')}")
        else:
            lines.append("- Diagnostic compare pages: none")
        if node_debug_archive_path:
            lines.append(f"- Diagnostic archive manifest: {relative_link(node_debug_archive_path, report_dir, repo_root, 'manifest')}")
        else:
            lines.append("- Diagnostic archive manifest: none")

    lines.extend([
        "",
        "## Notes On Semantics",
        "",
        "- This report is a date-scoped operator triage view, not the canonical pass/fail source of truth.",
        "- Child dashboards remain authoritative for per-check detail.",
        "- V2 reads committed dashboards and campaign JSON only; it does not require raw result trees.",
        "- Report-only anomalies do not change child pass/fail, but they can elevate node suspicion in this by-node view.",
        f"- Dashboard statistic and anomaly definitions: [Stats Explained]({REPORT_STATS_LINK}).",
    ])
    return "\n".join(lines) + "\n"


def write_outputs(report, results_root, markdown):
    report_dir = results_root / "reports" / report["date"]
    report_dir.mkdir(parents=True, exist_ok=True)
    stem = f"nodes-{report['cluster']}-{report['date']}"
    md_path = report_dir / f"{stem}.md"
    json_path = report_dir / f"{stem}.json"
    md_path.write_text(markdown, encoding="utf-8")
    json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    index_path = write_reports_index(results_root)
    return md_path, json_path, index_path


def main():
    parser = build_parser()
    args = parser.parse_args()
    try:
        date_value = resolve_date(args.date)
    except ValueError as exc:
        parser.error(str(exc))

    results_root = Path(args.results_root)
    if not results_root.is_absolute():
        results_root = Path.cwd() / results_root

    try:
        report = build_report(results_root, date_value, args.cluster)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    want_ascii = args.ascii or args.both or not args.markdown
    want_markdown = args.markdown or args.both

    if want_ascii:
        print(render_ascii(report))

    if want_markdown:
        markdown = render_markdown(report, results_root)
        if args.write:
            md_path, json_path, index_path = write_outputs(report, results_root, markdown)
            print(f"Wrote {md_path}", file=sys.stderr)
            print(f"Wrote {json_path}", file=sys.stderr)
            print(f"Wrote {index_path}", file=sys.stderr)
        else:
            print(markdown, end="")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
