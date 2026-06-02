# submit-ddp-resnet50.sh

## Purpose

Preview or submit one fixed-iteration PyTorch DDP ResNet-50 Slurm job for explicit AICR GPU nodes.

## Usage

```text
scripts/benchmark/submit-ddp-resnet50.sh [--cluster <b200|rtxpro6000>] --nodes <1|2|4|8|16> [--launcher <torchrun|srun>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--nodelist <csv>] [--partition <name>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--mem <size>] [--repeat-count <n>] [--repeat-stagger-seconds <n>] [--apply] [--] [run-ddp-resnet50 args...]
```

The public Make entrypoint is:

```bash
make benchmark-ddp-resnet50 CLUSTER=<b200|rtxpro6000> NODES=<1|2|4|8|16> NODELIST=<node[,node...]> DDP_RUN_ARGS="<runner args>"
```

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--nodes <n>`: Node count. B200 accepts `1`, `2`, `4`, `8`, or `16`; RTX accepts `1`, `2`, or `4`.
- `--launcher <name>`: `torchrun` or `srun`. Default: `torchrun`.
- `--from-node-report`: Select passed nodes for the selected cluster from the latest node report.
- `--date <value>`: Node-report date for `--from-node-report`. Default: `today`.
- `--partition <name>`: Override Slurm partition.
- `--time <HH:MM:SS>`: Override Slurm time limit.
- `--cpus-per-task <n>`: CPU allocation per Slurm task.
- `--mem <size>`: Slurm memory request. Default: `0`, which grants the
  node memory cgroup for full-node DDP rows.
- `--nodelist <nodes>`: Explicit node or comma-separated nodes.
- `--repeat-count <n>`: Submit the same shape multiple times. Default: `1`.
- `--repeat-stagger-seconds <n>`: Seconds between repeated submissions. Default: `30`.
- `--apply`: Submit the job. Omit for dry-run preview.
- `-- <runner args...>`: Forward remaining arguments to [run-ddp-resnet50.sh](run-ddp-resnet50.md).
- `--help`: Print help.

## Examples

Preview one RTX DDP job:

```bash
scripts/benchmark/submit-ddp-resnet50.sh --cluster rtxpro6000 --nodes 1 --nodelist a0002 -- --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0
```

Inspect the submitter help:

```bash
scripts/benchmark/submit-ddp-resnet50.sh --help
```

Preview one B200 two-node DDP job:

```bash
scripts/benchmark/submit-ddp-resnet50.sh --cluster b200 --nodes 2 --nodelist b0001,b0002 -- --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0
```

Submit one explicit RTX teaching job:

```bash
scripts/benchmark/submit-ddp-resnet50.sh --cluster rtxpro6000 --nodes 1 --nodelist a0002 --apply -- --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0
```
