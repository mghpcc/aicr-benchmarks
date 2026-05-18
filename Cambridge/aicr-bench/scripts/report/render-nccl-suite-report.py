#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import statistics
from collections import defaultdict
from pathlib import Path

from repeat_aggregation import aggregate_values, normalize_repeat_aggregation

EXPECTED_SCALE_OPS = ("allreduce", "allgather", "reduce_scatter", "alltoall")
OP_TABLE_ORDER = ("allreduce", "reduce_scatter", "allgather", "alltoall")
OP_LABELS = {
    "allreduce": "AR",
    "reduce_scatter": "RS",
    "allgather": "AG",
    "alltoall": "A2A",
}
NON_ISSUE_STATUSES = {"passed", "skipped"}
STATUS_RANK = {
    "failed": 5,
    "degraded": 4,
    "missing": 3,
    "unknown": 2,
    "passed": 1,
    "skipped": 0,
}
REPORT_STATS_LINK = "../../../docs/stats-explained.md"


def build_parser():
    p = argparse.ArgumentParser(description="Render NCCL suite local/RDMA/scale summaries.")
    p.add_argument("--date", default="today")
    p.add_argument("--cluster", required=True, choices=["b200", "rtxpro6000"])
    p.add_argument("--scope", required=True, choices=["local", "rdma", "scale"])
    p.add_argument("--results-root", default="results")
    p.add_argument("--nodes-per-job", type=int)
    p.add_argument("--fleet-manifest", default="")
    p.add_argument("--output", default="")
    return p


def resolve_date(value):
    if value not in {"today", "yesterday"}:
        return value
    offset = 0 if value == "today" else 1
    return (dt.datetime.now(dt.timezone.utc).date() - dt.timedelta(days=offset)).isoformat()


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def fmt(value):
    if value is None:
        return "-"
    try:
        return f"{float(value):.3f}"
    except (TypeError, ValueError):
        return str(value)


def fmt_int(value):
    if value is None or value == "":
        return "-"
    return str(value)


def md(value):
    return str(value if value is not None else "-").replace("|", "/")


def code(value):
    return f"`{md(value)}`"


def status_value(value):
    value = str(value or "").strip().strip("`").strip().lower()
    if value in {"pass", "ok"}:
        return "passed"
    if value in {"fail", "error"}:
        return "failed"
    if value in {"incomplete", "partial"}:
        return "degraded"
    return value or "unknown"


def int_or_none(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def numeric_or_none(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def manifest_repeat_aggregation(manifest):
    try:
        return normalize_repeat_aggregation((manifest or {}).get("repeat_aggregation"))
    except ValueError:
        return "standard"


def aggregation_center_label(manifest):
    return "Olympic avg" if manifest_repeat_aggregation(manifest) == "olympic" else "Median"


def aggregation_note(summary):
    if summary.get("fallback_used"):
        return summary.get("note") or "olympic fallback"
    if summary.get("olympic_available"):
        return summary.get("note") or "olympic avg"
    return summary.get("note") or "-"


def fmt_dropped(summary):
    if not summary.get("olympic_available"):
        return "-"
    return f"{fmt(summary.get('dropped_low'))}/{fmt(summary.get('dropped_high'))}"


def latest_local_summaries(root, date_value, cluster):
    base = root / "by-date" / date_value / "parsed" / cluster / "nodes"
    if not base.exists():
        return []
    selected = []
    for node_dir in sorted(path for path in base.iterdir() if path.is_dir()):
        check_dir = node_dir / "nccl-suite-local"
        if not check_dir.exists():
            continue
        runs = sorted(path for path in check_dir.iterdir() if path.is_dir())
        if runs and (runs[-1] / "summary.json").exists():
            selected.append(runs[-1] / "summary.json")
    return selected


def multi_node_summaries(root, date_value, cluster, check, nodes_per_job):
    base = root / "by-date" / date_value / "parsed" / cluster / "multi-node" / check
    if not base.exists():
        return []
    paths = []
    for run_dir in sorted(path for path in base.iterdir() if path.is_dir()):
        summary_path = run_dir / "summary.json"
        if not summary_path.exists():
            continue
        if nodes_per_job is not None:
            try:
                summary = load_json(summary_path)
            except json.JSONDecodeError:
                continue
            if int(summary.get("node_count") or 0) != nodes_per_job:
                continue
        paths.append(summary_path)
    return paths


def resolve_artifact_path(results_root, artifact_path):
    path = Path(artifact_path)
    if path.is_absolute():
        return path
    if path.parts and path.parts[0] == "results":
        return results_root.parent / path
    return results_root / path


def split_markdown_row(line):
    line = line.strip()
    if not line.startswith("|") or not line.endswith("|"):
        return None
    return [cell.strip() for cell in line.strip("|").split("|")]


def is_separator_row(cells):
    return bool(cells) and all(cell.strip().strip(":").strip("-") == "" and "---" in cell for cell in cells)


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


def first_detailed_table(text):
    table = table_after_heading(text, "## Detailed Rows")
    if table:
        return table
    for candidate in markdown_tables(text):
        header = set(candidate["header"])
        if {"Entity", "Scale", "Status", "Op"} <= header:
            return candidate
    return None


def uncode(value):
    return str(value or "").strip().strip("`").strip()


def rows_from_existing_report(path):
    if not path.exists():
        return []
    table = first_detailed_table(path.read_text(encoding="utf-8"))
    if not table:
        return []
    rows = []
    for item in table["rows"]:
        run_id = uncode(item.get("Run"))
        rows.append({
            "entity": uncode(item.get("Entity")) or "-",
            "scale": uncode(item.get("Scale")) or "-",
            "run_id": run_id,
            "profile": uncode(item.get("Profile")),
            "suite_class": uncode(item.get("Class")),
            "op": uncode(item.get("Op")),
            "gpu_set": uncode(item.get("GPU set")) or "all",
            "rank_shape": uncode(item.get("Rank shape")),
            "ranks": uncode(item.get("Ranks")),
            "gpus_arg": uncode(item.get("-g")),
            "status": uncode(item.get("Status")),
            "largest_busbw": numeric_or_none(uncode(item.get("Largest busbw"))),
            "max_busbw": numeric_or_none(uncode(item.get("Max busbw"))),
            "wrong": uncode(item.get("Wrong")) or "-",
            "return_code": uncode(item.get("RC")) or "-",
            "hints": uncode(item.get("Hints")) or "-",
            "notes": uncode(item.get("Notes")),
            "job_id": "",
            "sample_id": run_id,
            "round": "",
            "synthetic": False,
        })
    return rows


def summary_refs_from_manifest(root, date_value, cluster, manifest):
    if not manifest:
        return []
    jobs = [item for item in manifest.get("submitted_jobs", []) if item.get("job_id")]
    job_ids = [str(item.get("job_id")) for item in jobs]
    if not job_ids:
        return []
    index_path = root / "by-date" / date_value / "index.jsonl"
    if not index_path.exists():
        return []
    summaries_by_job = {}
    for line in index_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        job_id = str(row.get("job_id") or "")
        if job_id not in job_ids:
            continue
        if row.get("cluster") != cluster or row.get("check") != "nccl-suite-scale":
            continue
        for artifact in row.get("parsed_artifact_paths") or []:
            if artifact.endswith("/summary.json"):
                summary_path = resolve_artifact_path(root, artifact)
                if summary_path.exists():
                    summaries_by_job[job_id] = summary_path
    return [
        {"job": job, "job_id": str(job.get("job_id")), "path": summaries_by_job[str(job.get("job_id"))]}
        for job in jobs
        if str(job.get("job_id")) in summaries_by_job
    ]


def path_refs(paths):
    return [{"job": None, "job_id": "", "path": path} for path in paths]


def unique_summary_items(items, node_count=None):
    if node_count:
        scale_marker = f"_scale_{node_count}n_"
        matching_scale = [item for item in items if scale_marker in str(item.get("suite_class", ""))]
        if matching_scale:
            items = matching_scale

    seen = set()
    unique = []
    for item in items:
        key = (
            item.get("suite_class", ""),
            item.get("op", ""),
            item.get("gpu_set") or "all",
            item.get("rank_shape", ""),
            item.get("ranks"),
            item.get("gpus_arg"),
            item.get("test_params", ""),
        )
        if key in seen:
            continue
        seen.add(key)
        unique.append(item)
    return unique


def collect_rows(refs):
    rows = []
    for ref in refs:
        path = Path(ref["path"])
        submitted_job = ref.get("job") or {}
        try:
            summary = load_json(path)
        except json.JSONDecodeError:
            continue
        job_id = str(ref.get("job_id") or summary.get("job_id") or "")
        node_count = int(summary.get("node_count") or submitted_job.get("node_count") or 0)
        entity = summary.get("peer_nodes_csv") if node_count > 1 else summary.get("host")
        entity = entity or submitted_job.get("group") or summary.get("peer_nodes_csv") or "-"
        scale = f"{node_count}n" if node_count else "-"
        sample_id = job_id or summary.get("run_id", "")
        base = {
            "entity": entity,
            "scale": scale,
            "run_id": summary.get("run_id", ""),
            "profile": summary.get("profile", ""),
            "job_id": job_id,
            "sample_id": sample_id,
            "round": submitted_job.get("round", ""),
            "synthetic": False,
        }
        items = unique_summary_items(summary.get("items") or [], node_count=node_count)
        if not items:
            row = dict(base)
            row.update({
                "suite_class": "suite",
                "op": "-",
                "gpu_set": "all",
                "rank_shape": "-",
                "ranks": "-",
                "gpus_arg": "-",
                "status": summary.get("status", ""),
                "largest_busbw": None,
                "max_busbw": None,
                "wrong": "-",
                "return_code": "-",
                "hints": "-",
                "notes": summary.get("notes", ""),
            })
            rows.append(row)
            continue
        for item in items:
            row = dict(base)
            row.update({
                "suite_class": item.get("suite_class", ""),
                "op": item.get("op", ""),
                "gpu_set": item.get("gpu_set") or "all",
                "rank_shape": item.get("rank_shape", ""),
                "ranks": item.get("ranks"),
                "gpus_arg": item.get("gpus_arg"),
                "status": item.get("status", ""),
                "largest_busbw": numeric_or_none(item.get("largest_message_busbw")),
                "max_busbw": numeric_or_none(item.get("max_busbw")),
                "wrong": item.get("wrong_count"),
                "return_code": item.get("return_code"),
                "hints": item.get("transport_hints", ""),
                "notes": item.get("notes", ""),
            })
            rows.append(row)
    return rows


def manifest_jobs(manifest):
    return list((manifest or {}).get("submitted_jobs") or [])


def expected_jobs_by_scale(manifest):
    counts = defaultdict(int)
    jobs = manifest_jobs(manifest)
    if jobs:
        for job in jobs:
            scale = job.get("scale")
            if scale is not None:
                counts[f"{scale}n"] += 1
        return dict(counts)

    repeat_count = int_or_none((manifest or {}).get("repeat_count")) or 1
    for group in (manifest or {}).get("selected_groups") or []:
        scale = group.get("scale")
        if scale is not None:
            counts[f"{scale}n"] += repeat_count
    return dict(counts)


def expected_jobs_by_group(manifest):
    counts = defaultdict(int)
    for job in manifest_jobs(manifest):
        scale = job.get("scale")
        if scale is None:
            continue
        group = job.get("group") or ",".join(job.get("nodes") or [])
        counts[(f"{scale}n", group)] += 1
    return dict(counts)


def missing_rows_from_manifest(manifest, rows):
    if not manifest:
        return []
    completed_job_ids = {
        str(row.get("job_id"))
        for row in rows
        if row.get("job_id") and not row.get("synthetic")
    }
    missing = []
    for job in manifest_jobs(manifest):
        job_id = str(job.get("job_id") or "")
        if not job_id or job_id in completed_job_ids:
            continue
        scale = f"{job.get('scale')}n"
        node_count = int(job.get("node_count") or len(job.get("nodes") or []) or 0)
        gpu_count = int(job.get("gpu_count") or node_count * 8 or 0)
        entity = job.get("group") or ",".join(job.get("nodes") or []) or "-"
        for op in EXPECTED_SCALE_OPS:
            missing.append({
                "entity": entity,
                "scale": scale,
                "run_id": f"job-{job_id}",
                "profile": (manifest or {}).get("profile", ""),
                "suite_class": f"{(manifest or {}).get('cluster', 'cluster')}_scale_{scale}_8rank_1g",
                "op": op,
                "gpu_set": "all",
                "rank_shape": "8rank_1g_per_node",
                "ranks": gpu_count or "-",
                "gpus_arg": 1,
                "status": "missing",
                "largest_busbw": None,
                "max_busbw": None,
                "wrong": "-",
                "return_code": "-",
                "hints": "-",
                "notes": f"manifest job {job_id} has no parsed summary yet",
                "job_id": job_id,
                "sample_id": job_id,
                "round": job.get("round", ""),
                "synthetic": True,
            })
    return missing


def scale_sort_key(scale):
    value = str(scale)
    if value.endswith("n"):
        try:
            return (0, int(value[:-1]))
        except ValueError:
            pass
    return (1, value)


def all_scales(rows, manifest):
    scales = {row.get("scale") for row in rows if row.get("scale")}
    scales.update(expected_jobs_by_scale(manifest).keys())
    return sorted(scales, key=scale_sort_key)


def row_status_counts(rows):
    counts = defaultdict(int)
    for row in rows:
        counts[status_value(row.get("status"))] += 1
    return dict(counts)


def issue_rows(rows):
    issues = []
    for row in rows:
        status = status_value(row.get("status"))
        wrong = int_or_none(row.get("wrong"))
        rc = int_or_none(row.get("return_code"))
        notes = str(row.get("notes") or "").strip()
        if status not in NON_ISSUE_STATUSES or (wrong and wrong > 0) or (rc and rc != 0) or notes:
            issues.append(row)
    return issues


def centers_by_scale_op(rows, manifest):
    aggregation = manifest_repeat_aggregation(manifest)
    grouped = defaultdict(list)
    for row in rows:
        value = row.get("largest_busbw")
        if isinstance(value, (int, float)):
            grouped[(row.get("scale") or "-", row.get("op") or "-")].append(value)
    return {
        key: aggregate_values(values, aggregation, standard_center="median").get("center")
        for key, values in sorted(grouped.items())
    }


def worst_status(statuses):
    normalized = [status_value(status) for status in statuses if status]
    if not normalized:
        return "unknown"
    return max(normalized, key=lambda value: STATUS_RANK.get(value, -1))


def scale_status(scale_rows, expected_rows=None):
    if not scale_rows:
        return "missing"
    statuses = [status_value(row.get("status")) for row in scale_rows]
    if "failed" in statuses:
        return "failed"
    if any(status not in {"passed", "skipped"} for status in statuses):
        return "degraded"
    completed_rows = sum(1 for row in scale_rows if not row.get("synthetic"))
    if expected_rows is not None and completed_rows < expected_rows:
        return "degraded"
    return "passed"


def completed_sample_ids(rows):
    return {
        row.get("sample_id")
        for row in rows
        if row.get("sample_id") and not row.get("synthetic")
    }


def submitted_job_count(manifest):
    return len(manifest_jobs(manifest))


def completed_job_count(rows):
    return len(completed_sample_ids(rows))


def expected_row_count(manifest, rows):
    submitted = submitted_job_count(manifest)
    if submitted:
        return submitted * len(EXPECTED_SCALE_OPS)
    return len(rows)


def scale_page_name(output_path, cluster, scale):
    if output_path:
        path = Path(output_path)
        return f"{path.stem}-{scale}{path.suffix}"
    return f"nccl-suite-{cluster}-{scale}.md"


def render_run_overview(rows, manifest):
    status_counts = row_status_counts(rows)
    passed = status_counts.get("passed", 0)
    status_summary = ", ".join(f"{name}={count}" for name, count in sorted(status_counts.items())) or "none"
    expected_rows = expected_row_count(manifest, rows)
    scales = ",".join(str(item) for item in (manifest or {}).get("selected_scales") or []) or ",".join(all_scales(rows, manifest)) or "-"
    gpu_preflight = manifest or {}
    excluded = gpu_preflight.get("gpu_preflight_excluded_nodes") or []
    lines = [
        "## Run Overview",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Profile | {code((manifest or {}).get('profile', '-'))} |",
        f"| Scales | {code(scales)} |",
        f"| Repeat aggregation | {code(manifest_repeat_aggregation(manifest))} |",
        f"| GPU preflight filter | {code('enabled' if gpu_preflight.get('gpu_preflight_filter_enabled') else 'disabled')} |",
        f"| Submitted jobs | {submitted_job_count(manifest)} |",
        f"| Completed jobs | {completed_job_count(rows)}/{submitted_job_count(manifest) or completed_job_count(rows)} |",
        f"| Detailed rows | {len(rows)}/{expected_rows} |",
        f"| Passed rows | {passed}/{len(rows)} |",
        f"| Status counts | {code(status_summary)} |",
        f"| Rows needing review | {len(issue_rows(rows))} |",
        f"| Shape | {code('8 MPI ranks per node, 1 GPU per rank, 16 CPU cores per rank')} |",
    ]
    if gpu_preflight.get("gpu_preflight_filter_enabled"):
        lines.extend([
            f"| GPU preflight source | {code(gpu_preflight.get('gpu_preflight_source', '-'))} |",
            f"| GPU preflight expected count | {code(gpu_preflight.get('gpu_preflight_expected_count', '-'))} |",
            f"| GPU preflight excluded nodes | {len(excluded)} |",
        ])
    return lines


def render_skipped_nodes(manifest):
    skipped = (manifest or {}).get("skipped_nodes_by_state") or {}
    if not skipped:
        return []
    lines = ["## Skipped Nodes", ""]
    for state, nodes in sorted(skipped.items()):
        lines.append(f"- {code(state)}: {', '.join(nodes)}")
    return lines + [""]


def render_scale_coverage(rows, manifest, output_path, cluster):
    expected_jobs = expected_jobs_by_scale(manifest)
    lines = [
        "",
        "## Scale Coverage",
        "",
        "| Scale | Jobs | Completed | Rows | Passes | Status | Drilldown |",
        "| --- | ---: | ---: | ---: | ---: | --- | --- |",
    ]
    for scale in all_scales(rows, manifest):
        scale_rows = [row for row in rows if row.get("scale") == scale]
        expected_job_count = expected_jobs.get(scale, completed_job_count(scale_rows))
        expected_rows = expected_job_count * len(EXPECTED_SCALE_OPS) if expected_job_count else len(scale_rows)
        completed_jobs = completed_job_count(scale_rows)
        completed_rows = sum(1 for row in scale_rows if not row.get("synthetic"))
        passed = sum(1 for row in scale_rows if status_value(row.get("status")) == "passed")
        status = scale_status(scale_rows, expected_rows)
        drilldown = f"[{scale}](./{scale_page_name(output_path, cluster, scale)})"
        lines.append(
            f"| {code(scale)} | {expected_job_count} | {completed_jobs}/{expected_job_count} | "
            f"{completed_rows}/{expected_rows} | {passed}/{len(scale_rows)} | {code(status)} | {drilldown} |"
        )
    if len(lines) == 4:
        lines.append("| - | 0 | 0/0 | 0/0 | 0/0 | `missing` | - |")
    return lines


def render_fleet_medians(rows, manifest):
    centers = centers_by_scale_op(rows, manifest)
    center_label = aggregation_center_label(manifest)
    lines = [
        "",
        f"## Fleet {center_label}s",
        "",
        f"| Scale | AR {center_label} | RS {center_label} | AG {center_label} | A2A {center_label} |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    for scale in sorted({key[0] for key in centers}, key=scale_sort_key):
        values = {op: centers.get((scale, op)) for op in OP_TABLE_ORDER}
        lines.append(
            f"| {code(scale)} | "
            + " | ".join(fmt(values[op]) for op in OP_TABLE_ORDER)
            + " |"
        )
    if len(lines) == 4:
        lines.append("| - | - | - | - | - |")
    lines.append("")
    lines.append("Bandwidth columns are largest-message `busbw` in GB/s.")
    lines.append(f"See [Stats Explained]({REPORT_STATS_LINK}) for repeat aggregation definitions.")
    return lines


def render_issue_table(rows, heading="Rows Needing Review"):
    issues = issue_rows(rows)
    lines = [
        "",
        f"## {heading}",
        "",
    ]
    if not issues:
        lines.append("- None")
        return lines
    lines.extend([
        "| Scale | Entity | Op | Run | Job | Status | Wrong | RC | Hints | Notes |",
        "| --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |",
    ])
    for row in issues:
        lines.append(
            f"| {code(row.get('scale', '-'))} | {code(row.get('entity', '-'))} | {code(row.get('op', '-'))} | "
            f"{code(row.get('run_id', '-'))} | {code(row.get('job_id') or '-')} | {code(row.get('status', '-'))} | "
            f"{md(row.get('wrong', '-'))} | {md(row.get('return_code', '-'))} | {md(row.get('hints') or '-')} | {md(row.get('notes') or '-')} |"
        )
    return lines


def render_node_selection_notes(rows):
    issue_nodes = sorted({
        node
        for row in issue_rows(rows)
        for node in str(row.get("entity") or "").split(",")
        if node
    })
    lines = [
        "",
        "## Benchmark Node Selection Notes",
        "",
        "- Treat this NCCL report as communication-readiness evidence for the same-day by-node dashboard.",
        "- Strict benchmark candidates are selected from the by-node JSON only when the overall node status is `passed`.",
    ]
    if issue_nodes:
        lines.append(f"- Nodes participating in NCCL rows needing review: `{', '.join(issue_nodes)}`")
    else:
        lines.append("- No NCCL rows currently remove nodes from the strict candidate pool.")
    return lines


def split_nodes(group):
    return [item for item in str(group or "").split(",") if item]


def fmt_range(values):
    values = [value for value in values if isinstance(value, (int, float))]
    if not values:
        return "-"
    if len(values) == 1:
        return fmt(values[0])
    return f"{fmt(min(values))}..{fmt(max(values))}"


def sample_status(sample_rows):
    if not sample_rows:
        return "missing"
    statuses = [status_value(row.get("status")) for row in sample_rows]
    if any(status == "failed" for status in statuses):
        return "failed"
    if any(status not in {"passed", "skipped"} for status in statuses):
        return "degraded"
    return "passed"


def group_summary_rows(rows, manifest, scale):
    expected = expected_jobs_by_group(manifest)
    groups = {row.get("entity") for row in rows if row.get("scale") == scale}
    groups.update(group for group_scale, group in expected if group_scale == scale)
    summaries = []
    for group in sorted(groups):
        group_rows = [row for row in rows if row.get("scale") == scale and row.get("entity") == group]
        expected_samples = expected.get((scale, group), len({row.get("sample_id") for row in group_rows if row.get("sample_id")}) or 1)
        sample_ids = sorted({row.get("sample_id") for row in group_rows if row.get("sample_id")})
        completed = len({row.get("sample_id") for row in group_rows if row.get("sample_id") and not row.get("synthetic")})
        sample_statuses = [
            sample_status([row for row in group_rows if row.get("sample_id") == sample_id])
            for sample_id in sample_ids
        ]
        passed_samples = sum(1 for status in sample_statuses if status == "passed")
        if not group_rows:
            status = "missing"
        elif any(status == "failed" for status in sample_statuses):
            status = "failed"
        elif completed == 0:
            status = "missing"
        elif passed_samples < expected_samples or any(status != "passed" for status in sample_statuses):
            status = "degraded"
        else:
            status = "passed"
        wrong = sum(int_or_none(row.get("wrong")) or 0 for row in group_rows)
        op_values = {}
        for op in OP_TABLE_ORDER:
            values = [
                row.get("largest_busbw")
                for row in group_rows
                if row.get("op") == op
                and status_value(row.get("status")) == "passed"
                and isinstance(row.get("largest_busbw"), (int, float))
            ]
            op_values[op] = values
        jobs = sorted({row.get("job_id") or row.get("run_id") for row in group_rows if row.get("job_id") or row.get("run_id")})
        node_count = len(split_nodes(group))
        summaries.append({
            "group": group,
            "nodes": node_count,
            "gpus": node_count * 8 if node_count else "-",
            "samples": f"{completed}/{expected_samples}",
            "passes": f"{passed_samples}/{expected_samples}",
            "status": status,
            "wrong": wrong,
            "jobs": ",".join(jobs) if jobs else "-",
            "op_values": op_values,
        })
    return summaries


def render_group_rows(rows, manifest, scale):
    summaries = group_summary_rows(rows, manifest, scale)
    aggregation = manifest_repeat_aggregation(manifest)
    center_label = aggregation_center_label(manifest)
    lines = [
        "",
        "## Group Rows",
        "",
    ]
    if aggregation == "olympic":
        lines.extend([
            f"| Node Group | Nodes | GPUs | Samples | Passes | Status | AR {center_label} | AR min..max | AR drop min/max | RS {center_label} | RS min..max | RS drop min/max | AG {center_label} | AG min..max | AG drop min/max | A2A {center_label} | A2A min..max | A2A drop min/max | Wrong | Aggregation | Jobs |",
            "| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |",
        ])
    else:
        lines.extend([
            "| Node Group | Nodes | GPUs | Samples | Passes | Status | AR med | AR min..max | RS med | RS min..max | AG med | AG min..max | A2A med | A2A min..max | Wrong | Jobs |",
            "| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | ---: | --- | ---: | --- | ---: | --- | ---: | --- |",
        ])
    for item in summaries:
        cells = [
            code(item["group"]),
            item["nodes"],
            item["gpus"],
            item["samples"],
            item["passes"],
            code(item["status"]),
        ]
        notes = []
        for op in OP_TABLE_ORDER:
            values = item["op_values"][op]
            summary = aggregate_values(values, aggregation, standard_center="median")
            cells.extend([fmt(summary.get("center")), fmt_range(values)])
            if aggregation == "olympic":
                cells.append(fmt_dropped(summary))
                if values and summary.get("fallback_used"):
                    notes.append(f"{OP_LABELS.get(op, op)}: {aggregation_note(summary)}")
        cells.append(item["wrong"])
        if aggregation == "olympic":
            cells.append(md("; ".join(notes) if notes else "olympic avg"))
        cells.append(code(item["jobs"]))
        lines.append("| " + " | ".join(str(cell) for cell in cells) + " |")
    if not summaries:
        if aggregation == "olympic":
            lines.append("| - | 0 | 0 | 0/0 | 0/0 | `missing` | - | - | - | - | - | - | - | - | - | - | - | - | 0 | - | - |")
        else:
            lines.append("| - | 0 | 0 | 0/0 | 0/0 | `missing` | - | - | - | - | - | - | - | - | 0 | - |")
    lines.extend([
        "",
        "Bandwidth columns are largest-message `busbw` in GB/s.",
        f"{center_label} columns aggregate passed samples for each node group. See [Stats Explained]({REPORT_STATS_LINK}) for repeat aggregation and min/max definitions.",
    ])
    return lines


def render_scale_statistics(rows, scale, manifest):
    scale_rows = [row for row in rows if row.get("scale") == scale]
    aggregation = manifest_repeat_aggregation(manifest)
    center_label = aggregation_center_label(manifest)
    lines = [
        "",
        "## Per-Op Statistics",
        "",
        f"Only passed rows with numeric largest-message `busbw` values are included. See [Stats Explained]({REPORT_STATS_LINK}) for repeat aggregation and min/max definitions.",
        "",
    ]
    if aggregation == "olympic":
        lines.extend([
            f"| Metric | n | {center_label} | Min | Max | Dropped min/max | Aggregation |",
            "| --- | ---: | ---: | ---: | ---: | --- | --- |",
        ])
    else:
        lines.extend([
            "| Metric | n | Median | Min | Max |",
            "| --- | ---: | ---: | ---: | ---: |",
        ])
    for op in OP_TABLE_ORDER:
        values = [
            row.get("largest_busbw")
            for row in scale_rows
            if row.get("op") == op
            and status_value(row.get("status")) == "passed"
            and isinstance(row.get("largest_busbw"), (int, float))
        ]
        label = OP_LABELS.get(op, op)
        if values:
            summary = aggregate_values(values, aggregation, standard_center="median")
            if aggregation == "olympic":
                lines.append(
                    f"| {label} busbw | {len(values)} | {fmt(summary.get('center'))} | {fmt(min(values))} | {fmt(max(values))} | "
                    f"{fmt_dropped(summary)} | {md(aggregation_note(summary))} |"
                )
            else:
                lines.append(f"| {label} busbw | {len(values)} | {fmt(summary.get('center'))} | {fmt(min(values))} | {fmt(max(values))} |")
        else:
            if aggregation == "olympic":
                lines.append(f"| {label} busbw | 0 | - | - | - | - | - |")
            else:
                lines.append(f"| {label} busbw | 0 | - | - | - |")
    return lines


def render_bandwidth_anomalies(rows, scale, manifest):
    aggregation = manifest_repeat_aggregation(manifest)
    center_label = aggregation_center_label(manifest)
    group_rows = group_summary_rows(rows, manifest, scale)
    anomalies = []
    for op in OP_TABLE_ORDER:
        values_by_group = []
        for item in group_rows:
            values = item["op_values"][op]
            if values:
                center = aggregate_values(values, aggregation, standard_center="median").get("center")
                if isinstance(center, (int, float)):
                    values_by_group.append((item["group"], center))
        values = [value for _, value in values_by_group]
        if len(values) < 3:
            continue
        median_value = statistics.median(values)
        if median_value <= 0:
            continue
        for group, value in values_by_group:
            delta = (value - median_value) / median_value
            if delta <= -0.01:
                anomalies.append((group, op, value, median_value, delta))
    lines = [
        "",
        "## Bandwidth Anomalies",
        "",
        f"Anomalies are report evidence only and do not change canonical `status.json` pass/fail. See [Stats Explained]({REPORT_STATS_LINK}) for `Delta` and anomaly-label definitions.",
        "",
    ]
    if not anomalies:
        lines.append("(none)")
        return lines
    lines.extend([
        "| Severity | Node Group | Metric | Value | Median | Delta |",
        "| --- | --- | --- | ---: | ---: | ---: |",
    ])
    for group, op, value, median_value, delta in anomalies:
        lines.append(
            f"| low_tail | {code(group)} | {OP_LABELS.get(op, op)} busbw | {fmt(value)} | {fmt(median_value)} | {delta * 100:.1f}% |"
        )
    if center_label != "Median":
        lines.append("")
        lines.append(f"`Value` uses {center_label} per node group before fleet-median comparison.")
    return lines


def render_detailed_rows(rows):
    lines = [
        "",
        "## Detailed Rows",
        "",
        "| Entity | Scale | Run | Profile | Class | Op | GPU set | Rank shape | Ranks | -g | Status | Largest busbw | Max busbw | Wrong | RC | Hints | Notes |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| {code(row.get('entity', '-'))} | {code(row.get('scale', '-'))} | {code(row.get('run_id', '-'))} | "
            f"{code(row.get('profile', '-'))} | {code(row.get('suite_class', '-'))} | {code(row.get('op', '-'))} | "
            f"{code(row.get('gpu_set', '-'))} | {code(row.get('rank_shape', '-'))} | {fmt_int(row.get('ranks'))} | "
            f"{fmt_int(row.get('gpus_arg'))} | {code(row.get('status', '-'))} | {fmt(row.get('largest_busbw'))} | "
            f"{fmt(row.get('max_busbw'))} | {md(row.get('wrong', '-'))} | {md(row.get('return_code', '-'))} | "
            f"{md(row.get('hints') or '-')} | {md(row.get('notes') or '')} |"
        )
    if not rows:
        lines.append("| - | - | - | - | - | - | - | - | - | - | `missing` | - | - | - | - | - | no summaries found |")
    return lines


def render_scale_index(date_value, cluster, rows, manifest, output_path=None):
    lines = [
        f"# NCCL System Verification {cluster} {date_value}",
        "",
        "This dashboard is an operator index for rank-per-GPU system verification. Use the per-scale drilldowns for job-shape detail and the by-node dashboard for benchmark candidate selection.",
        "",
    ]
    lines.extend(render_run_overview(rows, manifest))
    lines.extend(render_skipped_nodes(manifest))
    lines.extend(render_scale_coverage(rows, manifest, output_path, cluster))
    lines.extend(render_fleet_medians(rows, manifest))
    lines.extend(render_issue_table(rows))
    lines.extend(render_node_selection_notes(rows))
    lines.extend(render_detailed_rows(rows))
    return "\n".join(lines) + "\n"


def render_scale_page(date_value, cluster, scale, rows, manifest, index_name):
    scale_rows = [row for row in rows if row.get("scale") == scale]
    expected_jobs = expected_jobs_by_scale(manifest).get(scale, completed_job_count(scale_rows))
    expected_rows = expected_jobs * len(EXPECTED_SCALE_OPS) if expected_jobs else len(scale_rows)
    completed_rows = sum(1 for row in scale_rows if not row.get("synthetic"))
    passed = sum(1 for row in scale_rows if status_value(row.get("status")) == "passed")
    lines = [
        f"# NCCL System Verification {cluster} {date_value} {scale}",
        "",
        f"- Index: [{index_name}](./{index_name})",
        f"- Profile: {code((manifest or {}).get('profile', '-'))}",
        f"- Scale: {code(scale)}",
        f"- Submitted jobs: {expected_jobs}",
        f"- Completed jobs: {completed_job_count(scale_rows)}/{expected_jobs}",
        f"- Detailed rows: {completed_rows}/{expected_rows}",
        f"- Passed rows: {passed}/{len(scale_rows)}",
        f"- Status: {code(scale_status(scale_rows, expected_rows))}",
        f"- Shape: {code('8 MPI ranks per node, 1 GPU per rank, 16 CPU cores per rank')}",
    ]
    lines.extend(render_group_rows(rows, manifest, scale))
    lines.extend(render_scale_statistics(rows, scale, manifest))
    lines.extend(render_bandwidth_anomalies(rows, scale, manifest))
    lines.extend(render_issue_table(scale_rows))
    lines.extend(render_detailed_rows(scale_rows))
    return "\n".join(lines) + "\n"


def render_generic(date_value, cluster, scope, rows):
    title = "NCCL Suite Local" if scope == "local" else "NCCL Suite RDMA"
    lines = [
        f"# {title} {cluster} {date_value}",
        "",
    ]
    lines.extend(render_issue_table(rows))
    lines.extend(render_detailed_rows(rows))
    return "\n".join(lines) + "\n"


def write_outputs(output_path, date_value, cluster, rows, manifest):
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(render_scale_index(date_value, cluster, rows, manifest, out), encoding="utf-8")
    index_name = out.name
    for scale in all_scales(rows, manifest):
        scale_path = out.with_name(scale_page_name(out, cluster, scale))
        scale_path.write_text(render_scale_page(date_value, cluster, scale, rows, manifest, index_name), encoding="utf-8")


def rows_for_args(args, results_root, date_value, manifest):
    if args.scope == "local":
        return collect_rows(path_refs(latest_local_summaries(results_root, date_value, args.cluster)))
    if args.scope == "scale":
        refs = summary_refs_from_manifest(results_root, date_value, args.cluster, manifest)
        if refs:
            rows = collect_rows(refs)
            rows.extend(missing_rows_from_manifest(manifest, rows))
            return rows
        paths = multi_node_summaries(results_root, date_value, args.cluster, "nccl-suite-scale", args.nodes_per_job)
        rows = collect_rows(path_refs(paths))
        if not rows:
            existing = results_root / "reports" / date_value / f"nccl-suite-{args.cluster}.md"
            rows = rows_from_existing_report(existing)
        if not rows:
            rows.extend(missing_rows_from_manifest(manifest, rows))
        return rows
    paths = multi_node_summaries(results_root, date_value, args.cluster, "nccl-suite-rdma", args.nodes_per_job)
    return collect_rows(path_refs(paths))


def main():
    args = build_parser().parse_args()
    date_value = resolve_date(args.date)
    results_root = Path(args.results_root)
    manifest = load_json(Path(args.fleet_manifest)) if args.fleet_manifest else None
    rows = rows_for_args(args, results_root, date_value, manifest)
    if args.scope == "scale":
        if args.output:
            write_outputs(args.output, date_value, args.cluster, rows, manifest)
        else:
            print(render_scale_index(date_value, args.cluster, rows, manifest), end="")
    else:
        output = render_generic(date_value, args.cluster, args.scope, rows)
        if args.output:
            out = Path(args.output)
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(output, encoding="utf-8")
        else:
            print(output, end="")


if __name__ == "__main__":
    main()
