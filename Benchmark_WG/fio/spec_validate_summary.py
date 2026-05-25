#!/usr/bin/env python3
"""Fair Vast-spec validation readout for a client-count scaling sweep.

Usage:
    python spec_validate_summary.py results-peak/specval_<TIMESTAMP>
    python spec_validate_summary.py results-peak/specval_<TIMESTAMP>_c42  # one tier

Reads every tier directory matching "<base>_c<NN>" (NN = client-node count)
produced by submit_spec_validate.sh, aggregates each tier with the proven
parse_run() from peak_aggregate_summary.py, and prints:

  * a scaling table per I/O direction (throughput vs client count),
  * % of the vendor spec — for writes against BOTH the Max and the Sustained
    spec lines,
  * a CACHE flag whenever a cold read still exceeds its storage ceiling
    (conservative read > Max ⇒ cache leaked through; not a real cold number),
  * a verdict per direction: MEETS spec / STORAGE-limited (plateaued below
    spec) / CLIENT-limited (still rising at the largest tier).

Conservative aggregate (honest wall-clock) is used throughout — never the
optimistic cluster_sum — because this script exists to make a fair claim.
"""

import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from peak_aggregate_summary import parse_run  # reuse the JSON parsing

# (metric, Max spec, Sustained spec or None, unit)
SPEC = {
    "seq_read":   ("BW",   462.0, None,  "GB/s"),
    "seq_write":  ("BW",   165.0, 87.5,  "GB/s"),   # Max / Sustained
    "rand_read":  ("IOPS", 2775.0, None, "kIOPS"),
    "rand_write": ("IOPS", 825.0, None,  "kIOPS"),
}
DIRECTIONS = ("seq_read", "seq_write", "rand_read", "rand_write")


def cell_conservative(rows):
    """(procs, conservative_GBps, conservative_kIOPS) for one parsed cell."""
    if not rows:
        return (0, 0.0, 0.0)
    total_bytes = sum(r[0] for r in rows)
    max_runtime_s = max(r[1] for r in rows) / 1000.0
    sum_bw_bps = sum(r[2] for r in rows)
    sum_iops = sum(r[3] for r in rows)
    cons_bw = total_bytes / max_runtime_s if max_runtime_s > 0 else 0.0
    avg_bs = (sum_bw_bps / sum_iops) if sum_iops > 0 else 4096.0
    total_ops = total_bytes / avg_bs if avg_bs > 0 else 0.0
    cons_iops = total_ops / max_runtime_s if max_runtime_s > 0 else 0.0
    return (len(rows), cons_bw / 1e9, cons_iops / 1e3)


def tier_value(by_cell, wl):
    """Primary conservative metric for a direction in one tier, plus procs."""
    rows = by_cell.get((wl, None), [])
    procs, gbps, kiops = cell_conservative(rows)
    metric = SPEC[wl][0]
    return procs, (gbps if metric == "BW" else kiops)


def discover_tiers(base):
    """Return [(node_count, run_dir)] sorted by node count.

    Accepts either a base prefix (…/specval_<ts>) → globs _c<NN>, or a single
    tier dir (…/specval_<ts>_c42).
    """
    tiers = []
    direct = re.search(r"_c(\d+)$", base.rstrip("/"))
    if direct and os.path.isdir(base):
        return [(int(direct.group(1)), base.rstrip("/"))]
    for d in glob.glob(base.rstrip("/") + "_c*"):
        m = re.search(r"_c(\d+)$", d)
        if m and os.path.isdir(d):
            tiers.append((int(m.group(1)), d))
    return sorted(tiers)


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: spec_validate_summary.py results-peak/specval_<TIMESTAMP>[_cNN]")
    base = sys.argv[1]
    tiers = discover_tiers(base)
    if not tiers:
        sys.exit(f"no tier dirs found for prefix '{base}' (expected '<base>_c<NN>')")

    # Aggregate every tier up front: results[wl] = [(nodes, value, procs), ...]
    results = {wl: [] for wl in DIRECTIONS}
    for nodes, run_dir in tiers:
        by_cell = parse_run(run_dir)
        for wl in DIRECTIONS:
            procs, val = tier_value(by_cell, wl)
            results[wl].append((nodes, val, procs))

    print(f"Vast spec VALIDATION — scaling sweep")
    print(f"Base: {base}")
    print(f"Tiers (client nodes): {', '.join(str(n) for n, _ in tiers)}")
    print("All numbers are CONSERVATIVE (honest wall-clock) aggregates, cold + "
          "sustained.\n")

    for wl in DIRECTIONS:
        metric, spec_max, spec_sus, unit = SPEC[wl]
        print(f"=== {wl}  ({unit}, cold/sustained) ===")
        header = f"  {'nodes':>6} {'procs':>6} {unit:>12} {'%Max':>8}"
        if spec_sus:
            header += f" {'%Sustained':>11}"
        header += "  note"
        print(header)

        rising = None
        prev = None
        for nodes, val, procs in results[wl]:
            pct_max = 100.0 * val / spec_max
            line = f"  {nodes:>6} {procs:>6} {val:>12.1f} {pct_max:>7.1f}%"
            if spec_sus:
                line += f" {100.0*val/spec_sus:>10.1f}%"
            note = ""
            # Cold sequential read above its BW Max ceiling is physically
            # impossible for cold data ⇒ cache leaked through (hard flag).
            if metric == "BW" and wl.endswith("read") and val > spec_max:
                note = "CACHE? read > Max ceiling — working set may still fit cache"
            # Random read IOPS above spec has no hard ceiling (could be the
            # legitimate aggregate-of-clients premium, like rand_write), but it
            # can also be residual cache. Soft cross-check.
            elif metric == "IOPS" and wl.endswith("read") and val > spec_max:
                note = "read > spec — verify it tracks the rand_write premium, else residual cache (raise DEFEAT_TIB)"
            if procs and nodes and procs < nodes:
                note = (note + "; " if note else "") + f"only {procs} procs reported (<{nodes})"
            line += f"  {note}"
            print(line)
            if prev is not None:
                rising = val > prev * 1.05  # >5% gain from previous tier
            prev = val

        # Verdict from the largest tier.
        top_nodes, top_val, _ = results[wl][-1]
        top_pct = 100.0 * top_val / spec_max
        if metric == "BW" and wl.endswith("read") and top_val > spec_max:
            verdict = ("INCONCLUSIVE — top tier exceeds the cold-storage Max "
                       "ceiling, so cache is still leaking. Raise DEFEAT_TIB and re-run.")
        elif metric == "IOPS" and wl.endswith("read") and top_val > spec_max:
            verdict = (f"MEETS spec at {top_nodes} nodes ({top_pct:.0f}% of Max) — "
                       "but confirm this is the aggregate premium (compare to rand_write %), "
                       "not residual cache; if unsure, raise DEFEAT_TIB.")
        elif top_pct >= 95.0:
            verdict = f"MEETS spec at {top_nodes} nodes ({top_pct:.0f}% of Max)."
        elif rising:
            verdict = (f"CLIENT-limited — still rising at {top_nodes} nodes "
                       f"({top_pct:.0f}% of Max). Spec may need more clients than the pool has.")
        else:
            verdict = (f"STORAGE-limited — plateaued at {top_pct:.0f}% of Max by "
                       f"{top_nodes} nodes. Product does not reach the quoted number on this path.")
        print(f"  -> {verdict}")
        if spec_sus and not (metric == "BW" and wl.endswith("read")):
            top_sus = 100.0 * top_val / spec_sus
            print(f"     (write Sustained spec {spec_sus} {unit}: {top_sus:.0f}% at {top_nodes} nodes)")
        print()

    print("Reading this:")
    print("- %Max compares to the vendor 'max' line; for writes %Sustained compares")
    print("  to the sustained line (the honest steady-state target).")
    print("- A read flagged CACHE? is NOT a valid cold number — its working set still")
    print("  fits server cache. Raise DEFEAT_TIB until the flag clears, then re-read.")
    print("- CLIENT-limited means add client nodes; STORAGE-limited means the product")
    print("  itself tops out below spec on this access path. Both are real findings.")
    print("- This is an aggregate-of-N-clients measurement. If the vendor quoted the")
    print("  spec with a specific client fleet, match that fleet for an apples-to-apples")
    print("  claim; otherwise report it explicitly as 'sustained by N client nodes'.")


if __name__ == "__main__":
    main()
