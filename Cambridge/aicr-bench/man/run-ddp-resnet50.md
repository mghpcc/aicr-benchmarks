# run-ddp-resnet50.sh

## Purpose

Run fixed-iteration PyTorch DDP ResNet-50 inside a Slurm allocation and write canonical raw and parsed artifacts.

This script is normally launched by `submit-ddp-resnet50.sh` through a Slurm wrapper.

## Usage

```text
scripts/benchmark/run-ddp-resnet50.sh [--profile <small|medium|large>] [--inspect-profile] [--launcher <torchrun|srun>] [--dataset-root <path>] [--split <train|val>] [--image <path>] [--batch-size <n>] [--num-workers <n>] [--prefetch-factor <n>] [--pin-memory <0|1>] [--persistent-workers <0|1>] [--warmup-iters <n>] [--measured-iters <n>] [--precision <bf16|fp32>] [--channels-last <0|1>] [--drop-last <0|1>]
```

## Options

- `--profile <name>`: `small`, `medium`, or `large`. Controls workload intensity defaults only.
- `--inspect-profile`: Print the selected profile without running the workload.
- `--launcher <name>`: `torchrun` or `srun`.
- `--dataset-root <path>`: ImageFolder root containing `train/` and `val/`.
- `--split <name>`: `train` or `val`.
- `--image <path>`: PyTorch Apptainer image.
- `--batch-size <n>`: Per-rank batch size.
- `--num-workers <n>`: DataLoader workers per rank.
- `--prefetch-factor <n>`: DataLoader prefetch factor when workers are enabled.
- `--pin-memory <0|1>`: Enable or disable pinned host memory.
- `--persistent-workers <0|1>`: Keep workers alive across iterator resets when workers are enabled.
- `--warmup-iters <n>`: Untimed warmup iterations.
- `--measured-iters <n>`: Timed training iterations.
- `--precision <bf16|fp32>`: Training autocast mode.
- `--channels-last <0|1>`: Use channels-last tensor layout.
- `--drop-last <0|1>`: Drop incomplete DataLoader batches.
- `--help`: Print help.

## Outputs

```text
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/
results/by-date/<date>/parsed/<cluster>/multi-node/ddp-resnet50/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/multi-node/ddp-resnet50/<run_id>/status.json
```

Canonical status comes from parsed `summary.json` and `status.json`.
