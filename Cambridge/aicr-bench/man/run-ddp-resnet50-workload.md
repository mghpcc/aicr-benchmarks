# run-ddp-resnet50-workload.py

## Purpose

Run the in-container fixed-iteration PyTorch DDP ResNet-50 workload and write
rank-local plus aggregate metrics. This is the workload engine called by
`run-ddp-resnet50.sh`; users normally launch it through the Slurm wrapper or
`submit-ddp-resnet50.sh`.

## Usage

```text
scripts/benchmark/run-ddp-resnet50-workload.py --dataset-root <path> --run-id <id> --output-dir <dir> --summary-output <path> --status-output <path> [options]
```

The runner expects a Slurm or torch distributed environment with rank variables
such as `RANK`, `WORLD_SIZE`, and `LOCAL_RANK`.

## Options

- `--dataset-root <path>`: ImageNet root containing the requested split.
- `--split <train|val>`: Dataset split. Default: `train`.
- `--batch-size <n>`: Per-rank batch size.
- `--num-workers <n>`: PyTorch DataLoader workers per rank.
- `--prefetch-factor <n>`: PyTorch DataLoader prefetch factor when workers are enabled.
- `--pin-memory <0|1>`: Enable page-locked host memory.
- `--persistent-workers <0|1>`: Keep workers alive across iterator resets when workers are enabled.
- `--drop-last <0|1>`: Drop incomplete DataLoader batches.
- `--warmup-iters <n>`: Untimed warmup iterations.
- `--measured-iters <n>`: Timed training iterations.
- `--precision <bf16|fp32>`: Training autocast mode.
- `--channels-last <0|1>`: Use channels-last tensor layout.
- `--launcher <torchrun|srun>`: Launcher label for metadata.
- `--run-id <id>`: Run identifier written into artifacts.
- `--node-list <csv>`: Comma-separated node list for metadata.
- `--output-dir <dir>`: Directory for per-rank JSON metrics.
- `--summary-output <path>`: Aggregate summary JSON path.
- `--status-output <path>`: Aggregate status JSON path.
- `--local-rank <n>`: Local rank override.

## Outputs

The workload writes one rank JSON file per rank, an aggregate `summary.json`,
and a `status.json`. Metrics include images/s, rank imbalance, data wait time,
H2D/input preparation time, training step time, precision, layout, and dataset
metadata.

`run-ddp-resnet50.sh` wraps these outputs with the canonical raw and parsed
artifact layout used by AICR-Bench.

## Notes

This script is an internal workload engine. Prefer `run-ddp-resnet50.sh` or
`submit-ddp-resnet50.sh` for supported command-line use.
