# render-nccl-suite-report.py

## Purpose

Render NCCL suite reports from parsed NCCL suite artifacts.

## Usage

```text
scripts/report/render-nccl-suite-report.py --date DATE --cluster {b200,rtxpro6000} --scope {local,rdma,survey} [options]
```

The public Make entrypoint is:

```bash
make render-nccl-suite NCCL_SCOPE=<local|rdma|survey> CLUSTER=<b200|rtxpro6000> DATE=<YYYY-MM-DD|today>
```

## Options

- `--date <value>`: Report date. Supports `today`.
- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--scope <name>`: `local`, `rdma`, or `survey`.
- `--results-root <path>`: Results root. Default: `results`.
- `--nodes-per-job <n>`: Filter multi-node summaries by node count.
- `--fleet-manifest <path>`: Use a submitter manifest to determine expected rows.
- `--output <path>`: Write Markdown output instead of printing to stdout.

## Examples

Print the current B200 survey dashboard:

```bash
make render-nccl-suite NCCL_SCOPE=survey CLUSTER=b200 DATE=today
```

Print a four-node RTX RDMA report:

```bash
make render-nccl-suite NCCL_SCOPE=rdma CLUSTER=rtxpro6000 NCCL_NODES_PER_JOB=4 DATE=today
```

Write a report from a known manifest:

```bash
scripts/report/render-nccl-suite-report.py \
  --date today \
  --cluster b200 \
  --scope survey \
  --fleet-manifest results/reports/2026-05-09/nccl-suite/120000Z-nccl-suite-b200.json \
  --output results/reports/2026-05-09/nccl-suite-b200.md
```

## Notes

Rendering is read-only unless `--output` is provided. Applied NCCL suite submissions that wait for completion render the report automatically.
