# submit-dataloader-derived-dataset.sh

## Purpose

Submit bounded DataLoader derived-dataset preparation as a CPU Slurm job.

Use this wrapper for ImageNet-derived JPEG, synthetic JPEG, procedural JPEG,
NumPy shard prep, and per-sample NumPy fp16 files for DALI/GDS experiments. It
keeps heavy filesystem work off login nodes. The wrapper is
dry-run-first and has two gates: `--apply` submits the CPU Slurm job, and
`--write` forwards `--apply` to `prepare-dataloader-derived-dataset.py`.

## Usage

```text
scripts/benchmark/submit-dataloader-derived-dataset.sh [--dataset-root <path>] --derived-root <path> [--split <train|val>] [--samples-per-class <n>] [--seed <n>] [--image-size-list <csv>] [--formats <csv>] [--jpeg-quality <n>] [--partition <name>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--mem <size>] [--nodelist <node>] [--write] [--overwrite] [--apply]
```

## Options

- `--dataset-root <path>`: ImageFolder root. Defaults to `AICR_IMAGENET_DIR`.
- `--derived-root <path>`: Output root. Defaults to `AICR_DATALOADER_DERIVED_ROOT`.
  The submitter accepts the explicit root you choose. The portable default is
  repo-local under `$AICR_BMARK_DIR/scratch`; on AICR HPC, prefer
  `/scratch/$USER` for regenerated datasets unless you intentionally need
  durable storage.
- `--split <train|val>`: Dataset split. Default: `train`.
- `--samples-per-class <n>`: Bounded samples per class. Default: `16`.
- `--seed <n>`: Deterministic sample seed. Default: `1234`.
- `--image-size-list <csv>`: Square resize targets. Default: `224,384,512`.
- `--formats <csv>`: Formats. Default: `jpeg,numpy-uint8,numpy-fp16`.
  Also supports `numpy-fp16-files` and `numpy-fp16-blocks` for DALI NumPy reader
  experiments.
- `--numpy-block-size <n>`: Images per block file for `numpy-fp16-blocks`.
  Default: `128`.
- `--jpeg-quality <n>`: JPEG quality forwarded to the prep helper. Default: `95`.
- `--partition <name>`: Slurm CPU partition. Default: `cpu`.
- `--time <HH:MM:SS>`: Slurm time limit. Default: `04:00:00`.
- `--cpus-per-task <n>`: Slurm CPU request. Default: `16`.
- `--mem <size>`: Slurm memory request. Default: `0`.
- `--nodelist <node>`: Optional CPU node pin.
- `--write`: Write derived outputs inside the Slurm job.
- `--overwrite`: Replace existing derived dataset directories.
- `--apply`: Submit the CPU Slurm job.

## Examples

Preview the CPU Slurm job:

```bash
scripts/benchmark/submit-dataloader-derived-dataset.sh --derived-root "$PWD/scratch/derived-datasets/dataloader-lab/example"
```

Submit a planner job that writes no derived outputs:

```bash
scripts/benchmark/submit-dataloader-derived-dataset.sh --derived-root "$PWD/scratch/derived-datasets/dataloader-lab/example" --apply
```

Submit a writer job only after reviewing the dry-run storage estimate:

```bash
scripts/benchmark/submit-dataloader-derived-dataset.sh --derived-root "$PWD/scratch/derived-datasets/dataloader-lab/example" --write --apply
```

Use Make:

```bash
make prep-dataloader-derived-dataset DATALOADER_PREP_DERIVED_ROOT=$PWD/scratch/derived-datasets/dataloader-lab/example
make prep-dataloader-derived-dataset DATALOADER_PREP_DERIVED_ROOT=$PWD/scratch/derived-datasets/dataloader-lab/example APPLY=1
make prep-dataloader-derived-dataset DATALOADER_PREP_DERIVED_ROOT=$PWD/scratch/derived-datasets/dataloader-lab/example APPLY=1 DATALOADER_PREP_WRITE=1
```
