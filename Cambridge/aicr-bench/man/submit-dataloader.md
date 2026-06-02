# submit-dataloader.sh

## Purpose

Preview or submit one PyTorch DataLoader Slurm job for explicit AICR GPU nodes.
This is the host-side one-job submitter; use
[sweep-dataloader.sh](sweep-dataloader.md) for parameter matrices.

## Usage

```text
scripts/benchmark/submit-dataloader.sh [--cluster <b200|rtxpro6000>] [--profile <small|medium|large>] [--inspect-profile] [--nodes <n>] [--gpu-count <1|8>] [--mode <single|replicated|distributed-sharded>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--partition <name>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--mem <size>] [--dependency <slurm-dependency>] [--nodelist <nodes>] [--apply] [--] [runner args...]
```

The Make entrypoint is:

```bash
make benchmark-dataloader CLUSTER=<b200|rtxpro6000> PROFILE=<small|medium|large> GPU_COUNT=<1|8> MODE=<single|replicated|distributed-sharded> NODELIST=<node[,node...]>
```

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--profile <name>`: `small`, `medium`, or `large`. Controls workload intensity defaults only.
- `--inspect-profile`: Print the selected profile without submitting a job.
- `--nodes <n>`: Node count. B200 and RTX accept `1`, `2`, `4`, `8`, or `16`.
- `--gpu-count <1|8>`: Selects one-GPU or eight-GPU wrappers.
- `--mode <name>`: `single`, `replicated`, or `distributed-sharded`.
- `--from-node-report`: Select passed nodes for the selected cluster from the latest node report.
- `--date <value>`: Node-report date for `--from-node-report`. Default: `today`.
- `--partition <name>`: Override Slurm partition.
- `--time <HH:MM:SS>`: Override Slurm time limit.
- `--cpus-per-task <n>`: CPU allocation per Slurm task.
- `--mem <size>`: Slurm memory request. Default: `0`, so the job receives the
  node memory cgroup.
- `--dependency <value>`: Forward a Slurm dependency to `sbatch`.
- `--nodelist <nodes>`: Explicit node or comma-separated nodes.
- `--apply`: Submit the job. Omit for dry-run preview.
- `-- <runner args...>`: Forward remaining arguments to [run-dataloader.sh](run-dataloader.md).
- `--help`: Print help.

## Examples

Preview one RTX single-GPU job:

```bash
scripts/benchmark/submit-dataloader.sh --cluster rtxpro6000 --gpu-count 1 --mode single --nodelist a0002 -- --warmup-batches 100 --measured-batches 500 --num-workers 0 --byte-estimate-sample-count 0
```

Inspect the small profile:

```bash
scripts/benchmark/submit-dataloader.sh --profile small --inspect-profile
```

Preview one B200 replicated job:

```bash
scripts/benchmark/submit-dataloader.sh --cluster b200 --gpu-count 8 --mode replicated --nodelist b0001 -- --batch-size 256 --num-workers 8 --prefetch-factor 4
```

Submit one explicit RTX single-GPU job:

```bash
scripts/benchmark/submit-dataloader.sh --cluster rtxpro6000 --gpu-count 1 --mode single --nodelist a0002 --apply -- --warmup-batches 100 --measured-batches 500 --num-workers 0 --byte-estimate-sample-count 0
```
