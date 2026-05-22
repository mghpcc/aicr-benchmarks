# fio — peak aggregate I/O benchmark

Drive the Vast cluster with **many concurrent fio jobs** to measure peak
aggregate bandwidth (sequential) and IOPS (random) and compare to the Vast
spec — same recipe as `../raw-io/`, but using fio against private per-task
data directories instead of `os.read` against the ImageNet tree.

> **Push to the limit:** `WORKLOAD=all ./submit.sh` from this directory.
> One submission, both partitions, all four workloads. See [TL;DR](#tldr--push-the-cluster-to-its-limit).

The Vast spec (AICR proposal, 16×7 Gen5/Ceres 1350):
- **Max Read: 462 GB/s**
- **Max Write: 165 GB/s**
- Sustained Write: 87.5 GB/s

## What's here

| file | purpose |
|---|---|
| `jobs/seq_read_bw.fio`   | sequential read, bs=1 MiB, direct I/O, `cpus_allowed_policy=split` → peak read bandwidth |
| `jobs/seq_write_bw.fio`  | sequential write, bs=1 MiB, direct I/O, `end_fsync=1`, `cpus_allowed_policy=split` → peak write bandwidth |
| `jobs/rand_read_iops.fio`  | random read, bs=4 KiB, `norandommap=1`, `iodepth_batch_submit=8`, `iodepth_batch_complete=8`, CPU-pinned → peak read IOPS |
| `jobs/rand_write_iops.fio` | random write, bs=4 KiB, `norandommap=1`, batched submits, CPU-pinned → peak write IOPS |
| `peak_aggregate_fio.sh`  | Slurm job-array wrapper. One fio process per node, `JOBS_PER_NODE` jobs per process. Auto-detects io_uring vs posixaio, computes per-node CPU mask, auto-removes the test files on exit. fio handles its own file layout before the timed run, so read workloads don't need a separate prefill step. |
| `peak_aggregate_summary.py` | Aggregates all per-node fio JSON outputs from a run; prints cluster-aggregate BW / IOPS vs Vast spec. |
| `submit.sh`              | Combined b200 + rtx submission sized for current cluster availability. |
| `install/bin/fio`        | Local fio build (run `cd fio-src && ./configure --prefix=$PWD/../install && make -j$(nproc) install` to rebuild). |

## How it follows the "approach the spec" recipe

| recipe item | what the script does |
|---|---|
| Many concurrent jobs, not one big one | Slurm array (default 21 concurrent tasks: 13 on b200 + 8 on rtx) |
| Each job mounts via a distinct CBOX VIP | Slurm spreads tasks across nodes; each node's `/work` mount lands on its own CBOX via the VIP pool's DNS round-robin. The script logs `nfsstat -m` so you can verify VIP dispersion. |
| Use `nconnect=8` or `=16` | Already on by default — `nfsstat -m` shows `nconnect=16` on `/work`. |
| Read/write disjoint files per task | Each task writes/reads inside its own `${DATA_ROOT}/${TAG}/task_<N>/<host>/<workload>/` subtree, so no two tasks share a file (no cache overlap). |
| Avoid synchronized hot files | Same — each task's data dir is private. |
| Right-size each job | Default 2 nodes per task, 32 fio jobs per node, iodepth=64 → 2048 in-flight ops per node. Tunable via env vars. |
| Pin workers to disjoint CPUs | All jobfiles set `cpus_allowed_policy=split`; the wrapper passes `cpus_allowed=0-$((nproc-1))` per node so each fio job lands on its own CPU slice. |
| Pick the fastest available async engine | `IOENGINE=auto` (default) probes io_uring on the compute node and falls back to posixaio if the kernel refuses. io_uring is ~2–4× faster on 4 KiB random IOPS. |

## Prerequisites

- `fio` built locally at `./install/bin/fio` (already done in this repo —
  run `cd fio-src && make distclean && ./configure --prefix=$PWD/../install && make -j$(nproc) install` to rebuild from the vendored source).
- Writable scratch directory on `/work`. Default is
  `/work/mit/datasets/test/fio`; override with `DATA_ROOT` if you
  don't have write access there.
- No Python env or conda is needed — the wrapper is pure bash + fio.

## How to use

All commands assume you're in `/home/shaohao_mit/benchmarks/fio/`.

### TL;DR — push the cluster to its limit

```bash
cd /home/shaohao_mit/benchmarks/fio
WORKLOAD=all ./submit.sh
```

**This is the push-to-limit run.** One submission, both partitions, all
four workloads (seq_write → seq_read → rand_write → rand_read)
back-to-back inside every task, every node concurrent during each
workload's measurement window. After both arrays finish:

```bash
python peak_aggregate_summary.py results-peak/$TAG   # $TAG printed by submit.sh
```

You get peak BW (read + write) and peak IOPS (read + write) for the
cluster, all from one TAG. Everything else below is for narrower
experiments (one workload, one partition, custom sizing) — start with the
two lines above unless you need otherwise.

### 1. Submit the job array

```bash
cd /home/shaohao_mit/benchmarks/fio

# *** Push-to-limit run (recommended): all four workloads, both partitions ***
WORKLOAD=all ./submit.sh

# Narrower variants — only useful if you specifically don't want the full sweep:
./submit.sh                     # seq_read only
WORKLOAD=seq_write ./submit.sh  # write BW only
WORKLOAD=rand_read ./submit.sh  # read IOPS only

# Custom sizing (skip submit.sh, drive sbatch directly):
sbatch --array=0-15%16 peak_aggregate_fio.sh
WORKLOAD=rand_read sbatch -p rtx-batch -J fio_iops_rtx \
    --array=0-7%8 peak_aggregate_fio.sh
WORKLOAD=all sbatch --array=0-15%16 peak_aggregate_fio.sh
```

`sbatch` flags override the in-script `#SBATCH` directives, so the same
script runs on any partition by adding `-p <partition>` (and `-J <name>` to
keep stdout files distinguishable).

Tunable env vars:

| var | default | what it does |
|---|---|---|
| `ARRAY_SIZE`    | 16 (auto from `--array`) | number of concurrent array tasks — must match `--array=` size |
| `NODES_PER`     | 2  | nodes per array task (also set with `-N`) |
| `JOBS_PER_NODE` | 32 | fio numjobs per node — workers writing in parallel |
| `IODEPTH`       | 64 | per-fio-job iodepth (32 jobs × 64 depth = 2048 in-flight ops per node) |
| `SIZE_PER_JOB`  | 16G | per-job file size; total bytes per node = NUMJOBS × this |
| `RUNTIME`       | 60 | seconds per workload (after RAMP_TIME) |
| `RAMP_TIME`     | 10 | warm-up seconds before measurement starts |
| `WORKLOAD`      | seq_read | one of: seq_read, seq_write, rand_read, rand_write, all |
| `IOENGINE`      | auto | fio ioengine. `auto` probes io_uring on each compute node (a 1-second 4 KiB write) and falls back to posixaio if the kernel refuses (EPERM is common on login nodes and inside containers). Force a choice with `IOENGINE=io_uring` or `IOENGINE=posixaio`. The vendored fio build is missing libaio (libaio-devel wasn't present at configure time), so io_uring vs posixaio is the real choice — io_uring is ~2–4× faster on 4 KiB random IOPS and ~10–20% faster on sequential BW. |
| `DATA_ROOT`     | `/work/mit/datasets/test/fio` | base writable directory |
| `FIO_BIN`       | `./install/bin/fio` | absolute path to the fio binary |
| `TAG`           | `$SLURM_ARRAY_JOB_ID` | subdirectory under `results-peak/` and `$DATA_ROOT/` |
| `CLEANUP`       | 1 | on script exit (success, error, signal) `rm -rf` this task's data subtree under `$DATA_ROOT`. Set to `0` to keep the laid-out files for inspection or to re-run read workloads against an existing file set. JSON results in `results-peak/` are always kept. |

Per-task JSON outputs land in `./results-peak/<TAG>/task_<N>/<host>.<workload>.json`.
Slurm stdout lands in `./output-peak/`.

#### What the wrapper does for you on each node

Things that happen automatically inside `peak_aggregate_fio.sh`; you do not
need to set them by hand.

- **Engine auto-detect.** If `IOENGINE=auto` (the default), the wrapper runs
  a 1-second 4 KiB `io_uring` probe on each compute node. If io_uring works,
  the real workload uses it; if the kernel refuses (`Operation not
  permitted` is what you'll see in `output-peak/...` — common on login nodes
  and inside containers), the wrapper falls back to `posixaio`. The chosen
  engine is logged in the `engine=...` line of the task stdout. To skip the
  probe, set `IOENGINE=io_uring` or `IOENGINE=posixaio` explicitly.
- **CPU mask.** `cpus_allowed` is computed from `nproc` on each compute node
  (so it matches what Slurm gave the task via `--cpus-per-task`), and
  `cpus_allowed_policy=split` divides that mask across `JOBS_PER_NODE`
  workers so each fio job is pinned to a disjoint CPU slice.
- **Auto cleanup.** A bash `EXIT` trap removes `${DATA_ROOT}/${TAG}/task_<N>/`
  on success, error, or signal — the run leaves no fio scratch files
  behind. JSON results in `./results-peak/` are always kept. Set
  `CLEANUP=0` if you want to keep the laid-out files (e.g. to re-run a
  read workload against an existing file set without paying for layout again).
- **No prefill needed.** With `time_based=1` plus `size=`, fio lays out the
  backing files before the runtime clock starts, so read workloads against
  a fresh directory still measure real reads, not writes-then-reads.

### 2. After the array finishes, summarize

```bash
python peak_aggregate_summary.py results-peak/<TAG>
```

Output (example, made up — actual numbers depend on cluster state):

```
Run dir: results-peak/fio_1716341234
Tasks:        21
JSON files:   168
Workloads:    ['rand_read', 'rand_write', 'seq_read', 'seq_write']

=== seq_read  (BW)  [42 fio processes] ===
  cluster_sum   (sum of per-process rates):    218.40 GB/s
  conservative  (total_bytes / max_runtime):   206.10 GB/s
  vs Vast spec  (462 GB/s):  sum= 47.3%   conservative= 44.6%
  per-process distribution: min=    4.62 GB/s  median=    5.20 GB/s  max=    5.41 GB/s

=== seq_write (BW)  [42 fio processes] ===
  cluster_sum   (sum of per-process rates):     76.30 GB/s
  conservative  (total_bytes / max_runtime):    72.10 GB/s
  vs Vast spec  (165 GB/s):  sum= 46.2%   conservative= 43.7%

=== rand_read  (IOPS)  [42 fio processes] ===
  cluster_sum   (sum of per-process rates):   1450.20 kIOPS
  conservative  (total_bytes / max_runtime):  1380.00 kIOPS
  per-process distribution: min=   28.40 kIOPS  median=   34.50 kIOPS  max=   38.20 kIOPS

=== rand_write (IOPS)  [42 fio processes] ===
  cluster_sum   (sum of per-process rates):    420.10 kIOPS
  conservative  (total_bytes / max_runtime):   401.20 kIOPS
```

IOPS rows have no `vs Vast spec` line because the Vast spec sheet doesn't
publish an IOPS target. If you have one, add it to `VAST_SPEC` in
`peak_aggregate_summary.py` (e.g.
`"rand_read": ("IOPS", 5000.0, "kIOPS")`).

Two numbers because they answer different questions:
- **`cluster_sum`** = sum of per-fio-process bandwidth. Same convention as
  `../raw-io/peak_aggregate_summary.py`. Overestimates when processes finish
  at different moments.
- **`conservative`** = `total_bytes_all / max_runtime_all`. The honest
  wall-clock cluster aggregate when tasks may not overlap perfectly.

If `conservative` is much smaller than `cluster_sum`, the array tasks weren't
all reading at the same time — raise `RUNTIME` or lower `SIZE_PER_JOB` so the
measurement window actually covers all tasks concurrently.

### 3. Verify CBOX distribution (optional)

Each task's stdout in `./output-peak/` includes a `nfsstat -m` dump. The
`addr=172.23.11.xxx` field is the CBOX VIP that node mounted. To check that
the array actually spread across many CBOXes:

```bash
grep -h 'addr=' output-peak/*_a<ARRAY_ID>_t*.out | grep -oE 'addr=[0-9.]+' | sort -u
```

A healthy distribution shows many distinct addresses. If all addresses are
the same, the VIP pool isn't rotating and you've bottlenecked on one CBOX.

## Pushing toward cluster limit

The same per-mount cap that limits `../raw-io/` applies here: each NFS-
over-RDMA mount caps at ~5 GB/s per client, and the cluster's available
client nodes (b200 + rtx ≈ 45 idle on a good day) give a realistic
bandwidth ceiling of **~225 GB/s read, ~80 GB/s write**, well under the
462 / 165 GB/s spec. That gap is **client-pool-bound and
per-mount-cap-bound**, not a tuning miss. See
`../raw-io/pushing-to-400gbps.md` for the full diagnosis. To exceed those
caps you need Vast's proprietary DPC (Data Path Client) which multiplexes
a single host across all CBOXes.

For IOPS specifically, the bottleneck is different — it's per-process
syscall throughput and NFS RPC concurrency. The two knobs that move the
needle:

1. **`io_uring` vs `posixaio`.** io_uring is ~2–4× faster on 4 KiB random
   I/O. Check the `engine=...` line in `output-peak/...` after a run to
   see what auto-detect picked. If it landed on `posixaio` on compute
   nodes (not the login node), something's blocking io_uring there worth
   chasing.
2. **`IODEPTH` and `JOBS_PER_NODE`.** Defaults of 64 × 32 = 2048 in-flight
   per node are aggressive but not maxed; raising `IODEPTH=128` on big
   nodes can extract more.

For best stock-NFS aggregates, check `sinfo`, then submit. **The
push-to-limit run is `WORKLOAD=all ./submit.sh`** — it sweeps both
read and write directions for both BW and IOPS in one go:

```bash
sinfo -o "%P %a %D %t" | grep -E "b200-batch|rtx-batch"
cd /home/shaohao_mit/benchmarks/fio
WORKLOAD=all ./submit.sh       # <-- push-to-limit (all four workloads)
# Narrower runs if you don't want the full sweep:
./submit.sh                    # seq_read on 42 concurrent nodes
WORKLOAD=seq_write ./submit.sh # write BW only
```

## What this does NOT measure

- **Single-job ceiling.** This is an aggregate-cluster experiment. To see
  what a single node can do, run fio directly. Pick an engine first
  (`io_uring` on a compute node, `posixaio` on the login node — auto-detect
  only runs inside the wrapper):
  ```bash
  DATA_DIR=/work/mit/datasets/test/fio/single \
  SIZE_PER_JOB=16G NUMJOBS=32 RUNTIME=60 RAMP_TIME=10 \
  IODEPTH=64 IOENGINE=io_uring \
  CPUS_ALLOWED="0-$(($(nproc)-1))" \
      install/bin/fio --output-format=json jobs/seq_read_bw.fio
  ```
- **End-user application throughput.** Pure `fio --direct=1` against a
  scratch file. For real-workload reads (e.g. ImageNet shards), use
  `../raw-io/peak_aggregate_read_v2.sh`.

## Reference

- Vast spec (AICR proposal, 16x7 Gen5/Ceres 1350): Max Read **462 GB/s**,
  Max Write **165 GB/s**, Sustained Write 87.5 GB/s.
- raw-io baseline (42-node, 21-task array, ImageNet raw read): ~206 GB/s
  — see `../raw-io/README.md`.
