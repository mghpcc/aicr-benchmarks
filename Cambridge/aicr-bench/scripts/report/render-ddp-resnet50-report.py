#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

REPORT_STATS_LINK = "../../../../docs/stats-explained.md"
PREPARED_BLOCK_GDS_BACKEND = "dali-numpy-fp16-blocks-gds"
PREPARED_BLOCK_PYTORCH_BACKEND = "numpy-fp16-blocks-pytorch"
PREPARED_BLOCK_BACKENDS = {PREPARED_BLOCK_GDS_BACKEND, PREPARED_BLOCK_PYTORCH_BACKEND}


def build_parser():
    parser = argparse.ArgumentParser(description="Render DDP ResNet-50 benchmark reports.")
    parser.add_argument("--date", required=True, help="UTC date, today, or yesterday")
    parser.add_argument("--extra-date", action="append", default=[], help="Additional UTC date to include in the same report; may be repeated")
    parser.add_argument("--cluster", default="b200")
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--include-smoke", action="store_true")
    parser.add_argument("--include-short-runs", dest="include_smoke", action="store_true", help="Include short launch-validation rows.")
    parser.add_argument("--ascii", action="store_true", help="Print a compact terminal summary after writing files.")
    return parser


def resolve_date(value):
    if value == "today":
        return dt.datetime.now(dt.timezone.utc).date().isoformat()
    if value == "yesterday":
        return (dt.datetime.now(dt.timezone.utc).date() - dt.timedelta(days=1)).isoformat()
    return value


def resolve_dates(date_value, extra_dates):
    dates = [resolve_date(date_value)]
    for value in extra_dates:
        resolved = resolve_date(value)
        if resolved not in dates:
            dates.append(resolved)
    return dates


def is_smoke(row):
    measured = row.get("measured_iters")
    warmup = row.get("warmup_iters")
    return (isinstance(measured, int) and measured < 100) or (isinstance(warmup, int) and warmup < 20)


def max_per_rank(summary, key):
    values = []
    for row in summary.get("per_rank", []) or []:
        value = row.get(key)
        if isinstance(value, (int, float)):
            values.append(float(value))
    return max(values) if values else None


def truthy(value):
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def min_present(series):
    values = [value for value in series if value is not None and pd.notna(value)]
    return min(values) if values else None


def cufile_counts(results_root, date_value, cluster, run_id):
    counts = {
        "cufile_log_count": 0,
        "cufile_init_count": 0,
    }
    if not run_id:
        return counts
    raw_root = (
        results_root
        / "by-date"
        / str(date_value)
        / "raw"
        / str(cluster)
        / "multi-node"
        / "ddp-resnet50"
        / str(run_id)
        / "canonical"
        / "ranks"
    )
    if not raw_root.exists():
        return counts
    log_paths = sorted(raw_root.glob("rank-*/cufile.log"))
    counts["cufile_log_count"] = len(log_paths)
    for log_path in log_paths:
        try:
            text = log_path.read_text(encoding="utf-8", errors="replace").lower()
        except OSError:
            continue
        if "cufile" in text and ("init" in text or "initializ" in text):
            counts["cufile_init_count"] += 1
    return counts


def launcher_detail(row):
    launcher = row.get("launcher")
    if launcher != "srun":
        return launcher or ""
    cpu_bind = row.get("srun_cpu_bind")
    mem_bind = row.get("srun_mem_bind")
    if cpu_bind or mem_bind:
        return f"srun cpu={cpu_bind or 'default'} mem={mem_bind or 'default'}"
    return "srun default-bind"


def load_rows(results_root, date_value, cluster):
    parsed_root = results_root / "by-date" / date_value / "parsed" / cluster / "multi-node" / "ddp-resnet50"
    rows = []
    if not parsed_root.exists():
        return rows
    for summary_path in sorted(parsed_root.glob("*/summary.json")):
        try:
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            rows.append({"status": "invalid-json", "notes": str(exc), "summary_path": str(summary_path)})
            continue
        row = {
            "date": summary.get("date") or date_value,
            "cluster": summary.get("cluster") or cluster,
            "run_id": summary.get("run_id"),
            "job_id": summary.get("job_id"),
            "status": summary.get("status"),
            "launcher": summary.get("launcher"),
            "input_backend": summary.get("input_backend", "pytorch-cpu-dataloader"),
            "input_gpu_resident": summary.get("input_gpu_resident"),
            "node_count": summary.get("node_count"),
            "world_size": summary.get("world_size"),
            "precision": summary.get("precision"),
            "dataset_size": summary.get("dataset_size"),
            "batches_per_rank": summary.get("batches_per_rank"),
            "global_batch_size": summary.get("global_batch_size"),
            "batch_size_per_rank": summary.get("batch_size_per_rank"),
            "logical_batch_size_per_rank": summary.get("logical_batch_size_per_rank"),
            "reader_batch_size_per_rank": summary.get("reader_batch_size_per_rank"),
            "num_workers": summary.get("num_workers"),
            "prefetch_factor": summary.get("prefetch_factor"),
            "dali_num_threads": summary.get("dali_num_threads"),
            "dali_prefetch_queue_depth": summary.get("dali_prefetch_queue_depth"),
            "dali_numpy_reader_prefetch_queue_depth": summary.get("dali_numpy_reader_prefetch_queue_depth"),
            "dali_decode_mode": summary.get("dali_decode_mode"),
            "dali_hw_decoder_load": summary.get("dali_hw_decoder_load"),
            "gds_requested": summary.get("gds_requested"),
            "dali_reader_device": summary.get("dali_reader_device"),
            "dali_numpy_use_o_direct": summary.get("dali_numpy_use_o_direct"),
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
            "prepared_block_label_source": summary.get("prepared_block_label_source"),
            "synthetic_class_count": summary.get("synthetic_class_count"),
            "synthetic_image_size": summary.get("synthetic_image_size"),
            "synthetic_dtype": summary.get("synthetic_dtype"),
            "derived_root": summary.get("derived_root"),
            "derived_image_size": summary.get("derived_image_size"),
            "derived_samples_per_class": summary.get("derived_samples_per_class"),
            "derived_seed": summary.get("derived_seed"),
            "derived_format": summary.get("derived_format"),
            "derived_storage_dtype": summary.get("derived_storage_dtype"),
            "derived_storage_layout": summary.get("derived_storage_layout"),
            "pin_memory": summary.get("pin_memory"),
            "persistent_workers": summary.get("persistent_workers"),
            "warmup_iters": summary.get("warmup_iters"),
            "measured_iters": summary.get("measured_iters"),
            "samples_per_second": summary.get("samples_per_second"),
            "estimated_epoch_time_minutes": summary.get("estimated_epoch_time_minutes"),
            "rank_imbalance_ratio": summary.get("rank_imbalance_ratio"),
            "rank_imbalance_percent": summary.get("rank_imbalance_percent"),
            "step_mean_seconds_max_rank": summary.get("step_mean_seconds_max_rank"),
            "data_wait_mean_seconds_max_rank": summary.get("data_wait_mean_seconds_max_rank"),
            "h2d_mean_seconds_max_rank": summary.get("h2d_mean_seconds_max_rank"),
            "input_prepare_mean_seconds_max_rank": summary.get("input_prepare_mean_seconds_max_rank"),
            "train_mean_seconds_max_rank": summary.get("train_mean_seconds_max_rank", max_per_rank(summary, "train_mean_seconds")),
            "srun_mpi": summary.get("srun_mpi"),
            "srun_cpu_bind": summary.get("srun_cpu_bind"),
            "srun_mem_bind": summary.get("srun_mem_bind"),
            "node_list": summary.get("node_list"),
            "notes": summary.get("notes", ""),
            "summary_path": str(summary_path.relative_to(results_root.parent)),
        }
        counts = cufile_counts(results_root, row["date"], row["cluster"], row["run_id"])
        for key in counts:
            if counts[key] == 0 and summary.get(key) is not None:
                counts[key] = summary.get(key)
        row.update(counts)
        row["launcher_detail"] = launcher_detail(row)
        row["smoke"] = is_smoke(row)
        rows.append(row)
    return rows


def fmt(value, digits=2):
    if value is None or pd.isna(value):
        return ""
    return f"{float(value):.{digits}f}"


def add_derived_fields(df):
    if df.empty:
        return df
    out = df.copy()
    if "rank_imbalance_percent" not in out.columns:
        out["rank_imbalance_percent"] = float("nan")
    if "rank_imbalance_ratio" in out.columns:
        missing_imbalance = out["rank_imbalance_percent"].isna()
        out.loc[missing_imbalance, "rank_imbalance_percent"] = pd.to_numeric(
            out.loc[missing_imbalance, "rank_imbalance_ratio"],
            errors="coerce",
        ).apply(lambda value: (float(value) - 1.0) * 100.0 if pd.notna(value) else float("nan"))
    if "estimated_epoch_time_minutes" not in out.columns:
        out["estimated_epoch_time_minutes"] = float("nan")
    else:
        out["estimated_epoch_time_minutes"] = pd.to_numeric(out["estimated_epoch_time_minutes"], errors="coerce")
    if "dataset_size" in out.columns and "samples_per_second" in out.columns:
        missing_epoch = out["estimated_epoch_time_minutes"].isna()
        out.loc[missing_epoch, "estimated_epoch_time_minutes"] = out[missing_epoch].apply(
            lambda row: (
                float(row["dataset_size"]) / float(row["samples_per_second"]) / 60.0
                if pd.notna(row.get("dataset_size")) and pd.notna(row.get("samples_per_second")) and float(row.get("samples_per_second")) > 0
                else float("nan")
            ),
            axis=1,
        )
    out["scaling_efficiency_percent"] = None
    group_columns = [
        column
        for column in [
            "launcher",
            "input_backend",
            "precision",
            "batch_size_per_rank",
            "num_workers",
            "prefetch_factor",
            "dali_num_threads",
            "dali_prefetch_queue_depth",
            "dali_decode_mode",
            "dali_hw_decoder_load",
            "synthetic_image_size",
            "synthetic_dtype",
        ]
        if column in out.columns
    ]
    if not group_columns or "node_count" not in out.columns or "samples_per_second" not in out.columns:
        return out
    for _, group in out.groupby(group_columns, dropna=False):
        baseline = group[(group["node_count"] == 1) & group["samples_per_second"].notna()]
        if baseline.empty:
            continue
        baseline_sps = float(baseline["samples_per_second"].max())
        if baseline_sps <= 0:
            continue
        for index, row in group.iterrows():
            if pd.isna(row.get("samples_per_second")) or pd.isna(row.get("node_count")):
                continue
            nodes = float(row.get("node_count"))
            if nodes <= 0:
                continue
            out.at[index, "scaling_efficiency_percent"] = float(row.get("samples_per_second")) / (baseline_sps * nodes) * 100.0
    return out


def esc(value):
    return ("" if value is None else str(value)).replace("|", "\\|").replace("\n", " ")


def config_label(row):
    launcher = row.get("launcher_detail") or row.get("launcher") or ""
    backend = row.get("input_backend") or "pytorch-cpu-dataloader"
    size = row.get("derived_image_size")
    size_label = f" size{int(size)}" if size is not None and pd.notna(size) else ""
    logical_batch = row.get("logical_batch_size_per_rank") or row.get("batch_size_per_rank")
    file_batch = row.get("reader_batch_size_per_rank")
    file_label = f" filebs{file_batch}" if file_batch is not None and pd.notna(file_batch) else ""
    return f"{backend}{size_label} {launcher} {row.get('node_count')}n/{row.get('world_size')}g logicalbs{logical_batch}{file_label} nw{row.get('num_workers')}"


def input_label(row):
    backend = row.get("input_backend") or "pytorch-cpu-dataloader"
    size = row.get("derived_image_size")
    derived_format = row.get("derived_format")
    storage_dtype = row.get("derived_storage_dtype")
    if size is not None and pd.notna(size):
        suffix = f" size={int(size)}"
        if derived_format is not None and pd.notna(derived_format):
            suffix += f" {derived_format}"
        if storage_dtype is not None and pd.notna(storage_dtype):
            suffix += f" {storage_dtype}"
        return f"{backend}{suffix}"
    if backend == "synthetic-gpu":
        image_size = row.get("synthetic_image_size")
        dtype = row.get("synthetic_dtype")
        parts = [f"classes={row.get('synthetic_class_count')}"]
        if image_size is not None and pd.notna(image_size):
            parts.append(f"size={int(image_size)}")
        if dtype is not None and pd.notna(dtype):
            parts.append(str(dtype))
        if storage_dtype is not None and pd.notna(storage_dtype):
            storage_text = str(storage_dtype)
            if dtype is None or pd.isna(dtype) or storage_text != str(dtype):
                parts.append(storage_text)
        return f"{backend} " + " ".join(parts)
    return backend


def dali_config(row):
    backend = row.get("input_backend")
    if backend not in {"dali-gpu-decode", PREPARED_BLOCK_GDS_BACKEND}:
        return ""
    parts = []
    threads = row.get("dali_num_threads")
    queue = row.get("dali_prefetch_queue_depth")
    numpy_queue = row.get("dali_numpy_reader_prefetch_queue_depth")
    decode = row.get("dali_decode_mode")
    hw_load = row.get("dali_hw_decoder_load")
    reader_device = row.get("dali_reader_device")
    o_direct = row.get("dali_numpy_use_o_direct")
    chunk = row.get("dali_gds_chunk_size")
    if threads is not None and pd.notna(threads):
        parts.append(f"threads={int(threads)}")
    if queue is not None and pd.notna(queue):
        parts.append(f"queue={int(queue)}")
    if numpy_queue is not None and pd.notna(numpy_queue):
        parts.append(f"reader_queue={int(numpy_queue)}")
    if decode is not None and pd.notna(decode):
        parts.append(f"decode={decode}")
    if hw_load is not None and pd.notna(hw_load):
        parts.append(f"hw={float(hw_load):g}")
    if reader_device is not None and pd.notna(reader_device):
        parts.append(f"reader={reader_device}")
    if o_direct is not None and pd.notna(o_direct):
        parts.append(f"o_direct={str(o_direct).lower()}")
    if chunk is not None and pd.notna(chunk):
        parts.append(f"chunk={chunk}")
    return " ".join(parts)


def olympic_mean(values):
    clean = sorted(float(value) for value in values if value is not None and pd.notna(value))
    if not clean:
        return None
    if len(clean) >= 5:
        return sum(clean[1:-1]) / len(clean[1:-1])
    return sum(clean) / len(clean)


def aggregation_kind(count):
    if count >= 5:
        return "olympic"
    if count > 1:
        return "partial"
    return "single"


def aggregate_repeat_rows(df):
    if df.empty or "samples_per_second" not in df.columns:
        return pd.DataFrame()
    passed = df[(df["status"] == "passed") & (df["samples_per_second"].notna())].copy()
    if passed.empty:
        return pd.DataFrame()
    group_columns = [
        "cluster",
        "launcher_detail",
        "input_backend",
        "input_gpu_resident",
        "node_count",
        "world_size",
        "precision",
        "batch_size_per_rank",
        "logical_batch_size_per_rank",
        "reader_batch_size_per_rank",
        "num_workers",
        "prefetch_factor",
        "dali_num_threads",
        "dali_prefetch_queue_depth",
        "dali_numpy_reader_prefetch_queue_depth",
        "dali_decode_mode",
        "dali_hw_decoder_load",
        "dataset_size",
        "global_batch_size",
        "gds_requested",
        "dali_reader_device",
        "dali_numpy_use_o_direct",
        "dali_gds_chunk_size",
        "storage_transport_path",
        "dataset_file_count",
        "dataset_block_count",
        "dataset_total_bytes",
        "logical_sample_count",
        "numpy_block_size",
        "numpy_block_cache_size",
        "prepared_block_label_source",
        "derived_root",
        "derived_image_size",
        "derived_samples_per_class",
        "derived_seed",
        "derived_format",
        "derived_storage_dtype",
        "derived_storage_layout",
        "synthetic_class_count",
        "synthetic_image_size",
        "synthetic_dtype",
        "warmup_iters",
        "measured_iters",
    ]
    group_columns = [column for column in group_columns if column in passed.columns]
    rows = []
    for values, group in passed.groupby(group_columns, dropna=False):
        value_map = dict(zip(group_columns, values if isinstance(values, tuple) else (values,)))
        samples = [float(value) for value in group["samples_per_second"].dropna()]
        data_wait = [float(value) for value in group["data_wait_mean_seconds_max_rank"].dropna()] if "data_wait_mean_seconds_max_rank" in group.columns else []
        train = [float(value) for value in group["train_mean_seconds_max_rank"].dropna()] if "train_mean_seconds_max_rank" in group.columns else []
        row = {
            **value_map,
            "sample_count": len(samples),
            "aggregation_kind": aggregation_kind(len(samples)),
            "samples_per_second_mean": sum(samples) / len(samples) if samples else None,
            "samples_per_second_olympic": olympic_mean(samples),
            "samples_per_second_min": min(samples) if samples else None,
            "samples_per_second_max": max(samples) if samples else None,
            "data_wait_mean_seconds_olympic": olympic_mean(data_wait),
            "train_mean_seconds_olympic": olympic_mean(train),
            "cufile_log_count_min": min_present(group["cufile_log_count"]) if "cufile_log_count" in group.columns else None,
            "cufile_init_count_min": min_present(group["cufile_init_count"]) if "cufile_init_count" in group.columns else None,
            "run_ids": ",".join(str(value) for value in group["run_id"].dropna().tolist()),
            "job_ids": ",".join(str(value) for value in group["job_id"].dropna().tolist()),
        }
        dataset_total_bytes = row.get("dataset_total_bytes")
        logical_sample_count = row.get("logical_sample_count") or row.get("dataset_size")
        if (
            dataset_total_bytes is not None
            and pd.notna(dataset_total_bytes)
            and logical_sample_count is not None
            and pd.notna(logical_sample_count)
            and float(logical_sample_count) > 0
            and row.get("samples_per_second_olympic") is not None
        ):
            row["estimated_read_gb_per_second"] = (
                float(row["samples_per_second_olympic"]) * (float(dataset_total_bytes) / float(logical_sample_count)) / 1_000_000_000.0
            )
        else:
            row["estimated_read_gb_per_second"] = None
        rows.append(row)
    out = pd.DataFrame(rows)
    if out.empty:
        return out
    out["input_label"] = out.apply(input_label, axis=1)
    out = add_same_size_baseline_speedups(out)
    return out.sort_values(["node_count", "input_backend", "derived_image_size", "dali_num_threads", "dali_prefetch_queue_depth"], na_position="last")


def add_same_size_baseline_speedups(df):
    out = df.copy()
    out["speedup_vs_same_size_pytorch"] = float("nan")
    out["data_wait_ratio_vs_same_size_pytorch"] = float("nan")
    out["comparison_baseline_backend"] = None

    def key_value(value):
        return None if pd.isna(value) else value

    generic_key_columns = [
        "launcher_detail",
        "node_count",
        "world_size",
        "precision",
        "batch_size_per_rank",
        "num_workers",
        "prefetch_factor",
        "dataset_size",
        "derived_root",
        "derived_image_size",
        "derived_samples_per_class",
        "derived_seed",
        "derived_format",
        "derived_storage_dtype",
        "derived_storage_layout",
        "synthetic_class_count",
        "synthetic_image_size",
        "synthetic_dtype",
        "warmup_iters",
        "measured_iters",
    ]
    generic_key_columns = [column for column in generic_key_columns if column in out.columns]
    prepared_key_columns = [
        "launcher_detail",
        "node_count",
        "world_size",
        "precision",
        "dataset_size",
        "logical_batch_size_per_rank",
        "global_batch_size",
        "derived_root",
        "derived_image_size",
        "derived_samples_per_class",
        "derived_seed",
        "derived_format",
        "derived_storage_dtype",
        "derived_storage_layout",
        "logical_sample_count",
        "numpy_block_size",
        "warmup_iters",
        "measured_iters",
    ]
    prepared_key_columns = [column for column in prepared_key_columns if column in out.columns]

    def build_baselines(baseline_rows, key_columns):
        baselines = {}
        for _, row in baseline_rows.iterrows():
            key = tuple(key_value(row.get(column)) for column in key_columns)
            value = row.get("samples_per_second_olympic")
            if value is not None and pd.notna(value):
                baselines[key] = row
        return baselines

    generic_baselines = build_baselines(out[out["input_backend"] == "pytorch-cpu-dataloader"], generic_key_columns)
    prepared_baselines = build_baselines(out[out["input_backend"] == PREPARED_BLOCK_PYTORCH_BACKEND], prepared_key_columns)

    def apply_baseline(index, row, baseline, baseline_backend):
        if baseline is None:
            return
        out.at[index, "comparison_baseline_backend"] = baseline_backend
        baseline_sps = baseline.get("samples_per_second_olympic")
        row_sps = row.get("samples_per_second_olympic")
        if baseline_sps is not None and pd.notna(baseline_sps) and float(baseline_sps) > 0 and row_sps is not None and pd.notna(row_sps):
            out.at[index, "speedup_vs_same_size_pytorch"] = float(row_sps) / float(baseline_sps)
        baseline_wait = baseline.get("data_wait_mean_seconds_olympic")
        row_wait = row.get("data_wait_mean_seconds_olympic")
        if baseline_wait is not None and pd.notna(baseline_wait) and float(baseline_wait) > 0 and row_wait is not None and pd.notna(row_wait):
            out.at[index, "data_wait_ratio_vs_same_size_pytorch"] = float(row_wait) / float(baseline_wait)

    for index, row in out.iterrows():
        if row.get("input_backend") == PREPARED_BLOCK_GDS_BACKEND:
            key = tuple(key_value(row.get(column)) for column in prepared_key_columns)
            apply_baseline(index, row, prepared_baselines.get(key), PREPARED_BLOCK_PYTORCH_BACKEND)
            continue
        key = tuple(key_value(row.get(column)) for column in generic_key_columns)
        apply_baseline(index, row, generic_baselines.get(key), "pytorch-cpu-dataloader")

    for index, row in out.iterrows():
        backend = row.get("input_backend")
        if backend == "pytorch-cpu-dataloader":
            out.at[index, "comparison_baseline_backend"] = "pytorch-cpu-dataloader"
            out.at[index, "speedup_vs_same_size_pytorch"] = 1.0
            out.at[index, "data_wait_ratio_vs_same_size_pytorch"] = 1.0
        if backend == PREPARED_BLOCK_PYTORCH_BACKEND:
            out.at[index, "comparison_baseline_backend"] = PREPARED_BLOCK_PYTORCH_BACKEND
            out.at[index, "speedup_vs_same_size_pytorch"] = 1.0
            out.at[index, "data_wait_ratio_vs_same_size_pytorch"] = 1.0
    return out


def ddp_validation_rows(aggregate_df):
    if aggregate_df.empty:
        return []
    rows = aggregate_df[
        (~aggregate_df["input_backend"].isin({"pytorch-cpu-dataloader", *PREPARED_BLOCK_BACKENDS}))
        & (aggregate_df["samples_per_second_olympic"].notna())
    ].copy()
    if rows.empty:
        return []
    return rows.sort_values(["input_backend", "derived_image_size"], na_position="last").to_dict("records")


def prepared_pilot_rows(aggregate_df):
    if aggregate_df.empty or "input_backend" not in aggregate_df.columns:
        return []
    rows = aggregate_df[
        aggregate_df["input_backend"].isin(PREPARED_BLOCK_BACKENDS)
        & aggregate_df["samples_per_second_olympic"].notna()
    ].copy()
    if rows.empty:
        return []
    return rows.sort_values(["derived_image_size", "input_backend"], na_position="last").to_dict("records")


def cufile_summary(row):
    log_count = row.get("cufile_log_count_min")
    init_count = row.get("cufile_init_count_min")
    if log_count is None or pd.isna(log_count):
        return ""
    return f"logs={int(log_count)} init={int(init_count or 0)}"


def prepared_note(row):
    backend = row.get("input_backend")
    if backend == PREPARED_BLOCK_GDS_BACKEND:
        if truthy(row.get("gds_requested")) and str(row.get("dali_reader_device")) == "gpu" and truthy(row.get("dali_numpy_use_o_direct")):
            return "Diagnostic DALI NumPy GPU/cuFile path"
        return "Diagnostic DALI NumPy GPU path; GDS provenance incomplete"
    if backend == PREPARED_BLOCK_PYTORCH_BACKEND:
        return "PyTorch mmap prepared-block CPU comparator"
    return ""


def write_throughput_plot(df, path):
    if df.empty:
        return False
    plot_df = df.sort_values(["node_count", "launcher", "run_id"]).copy()
    plot_df["config"] = plot_df.apply(config_label, axis=1)
    fig_height = max(4, min(12, 0.45 * len(plot_df) + 1.5))
    fig, ax = plt.subplots(figsize=(10, fig_height))
    ax.barh(plot_df["config"], plot_df["samples_per_second"])
    ax.set_xlabel("Images/sec")
    ax.set_ylabel("Config")
    ax.set_title("DDP ResNet-50 Throughput")
    ax.grid(axis="x", alpha=0.25)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    return True


def write_scaling_plot(df, path):
    if df.empty or "samples_per_second" not in df.columns or "world_size" not in df.columns:
        return False
    plot_df = df[df["samples_per_second"].notna() & df["world_size"].notna()].copy()
    if plot_df.empty:
        return False
    fig, ax = plt.subplots(figsize=(8, 5))
    launcher_column = "launcher_detail" if "launcher_detail" in plot_df.columns else "launcher"
    group_columns = ["input_backend", launcher_column] if "input_backend" in plot_df.columns else [launcher_column]
    for values, group in plot_df.groupby(group_columns):
        group = group.sort_values("world_size")
        label = " ".join(str(value) for value in (values if isinstance(values, tuple) else (values,)))
        ax.plot(group["world_size"], group["samples_per_second"], marker="o", label=label)
    ax.set_xlabel("GPUs")
    ax.set_ylabel("Images/sec")
    ax.set_title("DDP ResNet-50 Scaling")
    ax.grid(alpha=0.25)
    ax.legend()
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    return True


def launcher_comparison_rows(df):
    if df.empty or "launcher" not in df.columns:
        return []
    required = {"node_count", "world_size", "precision", "input_backend", "batch_size_per_rank", "num_workers", "prefetch_factor", "warmup_iters", "measured_iters"}
    if not required.issubset(set(df.columns)):
        return []
    rows = []
    compare_df = df[
        (df["status"] == "passed")
        & (df["samples_per_second"].notna())
        & (df["launcher"].isin(["srun", "torchrun"]))
    ].copy()
    if compare_df.empty:
        return rows
    group_columns = [
        "node_count",
        "world_size",
        "precision",
        "input_backend",
        "batch_size_per_rank",
        "num_workers",
        "prefetch_factor",
        "dali_num_threads",
        "dali_prefetch_queue_depth",
        "dali_decode_mode",
        "dali_hw_decoder_load",
        "synthetic_image_size",
        "synthetic_dtype",
        "warmup_iters",
        "measured_iters",
    ]
    for values, group in compare_df.groupby(group_columns, dropna=False):
        by_launcher = {}
        for launcher, launcher_group in group.groupby("launcher"):
            best = launcher_group.sort_values("samples_per_second", ascending=False).iloc[0]
            by_launcher[launcher] = best
        if "srun" not in by_launcher or "torchrun" not in by_launcher:
            continue
        srun_sps = float(by_launcher["srun"]["samples_per_second"])
        torchrun_sps = float(by_launcher["torchrun"]["samples_per_second"])
        ratio = srun_sps / torchrun_sps if torchrun_sps > 0 else None
        value_map = dict(zip(group_columns, values if isinstance(values, tuple) else (values,)))
        rows.append({
            **value_map,
            "srun_samples_per_second": srun_sps,
            "torchrun_samples_per_second": torchrun_sps,
            "srun_to_torchrun_ratio": ratio,
            "srun_run_id": by_launcher["srun"].get("run_id"),
            "torchrun_run_id": by_launcher["torchrun"].get("run_id"),
            "srun_launcher_detail": by_launcher["srun"].get("launcher_detail"),
        })
    return sorted(rows, key=lambda row: (row.get("node_count") or 0, row.get("world_size") or 0))


def srun_binding_comparison_rows(df):
    if df.empty or "launcher" not in df.columns:
        return []
    required = {"node_count", "world_size", "precision", "input_backend", "batch_size_per_rank", "num_workers", "prefetch_factor", "warmup_iters", "measured_iters"}
    if not required.issubset(set(df.columns)):
        return []
    compare_df = df[
        (df["status"] == "passed")
        & (df["samples_per_second"].notna())
        & (df["launcher"] == "srun")
    ].copy()
    if compare_df.empty or "launcher_detail" not in compare_df.columns:
        return []
    group_columns = [
        "node_count",
        "world_size",
        "precision",
        "input_backend",
        "batch_size_per_rank",
        "num_workers",
        "prefetch_factor",
        "dali_num_threads",
        "dali_prefetch_queue_depth",
        "dali_decode_mode",
        "dali_hw_decoder_load",
        "synthetic_image_size",
        "synthetic_dtype",
        "warmup_iters",
        "measured_iters",
    ]
    rows = []
    for values, group in compare_df.groupby(group_columns, dropna=False):
        default_group = group[group["launcher_detail"] == "srun default-bind"]
        nobind_group = group[group["launcher_detail"] == "srun cpu=none mem=none"]
        if default_group.empty or nobind_group.empty:
            continue
        default_best = default_group.sort_values("samples_per_second", ascending=False).iloc[0]
        nobind_best = nobind_group.sort_values("samples_per_second", ascending=False).iloc[0]
        default_sps = float(default_best["samples_per_second"])
        nobind_sps = float(nobind_best["samples_per_second"])
        value_map = dict(zip(group_columns, values if isinstance(values, tuple) else (values,)))
        rows.append({
            **value_map,
            "default_samples_per_second": default_sps,
            "nobind_samples_per_second": nobind_sps,
            "nobind_to_default_ratio": nobind_sps / default_sps if default_sps > 0 else None,
            "default_train_mean_seconds": default_best.get("train_mean_seconds_max_rank"),
            "nobind_train_mean_seconds": nobind_best.get("train_mean_seconds_max_rank"),
            "default_run_id": default_best.get("run_id"),
            "nobind_run_id": nobind_best.get("run_id"),
        })
    return sorted(rows, key=lambda row: (row.get("node_count") or 0, row.get("world_size") or 0))


def write_markdown(
    df,
    aggregate_df,
    path,
    csv_path,
    aggregate_csv_path,
    meta_path,
    throughput_path,
    throughput_written,
    scaling_path,
    scaling_written,
    excluded_smoke_count,
):
    lines = [
        f"# DDP ResNet-50 Report  {path.stem}",
        "",
        "Fixed-iteration PyTorch DDP benchmark summary for public review.",
        "",
        "## Artifacts",
        "",
        f"- CSV: [{csv_path.name}](./{csv_path.name})",
        f"- Repeat aggregation CSV: [{aggregate_csv_path.name}](./{aggregate_csv_path.name})",
        f"- JSON: [{meta_path.name}](./{meta_path.name})",
    ]
    if throughput_written:
        lines.append(f"- Throughput plot: `{throughput_path.name}`")
    if scaling_written:
        lines.append(f"- Scaling plot: `{scaling_path.name}`")
    if excluded_smoke_count:
        lines.extend(["", "## Omitted Rows", "", f"- Excluded {excluded_smoke_count} smoke row(s). Re-render with `--include-smoke` to include launch-validation runs."])
    prepared_rows = prepared_pilot_rows(aggregate_df)
    if prepared_rows:
        lines.extend([
            "",
            "## Prepared-Tensor DDP Transport Pilot",
            "",
            "These rows are diagnostic prepared-input transport evidence, not canonical ImageNet JPEG evidence and not training-quality or accuracy evidence.",
            "The DALI row uses real prepared fp16 image tensors through the DALI NumPy GPU/cuFile path (`fn.readers.numpy(device=\"gpu\", use_o_direct=True)`) and synthetic GPU labels.",
            "The PyTorch comparator reads the same blocked tensor layout through CPU mmap and then transfers image tensors to the GPU.",
            "Keep DALI NumPy GPU/cuFile rows separate from DALI JPEG rows and from canonical ImageNet evidence.",
            "",
            "| Input | Samples | Aggregation | Img/s | Est read GB/s | Speedup vs PyTorch block | Data wait ratio | Logical batch/GPU | File batch/GPU | Block | Labels | Storage path | cuFile logs | Note |",
            "| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | --- |",
        ])
        for row in prepared_rows:
            lines.append("| " + " | ".join([
                esc(row.get("input_label")),
                esc(row.get("sample_count")),
                esc(row.get("aggregation_kind")),
                fmt(row.get("samples_per_second_olympic")),
                fmt(row.get("estimated_read_gb_per_second"), 2),
                fmt(row.get("speedup_vs_same_size_pytorch"), 2),
                fmt(row.get("data_wait_ratio_vs_same_size_pytorch"), 2),
                esc(row.get("logical_batch_size_per_rank") or row.get("batch_size_per_rank")),
                esc(row.get("reader_batch_size_per_rank")),
                esc(row.get("numpy_block_size")),
                esc(row.get("prepared_block_label_source") or "real labels"),
                esc(row.get("storage_transport_path")),
                esc(cufile_summary(row)),
                esc(prepared_note(row)),
            ]) + " |")
    validation_rows = ddp_validation_rows(aggregate_df)
    if validation_rows:
        lines.extend([
            "",
            "## Training-Throughput Validation",
            "",
            "Use this table to compare DataLoader-only candidates after they enter ResNet-50 DDP training.",
            "A real input candidate should beat the same-size PyTorch CPU DDP baseline and reduce or hold steady max-rank data wait.",
            "Synthetic GPU rows are shown as ceilings, not as real input pipelines. Prepared-tensor transport pilots are reported in their own diagnostic table.",
            "",
            "| Input | Samples | Aggregation | Olympic img/s | Speedup vs PyTorch | Data wait ratio | Validation note |",
            "| --- | ---: | --- | ---: | ---: | ---: | --- |",
        ])
        for row in validation_rows:
            backend = row.get("input_backend")
            speedup = row.get("speedup_vs_same_size_pytorch")
            data_wait_ratio = row.get("data_wait_ratio_vs_same_size_pytorch")
            if backend == "synthetic-gpu":
                note = "Ceiling only"
            elif speedup is not None and pd.notna(speedup) and float(speedup) >= 1.10 and data_wait_ratio is not None and pd.notna(data_wait_ratio) and float(data_wait_ratio) <= 1.0:
                note = "Validated training win"
            elif speedup is not None and pd.notna(speedup) and float(speedup) >= 1.10:
                note = "Throughput win; inspect data wait"
            else:
                note = "No training win"
            lines.append("| " + " | ".join([
                esc(row.get("input_label")),
                esc(row.get("sample_count")),
                esc(row.get("aggregation_kind")),
                fmt(row.get("samples_per_second_olympic")),
                fmt(speedup, 2),
                fmt(data_wait_ratio, 2),
                esc(note),
            ]) + " |")
    lines.extend([
        "",
        "## Validation Stop Conditions",
        "",
        "- Compare each candidate to the same-size PyTorch CPU DDP baseline in this report.",
        "- Treat a row as not accepted if throughput improves but max-rank data-wait time does not improve or hold steady; that suggests the gain may not come from the input path.",
        "- Treat rank imbalance, GPU health faults, timeout, coredump, or missing parsed throughput as diagnostic rather than final evidence.",
        "- Show synthetic GPU-resident rows as ceilings for context, not as real input-pipeline replacements.",
        "- Keep prepared-tensor DALI NumPy GPU/cuFile rows separate from canonical ImageNet JPEG rows and disclose synthetic GPU labels.",
        "- If `batch/GPU=256` fails from memory pressure, rerun once at `128` and label it as a reduced-batch smoke row.",
        "",
    ])
    if not aggregate_df.empty:
        lines.extend([
            "",
            "## Repeat Aggregation",
            "",
            "Rows with five or more samples use Olympic aggregation: drop the minimum and maximum images/sec values and average the remaining samples. Rows with fewer samples report the arithmetic mean and are labeled `partial` or `single`.",
            "",
            "| Input | Launcher | Nodes | GPUs | Logical batch/GPU | File batch/GPU | Workers | Prefetch | DALI config | Storage path | Labels | Est read GB/s | Samples | Aggregation | Olympic img/s | Mean img/s | Min img/s | Max img/s | Speedup vs PyTorch | Data wait ratio | Olympic data wait | Olympic train s | Jobs |",
            "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
        ])
        for _, row in aggregate_df.iterrows():
            lines.append("| " + " | ".join([
                esc(row.get("input_label")),
                esc(row.get("launcher_detail")),
                esc(row.get("node_count")),
                esc(row.get("world_size")),
                esc(row.get("logical_batch_size_per_rank") or row.get("batch_size_per_rank")),
                esc(row.get("reader_batch_size_per_rank")),
                esc(row.get("num_workers")),
                esc(row.get("prefetch_factor")),
                esc(dali_config(row)),
                esc(row.get("storage_transport_path")),
                esc(row.get("prepared_block_label_source")),
                fmt(row.get("estimated_read_gb_per_second"), 2),
                esc(row.get("sample_count")),
                esc(row.get("aggregation_kind")),
                fmt(row.get("samples_per_second_olympic")),
                fmt(row.get("samples_per_second_mean")),
                fmt(row.get("samples_per_second_min")),
                fmt(row.get("samples_per_second_max")),
                fmt(row.get("speedup_vs_same_size_pytorch"), 2),
                fmt(row.get("data_wait_ratio_vs_same_size_pytorch"), 2),
                fmt(row.get("data_wait_mean_seconds_olympic"), 4),
                fmt(row.get("train_mean_seconds_olympic"), 4),
                esc(row.get("job_ids")),
            ]) + " |")
    comparisons = launcher_comparison_rows(df)
    if comparisons:
        lines.extend([
            "",
            "## Launcher Comparison",
            "",
            "| Input | Nodes | GPUs | Batch/GPU | Workers | Prefetch | Warmup | Measured | torchrun img/s | srun img/s | srun/torchrun | srun binding | Runs |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |",
        ])
        for row in comparisons:
            lines.append("| " + " | ".join([
                esc(row.get("input_backend")),
                esc(row.get("node_count")),
                esc(row.get("world_size")),
                esc(row.get("batch_size_per_rank")),
                esc(row.get("num_workers")),
                esc(row.get("prefetch_factor")),
                esc(row.get("warmup_iters")),
                esc(row.get("measured_iters")),
                fmt(row.get("torchrun_samples_per_second")),
                fmt(row.get("srun_samples_per_second")),
                fmt(row.get("srun_to_torchrun_ratio"), 3),
                esc(row.get("srun_launcher_detail")),
                esc(f"torchrun={row.get('torchrun_run_id')} srun={row.get('srun_run_id')}"),
            ]) + " |")
    binding_rows = srun_binding_comparison_rows(df)
    if binding_rows:
        lines.extend([
            "",
            "## Srun Binding Comparison",
            "",
            "| Input | Nodes | GPUs | Batch/GPU | Workers | Prefetch | Warmup | Measured | default-bind img/s | no-bind img/s | no-bind/default | default train s | no-bind train s | Runs |",
            "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
        ])
        for row in binding_rows:
            lines.append("| " + " | ".join([
                esc(row.get("input_backend")),
                esc(row.get("node_count")),
                esc(row.get("world_size")),
                esc(row.get("batch_size_per_rank")),
                esc(row.get("num_workers")),
                esc(row.get("prefetch_factor")),
                esc(row.get("warmup_iters")),
                esc(row.get("measured_iters")),
                fmt(row.get("default_samples_per_second")),
                fmt(row.get("nobind_samples_per_second")),
                fmt(row.get("nobind_to_default_ratio"), 2),
                fmt(row.get("default_train_mean_seconds"), 4),
                fmt(row.get("nobind_train_mean_seconds"), 4),
                esc(f"default={row.get('default_run_id')} no-bind={row.get('nobind_run_id')}"),
            ]) + " |")
    lines.extend([
        "",
        "## Rows",
        "",
        f"Mean timing fields follow [Stats Explained]({REPORT_STATS_LINK}).",
        "",
    ])
    if df.empty:
        lines.append(
            "No DDP rows found for this date and cluster. Check that "
            "`parsed/<date>` contains DDP summaries, or pass "
            "`--include-short-runs` to include shorter teaching rows."
        )
    else:
        lines.extend([
            "| Run | Job | Status | Input | GPU resident | Launcher | Nodes | GPUs | Precision | Logical batch/GPU | File batch/GPU | Workers | Prefetch | DALI config | Storage path | Labels | Images/sec | Epoch min | Scaling eff % | Rank imbalance % | Step s | Train s | Data Wait | H2D | Input Prep | Notes |",
            "| --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
        ])
        for _, row in df.sort_values(["input_backend", "node_count", "launcher", "run_id"], na_position="last").iterrows():
            notes = "smoke" if bool(row.get("smoke")) else row.get("notes", "")
            lines.append("| " + " | ".join([
                esc(row.get("run_id")),
                esc(row.get("job_id")),
                esc(row.get("status")),
                esc(input_label(row)),
                esc(row.get("input_gpu_resident")),
                esc(row.get("launcher_detail")),
                esc(row.get("node_count")),
                esc(row.get("world_size")),
                esc(row.get("precision")),
                esc(row.get("logical_batch_size_per_rank") or row.get("batch_size_per_rank")),
                esc(row.get("reader_batch_size_per_rank")),
                esc(row.get("num_workers")),
                esc(row.get("prefetch_factor")),
                esc(dali_config(row)),
                esc(row.get("storage_transport_path")),
                esc(row.get("prepared_block_label_source")),
                fmt(row.get("samples_per_second")),
                fmt(row.get("estimated_epoch_time_minutes")),
                fmt(row.get("scaling_efficiency_percent")),
                fmt(row.get("rank_imbalance_percent")),
                fmt(row.get("step_mean_seconds_max_rank"), 4),
                fmt(row.get("train_mean_seconds_max_rank"), 4),
                fmt(row.get("data_wait_mean_seconds_max_rank"), 4),
                fmt(row.get("h2d_mean_seconds_max_rank"), 4),
                fmt(row.get("input_prepare_mean_seconds_max_rank"), 4),
                esc(notes),
            ]) + " |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def print_ascii(df, aggregate_df, date_value, cluster):
    print(f"DDP ResNet-50 {cluster} {date_value}")
    if df.empty:
        print("No rows")
        return
    print(f"Rows: {len(df)}")
    if aggregate_df.empty:
        best = df[df["samples_per_second"].notna()].sort_values("samples_per_second", ascending=False).head(5)
        for _, row in best.iterrows():
            print(
                f"- {input_label(row)} {row.get('node_count')}n/{row.get('world_size')}g "
                f"{fmt(row.get('samples_per_second'))} img/s"
            )
        return
    best = aggregate_df[aggregate_df["samples_per_second_olympic"].notna()].sort_values(
        "samples_per_second_olympic",
        ascending=False,
    ).head(5)
    for _, row in best.iterrows():
        print(
            f"- {row.get('input_label')} {row.get('node_count')}n/{row.get('world_size')}g "
            f"{fmt(row.get('samples_per_second_olympic'))} olympic img/s "
            f"({row.get('sample_count')} samples)"
        )


def main():
    args = build_parser().parse_args()
    date_value = resolve_date(args.date)
    date_values = resolve_dates(args.date, args.extra_date)
    results_root = Path(args.results_root)
    output_dir = Path(args.output_dir) if args.output_dir else results_root / "reports" / date_value / "ddp"
    output_dir.mkdir(parents=True, exist_ok=True)

    rows = []
    for source_date in date_values:
        rows.extend(load_rows(results_root, source_date, args.cluster))
    all_df = pd.DataFrame(rows)
    if not all_df.empty and not args.include_smoke:
        df = all_df[all_df["smoke"] != True].copy()  # noqa: E712
    else:
        df = all_df.copy()
    df = add_derived_fields(df)
    excluded_smoke_count = int(len(all_df) - len(df))

    csv_path = output_dir / f"ddp-resnet50-summary-{args.cluster}-{date_value}.csv"
    aggregate_csv_path = output_dir / f"ddp-resnet50-repeat-aggregation-{args.cluster}-{date_value}.csv"
    md_path = output_dir / f"ddp-resnet50-{args.cluster}-{date_value}.md"
    meta_path = output_dir / f"ddp-resnet50-report-{args.cluster}-{date_value}.json"
    throughput_path = output_dir / f"ddp-resnet50-throughput-{args.cluster}-{date_value}.png"
    scaling_path = output_dir / f"ddp-resnet50-scaling-{args.cluster}-{date_value}.png"

    df.to_csv(csv_path, index=False)
    aggregate_df = aggregate_repeat_rows(df)
    aggregate_df.to_csv(aggregate_csv_path, index=False)
    throughput_written = write_throughput_plot(df, throughput_path)
    scaling_written = write_scaling_plot(df, scaling_path)
    write_markdown(
        df,
        aggregate_df,
        md_path,
        csv_path,
        aggregate_csv_path,
        meta_path,
        throughput_path,
        throughput_written,
        scaling_path,
        scaling_written,
        excluded_smoke_count,
    )
    metadata = {
        "schema_version": 1,
        "date": date_value,
        "source_dates": date_values,
        "cluster": args.cluster,
        "include_smoke": args.include_smoke,
        "raw_row_count": int(len(all_df)),
        "row_count": int(len(df)),
        "aggregate_row_count": int(len(aggregate_df)),
        "excluded_smoke_count": excluded_smoke_count,
        "outputs": {
            "csv": str(csv_path),
            "repeat_aggregation_csv": str(aggregate_csv_path),
            "markdown": str(md_path),
            "throughput_plot": str(throughput_path) if throughput_written else None,
            "scaling_plot": str(scaling_path) if scaling_written else None,
        },
    }
    meta_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {csv_path}")
    print(f"Wrote {aggregate_csv_path}")
    print(f"Wrote {md_path}")
    print(f"Wrote {meta_path}")
    if throughput_written:
        print(f"Wrote {throughput_path}")
    if scaling_written:
        print(f"Wrote {scaling_path}")
    if args.ascii:
        print_ascii(df, aggregate_df, date_value, args.cluster)
    return 0


if __name__ == "__main__":
    sys.exit(main())
