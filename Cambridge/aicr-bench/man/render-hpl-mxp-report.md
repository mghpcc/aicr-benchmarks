# render-hpl-mxp-report.py

## Purpose

Render completed HPL-MxP rows into a Markdown report, CSV summary, and
JSON metadata.

## Usage

```bash
scripts/report/render-hpl-mxp-report.py \
  --results-root results \
  --date <YYYY-MM-DD|today|yesterday> \
  --cluster <b200|rtxpro6000> \
  [--repeat-aggregation <standard|olympic>] \
  [--job-id-min <id>] \
  [--job-id-max <id>] \
  [--job-id-list <id[,id|range]...>]
```

The public Make entrypoint is:

```bash
make render-hpl-mxp CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today> REPEAT_AGGREGATION=<standard|olympic>
```

## Options

- `--date <value>`: UTC date to render, or `today`/`yesterday`.
- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--results-root <path>`: Results root. Default: `results`.
- `--output-dir <path>`: Override report output directory.
- `--repeat-aggregation <name>`: `standard` or `olympic`. Default: `standard`.
- `--job-id-min <id>` and `--job-id-max <id>`: include only rows whose Slurm
  job id falls inside the requested range.
- `--job-id-list <items>`: include only explicit job ids or comma-separated
  ranges such as `28201,28204-28206`.
- Job-id filters apply before public row selection and repeat aggregation. Use
  them to keep same-day unrelated jobs out of the public report without editing
  the result tree.
- `--help`: Print help.

## Output

The renderer writes under:

```text
results/reports/<date>/hpl-mxp/
```

The report summarizes status, residual result, PFLOPS, matrix size, block size,
processor grid, node count, and runtime controls.
The JSON `status` is `complete` for unfiltered reports, `filtered` when
job-id filters are active, `blocked` for a B200 render with no matching rows,
and `not-run` for another cluster render with no matching rows.

Expected files include:

```text
results/reports/<date>/hpl-mxp/hpl-mxp-<cluster>-<date>.md
results/reports/<date>/hpl-mxp/hpl-mxp-summary-<cluster>-<date>.csv
results/reports/<date>/hpl-mxp/hpl-mxp-repeat-aggregation-<cluster>-<date>.csv
results/reports/<date>/hpl-mxp/hpl-mxp-report-<cluster>-<date>.json
```
