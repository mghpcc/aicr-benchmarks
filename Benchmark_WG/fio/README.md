# Fair Vast Spec Validation — User Guide

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

```bash
# 1. Submit the scaling sweep (chained tiers, runs unattended).
./submit_spec_validate.sh

# 2. After it finishes, read the scaling curve + spec verdict.
python spec_validate_summary.py results-peak/specval_<TIMESTAMP>
```

`submit_spec_validate.sh` prints the exact `BASE_TAG` (e.g. `specval_1779999999`)
and the summary command to run when done.

## What makes the comparison fair

The four things that made the old peak numbers unfair vs. spec, and how this
harness fixes each:

1. **Cold, not cache.** Each tier sizes the cluster-wide working set to
   `DEFEAT_TIB` (default **32 TiB**), held constant across tiers so every tier
   independently overflows the CBOX server cache. Reads are measured only after
   two multi-TB write phases (`seq_write`, `rand_write`) have evicted the
   laid-out read sources from cache. Client cache is killed as always
   (`direct=1 + invalidate=1 + fadvise_hint=1`). Note: `direct=1` only bypasses
   the *client* page cache — defeating the *server* CBOX cache requires
   working-set sizing, which is why `DEFEAT_TIB` exists (see `node.md`).
2. **Sustained, not burst.** `time_based` writes run for `RUNTIME` (default
   **900 s = 15 min**) so the CBOX NVMe write buffer saturates and you measure
   the rate storage can hold — comparable to the vendor "sustained write" line.
3. **Streaming, not metadata.** seq_* uses large files (`FILE_SIZE`, default
   **1G**) so bandwidth isn't throttled by file-create RPCs (the small-file
   metadata trap that made seq_write read 11% of spec).
4. **Honest writes.** `end_fsync=1` (`HONEST_FSYNC=1`) — writes wait for server
   commit before the clock stops.

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
| `DEFEAT_TIB` | `32` | cluster working set per direction (TiB). Must exceed CBOX cache. Lower to ~4× actual cache once known, to cut layout time. |
| `RUNTIME` | `900` | sustained-window seconds per `time_based` phase |
| `RAMP_TIME` | `60` | warm-up before measurement |
| `NUMJOBS` | `96` | fio workers per node = allocated cores. **Never** exceed cores — oversubscription regresses on a sync engine (see `summary.md` n128). `--cpus-per-task` is set to match. |
| `FILE_SIZE` | `1G` | per-file size for seq_* streaming |
| `HONEST_FSYNC` | `1` | 1 = wait for server commit; 0 = buffered (dishonest, don't use for validation) |
| `TIER_TIME` | `08:00:00` | Slurm `--time` per tier (size for the SLOWEST/smallest tier) |
| `IOENGINE` | `auto` | probe `io_uring → libaio → pvsync2 → posixaio`; io_uring gives real iodepth if unblocked |

## Cost & caveats

- **Space + time.** At `DEFEAT_TIB=32` each tier lays out ~32 TiB per read
  source on `/work` and rewrites ≥32 TiB during the write phases. Small tiers
  (few nodes) lay out the same footprint with fewer nodes, so they are the slow
  ones — the 6-node tier can take hours; the full chained sweep may run
  overnight. This is the honest cost of cold+sustained measurement. `CLEANUP=1`
  frees each task's data on exit, so peak `/work` use is ~one tier's footprint.
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
