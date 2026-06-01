#!/usr/bin/env python3
"""Render the standard-ImageNet DALI optimization study report."""

from __future__ import annotations

import argparse
import importlib.util
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

from repeat_aggregation import aggregate_values


def load_dataloader_report_module():
    module_path = Path(__file__).with_name("render-dataloader-report.py")
    spec = importlib.util.spec_from_file_location("render_dataloader_report", module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build_parser():
    parser = argparse.ArgumentParser(
        description="Render the DataLoader DALI optimization study on standard ImageNet."
    )
    parser.add_argument("--date", required=True, help="UTC date to render, or today/yesterday")
    parser.add_argument("--cluster", default="b200")
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--include-smoke", action="store_true")
    return parser


def is_missing(value):
    return value is None or (isinstance(value, float) and math.isnan(value)) or pd.isna(value)


def as_int(value):
    return None if is_missing(value) else int(float(value))


def as_float(value):
    return None if is_missing(value) else float(value)


def fmt_int(value):
    parsed = as_int(value)
    return "-" if parsed is None else f"{parsed:,}"


def fmt_float(value, digits=1):
    parsed = as_float(value)
    return "-" if parsed is None else f"{parsed:.{digits}f}"


def fmt_sps(value):
    parsed = as_float(value)
    return "-" if parsed is None else f"{parsed:,.0f}"


def fmt_speedup(value):
    parsed = as_float(value)
    return "-" if parsed is None else f"{parsed:.3f}x"


def esc(value):
    return ("" if value is None else str(value)).replace("|", "\\|").replace("\n", " ")


def standard_imagenet_rows(df, include_smoke=False):
    if df.empty:
        return df.copy()
    rows = df.copy()
    derived_size = rows.get("derived_image_size")
    if derived_size is not None:
        rows = rows[derived_size.isna()]
    derived_root = rows.get("derived_root")
    if derived_root is not None:
        rows = rows[derived_root.isna() | (derived_root == "")]
    rows = rows[
        (rows["status"] == "passed")
        & (rows["sampler_mode"] == "replicated")
        & (rows["node_count"] == 1)
        & (rows["requested_gpu_count"] == 8)
        & (rows["input_backend"].isin(["pytorch-cpu-dataloader", "dali-gpu-decode"]))
        & (rows["warmup_batches"] == 100)
        & (rows["measured_batches"] == 500)
        & rows["samples_per_second"].notna()
    ].copy()
    if not include_smoke and "smoke" in rows.columns:
        rows = rows[rows["smoke"] != True]  # noqa: E712
    dataset_root = rows.get("dataset_root")
    if dataset_root is not None:
        rows = rows[dataset_root.fillna("").str.contains("ILSVRC/Data/CLS-LOC")]
    return rows


def config_key(row):
    backend = row.get("input_backend")
    return (
        row.get("cluster"),
        row.get("host"),
        row.get("node_list"),
        backend,
        as_int(row.get("batch_size")),
        as_int(row.get("num_workers")),
        as_int(row.get("prefetch_factor")),
        as_int(row.get("dali_num_threads")) if backend == "dali-gpu-decode" else None,
        as_int(row.get("dali_prefetch_queue_depth")) if backend == "dali-gpu-decode" else None,
        row.get("dali_decode_mode") if backend == "dali-gpu-decode" else None,
        as_float(row.get("dali_hw_decoder_load")) if backend == "dali-gpu-decode" else None,
        bool(row.get("pin_memory")) if not is_missing(row.get("pin_memory")) else None,
        bool(row.get("persistent_workers")) if not is_missing(row.get("persistent_workers")) else None,
        as_int(row.get("warmup_batches")),
        as_int(row.get("measured_batches")),
    )


def config_label(row):
    backend = row.get("input_backend")
    batch = fmt_int(row.get("batch_size"))
    if backend == "dali-gpu-decode":
        return (
            f"DALI bs={batch} "
            f"thr={fmt_int(row.get('dali_num_threads'))} "
            f"q={fmt_int(row.get('dali_prefetch_queue_depth'))}"
        )
    return (
        f"PyTorch CPU bs={batch} "
        f"nw={fmt_int(row.get('num_workers'))} "
        f"pf={fmt_int(row.get('prefetch_factor'))}"
    )


def aggregate_configs(rows):
    columns = [
        "cluster",
        "host",
        "node_list",
        "input_backend",
        "batch_size",
        "num_workers",
        "prefetch_factor",
        "dali_num_threads",
        "dali_prefetch_queue_depth",
        "dali_decode_mode",
        "dali_hw_decoder_load",
        "pin_memory",
        "persistent_workers",
        "warmup_batches",
        "measured_batches",
        "repeat_count",
        "aggregation_kind",
        "samples_per_second",
        "mean_samples_per_second",
        "min_samples_per_second",
        "max_samples_per_second",
        "stdev_samples_per_second",
        "aggregation_note",
        "job_ids",
        "run_ids",
        "summary_paths",
        "config_label",
    ]
    if rows.empty:
        return pd.DataFrame(columns=columns)
    grouped = {}
    for _, row in rows.iterrows():
        grouped.setdefault(config_key(row), []).append(row)
    out = []
    for _key, group_rows in grouped.items():
        first = group_rows[0]
        values = [as_float(row.get("samples_per_second")) for row in group_rows]
        values = [value for value in values if value is not None]
        agg = aggregate_values(values, "olympic", standard_center="mean")
        row = {
            "cluster": first.get("cluster"),
            "host": first.get("host"),
            "node_list": first.get("node_list"),
            "input_backend": first.get("input_backend"),
            "batch_size": as_int(first.get("batch_size")),
            "num_workers": as_int(first.get("num_workers")),
            "prefetch_factor": as_int(first.get("prefetch_factor")),
            "dali_num_threads": as_int(first.get("dali_num_threads")),
            "dali_prefetch_queue_depth": as_int(first.get("dali_prefetch_queue_depth")),
            "dali_decode_mode": first.get("dali_decode_mode"),
            "dali_hw_decoder_load": as_float(first.get("dali_hw_decoder_load")),
            "pin_memory": first.get("pin_memory"),
            "persistent_workers": first.get("persistent_workers"),
            "warmup_batches": as_int(first.get("warmup_batches")),
            "measured_batches": as_int(first.get("measured_batches")),
            "repeat_count": len(values),
            "aggregation_kind": "olympic" if agg.get("olympic_available") else "partial" if len(values) > 1 else "single",
            "samples_per_second": agg.get("center"),
            "mean_samples_per_second": agg.get("mean"),
            "min_samples_per_second": agg.get("min"),
            "max_samples_per_second": agg.get("max"),
            "stdev_samples_per_second": agg.get("stdev"),
            "aggregation_note": agg.get("note"),
            "job_ids": ",".join(str(row.get("job_id")) for row in group_rows if row.get("job_id")),
            "run_ids": ",".join(str(row.get("run_id")) for row in group_rows if row.get("run_id")),
            "summary_paths": ",".join(str(row.get("summary_path")) for row in group_rows if row.get("summary_path")),
        }
        row["config_label"] = config_label(row)
        out.append(row)
    return pd.DataFrame(out, columns=columns).sort_values(
        ["input_backend", "samples_per_second", "batch_size"],
        ascending=[True, False, True],
    )


def add_cpu_speedup(aggregate_df):
    if aggregate_df.empty:
        aggregate_df["speedup_vs_cpu_anchor"] = None
        return aggregate_df
    out = aggregate_df.copy()
    cpu_rows = out[out["input_backend"] == "pytorch-cpu-dataloader"].copy()
    cpu_anchor = None
    if not cpu_rows.empty:
        cpu_anchor = cpu_rows.sort_values("samples_per_second", ascending=False).iloc[0]["samples_per_second"]
    out["speedup_vs_cpu_anchor"] = out["samples_per_second"].apply(
        lambda value: float(value) / float(cpu_anchor)
        if cpu_anchor is not None and not is_missing(value) and float(cpu_anchor) > 0
        else None
    )
    return out


def write_tuning_plot(aggregate_df, output_path):
    dali = aggregate_df[aggregate_df["input_backend"] == "dali-gpu-decode"].copy()
    if dali.empty:
        return False
    queues = sorted(dali["dali_prefetch_queue_depth"].dropna().unique())
    fig, axes = plt.subplots(1, len(queues), figsize=(5 * len(queues), 4), sharey=True)
    if len(queues) == 1:
        axes = [axes]
    for ax, queue in zip(axes, queues):
        qdf = dali[dali["dali_prefetch_queue_depth"] == queue]
        for threads, group in qdf.groupby("dali_num_threads"):
            group = group.sort_values("batch_size")
            ax.plot(group["batch_size"], group["samples_per_second"], marker="o", label=f"threads={int(threads)}")
        ax.set_title(f"DALI queue={int(queue)}")
        ax.set_xlabel("batch size")
        ax.grid(alpha=0.25)
    axes[0].set_ylabel("samples/s")
    axes[-1].legend(loc="best")
    fig.suptitle("DALI Standard ImageNet Tuning")
    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    plt.close(fig)
    return True


def write_top_plot(aggregate_df, output_path):
    if aggregate_df.empty:
        return False
    plot_df = aggregate_df.sort_values("samples_per_second", ascending=False).head(12).copy()
    plot_df = plot_df.sort_values("samples_per_second")
    fig, ax = plt.subplots(figsize=(10, max(4, 0.45 * len(plot_df) + 1.5)))
    colors = ["tab:orange" if value == "dali-gpu-decode" else "tab:blue" for value in plot_df["input_backend"]]
    ax.barh(plot_df["config_label"], plot_df["samples_per_second"], color=colors)
    ax.set_xlabel("samples/s")
    ax.set_title("Top Standard ImageNet DataLoader Configs")
    ax.grid(axis="x", alpha=0.25)
    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    plt.close(fig)
    return True


def table(lines, rows, columns):
    lines.append("| " + " | ".join(label for label, _key, _fmt in columns) + " |")
    lines.append("| " + " | ".join("---" for _ in columns) + " |")
    for _, row in rows.iterrows():
        cells = []
        for _label, key, formatter in columns:
            cells.append(formatter(row.get(key)))
        lines.append("| " + " | ".join(cells) + " |")


def write_markdown(output_path, date_value, cluster, rows, aggregate_df, artifacts):
    lines = [
        f"# DataLoader DALI Standard ImageNet Optimization - {cluster}",
        "",
        "Purpose: tune DALI on canonical ImageNet input and compare finalists with the tuned PyTorch CPU DataLoader anchor.",
        "",
        "This rendered report is study evidence for DataLoader-only input throughput. It is not DDP training throughput.",
        "",
        "## Run Shape",
        "",
        "| Field | Value |",
        "| --- | --- |",
        f"| Date | `{date_value}` |",
        f"| Cluster | `{cluster}` |",
        "| Dataset | canonical ImageNet ImageFolder train split |",
        "| Mode | `replicated` |",
        "| Nodes / GPUs | `1` / `8` |",
        "| Warmup / measured | `100` / `500` batches |",
        "| Main DALI mode | `random-crop` |",
        "",
        "## CPU Anchor",
        "",
    ]
    cpu_rows = aggregate_df[aggregate_df["input_backend"] == "pytorch-cpu-dataloader"].copy()
    if cpu_rows.empty:
        lines.append("No CPU anchor rows found.")
    else:
        table(
            lines,
            cpu_rows.sort_values("samples_per_second", ascending=False),
            [
                ("Config", "config_label", esc),
                ("Repeats", "repeat_count", fmt_int),
                ("Aggregation", "aggregation_kind", esc),
                ("Samples/s", "samples_per_second", fmt_sps),
                ("Job IDs", "job_ids", esc),
            ],
        )
    lines.extend(["", "## DALI Tuning Rows", ""])
    dali_rows = aggregate_df[aggregate_df["input_backend"] == "dali-gpu-decode"].copy()
    if dali_rows.empty:
        lines.append("No DALI rows found.")
    else:
        top = dali_rows.sort_values("samples_per_second", ascending=False).head(12)
        table(
            lines,
            top,
            [
                ("Config", "config_label", esc),
                ("Repeats", "repeat_count", fmt_int),
                ("Aggregation", "aggregation_kind", esc),
                ("Samples/s", "samples_per_second", fmt_sps),
                ("Vs CPU", "speedup_vs_cpu_anchor", fmt_speedup),
                ("Job IDs", "job_ids", esc),
            ],
        )
    lines.extend(["", "## Figures", ""])
    for label, path in artifacts:
        lines.append(f"- {label}: `{path.name}`")
    lines.extend([
        "",
        "## Promotion Notes",
        "",
        "- Single-repeat DALI rows are tuning evidence only.",
        "- A DALI finalist needs five passed numeric repeats before publication.",
        "- A DALI loss on standard ImageNet is a valid result: it means this workload does not amortize DALI overhead against the tuned CPU anchor.",
        "",
        "## Source Rows",
        "",
        f"- Parsed summaries included: `{len(rows)}`",
        f"- Aggregate configs included: `{len(aggregate_df)}`",
        "",
    ])
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    args = build_parser().parse_args()
    report = load_dataloader_report_module()
    date_value = report.resolve_date(args.date)
    results_root = Path(args.results_root)
    output_dir = Path(args.output_dir) if args.output_dir else results_root / "reports" / date_value / "dataloader-dali-standard-imagenet"
    output_dir.mkdir(parents=True, exist_ok=True)

    rows = report.load_rows(results_root, date_value, args.cluster)
    df = pd.DataFrame(rows)
    filtered = standard_imagenet_rows(df, include_smoke=args.include_smoke)
    aggregate_df = add_cpu_speedup(aggregate_configs(filtered))

    prefix = f"dataloader-dali-standard-imagenet-{args.cluster}-{date_value}"
    summary_csv = output_dir / f"{prefix}-summary.csv"
    summary_json = output_dir / f"{prefix}-summary.json"
    aggregate_csv = output_dir / f"{prefix}-aggregate.csv"
    aggregate_json = output_dir / f"{prefix}-aggregate.json"
    tuning_plot = output_dir / f"{prefix}-dali-tuning.png"
    top_plot = output_dir / f"{prefix}-top-configs.png"
    markdown = output_dir / f"{prefix}.md"

    filtered.to_csv(summary_csv, index=False)
    summary_json.write_text(json.dumps(filtered.to_dict(orient="records"), indent=2) + "\n", encoding="utf-8")
    aggregate_df.to_csv(aggregate_csv, index=False)
    aggregate_json.write_text(json.dumps(aggregate_df.to_dict(orient="records"), indent=2) + "\n", encoding="utf-8")

    artifacts = []
    if write_tuning_plot(aggregate_df, tuning_plot):
        artifacts.append(("DALI tuning plot", tuning_plot))
    if write_top_plot(aggregate_df, top_plot):
        artifacts.append(("Top config plot", top_plot))
    write_markdown(markdown, date_value, args.cluster, filtered, aggregate_df, artifacts)
    print(f"Wrote {markdown}")
    print(f"Wrote {aggregate_csv}")


if __name__ == "__main__":
    main()
