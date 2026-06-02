#!/usr/bin/env python3
import argparse
import datetime as dt
import json
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REGISTRY_PATH = REPO_ROOT / "docs" / "benchmarks" / "campaign-requirements.json"
CLUSTERS = ("b200", "rtxpro6000")
STATUS_VOCABULARY = {
    "complete": {
        "evidence_class": "campaign",
        "readiness": "ready",
        "meaning": "Final campaign-scope evidence is present for this required surface.",
        "operator_action": "Review and promote only after the study lead accepts the row.",
    },
    "surrogate": {
        "evidence_class": "surrogate",
        "readiness": "not-ready",
        "meaning": "Harness-validation or short-run evidence exists, but it is not final campaign evidence.",
        "operator_action": "Rerun with campaign parameters before using in final reporting.",
    },
    "staged": {
        "evidence_class": "staged",
        "readiness": "not-ready",
        "meaning": "A non-final staged row exists, usually for HPL-MxP matrix-size ramp validation.",
        "operator_action": "Advance to the reviewed campaign-sized row when approved.",
    },
    "dry-run-gated": {
        "evidence_class": "dry-run",
        "readiness": "not-ready",
        "meaning": "The interface should be validated by dry-run before consuming cluster time.",
        "operator_action": "Run the dry-run path, then schedule real collection if availability allows.",
    },
    "not-run": {
        "evidence_class": "none",
        "readiness": "not-ready",
        "meaning": "The repo has a path for this requirement, but no matching evidence was found for the date.",
        "operator_action": "Collect the required row or record an explicit availability limitation.",
    },
    "gap": {
        "evidence_class": "implementation-gap",
        "readiness": "not-ready",
        "meaning": "Implementation or parsing support is missing or incomplete for this requirement.",
        "operator_action": "Fix the harness, parser, or renderer before benchmark-day collection.",
    },
    "blocked": {
        "evidence_class": "blocked",
        "readiness": "blocked",
        "meaning": "Execution is intentionally blocked by safety, system, or operator-review policy.",
        "operator_action": "Resolve the blocker before collecting final evidence.",
    },
}
STATUS_ORDER = tuple(STATUS_VOCABULARY)
REVIEW_STATUS_VOCABULARY = {
    "campaign-ready": "Final campaign evidence is present for a campaign-required deliverable.",
    "implemented-not-run": "The repo has a collection/reporting path, but no final evidence is present for this date.",
    "surrogate-only": "Only smoke or surrogate evidence exists; it must not be promoted as final campaign evidence.",
    "staged-only": "Only staged runtime/parser evidence exists; it must advance to campaign-sized evidence.",
    "dry-run-gated": "The interface needs dry-run validation or scheduling approval before real collection.",
    "blocked": "Execution or completion is blocked by an operator, safety, or missing-definition issue.",
    "gap": "Implementation, parser, renderer, or configured reference data is missing.",
    "not-run": "No matching evidence was found.",
    "out-of-scope": "Optional rehearsal/comparison evidence; not required for campaign closeout.",
}
REVIEW_STATUS_ORDER = tuple(REVIEW_STATUS_VOCABULARY)
HPL_CAMPAIGN_TARGETS = {
    ("b200", 1): 379904,
    ("b200", 2): 530432,
    ("b200", 4): 749568,
    ("b200", 8): 1049600,
    ("b200", 16): 1500160,
    ("rtxpro6000", 1): 379904,
    ("rtxpro6000", 2): 530432,
    ("rtxpro6000", 4): 749568,
}
HPL_EVIDENCE_RANK = {"campaign": 3, "staged": 2, "smoke": 1}
ELBENCHO_METRIC_KEYS = (
    "read_iops",
    "write_iops",
    "read_mib_per_second",
    "write_mib_per_second",
    "mkdirs_per_second",
    "file_creates_per_second",
    "file_reads_per_second",
    "file_writes_per_second",
    "rmfiles_per_second",
    "rmdirs_per_second",
    "stats_per_second",
)


def build_parser():
    parser = argparse.ArgumentParser(description="Render benchmark campaign requirements coverage.")
    parser.add_argument("--date", required=True)
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--requirements-registry", default=str(DEFAULT_REGISTRY_PATH))
    return parser


def resolve_date(value):
    if value == "today":
        return dt.datetime.now(dt.timezone.utc).date().isoformat()
    if value == "yesterday":
        return (dt.datetime.now(dt.timezone.utc).date() - dt.timedelta(days=1)).isoformat()
    return value


def load_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def load_registry(path):
    registry = load_json(path)
    if not isinstance(registry, dict):
        raise ValueError(f"Unable to load requirements registry: {path}")
    rows = registry.get("rows")
    if not isinstance(rows, list):
        raise ValueError(f"Requirements registry has no rows list: {path}")
    seen = set()
    required_fields = ("id", "benchmark", "memo_scope", "cluster", "requirement", "detector")
    for index, row in enumerate(rows, start=1):
        missing = [field for field in required_fields if field not in row]
        if missing:
            raise ValueError(f"Registry row {index} is missing required fields: {', '.join(missing)}")
        row_id = row["id"]
        if row_id in seen:
            raise ValueError(f"Duplicate requirements registry id: {row_id}")
        seen.add(row_id)
    return registry


def parsed_summaries(results_root, date_value, cluster, benchmark):
    root = results_root / "by-date" / date_value / "parsed" / cluster / "multi-node" / benchmark
    if not root.exists():
        return []
    rows = []
    for path in sorted(root.glob("*/summary.json")):
        row = load_json(path)
        if row is None:
            continue
        row["_summary_path"] = str(path.relative_to(results_root.parent))
        rows.append(row)
    if benchmark == "hpl-mxp":
        add_hpl_scaling_efficiency(rows)
    return rows


def dataloader_summaries(results_root, date_value, cluster):
    roots = [
        results_root / "by-date" / date_value / "parsed" / cluster / "multi-node" / "dataloader",
        results_root / "by-date" / date_value / "parsed" / cluster / "nodes",
    ]
    rows = []
    multi_root = roots[0]
    if multi_root.exists():
        for path in sorted(multi_root.glob("*/summary.json")):
            row = load_json(path)
            if row:
                row["_summary_path"] = str(path.relative_to(results_root.parent))
                rows.append(row)
    node_root = roots[1]
    if node_root.exists():
        for path in sorted(node_root.glob("*/dataloader/*/summary.json")):
            row = load_json(path)
            if row:
                row["_summary_path"] = str(path.relative_to(results_root.parent))
                row.setdefault("node_count", 1)
                rows.append(row)
    return rows


def evidence_path(row):
    return row.get("_summary_path") or row.get("summary_path") or "-"


def status_from_rows(rows, predicate, complete_note, missing_note, missing_status="not-run"):
    matches = [row for row in rows if predicate(row)]
    if matches:
        return "complete", evidence_path(matches[0]), complete_note
    return missing_status, "-", missing_note


def latest_matching_row(rows, predicate):
    matches = [row for row in rows if predicate(row)]
    if not matches:
        return None
    return sorted(matches, key=lambda item: (str(item.get("run_id") or ""), str(item.get("job_id") or "")), reverse=True)[0]


def status_from_candidate_rows(rows, predicate, is_surrogate, complete_note, surrogate_note, missing_note, missing_status="not-run"):
    matches = [row for row in rows if predicate(row)]
    if not matches:
        return missing_status, "-", missing_note
    final_rows = [row for row in matches if not is_surrogate(row)]
    if final_rows:
        return "complete", evidence_path(final_rows[0]), complete_note
    return "surrogate", evidence_path(matches[0]), surrogate_note


def evidence_class(status):
    return STATUS_VOCABULARY.get(status, {}).get("evidence_class", "unknown")


def formatted_value(value, date_value):
    if value is None:
        return "-"
    return str(value).format(date=date_value)


def review_status(memo_scope, status):
    if memo_scope != "required":
        return "out-of-scope"
    if status == "complete":
        return "campaign-ready"
    if status == "surrogate":
        return "surrogate-only"
    if status == "staged":
        return "staged-only"
    if status in {"dry-run-gated", "blocked", "gap", "not-run"}:
        return "implemented-not-run" if status == "not-run" else status
    return "not-run"


def add_row(rows, requirement_row, status, evidence, note, date_value):
    memo_scope = requirement_row.get("memo_scope", "required")
    memo_required = memo_scope == "required"
    row_evidence_class = evidence_class(status)
    if not memo_required and status == "complete":
        row_evidence_class = "supplemental"
    rows.append({
        "id": requirement_row["id"],
        "benchmark": requirement_row["benchmark"],
        "cluster": requirement_row.get("cluster", "all"),
        "requirement": requirement_row["requirement"],
        "status": status,
        "review_status": review_status(memo_scope, status),
        "memo_required": bool(memo_required),
        "memo_scope": memo_scope,
        "evidence_class": row_evidence_class,
        "campaign_ready": bool(memo_required and status == "complete"),
        "evidence": formatted_value(evidence, date_value),
        "note": formatted_value(note, date_value),
    })


def has_passed_metric(row, key):
    return row.get("status") == "passed" and row.get(key) is not None


def maybe_int(value):
    if value in (None, ""):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def maybe_float(value):
    if value in (None, ""):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def batch_load_ms_available(row):
    if row.get("batch_load_milliseconds") is not None:
        return row.get("status") == "passed"
    measured = row.get("measured_batches")
    elapsed = row.get("load_elapsed_seconds")
    return row.get("status") == "passed" and isinstance(measured, int) and measured > 0 and elapsed is not None


def is_dataloader_surrogate(row):
    measured = row.get("measured_batches")
    warmup = row.get("warmup_batches")
    return (
        row.get("smoke") is True
        or (isinstance(measured, int) and measured < 100)
        or (isinstance(warmup, int) and warmup < 20)
    )


def dataloader_node_count(row):
    return row.get("node_count") or (1 if row.get("scope") == "node" else None)


def dataloader_gpu_count(row):
    return row.get("requested_gpu_count") or row.get("gpu_count") or row.get("world_size")


def dataloader_original_pytorch_row(row):
    return (
        row.get("status") == "passed"
        and row.get("input_backend") == "pytorch-cpu-dataloader"
        and row.get("derived_root") in (None, "")
        and row.get("samples_per_second") is not None
    )


def dataloader_config_key(row):
    return (
        row.get("input_backend"),
        row.get("sampler_mode"),
        row.get("mode"),
        maybe_int(row.get("batch_size")),
        maybe_int(row.get("num_workers")),
        maybe_int(row.get("prefetch_factor")),
        bool(row.get("pin_memory")),
        bool(row.get("persistent_workers")),
        bool(row.get("h2d_enabled")),
        bool(row.get("transfer_labels")),
        bool(row.get("drop_last")),
        maybe_int(row.get("warmup_batches")),
        maybe_int(row.get("measured_batches")),
    )


def dataloader_config_matches(row, key):
    return dataloader_config_key(row) == key


def olympic_center(values):
    numeric_values = sorted(value for value in values if value is not None)
    if len(numeric_values) >= 5:
        numeric_values = numeric_values[1:-1]
    if not numeric_values:
        return None
    return sum(numeric_values) / len(numeric_values)


def dataloader_final_config(rows):
    groups = {}
    for row in rows:
        if is_dataloader_surrogate(row):
            continue
        if not dataloader_original_pytorch_row(row):
            continue
        if dataloader_node_count(row) != 1:
            continue
        if dataloader_gpu_count(row) != 8:
            continue
        if row.get("sampler_mode") != "distributed-sharded":
            continue
        key = dataloader_config_key(row)
        groups.setdefault(key, []).append(row)
    candidates = []
    for key, group in groups.items():
        if len(group) < 5:
            continue
        values = [maybe_float(item.get("samples_per_second")) for item in group]
        center = olympic_center(values)
        if center is None:
            continue
        candidates.append((center, key, group))
    if not candidates:
        return None, []
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1], candidates[0][2]


def dataloader_repeated_matching_rows(rows, key, nodes, gpus, min_count=5):
    matches = []
    for row in rows:
        if is_dataloader_surrogate(row):
            continue
        if not dataloader_original_pytorch_row(row):
            continue
        if not dataloader_config_matches(row, key):
            continue
        if dataloader_node_count(row) != nodes:
            continue
        if dataloader_gpu_count(row) != gpus:
            continue
        matches.append(row)
    if len(matches) < min_count:
        return []
    return matches


def dataloader_sweep_candidate_rows(rows):
    candidates = []
    for row in rows:
        if is_dataloader_surrogate(row):
            continue
        if not dataloader_original_pytorch_row(row):
            continue
        if row.get("untrusted") is True:
            continue
        if dataloader_node_count(row) != 1:
            continue
        if dataloader_gpu_count(row) != 8:
            continue
        if row.get("sampler_mode") != "distributed-sharded":
            continue
        candidates.append(row)
    return candidates


def dataloader_axis_values(rows, key):
    values = set()
    for row in rows:
        if key == "pin_memory":
            values.add(bool(row.get(key)))
        else:
            value = maybe_int(row.get(key))
            if value is not None:
                values.add(value)
    return values


def dataloader_expected_set(row, field, default):
    values = row.get(field, default)
    if field == "pin_memory":
        return {bool(value) for value in values}
    return {maybe_int(value) for value in values if maybe_int(value) is not None}


def dataloader_config_text(key):
    if key is None:
        return "no repeated tuned 1-node config selected"
    (
        _backend,
        _sampler_mode,
        _mode,
        batch_size,
        num_workers,
        prefetch_factor,
        pin_memory,
        persistent_workers,
        h2d_enabled,
        transfer_labels,
        _drop_last,
        warmup_batches,
        measured_batches,
    ) = key
    return (
        f"batch={batch_size}, workers={num_workers}, prefetch={prefetch_factor}, "
        f"pin={int(pin_memory)}, persistent={int(persistent_workers)}, "
        f"h2d={int(h2d_enabled)}, labels={int(transfer_labels)}, "
        f"warmup={warmup_batches}, measured={measured_batches}"
    )


def is_ddp_surrogate(row):
    measured = row.get("measured_iters")
    warmup = row.get("warmup_iters")
    return (
        row.get("smoke") is True
        or (isinstance(measured, int) and measured < 100)
        or (isinstance(warmup, int) and warmup < 20)
    )


def ddp_epoch_available(row):
    if row.get("estimated_epoch_time_minutes") is not None:
        return True
    return (
        row.get("dataset_size") is not None
        and row.get("samples_per_second") is not None
        and row.get("samples_per_second") > 0
    )


def ddp_scaling_efficiency_available(rows, launcher):
    baseline_rows = [
        row
        for row in rows
        if row.get("status") == "passed"
        and row.get("launcher") == launcher
        and row.get("node_count") == 1
        and row.get("samples_per_second") is not None
    ]
    scale_rows = [
        row
        for row in rows
        if row.get("status") == "passed"
        and row.get("launcher") == launcher
        and row.get("node_count") not in (None, 1)
        and row.get("samples_per_second") is not None
    ]
    return bool(baseline_rows and scale_rows)


def add_hpl_scaling_efficiency(rows):
    baselines = {}
    for row in rows:
        if row.get("scaling_study") != "strong":
            row["scaling_efficiency_percent"] = None
            continue
        nodes = maybe_int(row.get("node_count"))
        matrix_size = maybe_int(row.get("matrix_size"))
        baseline_size = maybe_int(row.get("baseline_matrix_size")) or matrix_size
        perf = maybe_float(row.get("performance_pflops"))
        if nodes == 1 and matrix_size == baseline_size and perf is not None:
            current = baselines.get(baseline_size)
            current_perf = maybe_float(current.get("performance_pflops")) if current else None
            if current is None or current_perf is None or perf > current_perf:
                baselines[baseline_size] = row
    for row in rows:
        if row.get("scaling_study") != "strong":
            continue
        nodes = maybe_int(row.get("node_count"))
        perf = maybe_float(row.get("performance_pflops"))
        baseline_size = maybe_int(row.get("baseline_matrix_size")) or maybe_int(row.get("matrix_size"))
        baseline = baselines.get(baseline_size)
        baseline_perf = maybe_float(baseline.get("performance_pflops")) if baseline else None
        if not nodes or perf is None or not baseline_perf:
            continue
        if nodes == 1:
            row["scaling_efficiency_percent"] = None
            row["scaling_efficiency_label"] = "baseline"
        else:
            row["scaling_efficiency_percent"] = perf / (baseline_perf * nodes) * 100.0


def hpl_campaign_sized(row, cluster):
    target = HPL_CAMPAIGN_TARGETS.get((cluster, maybe_int(row.get("node_count"))))
    matrix_size = maybe_int(row.get("matrix_size"))
    if target is None or matrix_size != target or row.get("status") != "passed":
        return False
    return bool(row.get("preset") == "weak-study" and row.get("scaling_study") == "weak")


def hpl_evidence_type(row, cluster):
    evidence_type = row.get("evidence_type")
    if hpl_campaign_sized(row, cluster):
        return "campaign"
    if evidence_type in HPL_EVIDENCE_RANK:
        return evidence_type
    if row.get("matrix_size") == 8192 and row.get("preset", "smoke") == "smoke":
        return "smoke"
    return "staged"


def hpl_matches_requirement(summary_row, requirement_row):
    target = requirement_row.get("target_matrix_size") or HPL_CAMPAIGN_TARGETS.get((requirement_row["cluster"], requirement_row.get("nodes")))
    if target is not None and maybe_int(summary_row.get("matrix_size")) != maybe_int(target):
        return False
    target_nb = requirement_row.get("target_nb")
    if target_nb is not None and maybe_int(summary_row.get("nb")) != maybe_int(target_nb):
        return False
    study = requirement_row.get("scaling_study")
    if study and summary_row.get("scaling_study") != study:
        return False
    baseline_size = requirement_row.get("baseline_matrix_size")
    if baseline_size is not None and maybe_int(summary_row.get("baseline_matrix_size")) != maybe_int(baseline_size):
        return False
    return True


def best_hpl_row(rows, cluster, nodes, requirement_row=None):
    candidates = [row for row in rows if maybe_int(row.get("node_count")) == maybe_int(nodes)]
    if not candidates:
        return None
    for row in candidates:
        row["evidence_type"] = hpl_evidence_type(row, cluster)
        row["campaign_sized"] = hpl_campaign_sized(row, cluster)
    if requirement_row is not None:
        matching = [row for row in candidates if hpl_matches_requirement(row, requirement_row)]
        if matching:
            candidates = matching
    return sorted(
        candidates,
        key=lambda row: (
            HPL_EVIDENCE_RANK.get(row.get("evidence_type"), 0),
            1 if row.get("status") == "passed" else 0,
            row.get("matrix_size") or 0,
            row.get("run_id") or "",
        ),
        reverse=True,
    )[0]


def summaries_for(context, cluster, benchmark):
    key = (cluster, benchmark)
    if key not in context["summaries"]:
        if benchmark == "dataloader":
            rows = dataloader_summaries(context["results_root"], context["date"], cluster)
        else:
            rows = parsed_summaries(context["results_root"], context["date"], cluster, benchmark)
        context["summaries"][key] = rows
    return context["summaries"][key]


def evaluate_static_status(row, context):
    del context
    return row.get("status", "not-run"), row.get("evidence", "-"), row.get("note", "")


def evaluate_elbencho_workload(row, context):
    rows = summaries_for(context, row["cluster"], "elbencho")
    match = latest_matching_row(
        rows,
        lambda item: item.get("workload") == row.get("workload") and item.get("status") == "passed",
    )
    if match is None:
        return row.get("missing_status", "not-run"), "-", row.get("missing_note", "not collected yet")
    return row.get("complete_status", "complete"), evidence_path(match), row.get("complete_note", "passed campaign-scope row present")


def evaluate_elbencho_metrics(row, context):
    rows = summaries_for(context, row["cluster"], "elbencho")
    status, evidence, note = status_from_rows(
        rows,
        lambda item: item.get("status") == "passed"
        and any((item.get("metrics") or {}).get(key) is not None for key in ELBENCHO_METRIC_KEYS),
        row.get("complete_note", "at least one parsed elbencho metric present"),
        row.get("missing_note", "parser implemented; needs real elbencho output"),
        row.get("missing_status", "not-run"),
    )
    if status == "complete":
        status = row.get("complete_status", "complete")
    return status, evidence, note


def evaluate_dataloader_metric(row, context):
    rows = summaries_for(context, row["cluster"], "dataloader")
    final_key, final_rows = dataloader_final_config(rows)
    if final_key is None:
        return (
            row.get("missing_status", "not-run"),
            "-",
            row.get("missing_note", f"{row['cluster']} needs repeated 1-node OFAT winner before final metrics"),
        )
    metric = row.get("metric")
    predicate = batch_load_ms_available if metric == "batch_load_milliseconds" else lambda item: has_passed_metric(item, metric)
    final_matches = [item for item in rows if dataloader_config_matches(item, final_key)]
    return status_from_candidate_rows(
        final_matches,
        predicate,
        is_dataloader_surrogate,
        row.get("complete_note", f"{row['cluster']} final tuned metric row present ({dataloader_config_text(final_key)})"),
        row.get("surrogate_note", f"{row['cluster']} surrogate metric row present; not final tuned campaign evidence"),
        row.get("missing_note", f"{row['cluster']} needs final tuned rows with this metric ({dataloader_config_text(final_key)})"),
        row.get("missing_status", "not-run"),
    )


def evaluate_dataloader_scale(row, context):
    rows = summaries_for(context, row["cluster"], "dataloader")
    final_key, _final_rows = dataloader_final_config(rows)
    if final_key is None:
        return (
            row.get("missing_status", "not-run"),
            "-",
            row.get("missing_note", f"{row['cluster']} needs repeated 1-node OFAT winner before scale rows"),
        )
    nodes = row.get("nodes")
    gpus = nodes * 8
    matches = dataloader_repeated_matching_rows(rows, final_key, nodes, gpus, min_count=5)
    if not matches:
        return (
            row.get("missing_status", "not-run"),
            "-",
            row.get("missing_note", f"{row['cluster']} needs 5 repeated {nodes}n rows at tuned config ({dataloader_config_text(final_key)})"),
        )
    predicate = lambda item: item in matches
    complete_note = row.get("complete_note", f"{row['cluster']} {nodes}n tuned distributed-sharded row present ({dataloader_config_text(final_key)})")
    return status_from_candidate_rows(
        matches,
        predicate,
        is_dataloader_surrogate,
        complete_note,
        row.get("surrogate_note", f"{row['cluster']} {nodes}n surrogate row present; not final tuned campaign evidence"),
        row.get("missing_note", "not collected yet"),
        row.get("missing_status", "not-run"),
    )


def evaluate_dataloader_sweep_coverage(row, context):
    clusters = row.get("clusters") or ["b200", "rtxpro6000"]
    expected_axes = (
        ("batch_sizes", "batch_size", dataloader_expected_set(row, "batch_sizes", [256, 384, 512, 640, 768])),
        ("num_workers", "num_workers", dataloader_expected_set(row, "num_workers", [12, 16, 20])),
        ("prefetch_factors", "prefetch_factor", dataloader_expected_set(row, "prefetch_factors", [2, 4, 6, 8])),
        ("pin_memory", "pin_memory", dataloader_expected_set(row, "pin_memory", [True, False])),
    )
    evidence_paths = []
    missing = []
    for cluster in clusters:
        candidates = dataloader_sweep_candidate_rows(summaries_for(context, cluster, "dataloader"))
        if candidates:
            evidence_paths.append(evidence_path(candidates[0]))
        for label, summary_key, expected in expected_axes:
            observed = dataloader_axis_values(candidates, summary_key)
            absent = expected - observed
            if absent:
                values = ", ".join(str(value).lower() if isinstance(value, bool) else str(value) for value in sorted(absent))
                missing.append(f"{cluster} missing {label}: {values}")
    if missing:
        return (
            row.get("missing_status", "not-run"),
            "; ".join(evidence_paths) if evidence_paths else "-",
            row.get("missing_note", "DataLoader sweep coverage is incomplete") + " (" + "; ".join(missing) + ")",
        )
    evidence = "; ".join(evidence_paths) if evidence_paths else row.get("evidence", "-")
    return (
        "complete",
        evidence,
        row.get("complete_note", "DataLoader sweep coverage present for batch, workers, prefetch, and pin-memory axes"),
    )


def evaluate_ddp_throughput(row, context):
    rows = summaries_for(context, row["cluster"], "ddp-resnet50")
    nodes = row.get("nodes")
    launcher = row.get("launcher")
    missing_note = "campaign requires torchrun; not collected yet" if launcher == "torchrun" else "srun comparison row not collected"
    return status_from_candidate_rows(
        rows,
        lambda item: (
            item.get("status") == "passed"
            and item.get("launcher") == launcher
            and item.get("node_count") == nodes
            and item.get("samples_per_second") is not None
        ),
        is_ddp_surrogate,
        row.get("complete_note", f"{row['cluster']} {nodes}n {launcher} throughput row present"),
        row.get("surrogate_note", f"{row['cluster']} {nodes}n {launcher} surrogate row present; not final campaign evidence"),
        row.get("missing_note", missing_note),
        row.get("missing_status", "not-run"),
    )


def evaluate_ddp_epoch(row, context):
    rows = summaries_for(context, row["cluster"], "ddp-resnet50")
    launcher = row.get("launcher")
    return status_from_candidate_rows(
        rows,
        lambda item: item.get("status") == "passed" and item.get("launcher") == launcher and ddp_epoch_available(item),
        is_ddp_surrogate,
        row.get("complete_note", f"{row['cluster']} {launcher} epoch estimate present"),
        row.get("surrogate_note", f"{row['cluster']} {launcher} surrogate epoch estimate present"),
        row.get("missing_note", f"renderer can derive after {launcher} DDP rows exist"),
        row.get("missing_status", "not-run"),
    )


def evaluate_ddp_scaling(row, context):
    rows = summaries_for(context, row["cluster"], "ddp-resnet50")
    launcher = row.get("launcher")
    if not ddp_scaling_efficiency_available(rows, launcher):
        return "not-run", "-", row.get("missing_note", f"needs {launcher} 1n baseline plus at least one larger scale row")
    scale_row = next(
        (
            item
            for item in rows
            if item.get("status") == "passed"
            and item.get("launcher") == launcher
            and item.get("node_count") not in (None, 1)
            and item.get("samples_per_second") is not None
        ),
        {},
    )
    status = "surrogate" if is_ddp_surrogate(scale_row) else "complete"
    note = row.get("complete_note", f"1n baseline and scale row present for {launcher}")
    if status == "surrogate":
        note = row.get("surrogate_note", f"{note}; surrogate timing only")
    return status, evidence_path(scale_row), note


def hpl_row_status(row, context):
    rows = summaries_for(context, row["cluster"], "hpl-mxp")
    nodes = row.get("nodes")
    target = row.get("target_matrix_size") or HPL_CAMPAIGN_TARGETS.get((row["cluster"], nodes))
    best_row = best_hpl_row(rows, row["cluster"], nodes, row)
    if best_row is None:
        return None, target, "not-run", "-", row.get("missing_note", "HPL-MxP workspace row not collected")
    if best_row.get("campaign_sized") and best_row.get("status") == "passed":
        return best_row, target, "complete", evidence_path(best_row), row.get("complete_note", "campaign-sized row present")
    if best_row.get("evidence_type") == "staged" and best_row.get("status") == "passed":
        note = row.get("staged_note", f"staged row present at N={best_row.get('matrix_size')}; not final campaign size N={target}")
        return best_row, target, "staged", evidence_path(best_row), note
    note = row.get("surrogate_note", f"{best_row.get('evidence_type')} row present; not final campaign evidence")
    return best_row, target, "surrogate", evidence_path(best_row), note


def evaluate_hpl_size(row, context):
    _best_row, _target, status, evidence, note = hpl_row_status(row, context)
    return status, evidence, note


def evaluate_hpl_metrics(row, context):
    best_row, _target, status, evidence, _note = hpl_row_status(row, context)
    if best_row is None:
        return "not-run", "-", row.get("missing_note", "HPL-MxP metrics not collected")
    if best_row.get("performance_pflops") is None or best_row.get("residual_check") is None:
        return "gap", evidence, row.get("gap_note", "PFLOPS or residual parsing is missing")
    nodes = row.get("nodes")
    if row.get("requires_scaling_efficiency", True) and nodes and nodes > 1 and best_row.get("scaling_efficiency_percent") is None:
        return "gap", evidence, row.get("gap_note", "PFLOPS and residual parsed; scaling efficiency needs tuned 1-node baseline")
    if nodes == 1:
        return status, evidence, row.get("complete_note", "tuned 1-node PFLOPS and residual parsed")
    return status, evidence, row.get("complete_note", "PFLOPS, scaling efficiency, and residual parsed")


DETECTORS = {
    "static_status": evaluate_static_status,
    "elbencho_workload": evaluate_elbencho_workload,
    "elbencho_metrics": evaluate_elbencho_metrics,
    "dataloader_metric": evaluate_dataloader_metric,
    "dataloader_scale": evaluate_dataloader_scale,
    "dataloader_sweep_coverage": evaluate_dataloader_sweep_coverage,
    "ddp_throughput": evaluate_ddp_throughput,
    "ddp_epoch": evaluate_ddp_epoch,
    "ddp_scaling": evaluate_ddp_scaling,
    "hpl_size": evaluate_hpl_size,
    "hpl_metrics": evaluate_hpl_metrics,
}


def evaluate_requirement(row, context):
    detector_name = row.get("detector")
    detector = DETECTORS.get(detector_name)
    if detector is None:
        return "gap", "-", f"unknown campaign requirement detector: {detector_name}"
    status, evidence, note = detector(row, context)
    if status not in STATUS_VOCABULARY:
        return "gap", evidence, f"invalid detector status {status} from {detector_name}"
    return status, evidence, note


def build_rows(results_root, date_value, registry):
    rows = []
    context = {
        "date": date_value,
        "results_root": results_root,
        "summaries": {},
    }
    for requirement_row in registry["rows"]:
        status, evidence, note = evaluate_requirement(requirement_row, context)
        add_row(rows, requirement_row, status, evidence, note, date_value)
    return rows


def markdown_escape(value):
    return str(value if value is not None else "").replace("|", "\\|").replace("\n", " ")


def count_statuses(rows):
    counts = {}
    for row in rows:
        counts[row["status"]] = counts.get(row["status"], 0) + 1
    return counts


def ordered_status_counts(counts):
    ordered = []
    for status in STATUS_ORDER:
        if counts.get(status, 0):
            ordered.append({"status": status, "count": counts[status]})
    for status in sorted(status for status in counts if status not in STATUS_ORDER):
        ordered.append({"status": status, "count": counts[status]})
    return ordered


def ordered_review_status_counts(counts):
    ordered = []
    for status in REVIEW_STATUS_ORDER:
        if counts.get(status, 0):
            ordered.append({"status": status, "count": counts[status]})
    for status in sorted(status for status in counts if status not in REVIEW_STATUS_ORDER):
        ordered.append({"status": status, "count": counts[status]})
    return ordered


def benchmark_summary(rows):
    by_benchmark = {}
    for row in rows:
        item = by_benchmark.setdefault(row["benchmark"], {"benchmark": row["benchmark"], "required_rows": 0, "optional_rows": 0})
        if row["memo_required"]:
            item["required_rows"] += 1
            key = f"required_{row['status']}"
        else:
            item["optional_rows"] += 1
            key = f"optional_{row['status']}"
        item[key] = item.get(key, 0) + 1
    return [by_benchmark[name] for name in sorted(by_benchmark)]


def readiness_summary(rows):
    required_rows = [row for row in rows if row["memo_required"]]
    optional_rows = [row for row in rows if not row["memo_required"]]
    ready_rows = [row for row in required_rows if row["status"] == "complete"]
    non_ready_rows = [row for row in required_rows if row["status"] != "complete"]
    blocking_statuses = count_statuses(non_ready_rows)
    review_counts = {}
    for row in required_rows:
        review_counts[row["review_status"]] = review_counts.get(row["review_status"], 0) + 1
    return {
        "campaign_ready": bool(required_rows and not non_ready_rows),
        "required_rows": len(required_rows),
        "campaign_ready_required_rows": len(ready_rows),
        "non_ready_required_rows": len(non_ready_rows),
        "optional_rows": len(optional_rows),
        "required_review_status_counts": ordered_review_status_counts(review_counts),
        "required_status_counts": ordered_status_counts(count_statuses(required_rows)),
        "all_status_counts": ordered_status_counts(count_statuses(rows)),
        "blocking_status_counts": ordered_status_counts(blocking_statuses),
    }


def next_actions(rows):
    actions = []
    required = [row for row in rows if row["memo_required"]]
    status_to_action = (
        ("blocked", "Resolve blocked required surfaces before final collection."),
        ("gap", "Close implementation or parser gaps before benchmark-day collection."),
        ("dry-run-gated", "Run dry-run-gated required surfaces before scheduling real jobs."),
        ("staged", "Advance staged required rows to reviewed campaign-sized rows."),
        ("surrogate", "Rerun surrogate required rows with campaign parameters."),
        ("not-run", "Collect not-run required rows or record availability limitations."),
    )
    for status, action in status_to_action:
        count = sum(1 for row in required if row["status"] == status)
        if count:
            actions.append(f"{action} Count: `{count}`.")
    if not actions:
        actions.append("All required rows are campaign-ready; review evidence before promotion.")
    return actions


def report_payload(rows, date_value, md_path=None, json_path=None, registry_path=None):
    readiness = readiness_summary(rows)
    outputs = {}
    if md_path is not None:
        outputs["markdown"] = str(md_path)
    if json_path is not None:
        outputs["json"] = str(json_path)
    return {
        "schema_version": 4,
        "date": date_value,
        "requirements_registry": str(registry_path) if registry_path is not None else None,
        "status_vocabulary": STATUS_VOCABULARY,
        "review_status_vocabulary": REVIEW_STATUS_VOCABULARY,
        "readiness": readiness,
        "benchmark_summary": benchmark_summary(rows),
        "next_actions": next_actions(rows),
        "rows": rows,
        "outputs": outputs,
    }


def count_rows(rows, predicate):
    return sum(1 for row in rows if predicate(row))


def status_counts_text(rows, *, required_only=True, review=False):
    source = [row for row in rows if (row["memo_required"] if required_only else True)]
    key = "review_status" if review else "status"
    order = REVIEW_STATUS_ORDER if review else STATUS_ORDER
    parts = []
    for status in order:
        count = sum(1 for row in source if row[key] == status)
        if count:
            parts.append(f"{status}={count}")
    return ", ".join(parts) or "-"


def campaign_scope_text(row):
    return "Original Target" if row["memo_required"] else "Supplemental"


def action_for_benchmark(rows):
    required = [row for row in rows if row["memo_required"]]
    if not required:
        return "Optional evidence only."
    blocked = [row for row in required if row["review_status"] == "blocked"]
    gaps = [row for row in required if row["review_status"] == "gap"]
    staged = [row for row in required if row["review_status"] in {"surrogate-only", "staged-only", "dry-run-gated"}]
    not_run = [row for row in required if row["review_status"] in {"implemented-not-run", "not-run"}]
    ready = count_rows(required, lambda row: row["campaign_ready"])
    if blocked:
        return f"Resolve blocker for {len(blocked)} required row(s)."
    if gaps:
        return f"Close implementation/parser gap for {len(gaps)} required row(s)."
    if staged:
        return f"Promote staged/surrogate evidence for {len(staged)} required row(s)."
    if not_run:
        return f"Collect {len(not_run)} required row(s) or record availability limitation."
    if ready == len(required):
        return "Review evidence for promotion."
    return "Review row details."


def rows_by_benchmark(rows):
    grouped = {}
    for row in rows:
        grouped.setdefault(row["benchmark"], []).append(row)
    return grouped


def rows_by_cluster(rows):
    grouped = {}
    for row in rows:
        grouped.setdefault(row["cluster"], []).append(row)
    return grouped


def compact_row(row):
    cells = [
        markdown_escape(row["id"]),
        markdown_escape(f"{row['benchmark']} / {row['cluster']}"),
        markdown_escape(campaign_scope_text(row)),
        markdown_escape(row["requirement"]),
        markdown_escape(row["review_status"]),
        markdown_escape(row["status"]),
        markdown_escape(row["evidence_class"]),
        markdown_escape(row["evidence"]),
        markdown_escape(row["note"]),
    ]
    return "| " + " | ".join(cells) + " |"


def render_markdown(rows, date_value):
    payload = report_payload(rows, date_value)
    readiness = payload["readiness"]
    required = [row for row in rows if row["memo_required"]]
    optional = [row for row in rows if not row["memo_required"]]
    ready_required = [row for row in required if row["campaign_ready"]]
    blocked_required = [row for row in required if row["review_status"] == "blocked"]
    remaining_required = [
        row
        for row in required
        if not row["campaign_ready"] and row["review_status"] != "blocked"
    ]
    supplemental_rows = [
        row
        for row in optional
        if row["status"] != "not-run" or row["evidence_class"] not in {"none", "implementation-gap"}
    ]
    lines = [
        f"# AICR Benchmark Campaign Dashboard {date_value}",
        "",
        "Campaign progress tracker for Elbencho, DataLoader, ResNet-50 DDP, HPL-MxP, and final reporting deliverables.",
        "",
        "This is a closeout dashboard, not the final benchmark report. It separates required campaign targets from supplemental evidence, and separates final campaign evidence from smoke, staged, blocked, and not-yet-run rows.",
        "",
        "## Executive Snapshot",
        "",
        f"- Overall campaign ready: `{'yes' if readiness['campaign_ready'] else 'no'}`",
        f"- Required rows: `{readiness['required_rows']}`",
        f"- Ready required rows: `{readiness['campaign_ready_required_rows']}`",
        f"- Remaining required rows: `{readiness['non_ready_required_rows']}`",
        f"- Blocked required rows: `{len(blocked_required)}`",
        f"- Supplemental rehearsal/comparison rows: `{readiness['optional_rows']}`",
        "",
        "Read this as: ready rows can be reviewed for promotion; blocked rows need reviewer or sysadmin action; remaining rows need collection, parser work, or an explicit availability note.",
        "",
        "## Readiness By Benchmark",
        "",
        "| Benchmark | Ready / Required | Blocked | Remaining | Supplemental | Review Status Counts | Next Action |",
        "| --- | ---: | ---: | ---: | ---: | --- | --- |",
    ]
    for benchmark, benchmark_rows in rows_by_benchmark(rows).items():
        bench_required = [row for row in benchmark_rows if row["memo_required"]]
        bench_optional = [row for row in benchmark_rows if not row["memo_required"]]
        ready_count = count_rows(bench_required, lambda row: row["campaign_ready"])
        blocked_count = count_rows(bench_required, lambda row: row["review_status"] == "blocked")
        remaining_count = len(bench_required) - ready_count - blocked_count
        lines.append(
            "| "
            + " | ".join([
                markdown_escape(benchmark),
                f"{ready_count} / {len(bench_required)}",
                str(blocked_count),
                str(remaining_count),
                str(len(bench_optional)),
                markdown_escape(status_counts_text(benchmark_rows, review=True)),
                markdown_escape(action_for_benchmark(benchmark_rows)),
            ])
            + " |"
        )

    lines.extend([
        "",
        "## Readiness By Platform",
        "",
        "| Platform / Scope | Ready / Required | Blocked | Remaining | Review Status Counts | Next Action |",
        "| --- | ---: | ---: | ---: | --- | --- |",
    ])
    for cluster, cluster_rows in rows_by_cluster(rows).items():
        cluster_required = [row for row in cluster_rows if row["memo_required"]]
        if not cluster_required:
            continue
        ready_count = count_rows(cluster_required, lambda row: row["campaign_ready"])
        blocked_count = count_rows(cluster_required, lambda row: row["review_status"] == "blocked")
        remaining_count = len(cluster_required) - ready_count - blocked_count
        lines.append(
            "| "
            + " | ".join([
                markdown_escape(cluster),
                f"{ready_count} / {len(cluster_required)}",
                str(blocked_count),
                str(remaining_count),
                markdown_escape(status_counts_text(cluster_rows, review=True)),
                markdown_escape(action_for_benchmark(cluster_rows)),
            ])
            + " |"
        )

    lines.extend([
        "",
        "## Ready Evidence",
        "",
        "| ID | Benchmark / Cluster | Campaign Scope | Requirement | Review Status | Detector Status | Evidence Type | Evidence | Blocker / Next Action |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ])
    if ready_required:
        for row in ready_required:
            lines.append(compact_row(row))
    else:
        lines.append("| - | - | - | No ready required rows for this date. | - | - | - | - | - |")

    lines.extend([
        "",
        "## Blocked Work",
        "",
        "| ID | Benchmark / Cluster | Campaign Scope | Requirement | Review Status | Detector Status | Evidence Type | Evidence | Blocker / Next Action |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ])
    if blocked_required:
        for row in blocked_required:
            lines.append(compact_row(row))
    else:
        lines.append("| - | - | - | No blocked required rows for this date. | - | - | - | - | - |")

    lines.extend([
        "",
        "## Remaining Required Work",
        "",
        "| ID | Benchmark / Cluster | Campaign Scope | Requirement | Review Status | Detector Status | Evidence Type | Evidence | Blocker / Next Action |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ])
    if remaining_required:
        for row in remaining_required:
            lines.append(compact_row(row))
    else:
        lines.append("| - | - | - | No unblocked remaining required rows for this date. | - | - | - | - | - |")

    lines.extend([
        "",
        "## Supplemental Evidence",
        "",
        "Supplemental rows and supporting studies help explain the campaign, but do not close required rows by themselves.",
        "",
        "| ID | Benchmark / Cluster | Campaign Scope | Requirement | Review Status | Detector Status | Evidence Type | Evidence | Blocker / Next Action |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ])
    if supplemental_rows:
        for row in supplemental_rows:
            lines.append(compact_row(row))
    else:
        lines.append("| - | - | - | No supplemental evidence rows found for this date. | - | - | - | - | - |")

    lines.extend([
        "",
        "## Next Actions",
        "",
    ])
    lines.extend(f"- {action}" for action in payload["next_actions"])

    lines.extend([
        "",
        "## Status Legend",
        "",
        "Use `Review Status` for review decisions. `Detector Status` is parser/detector output used for debugging row classification.",
        "",
        "| Review Status | Meaning |",
        "| --- | --- |",
    ])
    for status in REVIEW_STATUS_ORDER:
        lines.append("| " + " | ".join([markdown_escape(status), markdown_escape(REVIEW_STATUS_VOCABULARY[status])]) + " |")
    lines.extend([
        "",
        "| Detector Status | Evidence Type | Meaning | Operator Action |",
        "| --- | --- | --- | --- |",
    ])
    for status in STATUS_ORDER:
        item = STATUS_VOCABULARY[status]
        lines.append(
            "| "
            + " | ".join([
                markdown_escape(status),
                markdown_escape(item["evidence_class"]),
                markdown_escape(item["meaning"]),
                markdown_escape(item["operator_action"]),
            ])
            + " |"
        )

    lines.extend([
        "",
        "## Detailed Requirement Appendix",
        "",
        "| ID | Benchmark | Cluster | Campaign Scope | Requirement | Review Status | Detector Status | Evidence Type | Evidence | Blocker / Next Action |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ])
    for row in rows:
        lines.append(
            "| "
            + " | ".join([
                markdown_escape(row["id"]),
                markdown_escape(row["benchmark"]),
                markdown_escape(row["cluster"]),
                markdown_escape(campaign_scope_text(row)),
                markdown_escape(row["requirement"]),
                markdown_escape(row["review_status"]),
                markdown_escape(row["status"]),
                markdown_escape(row["evidence_class"]),
                markdown_escape(row["evidence"]),
                markdown_escape(row["note"]),
            ])
            + " |"
        )
    return "\n".join(lines) + "\n"


def main():
    args = build_parser().parse_args()
    date_value = resolve_date(args.date)
    results_root = Path(args.results_root)
    registry_path = Path(args.requirements_registry)
    registry = load_registry(registry_path)
    output_dir = Path(args.output_dir) if args.output_dir else results_root / "reports" / date_value
    output_dir.mkdir(parents=True, exist_ok=True)
    rows = build_rows(results_root, date_value, registry)
    md_path = output_dir / f"benchmark-campaign-{date_value}.md"
    json_path = output_dir / f"benchmark-campaign-{date_value}.json"
    md_path.write_text(render_markdown(rows, date_value), encoding="utf-8")
    json_path.write_text(
        json.dumps(report_payload(rows, date_value, md_path, json_path, registry_path), indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {md_path}")
    print(f"Wrote {json_path}")


if __name__ == "__main__":
    raise SystemExit(main())
