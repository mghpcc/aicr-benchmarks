# render-hpl-mxp-report.py

## Purpose

Render completed HPL-MxP rows into a Markdown campaign report, CSV summary, and
JSON metadata.

## Usage

```bash
scripts/report/render-hpl-mxp-report.py \
  --results-root results \
  --date <YYYY-MM-DD|today|yesterday> \
  --cluster <b200|rtxpro6000>
```

## Output

The renderer writes under:

```text
results/reports/<date>/hpl-mxp/
```

The report summarizes status, residual result, PFLOPS, matrix size, block size,
processor grid, node count, and runtime controls.
