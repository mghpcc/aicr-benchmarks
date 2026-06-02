# run-dataloader.sh

## Purpose

Run the DataLoader workload inside an existing Slurm allocation and write raw,
parsed, and record artifacts. This is the allocation-side runner used by the
Slurm wrappers and host-side submitters.

## Usage

```text
scripts/benchmark/run-dataloader.sh [--cluster <b200|rtxpro6000>] [--profile <small|medium|large>] [--inspect-profile] [--nodes <n>] [--mode <single|replicated|distributed-sharded>] [--requested-gpu-count <n>] [--dataset-root <path>] [--split <train|val>] [--image <path>] [--gpu <index>] [--input-backend <pytorch-cpu-dataloader|dali-gpu-decode|numpy-uint8-shards|numpy-fp16-shards|numpy-fp16-blocks-pytorch|dali-numpy-fp16-cpu|dali-numpy-fp16-gds|dali-numpy-fp16-blocks-cpu|dali-numpy-fp16-blocks-gds>] [--derived-root <path>] [--derived-image-size <n>] [--derived-samples-per-class <n>] [--derived-seed <n>] [--batch-size <n>] [--num-workers <n>] [--prefetch-factor <n>] [--dali-num-threads <n>] [--dali-prefetch-queue-depth <n>] [--dali-numpy-reader-prefetch-queue-depth <n>] [--dali-decode-mode <random-crop|decode-resize>] [--dali-hw-decoder-load <float>] [--dali-gds-chunk-size <value>] [--numpy-block-cache-size <n>] [--cufile-log-path <path>] [--cufile-log-level <level>] [--pin-memory <0|1>] [--persistent-workers <0|1>] [--warmup-batches <n>] [--measured-batches <n>] [--h2d <0|1>] [--transfer-labels <0|1>] [--drop-last <0|1>] [--byte-estimate-sample-count <n>]
```

This script is normally called by Slurm wrappers under `slurm/benchmark/`. Use
`make benchmark-dataloader`, [submit-dataloader.sh](submit-dataloader.md), or
[sweep-dataloader.sh](sweep-dataloader.md) from the install root for normal
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
- `--input-backend <name>`: `pytorch-cpu-dataloader`, `dali-gpu-decode`,
  `numpy-uint8-shards`, `numpy-fp16-shards`, `numpy-fp16-blocks-pytorch`,
  `dali-numpy-fp16-cpu`, `dali-numpy-fp16-gds`,
  `dali-numpy-fp16-blocks-cpu`, or `dali-numpy-fp16-blocks-gds`.
- `--numpy-block-cache-size <n>`: per-worker mmap block cache size for the
  PyTorch NumPy block backend.
- `--derived-root <path>`: Derived dataset root for NumPy shard and DALI NumPy
  file backends.
- `--derived-image-size <n>`: Derived image-size selector.
- `--derived-samples-per-class <n>`: Derived subset selector.
- `--derived-seed <n>`: Derived subset seed selector.
- `--batch-size <n>`: Per-rank batch size.
- `--num-workers <n>`: DataLoader workers per rank.
- `--prefetch-factor <n>`: DataLoader prefetch factor.
- `--dali-num-threads <n>`: DALI CPU worker threads for DALI backend runs.
- `--dali-prefetch-queue-depth <n>`: DALI pipeline prefetch queue depth.
- `--dali-numpy-reader-prefetch-queue-depth <n>`: Reader-level prefetch queue
  depth for DALI NumPy file and block readers. Defaults to `1`.
- `--dali-decode-mode <random-crop|decode-resize>`: DALI decode policy.
- `--dali-hw-decoder-load <float>`: DALI hardware decoder load hint.
- `--dali-gds-chunk-size <value>`: Optional `DALI_GDS_CHUNK_SIZE` value set
  before DALI pipeline construction, such as `2097152` or `2M`.
- `--cufile-log-path <path>`: Optional cuFile log path for DALI NumPy GDS rows.
  Defaults to the run artifact tree for `*-gds` backends.
- `--cufile-log-level <level>`: Optional `CUFILE_LOGGING_LEVEL` for GDS rows with a
  cuFile log path. Defaults to `INFO` when a path is set.
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
- `AICR_DATALOADER_DERIVED_ROOT`: Derived dataset root for NumPy shard and DALI
  NumPy file backends. Defaults under `$AICR_BMARK_DIR/scratch`; on AICR HPC, prefer
  `/scratch/$USER` for regenerated datasets unless you intentionally need
  durable storage.
- `DATALOADER_DALI_GDS_CHUNK_SIZE`: Optional default for
  `--dali-gds-chunk-size`.
- `DATALOADER_DALI_NUMPY_READER_PREFETCH_QUEUE_DEPTH`: Optional default for
  `--dali-numpy-reader-prefetch-queue-depth`.
- `DATALOADER_CUFILE_LOG_PATH`: Optional default for `--cufile-log-path`.
- `DATALOADER_CUFILE_LOG_LEVEL`: Optional default for `--cufile-log-level`.
- `DATALOADER_NOFILE_LIMIT`: Soft file-descriptor limit requested before the
  workload starts. Default: `65536`. The parsed summary records the requested
  value, effective soft and hard limits, and a best-effort open FD count.
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
