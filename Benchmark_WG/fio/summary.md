# Storage spec validation — scaling sweep (log.specval-06 → 42)

Source: `specval_1779767723` single-tier runs at 6 / 12 / 24 / 42 client nodes
(`results-peak/specval_1779767723_c06…c42`), cold + sustained (conservative
wall-clock aggregates). Spec constants from `spec_validate_summary.py:41-44`.
In these logs the `procs` column equals the node count (one aggregation unit per
node).

## Vast spec (reference)

| Workload | Metric | Max spec | Sustained spec |
|---|---|---|---|
| seq_read | GB/s | 462.0 | — |
| seq_write | GB/s | 165.0 | 87.5 |
| rand_read | kIOPS | 2775.0 | — |
| rand_write | kIOPS | 825.0 | — |

**Max** is the short-lived burst ceiling — peak throughput while writes still land in the NVMe/RAM buffer before it drains. **Sustained** is the steady-state rate the system holds once those buffers fill and it runs at the backend drain speed, so it's the fair number for any long, honest-fsync run.

## ⭐ MOST IMPORTANT — fair apples-to-apples comparison

Only the valid cold/sustained numbers below are fair to quote against the Vast
spec (cache-tainted reads excluded; writes shown against both spec lines).

| Workload | Fair number | vs spec | Result |
|---|---|---|---|
| **seq_read** | 418.5 GB/s @ c12 | 462 Max | **91%** (top valid tier, still rising) |
| **seq_write** | 85.9 GB/s @ c42 | 87.5 Sustained / 165 Max | **98%** (just under) / **52%** |
| **rand_write** | 463.8 kIOPS @ c42 | 825 Max | **56%** (storage-limited) |
| **rand_read** | 2262.8 kIOPS @ c42 | 2775 Max | **82%** (client-limited, still rising) |

`c06`/`c12`/`c24`/`c42` denote the client-fleet size of each run — 6, 12, 24, and
42 client nodes respectively. **This sweep does not cleanly clear spec on any of
the four paths**: writes plateau below their targets and the only valid read
tier tops out at 91%.

- **seq_read** — 91% of the 462 GB/s Max at 12 nodes and still rising
  (61.5%→90.6%), but the c24/c42 tiers (115.6%/126.4%) exceed the cold ceiling →
  cache-tainted and excluded by the CI gate. The honest valid number is 418.5
  GB/s @ c12; whether it would reach 100% is unknown because the higher tiers are
  invalid.
- **seq_write** — Tracks but never crosses the honest **Sustained** line: flat at
  82–86 GB/s across every tier (93.7%→98.1% of 87.5), peaking at **98%** at 42
  nodes. Against the Max line (165) it is **52%**. Plateaus just under sustained.
- **rand_write** — 56% of the 825 kIOPS Max at 42 nodes and clearly flattening
  (35.7→47.8→55.1→56.2) → **storage-limited well below spec** on this path.
- **rand_read** — 82% of the 2775 kIOPS Max and still climbing near-linearly →
  **client-limited**, the one path with headroom; add client nodes to push higher.

## Results vs spec

| Workload | c06 | c12 | c24 | c42 | Spec basis |
|---|---|---|---|---|---|
| **seq_read** GB/s | 284.3 (61.5%) | 418.5 (**91%**) | 534.2 (116% ⚠) | 584.2 (126% ⚠) | %Max 462 |
| **seq_write** GB/s | 82.0 (50% / 94%) | 83.1 (50% / 95%) | 82.5 (50% / 94%) | 85.9 (52% / **98%**) | %Max 165 / %Sus 87.5 |
| **rand_read** kIOPS | 570.8 (21%) | 974.9 (35%) | 1702.9 (61%) | 2262.8 (**82%**) | %Max 2775 |
| **rand_write** kIOPS | 294.8 (36%) | 394.5 (48%) | 454.9 (55%) | 463.8 (**56%**) | %Max 825 |

⚠ = flagged `CACHE?` — exceeds the physical cold-storage ceiling, so the number
is contaminated by server cache and is **not a valid cold result**.

**CI gate per tier:** c06 PASS · c12 PASS · c24 **FAIL** (seq_read 534.2 > 462) ·
c42 **FAIL** (seq_read 584.2 > 462).

## Verdicts

- **seq_read** — Does not reach Max in any *valid* tier: 91% at 12 nodes, still
  rising. The c24/c42 numbers (116%, 126%) are physically impossible from cold
  media → cache hits, not storage, and trip the CI gate. Honest answer: 418.5
  GB/s @ c12 is the best defensible read; the verdict above that is inconclusive
  until a larger `DEFEAT_TIB` re-run makes c24/c42 valid.
- **seq_write** — Falls just short of the *honest* (Sustained) spec: flat at
  82–86 GB/s across all four tiers, peaking at 98% of 87.5 GB/s at 42 nodes
  without crossing it. Against the Max line (165) it is only 52%. The flatness is
  the signature of a steady-state drain ceiling — adding clients does not move it.
- **rand_read** — 82% at 42 nodes and still climbing nearly linearly
  (21→35→61→82). **Client-limited**, not a storage wall — more client nodes would
  push it higher.
- **rand_write** — 56% of Max at 42 nodes and plateauing → **storage-limited
  below spec**. Does not meet spec on this path.

## Trend c06 → c42 (7× the nodes)

Total aggregate rises on every path except seq_write (essentially flat), but
**per-node efficiency falls on every path** — the signature of approaching a
shared backend ceiling:

| Per-node | c06 | c12 | c24 | c42 | c06→c42 aggregate gain |
|---|---|---|---|---|---|
| seq_read GB/s/node | 47.4 | 34.9 | 22.3 ⚠ | 13.9 ⚠ | 2.1× (tainted) |
| seq_write GB/s/node | 13.7 | 6.9 | 3.4 | 2.0 | 1.05× |
| rand_read kIOPS/node | 95.1 | 81.2 | 71.0 | 53.9 | 4.0× |
| rand_write kIOPS/node | 49.1 | 32.9 | 19.0 | 11.0 | 1.6× |

Ideal scaling would be 7×. Realized: rand_read 57%, seq_read ~29% (tainted),
rand_write 22%, seq_write 15%.

**Reading the trend:**

1. **Random read scales best; sequential write does not scale at all.** rand_read
   keeps ~57% scaling efficiency and is the only path still clearly rising at the
   top tier — small-block random reads spread across the CBOX/DBOX fabric and
   aren't yet contended. seq_write is the opposite: 82.0→83.1→82.5→85.9 GB/s is a
   flat line, so the aggregate is already at the backend drain rate by 6 nodes and
   extra clients just queue behind the same commit path.

2. **rand_write flattens toward ~56% of Max.** The per-tier gain shrinks each step
   (294.8→394.5→454.9→463.8; the c24→c42 step adds only ~9 kIOPS), so this path
   tops out around 56% of the 825 kIOPS Max — a genuine storage-side limit on this
   sweep, not a client shortfall.

3. **Reads go from clean to cache-tainted as nodes rise.** Valid cold through 12
   nodes (CI PASS), but c24/c42 exceed the 462 GB/s cold ceiling (534/584) and the
   CI gate FAILs both. The cache-defeat margin (`DEFEAT_TIB`) held to 12 nodes and
   broke at 24/42 — the real CBOX read cache is larger than the assumed headroom
   (and/or the higher-node runs finish the eviction phase fast enough that the read
   source isn't fully displaced). Fix: raise `DEFEAT_TIB` and re-run the c24/c42
   read tiers before trusting those read numbers — the write IOPS/BW at those tiers
   are unaffected.

## Bottom line

- This sweep **does not cleanly clear spec on any of the four paths.** seq_write
  asymptotes just under the honest sustained line (98% at 42 nodes); rand_write
  plateaus at 56% of Max (storage-limited); the only valid seq_read tier is 91%;
  rand_read is at 82% and still climbing.
- **rand_read** is the one path with clear headroom — **client-limited** (still
  rising near-linearly), so add client nodes to push it higher.
- The **seq_read c24/c42** cells are **inconclusive (cache leak)** — the CI gate
  FAILs both — and need a larger `DEFEAT_TIB` re-run; don't quote 534/584 GB/s.
- The **seq_write "Max 165"** line is a burst number; the steady-state product
  tracks the 87.5 GB/s sustained line but stops just short of it here (98%).
- Note vs the prior sweep (`spec-1`, run `specval_1779653518`): per-node output at
  c06 is comparable, but this run scales far worse — seq_write here is flat
  (1.05×) where spec-1 reached 119 GB/s / 136% of sustained, and rand_write here
  plateaus at 56% where spec-1 hit 114%. If both used the same client config,
  this points to a lower backend ceiling / more contention in this run; worth
  confirming the runs are comparable before drawing product conclusions.
