# fio — peak aggregate I/O benchmark

Drive the Vast cluster with **many concurrent fio jobs** to measure peak
aggregate bandwidth (sequential) and IOPS (random), and compare to the Vast
spec — same recipe as `../raw-io/`, but using fio against private per-task
data directories instead of `os.read` against the ImageNet tree.

## Quick start

```bash
cd /home/shaohao_mit/benchmarks/fio

# Submit: numjobs sweep ({96, 128}) × both partitions × all 4 workloads
./submit.sh

# Or with a custom numjobs sweep
NUMJOBS_SWEEP="64 96 128" ./submit.sh

# Watch progress
squeue -u $USER -o "%i %j %t %M %R"

# After each sweep cell finishes, aggregate its TAG (paths printed by submit.sh):
python peak_aggregate_summary.py results-peak/fio_<timestamp>_n96
python peak_aggregate_summary.py results-peak/fio_<timestamp>_n128
```

Each sweep cell runs `WORKLOAD=all` (seq_read_layout → seq_write →
rand_write → seq_read → rand_read) on 42 nodes and takes ~30 min wall
(45-min Slurm ceiling). Cells are chained via Slurm
`--dependency=afterany`, so a 2-value sweep finishes in ~65 min after
queue admission. `SIZES="1M 10M"` (100M removed). **Every read cell is
cache-cold** — `TOTAL_PER_JOB × numjobs × nodes ≈ 10 TiB` at numjobs=128
overflows CBOX cache for both the 1M and 10M cells. The 1M cell is slow
to lay out (NFS file-CREATE bottleneck on 262k files per fio
invocation) but the walltime is sized to absorb it. See
[TL;DR](#tldr--push-the-cluster-to-its-limit) below for the longer
explanation.

The Vast spec (AICR proposal, 16×7 Gen5/Ceres 1350):
- **Max Read: 462 GB/s**
- **Max Write: 165 GB/s** (sustained 87.5 GB/s)
- **Max Read IOPS: 2,775 k**
- **Max Write IOPS: 825 k**

## What's here

| file | purpose |
|---|---|
| `jobs/seq_read_bw.fio`     | sequential read, bs=1 MiB, direct I/O, single-pass, depends on the wrapper's layout-first flow for cold reads |
| `jobs/seq_write_bw.fio`    | sequential write, bs=1 MiB, direct I/O, `time_based=1`, `end_fsync=1` → peak write bandwidth |
| `jobs/rand_read_iops.fio`  | random read, bs=4 KiB, `time_based=1`, `norandommap=1`, batched submits → peak read IOPS |
| `jobs/rand_write_iops.fio` | random write, bs=4 KiB, `time_based=1`, batched submits → peak write IOPS |
| `peak_aggregate_fio.sh`    | Slurm job-array wrapper. One fio process per node, per-workload numjobs (seq_read / seq_write / rand_*). Auto-probes ioengine (io_uring → libaio → pvsync2 → posixaio). Handles cache-defeat via explicit `seq_read_layout` phase. Auto-removes test files on exit. |
| `peak_aggregate_summary.py`| Aggregates all per-node fio JSON outputs from a run dir; prints cluster-aggregate BW / IOPS vs Vast spec per `(workload, file-size)` cell. |
| `submit.sh`                | Combined b200 + rtx submission with numjobs sweep. Chains sweep cells via Slurm `afterany` dependency so per-TAG data doesn't smear across calendar windows. |
| `install/bin/fio`          | Local fio build (run `cd fio-src && ./configure --prefix=$PWD/../install && make -j$(nproc) install` to rebuild). |

## How it follows the "approach the spec" recipe

| recipe item | what the script does |
|---|---|
| Many concurrent jobs, not one big one | Slurm array (default 21 concurrent tasks: 13 on b200 + 8 on rtx → 42 nodes) |
| Each job mounts via a distinct CBOX VIP | Slurm spreads tasks across nodes; each node's `/work` mount lands on its own CBOX via the VIP pool's DNS round-robin. The wrapper logs `nfsstat -m`. |
| Use `nconnect=8` or `=16` | Already on by default — `nfsstat -m` shows `nconnect=16` on `/work`. |
| Read/write disjoint files per task | Each task writes/reads inside its own `${DATA_ROOT}/${TAG}/task_<N>/<host>/<jobname>/` subtree, so no two tasks share a file. |
| **Defeat CBOX server-side cache for reads** | `WORKLOAD=all` runs as `seq_read_layout → seq_write → rand_write → seq_read → rand_read`. The layout-only first pass creates the seq_read source files; the intervening writes push them out of CBOX cache before `seq_read` measures. |
| Pin workers to disjoint CPUs | All jobfiles set `cpus_allowed_policy=split`. The wrapper passes `cpus_allowed=0-$((nproc-1))` per node; if `JOBS_PER_NODE > nproc` (e.g. 128 workers on 96-core nodes) fio rotates them across the mask. |
| Pick the fastest available async engine | `IOENGINE=auto` (default) probes per-node in order `io_uring → libaio → pvsync2 → posixaio` (first that loads + survives a 1 s 4 KiB write wins). On this cluster the probe currently lands on `pvsync2` everywhere (io_uring seccomp-blocked, libaio not compiled into the local fio build). |

## Prerequisites

- `fio` built locally at `./install/bin/fio` (run
  `cd fio-src && make distclean && ./configure --prefix=$PWD/../install && make -j$(nproc) install`
  to rebuild). The current build is missing `libaio` support (`libaio-devel`
  wasn't installed at configure time) — installing it and rebuilding would
  add a real-iodepth fallback for nodes where io_uring is blocked.
- Writable scratch on `/work`. Default is `/work/mit/datasets/test/fio`;
  override with `DATA_ROOT` if you don't have write access there.
- No Python env needed — wrapper is pure bash + fio. Aggregator uses only
  the stdlib.

## How to use

All commands assume you're in `/home/shaohao_mit/benchmarks/fio/`.

### TL;DR — push the cluster to its limit

```bash
cd /home/shaohao_mit/benchmarks/fio
./submit.sh
```

That's the push-to-limit run. One command does:

- **Two sweep cells** — `numjobs ∈ {96, 128}` applied uniformly to
  seq_read / seq_write / rand_read / rand_write (set with
  `NUMJOBS_SWEEP="96 128"` by default).
- **Both partitions** — 13 b200 tasks + 8 rtx tasks = 42 concurrent nodes
  per sweep cell.
- **All four workloads** — `WORKLOAD=all` wires `seq_read_layout →
  seq_write → rand_write → seq_read → rand_read` inside every task.
- **Cold reads** — layout-first chain pushes seq_read source files out of
  CBOX cache via the intervening writes before measurement.
- **Three seq file sizes** — `SIZES="1M 10M 100M"` swept inside seq_read
  and seq_write; rand_* uses a single 16 GiB file per worker.

Sweep cells are submitted as a Slurm dependency chain
(`--dependency=afterany`), so the second cell only starts after the first
finishes. Without the chain, Slurm could schedule `b200@n96` next to
`rtx@n128` (different partitions, no slot contention) and split each
TAG's data across two calendar windows — invalid for an aggregate
measurement.

`submit.sh` prints a `BASE_TAG` plus per-cell TAGs (e.g.
`fio_<ts>_n96`, `fio_<ts>_n128`). After both cells finish:

```bash
for tag in results-peak/fio_<ts>_n*; do
    echo "=== $tag ==="
    python peak_aggregate_summary.py "$tag"
done
```

(The exact paths are echoed at the end of `submit.sh`'s output.)

Each TAG gives you peak BW (read + write, per file size) and peak IOPS
(read + write) for the cluster at that numjobs setting. Comparing TAGs
shows whether 96 or 128 workers/node helps each workload.

### Variants

```bash
# Single numjobs value (no sweep), all workloads, default sizes
NUMJOBS_SWEEP=96 ./submit.sh

# Single workload, numjobs sweep
WORKLOAD=seq_write ./submit.sh

# Three numjobs values
NUMJOBS_SWEEP="64 96 128" ./submit.sh

# Custom seq_* size sweep
SIZES="1M 10M 100M 1G" ./submit.sh

# Bypass submit.sh for narrower experiments — drive sbatch directly
WORKLOAD=rand_read sbatch -p rtx-batch -J fio_iops_rtx \
    -N 2 --ntasks-per-node=1 --cpus-per-task=96 \
    --array=0-7%8 peak_aggregate_fio.sh
```

`sbatch` flags override the in-script `#SBATCH` directives, so the same
wrapper script runs on any partition by adding `-p <partition>` (and
`-J <name>` to keep stdout files distinguishable).

### Tunable env vars

The wrapper script (`peak_aggregate_fio.sh`) reads these directly. When
launched via `submit.sh`, the submit script sets several of them per
sweep cell; the defaults below are what the wrapper falls back to when
run standalone.

| var | default | what it does |
|---|---|---|
| `ARRAY_SIZE`               | from `--array`  | number of concurrent array tasks |
| `NODES_PER`                | 2               | nodes per array task (also `-N`) |
| `JOBS_PER_NODE`            | 32              | fio numjobs/node for `seq_read` |
| `SEQ_WRITE_JOBS_PER_NODE`  | 128             | fio numjobs/node for `seq_write`. Higher than seq_read because pvsync2 is sync (`iodepth` clamped to 1), so more workers is the only knob for more in-flight writes. Deliberately oversubscribes the 96 allowed CPUs (workers are RPC-bound, not CPU-bound). |
| `RAND_JOBS_PER_NODE`       | 64              | fio numjobs/node for `rand_*` |
| `IODEPTH`                  | 64              | per-job iodepth for `seq_*` (clamped to 1 by the wrapper for sync engines like pvsync2 — fio's iodepth-warning would otherwise break JSON parsing) |
| `RAND_IODEPTH`             | 128             | per-job iodepth for `rand_*` (same sync-engine clamp applies) |
| `SIZES`                    | `"1M 10M"`      | space-separated file-size sweep for `seq_*`. nrfiles is computed as `TOTAL_PER_JOB / size` with no cap, so every cell honors the cache-defeat footprint of `TOTAL_PER_JOB × numjobs × nodes`. 100M was dropped from the default because it gave the worst cache-hit signal on prior runs and added significant wall time. The 1M cell is the slowest (NFS file-CREATE RPC bottleneck at high file counts) — the walltime is sized to absorb this. |
| `TOTAL_PER_JOB`            | 2G              | per-worker working set for `seq_*`. Cluster footprint = numjobs × nodes × this (≈10 TiB at numjobs=128 × 42 nodes). Sized to overflow CBOX server-side cache so the layout-first chain delivers honest cold-read seq_read numbers. The 512M variant fit in a 12-min Slurm wall but produced seq_read above the 462 GB/s storage spec (cache-hit signature). |
| `RAND_SIZE_PER_JOB`        | 512M            | per-worker file size for `rand_*` (single file each, time_based loops over it). The random access pattern dilutes CBOX cache hits enough at this size to keep rand_* honest. Raise to 4G+ if you want fully cache-cold rand_*. |
| `RUNTIME`                  | 20              | seconds per workload for seq_write and rand_* (no effect on seq_read; that's single-pass). 20 s × ~50 k IOPS/node ≈ 1 M ops per worker — sub-1% IOPS noise. |
| `RAMP_TIME`                | 5               | warm-up seconds before measurement (industry-norm) |
| `HONEST_FSYNC`             | 1               | `1` = `rand_write` uses `end_fsync=1` (wait for server commit, honest). `0` = drops it for dishonest spec comparison only. |
| `WORKLOAD`                 | `seq_read`      | one of: `seq_read`, `seq_write`, `rand_read`, `rand_write`, `seq_read_layout`, `all`. `all` expands to the cache-defeat chain. `seq_read_layout` is the layout-only pseudo-workload (no measurement). |
| `IOENGINE`                 | `auto`          | `auto` probes `io_uring → libaio → pvsync2 → posixaio` per node and picks the first that loads + survives a 1 s 4 KiB probe. Force a choice with `IOENGINE=io_uring`, `libaio`, `pvsync2`, or `posixaio`. |
| `DATA_ROOT`                | `/work/mit/datasets/test/fio` | base writable directory |
| `FIO_BIN`                  | `./install/bin/fio` | absolute path to the fio binary |
| `TAG`                      | `$SLURM_ARRAY_JOB_ID` | subdir under `results-peak/` and `$DATA_ROOT/` |
| `CLEANUP`                  | 1               | on script exit `rm -rf` this task's data subtree under `$DATA_ROOT`. Set to `0` to keep laid-out files for inspection. JSON results in `results-peak/` are always kept. |

`submit.sh` tunables (drive the sweep):

| var | default | what it does |
|---|---|---|
| `NUMJOBS_SWEEP` | `"96 128"`        | space-separated numjobs values. Applied uniformly to `JOBS_PER_NODE`, `SEQ_WRITE_JOBS_PER_NODE`, and `RAND_JOBS_PER_NODE` within each sweep cell. |
| `WORKLOAD`      | `all`              | passed through to the wrapper |
| `SIZES`         | `"1M 10M 100M"`    | passed through to the wrapper |

Per-task JSON lands in `./results-peak/<TAG>/task_<N>/<host>.<jobname>.json`.
Slurm stdout lands in `./output-peak/`.

#### What the wrapper does for you on each node

These happen automatically inside `peak_aggregate_fio.sh`; you don't
need to set them by hand.

- **Engine auto-detect.** With `IOENGINE=auto` (default), each compute
  node runs a 1 s 4 KiB probe against each engine in turn:
  `io_uring → libaio → pvsync2 → posixaio`. The first one that loads and
  doesn't print a failure marker is selected. Chosen engine is logged in
  the `engine=…` line of the task's stdout in `output-peak/`.
- **`iodepth` clamp for sync engines.** Sync engines (`pvsync2`, `psync`,
  `sync`, `vsync`) ignore `iodepth` and emit a `note:` prologue line that
  would break JSON parsing downstream. The wrapper forces `iodepth=1` in
  the rendered jobfile when the chosen engine is sync.
- **Layout-first cache defeat for seq_read.** When `WORKLOAD=all`, the
  wrapper runs `seq_read_layout` first (`fio --create_only=1` against the
  seq_read jobfile, writing to `/dev/null` for output), then runs the
  measurement workloads in an order that interleaves enough writes between
  layout and `seq_read` to push the source files out of CBOX server-side
  cache. **Running `WORKLOAD=seq_read` standalone does NOT have this
  benefit** — fio's own implicit layout will warm cache with exactly what
  you're about to read; the result will be cache-inflated.
- **CPU mask.** `cpus_allowed=0-$((nproc-1))` matches whatever Slurm gave
  the task via `--cpus-per-task`. `cpus_allowed_policy=split` divides that
  mask across workers; if numjobs exceeds the CPU count (e.g. seq_write at
  128 workers on a 96-core slot), fio rotates so multiple workers share a
  CPU. For RPC-bound sync I/O, oversubscription is intentional and
  doesn't hurt.
- **Auto cleanup.** A bash `EXIT` trap removes
  `${DATA_ROOT}/${TAG}/task_<N>/` on success, error, or signal. JSON
  outputs in `./results-peak/` are always kept. Set `CLEANUP=0` to
  preserve the laid-out files (e.g. to re-run a read workload against an
  existing file set).

### After the array finishes, summarize

```bash
python peak_aggregate_summary.py results-peak/<TAG>
```

The aggregator groups by `(workload, file-size)` cell. For seq_*, the
file-size labels come from the `SIZES` sweep (e.g. `seq_read [1M]`);
rand_* has no size label.

Output (shape — actual numbers from a real run will differ):

```
Run dir: results-peak/fio_1779420797_n96
Tasks:        21
JSON files:   336
Cells found:  [('rand_read', None), ('rand_write', None),
               ('seq_read', '100M'), ('seq_read', '10M'), ('seq_read', '1M'),
               ('seq_write', '100M'), ('seq_write', '10M'), ('seq_write', '1M')]

=== seq_read  [1M]  (BW)  [42 fio processes] ===
  BW   cluster_sum:    384.32 GB/s   conservative:   309.18 GB/s
  IOPS cluster_sum:    366.51 kIOPS  conservative:   294.59 kIOPS   (avg bs ≈ 1024 KiB)
  vs Vast spec  (462 GB/s):  sum= 83.2%   conservative= 66.9%
  per-process BW   distribution: min=    7.35 GB/s  median=    9.83 GB/s  max=   15.22 GB/s
…
=== rand_read  (IOPS)  [42 fio processes] ===
  BW   cluster_sum:       7.97 GB/s  conservative:     7.97 GB/s
  IOPS cluster_sum:    1946.41 kIOPS conservative:  1945.04 kIOPS   (avg bs ≈ 4 KiB)
  vs Vast spec  (2775 kIOPS):  sum= 70.1%   conservative= 70.1%
…
```

Two numbers per cell:
- **`cluster_sum`** = sum of per-fio-process throughput. Matches the
  sum-of-rank-rates convention from the dataloader / `../raw-io/`
  suites. **Overestimates** when nodes finish at different moments.
- **`conservative`** = `total_bytes_all / max_runtime_all`. Honest
  wall-clock cluster aggregate. **Use this** for comparisons against the
  Vast spec.

If `conservative` is much smaller than `cluster_sum` on a `time_based`
workload, the array tasks weren't all reading at the same time — raise
`RUNTIME` or shorten the per-task working set. For single-pass `seq_read`
the gap is expected at small file sizes (short runtime, more overlap loss).

If `cluster_sum` for `seq_read` exceeds the 462 GB/s spec, that's a
cache-hit signal — the layout-first flow probably didn't push hard
enough cache pressure. Increase intervening write volume (raise
`RUNTIME` on seq_write, or sweep more sizes).

### Verify CBOX distribution (optional)

Each task's stdout in `./output-peak/` includes an `nfsstat -m` dump. The
`addr=172.23.11.xxx` field is the CBOX VIP that node mounted. To check
that the array actually spread across many CBOXes:

```bash
grep -h 'addr=' output-peak/*_a<ARRAY_ID>_t*.out | grep -oE 'addr=[0-9.]+' | sort -u
```

A healthy distribution shows many distinct addresses. If all are the
same, the VIP pool isn't rotating and you've bottlenecked on one CBOX.

## Pushing toward the cluster limit

The same per-mount cap that limits `../raw-io/` applies here: each
NFS-over-RDMA mount caps at ~5 GB/s/client cold-read, and the available
client pool (b200 + rtx ≈ 42–55 nodes on a good day) gives a realistic
honest-cold ceiling of **~270 GB/s read, ~80 GB/s write** without DPC,
well under the 462 / 165 GB/s spec. That gap is **client-pool-bound and
per-mount-cap-bound**, not a tuning miss. To exceed those caps you need
Vast's proprietary DPC (Data Path Client) which multiplexes a single
host across all CBOXes.

For IOPS, the bottleneck is engine-driven. `pvsync2` (the current
auto-pick) gives ~50 kIOPS/node read / ~21 kIOPS/node write — roughly
**70 % of spec read, > spec write** on a 42-node pool. The remaining
gap to read spec would close with either `io_uring` (currently
seccomp-blocked) or a larger client pool.

```bash
sinfo -o "%P %a %D %t" | grep -E "b200-batch|rtx-batch"
cd /home/shaohao_mit/benchmarks/fio
./submit.sh    # full numjobs sweep, all four workloads, cold-cache reads
```

## What this does NOT measure

- **Single-job ceiling.** This is an aggregate-cluster experiment. To
  see what a single node can do, run fio directly:
  ```bash
  DATA_DIR=/work/mit/datasets/test/fio/single \
  SIZE_PER_JOB=4G NRFILES=4096 NUMJOBS=32 RUNTIME=60 RAMP_TIME=10 \
  IODEPTH=64 IOENGINE=pvsync2 \
  CPUS_ALLOWED="0-$(($(nproc)-1))" JOBNAME=seq_read \
      install/bin/fio --output-format=json jobs/seq_read_bw.fio
  ```
- **End-user application throughput.** Pure `fio --direct=1` against a
  scratch file. For real-workload reads (e.g. ImageNet shards), use
  `../raw-io/peak_aggregate_read_v2.sh`.

## Reference

- Vast spec (AICR proposal, 16x7 Gen5/Ceres 1350): Max Read **462 GB/s**,
  Max Write **165 GB/s**, Sustained Write 87.5 GB/s; Max Read IOPS
  **2,775 k**, Max Write IOPS **825 k**.
- raw-io baseline (42-node, 21-task array, ImageNet cold reads):
  ~206 GB/s — see `../raw-io/README.md`.
- See `summary.md` / `notes.md` in this directory for analysis of recent
  runs and the engine / cache-defeat reasoning.
