# render-dataloader-input-lab-report.py

Render DataLoader input-pipeline lab tables and plots from parsed benchmark summaries.

## Usage

```bash
scripts/report/render-dataloader-input-lab-report.py \
  --date 2026-05-16 \
  --cluster b200
```

## Key Options

| Option | Meaning |
| --- | --- |
| `--date` | UTC campaign date, `today`, or `yesterday`. |
| `--cluster` | Cluster label, such as `b200` or `rtxpro6000`. |
| `--results-root` | Results root, default `results`. |
| `--output-dir` | Override report output directory. |
| `--baseline-samples-per-second` | Baseline throughput for speedup calculations. |
| `--include-smoke` | Include smoke rows with fewer than 100 measured batches. |
| `--input-backends` | Comma-separated backend filter. |

