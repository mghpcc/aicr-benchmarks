#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


COMMAND_SIGNAL_LABELS = {
    "target_path": "target path",
    "block_size": "block size",
    "file_size_or_count": "file size/count",
    "threads": "threads",
    "iodepth": "iodepth",
    "direct_io": "direct I/O",
    "cleanup": "cleanup",
    "dryrun_or_preflight": "dry-run/preflight",
    "namespace_cleanup": "namespace cleanup",
    "metadata_cache_control": "metadata cache control",
    "distributed_host_list": "distributed host list",
    "service_start": "service start",
    "service_stop": "service stop",
}

WORKLOAD_ORDER = {
    "peak-cluster": 0,
    "small-block": 1,
    "small-file": 2,
    "metadata": 3,
}

METRIC_KEYS = [
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
]


def build_parser():
    p = argparse.ArgumentParser(description="Render elbencho Benchmark 0 reports.")
    p.add_argument("--results-root", default="results")
    p.add_argument("--date", required=True)
    p.add_argument("--cluster", required=True, choices=["b200", "rtxpro6000"])
    p.add_argument("--ascii", action="store_true")
    p.add_argument("--markdown", action="store_true")
    p.add_argument("--both", action="store_true")
    p.add_argument("--write", action="store_true")
    return p


def load_json(path):
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def collect_summaries(results_root, date, cluster):
    root = results_root / "by-date" / date / "parsed" / cluster / "multi-node" / "elbencho"
    if not root.exists():
        return []
    return [run_dir / "summary.json" for run_dir in sorted(root.iterdir()) if (run_dir / "summary.json").exists()]


def markdown_escape(value):
    text = str(value if value is not None else "")
    return text.replace("|", "\\|")


def format_number(value):
    if isinstance(value, float):
        return f"{value:.3f}".rstrip("0").rstrip(".")
    return value


def format_missing_signals(missing):
    if not missing:
        return "-"
    return ", ".join(COMMAND_SIGNAL_LABELS.get(item, item.replace("_", " ")) for item in missing)


def row_sort_key(row):
    return (
        WORKLOAD_ORDER.get(row.get("workload"), 99),
        str(row.get("run_id") or ""),
        str(row.get("job_id") or ""),
    )


def selected_campaign_rows(rows):
    if not rows:
        return []
    source_rows = [row for row in rows if row.get("status") == "passed"]
    by_workload = {}
    for row in source_rows:
        workload = row.get("workload")
        by_workload.setdefault(workload, []).append(row)
    selected = []
    for workload_rows in by_workload.values():
        latest_rows = sorted(workload_rows, key=row_sort_key, reverse=True)[:5]
        selected.append(aggregate_rows(latest_rows))
    return sorted(selected, key=row_sort_key)


def olympic_mean(values):
    if not values:
        return None
    if len(values) >= 3:
        ordered = sorted(values)
        values = ordered[1:-1]
    return sum(values) / len(values)


def aggregate_rows(rows):
    rows = sorted(rows, key=row_sort_key)
    latest = dict(rows[-1])
    latest["sample_count"] = len(rows)
    latest["aggregation"] = "olympic mean" if len(rows) >= 3 else "mean"
    latest["run_id"] = ", ".join(row["run_id"] for row in rows)
    latest["job_id"] = ", ".join(str(row["job_id"]) for row in rows)
    for key in METRIC_KEYS:
        values = [row.get(key) for row in rows if isinstance(row.get(key), (int, float))]
        latest[key] = olympic_mean(values)
    return latest


def rows_from_summaries(paths):
    rows = []
    for path in paths:
        summary = load_json(path)
        peers = summary.get("peer_nodes") or []
        metrics = summary.get("metrics") or {}
        review = summary.get("command_review") or {}
        rows.append({
            "date": summary.get("date") or "-",
            "workload": summary.get("workload") or "-",
            "profile": summary.get("profile") or "-",
            "run_id": summary.get("run_id") or path.parent.name,
            "job_id": summary.get("job_id") or "-",
            "nodes": summary.get("node_count") or len(peers) or "-",
            "node_group": ",".join(peers) if peers else "-",
            "status": summary.get("status") or "-",
            "return_code": summary.get("return_code") if summary.get("return_code") is not None else "-",
            "evidence_label": summary.get("evidence_label") or "-",
            "read_iops": metrics.get("read_iops"),
            "write_iops": metrics.get("write_iops"),
            "read_mib_per_second": metrics.get("read_mib_per_second"),
            "write_mib_per_second": metrics.get("write_mib_per_second"),
            "mkdirs_per_second": metrics.get("mkdirs_per_second"),
            "file_creates_per_second": metrics.get("file_creates_per_second"),
            "file_reads_per_second": metrics.get("file_reads_per_second"),
            "file_writes_per_second": metrics.get("file_writes_per_second"),
            "rmfiles_per_second": metrics.get("rmfiles_per_second"),
            "rmdirs_per_second": metrics.get("rmdirs_per_second"),
            "stats_per_second": metrics.get("stats_per_second"),
            "command_review_status": review.get("status") or "needs-review",
            "command_review_missing": format_missing_signals(review.get("missing") or []),
            "command_review_missing_count": len(review.get("missing") or []),
            "notes": summary.get("notes") or "",
        })
    return rows


def columns():
    return [
        ("workload", "Workload"),
        ("profile", "Profile"),
        ("sample_count", "Samples"),
        ("aggregation", "Aggregation"),
        ("job_id", "Job"),
        ("run_id", "Run"),
        ("nodes", "Nodes"),
        ("node_group", "Node Group"),
        ("status", "Status"),
        ("return_code", "RC"),
        ("evidence_label", "Evidence Label"),
        ("read_iops", "Read IOPS"),
        ("write_iops", "Write IOPS"),
        ("read_mib_per_second", "Read MiB/s"),
        ("write_mib_per_second", "Write MiB/s"),
        ("mkdirs_per_second", "Mkdir/s"),
        ("file_creates_per_second", "File create/s"),
        ("file_reads_per_second", "File read/s"),
        ("file_writes_per_second", "File write/s"),
        ("rmfiles_per_second", "Rmfile/s"),
        ("rmdirs_per_second", "Rmdir/s"),
        ("stats_per_second", "Stat/s"),
        ("command_review_status", "Command Review"),
        ("command_review_missing", "Missing Command Signals"),
        ("notes", "Notes"),
    ]


def render_table(rows, cols):
    lines = ["| " + " | ".join(label for _, label in cols) + " |"]
    lines.append("| " + " | ".join("---" for _ in cols) + " |")
    if not rows:
        lines.append("| " + " | ".join("-" for _ in cols) + " |")
        return lines
    for row in rows:
        lines.append("| " + " | ".join(markdown_escape(format_number(row.get(key, ""))) for key, _ in cols) + " |")
    return lines


def command_review_rows(rows):
    return [
        {
            "workload": row["workload"],
            "run_id": row["run_id"],
            "status": row["command_review_status"],
            "missing": row["command_review_missing"],
        }
        for row in rows
        if row["command_review_status"] != "reviewed-shape"
    ]


def render_markdown(rows, date, cluster):
    campaign_rows = selected_campaign_rows(rows)
    lines = [
        f"# Elbencho Storage Benchmark {cluster} {date}",
        "",
        "Benchmark 0 is separate from GDS readiness. GDS stays node-local and `gdsio`-only; elbencho is the VAST/filesystem benchmark surface for peak cluster, small-block, small-file, and metadata evidence.",
        "",
        "Command review is shape validation only. A `reviewed-shape` command exposes the expected path, size/count, concurrency, cleanup, and dry-run signals for its workload. B200 campaign readiness still depends on the workload-definition review gates, storage-side facts, and accepted final evidence.",
        "",
        "The evidence table selects the latest passed row for each workload.",
    ]
    if cluster != "b200":
        lines.extend([
            "",
            f"`{cluster}` Elbencho rows are harness/runtime rehearsal evidence only. Final campaign Elbencho scope is B200.",
        ])
    lines.extend([
        "",
        "## Campaign Evidence Rows",
        "",
    ])
    lines.extend(render_table(campaign_rows, columns()))
    lines.append("")
    if not rows:
        lines.append("No elbencho summaries were found for this date and cluster.")
        lines.append("")
    needs_review = command_review_rows(rows)
    if needs_review:
        lines.extend([
            "## Command Review Follow-Up",
            "",
            "| Workload | Run | Review Status | Missing Signals |",
            "| --- | --- | --- | --- |",
        ])
        for row in needs_review:
            lines.append(
                "| "
                + " | ".join(markdown_escape(row[key]) for key in ("workload", "run_id", "status", "missing"))
                + " |"
            )
        lines.append("")
    return "\n".join(lines)


def render_ascii(rows, date, cluster):
    return render_markdown(rows, date, cluster)


def main():
    args = build_parser().parse_args()
    results_root = Path(args.results_root)
    rows = rows_from_summaries(collect_summaries(results_root, args.date, args.cluster))

    want_ascii = args.ascii or args.both or not args.markdown
    want_markdown = args.markdown or args.both

    if want_ascii:
        print(render_ascii(rows, args.date, args.cluster))
    if want_markdown:
        text = render_markdown(rows, args.date, args.cluster)
        if args.write:
            out = results_root / "reports" / args.date / f"elbencho-{args.cluster}.md"
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(text, encoding="utf-8")
            print(f"Wrote {out}")
        else:
            print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
