#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional

from report_index import write_reports_index


STATUS_VALUES = {"passed", "degraded", "failed", "skipped", "missing", "unknown"}
CHECK_STATUS_RANK = {
    "failed": 5,
    "degraded": 4,
    "missing": 3,
    "unknown": 2,
    "passed": 1,
    "skipped": 0,
}

SUPPORTED_CLUSTERS = ("b200", "rtxpro6000")
CLUSTER_LABELS = {
    "b200": "B200",
    "rtxpro6000": "RTX PRO 6000",
}


@dataclass(frozen=True)
class CheckSpec:
    check_id: str
    label: str
    dashboard_name: str
    manifest_dir: str
    manifest_pattern: str
    kind: str
    nodes_per_job: Optional[int] = None
    gpus_per_job: Optional[int] = None


def verification_check_specs(cluster):
    checks = [
        CheckSpec(
            "gpu-topology",
            "GPU topology",
            f"gpu-topology-{cluster}.md",
            "gpu-topology",
            f"*-gpu-topology-{cluster}.json",
            "gpu-topology",
        ),
        CheckSpec("gds", "GDS", f"gds-{cluster}.md", "gds", f"*-gds-{cluster}.json", "gds"),
        CheckSpec(
            "nccl-suite",
            "NCCL suite",
            f"nccl-suite-{cluster}.md",
            "nccl-suite",
            f"*-nccl-suite-{cluster}.json",
            "nccl-suite",
        ),
    ]

    return tuple(checks)


def cluster_supports_node_debug(cluster):
    return cluster in {"b200", "rtxpro6000"}


def build_parser():
    parser = argparse.ArgumentParser(description="Render AICR campaign dashboards from committed artifacts.")
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--date", required=True, help="ISO date, today, or yesterday")
    parser.add_argument("--cluster", required=True, choices=SUPPORTED_CLUSTERS)
    parser.add_argument("--campaign-type", default="verification", choices=["verification"])

    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--ascii", action="store_true")
    modes.add_argument("--markdown", action="store_true")
    modes.add_argument("--both", action="store_true")

    parser.add_argument("--write", action="store_true")
    return parser


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


def load_json(path):
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def repo_root_from_results_root(results_root):
    resolved = results_root.resolve()
    if resolved.name == "results":
        return resolved.parent
    return resolved.parent


def relpath(path, repo_root):
    if not path:
        return None
    try:
        return str(path.resolve().relative_to(repo_root.resolve()))
    except ValueError:
        return str(path)


def latest_match(root, pattern):
    if not root.exists():
        return None
    matches = sorted(root.glob(pattern))
    return matches[-1] if matches else None


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


def dashboard_table_for_check(spec, text):
    if spec.kind == "nccl-suite":
        return table_after_heading(text, "## Detailed Rows") or first_primary_table(text)
    return first_primary_table(text)


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


def normalized_status(value):
    value = (value or "").strip().strip("`").strip().lower()
    if value in {"pass", "ok"}:
        return "passed"
    if value in {"fail", "error"}:
        return "failed"
    if value in {"incomplete", "partial"}:
        return "degraded"
    if value in STATUS_VALUES:
        return value
    return "unknown"


def row_entity(row):
    return row.get("Entity") or row.get("Node Group") or row.get("Node") or row.get("Check") or "-"


def active_rows(rows):
    return [row for row in rows if normalized_status(row.get("Status")) != "skipped"]


def derive_check_status(rows):
    if not rows:
        return "unknown"

    statuses = [normalized_status(row.get("Status")) for row in rows]
    non_skipped = [status for status in statuses if status != "skipped"]

    if not non_skipped:
        return "skipped"
    if "failed" in non_skipped:
        return "failed"
    if "degraded" in non_skipped or "missing" in non_skipped:
        return "degraded"
    if "unknown" in non_skipped:
        return "unknown"
    return "passed"


def parse_ratio(value):
    value = (value or "").strip()
    match = re.match(r"^(\d+)\s*/\s*(\d+)$", value)
    if not match:
        return None
    return int(match.group(1)), int(match.group(2))


def manifest_repeat_count(manifest):
    if not manifest:
        return 1
    try:
        repeat_count = int(manifest.get("repeat_count", 1))
    except (TypeError, ValueError):
        return 1
    return max(repeat_count, 1)


def row_ratio_summary(rows_for_counts):
    sample_ratios = []
    pass_ratios = []
    for row in rows_for_counts:
        sample_ratio = parse_ratio(row.get("Samples"))
        pass_ratio = parse_ratio(row.get("Passes"))
        if sample_ratio:
            sample_ratios.append(sample_ratio)
        if pass_ratio:
            pass_ratios.append(pass_ratio)

    samples = "-"
    if sample_ratios:
        denominators = {denominator for _, denominator in sample_ratios}
        samples = str(denominators.pop()) if len(denominators) == 1 else "mixed"

    if not pass_ratios:
        return samples, "-"

    unique_passes = {f"{passed}/{total}" for passed, total in pass_ratios}
    if len(unique_passes) == 1:
        return samples, unique_passes.pop()

    worst_passed, worst_total = min(pass_ratios, key=lambda item: (item[0] / item[1] if item[1] else -1, item[0]))
    return samples, f"{worst_passed}/{worst_total}"


def repeated_surface_samples_and_passes(rows_for_counts, status, repeat_count):
    samples, passes = row_ratio_summary(rows_for_counts)
    if samples != "-" or passes != "-":
        return samples, passes

    passed = repeat_count if status == "passed" else 0
    return str(repeat_count), f"{passed}/{repeat_count}"


def samples_and_passes(spec, rows, status, manifest=None):
    rows_for_counts = active_rows(rows)
    if not rows_for_counts:
        if status == "skipped":
            return "-", "-"
        return "-", "-"

    if spec.kind in {"gpu-topology", "gds", "nccl-suite"}:
        repeat_count = manifest_repeat_count(manifest)
        if spec.kind in {"gds", "nccl-suite"} and repeat_count > 1:
            return repeated_surface_samples_and_passes(rows_for_counts, status, repeat_count)

        passed = 1 if status == "passed" else 0
        return "1", f"{passed}/1"

    return row_ratio_summary(rows_for_counts)


def headline_for_check(spec, rows, status, cluster):
    rows_for_counts = active_rows(rows)
    active_count = len(rows_for_counts)
    degraded_count = sum(1 for row in rows_for_counts if normalized_status(row.get("Status")) == "degraded")
    failed_count = sum(1 for row in rows_for_counts if normalized_status(row.get("Status")) == "failed")
    unknown_count = sum(1 for row in rows_for_counts if normalized_status(row.get("Status")) == "unknown")

    if not rows and status == "missing":
        return "expected evidence absent"
    if not rows and status == "unknown":
        return "evidence present; summary unavailable"

    if spec.kind == "gpu-topology":
        if status == "passed":
            return f"{active_count} idle {CLUSTER_LABELS.get(cluster, cluster)} nodes captured"
        return f"{active_count} topology rows; status {status}"

    if spec.kind == "gds":
        if status == "passed":
            return "repeated GDS complete"
        return f"{active_count} GDS nodes; {status}"

    if spec.kind == "nccl-suite":
        if status == "passed":
            scales = sorted({row.get("Scale", "").strip().strip("`").strip() for row in rows_for_counts if row.get("Scale")})
            return f"NCCL rank-per-GPU scale suite complete ({', '.join(scales)})"
        return f"{active_count} NCCL suite rows; {status}"

    return status


def primary_findings(spec, rows):
    findings = []
    issue_rows = [
        row
        for row in active_rows(rows)
        if normalized_status(row.get("Status")) not in {"passed", "skipped"}
    ]
    for row in issue_rows[:3]:
        status = normalized_status(row.get("Status"))
        entity = row_entity(row)
        passes = row.get("Passes")
        if passes:
            findings.append(f"{spec.label} {entity} is {status} ({passes} passes).")
        else:
            findings.append(f"{spec.label} {entity} is {status}.")
    remaining = len(issue_rows) - len(findings)
    if remaining > 0:
        findings.append(f"{spec.label} has {remaining} additional non-passing row(s).")
    return findings


def anomaly_findings(spec, text):
    if spec.kind != "gds":
        return []

    table = table_after_heading(text, "## GDS Anomalies")
    if not table:
        return []

    rows = table["rows"]
    severe = [row for row in rows if (row.get("Severity") or "").strip() == "severe_low"]
    if severe:
        nodes = sorted({row.get("Node", "-") for row in severe})
        return [f"GDS retained severe-low findings for selected nodes: {', '.join(nodes)}."]

    low_tail = [row for row in rows if (row.get("Severity") or "").strip() == "low_tail"]
    if low_tail:
        return [f"GDS retained {len(low_tail)} low-tail anomaly finding(s)."]
    return []


def derive_check(spec, results_root, report_dir, repo_root, cluster):
    dashboard_path = report_dir / spec.dashboard_name
    manifest_path = latest_match(report_dir / spec.manifest_dir, spec.manifest_pattern)
    dashboard_exists = dashboard_path.exists()
    manifest_exists = manifest_path is not None and manifest_path.exists()
    manifest = None
    if manifest_exists:
        try:
            manifest = load_json(manifest_path)
        except (OSError, json.JSONDecodeError):
            manifest = None

    if not dashboard_exists and not manifest_exists:
        return {
            "check_id": spec.check_id,
            "label": spec.label,
            "status": "missing",
            "expected": True,
            "dashboard_path": None,
            "manifest_path": None,
            "samples": "-",
            "passes": "-",
            "headline": "expected evidence absent",
            "findings": [f"{spec.label} expected evidence is absent."],
        }

    if not dashboard_exists:
        return {
            "check_id": spec.check_id,
            "label": spec.label,
            "status": "unknown",
            "expected": True,
            "dashboard_path": None,
            "manifest_path": relpath(manifest_path, repo_root),
            "samples": "-",
            "passes": "-",
            "headline": "manifest present; dashboard absent",
            "findings": [f"{spec.label} has a manifest but no committed dashboard."],
        }

    text = dashboard_path.read_text(encoding="utf-8")
    table = dashboard_table_for_check(spec, text)
    if not table:
        return {
            "check_id": spec.check_id,
            "label": spec.label,
            "status": "unknown",
            "expected": True,
            "dashboard_path": relpath(dashboard_path, repo_root),
            "manifest_path": relpath(manifest_path, repo_root) if manifest_exists else None,
            "samples": "-",
            "passes": "-",
            "headline": "dashboard present; summary unavailable",
            "findings": [f"{spec.label} dashboard could not be summarized safely."],
        }

    rows = table["rows"]
    status = derive_check_status(rows)
    samples, passes = samples_and_passes(spec, rows, status, manifest)
    findings = primary_findings(spec, rows)
    findings.extend(anomaly_findings(spec, text))

    if not manifest_exists and status == "unknown":
        headline = "dashboard present; manifest absent"
    else:
        headline = headline_for_check(spec, rows, status, cluster)

    return {
        "check_id": spec.check_id,
        "label": spec.label,
        "status": status,
        "expected": True,
        "dashboard_path": relpath(dashboard_path, repo_root),
        "manifest_path": relpath(manifest_path, repo_root) if manifest_exists else None,
        "samples": samples,
        "passes": passes,
        "headline": headline,
        "findings": findings,
    }


def derive_archive_check(results_root, date_value, cluster, repo_root):
    manifest_path = results_root / "archives" / date_value / f"aicr-results-{date_value}-{cluster}-verify.json"
    if not manifest_path.exists():
        return {
            "check_id": "archive-manifest",
            "label": "Archive manifest",
            "status": "missing",
            "expected": True,
            "dashboard_path": None,
            "manifest_path": None,
            "samples": "-",
            "passes": "-",
            "headline": "archive checksum manifest absent",
            "findings": ["Archive checksum manifest is absent."],
        }, {
            "status": "missing",
            "checksum_manifest_path": None,
        }

    try:
        manifest = load_json(manifest_path)
    except (OSError, json.JSONDecodeError):
        return {
            "check_id": "archive-manifest",
            "label": "Archive manifest",
            "status": "unknown",
            "expected": True,
            "dashboard_path": None,
            "manifest_path": relpath(manifest_path, repo_root),
            "samples": "-",
            "passes": "-",
            "headline": "archive checksum manifest unreadable",
            "findings": ["Archive checksum manifest could not be parsed."],
        }, {
            "status": "unknown",
            "checksum_manifest_path": relpath(manifest_path, repo_root),
        }

    archive = {
        "status": "present",
        "checksum_manifest_path": relpath(manifest_path, repo_root),
        "compression": manifest.get("compression"),
        "byte_size": manifest.get("byte_size"),
        "sha256": manifest.get("sha256"),
    }
    return {
        "check_id": "archive-manifest",
        "label": "Archive manifest",
        "status": "passed",
        "expected": True,
        "dashboard_path": None,
        "manifest_path": relpath(manifest_path, repo_root),
        "samples": "1",
        "passes": "1/1",
        "headline": "checksum manifest present",
        "findings": [],
    }, archive


def coverage(checks):
    counts = {
        "expected": len(checks),
        "present": 0,
        "passed": 0,
        "degraded": 0,
        "failed": 0,
        "skipped": 0,
        "missing": 0,
        "unknown": 0,
    }
    for check in checks:
        status = check["status"]
        if status != "missing":
            counts["present"] += 1
        counts[status] += 1
    return counts


def rollup_status(checks):
    statuses = [check["status"] for check in checks]
    if "failed" in statuses:
        return "failed"
    if "degraded" in statuses:
        return "degraded"
    if "missing" in statuses:
        return "degraded"
    if statuses and all(status == "skipped" for status in statuses):
        return "skipped"
    if "unknown" in statuses:
        return "unknown"
    return "passed"


def campaign_findings(checks):
    findings = []
    for check in checks:
        if check["status"] in {"failed", "degraded", "missing", "unknown"}:
            findings.append(f"{check['label']} is {check['status']}: {check['headline']}.")
        for finding in check.get("findings") or []:
            if finding not in findings:
                findings.append(finding)
    return findings


def node_report_followup(results_root, date_value, cluster):
    if not cluster_supports_node_debug(cluster):
        return None
    path = results_root / "reports" / date_value / f"nodes-{cluster}-{date_value}.json"
    if not path.exists():
        return None
    try:
        payload = load_json(path)
    except Exception:
        return None
    followup = payload.get("node_debug_followup")
    if followup:
        return followup

    suspects = []
    for item in payload.get("nodes") or []:
        profiles = item.get("recommended_debug_profiles") or []
        if item.get("status") in {"failed", "degraded", "unknown"} and profiles:
            suspects.append(item.get("node"))

    report_dir = results_root / "reports" / date_value
    summary_md = report_dir / f"diagnostic-{cluster}-{date_value}.md"
    summary_json = report_dir / f"diagnostic-{cluster}-{date_value}.json"
    compare_paths = sorted(report_dir.glob(f"diagnostic-compare-{cluster}-*-vs-*.md"))
    archive_path = results_root / "archives" / date_value / f"aicr-results-{date_value}-{cluster}-diagnostic.json"
    compared_suspects = set()
    for compare_path in compare_paths:
        stem = compare_path.stem
        prefix = f"diagnostic-compare-{cluster}-"
        if stem.startswith(prefix):
            bad_node, _, _ = stem[len(prefix):].partition("-vs-")
            if bad_node:
                compared_suspects.add(bad_node)
    missing_compare = [node for node in suspects if node not in compared_suspects]

    if not suspects:
        status = "not-needed"
    elif summary_md.exists() and summary_json.exists() and archive_path.exists() and not missing_compare:
        status = "complete"
    elif summary_md.exists() or summary_json.exists() or compare_paths or archive_path.exists():
        status = "partial"
    else:
        status = "pending"

    return {
        "supported": True,
        "required": bool(suspects),
        "closeout_status": status,
        "suspect_nodes": suspects,
        "summary_markdown_path": str(summary_md.relative_to(results_root.parent)) if summary_md.exists() else None,
        "summary_json_path": str(summary_json.relative_to(results_root.parent)) if summary_json.exists() else None,
        "compare_markdown_paths": [str(p.relative_to(results_root.parent)) for p in compare_paths],
        "archive_manifest_path": str(archive_path.relative_to(results_root.parent)) if archive_path.exists() else None,
        "missing_compare_suspects": missing_compare,
    }


def next_actions(status, checks, archive, node_debug_followup=None):
    actions = []
    if any(check["status"] in {"failed", "degraded"} for check in checks):
        actions.append("Review degraded or failed child dashboards before treating the campaign as fully clean.")
    if any(check["status"] == "missing" for check in checks):
        actions.append("Fill missing committed evidence or document an intentional skip before closing coverage.")
    if any(check["status"] == "unknown" for check in checks):
        actions.append("Inspect unknown checks; the campaign renderer found evidence but could not derive status safely.")
    if archive.get("status") == "present":
        actions.append("Use the archive checksum manifest to retrieve full raw/parsed evidence from VAST if needed.")
    else:
        actions.append("Create or recover the archive checksum manifest for full evidence retrieval.")
    if node_debug_followup and node_debug_followup.get("required"):
        suspects_csv = ", ".join(node_debug_followup.get("suspect_nodes") or [])
        closeout_status = node_debug_followup.get("closeout_status")
        if closeout_status == "pending":
            actions.append(
                f"Run same-day diagnostic closeout for suspect nodes: {suspects_csv}, then re-render nodes and campaign dashboards."
            )
        elif closeout_status == "partial":
            missing = node_debug_followup.get("missing_compare_suspects") or []
            if missing:
                actions.append(
                    f"Finish same-day diagnostic compare coverage for suspect nodes: {', '.join(missing)}, then re-render nodes and campaign dashboards."
                )
            else:
                actions.append(
                    f"Finish same-day diagnostic closeout for suspect nodes: {suspects_csv}, then re-render nodes and campaign dashboards."
                )
    if status == "passed" and not actions:
        actions.append("No campaign-level action required.")
    return actions


def build_campaign(results_root, date_value, cluster, campaign_type):
    repo_root = repo_root_from_results_root(results_root)
    report_dir = results_root / "reports" / date_value

    checks = [
        derive_check(spec, results_root, report_dir, repo_root, cluster)
        for spec in verification_check_specs(cluster)
    ]
    archive_check, archive = derive_archive_check(results_root, date_value, cluster, repo_root)
    checks.append(archive_check)

    if all(
        check["status"] == "missing"
        and not check.get("dashboard_path")
        and not check.get("manifest_path")
        for check in checks
    ):
        raise RuntimeError(f"no committed campaign evidence found for date={date_value} cluster={cluster}")

    status = rollup_status(checks)
    findings = campaign_findings(checks)
    node_debug_followup = node_report_followup(results_root, date_value, cluster)
    return {
        "schema_version": 1,
        "campaign_id": f"{cluster}-{campaign_type}-{date_value}",
        "campaign_type": campaign_type,
        "cluster": cluster,
        "date": date_value,
        "generated_at_utc": utc_now(),
        "status": status,
        "coverage": coverage(checks),
        "archive": archive,
        "node_debug_followup": node_debug_followup,
        "checks": checks,
        "findings": findings,
        "next_actions": next_actions(status, checks, archive, node_debug_followup),
    }


def render_table(rows, columns):
    widths = {
        key: max(len(label), *(len(str(row.get(key, ""))) for row in rows)) if rows else len(label)
        for key, label in columns
    }
    lines = []
    lines.append("  ".join(label.ljust(widths[key]) for key, label in columns))
    lines.append("  ".join("-" * widths[key] for key, _ in columns))
    for row in rows:
        lines.append("  ".join(str(row.get(key, "")).ljust(widths[key]) for key, _ in columns))
    return "\n".join(lines)


def truncate(value, max_len):
    value = str(value or "")
    if len(value) <= max_len:
        return value
    return value[: max_len - 3] + "..."


def evidence_name(check):
    path = check.get("dashboard_path") or check.get("manifest_path")
    return Path(path).name if path else "-"


def render_ascii(campaign):
    cov = campaign["coverage"]
    archive_status = campaign["archive"].get("status", "missing")
    rows = []
    for check in campaign["checks"]:
        rows.append({
            "check": check["check_id"],
            "status": check["status"],
            "samples": check["samples"],
            "passes": check["passes"],
            "headline": truncate(check["headline"], 36),
            "evidence": truncate(evidence_name(check), 34),
        })

    columns = [
        ("check", "Check"),
        ("status", "Status"),
        ("samples", "Samples"),
        ("passes", "Passes"),
        ("headline", "Headline"),
        ("evidence", "Evidence"),
    ]
    lines = [
        f"AICR System Verification Summary  {campaign['cluster']}  {campaign['date']}  {campaign['campaign_type']}",
        f"Status: {campaign['status'].upper()}   Coverage: {cov['present']}/{cov['expected']} present   Archive: {archive_status}",
    ]
    followup = campaign.get("node_debug_followup") or {}
    if followup.get("supported"):
        lines.append(
            f"Diagnostic follow-up: {followup.get('closeout_status', 'unknown').upper()}   Suspects: {len(followup.get('suspect_nodes') or [])}"
        )
    lines.extend([
        "",
        render_table(rows, columns),
    ])

    lines.extend(["", "Findings:"])
    if campaign["findings"]:
        lines.extend(f"- {finding}" for finding in campaign["findings"][:8])
        if len(campaign["findings"]) > 8:
            lines.append(f"- {len(campaign['findings']) - 8} additional finding(s) omitted from terminal view.")
    else:
        lines.append("- none")

    lines.extend(["", "Next actions:"])
    if campaign["next_actions"]:
        lines.extend(f"- {action}" for action in campaign["next_actions"])
    else:
        lines.append("- none")

    return "\n".join(lines)


def relative_report_link(target_path, campaign_report_dir, repo_root, label=None):
    if not target_path:
        return "-"
    target_abs = repo_root / target_path
    rel = os.path.relpath(target_abs.resolve(), campaign_report_dir.resolve())
    rel = rel.replace(os.sep, "/")
    if label is None:
        label = "dashboard" if target_path.endswith(".md") else "manifest"
    href = rel if rel.startswith("..") else f"./{rel}"
    return f"[{label}]({href})"


def markdown_escape(value):
    return str(value or "").replace("|", "\\|")


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


def render_markdown(campaign, results_root):
    repo_root = repo_root_from_results_root(results_root)
    report_dir = results_root / "reports" / campaign["date"]
    node_md_path = report_dir / f"nodes-{campaign['cluster']}-{campaign['date']}.md"
    node_json_path = report_dir / f"nodes-{campaign['cluster']}-{campaign['date']}.json"
    node_debug_archive_path = node_debug_archive_manifest_path(results_root, campaign["date"], campaign["cluster"], repo_root)
    node_debug_summary = node_debug_summary_paths(results_root, campaign["date"], campaign["cluster"], repo_root)
    node_debug_compare = node_debug_compare_paths(results_root, campaign["date"], campaign["cluster"], repo_root)
    cov = campaign["coverage"]
    archive = campaign["archive"]
    followup = campaign.get("node_debug_followup") or {}

    lines = [
        f"# AICR System Verification Summary: {campaign['cluster']} {campaign['date']}",
        "",
        "## Campaign Status",
        "",
        f"- Status: `{campaign['status']}`",
        f"- Campaign type: `{campaign['campaign_type']}`",
        f"- Coverage: `{cov['present']}/{cov['expected']}` expected checks present",
        f"- Generated at UTC: `{campaign['generated_at_utc']}`",
        "",
        "## Related Reports",
        "",
    ]

    if node_md_path.exists() or node_json_path.exists():
        lines.extend([
            f"- Node triage: {relative_report_link(relpath(node_md_path, repo_root) if node_md_path.exists() else None, report_dir, repo_root)}",
            f"- Node JSON: {relative_report_link(relpath(node_json_path, repo_root) if node_json_path.exists() else None, report_dir, repo_root)}",
        ])
    else:
        lines.extend([
            "- No committed node triage report for this date.",
        ])
    if cluster_supports_node_debug(campaign["cluster"]):
        if node_debug_summary["markdown"]:
            lines.append(f"- Diagnostic summary: {relative_report_link(node_debug_summary['markdown'], report_dir, repo_root)}")
        if node_debug_archive_path:
            lines.append(f"- Diagnostic archive manifest: {relative_report_link(node_debug_archive_path, report_dir, repo_root)}")
    else:
        lines.append("- Diagnostic: not yet supported for this cluster.")

    lines.extend([
        "",
        "## Coverage Matrix",
        "",
        "| Check | Status | Samples | Passes | Headline | Dashboard | Manifest |",
        "| --- | --- | ---: | ---: | --- | --- | --- |",
    ])

    for check in campaign["checks"]:
        dashboard_link = relative_report_link(check.get("dashboard_path"), report_dir, repo_root)
        manifest_link = relative_report_link(check.get("manifest_path"), report_dir, repo_root)
        lines.append(
            "| "
            + " | ".join([
                markdown_escape(check["label"]),
                markdown_escape(check["status"]),
                markdown_escape(check["samples"]),
                markdown_escape(check["passes"]),
                markdown_escape(check["headline"]),
                dashboard_link,
                manifest_link,
            ])
            + " |"
        )

    lines.extend(["", "## Major Findings", ""])
    if campaign["findings"]:
        lines.extend(f"- {finding}" for finding in campaign["findings"])
    else:
        lines.append("- none")

    operational = [
        check
        for check in campaign["checks"]
        if check["status"] in {"failed", "degraded", "missing", "unknown"}
    ]
    lines.extend(["", "## Operational Gaps", ""])
    if operational:
        for check in operational:
            lines.append(f"- `{check['check_id']}` is `{check['status']}`: {check['headline']}.")
    else:
        lines.append("- No campaign-level operational gaps were derived from committed summaries.")

    lines.extend(["", "## Archive Evidence", ""])
    if archive.get("status") == "present":
        manifest_link = relative_report_link(archive.get("checksum_manifest_path"), report_dir, repo_root)
        lines.extend([
            f"- Status: `{archive.get('status')}`",
            f"- Checksum manifest: {manifest_link}",
            f"- Compression: `{archive.get('compression')}`",
            f"- Byte size: `{archive.get('byte_size')}`",
            f"- SHA256: `{archive.get('sha256')}`",
        ])
        if node_debug_archive_path:
            lines.append(f"- Diagnostic archive manifest: {relative_report_link(node_debug_archive_path, report_dir, repo_root)}")
    else:
        lines.append(f"- Status: `{archive.get('status', 'missing')}`")

    lines.extend(["", "## Debug Artifacts", ""])
    if cluster_supports_node_debug(campaign["cluster"]):
        if followup.get("required"):
            lines.append(f"- Diagnostic closeout status: `{followup.get('closeout_status', 'unknown')}`")
            lines.append(f"- Suspect nodes: `{', '.join(followup.get('suspect_nodes') or [])}`")
        if node_debug_summary["markdown"]:
            lines.append(f"- Diagnostic summary: {relative_report_link(node_debug_summary['markdown'], report_dir, repo_root)}")
        else:
            lines.append("- Diagnostic summary: none")
        if node_debug_summary["json"]:
            lines.append(f"- Diagnostic JSON: {relative_report_link(node_debug_summary['json'], report_dir, repo_root, 'json')}")
        if node_debug_compare:
            for compare_path in node_debug_compare:
                compare_name = Path(compare_path).stem.replace(f"diagnostic-compare-{campaign['cluster']}-", "")
                lines.append(f"- Diagnostic compare `{compare_name}`: {relative_report_link(compare_path, report_dir, repo_root, 'report')}")
        else:
            lines.append("- Diagnostic compare pages: none")
        if node_debug_archive_path:
            lines.append(f"- Diagnostic archive manifest: {relative_report_link(node_debug_archive_path, report_dir, repo_root)}")
        else:
            lines.append("- Diagnostic archive manifest: none")
    else:
        lines.append("- Diagnostic is not yet supported for this cluster.")

    lines.extend(["", "## Recommended Next Actions", ""])
    if campaign["next_actions"]:
        lines.extend(f"- {action}" for action in campaign["next_actions"])
    else:
        lines.append("- none")

    lines.extend([
        "",
        "## Notes On Semantics",
        "",
        "- Child dashboards remain authoritative for per-check detail.",
        "- This system verification page summarizes committed evidence, coverage, status rollup, and navigation.",
        "- Raw and parsed evidence is archived outside Git.",
        "- Report-only anomaly filtering remains child-dashboard behavior.",
        "- Rows below the existing 1.0% anomaly display cutoff may be suppressed in child anomaly tables.",
        "- Report-only anomaly rows do not redefine campaign pass/fail.",
        "- A tiny `index.md` can be added later if public browsing still needs directory landing behavior.",
    ])

    return "\n".join(lines) + "\n"


def write_outputs(campaign, results_root, markdown):
    report_dir = results_root / "reports" / campaign["date"]
    report_dir.mkdir(parents=True, exist_ok=True)
    stem = f"campaign-{campaign['cluster']}-{campaign['date']}"
    md_path = report_dir / f"{stem}.md"
    json_path = report_dir / f"{stem}.json"
    md_path.write_text(markdown, encoding="utf-8")
    json_path.write_text(json.dumps(campaign, indent=2, sort_keys=False) + "\n", encoding="utf-8")
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
        campaign = build_campaign(results_root, date_value, args.cluster, args.campaign_type)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    want_ascii = args.ascii or args.both or not args.markdown
    want_markdown = args.markdown or args.both

    if want_ascii:
        print(render_ascii(campaign))

    if want_markdown:
        markdown = render_markdown(campaign, results_root)
        if args.write:
            md_path, json_path, index_path = write_outputs(campaign, results_root, markdown)
            print(f"Wrote {md_path}", file=sys.stderr)
            print(f"Wrote {json_path}", file=sys.stderr)
            print(f"Wrote {index_path}", file=sys.stderr)
        else:
            print(markdown, end="")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
