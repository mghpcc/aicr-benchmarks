#!/usr/bin/env python3
"""Aggregate fio JSON outputs from a peak-aggregate job-array run.

Usage:
    python peak_aggregate_summary.py results-peak/<TAG>

Sums per-node fio bandwidth and IOPS across ALL array tasks for each
(workload, file-size) cell, and compares to Vast spec.

Two numbers per cell, same convention as the raw-io summary script:

  cluster_sum     = sum of per-fio-process throughput. Matches the
                    sum-of-rank-rates convention from the dataloader/raw-io
                    suites; overestimates when nodes don't overlap perfectly.
  conservative    = (total bytes across all fio processes) / (max elapsed
                    across all fio processes). Honest wall-clock cluster
                    aggregate when tasks may not overlap.

Jobname convention emitted by the wrapper:
  seq_read_1M, seq_read_10M, seq_read_100M, ...  (sequential size sweep)
  rand_read, rand_write                          (single-size IOPS workloads)
"""

import glob
import json
import os
import re
import statistics
import sys
from collections import defaultdict

VAST_SPEC = {
    "seq_read":   ("BW",   462.0,   "GB/s"),
    "seq_write":  ("BW",   165.0,   "GB/s"),
    "rand_read":  ("IOPS", 2775.0,  "kIOPS"),
    "rand_write": ("IOPS",  825.0,  "kIOPS"),
}

WORKLOADS = ("seq_read", "seq_write", "rand_read", "rand_write")


def parse_jobname(jobname: str):
    """Split a fio jobname into (workload, size_label) or return None.

    Sequential sweeps emit names like 'seq_read_1M'; random workloads emit
    bare 'rand_read' / 'rand_write'.
    """
    for wl in WORKLOADS:
        if jobname == wl:
            return (wl, None)
        if jobname.startswith(wl + "_"):
            return (wl, jobname[len(wl) + 1:])
    return None


def parse_run(run_dir: str):
    """Return {(workload, size_label): [(bytes, runtime_ms, bw_bps, iops, path)]}."""
    by_cell = defaultdict(list)
    json_files = sorted(glob.glob(os.path.join(run_dir, "task_*", "*.json")))
    if not json_files:
        sys.exit(f"no fio JSON outputs found under {run_dir}/task_*/")
    for f in json_files:
        # fio may prepend "note:" lines (e.g. iodepth-warning for sync
        # engines) before the JSON body. Trim everything up to the first '{'
        # before parsing so we don't choke on the prologue.
        try:
            with open(f) as fh:
                text = fh.read()
            start = text.find("{")
            if start < 0:
                raise ValueError("no JSON object found")
            data = json.loads(text[start:])
        except (json.JSONDecodeError, ValueError) as e:
            print(f"warn: skipping {f}: {e}", file=sys.stderr)
            continue
        for job in data.get("jobs", []):
            name = job.get("jobname", "")
            cell = parse_jobname(name)
            if cell is None:
                continue
            wl, _size = cell
            side = job.get("read", {}) if wl.endswith("read") else job.get("write", {})
            total_bytes = int(side.get("io_bytes", 0))
            runtime_ms = int(side.get("runtime", 0))
            bw_bps = float(side.get("bw_bytes", 0.0))
            iops = float(side.get("iops", 0.0))
            if runtime_ms <= 0 or total_bytes <= 0:
                continue
            by_cell[cell].append((total_bytes, runtime_ms, bw_bps, iops, f))
    return by_cell


def fmt_bw(bps: float) -> str:
    return f"{bps / 1e9:8.2f} GB/s"


def fmt_iops(iops: float) -> str:
    return f"{iops / 1e3:8.2f} kIOPS"


_SIZE_ORDER_RE = re.compile(r"^(\d+)([KMGT]?)i?$", re.IGNORECASE)
_SIZE_MULT = {"": 1, "K": 1 << 10, "M": 1 << 20, "G": 1 << 30, "T": 1 << 40}


def size_sort_key(s):
    if s is None:
        return -1
    m = _SIZE_ORDER_RE.match(s)
    if not m:
        return float("inf")
    n, suf = m.groups()
    return int(n) * _SIZE_MULT[suf.upper()]


def print_cell(wl: str, size_label, rows):
    metric, spec, _unit = VAST_SPEC[wl]
    tag = f"{wl}  [{size_label}]" if size_label else wl
    print(f"\n=== {tag}  ({metric})  [{len(rows)} fio processes] ===")
    if not rows:
        print("  no data")
        return

    total_bytes = sum(r[0] for r in rows)
    max_runtime_s = max(r[1] for r in rows) / 1000.0
    sum_bw_bps = sum(r[2] for r in rows)
    sum_iops = sum(r[3] for r in rows)
    cons_bw_bps = total_bytes / max_runtime_s if max_runtime_s > 0 else 0.0

    # Both BW and IOPS are emitted for every workload; spec comparison goes
    # to whichever metric is the "primary" one for that workload (BW for seq,
    # IOPS for rand). The other is shown for context.
    print(f"  BW   cluster_sum:   {fmt_bw(sum_bw_bps)}   "
          f"conservative: {fmt_bw(cons_bw_bps)}")
    # Derive conservative IOPS from per-process iops samples (sum) and the
    # wall-clock conservative ratio (matches BW handling).
    bs_bytes = total_bytes / sum(r[1] for r in rows) * 1000.0 if sum(r[1] for r in rows) > 0 else 0
    # conservative IOPS = total_ops / max_runtime where ops = total_bytes / bs
    # We don't always know bs exactly; derive it as (sum_bw_bps / sum_iops).
    if sum_iops > 0:
        avg_bs = sum_bw_bps / sum_iops
    else:
        avg_bs = bs_bytes if bs_bytes > 0 else 4096
    total_ops = total_bytes / avg_bs if avg_bs > 0 else 0
    cons_iops = total_ops / max_runtime_s if max_runtime_s > 0 else 0.0
    print(f"  IOPS cluster_sum:   {fmt_iops(sum_iops)}   "
          f"conservative: {fmt_iops(cons_iops)}   "
          f"(avg bs ≈ {avg_bs/1024:.0f} KiB)")

    if spec:
        if metric == "BW":
            primary_sum = sum_bw_bps / 1e9
            primary_cons = cons_bw_bps / 1e9
            spec_str = f"{spec:.0f} GB/s"
        else:
            primary_sum = sum_iops / 1e3
            primary_cons = cons_iops / 1e3
            spec_str = f"{spec:.0f} kIOPS"
        pct_sum = 100.0 * primary_sum / spec
        pct_cons = 100.0 * primary_cons / spec
        print(f"  vs Vast spec  ({spec_str}):"
              f"  sum={pct_sum:5.1f}%   conservative={pct_cons:5.1f}%")

    bw_samples = [r[2] for r in rows]
    iops_samples = [r[3] for r in rows]
    print(f"  per-process BW   distribution: min={fmt_bw(min(bw_samples))}  "
          f"median={fmt_bw(statistics.median(bw_samples))}  max={fmt_bw(max(bw_samples))}")
    print(f"  per-process IOPS distribution: min={fmt_iops(min(iops_samples))}  "
          f"median={fmt_iops(statistics.median(iops_samples))}  max={fmt_iops(max(iops_samples))}")


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: peak_aggregate_summary.py <run_dir>")
    run_dir = sys.argv[1]
    by_cell = parse_run(run_dir)

    json_files = sorted(glob.glob(os.path.join(run_dir, "task_*", "*.json")))
    tasks = sorted({os.path.basename(os.path.dirname(f)) for f in json_files})
    print(f"Run dir: {run_dir}")
    print(f"Tasks:        {len(tasks)}")
    print(f"JSON files:   {len(json_files)}")
    print(f"Cells found:  {sorted(by_cell)}")

    for wl in WORKLOADS:
        sizes = [s for (w, s) in by_cell if w == wl]
        sizes.sort(key=size_sort_key)
        for sz in sizes:
            print_cell(wl, sz, by_cell[(wl, sz)])

    print()
    print("Notes:")
    print("- cluster_sum matches the convention in ../raw-io/peak_aggregate_summary.py")
    print("  (sum of per-process bandwidths). Overestimates when nodes finish at")
    print("  different times.")
    print("- conservative is the honest wall-clock aggregate. If it is well below")
    print("  cluster_sum, tasks did not overlap enough — for seq_* this is")
    print("  expected at small sizes (short single-pass runtime).")
    print("- seq_* runs are single-pass (loops=1) with nrfiles chosen so per-job")
    print("  working set = TOTAL_PER_JOB. Client cache is bypassed via direct=1 +")
    print("  invalidate=1 + fadvise_hint=1. Server CBOX cache is mitigated by")
    print("  cluster-aggregate working set > cache size, not flushed.")


if __name__ == "__main__":
    main()
