#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path


SUPPORTED_CLUSTERS = ("b200", "rtxpro6000")
DASHBOARD_ONLY_CHECKS = ("gpu-topology", "gds", "nccl-suite")
DASHBOARD_ONLY_EXPECTED_COVERAGE = 4
DASHBOARD_ONLY_TYPE = "benchmark candidates"


def load_json(path):
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def markdown_escape(value):
    return str(value or "").replace("|", "\\|")


def coverage_text(item):
    coverage = item.get("coverage") or {}
    present = coverage.get("present")
    expected = coverage.get("expected")
    if present is None or expected is None:
        return "-"
    return f"{present}/{expected}"


def index_link(path, label):
    if not path:
        return "-"
    href = path.as_posix()
    if not href.startswith("."):
        href = f"./{href}"
    return f"[{label}]({href})"


def campaign_report_name(item):
    return f"campaign-{item.get('cluster')}-{item.get('date')}.md"


def node_report_name(cluster, date_value):
    return f"nodes-{cluster}-{date_value}.md"


def child_report_name(check, cluster):
    return f"{check}-{cluster}.md"


def rel_or_none(path, reports_dir):
    try:
        return path.relative_to(reports_dir)
    except ValueError:
        return None


def archive_manifest_present(results_root, date_value, cluster):
    archive_dir = results_root / "archives" / date_value
    if not archive_dir.exists():
        return False
    pattern = f"aicr-results-{date_value}-{cluster}*.json"
    return any(archive_dir.glob(pattern))


def dashboard_cell_has_status(text, statuses):
    for status in statuses:
        if re.search(rf"\|\s*`?{re.escape(status)}`?\s*\|", text):
            return True
    return False


def dashboard_has_enabled_preflight(text):
    return "GPU preflight filter: `enabled`" in text


def dashboard_only_status(text_by_check):
    gds_text = text_by_check.get("gds", "")
    nccl_text = text_by_check.get("nccl-suite", "")
    topology_text = text_by_check.get("gpu-topology", "")

    workload_bad_statuses = {"failed", "missing", "unknown"}
    if dashboard_cell_has_status(gds_text, workload_bad_statuses) or dashboard_cell_has_status(
        nccl_text,
        workload_bad_statuses,
    ):
        return "failed"

    if dashboard_has_enabled_preflight(gds_text) or dashboard_has_enabled_preflight(nccl_text):
        return "passed-filtered"

    if dashboard_cell_has_status(topology_text, {"failed", "skipped", "missing", "unknown"}):
        return "degraded"

    return "passed"


def dashboard_only_rows(results_root, reports_dir, campaign_keys):
    rows = []
    for date_dir in sorted(path for path in reports_dir.iterdir() if path.is_dir()):
        date_value = date_dir.name
        for cluster in SUPPORTED_CLUSTERS:
            if (date_value, cluster) in campaign_keys:
                continue

            child_paths = {
                check: date_dir / child_report_name(check, cluster)
                for check in DASHBOARD_ONLY_CHECKS
            }
            node_md_path = date_dir / node_report_name(cluster, date_value)
            if not all(path.exists() for path in child_paths.values()):
                continue

            text_by_check = {}
            for check, path in child_paths.items():
                try:
                    text_by_check[check] = path.read_text(encoding="utf-8")
                except OSError:
                    text_by_check[check] = ""

            present = len(child_paths)
            if archive_manifest_present(results_root, date_value, cluster):
                present += 1

            rows.append({
                "date": date_value,
                "cluster": cluster,
                "campaign_type": DASHBOARD_ONLY_TYPE,
                "status": dashboard_only_status(text_by_check),
                "coverage": f"{present}/{DASHBOARD_ONLY_EXPECTED_COVERAGE}",
                "campaign_report_link": "-",
                "node_report_link": index_link(rel_or_none(node_md_path, reports_dir), "report") if node_md_path.exists() else "-",
                "topology_link": index_link(rel_or_none(child_paths["gpu-topology"], reports_dir), "report"),
                "gds_link": index_link(rel_or_none(child_paths["gds"], reports_dir), "report"),
                "nccl_suite_link": index_link(rel_or_none(child_paths["nccl-suite"], reports_dir), "report"),
            })
    return rows


def results_index_rows(results_root):
    reports_dir = results_root / "reports"
    rows = []
    if not reports_dir.exists():
        return rows

    campaign_keys = set()
    for json_path in sorted(reports_dir.glob("*/campaign-*.json")):
        try:
            item = load_json(json_path)
        except (OSError, json.JSONDecodeError):
            continue

        date_value = item.get("date") or json_path.parent.name
        cluster = item.get("cluster") or "-"
        campaign_keys.add((date_value, cluster))
        campaign_type = item.get("campaign_type") or "-"
        campaign_md_path = json_path.parent / campaign_report_name(item)
        node_md_path = json_path.parent / node_report_name(cluster, date_value)
        topology_md_path = json_path.parent / child_report_name("gpu-topology", cluster)
        gds_md_path = json_path.parent / child_report_name("gds", cluster)
        nccl_suite_md_path = json_path.parent / child_report_name("nccl-suite", cluster)

        campaign_md_rel = rel_or_none(campaign_md_path, reports_dir)
        node_md_rel = rel_or_none(node_md_path, reports_dir)
        topology_md_rel = rel_or_none(topology_md_path, reports_dir)
        gds_md_rel = rel_or_none(gds_md_path, reports_dir)
        nccl_suite_md_rel = rel_or_none(nccl_suite_md_path, reports_dir)

        rows.append({
            "date": date_value,
            "cluster": cluster,
            "campaign_type": campaign_type,
            "status": item.get("status") or "unknown",
            "coverage": coverage_text(item),
            "campaign_report_link": index_link(campaign_md_rel, "report") if campaign_md_rel and campaign_md_path.exists() else "-",
            "node_report_link": index_link(node_md_rel, "report") if node_md_rel and node_md_path.exists() else "-",
            "topology_link": index_link(topology_md_rel, "report") if topology_md_rel and topology_md_path.exists() else "-",
            "gds_link": index_link(gds_md_rel, "report") if gds_md_rel and gds_md_path.exists() else "-",
            "nccl_suite_link": index_link(nccl_suite_md_rel, "report") if nccl_suite_md_rel and nccl_suite_md_path.exists() else "-",
        })

    rows.extend(dashboard_only_rows(results_root, reports_dir, campaign_keys))

    return sorted(
        rows,
        key=lambda row: (row["date"], row["cluster"], row["campaign_type"]),
        reverse=True,
    )


def rows_by_index_version(rows):
    v2_rows = []
    v1_rows = []
    for row in rows:
        if row.get("nccl_suite_link") != "-":
            v2_rows.append(row)
        else:
            v1_rows.append(row)
    return v2_rows, v1_rows


def render_rows(rows):
    lines = [
        "| Date | Cluster | Type | Status | Coverage | Campaign | Nodes | GPU Topology | GDS | NCCL Suite |",
        "| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- |",
    ]
    if rows:
        for row in rows:
            lines.append(
                "| "
                + " | ".join([
                    markdown_escape(row["date"]),
                    markdown_escape(row["cluster"]),
                    markdown_escape(row["campaign_type"]),
                    markdown_escape(row["status"]),
                    markdown_escape(row["coverage"]),
                    row["campaign_report_link"],
                    row["node_report_link"],
                    row["topology_link"],
                    row["gds_link"],
                    row["nccl_suite_link"],
                ])
                + " |"
            )
    else:
        lines.append("| - | - | - | - | - | - | - | - | - | - |")
    return lines


def render_reports_index(results_root):
    rows = results_index_rows(results_root)
    v2_rows, v1_rows = rows_by_index_version(rows)
    lines = [
        "# System Verification Reports by Date",
        "",
        "## v2 System Verification",
        "",
        "Current reports use the GPU topology, GDS, NCCL suite, and archive-manifest evidence surface.",
        "Dashboard-only benchmark candidate rows may omit campaign reports; `passed-filtered` means workload dashboards passed after topology-driven GPU preflight filtering.",
        "",
    ]
    lines.extend(render_rows(v2_rows))
    lines.extend([
        "",
        "## v1 Legacy Verification",
        "",
        "Older reports predate the NCCL suite system-verification surface and may use legacy coverage counts.",
        "",
    ])
    lines.extend(render_rows(v1_rows))
    return "\n".join(lines) + "\n"


def write_reports_index(results_root):
    reports_dir = results_root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    index_path = reports_dir / "README.md"
    index_path.write_text(render_reports_index(results_root), encoding="utf-8")
    return index_path


def build_parser():
    parser = argparse.ArgumentParser(description="Render the system verification reports index.")
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--write", action="store_true")
    return parser


def main():
    args = build_parser().parse_args()
    results_root = Path(args.results_root)
    if args.write:
        path = write_reports_index(results_root)
        print(path)
    else:
        print(render_reports_index(results_root), end="")


if __name__ == "__main__":
    main()
