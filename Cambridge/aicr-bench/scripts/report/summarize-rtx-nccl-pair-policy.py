#!/usr/bin/env python3
import argparse
import csv
import datetime as dt
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path


DEFAULT_TEST_ORDER = [
    "all_reduce_perf",
    "all_gather_perf",
    "reduce_scatter_perf",
    "sendrecv_perf",
    "alltoall_perf",
]


PROFILE_ARGS = {
    "smoke": {
        "min_bytes": "8",
        "max_bytes": "2G",
        "step_factor": "2",
        "warmup_iters": 10,
        "iters": 30,
    },
    "small": {
        "min_bytes": "8",
        "max_bytes": "1G",
        "step_factor": "2",
        "warmup_iters": 5,
        "iters": 20,
    },
    "medium": {
        "min_bytes": "1M",
        "max_bytes": "2G",
        "step_factor": "2",
        "warmup_iters": 10,
        "iters": 50,
    },
    "large": {
        "min_bytes": "1M",
        "max_bytes": "8G",
        "step_factor": "2",
        "warmup_iters": 20,
        "iters": 100,
    },
    "deep": {
        "min_bytes": "1M",
        "max_bytes": "1G",
        "step_factor": "2",
        "warmup_iters": 10,
        "iters": 30,
    },
}


def build_parser():
    parser = argparse.ArgumentParser(
        description="Summarize RTX NCCL pair-policy experiment results."
    )
    parser.add_argument("--date", default="today", help="UTC date, today, or yesterday")
    parser.add_argument("--cluster", default="rtxpro6000")
    parser.add_argument("--results-root", default="results")
    parser.add_argument(
        "--nodes",
        default="",
        help="Optional comma- or space-separated node filter, e.g. 'a0004,a0005 a0006'.",
    )
    parser.add_argument(
        "--tests",
        default=" ".join(DEFAULT_TEST_ORDER),
        help="Optional comma- or space-separated test order/filter.",
    )
    parser.add_argument(
        "--all-runs",
        action="store_true",
        help="Include every run instead of only the latest run per node.",
    )
    parser.add_argument(
        "--view",
        choices=("matrix", "long", "nodes"),
        default="matrix",
        help="Output shape. matrix is one row per node/pair; long is one row per test.",
    )
    parser.add_argument(
        "--scope",
        choices=("pairs", "groups", "full", "all"),
        default="pairs",
        help="Which experiment shape to summarize.",
    )
    parser.add_argument(
        "--format",
        choices=("table", "markdown", "csv"),
        default="table",
    )
    parser.add_argument("--output", default="", help="Write output to this file.")
    return parser


def resolve_date(value):
    if value not in {"today", "yesterday"}:
        return value
    offset = 0 if value == "today" else 1
    return (dt.datetime.now(dt.timezone.utc).date() - dt.timedelta(days=offset)).isoformat()


def split_list(value):
    if not value:
        return []
    return [item for item in value.replace(",", " ").split() if item]


def load_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return {
            "status": "invalid-json",
            "notes": str(exc),
            "summary_path": str(path),
        }


def relative_path(path, base):
    try:
        return str(path.relative_to(base))
    except ValueError:
        return str(path)


def find_summary_paths(results_root, date_value, cluster):
    parsed_root = results_root / "by-date" / date_value / "parsed" / cluster / "nodes"
    if not parsed_root.exists():
        return []
    return sorted(parsed_root.glob("*/nccl-local-experiment/*/summary.json"))


def latest_by_node(items):
    selected = {}
    for item in items:
        node = item["node"]
        current = selected.get(node)
        if current is None or item["sort_key"] > current["sort_key"]:
            selected[node] = item
    return [selected[node] for node in sorted(selected)]


def infer_profile(nccl_args):
    normalized = {
        "min_bytes": str(nccl_args.get("min_bytes", "")),
        "max_bytes": str(nccl_args.get("max_bytes", "")),
        "step_factor": str(nccl_args.get("step_factor", "")),
        "warmup_iters": nccl_args.get("warmup_iters"),
        "iters": nccl_args.get("iters"),
    }
    for name, expected in PROFILE_ARGS.items():
        if normalized == expected:
            return name
    return "custom"


def collect_runs(results_root, date_value, cluster, nodes, all_runs):
    node_filter = set(nodes)
    run_items = []
    for path in find_summary_paths(results_root, date_value, cluster):
        parts = path.parts
        try:
            node = parts[parts.index("nodes") + 1]
            run_id = parts[parts.index("nccl-local-experiment") + 1]
        except (ValueError, IndexError):
            continue
        if node_filter and node not in node_filter:
            continue
        summary = load_json(path)
        run_items.append({
            "node": summary.get("host") or node,
            "path_node": node,
            "run_id": summary.get("run_id") or run_id,
            "summary": summary,
            "summary_path": path,
            "sort_key": (summary.get("run_id") or run_id, path.stat().st_mtime),
        })
    if all_runs:
        return sorted(run_items, key=lambda item: (item["node"], item["run_id"]))
    return latest_by_node(run_items)


def pair_from_experiment(experiment, test_item):
    cuda_visible = test_item.get("cuda_visible_devices") or ""
    if cuda_visible:
        return cuda_visible
    if experiment.startswith("pair_"):
        return experiment[len("pair_"):].replace("_", ",")
    if experiment.startswith("group_"):
        return experiment[len("group_"):].replace("_", ",")
    return experiment


def topology_hint(test_item):
    hints = []
    if test_item.get("channel_via_shm_hits", 0):
        hints.append("SHM")
    if test_item.get("using_network_hits", 0) or test_item.get("net_ib_hits", 0):
        hints.append("NET/IB")
    if test_item.get("type_sys_hits", 0):
        hints.append("SYS")
    if test_item.get("is_all_direct_p2p_zero_hits", 0):
        hints.append("not-all-direct-P2P")
    return ",".join(hints) if hints else "direct-or-unknown"


def shape_for_experiment(experiment_obj):
    group = experiment_obj.get("group")
    if group == "pair_matrix":
        return "pair"
    if group == "group_matrix":
        return "group"
    if experiment_obj.get("gpus_arg") == 8:
        return "full"
    return group or "other"


def scope_allows(scope, shape):
    return (
        scope == "all"
        or (scope == "pairs" and shape == "pair")
        or (scope == "groups" and shape == "group")
        or (scope == "full" and shape == "full")
    )


def add_outlier_columns(rows):
    grouped = defaultdict(list)
    for row in rows:
        value = row.get("largest_message_busbw")
        if isinstance(value, (int, float)):
            grouped[(row["shape"], row["test"], row["topology_hint"])].append(value)

    stats = {}
    for key, values in grouped.items():
        median = statistics.median(values)
        deviations = [abs(value - median) for value in values]
        mad = statistics.median(deviations) if deviations else 0.0
        stats[key] = (median, mad)

    for row in rows:
        value = row.get("largest_message_busbw")
        median, mad = stats.get((row["shape"], row["test"], row["topology_hint"]), (None, None))
        row["fleet_median_busbw"] = median
        if isinstance(value, (int, float)) and median:
            row["fleet_delta_pct"] = ((value - median) / median) * 100
            low_by_mad = mad and value < median - (3 * mad)
            low_by_pct = value < median * 0.90
            row["outlier"] = bool(low_by_mad and low_by_pct)
        else:
            row["fleet_delta_pct"] = None
            row["outlier"] = False
    return rows


def long_rows(run_items, results_root, date_value, cluster, test_filter, scope):
    rows = []
    allowed = set(test_filter)
    for run in run_items:
        summary = run["summary"]
        profile = summary.get("profile") or infer_profile(summary.get("nccl_args") or {})
        experiments = summary.get("experiments") or {}
        for experiment, experiment_obj in sorted(experiments.items()):
            shape = shape_for_experiment(experiment_obj)
            if not scope_allows(scope, shape):
                continue
            for test_item in experiment_obj.get("tests") or []:
                test_name = test_item.get("test", "")
                if allowed and test_name not in allowed:
                    continue
                gpu_set = pair_from_experiment(experiment, test_item)
                rows.append({
                    "date": date_value,
                    "cluster": summary.get("cluster") or cluster,
                    "node": run["node"],
                    "run_id": run["run_id"],
                    "run_status": summary.get("status", ""),
                    "profile": profile,
                    "parallel_pairs": summary.get("parallel_pairs"),
                    "shape": shape,
                    "gpu_set": gpu_set,
                    "pair": gpu_set,
                    "test": test_name,
                    "status": test_item.get("status", ""),
                    "largest_message_busbw": test_item.get("largest_message_busbw"),
                    "max_busbw": test_item.get("max_busbw"),
                    "largest_message_bytes": test_item.get("largest_message_bytes"),
                    "row_count": test_item.get("row_count"),
                    "wrong_count": test_item.get("wrong_count"),
                    "topology_hint": topology_hint(test_item),
                    "notes": test_item.get("notes", ""),
                    "summary_path": relative_path(run["summary_path"], results_root.parent),
                })
    return add_outlier_columns(sorted(rows, key=lambda row: (row["node"], row["run_id"], row["shape"], row["gpu_set"], row["test"])))


def node_rows(run_items, results_root, date_value, cluster):
    rows = []
    for run in run_items:
        summary = run["summary"]
        rows.append({
            "date": date_value,
            "cluster": summary.get("cluster") or cluster,
            "node": run["node"],
            "run_id": run["run_id"],
            "status": summary.get("status", ""),
            "profile": summary.get("profile") or infer_profile(summary.get("nccl_args") or {}),
            "parallel_pairs": summary.get("parallel_pairs"),
            "tests_passed": summary.get("tests_passed"),
            "tests_total": summary.get("tests_total"),
            "detected_gpu_count": summary.get("detected_gpu_count"),
            "dmesg_stop_hits": summary.get("dmesg_stop_hits"),
            "notes": summary.get("notes", ""),
            "summary_path": relative_path(run["summary_path"], results_root.parent),
        })
    return sorted(rows, key=lambda row: (row["node"], row["run_id"]))


def matrix_rows(rows, test_order):
    grouped = {}
    for row in rows:
        key = (row["node"], row["run_id"], row["shape"], row["gpu_set"])
        entry = grouped.setdefault(key, {
            "node": row["node"],
            "run_id": row["run_id"],
            "run_status": row["run_status"],
            "profile": row["profile"],
            "shape": row["shape"],
            "gpu_set": row["gpu_set"],
            "notes": [],
            "values": {},
        })
        value = row.get("largest_message_busbw")
        entry["values"][row["test"]] = {
            "status": row.get("status"),
            "busbw": value,
        }
        if row.get("notes"):
            entry["notes"].append(f"{row['test']}:{row['notes']}")
        if row.get("outlier"):
            entry["notes"].append(f"{row['test']}:fleet-low")

    out = []
    for entry in grouped.values():
        numeric = [
            item["busbw"]
            for item in entry["values"].values()
            if isinstance(item.get("busbw"), (int, float))
        ]
        row = {
            "node": entry["node"],
            "run_id": entry["run_id"],
            "status": entry["run_status"],
            "profile": entry["profile"],
            "shape": entry["shape"],
            "gpu_set": entry["gpu_set"],
        }
        for test in test_order:
            item = entry["values"].get(test)
            if item is None:
                row[test] = None
            elif item.get("status") != "passed":
                row[test] = item.get("status") or "unknown"
            else:
                row[test] = item.get("busbw")
        row["min_busbw"] = min(numeric) if numeric else None
        row["notes"] = "; ".join(entry["notes"])
        out.append(row)
    return sorted(out, key=lambda row: (row["node"], row["run_id"], row["shape"], row["gpu_set"]))


def format_value(value):
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.2f}"
    if isinstance(value, bool):
        return "yes" if value else "no"
    return str(value)


def render_table(rows, columns):
    if not rows:
        return "No matching RTX NCCL pair-policy rows found.\n"
    rendered = [[format_value(row.get(column)) for column in columns] for row in rows]
    widths = [
        max(len(column), *(len(row[idx]) for row in rendered))
        for idx, column in enumerate(columns)
    ]
    lines = ["  ".join(column.ljust(widths[idx]) for idx, column in enumerate(columns))]
    lines.append("  ".join("-" * width for width in widths))
    for row in rendered:
        lines.append("  ".join(value.ljust(widths[idx]) for idx, value in enumerate(row)))
    return "\n".join(lines) + "\n"


def render_markdown(rows, columns):
    if not rows:
        return "No matching RTX NCCL pair-policy rows found.\n"
    lines = [
        "| " + " | ".join(columns) + " |",
        "| " + " | ".join("---" for _ in columns) + " |",
    ]
    for row in rows:
        lines.append("| " + " | ".join(format_value(row.get(column)) for column in columns) + " |")
    return "\n".join(lines) + "\n"


def render_csv(rows, columns):
    import io

    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=columns, extrasaction="ignore")
    writer.writeheader()
    for row in rows:
        writer.writerow(row)
    return buffer.getvalue()


def numeric_values(rows, field):
    return [row[field] for row in rows if isinstance(row.get(field), (int, float))]


def stats_lines(long_result_rows, test_order):
    lines = []
    by_test = defaultdict(list)
    by_set = defaultdict(list)
    for row in long_result_rows:
        value = row.get("largest_message_busbw")
        if not isinstance(value, (int, float)):
            continue
        by_test[row["test"]].append(value)
        by_set[(row["shape"], row["gpu_set"])].append(value)
    if by_test:
        parts = []
        for test in test_order:
            values = by_test.get(test)
            if values:
                parts.append(f"{test} median {statistics.median(values):.2f} GB/s")
        if parts:
            lines.append("Tests: " + "; ".join(parts))
    if by_set:
        parts = []
        for shape, gpu_set in sorted(by_set):
            values = by_set[(shape, gpu_set)]
            parts.append(f"{shape} {gpu_set} median {statistics.median(values):.2f} GB/s")
        lines.append("GPU sets: " + "; ".join(parts))
    group_scores = []
    for (shape, gpu_set), values in by_set.items():
        if shape != "group":
            continue
        gpus = frozenset(int(item) for item in gpu_set.split(",") if item.isdigit())
        if len(gpus) != 4:
            continue
        group_scores.append((statistics.median(values), gpu_set, gpus))
    best_pair = None
    for idx, left in enumerate(group_scores):
        for right in group_scores[idx + 1:]:
            if left[2].isdisjoint(right[2]):
                score = min(left[0], right[0])
                candidate = (score, left, right)
                if best_pair is None or candidate[0] > best_pair[0]:
                    best_pair = candidate
    if best_pair is not None:
        _, left, right = best_pair
        lines.append(
            f"Best disjoint 4-GPU groups: {left[1]} ({left[0]:.2f} GB/s median) + "
            f"{right[1]} ({right[0]:.2f} GB/s median)"
        )
    return lines


def columns_for_view(view, test_order):
    if view == "nodes":
        return [
            "node",
            "run_id",
            "status",
            "profile",
            "parallel_pairs",
            "tests_passed",
            "tests_total",
            "detected_gpu_count",
            "dmesg_stop_hits",
            "notes",
            "summary_path",
        ]
    if view == "long":
        return [
            "node",
            "run_id",
            "run_status",
            "profile",
            "parallel_pairs",
            "shape",
            "gpu_set",
            "test",
            "status",
            "largest_message_busbw",
            "max_busbw",
            "largest_message_bytes",
            "wrong_count",
            "topology_hint",
            "fleet_median_busbw",
            "fleet_delta_pct",
            "outlier",
            "notes",
            "summary_path",
        ]
    return ["node", "run_id", "status", "profile", "shape", "gpu_set", *test_order, "min_busbw", "notes"]


def main():
    args = build_parser().parse_args()
    date_value = resolve_date(args.date)
    results_root = Path(args.results_root)
    nodes = split_list(args.nodes)
    test_order = split_list(args.tests)

    run_items = collect_runs(results_root, date_value, args.cluster, nodes, args.all_runs)
    long_result_rows = long_rows(run_items, results_root, date_value, args.cluster, test_order, args.scope)
    if args.view == "nodes":
        rows = node_rows(run_items, results_root, date_value, args.cluster)
    elif args.view == "long":
        rows = long_result_rows
    else:
        rows = matrix_rows(long_result_rows, test_order)

    columns = columns_for_view(args.view, test_order)
    if args.format == "csv":
        output = render_csv(rows, columns)
    elif args.format == "markdown":
        output = render_markdown(rows, columns)
    else:
        output = render_table(rows, columns)
        extra = stats_lines(long_result_rows, test_order)
        if extra:
            output += "\n" + "\n".join(extra) + "\n"

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
    else:
        sys.stdout.write(output)


if __name__ == "__main__":
    main()
