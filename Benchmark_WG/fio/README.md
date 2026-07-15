# Cold-Floor Read Campaign — User Guide

Measures the **cold read floor** of the storage product with reads that are
cold **by construction**, plus a vendor-methodology ask that decides which
number is the fair comparison to the Vast spec.

Third harness in this repo — fully separate from the other two (do not merge):

- `peak_aggregate_*` (see `README.md-peak_aggregate`) — chases the highest
  aggregate number; reads end up cache-served.
- `spec_validate_*` (see `README.md-spec_validate`) — fair sustained/honest
  methodology, but makes reads cold by **eviction** (`DEFEAT_TIB`), which is
  unprovable on VAST: writes land in the SCM write buffer and do not evict the
  read cache, and its `VERIFY_COLD` gate is one-sided (passing proves "not
  above the ceiling", not "cold"). 15+ runs could not certify coldness.
- `coldfloor_*` (this guide) — replaces eviction with **construction**: a read
  cache can only hold blocks that were previously read or recently written, so
  an **aged, never-read** region cannot be cache-resident. No `DEFEAT_TIB`.

| file | role |
|---|---|
| `coldfloor_layout_fio.sh` | PHASE A: write per-tier virgin read regions; never reads them |
| `coldfloor_measure_fio.sh` | PHASE B (per tier): aged single-pass cold reads + warm control |
| `submit_coldfloor.sh` | orchestrates A → aged → B per tier, tiers chained, partitions handled |
| `coldfloor_summary.py` | two-sided verdict: warm-fraction from latency, raw + cold-floor numbers |
| `jobs/coldfloor_seq_read.fio` | 1 MiB streaming read, `loops=1` single pass, latency-histogram logs |
| `jobs/coldfloor_rand_read.fio` | 4 KiB LFSR random read — every block at most once, never re-warms itself |
| `vendor_methodology_questions.md` | Scheme-6 ask to Vast — decides cold vs cache-inclusive comparison |

## Quick start

```bash
./submit_coldfloor.sh                     # defaults: TIERS="12 42", AGE_HOURS=12
# ... prints CAMPAIGN=cf_<epoch>; layout runs (~2 h on 42 nodes),
#     measure tiers start >= 12 h after submission, chained per tier ...
python coldfloor_summary.py <CAMPAIGN>    # raw + cold-floor numbers, verdicts
```

In parallel (it decides what the result *means* — see "Comparing to the spec"):
send `vendor_methodology_questions.md` to the Vast contact.

Common variants:

```bash
TIERS="42" AGE_HOURS=24 ./submit_coldfloor.sh    # top tier only, longer aging
CAMPAIGN=jun_floor ./submit_coldfloor.sh         # name the campaign yourself
WINDOW_S=300 ./submit_coldfloor.sh               # longer seq measurement window (bigger regions)
```

## How it works

**Phase A — layout** (`coldfloor_layout_fio.sh`, one array sized for the
largest tier). Writes one region per (tier, direction, logical node-slot):

```
/work/.../coldfloor_<CAMPAIGN>/tier_c42/seq/node_007/fio.seq.<job>.<file>
/work/.../coldfloor_<CAMPAIGN>/tier_c42/rand/node_007/fio.rand.<job>
```

Slots are **logical** (`node_000`…), not hostnames — the measure job lands on
different physical nodes and maps rank → slot by `TASK_ID*NODES_PER +
SLURM_PROCID`. Each slot gets a `.DONE` epoch stamp when fully written
(`end_fsync=1`). Task 0 writes `manifest.env` recording the exact sizing, which
the measure job sources — the two phases can never disagree about file layout.
Nothing in Phase A ever reads the regions.

**Aging gap (Scheme 2).** Measure jobs are submitted with
`--begin=now+AGE_HOURS` (default 12 h, counted from submission) AND
`afterok` on the layout. The measure job re-verifies the true age from the
`.DONE` stamps (`MIN_AGE_H`, default 6 h) and **aborts** if too young — a slow
layout cannot silently shrink the age. Aging lets any write-path residue from
the layout drain server-side.

**Phase B — measure** (`coldfloor_measure_fio.sh`, one array per tier):

1. `seq_read` — single pass (`loops=1`, `time_based=0`) over the aged virgin
   region. Client cache killed as always (`direct=1 + invalidate=1 +
   fadvise_hint=1`).
2. `rand_read` — `random_generator=lfsr` single pass: every 4 KiB block at
   most once, in pseudo-random order. Unlike the `time_based` loop in
   spec_validate, it can never re-read (re-warm) its own blocks mid-run.
3. **warm control** (task 0, last, so it can't pre-warm the server or skew
   phase starts) — writes a small (~96 GiB) set, reads it back twice at both
   1 MiB and 4 KiB; the second pass defines the WARM latency mode.

Guards: a tier region carries a `.CONSUMED` marker after any measure run —
a second run against the same region **aborts** (a re-read is warm by
definition). On success the region is deleted (`CLEANUP_REGION=1`); lay out a
fresh campaign for the next measurement.

**Verification (Scheme 4) — two-sided, in `coldfloor_summary.py`.** For each
direction it estimates the **warm fraction**: completions at/below the warm
threshold (warm-control p99 × 1.5), interpolated from the fio JSON latency
percentiles (full histograms are in `*_clat_hist*.log` for deeper analysis).
Unlike the old one-sided 462-ceiling gate, this can both **convict** (warm
fraction high) and **acquit** (≈0% warm with clean mode separation):

```
=== tier c42  (results-peak/coldfloor_cf_..._c42)  min region age: 13 h ===
  seq_read   raw    xxx.x GB/s  ( xx.x% of spec 462)   [42 nodes]
             warm threshold 450 us (warm-control p99 x 1.5)
             warm fraction ~0.31%   cold floor xxx.x GB/s ( xx.x% of spec)
             VERDICT: cold-verified — virgin construction + ~zero warm-mode completions.
```

The **cold floor** = raw × (1 − warm fraction), slightly conservative. A
`WARN ... modes overlap` line means the classifier can't separate warm from
cold latencies — inspect the histogram logs before quoting anything.

## Comparing to the spec (read this before quoting numbers)

The cold floor is a defensible **lower bound** on the product's read
performance under any interpretation. Whether it is *the* spec-comparable
number depends on §1 of `vendor_methodology_questions.md`:

- Vast measured **cold** → the cold floor is the apples-to-apples number.
- Vast measured **cache-inclusive** → the cold floor understates; bracket
  instead: "cold floor X GB/s, cache-assisted Y GB/s (peak harness), vendor
  spec 462 sits here."

Writes are *not* re-measured here — `spec_validate_*` already measures them
fairly (900 s sustained + `end_fsync=1`; ~86 GB/s ≈ 98% of the 87.5 GB/s
Sustained line at c42).

## Key tunables

Env vars before `./submit_coldfloor.sh` (forwarded to both phases):

| var | default | meaning |
|---|---|---|
| `TIERS` | `12 42` | client-node counts to measure (even; 2 nodes/array task) |
| `AGE_HOURS` | `12` | sbatch `--begin` delay for measure jobs (from submission) |
| `MIN_AGE_H` | `6` | hard age floor verified from `.DONE` stamps; abort if younger |
| `ENFORCE_AGE` | `1` | 0 = age warning only (result then carries a caveat) |
| `WINDOW_S` | `240` | target seq measurement window (sizes the regions) |
| `EXP_GBPS_<n>` | per-tier table | expected cold GB/s for tier *n*, used for sizing. **Over**-estimate = bigger region = longer window (safe); under-estimate truncates the window. Defaults: c06 300, c12 440, c24 550, c42 620. |
| `SAFETY_PCT` | `130` | sizing margin on top of `EXP_GBPS` |
| `RAND_GIB_PER_WORKER` | `8` | rand region per fio worker (8 GiB ≈ outlasts the 900 s cap) |
| `NUMJOBS` | `96` | fio workers per node = cores; must match between layout and measure (manifest enforces) |
| `CLEANUP_REGION` | `1` | delete a tier's region after successful measurement (it is no longer virgin) |
| `CAMPAIGN` | `cf_<epoch>` | campaign tag tying layout, measure, and results together |
| `LAYOUT_TIME` / `MEASURE_TIME` | `12:00:00` / `08:00:00` | Slurm walls per phase |

Engine selection is the same fair probe as spec_validate (`io_uring → libaio →
pvsync2`, abort rather than posixaio); on this cluster `pvsync2` is selected
(io_uring kernel-disabled, libaio absent).

## Cost & caveats

- **Space:** defaults (`TIERS="12 42"`, `WINDOW_S=240`) ≈ **330 TiB** on
  `/work` between layout and measure. Freed per tier after a successful
  measure. `TIERS="42"` alone ≈ 200 TiB.
- **Time:** layout ~2 h on 42 nodes; each measure tier ~1–2 h; first results
  ≥ `AGE_HOURS` after submission. The aging gap is the price of provable
  coldness — don't shrink it to save walltime.
- **One shot per region.** Once measured, a region is consumed. Re-measuring
  requires a fresh layout (new campaign). This is by design.
- **Node mix:** >24-node tiers span `b200-batch` + `rtx-batch` (26 + 16 pool),
  like the other harnesses.
- **Aggregate-of-N-clients:** same caveat as always — report as "sustained by
  N client nodes" unless the vendor fleet is known (vendor doc §2).

## Vast spec reference

AICR proposal, 16 × 7 Gen5 / Ceres 1350 — measurement regime **unverified**
(that's what `vendor_methodology_questions.md` is for):

| metric | spec |
|---|---|
| Max Read | 462 GB/s |
| Max Write | 165 GB/s |
| Sustained Write | 87.5 GB/s |
| Read IOPS | 2,775 k |
| Write IOPS | 825 k |
