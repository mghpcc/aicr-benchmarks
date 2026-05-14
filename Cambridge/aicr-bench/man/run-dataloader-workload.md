# run-dataloader-workload.py

## Purpose

Run the in-container PyTorch DataLoader workload for one rank and write a
rank-local metrics JSON file. This is the workload engine called by
`run-dataloader.sh`; users normally launch it through the Slurm wrappers,
submitter, sweep helper, or Make targets.

## Usage

```text
scripts/benchmark/run-dataloader-workload.py --dataset-root <path> --batch-size <n> --num-workers <n> --prefetch-factor <n> --pin-memory <0|1> --persistent-workers <0|1> --warmup-batches <n> --measured-batches <n> [options] --output <path>
```

Use `--output-dir <dir>` instead of `--output <path>` for multi-rank launches.

## Options

- `--dataset-root <path>`: ImageNet root containing `train/` and `val/`.
- `--split <train|val>`: Dataset split. Default: `train`.
- `--batch-size <n>`: Per-rank batch size.
- `--num-workers <n>`: PyTorch DataLoader workers per rank.
- `--prefetch-factor <n>`: PyTorch DataLoader prefetch factor when workers are enabled.
- `--pin-memory <0|1>`: Enable page-locked host memory.
- `--persistent-workers <0|1>`: Keep workers alive across iterator resets when workers are enabled.
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
worker CPU utilization, and estimated read volume when enabled.

`run-dataloader.sh` consumes these rank-local metrics and writes the canonical
summary, status, record, stdout, and stderr artifacts.

## Notes

This script is an internal workload engine. Prefer `run-dataloader.sh`,
`submit-dataloader.sh`, `sweep-dataloader.sh`, or `make benchmark-dataloader`
for supported command-line use.
