#!/usr/bin/env python3
import argparse
import json
import statistics
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from repeat_aggregation import aggregate_values, normalize_repeat_aggregation

REPORT_STATS_LINK = "../../../../docs/stats-explained.md"


CURRENT_STUDY_CONFIG = {
    "batch_size": 512,
    "num_workers": 16,
    "prefetch_factor": 4,
    "pin_memory": True,
    "persistent_workers": True,
    "h2d_enabled": True,
}

BACKEND_COLORS = {
    "pytorch-cpu-dataloader": "tab:blue",
    "dali-gpu-decode": "tab:orange",
    "numpy-uint8-shards": "tab:olive",
    "numpy-fp16-shards": "tab:purple",
    "numpy-fp16-blocks-pytorch": "tab:green",
    "dali-numpy-fp16-cpu": "tab:cyan",
    "dali-numpy-fp16-gds": "tab:orange",
    "dali-numpy-fp16-blocks-cpu": "tab:gray",
    "dali-numpy-fp16-blocks-gds": "tab:orange",
}


def backend_display(value):
    return {
        "pytorch-cpu-dataloader": "torch-cpu",
        "dali-gpu-decode": "dali-jpeg",
        "numpy-uint8-shards": "np-uint8",
        "numpy-fp16-shards": "np-fp16",
        "numpy-fp16-blocks-pytorch": "np-block-torch",
        "dali-numpy-fp16-cpu": "dali-np-cpu",
        "dali-numpy-fp16-gds": "dali-np-gds",
        "dali-numpy-fp16-blocks-cpu": "dali-block-cpu",
        "dali-numpy-fp16-blocks-gds": "dali-block-gds",
    }.get(value, value or "-")

CURRENT_STUDY_COVERAGE = [
    {
        "case": "1 node sharded",
        "sampler_mode": "distributed-sharded",
        "node_count": 1,
        "requested_gpu_count": 8,
        "purpose": "DDP-style input path on one node",
    },
    {
        "case": "2 node sharded diagnostic",
        "sampler_mode": "distributed-sharded",
        "node_count": 2,
        "requested_gpu_count": 16,
        "purpose": "repeatable small multi-node comparison",
    },
    {
        "case": "4 node sharded",
        "sampler_mode": "distributed-sharded",
        "node_count": 4,
        "requested_gpu_count": 32,
        "purpose": "memo scale point and current largest reviewed scale",
    },
]

CAMPAIGN_NODE_TARGETS_BY_CLUSTER = {
    "b200": [1, 4, 8, 16],
    "rtxpro6000": [1, 2, 4],
}

DELIVERABLE_GAPS = [
    "Rows produced before the May 1 metadata update do not include estimated VAST read GB/s or DataLoader worker CPU utilization; rerun the affected study rows before publishing them as final evidence.",
    "For B200, any unrun 8-node or 16-node rows must carry an explicit availability note in the rendered report.",
]

UNTRUSTED_RULES = [
    {
        "date": "2026-04-25",
        "num_workers": 16,
        "reason": "2026-04-25 num_workers=16 exploratory rows are untrusted/anomalous pending investigation.",
    }
]

def build_parser():
    parser = argparse.ArgumentParser(description="Render dataloader benchmark tables and plots.")
    parser.add_argument("--date", required=True, help="UTC date to render, or today/yesterday")
    parser.add_argument("--cluster", default="b200")
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--include-smoke", action="store_true", help="Include short smoke rows in CSV, plots, and Markdown.")
    parser.add_argument("--include-untrusted", action="store_true")
    parser.add_argument("--repeat-aggregation", default="standard", choices=["standard", "olympic"])
    return parser


def resolve_date(value):
    if value not in {"today", "yesterday"}:
        return value
    import datetime as dt

    offset = 0 if value == "today" else 1
    return (dt.datetime.now(dt.timezone.utc).date() - dt.timedelta(days=offset)).isoformat()


def is_untrusted(row):
    for rule in UNTRUSTED_RULES:
        if row.get("date") == rule["date"] and row.get("num_workers") == rule["num_workers"]:
            return True, rule["reason"]
    return False, ""


def is_smoke(summary):
    measured_batches = summary.get("measured_batches")
    warmup_batches = summary.get("warmup_batches")
    return (
        isinstance(measured_batches, int)
        and measured_batches < 100
    ) or (
        isinstance(warmup_batches, int)
        and warmup_batches < 20
    )


def row_from_summary(summary, summary_path, results_root, date_value, cluster, scope, host=None):
    untrusted, reason = is_untrusted(summary)
    smoke = is_smoke(summary)
    per_rank = summary.get("per_rank") or []
    sps_values = [
        item.get("samples_per_second")
        for item in per_rank
        if item.get("samples_per_second") is not None
    ]
    rank_min = summary.get("rank_min_samples_per_second")
    rank_median = summary.get("rank_median_samples_per_second")
    rank_max = summary.get("rank_max_samples_per_second")
    rank_imbalance_ratio = summary.get("rank_imbalance_ratio")
    rank_imbalance_percent = summary.get("rank_imbalance_percent")
    if sps_values:
        rank_min = min(sps_values) if rank_min is None else rank_min
        rank_median = statistics.median(sps_values) if rank_median is None else rank_median
        rank_max = max(sps_values) if rank_max is None else rank_max
        if rank_imbalance_ratio is None and rank_min and rank_min > 0:
            rank_imbalance_ratio = rank_max / rank_min
        if rank_imbalance_percent is None and rank_imbalance_ratio is not None:
            rank_imbalance_percent = (rank_imbalance_ratio - 1) * 100
    node_count = summary.get("node_count") or (1 if scope == "node" else None)
    world_size = summary.get("world_size") or summary.get("requested_gpu_count", 1)
    row = {
        "date": summary.get("date") or date_value,
        "cluster": summary.get("cluster") or cluster,
        "scope": summary.get("scope", scope),
        "host": summary.get("host", host),
        "run_id": summary.get("run_id"),
        "job_id": summary.get("job_id") or job_id_from_record(summary_path),
        "status": summary.get("status"),
        "launcher": summary.get("launcher", "local"),
        "mode": summary.get("mode", "single"),
        "sampler_mode": summary.get("sampler_mode", summary.get("mode", "single")),
        "node_count": node_count,
        "world_size": world_size,
        "node_list": summary.get("node_list") or host or "",
        "requested_gpu_count": summary.get("requested_gpu_count", world_size),
        "rank_count": summary.get("rank_count", 1),
        "input_backend": summary.get("input_backend", "pytorch-cpu-dataloader"),
        "study_class": summary.get("study_class"),
        "representation_class": summary.get("representation_class"),
        "transport_class": summary.get("transport_class"),
        "canonical_imagenet": summary.get("canonical_imagenet"),
        "derived_jpeg": summary.get("derived_jpeg"),
        "prepared_input_ceiling": summary.get("prepared_input_ceiling"),
        "input_delivery_endpoint": summary.get("input_delivery_endpoint"),
        "input_gpu_resident": summary.get("input_gpu_resident"),
        "labels_gpu_resident": summary.get("labels_gpu_resident"),
        "dali_num_threads": summary.get("dali_num_threads"),
        "dali_prefetch_queue_depth": summary.get("dali_prefetch_queue_depth"),
        "dali_decode_mode": summary.get("dali_decode_mode"),
        "dali_hw_decoder_load": summary.get("dali_hw_decoder_load"),
        "gds_requested": summary.get("gds_requested"),
        "dali_reader_device": summary.get("dali_reader_device"),
        "dali_numpy_use_o_direct": summary.get("dali_numpy_use_o_direct"),
        "dali_numpy_reader_prefetch_queue_depth": summary.get("dali_numpy_reader_prefetch_queue_depth"),
        "dali_gds_chunk_size": summary.get("dali_gds_chunk_size"),
        "cufile_log_path": summary.get("cufile_log_path"),
        "cufile_log_level": summary.get("cufile_log_level"),
        "storage_transport_path": summary.get("storage_transport_path"),
        "dataset_file_count": summary.get("dataset_file_count"),
        "dataset_block_count": summary.get("dataset_block_count"),
        "dataset_total_bytes": summary.get("dataset_total_bytes"),
        "logical_sample_count": summary.get("logical_sample_count"),
        "numpy_block_size": summary.get("numpy_block_size"),
        "numpy_block_cache_size": summary.get("numpy_block_cache_size"),
        "derived_root": summary.get("derived_root"),
        "derived_image_size": summary.get("derived_image_size"),
        "derived_samples_per_class": summary.get("derived_samples_per_class"),
        "derived_seed": summary.get("derived_seed"),
        "derived_format": summary.get("derived_format"),
        "derived_storage_dtype": summary.get("derived_storage_dtype"),
        "derived_storage_layout": summary.get("derived_storage_layout"),
        "derived_source_policy": summary.get("derived_source_policy"),
        "derived_jpeg_quality": summary.get("derived_jpeg_quality"),
        "batch_size": summary.get("batch_size"),
        "num_workers": summary.get("num_workers"),
        "prefetch_factor": summary.get("prefetch_factor"),
        "pin_memory": summary.get("pin_memory"),
        "persistent_workers": summary.get("persistent_workers"),
        "h2d_requested": summary.get("h2d_requested"),
        "h2d_enabled": summary.get("h2d_enabled"),
        "transfer_labels": summary.get("transfer_labels"),
        "drop_last": summary.get("drop_last"),
        "cpus_per_task": summary.get("cpus_per_task"),
        "warmup_batches": summary.get("warmup_batches"),
        "measured_batches": summary.get("measured_batches"),
        "samples_per_second": summary.get("samples_per_second"),
        "aggregate_samples_per_second": summary.get("aggregate_samples_per_second"),
        "aggregate_load_samples_per_second": summary.get("aggregate_load_samples_per_second"),
        "aggregate_h2d_samples_per_second": summary.get("aggregate_h2d_samples_per_second"),
        "estimated_read_bytes": summary.get("estimated_read_bytes"),
        "estimated_vast_read_gb_per_second": summary.get("estimated_vast_read_gb_per_second"),
        "worker_cpu_utilization_sample_count": summary.get("worker_cpu_utilization_sample_count"),
        "worker_cpu_utilization_mean_percent": summary.get("worker_cpu_utilization_mean_percent"),
        "worker_cpu_utilization_max_percent": summary.get("worker_cpu_utilization_max_percent"),
        "worker_cpu_utilization_total_percent": summary.get("worker_cpu_utilization_total_percent"),
        "nofile_requested": summary.get("nofile_requested"),
        "nofile_soft": summary.get("nofile_soft"),
        "nofile_hard": summary.get("nofile_hard"),
        "nofile_soft_min": summary.get("nofile_soft_min"),
        "nofile_soft_max": summary.get("nofile_soft_max"),
        "nofile_hard_min": summary.get("nofile_hard_min"),
        "nofile_hard_max": summary.get("nofile_hard_max"),
        "open_file_descriptor_count": summary.get("open_file_descriptor_count"),
        "open_file_descriptor_count_max": summary.get("open_file_descriptor_count_max"),
        "samples_total": summary.get("samples_total"),
        "elapsed_seconds": summary.get("elapsed_seconds"),
        "load_elapsed_seconds": summary.get("load_elapsed_seconds"),
        "h2d_elapsed_seconds": summary.get("h2d_elapsed_seconds"),
        "dataset_size": summary.get("dataset_size"),
        "class_count": summary.get("class_count"),
        "rank_min_samples_per_second": rank_min,
        "rank_median_samples_per_second": rank_median,
        "rank_max_samples_per_second": rank_max,
        "rank_imbalance_ratio": rank_imbalance_ratio,
        "rank_imbalance_percent": rank_imbalance_percent,
        "smoke": smoke,
        "untrusted": untrusted,
        "untrusted_reason": reason,
        "notes": summary.get("notes", ""),
        "summary_path": str(summary_path.relative_to(results_root.parent)),
        "evidence_path": str(summary_path.parent.relative_to(results_root.parent)),
    }
    return row


def job_id_from_record(summary_path):
    parts = list(summary_path.parts)
    try:
        parsed_index = parts.index("parsed")
    except ValueError:
        return None
    parts[parsed_index] = "raw"
    record_path = Path(*parts[:-1]) / "metadata" / "record.json"
    if not record_path.exists():
        return None
    try:
        record = json.loads(record_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    return record.get("job_id")


def load_rows(results_root, date_value, cluster):
    node_parsed_root = results_root / "by-date" / date_value / "parsed" / cluster / "nodes"
    multi_parsed_root = results_root / "by-date" / date_value / "parsed" / cluster / "multi-node" / "dataloader"
    rows = []

    node_summary_paths = sorted(node_parsed_root.glob("*/dataloader/*/summary.json")) if node_parsed_root.exists() else []
    for summary_path in node_summary_paths:
        try:
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            rows.append({
                "date": date_value,
                "cluster": cluster,
                "summary_path": str(summary_path),
                "status": "invalid-json",
                "smoke": False,
                "untrusted": False,
                "untrusted_reason": "",
                "notes": str(exc),
            })
            continue
        host = summary_path.relative_to(node_parsed_root).parts[0]
        rows.append(row_from_summary(summary, summary_path, results_root, date_value, cluster, "node", host))

    multi_summary_paths = sorted(multi_parsed_root.glob("*/summary.json")) if multi_parsed_root.exists() else []
    for summary_path in multi_summary_paths:
        try:
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            rows.append({
                "date": date_value,
                "cluster": cluster,
                "scope": "multi-node",
                "summary_path": str(summary_path),
                "status": "invalid-json",
                "smoke": False,
                "untrusted": False,
                "untrusted_reason": "",
                "notes": str(exc),
            })
            continue
        rows.append(row_from_summary(summary, summary_path, results_root, date_value, cluster, "multi-node"))
    return rows


def config_label(row):
    return (
        f"{backend_display(row.get('input_backend'))} "
        f"{row['sampler_mode']} {row.get('node_count', 1)}n/{row['requested_gpu_count']}g "
        f"bs{row['batch_size']} nw{row['num_workers']} "
        f"pf{row['prefetch_factor']} cpu{row['cpus_per_task']}"
    )


def write_throughput_plot(df, output_path):
    required_columns = {
        "mode",
        "node_count",
        "requested_gpu_count",
        "num_workers",
        "cpus_per_task",
        "run_id",
        "sampler_mode",
        "batch_size",
        "prefetch_factor",
        "samples_per_second",
    }
    if df.empty or not required_columns.issubset(df.columns):
        return False
    plot_df = df.sort_values(["mode", "node_count", "requested_gpu_count", "num_workers", "cpus_per_task", "run_id"]).copy()
    plot_df["config"] = plot_df.apply(config_label, axis=1)
    fig_height = max(4, min(12, 0.45 * len(plot_df) + 1.5))
    fig, ax = plt.subplots(figsize=(10, fig_height))
    bar_colors = [BACKEND_COLORS.get(value, "#9d9d9d") for value in plot_df["input_backend"]]
    ax.barh(plot_df["config"], plot_df["samples_per_second"], color=bar_colors)
    ax.set_xlabel("Samples/sec")
    ax.set_ylabel("Config")
    ax.set_title("Dataloader Throughput By Config")
    ax.grid(axis="x", alpha=0.25)
    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    plt.close(fig)
    return True


def write_rank_imbalance_plot(df, output_path):
    required_columns = {"run_id"}
    if df.empty or not required_columns.issubset(df.columns):
        return False
    plot_df = df.copy()
    if "rank_imbalance_percent" not in plot_df.columns:
        if "rank_imbalance_ratio" not in plot_df.columns:
            return False
        plot_df["rank_imbalance_percent"] = (plot_df["rank_imbalance_ratio"] - 1) * 100
    plot_df = plot_df[plot_df["rank_imbalance_percent"].notna()].copy()
    if plot_df.empty:
        return False
    plot_df = plot_df.sort_values(["rank_imbalance_percent", "run_id"])
    plot_df["config"] = plot_df.apply(config_label, axis=1)
    fig_height = max(4, min(12, 0.45 * len(plot_df) + 1.5))
    fig, ax = plt.subplots(figsize=(10, fig_height))
    bar_colors = [BACKEND_COLORS.get(value, "#9d9d9d") for value in plot_df["input_backend"]]
    ax.barh(plot_df["config"], plot_df["rank_imbalance_percent"], color=bar_colors)
    ax.axvline(5.0, color="black", linewidth=1)
    ax.set_xlabel("Rank imbalance (%)")
    ax.set_ylabel("Config")
    ax.set_title("Multi-rank DataLoader Rank Imbalance")
    ax.grid(axis="x", alpha=0.25)
    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    plt.close(fig)
    return True


def markdown_escape(value):
    text = "" if value is None else str(value)
    return text.replace("|", "\\|").replace("\n", " ")


def format_float(value, digits=2):
    if value is None or pd.isna(value):
        return ""
    return f"{float(value):.{digits}f}"


def format_float_dash(value, digits=2):
    text = format_float(value, digits)
    return text if text else "-"


def format_int_dash(value):
    if value is None or pd.isna(value):
        return "-"
    return str(int(value))


def format_bool_dash(value):
    if value is None or pd.isna(value):
        return "-"
    if isinstance(value, str):
        return value
    return "true" if bool(value) else "false"


def numeric_value(row, key):
    value = row.get(key)
    if value is None or pd.isna(value):
        return None
    return float(value)


def int_value(row, key):
    value = numeric_value(row, key)
    return None if value is None else int(value)


def bool_value(row, key):
    value = row.get(key)
    if value is None or pd.isna(value):
        return None
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "passed"}
    return bool(value)


def batch_load_ms(row):
    measured_batches = numeric_value(row, "measured_batches")
    load_elapsed_seconds = numeric_value(row, "load_elapsed_seconds")
    if not measured_batches or measured_batches <= 0 or load_elapsed_seconds is None:
        return None
    return (load_elapsed_seconds / measured_batches) * 1000


def images_per_gpu(row):
    samples_per_second = numeric_value(row, "samples_per_second")
    gpu_count = numeric_value(row, "requested_gpu_count")
    if samples_per_second is None or not gpu_count:
        return None
    return samples_per_second / gpu_count


def images_per_node(row):
    samples_per_second = numeric_value(row, "samples_per_second")
    node_count = numeric_value(row, "node_count")
    if samples_per_second is None or not node_count:
        return None
    return samples_per_second / node_count


def config_matches(row, config):
    for key, expected in config.items():
        if isinstance(expected, bool):
            if bool_value(row, key) is not expected:
                return False
        elif int_value(row, key) != expected:
            return False
    return True


def current_study_config_matches(row):
    return config_matches(row, CURRENT_STUDY_CONFIG)


def original_pytorch_rows(df):
    rows = passed_measured_rows(df)
    if rows.empty:
        return rows
    derived = rows.get("derived_root")
    if derived is None:
        derived_mask = True
    else:
        derived_mask = derived.isna() | (derived == "")
    return rows[
        (rows["input_backend"] == "pytorch-cpu-dataloader")
        & derived_mask
    ].copy()


def selected_study_config(df):
    rows = original_pytorch_rows(df)
    if rows.empty:
        return CURRENT_STUDY_CONFIG
    rows = rows[
        (rows["sampler_mode"] == "distributed-sharded")
        & (rows["node_count"] == 1)
        & (rows["requested_gpu_count"] == 8)
    ].copy()
    if rows.empty:
        return CURRENT_STUDY_CONFIG
    group_columns = [
        "batch_size",
        "num_workers",
        "prefetch_factor",
        "pin_memory",
        "persistent_workers",
        "h2d_enabled",
        "transfer_labels",
        "drop_last",
        "warmup_batches",
        "measured_batches",
    ]
    group_columns = [column for column in group_columns if column in rows.columns]
    candidates = []
    for _key, group in rows.groupby(group_columns, dropna=False):
        if len(group) < 5:
            continue
        values = [float(value) for value in group["samples_per_second"].dropna().tolist()]
        if len(values) < 5:
            continue
        center = aggregate_values(values, "olympic", standard_center="mean").get("center")
        if center is None:
            continue
        first = group.iloc[0]
        candidates.append((center, {
            "batch_size": int_value(first, "batch_size"),
            "num_workers": int_value(first, "num_workers"),
            "prefetch_factor": int_value(first, "prefetch_factor"),
            "pin_memory": bool_value(first, "pin_memory"),
            "persistent_workers": bool_value(first, "persistent_workers"),
            "h2d_enabled": bool_value(first, "h2d_enabled"),
        }))
    if not candidates:
        return CURRENT_STUDY_CONFIG
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1]


def rows_matching_case(df, case, config=None):
    if df.empty:
        return []
    matches = []
    for _, row in df.iterrows():
        if row.get("sampler_mode") != case["sampler_mode"]:
            continue
        if int_value(row, "node_count") != case["node_count"]:
            continue
        if int_value(row, "requested_gpu_count") != case["requested_gpu_count"]:
            continue
        if config is not None and not config_matches(row, config):
            continue
        matches.append(row)
    return sorted(
        matches,
        key=lambda row: (
            row.get("status") == "passed",
            int_value(row, "measured_batches") or 0,
            numeric_value(row, "samples_per_second") or -1.0,
            str(row.get("run_id") or ""),
        ),
        reverse=True,
    )


def passed_measured_rows(df):
    if df.empty:
        return df.copy()
    rows = df[
        (df["status"] == "passed")
        & (df["smoke"] != True)  # noqa: E712
        & (df["untrusted"] != True)  # noqa: E712
    ].copy()
    if "samples_per_second" in rows.columns:
        rows = rows[rows["samples_per_second"].notna()]
    return rows


def sweep_basis_rows(df, cluster):
    rows = passed_measured_rows(df)
    if rows.empty:
        return rows
    return rows[
        (rows["sampler_mode"] == "distributed-sharded")
        & (rows["node_count"] == 1)
        & (rows["requested_gpu_count"] == 8)
    ].copy()


def observed_values(rows, column):
    if rows.empty or column not in rows.columns:
        return "-"
    values = []
    for value in rows[column].dropna().tolist():
        if isinstance(value, bool):
            values.append("true" if value else "false")
        elif isinstance(value, float) and value.is_integer():
            values.append(str(int(value)))
        else:
            values.append(str(value))
    return ", ".join(sorted(set(values), key=lambda item: (len(item), item))) or "-"


def top_rows(rows, count=5):
    if rows.empty or "samples_per_second" not in rows.columns:
        return rows.copy()
    return rows.sort_values("samples_per_second", ascending=False).head(count).copy()


def row_config_text(row):
    return (
        f"{markdown_escape(row.get('sampler_mode'))} "
        f"{format_int_dash(row.get('node_count'))}n/{format_int_dash(row.get('requested_gpu_count'))}g "
        f"bs{format_int_dash(row.get('batch_size'))} "
        f"nw{format_int_dash(row.get('num_workers'))} "
        f"pf{format_int_dash(row.get('prefetch_factor'))} "
        f"pin={format_bool_dash(row.get('pin_memory'))}"
    )


def append_current_study_coverage_section(lines, df):
    study_config = selected_study_config(df)
    lines.extend([
        "",
        "## Current Study Coverage",
        "",
        "The active Benchmark 1 scale candidate is selected from repeated 1-node OFAT rows, then reused for scale rows. "
        f"Current selected config: `batch_size={study_config.get('batch_size')}`, "
        f"`num_workers={study_config.get('num_workers')}`, "
        f"`prefetch_factor={study_config.get('prefetch_factor')}`, "
        f"`pin_memory={int(bool(study_config.get('pin_memory')))}`, "
        f"`persistent_workers={int(bool(study_config.get('persistent_workers')))}`, and H2D enabled.",
        "",
        "| Case | Status | Nodes | GPUs | Node List | Images/sec | Images/sec/node | Images/sec/GPU | Est VAST GB/s | Worker CPU mean % | Load ms/batch | Imbalance % | Evidence |",
        "| --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ])
    for case in CURRENT_STUDY_COVERAGE:
        matches = rows_matching_case(df, case, study_config)
        if not matches:
            lines.append(
                "| "
                + " | ".join([
                    markdown_escape(case["case"]),
                    "missing",
                    str(case["node_count"]),
                    str(case["requested_gpu_count"]),
                    "-",
                    "-",
                    "-",
                    "-",
                    "-",
                    "-",
                    "-",
                    "-",
                    case["purpose"],
                ])
                + " |"
            )
            continue
        row = matches[0]
        lines.append(
            "| "
            + " | ".join([
                markdown_escape(case["case"]),
                markdown_escape(row.get("status")),
                format_int_dash(row.get("node_count")),
                format_int_dash(row.get("requested_gpu_count")),
                markdown_escape(row.get("node_list")),
                format_float_dash(row.get("samples_per_second")),
                format_float_dash(images_per_node(row)),
                format_float_dash(images_per_gpu(row)),
                format_float_dash(row.get("estimated_vast_read_gb_per_second")),
                format_float_dash(row.get("worker_cpu_utilization_mean_percent")),
                format_float_dash(batch_load_ms(row)),
                format_float_dash(row.get("rank_imbalance_percent")),
                markdown_escape(row.get("evidence_path") or row.get("summary_path")),
            ])
            + " |"
        )


def append_campaign_coverage_section(lines, df, cluster):
    rows = passed_measured_rows(df)
    targets = CAMPAIGN_NODE_TARGETS_BY_CLUSTER.get(cluster, [1, 4, 8, 16])
    lines.extend([
        "",
        "## Campaign Coverage",
        "",
        "Memo targets are tracked separately from the current study candidate so old rows do not appear as false failures. Rows collected before the added byte/CPU instrumentation can still satisfy throughput coverage, but not final metric coverage.",
        "",
        "Evidence note links resolve under `results/by-date/<date>/parsed/...` on AICR storage and are mirrored into the curated artifact bundle for public study pages.",
        "",
        "| Nodes | GPUs | Status | Best images/sec | Est VAST GB/s | Worker CPU mean % | Evidence / note |",
        "| ---: | ---: | --- | ---: | ---: | ---: | --- |",
    ])
    for nodes in targets:
        gpus = nodes * 8
        matches = []
        if not rows.empty:
            for _, row in rows.iterrows():
                if row.get("sampler_mode") != "distributed-sharded":
                    continue
                if int_value(row, "node_count") != nodes:
                    continue
                if int_value(row, "requested_gpu_count") != gpus:
                    continue
                matches.append(row)
        if not matches:
            lines.append(f"| {nodes} | {gpus} | missing | - | - | - | not run yet |")
            continue
        row = sorted(matches, key=lambda item: numeric_value(item, "samples_per_second") or -1.0, reverse=True)[0]
        metric_status = "complete" if numeric_value(row, "estimated_vast_read_gb_per_second") is not None and numeric_value(row, "worker_cpu_utilization_mean_percent") is not None else "needs metric rerun"
        lines.append(
            "| "
            + " | ".join([
                str(nodes),
                str(gpus),
                metric_status,
                format_float_dash(row.get("samples_per_second")),
                format_float_dash(row.get("estimated_vast_read_gb_per_second")),
                format_float_dash(row.get("worker_cpu_utilization_mean_percent")),
                markdown_escape(row.get("evidence_path") or row.get("summary_path")),
            ])
            + " |"
        )


def single_gpu_rows(df):
    rows = passed_measured_rows(df)
    if rows.empty:
        return rows
    return rows[
        (rows["sampler_mode"] == "single")
        & (rows["node_count"] == 1)
        & (rows["requested_gpu_count"] == 1)
        & (rows["h2d_enabled"] == True)  # noqa: E712
    ].copy()


def append_single_gpu_section(lines, df):
    rows = single_gpu_rows(df)
    lines.extend([
        "",
        "## Single-GPU Optimization",
        "",
        "Primary ranking uses passed, trusted, non-smoke `single` rows with H2D enabled. Loader-only and H2D-only rates are retained as explanatory metrics.",
        "",
    ])
    if rows.empty:
        lines.append("No trusted single-GPU optimization rows found yet.")
        return
    top = top_rows(rows, count=8)
    lines.extend([
        "| Rank | Run | Node | Images/sec | Load samples/sec | H2D samples/sec | Batch | Workers | Prefetch | Pin | Persistent | CPUs/task | Evidence |",
        "| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | --- |",
    ])
    for index, (_, row) in enumerate(top.iterrows(), start=1):
        lines.append(
            "| "
            + " | ".join([
                str(index),
                markdown_escape(row.get("run_id")),
                markdown_escape(row.get("node_list")),
                format_float_dash(row.get("samples_per_second")),
                format_float_dash(row.get("aggregate_load_samples_per_second")),
                format_float_dash(row.get("aggregate_h2d_samples_per_second")),
                format_int_dash(row.get("batch_size")),
                format_int_dash(row.get("num_workers")),
                format_int_dash(row.get("prefetch_factor")),
                format_bool_dash(row.get("pin_memory")),
                format_bool_dash(row.get("persistent_workers")),
                format_int_dash(row.get("cpus_per_task")),
                markdown_escape(row.get("evidence_path") or row.get("summary_path")),
            ])
            + " |"
        )


def append_sweep_section(lines, df, cluster):
    rows = sweep_basis_rows(df, cluster)
    study_config = selected_study_config(df)
    basis_text = "Sweep summaries use measured, trusted, passed `distributed-sharded` 1-node/8-GPU rows."
    lines.extend([
        "",
        "## Parameter Sweep",
        "",
        basis_text,
        "",
        "| Axis | Observed Values | Notes |",
        "| --- | --- | --- |",
        f"| Workers | {markdown_escape(observed_values(rows, 'num_workers'))} | Adaptive axis: `12,16,20` after batch selection |",
        f"| Batch size | {markdown_escape(observed_values(rows, 'batch_size'))} | Adaptive axis: `256,384,512,640,768` |",
        f"| Prefetch | {markdown_escape(observed_values(rows, 'prefetch_factor'))} | Adaptive axis: `2,4,6,8` after batch and worker selection |",
        f"| Pin memory | {markdown_escape(observed_values(rows, 'pin_memory'))} | Target check axis: `0,1` |",
        "",
        "### Top Measured Rows",
        "",
    ])
    top = top_rows(rows)
    if top.empty:
        lines.append("No trusted measured sweep rows found yet.")
    else:
        lines.extend([
            "| Run | Config | Node List | Images/sec | Images/sec/GPU | Load ms/batch | Imbalance % |",
            "| --- | --- | --- | ---: | ---: | ---: | ---: |",
        ])
        for _, row in top.iterrows():
            lines.append(
                "| "
                + " | ".join([
                    markdown_escape(row.get("run_id")),
                    row_config_text(row),
                    markdown_escape(row.get("node_list")),
                    format_float_dash(row.get("samples_per_second")),
                    format_float_dash(images_per_gpu(row)),
                    format_float_dash(batch_load_ms(row)),
                    format_float_dash(row.get("rank_imbalance_percent")),
                ])
                + " |"
            )

    lines.extend(["", "### Carry-Forward Recommendation", ""])
    carry_forward = []
    for _, row in rows.iterrows():
        if config_matches(row, study_config):
            carry_forward.append(row)
    carry_forward = sorted(
        carry_forward,
        key=lambda row: numeric_value(row, "samples_per_second") or -1.0,
        reverse=True,
    )
    if carry_forward:
        row = carry_forward[0]
        lines.append(
            "Carry forward the current study config unless a later, repeated sweep shows a clear gain without worse rank imbalance: "
            f"`batch_size={format_int_dash(row.get('batch_size'))}`, "
            f"`num_workers={format_int_dash(row.get('num_workers'))}`, "
            f"`prefetch_factor={format_int_dash(row.get('prefetch_factor'))}`, "
            f"`pin_memory={format_bool_dash(row.get('pin_memory'))}`, "
            f"`persistent_workers={format_bool_dash(row.get('persistent_workers'))}`."
        )
    else:
        lines.append("No measured carry-forward row is available yet for the current study config.")


def append_review_section(lines, df):
    lines.extend(["", "## Rows Needing Review", ""])
    if df.empty:
        lines.append("No rows found.")
        return
    review_rows = []
    for _, row in df.iterrows():
        reasons = []
        if row.get("status") != "passed":
            reasons.append(f"status={row.get('status')}")
        if bool(row.get("untrusted")):
            reasons.append("untrusted")
        imbalance = numeric_value(row, "rank_imbalance_percent")
        if imbalance is not None and imbalance > 25:
            reasons.append(f"rank imbalance {imbalance:.2f}%")
        if row.get("notes"):
            reasons.append(str(row.get("notes")))
        if reasons:
            review_rows.append((row, "; ".join(reasons)))
    if not review_rows:
        lines.append("No failed, untrusted, noted, or high-imbalance rows in the rendered set.")
        return
    lines.extend([
        "| Run | Status | Config | Node List | Images/sec | Reason | Evidence |",
        "| --- | --- | --- | --- | ---: | --- | --- |",
    ])
    for row, reason in review_rows:
        lines.append(
            "| "
            + " | ".join([
                markdown_escape(row.get("run_id")),
                markdown_escape(row.get("status")),
                row_config_text(row),
                markdown_escape(row.get("node_list")),
                format_float_dash(row.get("samples_per_second")),
                markdown_escape(reason),
                markdown_escape(row.get("evidence_path") or row.get("summary_path")),
            ])
            + " |"
        )


def repeated_group_key_columns(df):
    columns = [
        "sampler_mode",
        "node_count",
        "requested_gpu_count",
        "batch_size",
        "num_workers",
        "prefetch_factor",
        "pin_memory",
        "persistent_workers",
        "h2d_enabled",
        "transfer_labels",
        "drop_last",
        "warmup_batches",
        "measured_batches",
    ]
    return [column for column in columns if column in df.columns]


def append_repeat_summary_section(lines, df, repeat_aggregation="standard"):
    aggregation = normalize_repeat_aggregation(repeat_aggregation)
    center_label = "Olympic avg images/sec" if aggregation == "olympic" else "Mean images/sec"
    rows = passed_measured_rows(df)
    lines.extend([
        "",
        "## Repeated Config Summary",
        "",
        "Grouped rows use the same sampler, scale, DataLoader knobs, H2D settings, and run length. Repeat aggregation uses passed trusted numeric `samples_per_second` rows.",
        "",
    ])
    if rows.empty or "samples_per_second" not in rows.columns:
        lines.append("No trusted measured rows are available for repeat grouping.")
        return
    group_columns = repeated_group_key_columns(rows)
    if not group_columns:
        lines.append("No grouping columns are available.")
        return
    repeat_rows = []
    for key, group in rows.groupby(group_columns, dropna=False):
        if len(group) < 2:
            continue
        values = [float(value) for value in group["samples_per_second"].dropna().tolist()]
        if len(values) < 2:
            continue
        first = group.iloc[0]
        run_ids = ", ".join(str(value) for value in group["run_id"].dropna().tolist())
        job_ids = ", ".join(str(value) for value in group.get("job_id", pd.Series(dtype=object)).dropna().tolist())
        repeat_rows.append({
            "sampler_mode": first.get("sampler_mode"),
            "node_count": int_value(first, "node_count"),
            "requested_gpu_count": int_value(first, "requested_gpu_count"),
            "batch_size": int_value(first, "batch_size"),
            "num_workers": int_value(first, "num_workers"),
            "prefetch_factor": int_value(first, "prefetch_factor"),
            "warmup_batches": int_value(first, "warmup_batches"),
            "measured_batches": int_value(first, "measured_batches"),
            "count": len(values),
            "center": aggregate_values(values, aggregation, standard_center="mean").get("center"),
            "minimum": min(values),
            "maximum": max(values),
            "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
            "dropped": aggregate_values(values, aggregation, standard_center="mean"),
            "run_ids": run_ids,
            "job_ids": job_ids,
        })
    if not repeat_rows:
        lines.append("No repeated trusted measured configs found.")
        return
    repeat_rows.sort(key=lambda row: (row["sampler_mode"], row["node_count"], row["batch_size"], row["num_workers"], row["prefetch_factor"]))
    if aggregation == "olympic":
        lines.extend([
            f"| Sampler | Nodes | GPUs | Batch | Workers | Prefetch | Warmup | Measured | Samples | {center_label} | Min | Max | Dropped min/max | Stddev | Aggregation | Runs | Jobs |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | --- |",
        ])
    else:
        lines.extend([
            f"| Sampler | Nodes | GPUs | Batch | Workers | Prefetch | Warmup | Measured | Samples | {center_label} | Min | Max | Stddev | Runs | Jobs |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |",
        ])
    for row in repeat_rows:
        summary = row["dropped"]
        cells = [
            markdown_escape(row["sampler_mode"]),
            format_int_dash(row["node_count"]),
            format_int_dash(row["requested_gpu_count"]),
            format_int_dash(row["batch_size"]),
            format_int_dash(row["num_workers"]),
            format_int_dash(row["prefetch_factor"]),
            format_int_dash(row["warmup_batches"]),
            format_int_dash(row["measured_batches"]),
            str(row["count"]),
            format_float_dash(row["center"]),
            format_float_dash(row["minimum"]),
            format_float_dash(row["maximum"]),
        ]
        if aggregation == "olympic":
            dropped = "-"
            if summary.get("olympic_available"):
                dropped = f"{format_float_dash(summary.get('dropped_low'))}/{format_float_dash(summary.get('dropped_high'))}"
            cells.extend([dropped, format_float_dash(row["stdev"]), markdown_escape(summary.get("note") or "-")])
        else:
            cells.append(format_float_dash(row["stdev"]))
        cells.extend([
            markdown_escape(row["run_ids"]),
            markdown_escape(row["job_ids"]),
        ])
        lines.append("| " + " | ".join(cells) + " |")


def append_deliverable_gaps(lines):
    lines.extend(["", "## Study Coverage Notes", ""])
    lines.extend(f"- {gap}" for gap in DELIVERABLE_GAPS)


def write_markdown_report(df, output_path, csv_path, metadata_path, throughput_written, throughput_path, imbalance_written, imbalance_path, warnings, excluded_smoke_count, date_value, cluster, repeat_aggregation):
    passed_rows_count = int((df["status"] == "passed").sum()) if not df.empty and "status" in df.columns else 0
    non_passed_rows_count = int(len(df) - passed_rows_count)
    lines = [
        f"# Benchmark 1 DataLoader Report {cluster} {date_value}",
        "",
        "Scan-first DataLoader benchmark summary for study review.",
        "",
        "## Run Overview",
        "",
        f"- Date: `{date_value}`",
        f"- Cluster: `{cluster}`",
        f"- Repeat aggregation: `{repeat_aggregation}`",
        f"- Rendered rows: `{len(df)}`",
        f"- Passed rows: `{passed_rows_count}`",
        f"- Non-passed rows: `{non_passed_rows_count}`",
        f"- Omitted smoke rows: `{excluded_smoke_count}`",
        f"- Scope note: this dashboard summarizes available DataLoader evidence; treat it as final study evidence only after reviewing the study design.",
    ]
    lines.extend([
        "",
        "## Artifacts",
        "",
        f"- CSV: [{csv_path.name}](./{csv_path.name})",
        f"- JSON: [{metadata_path.name}](./{metadata_path.name})",
    ])
    if throughput_written:
        lines.append(f"- Throughput plot: [{throughput_path.name}](./{throughput_path.name})")
    if imbalance_written:
        lines.append(f"- Rank imbalance plot: [{imbalance_path.name}](./{imbalance_path.name})")

    if warnings:
        lines.extend(["", "## Warnings", ""])
        lines.extend(f"- {markdown_escape(warning)}" for warning in warnings)
    if excluded_smoke_count:
        lines.extend([
            "",
            "## Omitted Rows",
            "",
            f"- Excluded {excluded_smoke_count} smoke row(s). Re-render with `--include-smoke` to include launch-validation runs.",
        ])

    append_single_gpu_section(lines, df)
    append_current_study_coverage_section(lines, df)
    append_campaign_coverage_section(lines, df, cluster)
    append_sweep_section(lines, df, cluster)
    append_repeat_summary_section(lines, df, repeat_aggregation)
    append_review_section(lines, df)
    append_deliverable_gaps(lines)

    if throughput_written:
        lines.extend([
            "",
            "## Throughput",
            "",
            f"![Dataloader throughput](./{throughput_path.name})",
        ])
    if imbalance_written:
        lines.extend([
            "",
            "## Rank Imbalance",
            "",
            f"![Dataloader rank imbalance](./{imbalance_path.name})",
        ])

    lines.extend([
        "",
        "## Detailed Rows",
        "",
        f"Rank min/median/max definitions follow [Stats Explained]({REPORT_STATS_LINK}).",
        "",
    ])
    if df.empty:
        lines.append("No dataloader rows found.")
    else:
        table_df = df.sort_values(
            ["mode", "node_count", "requested_gpu_count", "measured_batches", "num_workers", "run_id"],
            na_position="last",
        )
        lines.extend([
            "| Run | Job | Status | Sampler | Nodes | GPUs | Node List | Batch | Workers | Prefetch | Pin | Persistent | H2D | Samples/sec | Est VAST GB/s | Worker CPU mean % | Load samples/sec | H2D samples/sec | Rank min | Rank median | Rank max | Imbalance % | Evidence | Notes |",
            "| --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |",
        ])
        for _, row in table_df.iterrows():
            notes = "untrusted" if bool(row.get("untrusted")) else ""
            if bool(row.get("smoke")):
                notes = "smoke" if not notes else f"{notes}; smoke"
            if row.get("untrusted_reason"):
                notes = row.get("untrusted_reason")
            lines.append(
                "| "
                + " | ".join([
                    markdown_escape(row.get("run_id")),
                    markdown_escape(row.get("job_id")),
                    markdown_escape(row.get("status")),
                    markdown_escape(row.get("sampler_mode")),
                    markdown_escape(row.get("node_count")),
                    markdown_escape(row.get("requested_gpu_count")),
                    markdown_escape(row.get("node_list")),
                    markdown_escape(row.get("batch_size")),
                    markdown_escape(row.get("num_workers")),
                    markdown_escape(row.get("prefetch_factor")),
                    markdown_escape(row.get("pin_memory")),
                    markdown_escape(row.get("persistent_workers")),
                    markdown_escape(row.get("h2d_enabled")),
                    format_float(row.get("samples_per_second")),
                    format_float(row.get("estimated_vast_read_gb_per_second")),
                    format_float(row.get("worker_cpu_utilization_mean_percent")),
                    format_float(row.get("aggregate_load_samples_per_second")),
                    format_float(row.get("aggregate_h2d_samples_per_second")),
                    format_float(row.get("rank_min_samples_per_second")),
                    format_float(row.get("rank_median_samples_per_second")),
                    format_float(row.get("rank_max_samples_per_second")),
                    format_float(row.get("rank_imbalance_percent"), 2),
                    markdown_escape(row.get("evidence_path") or row.get("summary_path")),
                    markdown_escape(notes),
                ])
                + " |"
            )

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    args = build_parser().parse_args()
    date_value = resolve_date(args.date)
    results_root = Path(args.results_root)
    output_dir = Path(args.output_dir) if args.output_dir else results_root / "reports" / date_value / "dataloader"
    output_dir.mkdir(parents=True, exist_ok=True)

    rows = load_rows(results_root, date_value, args.cluster)
    all_df = pd.DataFrame(rows)
    warnings = sorted({row["untrusted_reason"] for row in rows if row.get("untrusted_reason")})
    if not all_df.empty and not args.include_smoke:
        df = all_df[all_df["smoke"] != True].copy()  # noqa: E712
    else:
        df = all_df.copy()
    excluded_smoke_count = int(len(all_df) - len(df))

    if not df.empty and not args.include_untrusted:
        df_for_plots = df[df["untrusted"] != True].copy()  # noqa: E712
    else:
        df_for_plots = df.copy()

    csv_path = output_dir / f"dataloader-summary-{args.cluster}-{date_value}.csv"
    throughput_path = output_dir / f"dataloader-throughput-{args.cluster}-{date_value}.png"
    imbalance_path = output_dir / f"dataloader-rank-imbalance-{args.cluster}-{date_value}.png"
    metadata_path = output_dir / f"dataloader-report-{args.cluster}-{date_value}.json"
    markdown_path = output_dir / f"dataloader-{args.cluster}-{date_value}.md"

    df.to_csv(csv_path, index=False)
    throughput_written = write_throughput_plot(df_for_plots, throughput_path)
    imbalance_written = write_rank_imbalance_plot(df_for_plots, imbalance_path)
    write_markdown_report(
        df,
        markdown_path,
        csv_path,
        metadata_path,
        throughput_written,
        throughput_path,
        imbalance_written,
        imbalance_path,
        warnings,
        excluded_smoke_count,
        date_value,
        args.cluster,
        args.repeat_aggregation,
    )

    metadata = {
        "schema_version": 1,
        "date": date_value,
        "cluster": args.cluster,
        "include_smoke": args.include_smoke,
        "include_untrusted": args.include_untrusted,
        "repeat_aggregation": args.repeat_aggregation,
        "raw_row_count": int(len(all_df)),
        "row_count": int(len(df)),
        "excluded_smoke_count": excluded_smoke_count,
        "plot_row_count": int(len(df_for_plots)),
        "warnings": warnings,
        "outputs": {
            "csv": str(csv_path),
            "markdown": str(markdown_path),
            "throughput_plot": str(throughput_path) if throughput_written else None,
            "rank_imbalance_plot": str(imbalance_path) if imbalance_written else None,
        },
    }
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")

    for warning in warnings:
        print(f"WARNING: {warning}", file=sys.stderr)
    print(f"Wrote {csv_path}")
    print(f"Wrote {markdown_path}")
    print(f"Wrote {metadata_path}")
    if throughput_written:
        print(f"Wrote {throughput_path}")
    if imbalance_written:
        print(f"Wrote {imbalance_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
