# sweep-dataloader.sh

## Purpose

Preview or submit a DataLoader matrix through the host-side one-job submitter.

## Usage

```text
scripts/benchmark/sweep-dataloader.sh [--cluster <b200|rtxpro6000>] [--profile <small|medium|large>] [--inspect-profile] [--nodes-list <csv>] [--gpu-count <1|8>] [--mode <single|replicated|distributed-sharded>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--repeat-count <n>] [--input-backend-list <csv>] [--num-workers-list <csv>] [--batch-size-list <csv>] [--prefetch-factor-list <csv>] [--dali-num-threads-list <csv>] [--dali-prefetch-queue-depth-list <csv>] [--dali-decode-mode-list <csv>] [--dali-hw-decoder-load-list <csv>] [--pin-memory-list <csv>] [--persistent-workers-list <csv>] [--cpus-per-task <n>] [--cpus-per-task-list <csv>] [--mem <size>] [--mem-list <csv>] [--dependency <slurm-dependency>] [--partition <name>] [--time <HH:MM:SS>] [--nodelist <node[,node...]>] [--apply] [--] [runner args...]
```

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--profile <name>`: `small`, `medium`, or `large`. Controls runner workload intensity defaults only.
- `--inspect-profile`: Print the selected profile without submitting jobs.
- `--nodes-list <csv>`: Node-count axis for scale sweeps. B200 and RTX accept `1,2,4,8,16`.
- `--nodes <csv>`: Compatibility alias for `--nodes-list`.
- `--gpu-count <1|8>`: One GPU or eight GPUs per node.
- `--mode <name>`: `single`, `replicated`, or `distributed-sharded`.
- `--from-node-report`: Select passed nodes for the selected cluster from the latest node report.
- `--date <value>`: Node-report date for `--from-node-report`. Default: `today`.
- `--repeat-count <n>`: Submit each matrix point multiple times.
- `--input-backend-list <csv>`: Input backend axis. Supported values are
  `pytorch-cpu-dataloader`, `dali-gpu-decode`, `numpy-uint8-shards`,
  `numpy-fp16-shards`, `numpy-fp16-blocks-pytorch`,
  `dali-numpy-fp16-cpu`, `dali-numpy-fp16-gds`,
  `dali-numpy-fp16-blocks-cpu`, and `dali-numpy-fp16-blocks-gds`.
- `--num-workers-list <csv>`: DataLoader worker-count axis.
- `--batch-size-list <csv>`: Per-rank batch-size axis.
- `--prefetch-factor-list <csv>`: DataLoader prefetch-factor axis.
- `--dali-num-threads-list <csv>`: DALI worker-thread axis for DALI JPEG and
  DALI NumPy backend runs.
- `--dali-prefetch-queue-depth-list <csv>`: DALI pipeline prefetch queue-depth
  axis for DALI JPEG and DALI NumPy backend runs.
- `--dali-numpy-reader-prefetch-queue-depth-list <csv>`: Reader-level prefetch
  queue-depth axis for DALI NumPy file and block readers.
- `--dali-decode-mode-list <csv>`: DALI JPEG decode mode axis: `random-crop`
  or `decode-resize`.
- `--dali-hw-decoder-load-list <csv>`: DALI JPEG hardware decoder load axis.
- `--pin-memory-list <csv>`: `0` or `1`.
- `--persistent-workers-list <csv>`: `0` or `1`.
- `--cpus-per-task <n>`: Fixed CPU allocation.
- `--cpus-per-task-list <csv>`: CPU allocation axis.
- `--mem <size>`: Fixed Slurm memory request forwarded to each point. Default:
  `0`.
- `--mem-list <csv>`: Slurm memory-request axis. Use this only for memory
  diagnostics; normal points inherit the submitter default `--mem=0`.
- `--dependency <value>`: Forward a Slurm dependency to each submitted job.
- `--partition <name>`: Override Slurm partition.
- `--time <HH:MM:SS>`: Override Slurm time limit.
- `--nodelist <node[,node...]>`: Explicit ordered node pool. Each sweep point takes the first `N` nodes for its requested node count.
- `--apply`: Submit jobs. Omit for dry-run preview.
- `-- <runner args...>`: Forward non-swept runner arguments.
- `--help`: Print help.

## Common Patterns

- CPU DataLoader tuning: sweep `--batch-size-list`, `--num-workers-list`, and
  `--prefetch-factor-list` with `--input-backend-list pytorch-cpu-dataloader`.
- DALI tuning: sweep `--batch-size-list`, `--dali-num-threads-list`, and
  `--dali-prefetch-queue-depth-list` with `--input-backend-list dali-gpu-decode`.
  For DALI NumPy GDS work, also sweep
  `--dali-numpy-reader-prefetch-queue-depth-list`.
- Prepared-input ceilings: sweep `numpy-uint8-shards`, `numpy-fp16-shards`,
  `numpy-fp16-blocks-pytorch`, `dali-numpy-fp16-cpu`,
  `dali-numpy-fp16-gds`, and DALI block variants with explicit
  `--derived-root`, `--derived-image-size`, `--derived-samples-per-class`, and
  `--derived-seed` runner arguments.
- Multi-node scale probes: use `--nodes-list` with `--mode
  distributed-sharded` and an ordered `--nodelist` large enough for the largest
  scale.
- Memory diagnostics: use `--mem-list` only when intentionally testing Slurm
  cgroup behavior; normal rows inherit the submitter default `--mem=0`.

## Examples

Preview one RTX single-GPU point:

```bash
scripts/benchmark/sweep-dataloader.sh --cluster rtxpro6000 --gpu-count 1 --mode single --nodelist a0002 --num-workers-list 8 --batch-size-list 256 --prefetch-factor-list 4 -- --warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0
```

Preview B200 worker-count points:

```bash
scripts/benchmark/sweep-dataloader.sh --cluster b200 --gpu-count 8 --mode replicated --nodelist b0001 --num-workers-list 8,16 --batch-size-list 256 --prefetch-factor-list 4
```

Preview a B200 CPU-allocation axis:

```bash
scripts/benchmark/sweep-dataloader.sh --cluster b200 --gpu-count 8 --mode replicated --nodelist b0001 --batch-size-list 64 --num-workers-list 4 --prefetch-factor-list 2 --pin-memory-list 1 --persistent-workers-list 0 --cpus-per-task-list 4,8,16 -- --warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0
```

Preview a B200 scale axis:

```bash
scripts/benchmark/sweep-dataloader.sh --cluster b200 --nodes-list 1,2,4,8,16 --gpu-count 8 --mode distributed-sharded --nodelist b0001,b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0013,b0014,b0015,b0016,b0017 --batch-size-list 64 --num-workers-list 8 --prefetch-factor-list 2 --pin-memory-list 1 --persistent-workers-list 1 --cpus-per-task 16 -- --warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0
```

Preview an RTX scale axis:

```bash
scripts/benchmark/sweep-dataloader.sh --cluster rtxpro6000 --nodes-list 1,2,4,8 --gpu-count 8 --mode distributed-sharded --nodelist a0001,a0002,a0003,a0004,a0005,a0006,a0007,a0008 --batch-size-list 64 --num-workers-list 8 --prefetch-factor-list 2 --pin-memory-list 1 --persistent-workers-list 1 --cpus-per-task 16 -- --warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0
```
