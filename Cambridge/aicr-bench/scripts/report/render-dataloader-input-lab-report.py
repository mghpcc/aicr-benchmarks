#!/usr/bin/env python3
"""Render experimental DataLoader input-pipeline lab summaries."""

import argparse
import importlib.util
import json
from pathlib import Path
from statistics import mean

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd


DEFAULT_BASELINES = {
    "b200": 45954.0,
    "rtxpro6000": 48974.0,
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

AGGREGATION_KEY_COLUMNS = [
    "input_backend",
    "study_class",
    "representation_class",
    "transport_class",
    "canonical_imagenet",
    "derived_jpeg",
    "prepared_input_ceiling",
    "input_delivery_endpoint",
    "derived_image_size",
    "derived_format",
    "derived_source_policy",
    "derived_jpeg_quality",
    "batch_size",
    "num_workers",
    "prefetch_factor",
    "dali_num_threads",
    "dali_prefetch_queue_depth",
    "dali_decode_mode",
    "dali_hw_decoder_load",
    "dali_reader_device",
    "dali_numpy_use_o_direct",
    "dali_numpy_reader_prefetch_queue_depth",
    "dali_gds_chunk_size",
    "numpy_block_size",
    "numpy_block_cache_size",
    "dataset_variant",
    "node_count",
    "requested_gpu_count",
]


def load_dataloader_report_module():
    module_path = Path(__file__).with_name("render-dataloader-report.py")
    spec = importlib.util.spec_from_file_location("render_dataloader_report", module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build_parser():
    parser = argparse.ArgumentParser(
        description="Render DataLoader input-pipeline lab tables and plots."
    )
    parser.add_argument("--date", required=True, help="UTC date to render, or today/yesterday")
    parser.add_argument("--cluster", default="b200")
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--output-dir", default=None)
    parser.add_argument(
        "--baseline-samples-per-second",
        type=float,
        default=None,
        help="PyTorch CPU DataLoader baseline for speedup calculations. Defaults to the current one-node teaching baseline for the cluster.",
    )
    parser.add_argument(
        "--include-smoke",
        action="store_true",
        help="Include smoke rows with fewer than 100 measured batches.",
    )
    parser.add_argument(
        "--input-backends",
        default="pytorch-cpu-dataloader,dali-gpu-decode,numpy-uint8-shards,numpy-fp16-shards,numpy-fp16-blocks-pytorch,dali-numpy-fp16-cpu,dali-numpy-fp16-gds,dali-numpy-fp16-blocks-cpu,dali-numpy-fp16-blocks-gds",
        help="Comma-separated backend filter.",
    )
    return parser


def parse_csv(value):
    return [item.strip() for item in value.split(",") if item.strip()]


def fmt(value, digits=1):
    if value is None or pd.isna(value):
        return "-"
    return f"{float(value):.{digits}f}"


def fmt_int(value):
    if value is None or pd.isna(value):
        return "-"
    return f"{int(float(value)):,}"


def fmt_count(value):
    if value is None or pd.isna(value):
        return "0"
    return str(int(float(value)))


def fmt_speedup(value):
    if value is None or pd.isna(value):
        return "-"
    return f"{float(value):.2f}x"


def bool_text(value):
    if value is None or pd.isna(value):
        return "-"
    return "yes" if bool(value) else "no"


def backend_display(value):
    return {
        "pytorch-cpu-dataloader": "PyTorch CPU",
        "dali-gpu-decode": "DALI",
        "numpy-uint8-shards": "NumPy uint8",
        "numpy-fp16-shards": "NumPy fp16",
        "numpy-fp16-blocks-pytorch": "PyTorch NumPy blocks",
        "dali-numpy-fp16-cpu": "DALI NumPy CPU",
        "dali-numpy-fp16-gds": "DALI NumPy GPU/O_DIRECT",
        "dali-numpy-fp16-blocks-cpu": "DALI NumPy blocks CPU",
        "dali-numpy-fp16-blocks-gds": "DALI NumPy blocks GDS",
    }.get(value, value or "-")


def backend_config_label(row):
    backend = row.get("input_backend") or "-"
    backend_label = {
        "pytorch-cpu-dataloader": "torch-cpu",
        "dali-gpu-decode": "dali",
        "numpy-uint8-shards": "np-uint8",
        "numpy-fp16-shards": "np-fp16",
        "numpy-fp16-blocks-pytorch": "np-block-torch",
        "dali-numpy-fp16-cpu": "dali-np-cpu",
        "dali-numpy-fp16-gds": "dali-np-gds",
        "dali-numpy-fp16-blocks-cpu": "dali-block-cpu",
        "dali-numpy-fp16-blocks-gds": "dali-block-gds",
    }.get(backend, backend)
    parts = [backend_label]
    image_size = row.get("derived_image_size")
    if image_size is not None and not pd.isna(image_size):
        parts.append(f"size={int(float(image_size))}")
    batch_size = row.get("batch_size")
    if batch_size is not None and not pd.isna(batch_size):
        parts.append(f"bs={int(float(batch_size))}")
    if backend == "dali-gpu-decode" or backend in {
        "dali-numpy-fp16-cpu",
        "dali-numpy-fp16-gds",
        "dali-numpy-fp16-blocks-cpu",
        "dali-numpy-fp16-blocks-gds",
    }:
        dali_threads = row.get("dali_num_threads")
        queue_depth = row.get("dali_prefetch_queue_depth")
        decode_mode = row.get("dali_decode_mode")
        if dali_threads is not None and not pd.isna(dali_threads):
            parts.append(f"thr={int(float(dali_threads))}")
        if queue_depth is not None and not pd.isna(queue_depth):
            parts.append(f"q={int(float(queue_depth))}")
        if backend in {
            "dali-numpy-fp16-cpu",
            "dali-numpy-fp16-gds",
            "dali-numpy-fp16-blocks-cpu",
            "dali-numpy-fp16-blocks-gds",
        }:
            reader_device = row.get("dali_reader_device")
            reader_prefetch = row.get("dali_numpy_reader_prefetch_queue_depth")
            if reader_device is not None and not pd.isna(reader_device):
                parts.append(f"reader={reader_device}")
            if reader_prefetch is not None and not pd.isna(reader_prefetch):
                parts.append(f"rq={int(float(reader_prefetch))}")
        elif decode_mode == "random-crop":
            parts.append("rcrop")
        elif decode_mode:
            parts.append(str(decode_mode))
    else:
        num_workers = row.get("num_workers")
        prefetch = row.get("prefetch_factor")
        if num_workers is not None and not pd.isna(num_workers):
            parts.append(f"nw={int(float(num_workers))}")
        if prefetch is not None and not pd.isna(prefetch):
            parts.append(f"pf={int(float(prefetch))}")
        if backend == "numpy-fp16-blocks-pytorch":
            cache_size = row.get("numpy_block_cache_size")
            if cache_size is not None and not pd.isna(cache_size):
                parts.append(f"cache={int(float(cache_size))}")
    return " ".join(parts)


def cpu_profile_label(row):
    workers = row.get("num_workers")
    prefetch = row.get("prefetch_factor")
    if workers is None or pd.isna(workers):
        return "n/a"
    workers = int(float(workers))
    prefetch = None if prefetch is None or pd.isna(prefetch) else int(float(prefetch))
    if workers == 16 and prefetch == 4:
        return "training-tuned"
    return f"workers={workers},prefetch={prefetch if prefetch is not None else '-'}"


def dataset_variant_key(row):
    image_size = row.get("derived_image_size")
    derived_format = row.get("derived_format")
    if image_size is None or pd.isna(image_size):
        return "original-jpeg"
    fmt_value = derived_format if derived_format is not None and not pd.isna(derived_format) else "derived"
    return f"{fmt_value}:size-{int(float(image_size))}"


def storage_family(row):
    image_size = row.get("derived_image_size")
    if image_size is None or pd.isna(image_size):
        return "original-jpeg"
    backend = row.get("input_backend")
    derived_format = row.get("derived_format")
    if backend in {"dali-numpy-fp16-cpu", "dali-numpy-fp16-gds"}:
        return "dali-numpy-file"
    if backend in {"dali-numpy-fp16-blocks-cpu", "dali-numpy-fp16-blocks-gds"}:
        return "dali-numpy-block"
    if backend in ("numpy-uint8-shards", "numpy-fp16-shards"):
        return "numpy-shard"
    if backend == "numpy-fp16-blocks-pytorch":
        return "pytorch-numpy-block"
    if derived_format == "jpeg":
        return "pre-resized-jpeg"
    if derived_format in {"synthetic-jpeg", "procedural-jpeg"}:
        return "synthetic-large-jpeg"
    return "derived-input"


def add_same_size_speedups(df):
    df = df.copy()
    df["speedup_vs_same_size_pytorch_jpeg"] = None
    if df.empty or "derived_image_size" not in df.columns:
        return df
    py_jpeg = df[
        (df["input_backend"] == "pytorch-cpu-dataloader")
        & (df["derived_image_size"].notna())
        & (df["derived_format"].isin(["jpeg", "synthetic-jpeg", "procedural-jpeg"]))
        & (df["samples_per_second"].notna())
    ].copy()
    if py_jpeg.empty:
        return df
    baselines = (
        py_jpeg.groupby(["derived_format", "derived_image_size"])["samples_per_second"]
        .max()
        .to_dict()
    )

    def speedup(row):
        image_size = row.get("derived_image_size")
        derived_format = row.get("derived_format")
        sample_rate = row.get("samples_per_second")
        key = (derived_format, image_size)
        if (
            key in baselines
            and sample_rate is not None
            and not pd.isna(sample_rate)
            and baselines[key]
        ):
            return sample_rate / baselines[key]
        return None

    df["speedup_vs_same_size_pytorch_jpeg"] = df.apply(speedup, axis=1)
    return df


def add_derived_columns(df, baseline):
    df = df.copy()
    df["samples_per_second_per_gpu"] = df.apply(
        lambda row: row["samples_per_second"] / row["requested_gpu_count"]
        if row.get("samples_per_second") is not None
        and not pd.isna(row.get("samples_per_second"))
        and row.get("requested_gpu_count")
        else None,
        axis=1,
    )
    df["speedup_vs_original_pytorch_cpu"] = (
        df["samples_per_second"] / baseline if baseline and "samples_per_second" in df.columns else None
    )
    df["speedup_vs_baseline"] = df["speedup_vs_original_pytorch_cpu"]
    df["cpu_profile"] = df.apply(cpu_profile_label, axis=1)
    df["dataset_variant"] = df.apply(dataset_variant_key, axis=1)
    df["storage_family"] = df.apply(storage_family, axis=1)
    df["backend_config"] = df.apply(backend_config_label, axis=1)
    df["repeat_count"] = 1
    df["aggregation_kind"] = "single"
    return add_same_size_speedups(df)


def aggregate_repeat_rows(df):
    if df.empty:
        return df.copy()
    work_df = df.copy()
    for column in AGGREGATION_KEY_COLUMNS:
        if column not in work_df.columns:
            work_df[column] = None
    rows = []
    for _, group in work_df.groupby(AGGREGATION_KEY_COLUMNS, dropna=False):
        group = group.sort_values(["job_id", "run_id"], na_position="last")
        base = group.iloc[0].to_dict()
        sample_rows = [
            float(row["samples_per_second"])
            for _, row in group.iterrows()
            if row.get("samples_per_second") is not None and not pd.isna(row.get("samples_per_second"))
        ]
        if not sample_rows:
            continue
        source_row_count = len(sample_rows)
        selected_samples = sample_rows[-5:] if source_row_count >= 5 else sample_rows
        sorted_samples = sorted(selected_samples)
        repeat_count = len(selected_samples)
        if repeat_count == 5:
            aggregate_samples = mean(sorted_samples[1:-1])
            aggregation_kind = "olympic"
        elif repeat_count > 1:
            aggregate_samples = mean(sorted_samples)
            aggregation_kind = "partial"
        else:
            aggregate_samples = sorted_samples[0]
            aggregation_kind = "single"
        base["samples_per_second"] = aggregate_samples
        base["samples_per_second_min"] = min(sorted_samples)
        base["samples_per_second_max"] = max(sorted_samples)
        base["samples_per_second_mean"] = mean(sorted_samples)
        base["repeat_count"] = repeat_count
        base["source_row_count"] = source_row_count
        base["aggregation_kind"] = aggregation_kind
        if "rank_imbalance_percent" in group.columns:
            imbalance = group["rank_imbalance_percent"].dropna()
            base["rank_imbalance_percent"] = imbalance.mean() if not imbalance.empty else None
        for column in ["nofile_soft", "nofile_hard", "open_file_descriptor_count"]:
            if column in group.columns:
                values = group[column].dropna()
                if not values.empty:
                    base[f"{column}_min"] = values.min()
                    base[f"{column}_max"] = values.max()
                    if column == "open_file_descriptor_count":
                        base[column] = values.max()
                    else:
                        base[column] = values.min()
        if "nofile_requested" in group.columns:
            values = group["nofile_requested"].dropna()
            if not values.empty:
                base["nofile_requested"] = values.iloc[0]
        requested_gpus = base.get("requested_gpu_count")
        if requested_gpus and not pd.isna(requested_gpus):
            base["samples_per_second_per_gpu"] = aggregate_samples / requested_gpus
        rows.append(base)
    aggregate_df = pd.DataFrame(rows)
    if aggregate_df.empty:
        return aggregate_df
    baseline_values = df["samples_per_second"] / df["speedup_vs_original_pytorch_cpu"]
    baseline_values = baseline_values.dropna()
    baseline = float(baseline_values.iloc[0]) if not baseline_values.empty else None
    if baseline:
        aggregate_df["speedup_vs_original_pytorch_cpu"] = aggregate_df["samples_per_second"] / baseline
        aggregate_df["speedup_vs_baseline"] = aggregate_df["speedup_vs_original_pytorch_cpu"]
    aggregate_df = add_same_size_speedups(aggregate_df)
    aggregate_df["backend_config"] = aggregate_df.apply(backend_config_label, axis=1)
    return aggregate_df


def write_top_plot(df, output_path):
    if df.empty:
        return False
    plot_df = df.sort_values("samples_per_second", ascending=False).head(30).copy()
    if plot_df.empty:
        return False
    plot_df = plot_df.sort_values("samples_per_second", ascending=True)
    bar_colors = [BACKEND_COLORS.get(value, "#9d9d9d") for value in plot_df["input_backend"]]
    fig_height = max(6, 0.45 * len(plot_df) + 2.0)
    fig, ax = plt.subplots(figsize=(16, fig_height))
    ax.barh(plot_df["backend_config"], plot_df["samples_per_second"], color=bar_colors)
    ax.set_xlabel("samples/s")
    ax.set_title("DataLoader input-pipeline lab throughput")
    ax.grid(axis="x", alpha=0.25)
    max_value = plot_df["samples_per_second"].max()
    for index, value in enumerate(plot_df["samples_per_second"]):
        ax.text(value + max_value * 0.01, index, f"{value:,.0f}", va="center", fontsize=8)
    ax.set_xlim(0, max_value * 1.16)
    fig.subplots_adjust(left=0.28, right=0.96, top=0.94, bottom=0.08)
    fig.savefig(output_path, dpi=150)
    plt.close(fig)
    return True


def write_image_size_plot(df, output_path):
    if df.empty or "derived_image_size" not in df.columns:
        return False
    plot_df = df[df["derived_image_size"].notna()].copy()
    if plot_df.empty:
        return False
    grouped = (
        plot_df.groupby(["input_backend", "derived_image_size"], dropna=False)["samples_per_second"]
        .max()
        .reset_index()
        .sort_values(["input_backend", "derived_image_size"])
    )
    if grouped.empty:
        return False
    fig, ax = plt.subplots(figsize=(10, 6), constrained_layout=True)
    for backend, backend_df in grouped.groupby("input_backend"):
        ax.plot(
            backend_df["derived_image_size"],
            backend_df["samples_per_second"],
            marker="o",
            linewidth=2,
            label=backend_display(backend),
            color=BACKEND_COLORS.get(backend),
        )
    ax.set_xlabel("derived image size")
    ax.set_ylabel("best samples/s")
    ax.set_title("Best input throughput by image size")
    ax.grid(alpha=0.25)
    ax.legend(loc="best")
    fig.savefig(output_path, dpi=150)
    plt.close(fig)
    return True


def write_speedup_plot(df, output_path, *, metric, title, ylabel):
    if df.empty or "derived_image_size" not in df.columns or metric not in df.columns:
        return False
    plot_df = df[df["derived_image_size"].notna() & df[metric].notna()].copy()
    if plot_df.empty:
        return False
    grouped = (
        plot_df.groupby(["input_backend", "derived_image_size"], dropna=False)[metric]
        .max()
        .reset_index()
        .sort_values(["input_backend", "derived_image_size"])
    )
    if grouped.empty:
        return False
    fig, ax = plt.subplots(figsize=(10, 6), constrained_layout=True)
    for backend, backend_df in grouped.groupby("input_backend"):
        ax.plot(
            backend_df["derived_image_size"],
            backend_df[metric],
            marker="o",
            linewidth=2,
            label=backend_display(backend),
            color=BACKEND_COLORS.get(backend),
        )
    ax.axhline(1.0, color="#666666", linestyle="--", linewidth=1)
    ax.set_xlabel("derived image size")
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.grid(alpha=0.25)
    ax.legend(loc="best")
    fig.savefig(output_path, dpi=150)
    plt.close(fig)
    return True


def markdown_escape(value):
    if value is None or pd.isna(value):
        return "-"
    return str(value).replace("|", "\\|")


def append_table(lines, headers, rows):
    lines.append("| " + " | ".join(headers) + " |")
    lines.append(
        "| "
        + " | ".join("---:" if header.endswith(":") else "---" for header in headers)
        + " |"
    )
    if not rows:
        lines.append("| " + " | ".join("-" for _ in headers) + " |")
        return
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")


def compact_row(row):
    return [
        markdown_escape(backend_display(row.get("input_backend"))),
        markdown_escape(row.get("dataset_variant")),
        markdown_escape(row.get("backend_config")),
        fmt_count(row.get("repeat_count")),
        markdown_escape(row.get("aggregation_kind")),
        fmt_int(row.get("samples_per_second")),
        fmt_int(row.get("samples_per_second_min")),
        fmt_int(row.get("samples_per_second_max")),
        fmt_speedup(row.get("speedup_vs_original_pytorch_cpu")),
        fmt_speedup(row.get("speedup_vs_same_size_pytorch_jpeg")),
        fmt(row.get("rank_imbalance_percent"), 1),
    ]


def prepared_compact_row(row):
    return [
        markdown_escape(backend_display(row.get("input_backend"))),
        markdown_escape(row.get("dataset_variant")),
        markdown_escape(row.get("backend_config")),
        fmt_count(row.get("source_row_count", row.get("repeat_count"))),
        markdown_escape(row.get("aggregation_kind")),
        fmt_int(row.get("samples_per_second")),
        fmt_int(row.get("samples_per_second_min")),
        fmt_int(row.get("samples_per_second_max")),
        fmt_speedup(row.get("speedup_vs_original_pytorch_cpu")),
        fmt(row.get("rank_imbalance_percent"), 1),
        fmt_int(row.get("nofile_requested")),
        fmt_int(row.get("nofile_soft")),
        fmt_int(row.get("nofile_hard")),
        fmt_int(row.get("open_file_descriptor_count_max", row.get("open_file_descriptor_count"))),
    ]


def ddp_candidate_role(row):
    backend = row.get("input_backend")
    image_size = row.get("derived_image_size")
    if backend == "dali-gpu-decode":
        return "candidate input path"
    if backend == "numpy-fp16-shards" and image_size is not None and not pd.isna(image_size):
        if int(float(image_size)) == 224:
            return "prepared-input ceiling"
    if backend == "pytorch-cpu-dataloader":
        return "same-size baseline"
    return "diagnostic"


def ddp_candidate_rows(aggregate_df):
    if aggregate_df.empty:
        return aggregate_df
    olympic_df = aggregate_df[
        (aggregate_df["aggregation_kind"] == "olympic")
        & (aggregate_df["speedup_vs_original_pytorch_cpu"].fillna(0).astype(float) >= 1.10)
    ].copy()
    if olympic_df.empty:
        return olympic_df
    keep = (
        (olympic_df["input_backend"] == "dali-gpu-decode")
        | (
            (olympic_df["input_backend"] == "numpy-fp16-shards")
            & (olympic_df["derived_image_size"].fillna(0).astype(float) == 224)
        )
    )
    return olympic_df[keep].sort_values(["derived_image_size", "input_backend"])


def ddp_baseline_rows(aggregate_df):
    if aggregate_df.empty:
        return aggregate_df
    baseline_df = aggregate_df[
        (aggregate_df["aggregation_kind"] == "olympic")
        & (aggregate_df["input_backend"] == "pytorch-cpu-dataloader")
        & (aggregate_df["derived_image_size"].fillna(0).astype(float) <= 512)
    ].copy()
    return baseline_df.sort_values(["derived_image_size", "input_backend"])


def best_by_family_size(df):
    if df.empty:
        return df
    return (
        df.sort_values("samples_per_second", ascending=False)
        .groupby(["storage_family", "input_backend", "derived_image_size"], dropna=False)
        .head(1)
        .sort_values(["derived_image_size", "storage_family", "input_backend"], na_position="first")
    )


def gds_interpretation_lines(aggregate_df):
    if aggregate_df.empty or "input_backend" not in aggregate_df.columns:
        return [
            "No DALI NumPy CPU-reader versus GPU/O_DIRECT aggregate rows are "
            "present in this render. These rows, when present, are diagnostic "
            "prepared-tensor transport evidence only; they are not ImageNet training "
            "throughput, not DDP results, not JPEG decode evidence, and not a general "
            "GDS recommendation."
        ]
    rows = aggregate_df[
        aggregate_df["input_backend"].isin([
            "dali-numpy-fp16-cpu",
            "dali-numpy-fp16-gds",
            "dali-numpy-fp16-blocks-cpu",
            "dali-numpy-fp16-blocks-gds",
        ])
    ].copy()
    if rows.empty:
        return [
            "No DALI NumPy CPU-reader versus GPU/O_DIRECT aggregate rows are "
            "present in this render. These rows, when present, are diagnostic "
            "prepared-tensor transport evidence only; they are not ImageNet training "
            "throughput, not DDP results, not JPEG decode evidence, and not a general "
            "GDS recommendation."
        ]
    lines = [
        "These DALI NumPy rows are diagnostic prepared-tensor transport evidence only. "
        "They are not ImageNet training throughput, not DDP results, not JPEG decode "
        "evidence, and not a general GDS recommendation."
    ]
    backend_pairs = [
        ("dali-numpy-fp16-cpu", "dali-numpy-fp16-gds"),
        ("dali-numpy-fp16-blocks-cpu", "dali-numpy-fp16-blocks-gds"),
    ]
    for cpu_backend, gds_backend in backend_pairs:
        cpu_rows = rows[rows["input_backend"] == cpu_backend]
        gds_rows = rows[rows["input_backend"] == gds_backend]
        for _, gds_row in gds_rows.sort_values(["derived_image_size", "requested_gpu_count"]).iterrows():
            candidates = cpu_rows[
                (cpu_rows["derived_image_size"] == gds_row.get("derived_image_size"))
                & (cpu_rows["requested_gpu_count"] == gds_row.get("requested_gpu_count"))
                & (cpu_rows["batch_size"] == gds_row.get("batch_size"))
            ]
            if candidates.empty:
                continue
            cpu_row = candidates.sort_values("samples_per_second", ascending=False).iloc[0]
            cpu_sps = cpu_row.get("samples_per_second")
            gds_sps = gds_row.get("samples_per_second")
            if cpu_sps and gds_sps and not pd.isna(cpu_sps) and not pd.isna(gds_sps):
                ratio = float(gds_sps) / float(cpu_sps)
                lines.append(
                    f"For `{markdown_escape(gds_row.get('dataset_variant'))}` at "
                    f"`{fmt_count(gds_row.get('requested_gpu_count'))}` GPU(s), the "
                    f"DALI NumPy GPU/cuFile reader reached `{fmt_int(gds_sps)}` "
                    f"samples/s versus `{fmt_int(cpu_sps)}` samples/s for the DALI "
                    f"CPU reader (`{ratio:.2f}x`)."
                )
    lines.append(
        "Do not generalize a negative or positive delta from this small prepared-tensor "
        "probe to ordinary JPEG training. V2 needs larger sample counts, larger tensor "
        "sizes, chunk-size sweeps, repeated Olympic rows, and same-node GDS/cuFile "
        "provenance before making a storage-performance claim."
    )
    return lines


def write_markdown(df, aggregate_df, output_path, *, date_value, cluster, baseline, artifacts):
    partial_count = int((aggregate_df["aggregation_kind"] == "partial").sum()) if not aggregate_df.empty else 0
    olympic_count = int((aggregate_df["aggregation_kind"] == "olympic").sum()) if not aggregate_df.empty else 0
    large_count = (
        int((aggregate_df["derived_image_size"].fillna(0).astype(float) >= 768).sum())
        if not aggregate_df.empty and "derived_image_size" in aggregate_df.columns
        else 0
    )
    lines = [
        f"# DataLoader Input Pipeline Lab {cluster} {date_value}",
        "",
        "Experimental input-pipeline comparison for user workload design. These rows are not formal benchmark certification.",
        "",
        "**Diagnostic scope:** DALI NumPy GPU/cuFile rows are prepared-tensor transport evidence only. They are not ImageNet training throughput, not a DDP result, and not a general GDS recommendation.",
        "",
        "## Executive Summary",
        "",
        "The default rule on this system is not \"use DALI\"; it is \"use the simplest pipeline that feeds the GPUs fast enough.\" Tuned PyTorch CPU DataLoader remains the reference for original ImageNet JPEGs. In the current lab evidence, DALI becomes useful once JPEG inputs are pre-resized or large enough that decode and resize work are more regular, while predecoded fp16 shards show a prepared-input ceiling rather than normal augmentation semantics. Speedup versus the original PyTorch CPU row mixes representation and backend changes; same-size speedup is the cleaner DALI-versus-PyTorch comparison on a matched derived JPEG tree. Prepared fp16 transport rows report a representation-plus-backend ratio, not a same-semantics ImageNet speedup.",
        "",
        f"This render includes `{len(df)}` passed rows, `{len(aggregate_df)}` aggregate configurations, `{olympic_count}` Olympic aggregates, `{partial_count}` partial aggregates, and `{large_count}` large-image exploratory aggregate rows.",
        "",
        "## Rules Of Thumb",
        "",
    ]
    append_table(
        lines,
        ["Workload shape", "Recommended input path", "Why", "Caveat"],
        [
            [
                "Original variable-size ImageNet JPEGs",
                "Tuned PyTorch CPU DataLoader",
                "CPU workers are provisioned and online DALI did not win in the current evidence.",
                "Keep `num_workers=16`, `prefetch_factor=4` as the baseline on this system.",
            ],
            [
                "Pre-resized JPEGs, 224-512",
                "DALI GPU/mixed decode candidate",
                "Decode and resize work is more regular and easier to pipeline.",
                "Validate semantics before treating it as a training replacement.",
            ],
            [
                "Large JPEGs, 768+",
                "DALI exploratory candidate",
                "Larger images shift more work into decode/preprocess and can favor DALI.",
                "One-sample rows are exploratory until repeated.",
            ],
            [
                "Synthetic large JPEGs",
                "Decode crossover stress test",
                "Both PyTorch and DALI must decode and normalize runtime JPEG input.",
                "Keep separate from pre-resized JPEG and NumPy shard evidence.",
            ],
            [
                "Predecoded fp16 224 tensors",
                "Prepared-input ceiling",
                "JPEG decode and normalization are removed from the hot path.",
                "Preprocessing choices are baked in; no GPUDirect Storage claim.",
            ],
            [
                "Per-sample fp16 tensors on a GDS-capable path",
                "DALI NumPy CPU-reader versus GPU/cuFile-reader comparison",
                "The same prepared tensor layout can exercise CPU-reader versus DALI NumPy GPU/cuFile transport.",
                "This is prepared-tensor transport evidence, not JPEG decode evidence.",
            ],
            [
                "Large NumPy shards",
                "Use as cautionary evidence",
                "Decode is removed, but tensor payloads can become storage-bandwidth limited.",
                "Not a normal ImageNet training recipe.",
            ],
        ],
    )
    lines.extend(
        [
            "",
            "## Evidence Dashboard",
            "",
            f"- PyTorch CPU DataLoader reference for speedup: `{baseline:,.0f}` samples/s",
            "- Olympic aggregation drops the min and max of five repeats and averages the middle three.",
            "- Partial aggregates are rows whose repeat set is still draining or incomplete.",
            "- Pending or failed Slurm jobs are not included in this passed-row report; rerender after the queue drains for the final view.",
            "- Large-image rows remain exploratory until they are repeated.",
            "- DataLoader lab rows use replicated input readers; DDP uses distributed sharding, so DDP is the required training validation before calling a row a training-throughput win.",
            "- No GPUDirect Storage claim is made here; storage-to-GPU host-memory bypass requires separate GDS/cuFile evidence.",
            "- For prepared fp16 rows, ratios against the original PyTorch CPU row mix representation and backend changes; read them as representation-plus-backend ratios, not same-input speedups.",
            "",
            "### Top Rows",
            "",
        ]
    )
    append_table(
        lines,
        [
            "Backend",
            "Dataset",
            "Config",
            "Samples/s:",
            "Samples/s/GPU:",
            "Speedup vs original:",
            "Same-size speedup:",
            "Imbalance %:",
            "GPU-resident",
            "Evidence",
        ],
        [
            [
                markdown_escape(backend_display(row.get("input_backend"))),
                markdown_escape(row.get("dataset_variant")),
                markdown_escape(row.get("backend_config")),
                fmt_int(row.get("samples_per_second")),
                fmt(row.get("samples_per_second_per_gpu"), 1),
                fmt_speedup(row.get("speedup_vs_original_pytorch_cpu")),
                fmt_speedup(row.get("speedup_vs_same_size_pytorch_jpeg")),
                fmt(row.get("rank_imbalance_percent"), 1),
                bool_text(row.get("input_gpu_resident")),
                markdown_escape(row.get("evidence_path") or row.get("summary_path") or "-"),
            ]
            for _, row in df.sort_values("samples_per_second", ascending=False).head(20).iterrows()
        ],
    )

    repeat_df = aggregate_df[
        (aggregate_df["repeat_count"] > 1)
        & (aggregate_df["derived_image_size"].fillna(0).astype(float) <= 512)
    ].copy()
    lines.extend(["", "### Olympic Repeat Rows", ""])
    append_table(
        lines,
        [
            "Backend",
            "Dataset",
            "Config",
            "Repeats:",
            "Aggregation",
            "Samples/s:",
            "Min:",
            "Max:",
            "Speedup vs original:",
            "Same-size speedup:",
            "Imbalance %:",
        ],
        [compact_row(row) for _, row in repeat_df.sort_values(["derived_image_size", "input_backend"]).iterrows()],
    )

    candidate_df = ddp_candidate_rows(aggregate_df)
    baseline_df = ddp_baseline_rows(aggregate_df)
    lines.extend(["", "### DDP Candidate Shortlist", ""])
    lines.extend(
        [
            "These are not DDP results. They are DataLoader-only rows that met the 10% Olympic repeat-screen criterion and are worth carrying into a one-node DDP integration check. The DDP comparison must use the same-size PyTorch CPU DDP row as the baseline, not this lab baseline.",
            "",
        ]
    )
    append_table(
        lines,
        [
            "Role",
            "Backend",
            "Dataset",
            "Config",
            "Samples/s:",
            "Speedup vs original:",
            "Same-size speedup:",
            "Reason",
        ],
        [
            [
                markdown_escape(ddp_candidate_role(row)),
                markdown_escape(backend_display(row.get("input_backend"))),
                markdown_escape(row.get("dataset_variant")),
                markdown_escape(row.get("backend_config")),
                fmt_int(row.get("samples_per_second")),
                fmt_speedup(row.get("speedup_vs_original_pytorch_cpu")),
                fmt_speedup(row.get("speedup_vs_same_size_pytorch_jpeg")),
                "DALI candidate" if row.get("input_backend") == "dali-gpu-decode" else "prepared ceiling",
            ]
            for _, row in candidate_df.iterrows()
        ],
    )
    lines.extend(["", "Same-size PyTorch rows to carry as DDP baselines:", ""])
    append_table(
        lines,
        [
            "Role",
            "Backend",
            "Dataset",
            "Config",
            "Samples/s:",
            "Speedup vs original:",
            "Same-size speedup:",
            "Reason",
        ],
        [
            [
                markdown_escape(ddp_candidate_role(row)),
                markdown_escape(backend_display(row.get("input_backend"))),
                markdown_escape(row.get("dataset_variant")),
                markdown_escape(row.get("backend_config")),
                fmt_int(row.get("samples_per_second")),
                fmt_speedup(row.get("speedup_vs_original_pytorch_cpu")),
                fmt_speedup(row.get("speedup_vs_same_size_pytorch_jpeg")),
                "baseline for same-size comparison",
            ]
            for _, row in baseline_df.iterrows()
        ],
    )

    large_df = aggregate_df[aggregate_df["derived_image_size"].fillna(0).astype(float) >= 768].copy()
    lines.extend(["", "### Exploratory Large-Image Rows", ""])
    append_table(
        lines,
        [
            "Backend",
            "Dataset",
            "Config",
            "Repeats:",
            "Aggregation",
            "Samples/s:",
            "Min:",
            "Max:",
            "Speedup vs original:",
            "Same-size speedup:",
            "Imbalance %:",
        ],
        [compact_row(row) for _, row in best_by_family_size(large_df).iterrows()],
    )

    original_df = aggregate_df[aggregate_df["storage_family"] == "original-jpeg"].copy()
    lines.extend(["", "### Original JPEG Rows", ""])
    append_table(
        lines,
        [
            "Backend",
            "Dataset",
            "Config",
            "Repeats:",
            "Aggregation",
            "Samples/s:",
            "Min:",
            "Max:",
            "Speedup vs original:",
            "Same-size speedup:",
            "Imbalance %:",
        ],
        [compact_row(row) for _, row in best_by_family_size(original_df).iterrows()],
    )

    jpeg_df = aggregate_df[aggregate_df["storage_family"] == "pre-resized-jpeg"].copy()
    lines.extend(["", "### Pre-Resized JPEG Rows", ""])
    append_table(
        lines,
        [
            "Backend",
            "Dataset",
            "Config",
            "Repeats:",
            "Aggregation",
            "Samples/s:",
            "Min:",
            "Max:",
            "Speedup vs original:",
            "Same-size speedup:",
            "Imbalance %:",
        ],
        [compact_row(row) for _, row in best_by_family_size(jpeg_df).iterrows()],
    )

    synthetic_jpeg_df = aggregate_df[aggregate_df["storage_family"] == "synthetic-large-jpeg"].copy()
    lines.extend(["", "### Synthetic Large JPEG Rows", ""])
    append_table(
        lines,
        [
            "Backend",
            "Dataset",
            "Config",
            "Repeats:",
            "Aggregation",
            "Samples/s:",
            "Min:",
            "Max:",
            "Speedup vs original:",
            "Same-size speedup:",
            "Imbalance %:",
        ],
        [compact_row(row) for _, row in best_by_family_size(synthetic_jpeg_df).iterrows()],
    )

    numpy_df = aggregate_df[aggregate_df["storage_family"] == "numpy-shard"].copy()
    lines.extend(["", "### NumPy Shard Rows", ""])
    append_table(
        lines,
        [
            "Backend",
            "Dataset",
            "Config",
            "Repeats:",
            "Aggregation",
            "Samples/s:",
            "Min:",
            "Max:",
            "Speedup vs original:",
            "Same-size speedup:",
            "Imbalance %:",
        ],
        [compact_row(row) for _, row in best_by_family_size(numpy_df).iterrows()],
    )

    dali_numpy_df = aggregate_df[
        aggregate_df["storage_family"].isin(["dali-numpy-file", "dali-numpy-block"])
    ].copy()
    lines.extend(
        [
            "",
            "### DALI NumPy GPU/cuFile Interpretation",
            "",
        ]
    )
    lines.extend(gds_interpretation_lines(aggregate_df))
    lines.extend(
        [
            "",
            "### DALI NumPy Prepared Tensor Rows",
            "",
            "These rows compare DALI NumPy CPU-reader and GPU/cuFile reader paths for prepared tensors only. The ratio column is a representation-plus-backend ratio against the original PyTorch CPU JPEG reference, not a matched-input speedup.",
            "",
        ]
    )
    append_table(
        lines,
        [
            "Backend",
            "Dataset",
            "Config",
            "Source rows:",
            "Aggregation",
            "Samples/s:",
            "Min:",
            "Max:",
            "Representation+backend ratio:",
            "Imbalance %:",
            "nofile req:",
            "nofile soft:",
            "nofile hard:",
            "open FD max:",
        ],
        [prepared_compact_row(row) for _, row in best_by_family_size(dali_numpy_df).iterrows()],
    )

    lines.extend(
        [
            "",
            "## Backend Interpretation",
            "",
            "- PyTorch CPU DataLoader is the strong default when CPU workers are provisioned and the input path is normal ImageNet JPEG.",
            "- DALI is most interesting when decode and resize work is controlled, repeated, or large enough to amortize pipeline overhead.",
            "- Synthetic large JPEG rows should be interpreted as runtime decode crossover evidence, not as prepared-input evidence.",
            "- NumPy fp16 shards are a prepared-input ceiling because decode and normalization are already done.",
            "- NumPy uint8 shards remove JPEG decode, but they can still be limited by tensor payload size and host-visible filesystem reads.",
            "- The DALI NumPy GPU/cuFile reader delta for prepared fp16 tensors is prepared-tensor transport evidence; it does not imply that DALI JPEG input uses GDS.",
            "- Synthetic or DDP rows are follow-up validation paths, not part of this DataLoader-only evidence.",
            "- The DDP shortlist should start small: DALI pre-resized JPEG rows as real input candidates, NumPy fp16 `224` as a prepared-input ceiling, and same-size PyTorch CPU rows as baselines.",
            "",
            "## DDP Validation Threshold",
            "",
            "A DataLoader-only candidate becomes a DDP validation candidate when it exceeds the tuned PyTorch CPU baseline by at least 10% after Olympic aggregation. DDP candidates should come from Olympic rows, not one-sample large-image exploratory rows.",
            "",
            "## Artifacts",
            "",
        ]
    )
    for label, path in artifacts:
        lines.append(f"- {label}: `{path}`")
    lines.append("")
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    args = build_parser().parse_args()
    report = load_dataloader_report_module()
    date_value = report.resolve_date(args.date)
    results_root = Path(args.results_root)
    output_dir = Path(args.output_dir) if args.output_dir else results_root / "reports" / date_value / "dataloader-input-lab"
    output_dir.mkdir(parents=True, exist_ok=True)
    allowed_backends = set(parse_csv(args.input_backends))
    baseline = args.baseline_samples_per_second or DEFAULT_BASELINES.get(args.cluster, 1.0)

    rows = report.load_rows(results_root, date_value, args.cluster)
    df = pd.DataFrame(rows)
    if df.empty:
        raise SystemExit(f"no DataLoader rows found for {args.cluster} {date_value}")
    if "input_backend" not in df.columns:
        df["input_backend"] = "pytorch-cpu-dataloader"
    df = df[df["input_backend"].isin(allowed_backends)].copy()
    df = df[(df["status"] == "passed") & (df["untrusted"] != True)]  # noqa: E712
    if not args.include_smoke:
        df = df[df["smoke"] != True]  # noqa: E712
    if "samples_per_second" in df.columns:
        df = df[df["samples_per_second"].notna()].copy()
    if df.empty:
        raise SystemExit("no passed non-smoke DataLoader input-lab rows matched the filters")

    df = add_derived_columns(df, baseline)
    aggregate_df = aggregate_repeat_rows(df)

    csv_path = output_dir / f"dataloader-input-lab-summary-{args.cluster}-{date_value}.csv"
    json_path = output_dir / f"dataloader-input-lab-summary-{args.cluster}-{date_value}.json"
    aggregate_csv_path = output_dir / f"dataloader-input-lab-aggregate-{args.cluster}-{date_value}.csv"
    aggregate_json_path = output_dir / f"dataloader-input-lab-aggregate-{args.cluster}-{date_value}.json"
    md_path = output_dir / f"dataloader-input-lab-{args.cluster}-{date_value}.md"
    top_png = output_dir / f"dataloader-input-lab-throughput-{args.cluster}-{date_value}.png"
    image_size_png = output_dir / f"dataloader-input-lab-image-size-{args.cluster}-{date_value}.png"
    original_speedup_png = output_dir / f"dataloader-input-lab-speedup-original-{args.cluster}-{date_value}.png"
    same_size_speedup_png = output_dir / f"dataloader-input-lab-speedup-same-size-{args.cluster}-{date_value}.png"

    df.to_csv(csv_path, index=False)
    json_path.write_text(json.dumps(df.to_dict(orient="records"), indent=2) + "\n", encoding="utf-8")
    aggregate_df.to_csv(aggregate_csv_path, index=False)
    aggregate_json_path.write_text(
        json.dumps(aggregate_df.to_dict(orient="records"), indent=2) + "\n",
        encoding="utf-8",
    )
    artifacts = [
        ("Row CSV", csv_path),
        ("Row JSON", json_path),
        ("Aggregate CSV", aggregate_csv_path),
        ("Aggregate JSON", aggregate_json_path),
    ]
    if write_top_plot(df, top_png):
        artifacts.append(("Top throughput plot", top_png))
    if write_image_size_plot(aggregate_df, image_size_png):
        artifacts.append(("Best throughput by image size plot", image_size_png))
    if write_speedup_plot(
        aggregate_df,
        original_speedup_png,
        metric="speedup_vs_original_pytorch_cpu",
        title="Speedup vs original tuned PyTorch CPU baseline",
        ylabel="speedup",
    ):
        artifacts.append(("Speedup vs original PyTorch plot", original_speedup_png))
    if write_speedup_plot(
        aggregate_df,
        same_size_speedup_png,
        metric="speedup_vs_same_size_pytorch_jpeg",
        title="Speedup vs same-size PyTorch pre-resized JPEG",
        ylabel="speedup",
    ):
        artifacts.append(("Speedup vs same-size PyTorch plot", same_size_speedup_png))
    write_markdown(
        df,
        aggregate_df,
        md_path,
        date_value=date_value,
        cluster=args.cluster,
        baseline=baseline,
        artifacts=artifacts,
    )
    print(f"Wrote {md_path}")
    print(f"Wrote {csv_path}")
    print(f"Wrote {aggregate_csv_path}")


if __name__ == "__main__":
    main()
