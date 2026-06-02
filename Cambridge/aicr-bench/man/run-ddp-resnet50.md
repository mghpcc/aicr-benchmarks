# run-ddp-resnet50.sh

## Purpose

Run fixed-iteration PyTorch DDP ResNet-50 inside a Slurm allocation and write canonical raw and parsed artifacts.

This script is normally launched by
[submit-ddp-resnet50.sh](submit-ddp-resnet50.md) through a Slurm wrapper.

## Usage

```text
scripts/benchmark/run-ddp-resnet50.sh [--launcher <torchrun|srun>] [--dataset-root <path>] [--split <train|val>] [--image <path>] [--input-backend <pytorch-cpu-dataloader|dali-gpu-decode|numpy-uint8-shards|numpy-fp16-shards|numpy-fp16-blocks-pytorch|dali-numpy-fp16-blocks-gds|synthetic-gpu>] [--derived-root <path>] [--derived-image-size <n>] [--derived-samples-per-class <n>] [--derived-seed <n>] [--batch-size <n>] [--num-workers <n>] [--prefetch-factor <n>] [--dali-num-threads <n>] [--dali-prefetch-queue-depth <n>] [--dali-numpy-reader-prefetch-queue-depth <n>] [--dali-decode-mode <random-crop|decode-resize>] [--dali-hw-decoder-load <float>] [--dali-gds-chunk-size <value>] [--numpy-block-cache-size <n>] [--cufile-log-path <path>] [--cufile-log-level <level>] [--synthetic-class-count <n>] [--synthetic-image-size <n>] [--synthetic-dtype <float32|float16|bfloat16>] [--pin-memory <0|1>] [--persistent-workers <0|1>] [--warmup-iters <n>] [--measured-iters <n>] [--precision <bf16|fp32>] [--channels-last <0|1>] [--drop-last <0|1>]
```

## Options

- `--launcher <name>`: `torchrun` or `srun`.
- `--dataset-root <path>`: ImageFolder root containing `train/` and `val/`.
- `--split <name>`: `train` or `val`.
- `--image <path>`: PyTorch Apptainer image.
- `--input-backend <name>`: `pytorch-cpu-dataloader`, `dali-gpu-decode`,
  `numpy-uint8-shards`, `numpy-fp16-shards`,
  `numpy-fp16-blocks-pytorch`, `dali-numpy-fp16-blocks-gds`, or
  `synthetic-gpu`.
- `--derived-root <path>`: Derived NumPy shard root for NumPy input backends.
  On AICR HPC, prefer scratch-hosted roots for regenerated datasets unless
  durable storage is intentional.
- `--derived-image-size <n>`: Derived image size for shard metadata.
- `--derived-samples-per-class <n>`: Derived samples per class.
- `--derived-seed <n>`: Derived dataset seed.
- `--numpy-block-cache-size <n>`: Per-worker mmap block cache size for the
  PyTorch NumPy block backend.
- `--batch-size <n>`: Per-rank batch size.
- `--num-workers <n>`: DataLoader workers per rank.
- `--prefetch-factor <n>`: DataLoader prefetch factor when workers are enabled.
- `--dali-num-threads <n>`: DALI pipeline thread count. `0` follows the worker count.
- `--dali-prefetch-queue-depth <n>`: DALI prefetch queue depth.
- `--dali-numpy-reader-prefetch-queue-depth <n>`: Reader-level prefetch queue
  depth for DALI NumPy block readers.
- `--dali-decode-mode <name>`: DALI decode path, `random-crop` or `decode-resize`.
- `--dali-hw-decoder-load <float>`: DALI mixed-decoder hardware load hint.
- `--dali-gds-chunk-size <value>`: Optional `DALI_GDS_CHUNK_SIZE` value for
  DALI NumPy GDS reader experiments.
- `--cufile-log-path <path>`: Optional cuFile log path for DALI NumPy GDS rows.
- `--cufile-log-level <level>`: Optional `CUFILE_LOGGING_LEVEL` for GDS rows
  with a cuFile log path. Defaults to `INFO` when a path is set.
- `--synthetic-class-count <n>`: Synthetic class count for synthetic GPU input.
- `--synthetic-image-size <n>`: Synthetic GPU input image size.
- `--synthetic-dtype <name>`: Synthetic GPU input dtype, `float32`, `float16`, or `bfloat16`.
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
