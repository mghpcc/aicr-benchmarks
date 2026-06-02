# run-ddp-resnet50-workload.py

## Purpose

Run the in-container fixed-iteration PyTorch DDP ResNet-50 workload and write
rank-local plus aggregate metrics. This is the workload engine called by
[run-ddp-resnet50.sh](run-ddp-resnet50.md); users normally launch it through the
Slurm wrapper or [submit-ddp-resnet50.sh](submit-ddp-resnet50.md).

## Usage

```text
scripts/lib/run-repo-python.sh scripts/benchmark/run-ddp-resnet50-workload.py --dataset-root <path> --run-id <id> --output-dir <dir> --summary-output <path> --status-output <path> [options]
```

The runner expects a Slurm or torch distributed environment with rank variables
such as `RANK`, `WORLD_SIZE`, and `LOCAL_RANK`.

## Options

- `--dataset-root <path>`: ImageNet root containing the requested split.
- `--split <train|val>`: Dataset split. Default: `train`.
- `--input-backend <name>`: `pytorch-cpu-dataloader`, `dali-gpu-decode`,
  `numpy-uint8-shards`, `numpy-fp16-shards`,
  `numpy-fp16-blocks-pytorch`, `dali-numpy-fp16-blocks-gds`, or
  `synthetic-gpu`.
- `--derived-root <path>`: Derived dataset root for NumPy and DALI NumPy block
  input backends.
- `--derived-image-size <n>`: Derived image-size selector.
- `--derived-samples-per-class <n>`: Derived subset selector.
- `--derived-seed <n>`: Derived subset seed selector.
- `--batch-size <n>`: Per-rank batch size.
- `--num-workers <n>`: PyTorch DataLoader workers per rank.
- `--prefetch-factor <n>`: PyTorch DataLoader prefetch factor when workers are enabled.
- `--dali-num-threads <n>`: DALI pipeline thread count.
- `--dali-prefetch-queue-depth <n>`: DALI pipeline prefetch queue depth.
- `--dali-numpy-reader-prefetch-queue-depth <n>`: Reader-level prefetch queue
  depth for DALI NumPy block readers.
- `--dali-decode-mode <random-crop|decode-resize>`: DALI decode policy.
- `--dali-hw-decoder-load <float>`: DALI mixed-decoder hardware load hint.
- `--dali-gds-chunk-size <value>`: Optional `DALI_GDS_CHUNK_SIZE` value for
  DALI NumPy GDS reader experiments.
- `--numpy-block-cache-size <n>`: Per-worker mmap block cache size for the
  PyTorch NumPy block backend.
- `--cufile-log-path <path>`: Optional cuFile log path for DALI NumPy GDS rows.
- `--cufile-log-level <level>`: Optional `CUFILE_LOGGING_LEVEL` for GDS rows
  with a cuFile log path. Defaults to `INFO` when a path is set.
- `--prepared-block-label-source <synthetic-gpu>`: Label source for DALI
  prepared-block DDP rows; image transport remains the measured GDS path.
- `--synthetic-class-count <n>`: Synthetic class count for synthetic GPU input.
- `--synthetic-image-size <n>`: Synthetic GPU input image size.
- `--synthetic-dtype <float32|float16|bfloat16>`: Synthetic GPU input dtype.
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

[run-ddp-resnet50.sh](run-ddp-resnet50.md) wraps these outputs with the canonical raw and parsed
artifact layout used by AICR-Bench.

## Notes

This script is a low-level workload engine. Prefer
[run-ddp-resnet50.sh](run-ddp-resnet50.md) or
[submit-ddp-resnet50.sh](submit-ddp-resnet50.md) for supported command-line use.
