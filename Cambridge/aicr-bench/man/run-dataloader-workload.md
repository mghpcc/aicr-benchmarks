# run-dataloader-workload.py

## Purpose

Run the in-container PyTorch DataLoader workload for one rank and write a
rank-local metrics JSON file. This is the workload engine called by
[run-dataloader.sh](run-dataloader.md); users normally launch it through the Slurm wrappers,
submitter, sweep helper, or Make targets.

## Usage

```text
scripts/lib/run-repo-python.sh scripts/benchmark/run-dataloader-workload.py --dataset-root <path> [--input-backend <pytorch-cpu-dataloader|dali-gpu-decode|numpy-uint8-shards|numpy-fp16-shards|numpy-fp16-blocks-pytorch|dali-numpy-fp16-cpu|dali-numpy-fp16-gds|dali-numpy-fp16-blocks-cpu|dali-numpy-fp16-blocks-gds>] --batch-size <n> --num-workers <n> --prefetch-factor <n> --pin-memory <0|1> --persistent-workers <0|1> --warmup-batches <n> --measured-batches <n> [options] --output <path>
```

Use `--output-dir <dir>` instead of `--output <path>` for multi-rank launches.

## Options

- `--dataset-root <path>`: ImageNet root containing `train/` and `val/`.
- `--split <train|val>`: Dataset split. Default: `train`.
- `--input-backend <name>`: Data path for DataLoader-only comparisons. Supported
  values are `pytorch-cpu-dataloader`, `dali-gpu-decode`,
  `numpy-uint8-shards`, `numpy-fp16-shards`, `numpy-fp16-blocks-pytorch`,
  `dali-numpy-fp16-cpu`, `dali-numpy-fp16-gds`,
  `dali-numpy-fp16-blocks-cpu`, and `dali-numpy-fp16-blocks-gds`.
- `--numpy-block-cache-size <n>`: per-worker mmap block cache size for the
  PyTorch NumPy block backend.
- `--derived-root <path>`: Derived dataset root for NumPy shard and DALI NumPy
  file backends. On
  AICR HPC, prefer scratch-hosted roots for regenerated datasets unless durable
  storage is intentional.
- `--derived-image-size <n>`: Derived image-size selector.
- `--derived-samples-per-class <n>`: Derived subset selector.
- `--derived-seed <n>`: Derived subset seed selector.
- `--batch-size <n>`: Per-rank batch size.
- `--num-workers <n>`: PyTorch DataLoader workers per rank.
- `--prefetch-factor <n>`: PyTorch DataLoader prefetch factor when workers are enabled.
- `--pin-memory <0|1>`: Enable page-locked host memory.
- `--persistent-workers <0|1>`: Keep workers alive across iterator resets when workers are enabled.
- `--dali-num-threads <n>`: DALI CPU worker threads for DALI backend runs.
- `--dali-prefetch-queue-depth <n>`: DALI pipeline prefetch queue depth.
- `--dali-numpy-reader-prefetch-queue-depth <n>`: Reader-level prefetch queue
  depth for DALI NumPy file and block readers. Defaults to `1`.
- `--dali-decode-mode <random-crop|decode-resize>`: DALI decode policy.
- `--dali-hw-decoder-load <float>`: DALI hardware decoder load hint.
- `--dali-gds-chunk-size <value>`: Optional `DALI_GDS_CHUNK_SIZE` value set
  before DALI pipeline construction for `dali-numpy-fp16-gds` experiments,
  such as `2097152` or `2M`. Has no effect for any other backend; recorded in
  `dataloader-metrics.json` as `dali_gds_chunk_size` only when the GDS reader
  path is selected.
- `--cufile-log-path <path>`: Optional cuFile log file for DALI NumPy GDS rows.
  Multi-rank callers may include `{rank}` in the path.
- `--cufile-log-level <level>`: Optional `CUFILE_LOGGING_LEVEL` for GDS rows with
  a cuFile log path. Defaults to `INFO` when a path is set.
- `--warmup-batches <n>`: Untimed batches before measurement.
- `--measured-batches <n>`: Timed batches.
- `--selected-gpu <index>`: GPU index for single-rank launches.
- `--sampler-mode <single|replicated|distributed-sharded>`: Dataset sampling mode.
- `--rank <n>`: Rank override. Defaults to launcher environment.
- `--world-size <n>`: World-size override. Defaults to launcher environment.
- `--local-rank <n>`: Local rank override. Defaults to launcher environment.
- `--node-rank <n>`: Node rank override. Defaults to launcher environment.
- `--local-gpu-index <n>`: CUDA device index for this rank.
- `--node-list <csv>`: Comma-separated node list for metadata.
- `--node-count <n>`: Node count for metadata.
- `--launcher <name>`: Launcher label for metadata.
- `--epoch <n>`: Distributed sampler epoch.
- `--h2d <0|1>`: Include host-to-device transfer in the measured path.
- `--transfer-labels <0|1>`: Transfer labels when H2D is enabled.
- `--drop-last <0|1>`: Drop incomplete final batches.
- `--byte-estimate-sample-count <n>`: Number of ImageFolder paths to stat for estimated read volume; `0` disables the estimate.
- `--output <path>`: Metrics JSON path for single-rank launches.
- `--output-dir <dir>`: Metrics root for multi-rank launches.

## Outputs

The workload writes `dataloader-metrics.json` with status, rank metadata,
dataset metadata, batch counts, elapsed time, samples/s, load timing, H2D timing,
worker CPU utilization, evidence-scope labels, delivery endpoint labels,
GDS/DALI NumPy reader fields when applicable,
file-descriptor limit provenance, and estimated read volume when enabled.

[run-dataloader.sh](run-dataloader.md) consumes these rank-local metrics and writes the canonical
summary, status, record, stdout, and stderr artifacts.

## Notes

This script is a low-level workload engine. Prefer [run-dataloader.sh](run-dataloader.md),
[submit-dataloader.sh](submit-dataloader.md), [sweep-dataloader.sh](sweep-dataloader.md), or `make benchmark-dataloader`
for supported command-line use.
