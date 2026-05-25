#!/usr/bin/env python3
import argparse
import csv
import datetime as dt
import json
import math
import re
import shlex
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from repeat_aggregation import aggregate_values, normalize_repeat_aggregation


TARGETS = {
    "b200": [(1, 8, 379904), (2, 16, 530432), (4, 32, 749568), (8, 64, 1049600), (16, 128, 1500160)],
    "rtxpro6000": [(1, 8, 379904), (2, 16, 530432), (4, 32, 749568)],
}

CAMPAIGN_MATRIX_TARGETS = {
    ("b200", 1): 379904,
    ("b200", 2): 530432,
    ("b200", 4): 749568,
    ("b200", 8): 1049600,
    ("b200", 16): 1500160,
    ("rtxpro6000", 1): 379904,
    ("rtxpro6000", 2): 530432,
    ("rtxpro6000", 4): 749568,
}

EVIDENCE_RANK = {"campaign": 3, "staged": 2, "smoke": 1}
STATUS_RANK = {"passed": 3, "degraded": 2, "failed": 1, "skipped": 0}
GIB = 1024 ** 3
PRE_RENAME_PRESET = "workspace-fp16"
PROOF_JOB_IDS = {"28147"}


def build_parser():
    parser = argparse.ArgumentParser(description="Render HPL-MxP status reports.")
    parser.add_argument("--date", required=True)
    parser.add_argument("--cluster", choices=["b200", "rtxpro6000"], required=True)
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--repeat-aggregation", default="standard", choices=["standard", "olympic"])
    parser.add_argument("--job-id-min", type=int, default=None)
    parser.add_argument("--job-id-max", type=int, default=None)
    parser.add_argument("--job-id-list", default="")
    return parser


def resolve_date(value):
    if value == "today":
        return dt.datetime.now(dt.timezone.utc).date().isoformat()
    if value == "yesterday":
        return (dt.datetime.now(dt.timezone.utc).date() - dt.timedelta(days=1)).isoformat()
    return value


def load_summaries(results_root, date_value, cluster):
    root = results_root / "by-date" / date_value / "parsed" / cluster / "multi-node" / "hpl-mxp"
    rows = []
    parsed_run_ids = set()
    if root.exists():
        for summary_path in sorted(root.glob("*/summary.json")):
            try:
                row = json.loads(summary_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                row = {"status": "invalid-json", "notes": str(exc)}
            row["summary_path"] = str(summary_path.relative_to(results_root.parent))
            parsed_run_ids.add(summary_path.parent.name)
            enrich_from_stdout(row, results_root.parent)
            enrich_classification(row, cluster)
            rows.append(row)
    rows.extend(load_raw_fallback_rows(results_root, date_value, cluster, parsed_run_ids))
    return rows


def parse_command_fields(command_path):
    if not command_path.exists():
        return {}
    text = command_path.read_text(encoding="utf-8", errors="replace")
    try:
        tokens = shlex.split(text)
    except ValueError:
        tokens = text.split()
    fields = {"command_file": str(command_path)}
    option_map = {
        "--nodes": ("node_count", maybe_int),
        "--ntasks": ("rank_count", maybe_int),
        "--n": ("matrix_size", maybe_int),
        "--nb": ("nb", maybe_int),
        "--nprow": ("nprow", maybe_int),
        "--npcol": ("npcol", maybe_int),
        "--sloppy-type": ("sloppy_type", normalize_sloppy_type),
        "--test-loop": ("test_loop", maybe_int),
        "--mpi-use-mpi": ("mpi_use_mpi", maybe_int),
        "--use-mpi-panel-broadcast": ("mpi_panel_broadcast_percent", maybe_int),
        "--prioritize-trsm": ("prioritize_trsm", maybe_int),
        "--prioritize-factorization": ("prioritize_factorization", maybe_int),
        "--Anq-device": ("anq_device", maybe_int),
        "--fill-device": ("fill_device", maybe_int),
        "--fill-device-buffer-size": ("fill_device_buffer_size_mb", maybe_int),
        "--call-dgemv-with-multiple-threads": ("call_dgemv_with_multiple_threads", maybe_int),
        "--gpu-affinity": ("gpu_affinity", str),
        "--cpu-affinity": ("cpu_affinity", str),
        "--mem-affinity": ("mem_affinity", str),
        "--ucx-affinity": ("ucx_affinity", str),
        "--u-panel-chunk-nbs": ("u_panel_chunk_nbs", maybe_int),
        "--scaling-study": ("scaling_study", str),
        "--baseline-matrix-size": ("baseline_matrix_size", maybe_int),
    }
    for token in tokens:
        if token.startswith("OMPI_MCA_coll="):
            fields["ompi_mca_coll"] = token.split("=", 1)[1]
        elif token.startswith("OMPI_MCA_pml="):
            fields["ompi_mca_pml"] = token.split("=", 1)[1]
        elif token.startswith("OMPI_MCA_btl="):
            fields["ompi_mca_btl"] = token.split("=", 1)[1]
        elif token.startswith("OMPI_MCA_btl_tcp_if_include="):
            fields["ompi_mca_btl_tcp_if_include"] = token.split("=", 1)[1]
        elif token.startswith("OMPI_MCA_oob_tcp_if_include="):
            fields["ompi_mca_oob_tcp_if_include"] = token.split("=", 1)[1]
        elif token.startswith("PMIX_MCA_gds="):
            fields["pmix_mca_gds"] = token.split("=", 1)[1]
        elif token.startswith("HPL_MXP_SCALING_STUDY="):
            fields["scaling_study"] = token.split("=", 1)[1]
        elif token.startswith("HPL_MXP_BASELINE_MATRIX_SIZE="):
            fields["baseline_matrix_size"] = maybe_int(token.split("=", 1)[1])
    for index, token in enumerate(tokens[:-1]):
        if token not in option_map:
            continue
        key, converter = option_map[token]
        fields[key] = converter(tokens[index + 1])
    if fields.get("rank_count") and fields.get("node_count") is None:
        fields["node_count"] = fields["rank_count"] // 8
    if fields.get("rank_count") is None and fields.get("node_count"):
        fields["rank_count"] = fields["node_count"] * 8
    nprow = fields.get("nprow")
    npcol = fields.get("npcol")
    if nprow and npcol:
        fields["processor_grid"] = f"{nprow}x{npcol}"
    return fields


def parse_preflight_nodes(preflight_path):
    nodes = []
    if not preflight_path.exists():
        return nodes
    for line in preflight_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "|" not in line:
            continue
        node, payload = line.split("|", 1)
        if payload == "NODE" and node not in nodes:
            nodes.append(node)
    return nodes


def infer_preset(cluster, node_count, matrix_size):
    if matrix_size == 8192:
        return "smoke"
    if matrix_size == campaign_target_matrix_size(cluster, node_count):
        return "campaign-candidate"
    return "staged"


def load_raw_fallback_rows(results_root, date_value, cluster, parsed_run_ids):
    repo_root = results_root.parent
    raw_root = results_root / "by-date" / date_value / "raw" / cluster / "multi-node" / "hpl-mxp"
    if not raw_root.exists():
        return []
    rows = []
    for run_dir in sorted(raw_root.glob("*")):
        run_id = run_dir.name
        if run_id in parsed_run_ids:
            continue
        canonical = run_dir / "canonical"
        stdout_path = canonical / "hpl-mxp-stdout.txt"
        command_path = canonical / "hpl-mxp-command.txt"
        if not stdout_path.exists() or not command_path.exists():
            continue
        command_fields = parse_command_fields(command_path)
        stdout_text = stdout_path.read_text(encoding="utf-8", errors="replace")
        residual = parse_residual_check(stdout_text)
        perf = parse_performance_pflops(stdout_text)
        node_count = maybe_int(command_fields.get("node_count"))
        matrix_size = maybe_int(command_fields.get("matrix_size"))
        preflight_nodes = parse_preflight_nodes(canonical / "gpu-preflight.txt")
        row = {
            "schema_version": 1,
            "status": "passed" if residual == "passed" else "raw-only",
            "cluster": cluster,
            "date": date_value,
            "run_id": run_id,
            "node": preflight_nodes[0] if preflight_nodes else None,
            "peer_nodes": preflight_nodes,
            "job_id": (re.search(r"-j([0-9]+)$", run_id).group(1) if re.search(r"-j([0-9]+)$", run_id) else None),
            "preset": infer_preset(cluster, node_count, matrix_size),
            "evidence_type": "staged",
            "performance_pflops": perf,
            "residual_check": residual,
            "stdout_file": str(stdout_path.relative_to(repo_root)),
            "stderr_file": str((canonical / "hpl-mxp-stderr.txt").relative_to(repo_root)),
            "preflight_file": str((canonical / "gpu-preflight.txt").relative_to(repo_root)),
            "summary_path": str(command_path.relative_to(repo_root)),
            "notes": "raw fallback row; parsed wrapper summary was not written",
        }
        row.update(command_fields)
        enrich_classification(row, cluster)
        rows.append(row)
    return rows


def maybe_int(value):
    if value in (None, ""):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def parse_job_id_list(value):
    job_ids = set()
    for item in str(value or "").split(","):
        item = item.strip()
        if not item:
            continue
        if "-" in item:
            start, end = item.split("-", 1)
            start_int = maybe_int(start)
            end_int = maybe_int(end)
            if start_int is None or end_int is None:
                continue
            for job_id in range(min(start_int, end_int), max(start_int, end_int) + 1):
                job_ids.add(str(job_id))
        else:
            job_id = maybe_int(item)
            if job_id is not None:
                job_ids.add(str(job_id))
    return job_ids


def row_matches_job_filter(row, job_id_min=None, job_id_max=None, job_ids=None):
    if job_id_min is None and job_id_max is None and not job_ids:
        return True
    job_id = maybe_int(row.get("job_id"))
    if job_id is None:
        return False
    if job_id_min is not None and job_id < job_id_min:
        return False
    if job_id_max is not None and job_id > job_id_max:
        return False
    if job_ids and str(job_id) not in job_ids:
        return False
    return True


def filter_rows_by_job(rows, job_id_min=None, job_id_max=None, job_id_list=""):
    job_ids = parse_job_id_list(job_id_list)
    return [
        row
        for row in rows
        if row_matches_job_filter(
            row,
            job_id_min=job_id_min,
            job_id_max=job_id_max,
            job_ids=job_ids,
        )
    ]


def job_filter_metadata(job_id_min=None, job_id_max=None, job_id_list=""):
    job_ids = sorted(parse_job_id_list(job_id_list), key=lambda item: int(item))
    active = job_id_min is not None or job_id_max is not None or bool(job_ids)
    description = "none"
    if active:
        parts = []
        if job_id_min is not None:
            parts.append(f"job_id >= {job_id_min}")
        if job_id_max is not None:
            parts.append(f"job_id <= {job_id_max}")
        if job_ids:
            parts.append("job_id in " + ",".join(job_ids))
        description = "; ".join(parts)
    return {
        "active": active,
        "job_id_min": job_id_min,
        "job_id_max": job_id_max,
        "job_id_list": job_ids,
        "description": description,
    }


def normalize_sloppy_type(value):
    if value in (None, ""):
        return None
    text = str(value).strip().upper()
    if text == "1":
        return "FP8"
    if text == "2":
        return "FP16"
    return text


def maybe_float(value):
    if value in (None, ""):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def first_float(patterns, text):
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            try:
                return float(match.group(1).replace(",", ""))
            except ValueError:
                return None
    return None


def parse_processor_grid(value):
    if not value or "x" not in str(value):
        return None, None
    left, right = str(value).split("x", 1)
    return maybe_int(left), maybe_int(right)


def block_count(matrix_size, nb):
    matrix_size = maybe_int(matrix_size)
    nb = maybe_int(nb)
    if not matrix_size or not nb or matrix_size % nb != 0:
        return None
    return matrix_size // nb


def grid_multiple(nprow, npcol):
    nprow = maybe_int(nprow)
    npcol = maybe_int(npcol)
    if not nprow or not npcol:
        return None
    return math.lcm(nprow, npcol)


def parse_performance_pflops(text):
    float_re = r"([+-]?[0-9][0-9,]*(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)"
    pflops = first_float([
        rf"{float_re}\s*(?:peta)?flop/s",
        rf"{float_re}\s*pflops?",
    ], text)
    if pflops is not None:
        return pflops
    tflops = first_float([
        rf"{float_re}\s*(?:tera)?flop/s",
        rf"{float_re}\s*tflops?",
    ], text)
    if tflops is not None:
        return tflops / 1000.0
    gflops = first_float([
        rf"\bGFLOPS\s*=\s*{float_re}",
        rf"{float_re}\s*gflops?",
    ], text)
    if gflops is not None:
        return gflops / 1_000_000.0
    return None


def parse_residual_check(text):
    residual_block = re.search(r"HPL MxP Result(.+?)(?:test loop|test\s+\d+|\Z)", text, re.IGNORECASE | re.DOTALL)
    target = residual_block.group(1) if residual_block else text
    if re.search(r"\b(fail|failed|incorrect|wrong)\b", target, re.IGNORECASE):
        return "failed"
    if re.search(r"\b(pass|passed|successful)\b", target, re.IGNORECASE):
        return "passed"
    return None


def enrich_from_stdout(row, repo_root):
    stdout_file = row.get("stdout_file")
    if not stdout_file:
        return
    stdout_path = repo_root / stdout_file
    if not stdout_path.exists():
        return
    text = stdout_path.read_text(encoding="utf-8", errors="replace")
    if row.get("performance_pflops") is None:
        row["performance_pflops"] = parse_performance_pflops(text)
    if row.get("residual_check") is None:
        row["residual_check"] = parse_residual_check(text)


def campaign_target_matrix_size(cluster, nodes):
    return CAMPAIGN_MATRIX_TARGETS.get((cluster, maybe_int(nodes)))


def campaign_sized(row, cluster):
    target = campaign_target_matrix_size(cluster, row.get("node_count"))
    matrix_size = maybe_int(row.get("matrix_size"))
    if target is None or matrix_size != target or row.get("status") != "passed":
        return False
    return bool(row.get("preset") == "weak-study" and row.get("scaling_study") == "weak")


def evidence_type(row, cluster):
    existing = row.get("evidence_type")
    if campaign_sized(row, cluster):
        return "campaign"
    if existing in EVIDENCE_RANK:
        return existing
    if maybe_int(row.get("matrix_size")) == 8192 and row.get("preset", "smoke") == "smoke":
        return "smoke"
    return "staged"


def enrich_classification(row, cluster):
    nodes = maybe_int(row.get("node_count"))
    target = campaign_target_matrix_size(cluster, nodes)
    row["campaign_target_matrix_size"] = row.get("campaign_target_matrix_size") or target
    row["campaign_sized"] = campaign_sized(row, cluster)
    row["evidence_type"] = evidence_type(row, cluster)
    sloppy_type = normalize_sloppy_type(row.get("sloppy_type"))
    if sloppy_type is not None:
        row["sloppy_type"] = sloppy_type
        row["sloppy_precision"] = sloppy_type
    enrich_sizing(row)
    apply_public_inclusion(row)
    return row


def apply_public_inclusion(row):
    reason = public_exclusion_reason(row)
    row["public_inclusion"] = reason is None
    row["exclusion_reason"] = reason
    return row


def public_exclusion_reason(row):
    job_id = str(row.get("job_id") or "")
    run_id = str(row.get("run_id") or "")
    if job_id in PROOF_JOB_IDS or run_id.endswith("-j28147"):
        return "proof"
    status = row.get("status")
    if status != "passed":
        return f"status:{status or 'missing'}"
    if row.get("residual_check") != "passed":
        return "residual"
    if row.get("performance_pflops") is None:
        return "missing-performance"
    if row.get("preset") == PRE_RENAME_PRESET:
        return "pre-rename-preset"
    if row.get("preset") != "weak-study":
        return "non-weak-study"
    if row.get("evidence_type") != "campaign":
        return f"evidence:{row.get('evidence_type') or 'missing'}"
    return None


def enrich_sizing(row):
    matrix_size = maybe_int(row.get("matrix_size"))
    ranks = maybe_int(row.get("rank_count")) or maybe_int(row.get("gpu_count"))
    target = maybe_int(row.get("campaign_target_matrix_size"))
    if row.get("rank_count") is None and ranks is not None:
        row["rank_count"] = ranks
    nprow = maybe_int(row.get("nprow"))
    npcol = maybe_int(row.get("npcol"))
    if row.get("processor_grid") is None and nprow and npcol:
        row["processor_grid"] = f"{nprow}x{npcol}"
    if not nprow or not npcol:
        nprow, npcol = parse_processor_grid(row.get("processor_grid"))
    k_blocks = block_count(matrix_size, row.get("nb"))
    if k_blocks is not None:
        row["matrix_block_count_k"] = k_blocks
    multiple = grid_multiple(nprow, npcol)
    if multiple is not None:
        row["grid_multiple"] = multiple
    if k_blocks is not None and nprow and npcol:
        row["grid_balanced"] = (k_blocks % nprow == 0 and k_blocks % npcol == 0)
    if matrix_size:
        fp64_bytes = row.get("dense_fp64_matrix_bytes")
        if fp64_bytes is None:
            fp64_bytes = matrix_size * matrix_size * 8
            row["dense_fp64_matrix_bytes"] = fp64_bytes
        if row.get("dense_fp64_matrix_gib") is None:
            row["dense_fp64_matrix_gib"] = fp64_bytes / GIB
        if row.get("dense_fp64_matrix_gib_per_rank") is None and ranks:
            row["dense_fp64_matrix_gib_per_rank"] = row["dense_fp64_matrix_gib"] / ranks
    if matrix_size and target and row.get("campaign_size_ratio") is None:
        row["campaign_size_ratio"] = (matrix_size / target) ** 2
    if row.get("campaign_size_percent") is None and row.get("campaign_size_ratio") is not None:
        row["campaign_size_percent"] = row["campaign_size_ratio"] * 100.0
    scaling_study = row.get("scaling_study") or "exploratory"
    row["scaling_study"] = scaling_study
    baseline_size = maybe_int(row.get("baseline_matrix_size"))
    if baseline_size is None and scaling_study == "strong":
        baseline_size = matrix_size
    row["baseline_matrix_size"] = baseline_size
    nodes = maybe_int(row.get("node_count"))
    if (
        matrix_size
        and baseline_size
        and nodes
        and row.get("weak_relative_gpu_memory_percent") is None
    ):
        row["weak_relative_gpu_memory_percent"] = (
            (matrix_size * matrix_size) / (baseline_size * baseline_size * nodes) * 100.0
        )
    if scaling_study == "strong" and maybe_int(row.get("node_count")) == 1 and baseline_size == matrix_size:
        row["scaling_role"] = row.get("scaling_role") or "baseline"
    elif scaling_study == "strong":
        row["scaling_role"] = row.get("scaling_role") or "strong-scale"
    elif scaling_study in ("weak", "weak80", "weak90"):
        row["scaling_role"] = row.get("scaling_role") or "capacity"
    else:
        row["scaling_role"] = row.get("scaling_role") or "exploratory"
    row.setdefault("fp64_placement_policy", "hpl-mxp default; no --Anq-device or --fill-device override")
    row.setdefault("sizing_note", "Dense FP64 matrix footprint is a planning estimate, not exact GPU memory allocation.")
    return row


def baseline_policy_score(row):
    score = 0
    if row.get("preset") == "weak-study":
        score += 3
    if row.get("scaling_study") == "weak":
        score += 1
    if maybe_int(row.get("cpus_per_task")) and maybe_int(row.get("cpus_per_task")) >= 16:
        score += 1
    if row.get("mpi_use_mpi") == 1:
        score += 1
    if row.get("mpi_panel_broadcast_percent") == 50:
        score += 1
    if row.get("prioritize_factorization") == 1:
        score += 1
    if row.get("prioritize_trsm") == 0:
        score += 1
    if row.get("anq_device") in (None, "", 0) and row.get("fill_device") in (None, "", 0):
        score += 1
    if row.get("call_dgemv_with_multiple_threads") in (None, "", 0):
        score += 1
    if maybe_int(row.get("preset_gemm_kernel")) == 0:
        score += 1
    if maybe_int(row.get("u_panel_chunk_nbs")) == 16:
        score += 1
    if row.get("cpu_affinity") and row.get("mem_affinity") and row.get("ucx_affinity"):
        score += 1
    return score


def row_sort_key(row, cluster=None):
    nodes = maybe_int(row.get("node_count"))
    matrix_size = maybe_int(row.get("matrix_size"))
    target = campaign_target_matrix_size(cluster or row.get("cluster"), nodes)
    target_match = bool(target is not None and matrix_size == target)
    performance = row.get("performance_pflops")
    study_score = {"strong": 3, "weak": 2, "weak80": 2, "weak90": 2, "exploratory": 0}.get(row.get("scaling_study") or "exploratory", 0)
    return (
        EVIDENCE_RANK.get(row.get("evidence_type"), 0),
        STATUS_RANK.get(row.get("status"), -1),
        study_score,
        baseline_policy_score(row),
        1 if target_match else 0,
        float(performance) if performance is not None else -1.0,
        matrix_size or 0,
        str(row.get("run_id") or ""),
    )


def select_row(rows, cluster, nodes, public_only=False):
    candidates = [
        enrich_classification(row, cluster)
        for row in rows
        if maybe_int(row.get("node_count")) == nodes
    ]
    if public_only:
        candidates = [row for row in candidates if row.get("public_inclusion")]
    if not candidates:
        return None
    return sorted(candidates, key=lambda row: row_sort_key(row, cluster), reverse=True)[0]


def repeat_group_key(row):
    return (
        maybe_int(row.get("node_count")),
        maybe_int(row.get("matrix_size")),
        maybe_int(row.get("nb")),
        row.get("processor_grid"),
        row.get("preset"),
        row.get("scaling_study"),
        maybe_int(row.get("baseline_matrix_size")),
        maybe_int(row.get("cpus_per_task")),
        row.get("ompi_mca_coll"),
        row.get("ompi_mca_pml"),
        row.get("ompi_mca_btl"),
        row.get("ompi_mca_btl_tcp_if_include"),
        row.get("ompi_mca_oob_tcp_if_include"),
        row.get("pmix_mca_gds"),
        maybe_int(row.get("mpi_use_mpi")),
        maybe_int(row.get("mpi_panel_broadcast_percent")),
        maybe_int(row.get("prioritize_trsm")),
        maybe_int(row.get("prioritize_factorization")),
        maybe_int(row.get("anq_device")),
        maybe_int(row.get("fill_device")),
        maybe_int(row.get("fill_device_buffer_size_mb")),
        maybe_int(row.get("call_dgemv_with_multiple_threads")),
        row.get("gpu_affinity"),
        row.get("cpu_affinity"),
        row.get("mem_affinity"),
        row.get("ucx_affinity"),
        normalize_sloppy_type(row.get("sloppy_type")),
        maybe_int(row.get("u_panel_chunk_nbs")),
        maybe_int(row.get("test_loop")),
    )


def repeated_groups(rows, repeat_aggregation, public_only=False):
    aggregation = normalize_repeat_aggregation(repeat_aggregation)
    groups = {}
    for row in rows:
        enrich_classification(row, row.get("cluster") or "")
        if public_only and not row.get("public_inclusion"):
            continue
        if row.get("status") != "passed":
            continue
        if row.get("residual_check") != "passed":
            continue
        if row.get("performance_pflops") is None:
            continue
        key = repeat_group_key(row)
        groups.setdefault(key, []).append(row)
    out = []
    for key, group_rows in groups.items():
        if len(group_rows) < 2:
            continue
        group_rows = sorted(group_rows, key=lambda row: str(row.get("run_id") or ""))
        values = [row.get("performance_pflops") for row in group_rows]
        summary = aggregate_values(values, aggregation, standard_center="mean")
        first = group_rows[0]
        out.append({
            "node_count": first.get("node_count"),
            "matrix_size": first.get("matrix_size"),
            "nb": first.get("nb"),
            "processor_grid": first.get("processor_grid"),
            "grid_balanced": first.get("grid_balanced"),
            "weak_relative_gpu_memory_percent": first.get("weak_relative_gpu_memory_percent"),
            "preset": first.get("preset"),
            "scaling_study": first.get("scaling_study"),
            "scaling_role": first.get("scaling_role"),
            "baseline_matrix_size": first.get("baseline_matrix_size"),
            "sloppy_type": first.get("sloppy_type"),
            "u_panel_chunk_nbs": first.get("u_panel_chunk_nbs"),
            "gpu_affinity": first.get("gpu_affinity"),
            "cpu_affinity": first.get("cpu_affinity"),
            "mem_affinity": first.get("mem_affinity"),
            "ucx_affinity": first.get("ucx_affinity"),
            "sample_count": len(group_rows),
            "pass_count": sum(1 for row in group_rows if row.get("status") == "passed"),
            "residual_pass_count": sum(1 for row in group_rows if row.get("residual_check") == "passed"),
            "performance_pflops_center": summary.get("center"),
            "performance_pflops_center_label": summary.get("center_label"),
            "performance_pflops_min": summary.get("min"),
            "performance_pflops_max": summary.get("max"),
            "performance_pflops_dropped_low": summary.get("dropped_low"),
            "performance_pflops_dropped_high": summary.get("dropped_high"),
            "aggregation_note": summary.get("note"),
            "public_inclusion": True if public_only else all(row.get("public_inclusion") for row in group_rows),
            "exclusion_reason": None if public_only else first_exclusion_reason(group_rows),
            "run_ids": [row.get("run_id") for row in group_rows],
            "job_ids": [row.get("job_id") for row in group_rows],
        })
    return sorted(out, key=lambda item: (
        maybe_int(item.get("node_count")) or 0,
        maybe_int(item.get("matrix_size")) or 0,
        str(item.get("processor_grid") or ""),
        str(item.get("preset") or ""),
        str(item.get("scaling_study") or ""),
    ))


def first_exclusion_reason(rows):
    reasons = [row.get("exclusion_reason") for row in rows if row.get("exclusion_reason")]
    return ", ".join(sorted(set(reasons))) if reasons else None


def add_scaling_efficiency(rows, cluster):
    baselines = {}
    for row in rows:
        enrich_classification(row, cluster)
        if row.get("scaling_study") != "strong":
            row["scaling_efficiency_percent"] = None
            continue
        nodes = maybe_int(row.get("node_count"))
        matrix_size = maybe_int(row.get("matrix_size"))
        baseline_size = maybe_int(row.get("baseline_matrix_size")) or matrix_size
        perf = row.get("performance_pflops")
        if nodes == 1 and matrix_size == baseline_size and perf is not None:
            current = baselines.get(baseline_size)
            if current is None or row_sort_key(row, cluster) > row_sort_key(current, cluster):
                baselines[baseline_size] = row
    for row in rows:
        if row.get("scaling_study") != "strong":
            continue
        nodes = maybe_int(row.get("node_count"))
        perf = row.get("performance_pflops")
        baseline_size = maybe_int(row.get("baseline_matrix_size")) or maybe_int(row.get("matrix_size"))
        baseline = baselines.get(baseline_size)
        baseline_perf = baseline.get("performance_pflops") if baseline else None
        if not nodes or perf is None or not baseline_perf:
            continue
        if nodes == 1:
            row["scaling_efficiency_percent"] = None
            row["scaling_efficiency_label"] = "baseline"
        else:
            row["scaling_efficiency_percent"] = float(perf) / (float(baseline_perf) * nodes) * 100.0
    return rows


def fmt(value):
    if value is None:
        return "-"
    if isinstance(value, float):
        if value != 0 and abs(value) < 0.01:
            return f"{value:.3e}"
        return f"{value:.2f}"
    return str(value)


def comm_policy(row):
    values = []
    if row.get("mpi_use_mpi") is not None:
        values.append(f"mpi-use-mpi={row.get('mpi_use_mpi')}")
    if row.get("mpi_panel_broadcast_percent") is not None:
        values.append(f"panel={row.get('mpi_panel_broadcast_percent')}%")
    if row.get("prioritize_factorization") is not None:
        values.append(f"fact={row.get('prioritize_factorization')}")
    return ", ".join(values) if values else "-"


def scaling_efficiency_text(row):
    if row.get("scaling_efficiency_label"):
        return row["scaling_efficiency_label"]
    return fmt(row.get("scaling_efficiency_percent"))


def render_markdown(rows, date_value, cluster, repeat_aggregation="standard", row_filter=None):
    rows = add_scaling_efficiency(rows, cluster)
    public_rows = [row for row in rows if row.get("public_inclusion")]
    diagnostic_rows = [row for row in rows if not row.get("public_inclusion")]
    intro = "HPL-MxP weak-study rows use the reviewed weak-scaling matrix ladder with `weak-study`, `scaling_study=weak`, `NB=2048`, and the derived NPS4 affinity profile."
    missing_status = "not-run"
    missing_note = f"{cluster} HPL-MxP weak-study row not collected"
    lines = [
        f"# HPL-MxP Report {cluster} {date_value}",
        "",
        intro,
        "",
        "Matrix-footprint sizing is a planning estimate only; it is not an exact GPU memory allocation model for NVIDIA HPL-MxP and it is not the FP16 storage footprint.",
        "Relative per-rank matrix footprint is computed as `(N^2) / (baseline_N^2 * node_count) * 100` when a baseline `N` is available. It shows whether weak-scaling rows carry a similar matrix-footprint estimate per GPU/rank.",
        f"Repeat aggregation: `{normalize_repeat_aggregation(repeat_aggregation)}`.",
        f"Row filter: `{(row_filter or {}).get('description', 'none')}`.",
        "Public aggregate sections exclude skipped, failed, proof, smoke, staged, and pre-rename rows. Diagnostic/raw sections retain excluded rows for traceability.",
        f"Rows recorded with `preset={PRE_RENAME_PRESET}` are pre-rename historical entries from earlier on May 24; current public rows use `preset=weak-study`.",
        "",
        "| Nodes | GPUs | Preset | Evidence type | Scaling | Role | Matrix N | K | Grid | Balanced | Relative per-rank matrix footprint % | Target size | Status | PFLOPS | Residual | Evidence / blocker |",
        "| ---: | ---: | --- | --- | --- | --- | ---: | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |",
    ]
    for nodes, gpus, matrix_size in TARGETS[cluster]:
        row = select_row(rows, cluster, nodes, public_only=True)
        if row is None:
            lines.append(f"| {nodes} | {gpus} | - | - | - | - | {matrix_size} | - | - | - | - | - | {missing_status} | - | - | {missing_note} |")
            continue
        target = row.get("campaign_target_matrix_size")
        target_label = "yes" if row.get("campaign_sized") else f"no; target {target}" if target else "no target"
        lines.append(
            "| "
            + " | ".join([
                str(nodes),
                str(gpus),
                fmt(row.get("preset") or "smoke"),
                fmt(row.get("evidence_type")),
                fmt(row.get("scaling_study")),
                fmt(row.get("scaling_role")),
                fmt(row.get("matrix_size") or matrix_size),
                fmt(row.get("matrix_block_count_k")),
                fmt(row.get("processor_grid")),
                fmt(row.get("grid_balanced")),
                fmt(row.get("weak_relative_gpu_memory_percent")),
                target_label,
                fmt(row.get("status")),
                fmt(row.get("performance_pflops")),
                fmt(row.get("residual_check")),
                fmt(row.get("summary_path")),
            ])
            + " |"
        )
    if rows:
        repeat_rows = repeated_groups(rows, repeat_aggregation, public_only=True)
        if repeat_rows:
            lines.extend([
                "",
                "## Public Repeat Aggregates",
                "",
                "Aggregates use public-included rows with passed residuals and numeric PFLOPS for identical HPL-MxP shape and runtime controls.",
                "",
                "| Nodes | N | NB | Sloppy | U-panel | K | Grid | Balanced | Relative per-rank matrix footprint % | Preset | Scaling | Samples | Residual pass | PFLOPS center | Min PFLOPS | Max PFLOPS | Dropped low | Dropped high | Note | Run IDs |",
                "| ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | --- | --- |",
            ])
            for row in repeat_rows:
                lines.append(
                    "| "
                    + " | ".join([
                        fmt(row.get("node_count")),
                        fmt(row.get("matrix_size")),
                        fmt(row.get("nb")),
                        fmt(row.get("sloppy_type")),
                        fmt(row.get("u_panel_chunk_nbs")),
                        fmt(block_count(row.get("matrix_size"), row.get("nb"))),
                        fmt(row.get("processor_grid")),
                        fmt(row.get("grid_balanced")),
                        fmt(row.get("weak_relative_gpu_memory_percent")),
                        fmt(row.get("preset")),
                        fmt(row.get("scaling_study")),
                        fmt(row.get("sample_count")),
                        f"{fmt(row.get('residual_pass_count'))}/{fmt(row.get('sample_count'))}",
                        fmt(row.get("performance_pflops_center")),
                        fmt(row.get("performance_pflops_min")),
                        fmt(row.get("performance_pflops_max")),
                        fmt(row.get("performance_pflops_dropped_low")),
                        fmt(row.get("performance_pflops_dropped_high")),
                        fmt(row.get("aggregation_note")),
                        ", ".join([str(item) for item in row.get("run_ids", []) if item]),
                    ])
                    + " |"
                )
        scaling_rows = [
            row for row in public_rows
            if (row.get("scaling_study") or "exploratory") in ("strong", "weak", "weak80", "weak90")
        ]
        if scaling_rows:
            lines.extend([
                "",
                "## Public Scaling Study Rows",
                "",
                "Weak-study rows use the reviewed matrix-size ladder rather than a fixed-N strong-scaling baseline.",
                "",
                "| Run ID | Scaling | Role | Nodes | N | NB | Sloppy | U-panel | Baseline N | K | Grid | Balanced | Relative per-rank matrix footprint % | Status | PFLOPS | Residual | Evidence |",
                "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | --- | ---: | --- | --- |",
            ])
            for row in sorted(scaling_rows, key=lambda item: (
                str(item.get("scaling_study") or ""),
                maybe_int(item.get("node_count")) or 0,
                maybe_int(item.get("matrix_size")) or 0,
                str(item.get("run_id") or ""),
            )):
                lines.append(
                    "| "
                    + " | ".join([
                        fmt(row.get("run_id")),
                        fmt(row.get("scaling_study")),
                        fmt(row.get("scaling_role")),
                        fmt(row.get("node_count")),
                        fmt(row.get("matrix_size")),
                        fmt(row.get("nb")),
                        fmt(row.get("sloppy_type")),
                        fmt(row.get("u_panel_chunk_nbs")),
                        fmt(row.get("baseline_matrix_size")),
                        fmt(row.get("matrix_block_count_k")),
                        fmt(row.get("processor_grid")),
                        fmt(row.get("grid_balanced")),
                        fmt(row.get("weak_relative_gpu_memory_percent")),
                        fmt(row.get("status")),
                        fmt(row.get("performance_pflops")),
                        fmt(row.get("residual_check")),
                        fmt(row.get("summary_path")),
                    ])
                    + " |"
                )
        lines.extend([
            "",
            "## Diagnostic And Raw Rows",
            "",
            "These rows are retained for traceability and are not public aggregate evidence. Excluded rows include failed, skipped, proof, smoke, staged, and pre-rename entries.",
            "",
            "| Run ID | Public | Exclusion | Scaling | Role | Nodes | Node | N | NB | Sloppy | U-panel | Grid | CPUs/task | FP64 placement | Comm policy | DGEMV threads | Affinity | Status | PFLOPS | Residual | Evidence |",
            "| --- | --- | --- | --- | --- | ---: | --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |",
        ])
        for row in sorted(diagnostic_rows, key=lambda item: (
            maybe_int(item.get("node_count")) or 0,
            maybe_int(item.get("matrix_size")) or 0,
            str(item.get("run_id") or ""),
        )):
            lines.append(
                "| "
                + " | ".join([
                    fmt(row.get("run_id")),
                    fmt(row.get("public_inclusion")),
                    fmt(row.get("exclusion_reason")),
                    fmt(row.get("scaling_study")),
                    fmt(row.get("scaling_role")),
                    fmt(row.get("node_count")),
                    fmt(row.get("node")),
                    fmt(row.get("matrix_size")),
                    fmt(row.get("nb")),
                    fmt(row.get("sloppy_type")),
                    fmt(row.get("u_panel_chunk_nbs")),
                    fmt(row.get("processor_grid")),
                    fmt(row.get("cpus_per_task")),
                    fmt(row.get("fp64_placement_policy")),
                    comm_policy(row),
                    fmt(row.get("call_dgemv_with_multiple_threads")),
                    fmt("derived" if row.get("cpu_affinity") and row.get("mem_affinity") and row.get("ucx_affinity") else "custom" if row.get("gpu_affinity") or row.get("cpu_affinity") or row.get("mem_affinity") or row.get("ucx_affinity") else "unset"),
                    fmt(row.get("status")),
                    fmt(row.get("performance_pflops")),
                    fmt(row.get("residual_check")),
                    fmt(row.get("summary_path")),
                ])
                + " |"
            )
    return "\n".join(lines) + "\n"


def write_csv(path, rows, columns):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        for row in rows:
            writer.writerow({column: row.get(column) for column in columns})


def main():
    args = build_parser().parse_args()
    date_value = resolve_date(args.date)
    results_root = Path(args.results_root)
    output_dir = Path(args.output_dir) if args.output_dir else results_root / "reports" / date_value / "hpl-mxp"
    output_dir.mkdir(parents=True, exist_ok=True)
    row_filter = job_filter_metadata(args.job_id_min, args.job_id_max, args.job_id_list)
    rows = filter_rows_by_job(
        load_summaries(results_root, date_value, args.cluster),
        job_id_min=args.job_id_min,
        job_id_max=args.job_id_max,
        job_id_list=args.job_id_list,
    )
    rows = add_scaling_efficiency(rows, args.cluster)
    md_path = output_dir / f"hpl-mxp-{args.cluster}-{date_value}.md"
    summary_csv_path = output_dir / f"hpl-mxp-summary-{args.cluster}-{date_value}.csv"
    diagnostic_summary_csv_path = output_dir / f"hpl-mxp-diagnostic-summary-{args.cluster}-{date_value}.csv"
    repeat_csv_path = output_dir / f"hpl-mxp-repeat-aggregation-{args.cluster}-{date_value}.csv"
    json_path = output_dir / f"hpl-mxp-report-{args.cluster}-{date_value}.json"
    if not rows:
        report_status = "blocked" if args.cluster == "b200" else "not-run"
        report_status_note = "No HPL-MxP rows matched the selected date, cluster, and row filter."
    elif row_filter.get("active"):
        report_status = "filtered"
        report_status_note = (
            "Filtered public report; job-id filters are applied before public row "
            "selection and repeat aggregation."
        )
    else:
        report_status = "complete"
        report_status_note = "Unfiltered report for all HPL-MxP rows matching the selected date and cluster."
    repeat_aggregation = normalize_repeat_aggregation(args.repeat_aggregation)
    md_path.write_text(render_markdown(rows, date_value, args.cluster, repeat_aggregation, row_filter), encoding="utf-8")
    public_rows = [row for row in rows if row.get("public_inclusion")]
    repeat_rows = repeated_groups(rows, repeat_aggregation, public_only=True)
    diagnostic_repeat_rows = repeated_groups(rows, repeat_aggregation, public_only=False)
    summary_columns = [
        "date",
        "cluster",
        "run_id",
        "job_id",
        "node_count",
        "rank_count",
        "gpu_count",
        "node",
        "preset",
        "evidence_type",
        "scaling_study",
        "scaling_role",
        "matrix_size",
        "nb",
        "nprow",
        "npcol",
        "processor_grid",
        "sloppy_type",
        "u_panel_chunk_nbs",
        "cpus_per_task",
        "mpi_use_mpi",
        "mpi_panel_broadcast_percent",
        "prioritize_trsm",
        "prioritize_factorization",
        "anq_device",
        "call_dgemv_with_multiple_threads",
        "preset_gemm_kernel",
        "status",
        "return_code",
        "residual_check",
        "performance_pflops",
        "public_inclusion",
        "exclusion_reason",
        "summary_path",
    ]
    write_csv(summary_csv_path, public_rows, summary_columns)
    write_csv(diagnostic_summary_csv_path, rows, summary_columns)
    write_csv(repeat_csv_path, repeat_rows, [
        "node_count",
        "matrix_size",
        "nb",
        "processor_grid",
        "grid_balanced",
        "preset",
        "scaling_study",
        "scaling_role",
        "baseline_matrix_size",
        "sloppy_type",
        "u_panel_chunk_nbs",
        "sample_count",
        "pass_count",
        "residual_pass_count",
        "performance_pflops_center",
        "performance_pflops_center_label",
        "performance_pflops_min",
        "performance_pflops_max",
        "performance_pflops_dropped_low",
        "performance_pflops_dropped_high",
        "public_inclusion",
        "exclusion_reason",
        "aggregation_note",
        "run_ids",
        "job_ids",
    ])
    json_path.write_text(json.dumps({
        "schema_version": 1,
        "date": date_value,
        "cluster": args.cluster,
        "status": report_status,
        "status_note": report_status_note,
        "repeat_aggregation": repeat_aggregation,
        "row_filter": row_filter,
        "rows": rows,
        "public_rows": [row for row in rows if row.get("public_inclusion")],
        "repeat_aggregates": repeat_rows,
        "diagnostic_repeat_aggregates": diagnostic_repeat_rows,
        "outputs": {
            "markdown": str(md_path),
            "summary_csv": str(summary_csv_path),
            "diagnostic_summary_csv": str(diagnostic_summary_csv_path),
            "repeat_aggregation_csv": str(repeat_csv_path),
            "json": str(json_path),
        },
    }, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {md_path}")
    print(f"Wrote {summary_csv_path}")
    print(f"Wrote {diagnostic_summary_csv_path}")
    print(f"Wrote {repeat_csv_path}")
    print(f"Wrote {json_path}")


if __name__ == "__main__":
    raise SystemExit(main())
