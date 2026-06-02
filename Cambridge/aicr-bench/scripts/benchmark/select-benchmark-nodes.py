#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import sys
from pathlib import Path


SUPPORTED_CLUSTERS = ("b200", "rtxpro6000")


def build_parser():
    parser = argparse.ArgumentParser(description="Select verified healthy nodes for benchmark pilots.")
    parser.add_argument("--date", default="today", help="UTC date, today, yesterday, or YYYY-MM-DD")
    parser.add_argument("--cluster", default="b200", choices=SUPPORTED_CLUSTERS)
    parser.add_argument("--count", type=int, help="Maximum number of passed nodes to return")
    parser.add_argument("--results-root", default="results")
    parser.add_argument("--exclude", default="", help="Comma- or space-separated nodes to exclude")
    parser.add_argument("--format", choices=["csv", "lines"], default="csv")
    return parser


def resolve_date(value):
    if value == "today":
        return dt.datetime.now(dt.timezone.utc).date().isoformat()
    if value == "yesterday":
        return (dt.datetime.now(dt.timezone.utc).date() - dt.timedelta(days=1)).isoformat()
    return value


def excluded_nodes(value):
    return {item for item in value.replace(",", " ").split() if item}


def load_report(results_root, date_value, cluster):
    report_path = Path(results_root) / "reports" / date_value / f"nodes-{cluster}-{date_value}.json"
    if not report_path.exists():
        raise SystemExit(f"node report not found: {report_path}")
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"unable to parse node report: {report_path}: {exc}") from exc
    if report.get("cluster") not in (None, cluster):
        raise SystemExit(f"node report cluster mismatch: expected {cluster}, found {report.get('cluster')}")
    return report_path, report


def select_nodes(report, exclude):
    selected = []
    for item in report.get("nodes") or []:
        node = item.get("node")
        if not node or node in exclude:
            continue
        if item.get("status") == "passed":
            selected.append(node)
    return selected


def main():
    args = build_parser().parse_args()
    if args.count is not None and args.count < 1:
        raise SystemExit("--count must be positive when provided")

    date_value = resolve_date(args.date)
    report_path, report = load_report(args.results_root, date_value, args.cluster)
    nodes = select_nodes(report, excluded_nodes(args.exclude))

    if args.count is not None:
        if len(nodes) < args.count:
            raise SystemExit(f"requested {args.count} healthy nodes, found {len(nodes)} in {report_path}")
        nodes = nodes[: args.count]

    if args.format == "lines":
        print("\n".join(nodes))
    else:
        print(",".join(nodes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
