#!/usr/bin/env python3
"""Aggregate read-throughput summary across a peak-read job array.

Usage:
    python scripts/peak_aggregate_summary.py results-peak/<TAG>

Sums per-rank GBps across ALL array tasks for raw reads, prints the cluster
aggregate, and compares to the Vast spec Max Read = 462 GB/s.

The simultaneity caveat: per-rank GBps = total_bytes / per-rank-elapsed. Summing
across ranks/tasks overestimates the true wall-clock aggregate when tasks don't
overlap perfectly. We also report the conservative bound = total_bytes_all /
max_elapsed_all, which is closer to a real concurrent-aggregate number.
"""

import csv
import glob
import os
import statistics
import sys
from collections import defaultdict

VAST_MAX_READ_GBPS = 462.0

def parse_run(run_dir: str):
    # rows are 15-col READ schema; collect per-iter values
    by_iter = defaultdict(list)        # iter -> list of (gbps, elapsed_s, bytes)
    task_aggregate_by_iter = defaultdict(lambda: defaultdict(float))  # iter -> task -> sum_gbps
    rank_count = 0
    csv_files = sorted(glob.glob(os.path.join(run_dir, "task_*", "results.*.csv")))
    if not csv_files:
        sys.exit(f"no per-rank CSVs found under {run_dir}/task_*/")
    for f in csv_files:
        task = os.path.basename(os.path.dirname(f))
        with open(f) as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("timestamp,"):
                    continue
                parts = line.split(",")
                if len(parts) != 15:
                    continue
                mode = parts[3]
                if mode != "raw":
                    continue
                total_bytes = int(parts[6])
                elapsed_s = float(parts[7])
                gbps = float(parts[8])
                it = int(parts[14])
                by_iter[it].append((gbps, elapsed_s, total_bytes))
                task_aggregate_by_iter[it][task] += gbps
                rank_count += 1
    return by_iter, task_aggregate_by_iter, rank_count, csv_files

def main():
    if len(sys.argv) != 2:
        sys.exit("usage: peak_aggregate_summary.py <run_dir>")
    run_dir = sys.argv[1]
    by_iter, task_agg, rank_count, csv_files = parse_run(run_dir)

    print(f"Run dir: {run_dir}")
    print(f"Per-rank CSVs: {len(csv_files)}, total raw-read rows: {rank_count}")
    print(f"Tasks: {len(set(task for d in task_agg.values() for task in d))}")
    print()

    iters = sorted(by_iter)
    if not iters:
        sys.exit("no raw rows parsed")

    print(f"{'iter':>4}  {'cluster_sum_GBps':>17}  {'conservative_GBps':>18}  {'vs_462_spec':>12}  {'ranks':>6}")
    print(f"{'-'*4:>4}  {'-'*17:>17}  {'-'*18:>18}  {'-'*12:>12}  {'-'*6:>6}")
    sums = []
    conservatives = []
    for it in iters:
        rows = by_iter[it]
        total_bytes = sum(b for _, _, b in rows)
        max_elapsed = max(e for _, e, _ in rows)
        # sum-of-per-rank-throughputs (matches summary.md convention)
        sum_gbps = sum(g for g, _, _ in rows)
        # conservative = total_bytes / max_elapsed → true cluster wall-clock rate
        conservative_gbps = total_bytes / max_elapsed / 1e9
        sums.append(sum_gbps)
        conservatives.append(conservative_gbps)
        pct = 100.0 * sum_gbps / VAST_MAX_READ_GBPS
        print(f"{it:>4}  {sum_gbps:>17.2f}  {conservative_gbps:>18.2f}  {pct:>11.1f}%  {len(rows):>6}")

    mean_sum = statistics.mean(sums)
    mean_cons = statistics.mean(conservatives)
    print()
    print(f"mean cluster_sum_GBps (sum-of-rank-rates) : {mean_sum:8.2f} GB/s  "
          f"=> {100.0*mean_sum/VAST_MAX_READ_GBPS:5.1f}% of Vast Max Read (462 GB/s)")
    print(f"mean conservative_GBps (bytes/max_elapsed): {mean_cons:8.2f} GB/s  "
          f"=> {100.0*mean_cons/VAST_MAX_READ_GBPS:5.1f}% of Vast Max Read (462 GB/s)")
    print()
    print("Notes:")
    print("- sum-of-rank-rates matches the convention in summary.md (overestimates when")
    print("  ranks/tasks finish at different times).")
    print("- conservative bound is the right number to compare to a true wall-clock")
    print("  cluster aggregate; if it is well below sum-of-rank-rates, the array tasks")
    print("  did not overlap enough — shrink TOTAL_SIZE or increase ITERS so all tasks")
    print("  overlap during the measurement window.")

if __name__ == "__main__":
    main()
