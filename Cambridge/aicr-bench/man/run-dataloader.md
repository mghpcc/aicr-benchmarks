# run-dataloader.sh

## Purpose

Run the DataLoader workload inside an existing Slurm allocation and write raw,
parsed, and record artifacts. This is the allocation-side runner used by the
Slurm wrappers and host-side submitters.

## Usage

```text
scripts/benchmark/run-dataloader.sh [--cluster <b200|rtxpro6000>] [--profile <small|medium|large>] [--inspect-profile] [--nodes <n>] [--mode <single|replicated|distributed-sharded>] [--requested-gpu-count <n>] [--dataset-root <path>] [--split <train|val>] [--image <path>] [--gpu <index>] [--batch-size <n>] [--num-workers <n>] [--prefetch-factor <n>] [--pin-memory <0|1>] [--persistent-workers <0|1>] [--warmup-batches <n>] [--measured-batches <n>] [--h2d <0|1>] [--transfer-labels <0|1>] [--drop-last <0|1>] [--byte-estimate-sample-count <n>]
```

This script is normally called by Slurm wrappers under `slurm/benchmark/`. Use
`make benchmark-dataloader`, `scripts/benchmark/submit-dataloader.sh`, or
`scripts/benchmark/sweep-dataloader.sh` from the install root for normal
operation.

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--profile <name>`: `small`, `medium`, or `large`. Controls workload intensity defaults only.
- `--inspect-profile`: Print the selected profile without running the workload.
- `--nodes <n>`: Node count.
- `--mode <name>`: `single`, `replicated`, or `distributed-sharded`.
- `--requested-gpu-count <n>`: Expected world size.
- `--dataset-root <path>`: ImageFolder root containing `train/` and `val/`.
- `--split <train|val>`: Dataset split. Default: `train`.
- `--image <path>`: PyTorch Apptainer image.
- `--gpu <index>`: GPU index for `single` mode.
- `--batch-size <n>`: Per-rank batch size.
- `--num-workers <n>`: DataLoader workers per rank.
- `--prefetch-factor <n>`: DataLoader prefetch factor.
- `--pin-memory <0|1>`: Enable page-locked host memory.
- `--persistent-workers <0|1>`: Keep workers alive across iterator resets.
- `--warmup-batches <n>`: Untimed batches before measurement.
- `--measured-batches <n>`: Timed batches.
- `--h2d <0|1>`: Include host-to-device copy timing.
- `--transfer-labels <0|1>`: Transfer labels when H2D is enabled.
- `--drop-last <0|1>`: Drop incomplete final batches.
- `--byte-estimate-sample-count <n>`: Number of ImageFolder paths to stat for estimated read volume; `0` disables the estimate.
- `--help`: Print help.

## Profiles

| Profile | Batch size | Workers | Prefetch | Warmup batches | Measured batches |
| --- | ---: | ---: | ---: | ---: | ---: |
| `small` | 512 | 16 | 4 | 20 | 100 |
| `medium` | 512 | 16 | 4 | 100 | 500 |
| `large` | 512 | 16 | 4 | 200 | 5000 |

## Environment

- `AICR_IMAGENET_DIR`: ImageFolder root containing `train/` and `val/`.
- `DATALOADER_IMAGE`: DataLoader PyTorch image override.
- `PYTORCH_IMAGE`: PyTorch image fallback.
- `AICR_RUNTIME_ROOT`: Base runtime tree.
- `AICR_APPTAINER_IMAGE_DIR`: Image directory.

## Examples

Inspect help:

```bash
scripts/benchmark/run-dataloader.sh --help
```

Inspect the small profile:

```bash
scripts/benchmark/run-dataloader.sh --profile small --inspect-profile
```

Manual use requires an active GPU Slurm allocation with `benchmark-settings.env` loaded by the wrapper or current shell.
