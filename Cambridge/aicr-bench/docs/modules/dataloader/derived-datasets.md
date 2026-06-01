# Derived ImageNet Datasets

Purpose: document the derived ImageNet inputs used by DataLoader and DDP
input-pipeline experiments.

Derived ImageNet datasets are controlled experiment inputs for decode-pressure,
backend-crossover, and prepared-input studies. Canonical ImageNet remains the
primary input for hardware-progression rows; derived datasets provide
controlled image sizes and shard formats for focused input-pipeline studies.

## Dataset Types

| Format | Output path role | Purpose |
| --- | --- | --- |
| `jpeg` | ImageFolder-compatible pre-resized JPEG tree. | Increases image payload and decode work while preserving a JPEG training-like path. DALI rows on this format are JPEG decode/input-pipeline baselines, not GDS rows. |
| `procedural-jpeg` | Tiny fixture-oriented JPEG output. | Local dry-run and documentation checks without using real ImageNet. |
| `numpy-uint8` | NumPy shard tree with image-shaped uint8 arrays. | Removes JPEG decode while leaving runtime tensor conversion and normalization. |
| `numpy-fp16` | NumPy shard tree with prepared fp16 tensors. | Ceiling path that removes JPEG decode and most preprocessing from the measured job. |
| `numpy-fp16-files` | Per-sample NumPy files containing prepared fp16 NCHW tensors. | DALI NumPy reader path for comparing CPU-reader and DALI NumPy GPU/cuFile prepared-input transport. |
| `numpy-fp16-blocks` | Blocked NumPy files containing prepared fp16 NCHW tensors with shape `(block_size, 3, size, size)`. | Prepared-input transport through DALI NumPy GPU/cuFile reads and the CPU-safe PyTorch mmap block reader. |

Derived rows include `derived_root`, `derived_image_size`,
`derived_samples_per_class`, `derived_seed`, format, dtype, layout, and source
policy so reports can keep canonical and derived evidence separated.

Derived dataset paths use `spc-<n>-seed-<seed>` for the sampled subset. `spc`
means samples per class, so `spc-16-seed-1234` is the 16-sample-per-class
subset with seed `1234`; `spc-80` is the corresponding 80-sample-per-class
subset.

For `numpy-fp16-blocks`, the sample count must be divisible by
`--numpy-block-size` so every block has the same tensor shape. The intended V2
campaign shape uses `spc=64` with block size `128`.

## Storage Policy

On AICR HPC, use the shared `/work` ImageNet tree as the source and prefer a
scratch-backed derived root for regenerated inputs:

```text
/scratch/$USER/aicr-bench/derived-datasets/dataloader-imagenet
```

Use long-term storage when a study keeps the derived dataset for repeated
measurement. Always run a dry-run plan before writing derived data.

For `numpy-fp16-files` and `numpy-fp16-blocks` GPU/cuFile rows, choose a
GDS-capable VAST path and pair the DataLoader run with same-node
`make verify-gds` output. These formats are prepared-tensor transport paths.
For CPU comparison against the blocked layout, use `numpy-fp16-blocks-pytorch`.
It reads individual logical samples from mmap-backed block files and sets
`storage_transport_path=pytorch-numpy-block-cpu-mmap`.

The derived JPEG layout uses DALI's file reader and mixed image decode path.
The DALI GPU/cuFile path used by this module is the GPU variant of
`fn.readers.numpy` over prepared `.npy` tensors. `dali-gpu-decode` is the JPEG
decode/input-pipeline backend; `dali-numpy-fp16-blocks-gds` is the
prepared-tensor transport backend.

## Local Planner Dry Run

This command uses the committed ImageFolder-shaped fixture and writes no
outputs:

```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh \
  scripts/benchmark/prepare-dataloader-derived-dataset.py \
  --dataset-root tests/fixtures/dataloader/imagefolder-dry-run \
  --derived-root /tmp/aicr-dataloader-derived-docs \
  --samples-per-class 1 \
  --image-size-list 224 \
  --formats procedural-jpeg
```

Add `--apply` only when the plan and output root are correct.

## CPU Queue Submitter

The submitter is dry-run-first. Without `--apply`, it prints the `sbatch`
command. Without `--write`, even a submitted job remains a planner job and
writes no derived dataset outputs.

### Dry Run

```bash
scripts/benchmark/submit-dataloader-derived-dataset.sh \
  --dataset-root "$AICR_IMAGENET_DIR" \
  --derived-root /scratch/$USER/aicr-bench/derived-datasets/dataloader-imagenet \
  --samples-per-class 16 \
  --image-size-list 224,384,512,768,1024 \
  --formats jpeg,numpy-uint8,numpy-fp16,numpy-fp16-files,numpy-fp16-blocks \
  --numpy-block-size 128 \
  --partition cpu \
  --time 04:00:00
```

### Write Outputs

After checking the storage estimate and output paths:

```bash
scripts/benchmark/submit-dataloader-derived-dataset.sh \
  --dataset-root "$AICR_IMAGENET_DIR" \
  --derived-root /scratch/$USER/aicr-bench/derived-datasets/dataloader-imagenet \
  --samples-per-class 16 \
  --image-size-list 224,384,512,768,1024 \
  --formats jpeg,numpy-uint8,numpy-fp16,numpy-fp16-files,numpy-fp16-blocks \
  --numpy-block-size 128 \
  --partition cpu \
  --time 04:00:00 \
  --write \
  --apply
```

## Make Interface

The Make target wraps the same dry-run-first CPU submitter:

```bash
make prep-dataloader-derived-dataset \
  DATALOADER_PREP_DATASET_ROOT="$AICR_IMAGENET_DIR" \
  DATALOADER_PREP_DERIVED_ROOT=/scratch/$USER/aicr-bench/derived-datasets/dataloader-imagenet \
  DATALOADER_PREP_SAMPLES_PER_CLASS=16 \
  DATALOADER_PREP_IMAGE_SIZE_LIST=224,384,512,768,1024 \
  DATALOADER_PREP_FORMATS=jpeg,numpy-uint8,numpy-fp16,numpy-fp16-files,numpy-fp16-blocks \
  DATALOADER_PREP_NUMPY_BLOCK_SIZE=128
```

To submit a planner job, add `APPLY=1`. To write outputs from that job, also
set `DATALOADER_PREP_WRITE=1`.

## Related Studies

- [DALI optimization at 1024](studies/dali-large-image-optimization.md)
- [Optimized 224/1024 backend crossover](studies/optimized-backend-crossover.md)
- [Prepared-input ceilings](studies/prepared-input-ceilings.md)
- [Input Pipeline Reference](input-pipeline-reference.md)
