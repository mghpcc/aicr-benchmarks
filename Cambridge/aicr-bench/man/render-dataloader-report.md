# render-dataloader-report.py

## Purpose

Render DataLoader Markdown, CSV, JSON, and PNG summaries from parsed result artifacts.

## Usage

```text
scripts/report/render-dataloader-report.py --date DATE --cluster {b200,rtxpro6000} [--results-root RESULTS] [--output-dir DIR] [--repeat-aggregation {standard,olympic}]
```

The Make entrypoint is:

```bash
make render-dataloader CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today>
```

## Options

- `--date <value>`: UTC date to render, or `today`/`yesterday`.
- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--results-root <path>`: Results root. Default: `results`.
- `--output-dir <path>`: Override report output directory.
- `--repeat-aggregation <name>`: `standard` or `olympic`.
- `--help`: Print help.

## Examples

Render today's RTX DataLoader report:

```bash
make render-dataloader CLUSTER=rtxpro6000 DATE=today
```

Render directly:

```bash
scripts/report/render-dataloader-report.py --results-root results --date today --cluster rtxpro6000
```

## Outputs

```text
results/reports/<date>/dataloader/dataloader-<cluster>-<date>.md
results/reports/<date>/dataloader/dataloader-summary-<cluster>-<date>.csv
results/reports/<date>/dataloader/dataloader-aggregated-summary-<cluster>-<date>.csv
results/reports/<date>/dataloader/dataloader-<cluster>-<date>.json
results/reports/<date>/dataloader/dataloader-throughput-<cluster>-<date>.png
results/reports/<date>/dataloader/dataloader-throughput-matrix-<cluster>-<date>.png
results/reports/<date>/dataloader/dataloader-imbalance-matrix-<cluster>-<date>.png
results/reports/<date>/dataloader/dataloader-candidate-scatter-<cluster>-<date>.png
results/reports/<date>/dataloader/dataloader-matrix-<cluster>-<date>.html
```

The generated Markdown keeps raw rows for audit and includes an aggregated
configuration summary when repeated samples exist. With
`--repeat-aggregation olympic`, the aggregated CSV and plots drop the lowest
and highest throughput samples from each repeated configuration and compute
paired metrics from the retained jobs.

The DataLoader docs include a synthetic known-answer fixture under
`tests/fixtures/dataloader/olympic-repeat/`. A test-only helper under
`tests/scripts/` validates this Olympic aggregation behavior and the rendered
Markdown/HTML report shape through the executable documentation framework. Test
helpers are not part of the command surface.
