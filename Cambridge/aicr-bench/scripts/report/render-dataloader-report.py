#!/usr/bin/env python3
"""Render DataLoader Markdown summaries from parsed artifacts."""

from __future__ import annotations

import argparse
import csv
import html
import json
import math
import statistics
from datetime import datetime, timedelta, timezone
from pathlib import Path

from repeat_aggregation import OLYMPIC_MIN_SAMPLES, normalize_repeat_aggregation


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render DataLoader result summaries.")
    parser.add_argument("--date", required=True, help="UTC date to render, or today/yesterday.")
    parser.add_argument("--cluster", default="b200", choices=["b200", "rtxpro6000"])
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--output-dir", default=None)
    parser.add_argument("--repeat-aggregation", default="standard", choices=["standard", "olympic"])
    parser.add_argument(
        "--job-id-file",
        default="",
        help="Optional file containing one Slurm job id per line. When set, only matching summaries are rendered.",
    )
    return parser


def resolve_date(value: str) -> str:
    if value not in {"today", "yesterday"}:
        return value
    offset = 0 if value == "today" else 1
    return (datetime.now(timezone.utc).date() - timedelta(days=offset)).isoformat()


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"status": "failed", "notes": f"could not read {path}"}


def load_job_ids(path_value: str) -> set[str] | None:
    if not path_value:
        return None
    path = Path(path_value)
    return {line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()}


def summary_paths(results_root: Path, date_value: str, cluster: str) -> list[Path]:
    base = results_root / "by-date" / date_value / "parsed" / cluster
    paths = []
    paths.extend(base.glob("nodes/*/dataloader/*/summary.json"))
    paths.extend(base.glob("multi-node/dataloader/*/summary.json"))
    return sorted(paths)


def row_from_summary(path: Path, summary: dict) -> dict:
    return {
        "entity": summary.get("node_list") or summary.get("host") or "-",
        "run_id": summary.get("run_id") or path.parent.name,
        "job_id": summary.get("job_id") or "-",
        "status": summary.get("status") or "-",
        "mode": summary.get("mode") or summary.get("sampler_mode") or "-",
        "nodes": summary.get("node_count") or "-",
        "world_size": summary.get("world_size") or summary.get("requested_gpu_count") or "-",
        "batch_size": summary.get("batch_size") or "-",
        "num_workers": summary.get("num_workers") if summary.get("num_workers") is not None else "-",
        "prefetch_factor": summary.get("prefetch_factor") or "-",
        "pin_memory": yes_no(summary.get("pin_memory")),
        "persistent_workers": yes_no(summary.get("persistent_workers")),
        "warmup_batches": summary.get("warmup_batches") if summary.get("warmup_batches") is not None else "-",
        "measured_batches": summary.get("measured_batches") if summary.get("measured_batches") is not None else "-",
        "samples_per_second": summary.get("samples_per_second"),
        "load_samples_per_second": summary.get("aggregate_load_samples_per_second"),
        "h2d_samples_per_second": summary.get("aggregate_h2d_samples_per_second"),
        "estimated_vast_read_gb_per_second": summary.get("estimated_vast_read_gb_per_second"),
        "rank_imbalance_percent": summary.get("rank_imbalance_percent"),
        "gpu_preflight_status": normalize_status(summary.get("gpu_preflight_status")),
        "notes": summary.get("notes") or summary.get("gpu_preflight_note") or "",
        "summary_path": str(path),
    }


def normalize_status(value) -> str:
    text = str(value or "").strip().strip("`").lower()
    if text in {"pass", "passed", "ok"}:
        return "passed"
    if text in {"fail", "failed", "error"}:
        return "failed"
    return text or "-"


def yes_no(value) -> str:
    if value is True or value == 1 or value == "1":
        return "yes"
    if value is False or value == 0 or value == "0":
        return "no"
    return "-"


def fmt(value, digits: int = 2) -> str:
    if isinstance(value, (int, float)):
        return f"{value:.{digits}f}"
    return "-"


def as_number(value):
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if math.isfinite(float(value)):
            return value
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if math.isfinite(number):
        return number
    return None


def as_int(value):
    number = as_number(value)
    if number is None:
        return None
    return int(number)


def md_escape(value) -> str:
    text = str(value)
    return text.replace("|", "\\|")


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fieldnames = list(rows[0].keys())
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


REPEAT_CONFIG_FIELDS = (
    "entity",
    "mode",
    "nodes",
    "world_size",
    "batch_size",
    "num_workers",
    "prefetch_factor",
    "pin_memory",
    "persistent_workers",
    "warmup_batches",
    "measured_batches",
)


def repeat_config_key(row: dict) -> tuple:
    return tuple(str(row.get(field, "-")) for field in REPEAT_CONFIG_FIELDS)


def group_repeat_rows(rows: list[dict]) -> list[list[dict]]:
    grouped: dict[tuple, list[dict]] = {}
    for row in rows:
        if as_number(row.get("samples_per_second")) is None:
            continue
        grouped.setdefault(repeat_config_key(row), []).append(row)
    return [group for _, group in sorted(grouped.items(), key=lambda item: item[0])]


def metric_center(rows: list[dict], key: str, mode: str):
    values = [as_number(row.get(key)) for row in rows]
    numeric = [float(value) for value in values if value is not None]
    if not numeric:
        return None
    if mode == "standard":
        return statistics.median(numeric)
    return statistics.mean(numeric)


def aggregate_dataloader_repeat_rows(
    rows: list[dict],
    mode: str,
    *,
    include_singletons: bool = False,
) -> list[dict]:
    aggregation = normalize_repeat_aggregation(mode)
    summary_rows = []
    for group in group_repeat_rows(rows):
        passed_rows = [
            row
            for row in group
            if row.get("status") == "passed" and as_number(row.get("samples_per_second")) is not None
        ]
        if len(passed_rows) <= 1 and not include_singletons:
            continue
        if not passed_rows:
            continue
        ordered = sorted(passed_rows, key=lambda row: as_number(row.get("samples_per_second")) or 0.0)
        dropped_rows: list[dict] = []
        fallback_used = False
        if aggregation == "olympic":
            if len(ordered) >= OLYMPIC_MIN_SAMPLES:
                retained_rows = ordered[1:-1]
                dropped_rows = [ordered[0], ordered[-1]]
                note = f"olympic avg from {len(retained_rows)}/{len(ordered)}; dropped min/max throughput"
            else:
                retained_rows = ordered
                fallback_used = True
                note = f"olympic unavailable: need >= {OLYMPIC_MIN_SAMPLES} passed numeric samples"
        else:
            retained_rows = ordered
            note = "median from passed numeric samples"

        samples_values = [
            float(as_number(row.get("samples_per_second")) or 0.0)
            for row in retained_rows
        ]
        if not samples_values:
            continue
        samples_center = statistics.median(samples_values)
        if aggregation == "olympic" and not fallback_used:
            samples_center = statistics.mean(samples_values)
        base = {field: group[0].get(field, "-") for field in REPEAT_CONFIG_FIELDS}
        base.update(
            {
                "run_id": f"{len(passed_rows)} samples",
                "job_id": f"{len(passed_rows)} jobs",
                "status": "passed" if len(passed_rows) == len(group) else "mixed",
                "samples_per_second": samples_center,
                "samples_per_second_low": min(samples_values),
                "samples_per_second_high": max(samples_values),
                "samples_per_second_jitter": max(samples_values) - min(samples_values),
                "load_samples_per_second": metric_center(retained_rows, "load_samples_per_second", aggregation),
                "h2d_samples_per_second": metric_center(retained_rows, "h2d_samples_per_second", aggregation),
                "estimated_vast_read_gb_per_second": metric_center(
                    retained_rows,
                    "estimated_vast_read_gb_per_second",
                    aggregation,
                ),
                "rank_imbalance_percent": metric_center(retained_rows, "rank_imbalance_percent", aggregation),
                "gpu_preflight_status": "passed"
                if all(row.get("gpu_preflight_status") == "passed" for row in passed_rows)
                else "mixed",
                "notes": note,
                "repeat_sample_count": len(group),
                "repeat_passed_count": len(passed_rows),
                "repeat_included_count": len(retained_rows),
                "repeat_aggregation": aggregation,
                "repeat_fallback_used": fallback_used,
                "repeat_dropped_jobs": "/".join(str(row.get("job_id", "-")) for row in dropped_rows) or "-",
                "repeat_dropped_samples_per_second": "/".join(
                    f"{float(as_number(row.get('samples_per_second')) or 0.0):.2f}"
                    for row in dropped_rows
                )
                or "-",
                "summary_path": ";".join(str(row.get("summary_path", "")) for row in retained_rows),
            }
        )
        summary_rows.append(base)
    return summary_rows


def plot_label(row: dict) -> str:
    return (
        f"{row['mode']}\n"
        f"{row['nodes']}n/{row['world_size']}r\n"
        f"b{row['batch_size']} w{row['num_workers']} pf{row['prefetch_factor']}"
    )


def write_throughput_png(path: Path, rows: list[dict], date_value: str, cluster: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    numeric_rows = [
        row
        for row in rows
        if isinstance(row.get("samples_per_second"), (int, float))
    ]
    width = max(9.0, min(18.0, 0.75 * max(len(numeric_rows), 1)))
    height = 6.0 if numeric_rows else 3.0
    fig, ax = plt.subplots(figsize=(width, height))
    if numeric_rows:
        values = [row["samples_per_second"] for row in numeric_rows]
        labels = [plot_label(row) for row in numeric_rows]
        bars = ax.bar(range(len(values)), values, color="#2f6f9f")
        ax.set_xticks(range(len(labels)))
        ax.set_xticklabels(labels, rotation=45, ha="right")
        ax.set_ylabel("Samples/s")
        ax.bar_label(bars, labels=[f"{value:,.0f}" for value in values], padding=3, fontsize=8)
        ax.margins(y=0.15)
    else:
        ax.text(0.5, 0.5, "No numeric DataLoader rows", ha="center", va="center")
        ax.set_axis_off()
    ax.set_title(f"DataLoader throughput - {cluster} - {date_value}")
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def dataloader_dataframe(rows: list[dict]):
    import pandas as pd

    normalized_rows = []
    for row in rows:
        samples_per_second = as_number(row.get("samples_per_second"))
        nodes = as_int(row.get("nodes"))
        batch_size = as_int(row.get("batch_size"))
        num_workers = as_int(row.get("num_workers"))
        prefetch_factor = as_int(row.get("prefetch_factor"))
        if (
            samples_per_second is None
            or nodes is None
            or batch_size is None
            or num_workers is None
            or prefetch_factor is None
        ):
            continue
        normalized_rows.append(
            {
                **row,
                "samples_per_second": float(samples_per_second),
                "load_samples_per_second": as_number(row.get("load_samples_per_second")),
                "h2d_samples_per_second": as_number(row.get("h2d_samples_per_second")),
                "estimated_vast_read_gb_per_second": as_number(row.get("estimated_vast_read_gb_per_second")),
                "rank_imbalance_percent": as_number(row.get("rank_imbalance_percent")),
                "nodes": nodes,
                "batch_size": batch_size,
                "num_workers": num_workers,
                "prefetch_factor": prefetch_factor,
            }
        )
    return pd.DataFrame(normalized_rows)


def write_matrix_png(
    path: Path,
    rows: list[dict],
    date_value: str,
    cluster: str,
    *,
    metric: str,
    title: str,
    colorbar_label: str,
    cmap: str,
    value_format: str,
    threshold: float | None = None,
    threshold_label: str | None = None,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    import matplotlib

    matplotlib.use("Agg")
    from matplotlib import colors as mcolors
    import matplotlib.pyplot as plt
    import pandas as pd

    df = dataloader_dataframe(rows)
    df = df[df[metric].notna()] if not df.empty else df
    if df.empty:
        fig, ax = plt.subplots(figsize=(8, 3))
        ax.text(0.5, 0.5, f"No numeric {metric} rows", ha="center", va="center")
        ax.set_axis_off()
        ax.set_title(f"{title} - {cluster} - {date_value}")
        fig.tight_layout()
        fig.savefig(path, dpi=150)
        plt.close(fig)
        return

    node_values = sorted(df["nodes"].dropna().unique())
    prefetch_values = sorted(df["prefetch_factor"].dropna().unique())
    batch_values = sorted(df["batch_size"].dropna().unique())
    worker_values = sorted(df["num_workers"].dropna().unique())
    facet_values = [
        (node, prefetch)
        for node in node_values
        for prefetch in prefetch_values
    ]
    values = df[metric].dropna()
    vmin = float(values.min())
    vmax = float(values.max())
    if metric == "rank_imbalance_percent":
        vmin = 0.0
        vmax = max(vmax, threshold or 5.0)
    if vmin == vmax:
        vmax = vmin + 1.0
    cmap_object = plt.get_cmap(cmap)
    normalizer = mcolors.Normalize(vmin=vmin, vmax=vmax)

    def annotation_color(value: float, *, highlight: bool = False) -> str:
        red, green, blue, _alpha = cmap_object(normalizer(value))
        luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        if highlight and luminance > 0.55:
            return "#b00020"
        return "black" if luminance > 0.55 else "white"

    facet_count = len(facet_values)
    fig_width = max(9.5, 4.8 * facet_count + 2.8)
    fig_height = max(5.4, 0.70 * len(batch_values) + 3.8)
    fig, axes = plt.subplots(
        1,
        facet_count,
        figsize=(fig_width, fig_height),
        squeeze=False,
        sharey=True,
    )
    last_image = None
    for ax, (node_count, prefetch) in zip(axes[0], facet_values):
        subset = df[(df["nodes"] == node_count) & (df["prefetch_factor"] == prefetch)]
        pivot = (
            subset.pivot_table(
                index="batch_size",
                columns="num_workers",
                values=metric,
                aggfunc="mean",
            )
            .reindex(index=batch_values, columns=worker_values)
        )
        samples_pivot = None
        if metric == "rank_imbalance_percent":
            samples_pivot = (
                subset.pivot_table(
                    index="batch_size",
                    columns="num_workers",
                    values="samples_per_second",
                    aggfunc="mean",
                )
                .reindex(index=batch_values, columns=worker_values)
            )
        last_image = ax.imshow(
            pivot.to_numpy(),
            aspect="auto",
            cmap=cmap,
            vmin=vmin,
            vmax=vmax,
            origin="lower",
        )
        if len(node_values) > 1:
            ax.set_title(f"{node_count} nodes\nprefetch={prefetch}")
        else:
            ax.set_title(f"prefetch={prefetch}")
        ax.set_xticks(range(len(worker_values)))
        ax.set_xticklabels([str(value) for value in worker_values])
        ax.set_xlabel("num_workers")
        ax.set_yticks(range(len(batch_values)))
        ax.set_yticklabels([str(value) for value in batch_values])
        ax.set_ylabel("batch_size")
        for y_index, batch_size in enumerate(batch_values):
            for x_index, num_workers in enumerate(worker_values):
                value = pivot.loc[batch_size, num_workers]
                if pd.isna(value):
                    ax.text(x_index, y_index, "-", ha="center", va="center", fontsize=8)
                    continue
                numeric_value = float(value)
                highlighted = threshold is not None and numeric_value > threshold
                text_color = annotation_color(numeric_value, highlight=highlighted)
                label = value_format.format(numeric_value)
                fontsize = 8
                if samples_pivot is not None:
                    samples_value = samples_pivot.loc[batch_size, num_workers]
                    if not pd.isna(samples_value):
                        label = f"{numeric_value:.1f}%\n{float(samples_value):,.0f}/s"
                        fontsize = 7
                ax.text(
                    x_index,
                    y_index,
                    label,
                    ha="center",
                    va="center",
                    fontsize=fontsize,
                    color=text_color,
                    fontweight="bold" if highlighted else "normal",
                )
    subtitle = f"{title} - {cluster} - {date_value}"
    if threshold_label:
        subtitle = f"{subtitle}\n{threshold_label}"
    fig.suptitle(subtitle)
    fig.subplots_adjust(
        left=0.14 if facet_count == 1 else 0.08,
        right=0.80 if facet_count == 1 else 0.84,
        bottom=0.15,
        top=0.80 if threshold_label else 0.86,
        wspace=0.24,
    )
    if last_image is not None:
        cbar_ax = fig.add_axes([0.84 if facet_count == 1 else 0.88, 0.22, 0.025, 0.55])
        cbar = fig.colorbar(last_image, cax=cbar_ax)
        cbar.set_label(colorbar_label, labelpad=10)
    fig.savefig(path, dpi=150)
    plt.close(fig)


def write_candidate_scatter_png(path: Path, rows: list[dict], date_value: str, cluster: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    df = dataloader_dataframe(rows)
    df = df[df["rank_imbalance_percent"].notna()] if not df.empty else df
    if df.empty:
        fig, ax = plt.subplots(figsize=(8, 3))
        ax.text(0.5, 0.5, "No numeric candidate rows", ha="center", va="center")
        ax.set_axis_off()
        ax.set_title(f"DataLoader candidate scatter - {cluster} - {date_value}")
        fig.tight_layout()
        fig.savefig(path, dpi=150)
        plt.close(fig)
        return

    batches = sorted(df["batch_size"].unique())
    prefetch_values = sorted(df["prefetch_factor"].unique())
    markers = ["o", "s", "^", "D", "P", "X"]
    cmap = plt.get_cmap("viridis", len(batches))
    color_by_batch = {batch: cmap(index) for index, batch in enumerate(batches)}
    marker_by_prefetch = {
        prefetch: markers[index % len(markers)]
        for index, prefetch in enumerate(prefetch_values)
    }

    fig, ax = plt.subplots(figsize=(10, 6.5))
    for batch in batches:
        for prefetch in prefetch_values:
            subset = df[(df["batch_size"] == batch) & (df["prefetch_factor"] == prefetch)]
            if subset.empty:
                continue
            ax.scatter(
                subset["rank_imbalance_percent"],
                subset["samples_per_second"],
                s=90,
                color=color_by_batch[batch],
                marker=marker_by_prefetch[prefetch],
                edgecolor="black",
                linewidth=0.5,
                alpha=0.85,
                label=f"batch={batch}, prefetch={prefetch}",
            )
    balanced = df[df["rank_imbalance_percent"] <= 5.0]
    label_rows = balanced.sort_values("samples_per_second", ascending=False).head(8)
    for _, row in label_rows.iterrows():
        ax.annotate(
            f"b{int(row['batch_size'])}/w{int(row['num_workers'])}/pf{int(row['prefetch_factor'])}",
            (row["rank_imbalance_percent"], row["samples_per_second"]),
            textcoords="offset points",
            xytext=(5, 5),
            fontsize=8,
        )
    ax.axvline(5.0, color="#b00020", linestyle="--", linewidth=1.5, label="5% imbalance rule")
    ax.set_xlabel("Rank imbalance (%)")
    ax.set_ylabel("Samples/s")
    ax.set_title(f"DataLoader candidates - {cluster} - {date_value}")
    ax.grid(True, alpha=0.25)
    ax.legend(loc="center left", bbox_to_anchor=(1.02, 0.5), fontsize=8)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def candidate_summary_rows(df, *, limit: int = 6):
    balanced = df[df["rank_imbalance_percent"] <= 5.0].copy()
    source = balanced if not balanced.empty else df.copy()
    return source.sort_values("samples_per_second", ascending=False).head(limit)


def one_line_candidate(row) -> str:
    return (
        f"nodes={int(row.nodes)}, batch={int(row.batch_size)}, workers={int(row.num_workers)}, "
        f"prefetch={int(row.prefetch_factor)}"
    )


def dashboard_takeaways(df) -> tuple[list[str], object, object]:
    candidates = candidate_summary_rows(df, limit=6)
    best = candidates.iloc[0] if not candidates.empty else None
    scale_pool = candidates[candidates["batch_size"] <= 768] if not candidates.empty else candidates
    scale_anchor = scale_pool.iloc[0] if not scale_pool.empty else best
    is_aggregated = "repeat_sample_count" in df.columns and df["repeat_sample_count"].notna().any()
    takeaways = [
        (
            "Read this as repeated configuration evidence using the requested aggregation."
            if is_aggregated
            else "Read this as one-sample shape discovery: use it to choose finalist repeats, not as final benchmark evidence."
        ),
        "Prefer cells that are bright in throughput and still green in rank imbalance; the red dashed line marks the 5% balance rule.",
    ]
    if "num_workers" in df.columns and sorted(df["num_workers"].dropna().unique()) == [16]:
        takeaways.append("Worker count is fixed at 16 here, so the remaining question is batch size versus prefetch factor.")
    if best is not None:
        takeaways.append(
            "Best balanced point: "
            f"{one_line_candidate(best)} at {best.samples_per_second:,.0f} samples/s "
            f"and {best.rank_imbalance_percent:.2f}% imbalance."
        )
    if scale_anchor is not None:
        takeaways.append(
            "Practical first scale anchor: "
            f"{one_line_candidate(scale_anchor)} because it keeps the batch size at or below 768 "
            "while staying near the throughput plateau."
        )
    takeaways.append("Run repeated Olympic finalist validation before moving to multi-node DataLoader scale.")
    return takeaways, best, scale_anchor


def html_candidate_table(df) -> str:
    candidates = candidate_summary_rows(df, limit=8)
    if candidates.empty:
        return "<p>No balanced numeric candidates were available.</p>"
    rows = [
        "<table>",
        "<thead><tr>"
        "<th>Rank</th><th>Nodes</th><th>Batch</th><th>Workers</th><th>Prefetch</th>"
        "<th>Samples/s</th><th>Imbalance</th><th>VAST GB/s</th><th>Job</th>"
        "</tr></thead>",
        "<tbody>",
    ]
    for rank, row in enumerate(candidates.itertuples(), start=1):
        rows.append(
            "<tr>"
            f"<td>{rank}</td>"
            f"<td>{int(row.nodes)}</td>"
            f"<td>{int(row.batch_size)}</td>"
            f"<td>{int(row.num_workers)}</td>"
            f"<td>{int(row.prefetch_factor)}</td>"
            f"<td>{row.samples_per_second:,.0f}</td>"
            f"<td>{row.rank_imbalance_percent:.2f}%</td>"
            f"<td>{fmt(row.estimated_vast_read_gb_per_second, 3)}</td>"
            f"<td>{html.escape(str(row.job_id))}</td>"
            "</tr>"
        )
    rows.extend(["</tbody>", "</table>"])
    return "\n".join(rows)


def build_interactive_html_page(
    cluster: str,
    date_value: str,
    lede: str,
    takeaways: list[str],
    candidate_table_html: str,
    plot_html: str,
) -> str:
    takeaway_items = "\n".join(f"<li>{html.escape(item)}</li>" for item in takeaways)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>DataLoader {html.escape(cluster)} {html.escape(date_value)}</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      margin: 0;
      color: #172b4d;
      background: #f7f9fc;
    }}
    main {{
      max-width: 1360px;
      margin: 0 auto;
      padding: 28px;
    }}
    h1 {{
      margin: 0 0 6px;
      font-size: 28px;
    }}
    .lede {{
      margin: 0 0 18px;
      color: #4a5875;
    }}
    .summary {{
      display: grid;
      grid-template-columns: minmax(0, 1.2fr) minmax(420px, 0.8fr);
      gap: 18px;
      align-items: start;
      margin-bottom: 22px;
    }}
    .panel {{
      background: white;
      border: 1px solid #d9e1ef;
      border-radius: 8px;
      padding: 16px 18px;
      box-shadow: 0 1px 2px rgba(9, 30, 66, 0.08);
    }}
    .panel h2 {{
      margin: 0 0 10px;
      font-size: 18px;
    }}
    li {{
      margin-bottom: 8px;
      line-height: 1.4;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }}
    th, td {{
      border-bottom: 1px solid #edf1f7;
      padding: 6px 8px;
      text-align: right;
    }}
    th:first-child, td:first-child {{
      text-align: left;
    }}
    .plot {{
      background: white;
      border: 1px solid #d9e1ef;
      border-radius: 8px;
      padding: 8px;
      overflow-x: auto;
    }}
    @media (max-width: 980px) {{
      .summary {{
        grid-template-columns: 1fr;
      }}
    }}
  </style>
</head>
<body>
  <main>
    <h1>DataLoader matrix - {html.escape(cluster)} - {html.escape(date_value)}</h1>
    <p class="lede">{html.escape(lede)}</p>
    <section class="summary">
      <div class="panel">
        <h2>What To Take Away</h2>
        <ol>
{takeaway_items}
        </ol>
      </div>
      <div class="panel">
        <h2>Top Balanced Candidates</h2>
{candidate_table_html}
      </div>
    </section>
    <section class="plot">
{plot_html}
    </section>
  </main>
</body>
</html>
"""


def write_interactive_html(path: Path, rows: list[dict], date_value: str, cluster: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    import pandas as pd
    import plotly.graph_objects as go
    from plotly.subplots import make_subplots

    df = dataloader_dataframe(rows)
    if df.empty:
        path.write_text(
            "<!doctype html><meta charset=\"utf-8\"><title>DataLoader dashboard</title>"
            f"<h1>DataLoader {cluster} {date_value}</h1><p>No numeric rows.</p>\n",
            encoding="utf-8",
        )
        return

    node_values = sorted(df["nodes"].dropna().unique())
    prefetch_values = sorted(df["prefetch_factor"].dropna().unique())
    batch_values = sorted(df["batch_size"].dropna().unique())
    worker_values = sorted(df["num_workers"].dropna().unique())
    facet_values = [
        (node, prefetch)
        for node in node_values
        for prefetch in prefetch_values
    ]
    throughput_min = float(df["samples_per_second"].min())
    throughput_max = float(df["samples_per_second"].max())
    imbalance_max = max(float(df["rank_imbalance_percent"].max()), 5.0)
    takeaways, _, _ = dashboard_takeaways(df)
    is_aggregated = "repeat_sample_count" in df.columns and df["repeat_sample_count"].notna().any()
    rows_count = 3
    fig = make_subplots(
        rows=rows_count,
        cols=len(facet_values),
        subplot_titles=[
            f"Throughput {node}n pf={prefetch}" if len(node_values) > 1 else f"Throughput pf={prefetch}"
            for node, prefetch in facet_values
        ]
        + [
            f"Rank imbalance {node}n pf={prefetch}" if len(node_values) > 1 else f"Rank imbalance pf={prefetch}"
            for node, prefetch in facet_values
        ]
        + ["Candidate scatter"] + [""] * (len(facet_values) - 1),
        specs=[
            [{"type": "heatmap"} for _ in facet_values],
            [{"type": "heatmap"} for _ in facet_values],
            [{"type": "xy", "colspan": len(facet_values)}]
            + [None for _ in range(len(facet_values) - 1)],
        ],
        vertical_spacing=0.10,
        horizontal_spacing=0.06,
    )

    for col_index, (node_count, prefetch) in enumerate(facet_values, start=1):
        subset = df[(df["nodes"] == node_count) & (df["prefetch_factor"] == prefetch)]
        for metric, row_index, colorscale, hover_name in [
            ("samples_per_second", 1, "Viridis", "samples/s"),
            ("rank_imbalance_percent", 2, "RdYlGn_r", "rank imbalance %"),
        ]:
            pivot = (
                subset.pivot_table(
                    index="batch_size",
                    columns="num_workers",
                    values=metric,
                    aggfunc="mean",
                )
                .reindex(index=batch_values, columns=worker_values)
            )
            run_pivot = (
                subset.pivot_table(
                    index="batch_size",
                    columns="num_workers",
                    values="run_id",
                    aggfunc=lambda values: ",".join(str(value) for value in values),
                )
                .reindex(index=batch_values, columns=worker_values)
            )
            job_pivot = (
                subset.pivot_table(
                    index="batch_size",
                    columns="num_workers",
                    values="job_id",
                    aggfunc=lambda values: ",".join(str(value) for value in values),
                )
                .reindex(index=batch_values, columns=worker_values)
            )
            customdata = []
            for batch_size in batch_values:
                row_data = []
                for num_workers in worker_values:
                    run_id = run_pivot.loc[batch_size, num_workers]
                    job_id = job_pivot.loc[batch_size, num_workers]
                    row_data.append([
                        node_count,
                        prefetch,
                        "-" if pd.isna(run_id) else run_id,
                        "-" if pd.isna(job_id) else job_id,
                    ])
                customdata.append(row_data)
            fig.add_trace(
                go.Heatmap(
                    z=pivot.to_numpy(),
                    x=[str(value) for value in worker_values],
                    y=[str(value) for value in batch_values],
                    customdata=customdata,
                    coloraxis="coloraxis" if metric == "samples_per_second" else "coloraxis2",
                    hovertemplate=(
                        "nodes=%{customdata[0]}<br>"
                        "batch=%{y}<br>"
                        "workers=%{x}<br>"
                        "prefetch=%{customdata[1]}<br>"
                        f"{hover_name}=%{{z:.2f}}<br>"
                        "job=%{customdata[3]}<br>"
                        "run=%{customdata[2]}<extra></extra>"
                    ),
                ),
                row=row_index,
                col=col_index,
            )

    for batch_size in batch_values:
        subset = df[df["batch_size"] == batch_size]
        fig.add_trace(
            go.Scatter(
                x=subset["rank_imbalance_percent"],
                y=subset["samples_per_second"],
                mode="markers",
                name=f"batch={batch_size}",
                marker={
                    "size": 11,
                    "line": {"width": 1, "color": "black"},
                },
                customdata=[
                    [
                        int(row.nodes),
                        int(row.batch_size),
                        int(row.num_workers),
                        int(row.prefetch_factor),
                        row.estimated_vast_read_gb_per_second,
                        row.job_id,
                        row.run_id,
                        row.status,
                    ]
                    for row in subset.itertuples()
                ],
                hovertemplate=(
                    "nodes=%{customdata[0]}<br>"
                    "batch=%{customdata[1]}<br>"
                    "workers=%{customdata[2]}<br>"
                    "prefetch=%{customdata[3]}<br>"
                    "samples/s=%{y:.2f}<br>"
                    "rank imbalance=%{x:.2f}%<br>"
                    "VAST GB/s=%{customdata[4]:.3f}<br>"
                    "job=%{customdata[5]}<br>"
                    "run=%{customdata[6]}<br>"
                    "status=%{customdata[7]}<extra></extra>"
                ),
            ),
            row=3,
            col=1,
        )
    highlighted = candidate_summary_rows(df, limit=5)
    if not highlighted.empty:
        fig.add_trace(
            go.Scatter(
                x=highlighted["rank_imbalance_percent"],
                y=highlighted["samples_per_second"],
                mode="markers+text",
                text=[
                    f"{int(row.nodes)}n/b{int(row.batch_size)}/w{int(row.num_workers)}/pf{int(row.prefetch_factor)}"
                    for row in highlighted.itertuples()
                ],
                textposition="top center",
                name="top balanced candidates",
                marker={
                    "symbol": "diamond",
                    "size": 14,
                    "color": "#d62728",
                    "line": {"width": 1.5, "color": "black"},
                },
                customdata=[
                    [
                        int(row.nodes),
                        int(row.batch_size),
                        int(row.num_workers),
                        int(row.prefetch_factor),
                        row.estimated_vast_read_gb_per_second,
                        row.job_id,
                        row.run_id,
                        row.status,
                    ]
                    for row in highlighted.itertuples()
                ],
                hovertemplate=(
                    "candidate=%{text}<br>"
                    "samples/s=%{y:.2f}<br>"
                    "rank imbalance=%{x:.2f}%<br>"
                    "VAST GB/s=%{customdata[4]:.3f}<br>"
                    "job=%{customdata[5]}<br>"
                    "run=%{customdata[6]}<br>"
                    "status=%{customdata[7]}<extra></extra>"
                ),
            ),
            row=3,
            col=1,
        )
    fig.add_vline(x=5.0, line_width=2, line_dash="dash", line_color="#b00020", row=3, col=1)
    fig.update_xaxes(title_text="num_workers", row=1)
    fig.update_xaxes(title_text="num_workers", row=2)
    fig.update_yaxes(title_text="batch_size", row=1, col=1)
    fig.update_yaxes(title_text="batch_size", row=2, col=1)
    fig.update_xaxes(title_text="Rank imbalance (%)", row=3, col=1)
    fig.update_yaxes(title_text="Samples/s", row=3, col=1)
    fig.update_layout(
        title=(
            f"DataLoader matrix - {cluster} - {date_value}"
        ),
        height=1080,
        width=max(1250, 420 * len(facet_values)),
        template="plotly_white",
        margin={"l": 70, "r": 150, "t": 95, "b": 70},
        coloraxis={
            "colorscale": "Viridis",
            "cmin": throughput_min,
            "cmax": throughput_max,
            "colorbar": {"title": "samples/s", "x": 1.03, "y": 0.84, "len": 0.24},
        },
        coloraxis2={
            "colorscale": "RdYlGn_r",
            "cmin": 0,
            "cmax": imbalance_max,
            "colorbar": {"title": "imbalance %", "x": 1.03, "y": 0.49, "len": 0.24},
        },
        legend={
            "orientation": "h",
            "yanchor": "bottom",
            "y": -0.12,
            "xanchor": "left",
            "x": 0,
        },
    )
    plot_html = fig.to_html(include_plotlyjs="inline", full_html=False)
    lede = (
        "Hover cells and points for configuration details. Repeated configs use the requested aggregation; raw job rows remain in the Markdown report."
        if is_aggregated
        else "Hover cells and points for job/run details."
    )
    page = build_interactive_html_page(
        cluster,
        date_value,
        lede,
        takeaways,
        html_candidate_table(df),
        plot_html,
    )
    path.write_text(page, encoding="utf-8")


def build_markdown(
    rows: list[dict],
    summary_rows: list[dict],
    date_value: str,
    cluster: str,
    csv_path: Path,
    summary_csv_path: Path,
    png_path: Path,
    throughput_matrix_path: Path,
    imbalance_matrix_path: Path,
    candidate_scatter_path: Path,
    interactive_html_path: Path,
    repeat_aggregation: str,
    filter_metadata: dict | None = None,
) -> str:
    lines = [
        f"# DataLoader {cluster} {date_value}",
        "",
        "Public DataLoader summary rendered from parsed AICR-Bench artifacts.",
        "",
        "## Summary",
        "",
        f"- Rows: `{len(rows)}`",
        f"- Aggregated repeated configs: `{len(summary_rows)}`",
        f"- Repeat aggregation requested: `{repeat_aggregation}`",
        f"- CSV: `{csv_path}`",
        f"- Aggregated summary CSV: `{summary_csv_path}`",
        f"- Throughput chart: `{png_path}`",
        f"- Throughput matrix: `{throughput_matrix_path}`",
        f"- Rank-imbalance matrix: `{imbalance_matrix_path}`",
        f"- Candidate scatter: `{candidate_scatter_path}`",
        f"- Interactive HTML: `{interactive_html_path}`",
    ]
    if filter_metadata and filter_metadata.get("job_id_file"):
        lines.extend(
            [
                f"- Job ID filter: `{filter_metadata['job_id_file']}`",
                f"- Selected job IDs: `{filter_metadata['selected_job_count']}`",
                f"- Matched summaries: `{filter_metadata['matched_summary_count']}`",
                f"- Skipped summaries outside filter: `{filter_metadata['skipped_summary_count']}`",
            ]
        )
    lines.extend([
        "",
        "## Figures",
        "",
        f"![Throughput matrix]({throughput_matrix_path.name})",
        "",
        f"![Rank-imbalance matrix]({imbalance_matrix_path.name})",
        "",
        f"![Candidate scatter]({candidate_scatter_path.name})",
        "",
        "## Aggregated Configuration Summary",
        "",
    ])
    if summary_rows:
        lines.extend([
            "Repeated configuration rows are summarized before plotting. For olympic aggregation, the renderer drops the lowest and highest throughput samples and computes paired metrics from the same retained jobs.",
            "",
            "| Entity | Mode | Nodes | Ranks | Batch | Workers | Prefetch | Samples | Included | Aggregation | Samples/s | Low | High | Jitter | Rank imbalance % | VAST GB/s | Dropped throughput | Notes |",
            "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |",
        ])
        for row in summary_rows:
            lines.append(
                "| "
                + " | ".join(
                    [
                        f"`{md_escape(row['entity'])}`",
                        f"`{row['mode']}`",
                        str(row["nodes"]),
                        str(row["world_size"]),
                        str(row["batch_size"]),
                        str(row["num_workers"]),
                        str(row["prefetch_factor"]),
                        str(row["repeat_passed_count"]),
                        str(row["repeat_included_count"]),
                        f"`{row['repeat_aggregation']}`",
                        fmt(row["samples_per_second"]),
                        fmt(row["samples_per_second_low"]),
                        fmt(row["samples_per_second_high"]),
                        fmt(row["samples_per_second_jitter"]),
                        fmt(row["rank_imbalance_percent"]),
                        fmt(row["estimated_vast_read_gb_per_second"], 3),
                        md_escape(row["repeat_dropped_samples_per_second"]),
                        md_escape(row["notes"] or ""),
                    ]
                )
                + " |"
            )
    else:
        lines.append("- None")
    lines.extend([
        "",
        "## Rows Needing Review",
        "",
    ])
    review_rows = [row for row in rows if row["status"] != "passed" or row["notes"]]
    if review_rows:
        lines.extend([
            "| Entity | Run | Status | Notes |",
            "| --- | --- | --- | --- |",
        ])
        for row in review_rows:
            lines.append(f"| `{md_escape(row['entity'])}` | `{row['run_id']}` | `{row['status']}` | {md_escape(row['notes'] or '-')} |")
    else:
        lines.append("- None")
    lines.extend([
        "",
        "## Detailed Rows",
        "",
        "| Entity | Run | Job | Mode | Nodes | Ranks | Batch | Workers | Prefetch | Pin | Persistent | Warmup | Measured | Status | Samples/s | Load samples/s | H2D samples/s | VAST GB/s | Rank imbalance % | GPU preflight | Notes |",
        "| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | --- | --- |",
    ])
    if not rows:
        lines.append("| - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |")
    for row in rows:
        lines.append(
            "| "
            + " | ".join(
                [
                    f"`{md_escape(row['entity'])}`",
                    f"`{row['run_id']}`",
                    f"`{row['job_id']}`",
                    f"`{row['mode']}`",
                    str(row["nodes"]),
                    str(row["world_size"]),
                    str(row["batch_size"]),
                    str(row["num_workers"]),
                    str(row["prefetch_factor"]),
                    row["pin_memory"],
                    row["persistent_workers"],
                    str(row["warmup_batches"]),
                    str(row["measured_batches"]),
                    f"`{row['status']}`",
                    fmt(row["samples_per_second"]),
                    fmt(row["load_samples_per_second"]),
                    fmt(row["h2d_samples_per_second"]),
                    fmt(row["estimated_vast_read_gb_per_second"], 3),
                    fmt(row["rank_imbalance_percent"]),
                    f"`{row['gpu_preflight_status']}`",
                    md_escape(row["notes"] or ""),
                ]
            )
            + " |"
        )
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = build_parser().parse_args()
    date_value = resolve_date(args.date)
    results_root = Path(args.results_root)
    output_dir = Path(args.output_dir) if args.output_dir else results_root / "reports" / date_value / "dataloader"
    output_dir.mkdir(parents=True, exist_ok=True)
    job_ids = load_job_ids(args.job_id_file)
    rows = []
    skipped_summary_count = 0
    for path in summary_paths(results_root, date_value, args.cluster):
        summary = load_json(path)
        job_id = str(summary.get("job_id") or "")
        if job_ids is not None and job_id not in job_ids:
            skipped_summary_count += 1
            continue
        rows.append(row_from_summary(path, summary))
    filter_metadata = {
        "job_id_file": args.job_id_file,
        "selected_job_count": len(job_ids) if job_ids is not None else None,
        "matched_summary_count": len(rows),
        "skipped_summary_count": skipped_summary_count,
    }
    summary_rows = aggregate_dataloader_repeat_rows(rows, args.repeat_aggregation)
    plot_rows = aggregate_dataloader_repeat_rows(rows, args.repeat_aggregation, include_singletons=True) or rows
    csv_path = output_dir / f"dataloader-summary-{args.cluster}-{date_value}.csv"
    summary_csv_path = output_dir / f"dataloader-aggregated-summary-{args.cluster}-{date_value}.csv"
    md_path = output_dir / f"dataloader-{args.cluster}-{date_value}.md"
    metadata_path = output_dir / f"dataloader-{args.cluster}-{date_value}.json"
    png_path = output_dir / f"dataloader-throughput-{args.cluster}-{date_value}.png"
    throughput_matrix_path = output_dir / f"dataloader-throughput-matrix-{args.cluster}-{date_value}.png"
    imbalance_matrix_path = output_dir / f"dataloader-imbalance-matrix-{args.cluster}-{date_value}.png"
    candidate_scatter_path = output_dir / f"dataloader-candidate-scatter-{args.cluster}-{date_value}.png"
    interactive_html_path = output_dir / f"dataloader-matrix-{args.cluster}-{date_value}.html"
    write_csv(csv_path, rows)
    write_csv(summary_csv_path, summary_rows)
    write_throughput_png(png_path, plot_rows, date_value, args.cluster)
    write_matrix_png(
        throughput_matrix_path,
        plot_rows,
        date_value,
        args.cluster,
        metric="samples_per_second",
        title="DataLoader throughput matrix",
        colorbar_label="Samples/s",
        cmap="viridis",
        value_format="{:,.0f}",
    )
    write_matrix_png(
        imbalance_matrix_path,
        plot_rows,
        date_value,
        args.cluster,
        metric="rank_imbalance_percent",
        title="DataLoader rank-imbalance matrix",
        colorbar_label="Rank imbalance (%)",
        cmap="RdYlGn_r",
        value_format="{:.1f}",
        threshold=5.0,
        threshold_label="Red labels exceed the 5% publishable balance rule.",
    )
    write_candidate_scatter_png(candidate_scatter_path, plot_rows, date_value, args.cluster)
    write_interactive_html(interactive_html_path, plot_rows, date_value, args.cluster)
    markdown = build_markdown(
        rows,
        summary_rows,
        date_value,
        args.cluster,
        csv_path,
        summary_csv_path,
        png_path,
        throughput_matrix_path,
        imbalance_matrix_path,
        candidate_scatter_path,
        interactive_html_path,
        args.repeat_aggregation,
        filter_metadata,
    )
    md_path.write_text(markdown, encoding="utf-8")
    metadata_path.write_text(
        json.dumps(
            {
                "date": date_value,
                "cluster": args.cluster,
                "row_count": len(rows),
                "aggregated_row_count": len(summary_rows),
                "selected_job_count": filter_metadata["selected_job_count"],
                "matched_summary_count": filter_metadata["matched_summary_count"],
                "skipped_summary_count": filter_metadata["skipped_summary_count"],
                "job_id_file": args.job_id_file,
                "markdown": str(md_path),
                "csv": str(csv_path),
                "aggregated_summary_csv": str(summary_csv_path),
                "png": str(png_path),
                "throughput_matrix_png": str(throughput_matrix_path),
                "imbalance_matrix_png": str(imbalance_matrix_path),
                "candidate_scatter_png": str(candidate_scatter_path),
                "interactive_html": str(interactive_html_path),
                "repeat_aggregation": args.repeat_aggregation,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(markdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
