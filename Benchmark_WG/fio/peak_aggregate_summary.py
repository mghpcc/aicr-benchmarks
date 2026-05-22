#!/usr/bin/env python3
"""Aggregate fio JSON outputs from a peak-aggregate job-array run.

Usage:
    python peak_aggregate_summary.py results-peak/<TAG>

Sums per-node fio bandwidth and IOPS across ALL array tasks for each
workload, and compares to Vast spec (Max Read = 462 GB/s, Max Write = 165
GB/s).

Two numbers per workload, same convention as the raw-io summary script:

  cluster_sum     = sum of per-fio-process throughput. Matches the
                    sum-of-rank-rates convention from the dataloader/raw-io
                    suites; overestimates when nodes don't overlap perfectly.
  conservative    = (total bytes across all fio processes) / (max elapsed
                    across all fio processes). Honest wall-clock cluster
                    aggregate when tasks may not overlap.
"""

import glob
import json
import os
import statistics
import sys
from collections import defaultdict

VAST_SPEC = {
    "seq_read":   ("BW",   462.0,  "GB/s"),
    "seq_write":  ("BW",   165.0,  "GB/s"),
    "rand_read":  ("IOPS", None,   "kIOPS"),
    "rand_write": ("IOPS", None,   "kIOPS"),
}

WORKLOAD_FROM_JOBNAME = {
    "seq_read":   "seq_read",
    "seq_write":  "seq_write",
    "rand_read":  "rand_read",
    "rand_write": "rand_write",
}


def parse_run(run_dir: str):
    """Return {workload: [(bytes, runtime_ms, bw_bytes_per_s, iops, jsonpath)]}."""
    by_wl = defaultdict(list)
    json_files = sorted(glob.glob(os.path.join(run_dir, "task_*", "*.json")))
    if not json_files:
        sys.exit(f"no fio JSON outputs found under {run_dir}/task_*/")
    for f in json_files:
        try:
            with open(f) as fh:
                data = json.load(fh)
        except json.JSONDecodeError as e:
            print(f"warn: skipping {f}: {e}", file=sys.stderr)
            continue
        for job in data.get("jobs", []):
            name = job.get("jobname", "")
            wl = WORKLOAD_FROM_JOBNAME.get(name)
            if wl is None:
                continue
            # fio groups read and write totals separately; pick the side
            # the workload exercises.
            if wl.endswith("read"):
                side = job.get("read", {})
            else:
                side = job.get("write", {})
            total_bytes = int(side.get("io_bytes", 0))
            runtime_ms = int(side.get("runtime", 0))
            bw_bps = float(side.get("bw_bytes", 0.0))  # bytes/sec
            iops = float(side.get("iops", 0.0))
            if runtime_ms <= 0 or total_bytes <= 0:
                continue
            by_wl[wl].append((total_bytes, runtime_ms, bw_bps, iops, f))
    return by_wl


def fmt_bw(bps: float) -> str:
    return f"{bps / 1e9:8.2f} GB/s"


def fmt_iops(iops: float) -> str:
    return f"{iops / 1e3:8.2f} kIOPS"


def print_workload(wl: str, rows):
    metric, spec, unit = VAST_SPEC[wl]
    print(f"\n=== {wl}  ({metric})  [{len(rows)} fio processes] ===")
    if not rows:
        print("  no data")
        return

    total_bytes = sum(r[0] for r in rows)
    max_runtime_s = max(r[1] for r in rows) / 1000.0
    sum_bw_bps = sum(r[2] for r in rows)
    sum_iops = sum(r[3] for r in rows)
    cons_bw_bps = total_bytes / max_runtime_s if max_runtime_s > 0 else 0.0

    if metric == "BW":
        cluster_sum = sum_bw_bps
        cluster_cons = cons_bw_bps
        fmt = fmt_bw
        spec_str = f"{spec:.0f} GB/s" if spec else "n/a"
        pct_sum = 100.0 * (cluster_sum / 1e9) / spec if spec else 0.0
        pct_cons = 100.0 * (cluster_cons / 1e9) / spec if spec else 0.0
    else:
        cluster_sum = sum_iops
        # conservative IOPS = total ops / max elapsed. We didn't capture
        # total_ios directly, so derive from total_bytes assuming 4 KiB.
        total_ops = total_bytes / 4096
        cluster_cons = total_ops / max_runtime_s if max_runtime_s > 0 else 0.0
        fmt = fmt_iops
        spec_str = "n/a"
        pct_sum = pct_cons = 0.0

    print(f"  cluster_sum   (sum of per-process rates):  {fmt(cluster_sum)}")
    print(f"  conservative  (total_bytes / max_runtime): {fmt(cluster_cons)}")
    if spec:
        print(f"  vs Vast spec  ({spec_str}):"
              f"  sum={pct_sum:5.1f}%   conservative={pct_cons:5.1f}%")

    samples = [r[2] if metric == "BW" else r[3] for r in rows]
    print(f"  per-process distribution: min={fmt(min(samples))}  "
          f"median={fmt(statistics.median(samples))}  max={fmt(max(samples))}")


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: peak_aggregate_summary.py <run_dir>")
    run_dir = sys.argv[1]
    by_wl = parse_run(run_dir)

    json_files = sorted(glob.glob(os.path.join(run_dir, "task_*", "*.json")))
    tasks = sorted({os.path.basename(os.path.dirname(f)) for f in json_files})
    print(f"Run dir: {run_dir}")
    print(f"Tasks:        {len(tasks)}")
    print(f"JSON files:   {len(json_files)}")
    print(f"Workloads:    {sorted(by_wl)}")

    for wl in ("seq_read", "seq_write", "rand_read", "rand_write"):
        if wl in by_wl:
            print_workload(wl, by_wl[wl])

    print()
    print("Notes:")
    print("- cluster_sum matches the convention in ../raw-io/peak_aggregate_summary.py")
    print("  (sum of per-process bandwidths). Overestimates when nodes finish at")
    print("  different times.")
    print("- conservative is the honest wall-clock aggregate. If it is well below")
    print("  cluster_sum, tasks did not overlap enough — raise RUNTIME or lower")
    print("  SIZE_PER_JOB so all tasks are still running through the measurement")
    print("  window.")


if __name__ == "__main__":
    main()
