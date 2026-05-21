# PyTorch I/O benchmarks for Vast storage

Two scripts that measure read/write throughput against a Vast (NFS-over-RDMA)
mount using PyTorch primitives.

- `read_benchmark.py` — reads ImageNet JPEGs (raw bytes and/or full DataLoader
  with decode + transforms).
- `write_benchmark.py` — writes random data via three methods: raw bytes,
  `torch.save`, and `torch.distributed.checkpoint`.

Each Slurm task writes its own `results.<host>.<rank>.csv` to avoid write
races on a shared file. Concatenate the CSVs after the job for aggregation.

## Setup

```bash
module load miniforge3/25.3.0-3
source activate torch
```

Required Python packages: `torch`, `torchvision`, `Pillow`.

## Read benchmark

```bash
python read_benchmark.py \
    --input /work/mit/datasets/imagenet/images_complete/ilsvrc/train \
    --output-dir ./results \
    --mode both \
    --nproc 32 \
    --total-size 10G \
    --iters 3
```

### Key arguments

| Flag | Default | Notes |
|------|---------|-------|
| `--input` | `/work/mit/.../train` | Root containing JPEGs (class subdirs). |
| `--output-dir` | `.` | Where per-task CSV is written. |
| `--mode` | `both` | `raw` (bytes only), `dataloader` (decode + transforms), or `both`. |
| `--nproc` | `8` | DataLoader `num_workers` / raw `multiprocessing.Pool` size. |
| `--total-size` | `10G` | Approx bytes per measurement iter (file count is derived). |
| `--num-files` | `0` | Exact file count per iter; overrides `--total-size`. |
| `--warmup-files` | `200` | Files read (untimed) before the first measurement. |
| `--iters` | `3` | Repeats per mode; each iter uses a fresh disjoint file slice. |
| `--block-size` | `1M` | Read chunk size in raw mode. |
| `--batch-size` | `64` | DataLoader batch size. |
| `--use-mp` | off | DataLoader mode: spawn `nproc` independent `torch.multiprocessing` processes instead of using DataLoader workers. |
| `--o-direct` | off | Raw mode only: open with `O_DIRECT` (NFS support varies). |
| `--no-drop-cache` | off | Skip `posix_fadvise(DONTNEED)`. |
| `--index-file` | `./.imagenet_index.txt` | Cached file list (built on first run, reused after). |
| `--seed` | `0` | Per-rank seed = `seed + SLURM_PROCID`. |

### How sampling works

- The full file list is shuffled per Slurm rank (`seed + rank`).
- Each measurement iter takes a fresh, disjoint slice of `num_files` paths.
- `posix_fadvise(POSIX_FADV_DONTNEED)` is called on each fd after reading, so
  the working set is not artificially served from page cache.

## Write benchmark

```bash
python write_benchmark.py \
    --output-path /work/mit/datasets/test \
    --output-dir ./results \
    --mode all \
    --nproc 32 \
    --file-size 100K,1M,10M,100M \
    --files-per-proc 8 \
    --iters 3
```

### Key arguments

| Flag | Default | Notes |
|------|---------|-------|
| `--output-path` | `/work/mit/datasets/test` | Base dir on Vast. A unique subdir is created per invocation. |
| `--output-dir` | `.` | Where per-task CSV is written. |
| `--mode` | `all` | `raw`, `torch_save`, `dcp`, or `all`. |
| `--nproc` | `8` | `multiprocessing.Pool` size. |
| `--file-size` | `100K,1M,10M,100M` | Per-file size; comma-separated sweep. |
| `--files-per-proc` | `8` | Files written per process per size. |
| `--total-size` | — | If set, overrides `--files-per-proc`: files = total / (nproc × size). |
| `--iters` | `3` | Timed repeats per (mode, size). |
| `--warmup` | `1` | Untimed warmup iters per (mode, size). |
| `--block-size` | `1M` | Chunk size for raw writes. |
| `--o-direct` | off | Raw mode: `O_DIRECT` writes via aligned mmap buffer. |
| `--no-fsync` | off | Skip `fsync` (measures cache, not durable throughput). |
| `--no-drop-cache` | off | Skip `posix_fadvise(DONTNEED)`. |
| `--keep-files` | off | Don't delete files at the end (useful for debugging). |

### What each mode writes

- **raw** — `os.write` of a pre-allocated random buffer, `block_size` at a
  time, followed by `fsync` and `posix_fadvise(DONTNEED)`.
- **torch_save** — `torch.save(tensor, f)` on a float32 tensor sized to
  `file_size`, then `fsync` + `posix_fadvise(DONTNEED)` on the same fd.
- **dcp** — `torch.distributed.checkpoint.save` on a synthetic `nn.Module`
  with one parameter sized to `file_size`. Each worker initializes its own
  single-rank gloo process group via file-based `init_method` (no port
  collisions). Each DCP "file" is actually a directory containing data
  shards + `.metadata`; reported bytes = total size of those files.

### Per-worker timing

Each worker pre-allocates its random data outside the timed region, then
times only its own write loop. The aggregate throughput is
`sum(bytes_per_worker) / max(elapsed_per_worker)` — the slowest worker's wall
clock for the parallel section, which is the right denominator for a
saturation measurement.

## Output CSVs

Each Slurm task writes `results.<host>.<rank>.csv` to `--output-dir`. Rank
comes from `$SLURM_PROCID` (defaults to 0 outside Slurm).

Concatenate after the job:

```bash
# Header from any one file, then data rows from all.
head -n 1 results.*.csv | head -n 1 > all.csv
tail -n +2 -q results.*.csv >> all.csv
```

### Columns

**Read CSV:**
`timestamp, hostname, rank, mode, nproc, num_files, total_bytes, elapsed_s,
GBps, block_size, batch_size, o_direct, drop_cache, use_mp, iter_idx`

**Write CSV:**
`timestamp, hostname, rank, mode, nproc, file_size, files_per_proc,
num_files, total_bytes, elapsed_s, GBps, block_size, o_direct, fsync,
drop_cache, iter_idx`

## Sweeping nproc

The intended sweep is `nproc ∈ {1, 4, 16, 32, 64, 96}`. The Slurm scripts in
`slurm/` drive this sweep by looping `srun` calls (one per `nproc` value)
inside a single job, so a single submission produces a full sweep.

## Slurm job scripts

Three scripts live in the project root:

| Script | Purpose |
|--------|---------|
| `job.sh` | One sbatch job — reads or writes against the storage on the allocated nodes. |
| `loop-1node.sh` | Submits a sweep of 1-node `job.sh` jobs across `nproc ∈ {1, 8, 32, 64, 96}` and partitions `{GPU1, GPU2}` for both `read` and `write`. |
| `loop-multinode.sh` | Submits a sweep of multinode `job.sh` jobs across `Nnodes ∈ {2, 4, 8, 12}`, `nproc ∈ {32, 64, 96}`, partitions `{GPU1, GPU2}`, for both `read` and `write`. |
| `squential-loop-multinode.sh` | Same sweep as `loop-multinode.sh`, but submits every job with a shared `--job-name` and `--dependency=singleton` so SLURM runs them strictly one-at-a-time (no two ever in RUNNING state simultaneously). |

### Submit a single job

```bash
sbatch job.sh read           # 1 node, default 96 cpus, GPU2, 2 h
sbatch job.sh write
```

Override resources on the command line:

```bash
sbatch -N 4 --ntasks-per-node=64 -p GPU1 job.sh read
sbatch -N 1 --ntasks-per-node=32 -p GPU2 job.sh write my_tag
```

`job.sh` takes one required argument (`read` or `write`) and an optional second
argument used as a result-dir prefix.

### Submit a sweep

```bash
./loop-1node.sh
./loop-multinode.sh
```

Each loop iteration computes a tag like `1node_96cpu_GPU2` or `4node_64cpu_GPU1`
and passes it to `job.sh`. To customize the sweep ranges, edit the `for` lists
at the top of the script.

### Submit a sequential sweep

`squential-loop-multinode.sh` submits every job in the sweep with a shared
`--job-name` (default `dataloader-sweep`) and `--dependency=singleton`. SLURM
then enforces that only one job with that name runs at a time — all others
sit in the queue and start in submission order as the running one finishes.

```bash
./squential-loop-multinode.sh
```

The script returns as soon as all jobs are queued, so logout is irrelevant —
SLURM holds the dependency chain. Inspect with:

```bash
squeue -u $USER -n dataloader-sweep   # all queued/running sweep jobs
```

Each job's actual tag (`<Nnodes>node_<ncpus>cpu_<partition>`) lives in the
output path `output/<tag>/` and the result dir `results/<tag>_<jobid>/`, since
the SLURM job name is shared across the sweep.

### What each job does

1. Sets `OUT_DIR=results/<tag>_<jobid>` and `mkdir -p` it.
2. Runs `srun -n $SLURM_NNODES --ntasks-per-node=1 python {read,write}_benchmark.py
   --nproc $SLURM_NTASKS_PER_NODE ...` — one Python process per node, each
   using its full CPU allocation via `multiprocessing.Pool`.
3. Each task writes its own `results.<host>.<rank>.csv` into `OUT_DIR`.
4. At the end, concatenates all per-task CSVs into `OUT_DIR/all.csv`.

### Outputs

```
results/1node_96cpu_GPU2_<jobid>/
    results.<host>.<rank>.csv     # one per python rank
    all.csv                       # concatenated

results/4node_64cpu_GPU1_<jobid>/
    results.<host0>.<rank>.csv
    results.<host1>.<rank>.csv
    ...                           # one per node
    all.csv

output/1node_96cpu_GPU2/
    <jobname>_<node>_<jobid>.out  # SLURM stdout/stderr (unique per submission)
```

### Volume notes for the write benchmark

Vast `/work/mit/datasets/test` allows up to 1 TB resident. Peak resident is
`nodes * nproc * files_per_proc * file_size` during an iter (files are
deleted between iters).

- **Single-node** (`write_1node.sbatch`) uses `--files-per-proc 8`. Peak at
  `nproc=96, file_size=100M` is `96 * 8 * 100 MiB ≈ 76 GiB`. Well under quota.
- **Multi-node** (`write_multinode.sbatch`) uses `--files-per-proc 4` so that
  even at 16 nodes the peak (`16 * 96 * 4 * 100 MiB ≈ 614 GiB`) stays under
  1 TB.

If you change node count up or `files_per_proc` up, recompute the peak before
submitting.

### Pre-built file index for the read benchmark

The first read job will walk the ImageNet tree (~1.2M files) once and cache
the result to `./.imagenet_index.txt`. Subsequent jobs reuse the cache, so
the walk overhead only happens once. The cache lives next to the scripts; do
not delete unless the dataset layout changes.

### Aggregating results

`all.csv` already has rows from every host and every (nproc, mode, size,
iter). To group/sum in pandas:

```python
import pandas as pd
df = pd.read_csv("results/read_mn_<jobid>/all.csv")
agg = (df.groupby(["mode", "nproc"])["GBps"]
         .agg(["mean", "std", "count"]).reset_index())
print(agg)
```

For multi-node aggregate throughput at one (mode, nproc, size, iter), sum
across hosts:

```python
mn = (df.groupby(["mode", "nproc", "iter_idx"])["GBps"].sum()
        .groupby(level=[0, 1]).agg(["mean", "std"]))
```
