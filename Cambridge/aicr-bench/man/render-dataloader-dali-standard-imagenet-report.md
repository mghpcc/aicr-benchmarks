# render-dataloader-dali-standard-imagenet-report.py

Render the standard ImageNet DALI optimization study from parsed DataLoader
benchmark summaries.

## Usage

```bash
scripts/report/render-dataloader-dali-standard-imagenet-report.py \
  --date today \
  --cluster b200
```

## Key Options

| Option | Meaning |
| --- | --- |
| `--date` | UTC campaign date, `today`, or `yesterday`. |
| `--cluster` | Cluster label, such as `b200` or `rtxpro6000`. |
| `--results-root` | Results root, default `results`. |
| `--output-dir` | Override report output directory. |
| `--include-smoke` | Include smoke rows with fewer than 100 measured batches. |

## Filter

The renderer keeps standard ImageNet rows only:

- `replicated` mode;
- one node and eight GPUs;
- `pytorch-cpu-dataloader` or `dali-gpu-decode`;
- canonical ImageNet dataset root;
- no derived image size or derived root;
- `100` warmup batches and `500` measured batches.

## Outputs

By default, the renderer writes under
`results/reports/<date>/dataloader-dali-standard-imagenet/`:

```text
dataloader-dali-standard-imagenet-<cluster>-<date>.md
dataloader-dali-standard-imagenet-<cluster>-<date>-summary.csv
dataloader-dali-standard-imagenet-<cluster>-<date>-summary.json
dataloader-dali-standard-imagenet-<cluster>-<date>-aggregate.csv
dataloader-dali-standard-imagenet-<cluster>-<date>-aggregate.json
dataloader-dali-standard-imagenet-<cluster>-<date>-dali-tuning.png
dataloader-dali-standard-imagenet-<cluster>-<date>-top-configs.png
```
