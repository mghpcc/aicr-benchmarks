# raw-io — peak aggregate read benchmark

Drive the Vast cluster with **many concurrent jobs** to see how close the aggregate read throughput gets to the Vast spec **Max Read = 462 GB/s**.

A single 16-node job in `../dataloader/results-multinodes/` peaks at ~81 GB/s (≈18% of spec) because each NFS mount pins to one CBOX. This benchmark submits a Slurm **job array** so many independent client jobs hit different CBOXes in parallel — closer to how a real multi-user environment loads the cluster.

## What's here

| file | purpose |
|---|---|
| `peak_aggregate_read_v1.sh` | **v1**: original Slurm job-array script. Each task allocates a few nodes, shards the ImageNet class tree, and runs `read_benchmark.py --mode raw` on its shard. The version that produced the run in `results-peak/out.summary-v1` (peak iter sum = 254 GB/s). |
| `peak_aggregate_read_v2.sh` | **v2**: same as v1 plus a `REPEATS` env var that multiplies the shard.index N times so each iter is longer. Use this when shards are small relative to Slurm task-launch jitter. |
| `peak_aggregate_read.sh`    | Convenience alias — currently a copy of v1. |
| `peak_aggregate_summary.py` | Aggregates all per-rank CSVs from one array run and prints cluster GB/s vs the 462 GB/s spec. |
| `submit.sh`                 | Combined b200 + rtx submission sized for current cluster; calls `peak_aggregate_read_v2.sh` with `REPEATS=10 ITERS=5`. |

The benchmark binary (`read_benchmark.py`) lives in the sibling repo `/home/shaohao_mit/benchmarks/dataloader/`; the script calls it by absolute path, so you can submit from this directory.

**One script for any partition.** `sbatch` command-line flags override the in-script `#SBATCH` directives, so the same `peak_aggregate_read.sh` runs on `b200-batch`, `rtx-batch`, or any other partition just by adding `-p <partition>` (and `-J <name>` to keep stdout files distinguishable).

## How it follows the "approach the spec" recipe

| recipe item | what the script does |
|---|---|
| Many concurrent jobs, not one big one | Slurm array (default 16 concurrent tasks) instead of one fat allocation |
| Each job mounts via a distinct CBOX VIP | Slurm spreads tasks across nodes; each node's NFS mount lands on its own CBOX via the VIP pool's DNS round-robin. The script logs `nfsstat -m` so you can verify VIP dispersion |
| Use `nconnect=8` or `=16` | Already on by default — `nfsstat -m` shows `nconnect=16` on `/work`. Nothing to do |
| Read different file sets | Shards the 1000 ImageNet class directories by `task_id mod array_size`, so each task reads a disjoint set of files (no cache overlap) |
| Avoid synchronized hot files | Same — each task's shard contains only its own classes |
| Right-size each job | Default 2 nodes × 96 procs per task; tunable via `NODES_PER` / `CPU_PER_NODE` |

## Prerequisites

- The benchmark binary at `/home/shaohao_mit/benchmarks/dataloader/read_benchmark.py` exists and is runnable. Override with the `BENCH_PY` env var if it moves.
- Dataset path is hardcoded to `/work/mit/datasets/imagenet/images_complete/ilsvrc/train` (1000 ImageNet class directories). Change `DATA_ROOT` inside the script for a different corpus.
- Conda env `torch` (loaded inside the job via `module load miniforge3/25.3.0-3 && source activate torch`).

## How to use

All commands assume you're in `/home/shaohao_mit/benchmarks/raw-io/`.

### 1. Submit the job array

Two script versions are available. Pick one explicitly:

```bash
cd /home/shaohao_mit/benchmarks/raw-io

# --- v1: simpler, no REPEATS. Default for quick runs. ---
# default: b200-batch, 16 concurrent tasks × 2 nodes = 32 nodes
sbatch --array=0-15%16 peak_aggregate_read_v1.sh

# rtx-batch (17-node partition): override partition + job name
sbatch -p rtx-batch -J vast_peak_read_rtx --array=0-7%8 peak_aggregate_read_v1.sh

# more aggressive on b200 (idle days):
ARRAY_SIZE=20 sbatch --array=0-19%20 peak_aggregate_read_v1.sh

# larger jobs (4 nodes each, 8 concurrent):
NODES_PER=4 ARRAY_SIZE=8 sbatch --array=0-7%8 -N 4 peak_aggregate_read_v1.sh

# --- v2: adds REPEATS to extend each iter past Slurm launch jitter ---
# Each iter reads N× the raw shard. Useful when shards are small.
REPEATS=10 ITERS=5 ARRAY_SIZE=20 sbatch --array=0-19%20 peak_aggregate_read_v2.sh
```

Slurm flags worth knowing (set on the `sbatch` command line, override the script's `#SBATCH` directives):

| flag | default in script | what to use it for |
|---|---|---|
| `-p <partition>`   | `b200-batch` | switch partition (e.g. `-p rtx-batch`) |
| `-J <jobname>`     | `vast_peak_read` | rename so each partition's stdout files in `output-peak/` are distinguishable |
| `-N <nodes>`       | 2 | nodes per array task — must agree with `NODES_PER` env var |
| `--array=A-B%C`    | — | array range and max concurrency; must agree with `ARRAY_SIZE` |

Tunable env vars (also overridable on the `sbatch` command line):

| var | default | what it does |
|---|---|---|
| `ARRAY_SIZE`   | 16 (auto from `--array`) | number of concurrent array tasks — must match `--array=` size |
| `NODES_PER`    | 2  | nodes per array task (also set with `-N`) |
| `CPU_PER_NODE` | 96 | worker procs per node |
| `TOTAL_SIZE`   | 8G | bytes read per rank per iter; keep modest so all tasks overlap during the measurement window |
| `ITERS`        | 3  | iterations per task |
| `TAG`          | `$SLURM_ARRAY_JOB_ID` | subdirectory under `results-peak/` |
| `BENCH_PY`     | `/home/shaohao_mit/benchmarks/dataloader/read_benchmark.py` | absolute path to the benchmark binary |

Per-task results land in `./results-peak/<TAG>/task_<N>/`; Slurm stdout lands in `./output-peak/`.

### 2. After the array finishes, summarize

```bash
python peak_aggregate_summary.py results-peak/<TAG>
```

Output looks like:

```
iter  cluster_sum_GBps  conservative_GBps  vs_462_spec  ranks
  0            312.4              298.7        67.6%    1536
  1            324.1              305.2        70.2%    1536
  2            319.8              301.8        69.2%    1536

mean cluster_sum_GBps (sum-of-rank-rates) :   318.8 GB/s  =>  69.0% of Vast Max Read (462 GB/s)
mean conservative_GBps (bytes/max_elapsed):   301.9 GB/s  =>  65.4% of Vast Max Read (462 GB/s)
```

Two numbers because they answer different questions:
- **`cluster_sum_GBps`** = sum of per-rank `total_bytes / elapsed`. Same convention as `../dataloader/results-multinodes/summary.md`. Overestimates when ranks/tasks finish at different moments.
- **`conservative_GBps`** = `total_bytes_all / max_elapsed_all`. The honest wall-clock cluster aggregate when tasks may not overlap perfectly.

If `conservative` is much smaller than `cluster_sum_GBps`, the array tasks weren't all reading at the same time — shrink `TOTAL_SIZE` or raise `ITERS` so all tasks overlap during the measurement window.

### 3. Verify CBOX distribution (optional)

Each task's stdout in `./output-peak/` includes a `nfsstat -m` dump. The `addr=172.23.11.xxx` field is the CBOX VIP that node mounted. To check that the array actually spread across many CBOXes:

```bash
grep -h 'addr=' output-peak/*_a<ARRAY_ID>_t*.out | grep -oE 'addr=[0-9.]+' | sort -u
```

A healthy distribution shows many distinct addresses; if all addresses are the same, the VIP pool isn't rotating and you've bottlenecked on one CBOX.

## Pushing toward 400+ GB/s

**The 462 GB/s Vast spec is not reachable from this cluster with stock NFS.** Each NFS-over-RDMA mount caps at ~5 GB/s (even with `nconnect=16`), and the cluster's available compute nodes (b200 + rtx + cpu + devel ≈ 55 nodes max) give a realistic ceiling of **~270 GB/s**. The observed 42-node run reached **206 GB/s = 42 × 4.9 GB/s/node** — essentially the per-client cap times the node count, not a tuning miss. To genuinely exceed 270 GB/s you need either many more client nodes than this cluster has, or **Vast's proprietary DPC (Data Path Client)** which multiplexes a single host across all CBOXes and bypasses the per-mount cap. Ask the Vast / cluster team whether DPC is available here. Full diagnostic data, per-client-cap derivation, and DPC notes in [`pushing-to-400gbps.md`](pushing-to-400gbps.md).

To get the best stock-NFS aggregate measurement on this cluster, check `sinfo`, then submit using either script version. Pick by the trade-off you care about:

- **v1** (`peak_aggregate_read_v1.sh`) — simpler, longer iter count, lets some tasks finish early. The historical 254 GB/s peak in `results-peak/out.summary-v1` came from this path, though that number was partly an artifact of late-wave tasks aggregating into iter-index totals they didn't actually overlap with.
- **v2** (`peak_aggregate_read_v2.sh`, used by `submit.sh`) — `REPEATS` extends each iter past Slurm launch jitter, so the reported numbers genuinely reflect concurrent reads. Lower headline number (~206 GB/s on 42 nodes) but more honest.

```bash
sinfo -o "%P %a %D %t" | grep -E "b200-batch|rtx-batch"
cd /home/shaohao_mit/benchmarks/raw-io
```

### v1 run (28 tasks × 2 nodes, ITERS=15, no REPEATS):

```bash
TAG=v1_$(date +%s)
ARRAY_SIZE=28 TAG=$TAG CPU_PER_NODE=128 TOTAL_SIZE=32G ITERS=15 \
    sbatch -p b200-batch -J peak_b200 -N 2 --ntasks-per-node=128 \
           --array=0-19%20 peak_aggregate_read_v1.sh
ARRAY_SIZE=28 TAG=$TAG CPU_PER_NODE=128 TOTAL_SIZE=32G ITERS=15 \
    sbatch -p rtx-batch  -J peak_rtx  -N 2 --ntasks-per-node=128 \
           --array=20-27%8  peak_aggregate_read_v1.sh
python peak_aggregate_summary.py results-peak/$TAG
```

### v2 run via `submit.sh` (21 tasks × 2 nodes, ITERS=5, REPEATS=10):

```bash
./submit.sh
# prints the TAG and the summary command to run after both arrays finish
```

`submit.sh` runs the equivalent of (sized for ~28 idle b200 + ~17 idle rtx → 42 concurrent nodes):

```bash
TAG=combo_$(date +%s)
ARRAY_SIZE=21 TAG=$TAG CPU_PER_NODE=128 TOTAL_SIZE=64G ITERS=5 REPEATS=10 \
    sbatch -p b200-batch -J peak_b200 -N 2 --ntasks-per-node=128 \
           --array=0-12%13 peak_aggregate_read_v2.sh
ARRAY_SIZE=21 TAG=$TAG CPU_PER_NODE=128 TOTAL_SIZE=64G ITERS=5 REPEATS=10 \
    sbatch -p rtx-batch  -J peak_rtx  -N 2 --ntasks-per-node=128 \
           --array=13-20%8 peak_aggregate_read_v2.sh
python peak_aggregate_summary.py results-peak/$TAG
```

Read the **last 3 iters of `conservative_GBps`**, not the mean — early iters are warmup. Either path tops out near the **per-client cap × node count** ceiling (~270 GB/s with every idle node on this cluster); the gap to the 462 GB/s Vast spec is **client-pool-bound and per-mount-cap-bound**, not a tuning problem.

## What this does NOT measure

- **Write throughput.** Read-only. Use `../dataloader/write_benchmark.py` for writes.
- **`dataloader` mode** (JPEG decode + transforms). Pure `raw` `os.read` calls only.
- **Single-job ceiling.** This is an aggregate-cluster experiment. To see what a single job can do, use the per-config runs in `../dataloader/results-multinodes/`.

## Reference

- Vast spec (AICR proposal, 16x7 Gen5/Ceres 1350): Max Read **462 GB/s**, Max Write 165 GB/s, Sustained Write 87.5 GB/s.
- Single-job baseline (16 nodes × 128 cpu, `raw`): ~81 GB/s — see `../dataloader/results-multinodes/summary.md`.
