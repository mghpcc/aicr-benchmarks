# render-ddp-resnet50-report.py

## Purpose

Render public DDP ResNet-50 Markdown, CSV, JSON, and PNG summaries from parsed result artifacts.

## Usage

```text
scripts/report/render-ddp-resnet50-report.py --date DATE --cluster {b200,rtxpro6000} [--results-root RESULTS] [--output-dir DIR] [--include-smoke|--include-short-runs] [--ascii]
```

The public Make entrypoint is:

```bash
make render-ddp-resnet50 CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today>
```

The public ASCII entrypoint is:

```bash
make render-ddp-resnet50-ascii CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today>
```

## Options

- `--date <value>`: UTC date to render, or `today`/`yesterday`.
- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--results-root <path>`: Results root. Default: `results`.
- `--output-dir <path>`: Override report output directory.
- `--include-smoke`, `--include-short-runs`: Include short launch-validation rows.
- `--ascii`: Print a compact terminal dashboard after writing report files.
- `--help`: Print help.

## Examples

Render today's RTX DDP report:

```bash
make render-ddp-resnet50 CLUSTER=rtxpro6000 DATE=today
```

Render directly:

```bash
scripts/report/render-ddp-resnet50-report.py --results-root results --date today --cluster rtxpro6000
```

Print an ASCII dashboard:

```bash
make render-ddp-resnet50-ascii CLUSTER=rtxpro6000 DATE=today
```

## Outputs

```text
results/reports/<date>/ddp/ddp-resnet50-<cluster>-<date>.md
results/reports/<date>/ddp/ddp-resnet50-summary-<cluster>-<date>.csv
results/reports/<date>/ddp/ddp-resnet50-report-<cluster>-<date>.json
results/reports/<date>/ddp/ddp-resnet50-throughput-<cluster>-<date>.png
results/reports/<date>/ddp/ddp-resnet50-scaling-<cluster>-<date>.png
```

The throughput PNG is a matplotlib bar chart of `samples_per_second` by
launcher, node/rank shape, and batch size. The scaling PNG shows
`samples_per_second` across node counts for comparable launcher groups.
