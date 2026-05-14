# submit-ddp-resnet50.sh

## Purpose

Preview or submit one fixed-iteration PyTorch DDP ResNet-50 Slurm job for explicit AICR GPU nodes.

## Usage

```text
scripts/benchmark/submit-ddp-resnet50.sh [--cluster <b200|rtxpro6000>] [--profile <small|medium|large>] [--inspect-profile] --nodes <1|2|4|8|16> [--launcher <torchrun|srun>] [--nodelist <csv>] [--partition <name>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--apply] [--] [run-ddp-resnet50 args...]
```

The public Make entrypoint is:

```bash
make benchmark-ddp-resnet50 CLUSTER=<b200|rtxpro6000> PROFILE=<small|medium|large> DDP_NODES=<1|2|4|8|16> NODELIST=<node[,node...]>
```

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--profile <name>`: `small`, `medium`, or `large`. Controls workload intensity defaults only.
- `--inspect-profile`: Print the selected profile without submitting a job.
- `--nodes <n>`: Node count. B200 accepts `1`, `2`, `4`, `8`, or `16`; RTX accepts `1`, `2`, `4`, or `8`.
- `--launcher <name>`: `torchrun` or `srun`. Default: `torchrun`.
- `--partition <name>`: Override Slurm partition.
- `--time <HH:MM:SS>`: Override Slurm time limit.
- `--cpus-per-task <n>`: CPU allocation per Slurm task.
- `--nodelist <nodes>`: Explicit node or comma-separated nodes.
- `--apply`: Submit the job. Omit for dry-run preview.
- `-- <runner args...>`: Forward remaining arguments to `run-ddp-resnet50.sh`.
- `--help`: Print help.

## Examples

Preview one RTX DDP job:

```bash
scripts/benchmark/submit-ddp-resnet50.sh --cluster rtxpro6000 --nodes 1 --nodelist a0002 -- --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0
```

Inspect the small profile:

```bash
scripts/benchmark/submit-ddp-resnet50.sh --profile small --inspect-profile
```

Preview one B200 two-node DDP job:

```bash
scripts/benchmark/submit-ddp-resnet50.sh --cluster b200 --nodes 2 --nodelist b0001,b0002 -- --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0
```

Submit one explicit RTX teaching job:

```bash
scripts/benchmark/submit-ddp-resnet50.sh --cluster rtxpro6000 --nodes 1 --nodelist a0002 --apply -- --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0
```
