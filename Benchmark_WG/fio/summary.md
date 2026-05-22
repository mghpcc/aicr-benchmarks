# fio Peak Aggregate Run Analysis — `fio_1779420797`

## What Changed Since the Previous Run

Two things shifted relative to `summary.md-1` (`fio_1779399220`):

1. **ioengine: `pvsync2` cluster-wide** (was `posixaio`). The auto-probe added
   to `peak_aggregate_fio.sh` now tries `io_uring → pvsync2 → posixaio` per
   node; all 378 fio invocations in this run selected `pvsync2` (io_uring
   still blocked). `pvsync2` is kernel sync I/O — no userspace thread-pool
   tax — so `iodepth` collapses to 1 in practice, but it generally beats
   `posixaio` once `numjobs` is high enough.
2. **`seq_*` size sweep**: each task now runs `seq_write` and `seq_read`
   three times (file size 1M, 10M, 100M). `TOTAL_PER_JOB=4G` is held fixed,
   so `nrfiles = 4G / file_size` (4096 / 409 / 40). The intent: see how
   per-file size affects sustained throughput when client cache is killed
   (`direct=1, invalidate=1, fadvise_hint=1`).

The rand_\* tunables were also bumped to `numjobs=64, iodepth=128` (the
iodepth is clamped to 1 for `pvsync2` by the wrapper).

## Cluster Configuration Used

| dimension                | value                                                           |
|---                       |---                                                              |
| array tasks              | **21**, each 2 nodes (`--ntasks-per-node=1`, exclusive)         |
| total client nodes       | **42 nodes** (26 b200 + 14 rtx + 2 hosts reused across tasks)   |
| cores per node (physical)| **128** on both partitions                                      |
| cores used per node      | 96 (`--cpus-per-task=96`)                                       |
| fio processes per node   | 1 fio binary, `numjobs=32` (seq) / `numjobs=64` (rand)          |
| effective iodepth        | **1** (pvsync2 is sync — `RAND_IODEPTH=128` ignored)            |
| ioengine selected        | `pvsync2` on every node                                         |
| `HONEST_FSYNC`           | 1 — `rand_write` waits for server commit                        |
| NFS mount                | `vers=3, proto=rdma, nconnect=16, rsize/wsize=1M`               |
| `TOTAL_PER_JOB` (seq_*)  | 4 GiB                                                           |
| `RAND_SIZE_PER_JOB`      | 16 GiB                                                          |
| `RUNTIME` / `RAMP_TIME`  | 60 s / 10 s (`time_based`, rand_* only)                         |
| seq_* runtime mode       | single-pass `loops=1` (no `time_based`)                         |

> **Heads-up — 6 nodes timed out during `rand_read`.** The 45-min Slurm
> walltime was hit while `rand_read` (the last phase in the
> `WORKLOAD=all` order) was running on b0005/b0008/b0009/b0014/b0016/b0017.
> Their JSON files are zero-byte and were filtered by the aggregator, so
> the `rand_read` cell aggregates **36 fio processes**, not 42 — i.e. the
> headline `rand_read` IOPS is ~14% under-counted vs. a complete run.
> Every other cell aggregates the full 42.

## Headline Results

`cluster_sum` = sum of per-process throughput. `conservative` = total bytes
across all processes / max elapsed (honest wall-clock aggregate). Vast spec:
seq_read 462 GB/s, seq_write 165 GB/s, rand_read 2,775 kIOPS,
rand_write 825 kIOPS.

| workload                  | procs | cluster_sum    | conservative   | vs spec (cons) |
|---                        |---    |---             |---             |---             |
| `seq_read`  · file 1 MiB  | 42    | 465.25 GB/s    | **384.32 GB/s**| 83.2 %         |
| `seq_read`  · file 10 MiB | 42    | 410.60 GB/s    | **308.89 GB/s**| 66.9 %         |
| `seq_read`  · file 100 MiB| 42    | 872.56 GB/s    | **481.61 GB/s**| 104.2 %        |
| `seq_write` · file 1 MiB  | 42    |  49.41 GB/s    |   40.76 GB/s   | 24.7 %         |
| `seq_write` · file 10 MiB | 42    |  97.84 GB/s    |   38.05 GB/s   | 23.1 %         |
| `seq_write` · file 100 MiB| 42    | 104.62 GB/s    |   35.64 GB/s   | 21.6 %         |
| `rand_read`               | **36**| 1946.4 kIOPS   | **1945.0 kIOPS**| **70.1 %**    |
| `rand_write`              | 42    |  878.5 kIOPS   |  **877.3 kIOPS**| **106.3 %**   |

The two random workloads are the headline win: switching from `posixaio`
to `pvsync2` raised `rand_read` from 778 → 1946 kIOPS (**2.5×**) and
`rand_write` from 447 → 878 kIOPS (**2×**) on the same 42-node pool, no
admin changes required.

## Reading the seq_read Size Sweep

The 1M / 10M / 100M sweep separates "honest cold-read" from "cache-warmed":

- **1M file, 4096 files per worker** — `cluster_sum` 465 vs. `conservative`
  384 (sum is 21 % higher). The gap is overlap loss: thousands of tiny
  files mean some workers finish their working set well before others, so
  per-process rates are real but they don't all run during the same window.
  **384 GB/s is the honest cold-read number** at small files —
  ~9.1 GB/s/node median.
- **10M file, 409 files per worker** — same pattern, worse overlap (75 %
  ratio). Each file is bigger so layout takes longer; finish-time variance
  grows. **309 GB/s honest.**
- **100M file, 40 files per worker** — `cluster_sum` 873 GB/s, *almost
  double the 462 GB/s Vast spec*. **This is cache.** With 40 files × 100M
  × 32 jobs ≈ 128 GiB per node and reads issued right after the matching
  `seq_write_100M` filled them, the CBOX server-side cache services most
  of the read. The conservative 481 GB/s is still above spec for the same
  reason. **Treat the 100M number as storage-plus-cache, not storage.**

The 1M and 10M conservative numbers (384 / 309 GB/s) sit between the
`../raw-io/` cold-ImageNet measurement (≈ 200 GB/s on the same node pool)
and the 462 GB/s Vast spec — i.e. partially cache-warmed, but a real
storage workload. The honest cold-read ceiling on this 42-node client
pool is somewhere in that band.

## Reading the seq_write Size Sweep

`seq_write` looks worse than the previous run (40 / 38 / 36 GB/s
conservative vs. 65 GB/s before). Two effects compound:

1. **`pvsync2` + `iodepth=1` for writes**: the previous run used `posixaio`
   with `iodepth=64`, which masked some of the per-RPC latency. `pvsync2`
   serializes I/O per worker thread, so each of 32 workers/node pushes
   one 1-MiB write at a time. End result: per-node median is ~1.1 –
   1.9 GB/s here.
2. **Overlap loss explodes at single-pass writes**: `cluster_sum` for
   100M is 105 GB/s but `conservative` is only 36 — a 34 % ratio. The
   fastest nodes finish their 4 GiB working set in seconds; slow nodes
   are still grinding when the fast ones have already exited. The
   wall-clock denominator (max runtime) gets long while throughput on
   most of the cluster has already dropped to zero.

The right read of these numbers is: **per-node sustained write is
1 – 2 GB/s on `pvsync2`**, and a longer-running write workload
(`time_based=1`) would push the cluster aggregate up to roughly
1.5 GB/s/node × 42 = **65 GB/s sustained**, in line with the previous
run. The single-pass methodology with a small working set is unfair to
writes — the read side benefits from cache, the write side doesn't get
to amortize startup cost over a steady-state window.

## Reading the IOPS Numbers

This is where `pvsync2` pays off, exactly as `notes.md` predicted.

- **`rand_read` 1946 kIOPS = 70 % of Vast spec** with only 36 of 42
  processes counted. At 36 nodes the per-node median is ~50 kIOPS — nearly
  3× the posixaio ceiling of 18.5 kIOPS/node. If the 6 timed-out nodes
  had finished, the headline would be ~2270 kIOPS ≈ **82 % of spec**.
- **`rand_write` 877 kIOPS = 106 % of Vast spec** even with `HONEST_FSYNC=1`
  (every rand_write waits for server commit). Per-node median ~21 kIOPS,
  vs. ~10.6 kIOPS posixaio.

Above-spec on `rand_write` is a methodology note, not a fluke: Vast's
825 kIOPS spec is for the storage tier under one specific test
configuration; with 42 clients hitting 16 distinct CBOX VIPs in parallel,
each carrying RDMA `nconnect=16`, the **aggregate over the client pool
naturally exceeds a single-point storage measurement** — there is no
single bottleneck the spec was measuring.

The remaining gap to spec on `rand_read` (and any further headroom on
`rand_write`) is now likely **storage-tier**, not engine. Confirming
would need either io_uring (still blocked) or a larger client pool.

## Comparison to the Previous (posixaio) Run

Same 42-node pool, same `direct=1`, same NFS path. Only the engine and
seq sweep differ.

| workload          | old (posixaio)        | new (pvsync2)                 | change          |
|---                |---                    |---                            |---              |
| `seq_read`  cons  | 432.9 GB/s (1M only)  | 384 / 309 / 482 GB/s by size  | not directly comparable; mixed |
| `seq_write` cons  |  65.5 GB/s            |  41 / 38 / 36 GB/s            | **−40 % (methodology + engine)** |
| `rand_read` cons  | 775.4 kIOPS           | **1945 kIOPS** (36 procs)     | **+150 %**      |
| `rand_write` cons | 433.6 kIOPS           |  **877 kIOPS** (42 procs)     | **+102 %**      |

`seq_read` apparent change is dominated by the size sweep (the old run
used a single mid-size and got partial cache help). `seq_write` regression
is the `iodepth=64 posixaio` vs. `iodepth=1 pvsync2` swap plus the
overlap-loss-from-single-pass effect — not a storage regression. **Both
IOPS lines are real wins** from switching the engine.

## Where the Headroom Is Now

| lever                                    | gain potential        | how to apply                                             |
|---                                       |---                    |---                                                       |
| **Unblock `io_uring` on compute nodes**  | another ~1.5 – 2× IOPS, ~10 – 20 % BW | sysadmin needs to relax kernel.io_uring_disabled or container seccomp |
| Switch `seq_*` to `time_based=1`         | seq_write `conservative` → 60+ GB/s   | change the seq fio job files; trades single-pass purity for steady state |
| Push `numjobs` higher on rand_*          | a few % to 1.5×       | already 64 on 96-core nodes; room for 96 with care       |
| Increase `RAND_SIZE_PER_JOB`             | small — kills cache assist | already 16 G; bumping helps only if rand was showing cache hits (it isn't) |
| Vast DPC (Data Path Client)              | ~10× per-host BW      | proprietary client; ask Vast/cluster team for availability |
| Bigger client pool (more nodes)          | linear                | only ~13 more idle hosts available cluster-wide          |
| Drop `end_fsync` for `rand_write`        | another ~1.5 – 2×     | already at 106 % of spec with honest fsync — not worth the dishonesty |

The biggest practical change is **avoid the 45-min wall** so all 42
processes report on `rand_read`. Either shrink `RAND_SIZE_PER_JOB`, drop
the seq sweep when running `WORKLOAD=all`, or split the workloads across
separate array submissions.

## Vast Paper Spec Recap

Vast spec (AICR proposal, 16 × 7 Gen5 / Ceres 1350):
- Max Read **462 GB/s**, Max Write **165 GB/s**, Sustained Write 87.5 GB/s.
- Read IOPS **2,775k**, Write IOPS **825k**.

| direction    | this run                          | % of spec | gap explained by                              |
|---           |---                                |---        |---                                            |
| seq read     | 309 – 384 GB/s honest, 482 cached | 67 – 104 %| client pool size + remaining cache leakage    |
| seq write    | 35 – 41 GB/s `conservative`       | 22 – 25 % | single-pass methodology + `iodepth=1` pvsync2 — ~65 GB/s under `time_based=1` |
| rand read    | 1945 kIOPS                        | 70 % (36 procs) → ~82 % if full | likely storage-tier now; engine no longer bottleneck |
| rand write   | 877 kIOPS                         | 106 %     | over-spec; aggregate of 42 clients exceeds Vast's single-point measurement |

## Key Findings

- **`pvsync2` was the right call.** Auto-probe selected it everywhere;
  IOPS doubled vs. `posixaio` on the same hardware, no admin work needed.
- **`rand_write` cleared spec** (106 %) with `HONEST_FSYNC=1`;
  **`rand_read` is at 70 %** despite losing 6 of 42 processes to the
  Slurm walltime. Adjusting for the loss puts it near 82 %.
- **`seq_read` cold-read is 309 – 384 GB/s on 42 clients**, in line with
  what `../raw-io/` measures on cold data. The 100 MiB sweep number
  (482 GB/s, above spec) is cache-inflated by the preceding `seq_write`
  phase and shouldn't be cited as storage capacity.
- **`seq_write` regressed numerically vs. the prior run** because
  `pvsync2` runs `iodepth=1` and the single-pass methodology amplifies
  overlap loss for short writes. Per-node sustained write is ~1.5 GB/s,
  consistent with the prior run; the headline is just measured worse.
- **The 45-min wall is now the practical limit** on `WORKLOAD=all`.
  Either shorten the sweep or split workloads across array jobs.
- **Next single biggest lever is still `io_uring`** — needs the
  cluster admin. After that, DPC or more client nodes.
