# Fair Storage Spec Validation — User Guide

Three scripts that measure whether the storage product actually delivers the
vendor-quoted throughput / IOPS, under a **fair** comparison (cold, sustained,
streaming, honest). Separate from the `peak_aggregate_*` suite, which chases
the highest aggregate number and ends up reporting cache hits and write bursts
that exceed spec.

| file | role |
|---|---|
| `spec_validate_fio.sh` | per-tier fio runner with the fair methodology baked in |
| `submit_spec_validate.sh` | chained client-count scaling sweep (6→12→24→42 nodes) |
| `spec_validate_summary.py` | spec-aware readout: Max **and** Sustained lines, cache flags, storage- vs client-limited verdict |

## Quick start

Always probe the cache first, then size the sweep to it — `DEFEAT_TIB=128` is a
safe default but on small tiers it lays out 128 TiB per read source and can blow
past the wall clock. `--probe` submits a one-node measurement; read the
recommended `DEFEAT_TIB` from its output file and pass that to the real sweep,
which is typically far below 128 and finishes much faster. Finally read the
verdict with `--strict` so the summary exits non-zero on a cache leak (CI-gateable).

```bash
./submit_spec_validate.sh --probe                       # 1. measure cache (1 node); prints jobid
grep -i "Recommended DEFEAT_TIB" output-peak/specval_probe_a<JOBID>_t*.out   # read the number
DEFEAT_TIB=<rec> ./submit_spec_validate.sh              # 2. run the cold+fair sweep with it
python spec_validate_summary.py --strict results-peak/<BASE_TAG>   # 3. verdict (exit 2 on leak)
```

`submit_spec_validate.sh` prints `BASE_TAG` (e.g. `specval_1779999999`) and the
summary command when done. Cold (no cache) and spec-fairness are **enforced**:
the run fails if a read leaks cache or the fast engine is unavailable — details
below.

## What makes the comparison fair

The four things that made the old peak numbers unfair vs. spec, and how this
harness fixes each:

1. **Cold, measured + verified — not assumed.** `direct=1` only bypasses the
   *client* page cache; defeating the *server* CBOX cache needs working-set
   sizing. So: (a) `--probe` measures the real cache; (b) the cluster-wide
   working set is sized to `DEFEAT_TIB` (default **128 TiB**, raised from 32
   after 32 leaked at 24/42 nodes), held constant across tiers; (c) reads run
   only after two multi-TB write phases evict the sources; and (d) **`VERIFY_COLD`
   fails the run (exit 4)** if a cold `seq_read` still exceeds the physical cold
   ceiling — a cache hit aborts instead of being reported. Client cache is killed
   as always (`direct=1 + invalidate=1 + fadvise_hint=1`). See `node.md`.
2. **Sustained, not burst.** `time_based` writes run for `RUNTIME` (default
   **900 s = 15 min**) so the CBOX NVMe write buffer saturates and you measure
   the rate storage can hold — comparable to the vendor "sustained write" line.
3. **Streaming, not metadata.** seq_* uses large files (`FILE_SIZE`, default
   **1G**) so bandwidth isn't throttled by file-create RPCs (the small-file
   metadata trap that made seq_write read 11% of spec).
4. **Honest writes.** `end_fsync=1` (`HONEST_FSYNC=1`) — writes wait for server
   commit before the clock stops.
5. **Fair engine.** Uses `io_uring`/`libaio` (real async, `RAND_IODEPTH` default
   **64**) when available, else `pvsync2` (direct `preadv2`/`pwritev2` syscalls;
   concurrency from `numjobs`, iodepth clamps to 1). It **aborts (exit 3)**
   rather than fall back to `posixaio`, whose glibc thread pool caps random IOPS
   at the engine. On this cluster io_uring is kernel-disabled
   (`kernel.io_uring_disabled=2`) and libaio is absent, so `pvsync2` is selected.

The summary is also a **CI gate**: `spec_validate_summary.py` exits non-zero
(2 = cold read above its Max ceiling = cache leak; 3 = `--strict` read-over-spec)
so a build can fail on an untrustworthy run.

## Why a scaling sweep

A single full-pool run tells you *if* the product reaches spec but not *why* it
falls short. The sweep runs the same cold/sustained suite at increasing client
counts so you can distinguish:

- **STORAGE-limited** — throughput plateaus below spec as nodes increase ⇒ the
  product does not reach the quoted number on this access path.
- **CLIENT-limited** — throughput still rising at the full pool ⇒ you'd need
  more client nodes than you own; the spec likely assumes a bigger client fleet.

Tiers are separate `results-peak/<BASE>_c<NN>` dirs (NN = node count), chained
via `--dependency=afterany` so they never run concurrently (overlapping tiers
would contend for storage and corrupt every per-tier number).

## Reading the summary

```
=== rand_write  (kIOPS, cold/sustained) ===
   nodes  procs        kIOPS     %Max  note
       6     ...
      42     ...       ......   ...
  -> MEETS spec at 42 nodes (...% of Max).
```

- **%Max** compares to the vendor "max" line; for writes, **%Sustained** also
  compares to the 87.5 GB/s sustained line.
- A sequential read flagged **`CACHE?`** (conservative read > 462 GB/s Max
  ceiling) is *not* a valid cold number — its working set still fits server
  cache. Raise `DEFEAT_TIB` until the flag clears, then re-read.
- A random read above spec is soft-flagged: confirm it tracks the `rand_write`
  aggregate premium (random reads and writes should show a similar over-spec %
  if it's the genuine 42-client aggregate effect); if it's much higher, it's
  residual cache → raise `DEFEAT_TIB`.
- All numbers are **conservative** (honest wall-clock aggregate), never the
  optimistic `cluster_sum`.

## Key tunables

Set as env vars before `./submit_spec_validate.sh` (or on `spec_validate_fio.sh`
for a standalone run).

| var | default | meaning |
|---|---|---|
| `CLIENT_TIERS` | `6 12 24 42` | client-node counts to sweep (even numbers; 2 nodes/task) |
| `DEFEAT_TIB` | `128` | cluster working set per direction (TiB). Must exceed CBOX cache. Set to ~`CACHE_MULT`× the `--probe` result once known. |
| `CACHE_MULT` | `4` | working set must be ≥ this × the measured cache |
| `VERIFY_COLD` | `1` | 1 = **fail (exit 4)** if a cold read exceeds the cold ceiling; 0 = warn only |
| `RAND_IODEPTH` / `SEQ_IODEPTH` | `64` / `8` | queue depth per worker; random needs real depth to measure the device |
| `RUNTIME` | `900` | sustained-window seconds per `time_based` phase |
| `RAMP_TIME` | `60` | warm-up before measurement |
| `NUMJOBS` | `96` | fio workers per node = allocated cores. **Never** exceed cores — oversubscription regresses (see `summary.md` n128). `--cpus-per-task` is set to match. |
| `FILE_SIZE` | `1G` | per-file size for seq_* streaming |
| `HONEST_FSYNC` | `1` | 1 = wait for server commit; 0 = buffered (dishonest, don't use for validation) |
| `TIER_TIME` | `16:00:00` | Slurm `--time` per tier (size for the SLOWEST/smallest tier; partition cap 24:00:00) |
| `IOENGINE` | `auto` | `io_uring → libaio → pvsync2`, then **abort** (no posixaio fallback). `ALLOW_SLOW_ENGINE=1` permits posixaio (not spec-fair). |

## Cost & caveats

- **Space + time.** At `DEFEAT_TIB=128` each tier lays out ~128 TiB per read
  source on `/work` and rewrites ≥128 TiB during the write phases. Small tiers
  lay out the same footprint with fewer nodes, so they are the slow ones — the
  **6-node tier can exceed even the `TIER_TIME=16:00:00` default wall** and die with a
  Slurm `TIMEOUT` (before `VERIFY_COLD` even runs). This is the honest cost of
  cold+sustained measurement. `CLEANUP=1` frees each task's data on exit, so peak
  `/work` use is ~one tier's footprint. To avoid the timeout, pick one:
  ```bash
  ./submit_spec_validate.sh --probe          # measure cache, then size DEFEAT_TIB to ~4x it (faster)
  DEFEAT_TIB=<rec> ./submit_spec_validate.sh
  # or keep 128 but give the small tiers the max wall (partition cap is 24h):
  TIER_TIME=24:00:00 ./submit_spec_validate.sh
  # or skip the slow small tiers if you only need the high end:
  CLIENT_TIERS="24 42" ./submit_spec_validate.sh
  ```
- **Node mix.** Tiers 6/12/24 run on `b200-batch` only (homogeneous, cleanest
  scaling signal). The 42-node tier adds `rtx-batch` because the full pool is
  26 b200 + 16 rtx; that point mixes node types.
- **io_uring still blocked** ⇒ `pvsync2` selected, `iodepth=1`, so concurrency
  comes only from `NUMJOBS`. If a sysadmin unblocks io_uring, set
  `IOENGINE=io_uring` for real queue depth.
- **Aggregate-of-N-clients.** Results are what N client nodes sustain in
  aggregate. If the vendor quoted the spec with a specific client fleet, match
  that fleet for an apples-to-apples claim; otherwise report explicitly as
  "sustained by N client nodes."

## Vast spec being validated

AICR proposal, 16 × 7 Gen5 / Ceres 1350:

| metric | spec |
|---|---|
| Max Read | 462 GB/s |
| Max Write | 165 GB/s |
| Sustained Write | 87.5 GB/s |
| Read IOPS | 2,775 k |
| Write IOPS | 825 k |
