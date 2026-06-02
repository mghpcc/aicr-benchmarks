# prepare-dataloader-derived-dataset.py

Prepare bounded ImageNet-derived datasets for DataLoader input-pipeline experiments.

## Usage

```bash
scripts/lib/run-repo-python.sh scripts/benchmark/prepare-dataloader-derived-dataset.py \
  --dataset-root "$AICR_IMAGENET_DIR" \
  --split train \
  --derived-root "$AICR_DATALOADER_DERIVED_ROOT" \
  --samples-per-class 16 \
  --image-size-list 224,384,512,768,1024,1536
```

Add `--apply` to write outputs after reviewing the dry-run plan. The portable
default derived root lives under the checkout/install tree. On AICR HPC, prefer
`/scratch/$USER` for regenerated datasets unless you intentionally need durable
storage.

On AICR HPC, run applied or storage-heavy prep through the CPU Slurm wrapper
([submit-dataloader-derived-dataset.sh](submit-dataloader-derived-dataset.md))
rather than on a login node.

## Key Options

| Option | Meaning |
| --- | --- |
| `--dataset-root` | ImageFolder root containing `train/` and `val/`. |
| `--split` | Dataset split, usually `train`. |
| `--derived-root` | Output root for derived datasets. Defaults to `AICR_DATALOADER_DERIVED_ROOT`; choose a durable or scratch-backed path to match the run. |
| `--samples-per-class` | Bounded sample count per ImageNet class. |
| `--image-size-list` | Comma-separated square resize targets. |
| `--formats` | Derived formats: `jpeg`, `numpy-uint8`, `numpy-fp16`, `numpy-fp16-files`, `numpy-fp16-blocks`, or synthetic JPEG variants. |
| `--numpy-block-size` | Images per block file for `numpy-fp16-blocks`. Default: `128`. |
| `--apply` | Write outputs. Without it, only prints the plan. |
| `--overwrite` | Replace existing derived dataset directories. |

## Safety

The command is dry-run by default. Without `--apply`, it discovers the input
ImageFolder, prints selected image sizes and formats, and estimates storage
without writing derived datasets.

For Slurm replay, `make prep-dataloader-derived-dataset` has two gates:
`APPLY=1` submits the CPU Slurm job, and `DATALOADER_PREP_WRITE=1` forwards
`--apply` to this helper.

Documentation tests use `tests/fixtures/dataloader/imagefolder-dry-run` with
`--formats procedural-jpeg` to validate the planner path without reading pixels.
For `numpy-fp16-blocks`, the selected sample count must be divisible by
`--numpy-block-size` so every DALI reader sample has a fixed shape.
