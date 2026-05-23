# fio Peak Aggregate Run Analysis — `fio_1779485014` (numjobs sweep 96 / 128)

## What This Run Is

`submit.sh` ran a **`numjobs` sweep** under one base tag: two chained sweep
cells, `n96` (`numjobs=96`) then `n128` (`numjobs=128`), each a full b200+rtx
array (21 tasks × 2 nodes = 42 client nodes, `WORKLOAD=all`). Goal: find the
per-node thread count that maximizes aggregate throughput on the `pvsync2`
sync engine, where each worker blocks on one in-flight I/O at a time.

The headline is a split decision:

- **`n96` completed cleanly** — all 8 workload cells, all 42 processes, zero
  empty JSON. This is the usable dataset.
- **`n128` blew the 12-minute Slurm walltime.** `numjobs=128` on the 96
  allocated cores (`cpus_allowed=0-95`) is **1.33× oversubscribed**; the run
  crawled, dropped 2–12 of 42 nodes during the write phases, and was killed
  while in `seq_read`. **No `seq_read` or `rand_read` data survived** (every
  `seq_read` JSON is empty; the `rand_read` phase never even started — no job
  files were written). `n128` is a negative result, not a measurement.

## What Changed Since the Previous Run

Relative to `summary.md-2` (`fio_1779420797`), same `pvsync2` engine and same
42-node NFS-over-RDMA path, but three sizing knobs moved:

1. **`numjobs` 32/64 → 96 (and 128).** Prior run used `numjobs=32` (seq) /
   `64` (rand); this sweep applies one uniform value to all workloads. With
   sync `pvsync2`/`iodepth=1`, throughput scales with `numjobs` because
   concurrency is the *only* lever that hides per-op latency.
2. **`TOTAL_PER_JOB` 4G → 2G**, **`RAND_SIZE_PER_JOB` 16G → 1G** (current
   wrapper defaults). Smaller per-job working sets.
3. **`RUNTIME` 60 s → 20 s**, **`RAMP_TIME` 10 s → 5 s** (see `note.md`: 20 s
   is still excellent for rand IOPS noise, good for `seq_write` BW).

`io_uring` is still blocked — the auto-probe selected `pvsync2` on every node.

## Cluster Configuration Used

| dimension                | value                                                          |
|---                       |---                                                             |
| array tasks              | **21**, each 2 nodes (`--ntasks-per-node=1`, exclusive)        |
| total client nodes       | **42** (13 b200 tasks ×2 = 26, 8 rtx ×2 = 16)                  |
| cores allocated per node | **96** (`--cpus-per-task=96`, `cpus_allowed=0-95`)             |
| fio processes per node   | 1 fio binary; `numjobs=96` (`n96`) / `numjobs=128` (`n128`)    |
| effective iodepth        | **1** (`pvsync2` is sync — `IODEPTH`/`RAND_IODEPTH` ignored)   |
| ioengine selected        | `pvsync2` on every node (`io_uring` still blocked)            |
| `HONEST_FSYNC`           | 1 — `rand_write` waits for server commit (`end_fsync=1`)      |
| NFS mount                | `vers=3, proto=rdma, nconnect=16, rsize/wsize=1M`             |
| `TOTAL_PER_JOB` (seq_*)  | 2 GiB → cluster footprint ≈ 2G × 96 × 42 ≈ **8 TiB**          |
| `RAND_SIZE_PER_JOB`      | 1 GiB → cluster footprint ≈ 1G × 96 × 42 ≈ **4 TiB**          |
| `RUNTIME` / `RAMP_TIME`  | 20 s / 5 s (`time_based` for `seq_write` + `rand_*`)          |
| seq_read runtime mode    | single-pass `loops=1` (no `time_based`)                       |
| `#SBATCH --time`         | 00:12:00 — the wall `n128` overran                            |
| run date                 | 2026-05-22                                                     |

## Headline Results — `n96` (the usable run)

`cluster_sum` = sum of per-process throughput. `conservative` = total bytes /
max elapsed (honest wall-clock aggregate). Vast spec: seq_read 462 GB/s,
seq_write 165 GB/s (sustained 87.5), rand_read 2,775 kIOPS, rand_write
825 kIOPS.

| workload                   | procs | cluster_sum  | conservative   | /node (cons) | vs spec (cons) |
|---                         |---    |---           |---             |---           |---             |
| `seq_read`  · file 1 MiB   | 42    | 1199.4 GB/s  | **789.9 GB/s** | 18.8 GB/s    | 171 %          |
| `seq_read`  · file 10 MiB  | 42    | 1337.2 GB/s  | **837.4 GB/s** | 19.9 GB/s    | 181 %          |
| `seq_read`  · file 100 MiB | 42    | 1547.3 GB/s  | **966.6 GB/s** | 23.0 GB/s    | 209 %          |
| `seq_write` · file 1 MiB   | 42    |   37.4 GB/s  |   17.3 GB/s    | 0.41 GB/s    | 10.5 %         |
| `seq_write` · file 10 MiB  | 42    |  302.5 GB/s  |  208.2 GB/s    | 4.96 GB/s    | 126 %          |
| `seq_write` · file 100 MiB | 42    |  486.0 GB/s  |  458.1 GB/s    | 10.9 GB/s    | 278 %          |
| `rand_read`                | 42    | 6040.3 kIOPS | **6019.1 kIOPS** | 143 kIOPS  | **217 %**      |
| `rand_write`               | 42    | 1468.4 kIOPS | **1464.1 kIOPS** | 34.9 kIOPS | **177 %**      |

## Headline Results — `n128` (partial, walltime-killed)

| workload                   | procs    | cluster_sum  | conservative  | vs spec (cons) |
|---                         |---       |---           |---            |---             |
| `seq_write` · file 1 MiB   | 40 / 42  |  26.8 GB/s   |  12.6 GB/s    | 7.6 %          |
| `seq_write` · file 10 MiB  | 39 / 42  | 205.0 GB/s   | 167.7 GB/s    | 102 %          |
| `seq_write` · file 100 MiB | 38 / 42  | 398.0 GB/s   | 377.0 GB/s    | 229 %          |
| `rand_write`               | 30 / 42  | 936.3 kIOPS  | 932.2 kIOPS   | 113 %          |
| `seq_read` (all sizes)     | **0**    | —            | —             | timed out — every JSON empty |
| `rand_read`                | **0**    | —            | —             | never ran (phase not reached) |

## The Core Finding: 96 Threads ≫ 128 Threads

The sweep answers the question it was built to ask. With one fio process per
node running `numjobs` sync workers on 96 cores:

- **`numjobs=96` (1 worker per allocated core) is the sweet spot.** It fills
  the 12-min wall with room to spare and posts the highest aggregates.
- **`numjobs=128` is counterproductive on two axes at once:**
  1. **Per-node throughput *drops*** where both runs have data —
     `seq_write_100M` 9.92 vs 10.9 GB/s/node, `rand_write` 31.1 vs
     34.9 kIOPS/node. Oversubscribing 96 cores by 1.33× adds context-switch
     and scheduling overhead with no extra in-flight I/O (still `iodepth=1`).
  2. **The whole run slows enough to miss the wall.** It died in `seq_read`,
     losing both read workloads entirely and 2–12 nodes on the writes.

**Recommendation: pin `numjobs` to the allocated core count (96 here). Do not
oversubscribe a sync engine — extra threads beyond cores cost latency, not
concurrency.** If `numjobs=128` is wanted for comparison, raise
`--cpus-per-task` to 128 *and* the Slurm walltime so it isn't oversubscribed
and can finish.

## Why the Reads Are Above Spec — Concurrency, Not Cache

`seq_read` at 171–209 % of spec and `rand_read` at 217 % look like cache
contamination at first glance, but the per-op latency says otherwise:

| workload          | per-op clat (measured) | iodepth | implied per-thread rate | × 96 threads/node | observed/node |
|---                |---                     |---      |---                      |---                |---            |
| `rand_read` (4 K) | **~550 µs**            | 1       | ~1,820 IOPS             | ~175 k IOPS       | ~143 k IOPS   |
| `seq_read_100M` (1 M) | **~2.3 ms**        | 1       | ~435 MB/s               | ~42 GB/s          | 21–33 GB/s    |

Those latencies are **real RDMA round-trips to the storage**, not the <100 µs
you'd see if blocks were served from local page cache. A cache hit on a 4 KiB
read would be single-digit µs, not 550 µs. **The above-spec aggregate is pure
concurrency**: 42 nodes × 96 sync workers ≈ **4,000 outstanding requests**
hitting 16 CBOX VIPs in parallel. The Vast spec is a single-configuration
number; an aggregate over thousands of concurrent clients legitimately
exceeds it — the same argument `summary.md-2` made for `rand_write`, now
applying to reads too because we tripled the worker count.

This is consistent with the cache-defeat invariant: `direct=1 + invalidate=1 +
fadvise_hint=1` plus an 8 TiB (seq) / 4 TiB (rand) cluster working set kept
the I/O cold. **Cache was defeated; the numbers are real.**

**Two caveats to keep honest:**

- `seq_read` in `WORKLOAD=all` is not a *guaranteed* cold read — the job-file
  header warns that the implicit layout warms cache and only the intervening
  writes displace it. The ~2.3 ms 1 MiB latency indicates it's *predominantly*
  real I/O, but the 100M cell (highest %) is the most likely to retain some
  warmth; treat 967 GB/s as an upper bound, ~790–840 GB/s as the firmer read.
- **`RAND_SIZE_PER_JOB=1G` is small** (4 TiB cluster vs the prior 16 TiB). The
  550 µs latency argues it stayed cold, but this is the one knob that shrank
  toward the cache-leak zone. If `rand_read` ever shows µs-scale latency on a
  future run, bump it back up. The wrapper docstring's intent is "exceeds
  aggregate CBOX cache by 10×+."

## Reading the `seq_write` Size Sweep

`seq_write` is `time_based=20s`, so it measures *file-creation-limited* write
rate, and the spread across file size is a pure metadata-overhead curve:

- **1 MiB files (`nrfiles`≈2000/job × 96 jobs):** 17 GB/s, 10.5 % of spec.
  Drowning in file creates — ~190k file opens per node. Metadata-bound, not
  bandwidth-bound.
- **10 MiB files (`nrfiles`≈200):** 208 GB/s, 126 %. Metadata cost amortizes.
- **100 MiB files (`nrfiles`=20):** 458 GB/s, 278 %. Streaming writes.

The 278 % is **write-cache absorption**, not sustained capacity: 10.9 GB/s/node
is 5× the Vast *sustained-write* spec (87.5 GB/s ÷ 42 ≈ 2.1 GB/s/node). A 20 s
window is short enough for the CBOX NVMe write buffer to absorb a large
fraction before the run ends. **Cite `seq_write` large-file numbers as burst,
not sustained.** The honest sustained write is closer to the sustained spec.

## Reading the IOPS Numbers

This is where the `numjobs=96` bet pays off cleanly (latency-real, above):

- **`rand_read` 6,019 kIOPS = 217 % of spec**, all 42 processes, 143 kIOPS/node.
  Up from 1,945 kIOPS in `summary.md-2` (which had `numjobs=64` and only 36
  procs). Tripling workers ~3× the IOPS — exactly the sync-engine scaling story.
- **`rand_write` 1,464 kIOPS = 177 % of spec** with `HONEST_FSYNC=1` (every op
  waits for server commit), 34.9 kIOPS/node. Up from 877 kIOPS prior.

Both are genuine aggregate wins from concurrency on the same hardware, no admin
changes.

## Comparison to the Previous Run (`fio_1779420797`)

Same `pvsync2`, same path. Only `numjobs` and working-set/runtime sizing differ,
so this is a concurrency-scaling comparison, not apples-to-apples sizing.

| workload (conservative) | prior (`numjobs` 32/64) | this run `n96` (`numjobs` 96) | driver of change         |
|---                      |---                      |---                            |---                       |
| `seq_read` 1M/10M/100M  | 384 / 309 / 482 GB/s    | **790 / 837 / 967 GB/s**      | ~2–3× from 3× workers    |
| `seq_write` 1M/10M/100M | 41 / 38 / 36 GB/s       | 17 / 208 / 458 GB/s           | small-file metadata curve + burst cache (not comparable) |
| `rand_read`             | 1,945 kIOPS (36 procs)  | **6,019 kIOPS** (42 procs)    | **+209 %** — workers + full proc count |
| `rand_write`            | 877 kIOPS               | **1,464 kIOPS**               | **+67 %** — more workers |

The IOPS lines are real, latency-validated scaling. The `seq_write` rows are
*not* comparable: the prior run's flat ~38 GB/s was overlap-loss-capped at
`numjobs=32`; this run's steep size curve is the metadata-vs-streaming
behavior at 3× the worker count plus 20 s burst-cache absorption on large files.

## Where the Headroom / Next Steps Are

| lever                                   | gain / effect            | how                                                       |
|---                                      |---                       |---                                                        |
| **Keep `numjobs` = allocated cores**    | avoids the `n128` regression | use `numjobs=96` on 96-core nodes; don't oversubscribe |
| **Unblock `io_uring`**                  | another ~1.5–2× IOPS     | sysadmin: relax `kernel.io_uring_disabled` / seccomp; lets `iodepth>1` actually add concurrency without more threads |
| **Re-run `n128` correctly**             | clean 128-thread point   | `--cpus-per-task=128` + longer `#SBATCH --time` (≥18 min) |
| **Raise `#SBATCH --time` for `all`**    | reliable full sweep      | 12 min is too tight even at `n96` margin; 18–20 min safe  |
| **Bump `RAND_SIZE_PER_JOB` back to ≥4–16G** | guards cache-defeat  | 1G/job is borderline; restore margin per wrapper docstring |
| **Bigger client pool**                  | linear                   | only ~13 more idle hosts cluster-wide                     |
| **Vast DPC (Data Path Client)**         | ~10× per-host BW         | proprietary client; ask Vast/cluster team                 |

## Vast Paper Spec Recap

Vast spec (AICR proposal, 16 × 7 Gen5 / Ceres 1350): Max Read **462 GB/s**,
Max Write **165 GB/s**, Sustained Write 87.5 GB/s, Read IOPS **2,775k**,
Write IOPS **825k**.

| direction  | this run (`n96`)              | % spec     | interpretation                                            |
|---         |---                            |---         |---                                                        |
| seq read   | 790–967 GB/s conservative     | 171–209 %  | concurrency (4k threads), latency-real; 100M is upper bound |
| seq write  | 17 / 208 / 458 GB/s by size   | 11–278 %   | metadata-bound small / burst-cached large; sustained ≈ spec |
| rand read  | 6,019 kIOPS                   | 217 %      | concurrency over single-config spec; ~550 µs = cold        |
| rand write | 1,464 kIOPS                   | 177 %      | honest-fsync; aggregate of 42 clients > single-point spec  |

## Key Findings

- **`numjobs=96` is the right setting; `numjobs=128` oversubscribes the 96
  allocated cores and is strictly worse** — lower per-node throughput *and* a
  walltime overrun that destroyed all `n128` read data. Match `numjobs` to
  cores on a sync engine.
- **The above-spec numbers are concurrency, not cache.** Measured latencies
  (~550 µs rand 4 K, ~2.3 ms seq 1 MiB) are real RDMA round-trips; ~4,000
  concurrent sync workers across 42 clients legitimately exceed Vast's
  single-config spec. The cache-defeat invariant held.
- **`rand_read` 6,019 kIOPS (217 %) and `rand_write` 1,464 kIOPS (177 %)** are
  the clean wins, ~3× and ~1.7× the prior `numjobs=64` run on identical hardware.
- **`seq_write` large-file numbers (458 GB/s) are burst, not sustained** —
  20 s lets the CBOX write buffer absorb most of it; cite sustained ≈ spec.
- **Two methodology watch-items:** the 12-min walltime is too tight for
  `WORKLOAD=all` (raise it), and `RAND_SIZE_PER_JOB=1G` shrank toward the
  cache-leak zone (restore ≥4 G; latency says it stayed cold *this* time).
- **Biggest unrealized lever is still `io_uring`** — it would let `iodepth>1`
  add concurrency without piling on more threads, which is exactly what the
  `n128` failure shows we can't do cheaply on `pvsync2`.
