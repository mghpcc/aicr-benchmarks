# render-verify-dashboard.py

## Purpose

Render verification dashboards from canonical AICR-Bench artifacts.

## Usage

```text
scripts/report/render-verify-dashboard.py [--results-root RESULTS_ROOT] --date DATE --cluster {rtxpro6000,b200} [--check {gds,gpu-topology,nccl-local,nccl-rdma}] [--node NODE] [--ascii] [--markdown] [--both] [--write] [--fleet-manifest FLEET_MANIFEST] [--nodes-per-job {2,4,8,16}] [--no-stats]
```

## Options

- `--results-root <path>`: Results root. Default: `results`.
- `--date <date>`: ISO date or supported relative value.
- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--check <name>`: Verification check. Default: `gds`.
- `--node <node>`: Render one node where supported.
- `--ascii`: Print ASCII dashboard.
- `--markdown`: Print Markdown dashboard.
- `--both`: Render both ASCII and Markdown.
- `--write`: Write dashboard files under `results/reports/<date>/`.
- `--fleet-manifest <path>`: Use a specific fleet manifest.
- `--nodes-per-job <n>`: Filter NCCL RDMA summaries by node group size.
- `--no-stats`: Suppress GDS/NCCL statistics and anomaly sections.

## Outputs

- Terminal dashboard output.
- Optional report files under `results/reports/<date>/` when `--write` is used.

## Examples

Print a GDS ASCII dashboard:

```bash
scripts/report/render-verify-dashboard.py --results-root results --date today --cluster b200 --check gds --ascii
```

Use the Make target:

```bash
make render-gds-ascii CLUSTER=b200 DATE=today
```

Write Markdown:

```bash
scripts/report/render-verify-dashboard.py --results-root results --date 2026-05-09 --cluster b200 --check gds --markdown --write
```
