# prepare-dataloader-derived-dataset.py

Prepare bounded ImageNet-derived datasets for DataLoader input-pipeline experiments.

## Usage

```bash
scripts/benchmark/prepare-dataloader-derived-dataset.py \
  --dataset-root "$AICR_IMAGENET_DIR" \
  --split train \
  --derived-root "$AICR_DATALOADER_DERIVED_ROOT" \
  --samples-per-class 16 \
  --image-size-list 224,384,512,768,1024,1536
```

Add `--apply` to write outputs after reviewing the dry-run plan.

## Key Options

| Option | Meaning |
| --- | --- |
| `--dataset-root` | ImageFolder root containing `train/` and `val/`. |
| `--split` | Dataset split, usually `train`. |
| `--derived-root` | Output root for derived datasets. |
| `--samples-per-class` | Bounded sample count per ImageNet class. |
| `--image-size-list` | Comma-separated square resize targets. |
| `--formats` | Derived formats: `jpeg`, `numpy-uint8`, `numpy-fp16`, or synthetic JPEG variants. |
| `--apply` | Write outputs. Without it, only prints the plan. |
| `--overwrite` | Replace existing derived dataset directories. |

