# GDS B200 Fleet medium olympic

<!-- aicr-study-status: published -->

Purpose: Repeated medium-profile B200 GDS fleet run with olympic aggregation.

## Command Run

```bash
make verify-gds CLUSTER=b200 PROFILE=medium NODELIST=b0002 REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `b200`
- Profile: `medium`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `b0002`
- Slurm jobs: `16545, 16549, 16551, 16555, 16560`
- Run IDs: `223741Z-r01, 224243Z-r01, 224745Z-r01, 225247Z-r01, 225750Z-r01`
- Result: all rows/jobs in this study passed.
- Focus: Olympic repeated-run aggregation for one selected B200 node.

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

Copied from `results/reports/2026-05-10/gds/gds-b200-fleet-medium-olympic-dashboard.md` in the artifact bundle.

### GDS b200 2026-05-10

- Check: `gds`
- Cluster: `b200`
- Partition: `GPU2`
- Discovery time: `2026-05-10T22:37:38Z`
- Mode: `apply`
- GDS profile: `medium`
- Time limit: `01:00:00`
- Repeat count: `5`
- Repeat aggregation: `olympic`
- Round stagger seconds: `0`

| Node | Slurm | Samples | Passes | Status | Sequential Read olympic avg | Sequential Read min..max | Sequential Read drop min/max | Sequential Write olympic avg | Sequential Write min..max | Sequential Write drop min/max | Random Read olympic avg | Random Read min..max | Random Read drop min/max | Random Write olympic avg | Random Write min..max | Random Write drop min/max | Aggregation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | idle | 5/5 | 5/5 | passed | 10.116 | 7.445..10.662 | 7.445/10.662 | 7.214 | 5.474..7.434 | 5.474/7.434 | 0.230 | 0.220..0.241 | 0.220/0.241 | 0.071 | 0.069..0.073 | 0.069/0.073 | - |

Olympic avg columns aggregate passed numeric samples for each node.

### GDS Statistics

Only passed rows with numeric throughput values are included. Mean shows the overall level; median and MAD are preferred for anomaly detection because severe outliers can distort standard deviation.
See [Stats Explained](../../../stats-explained.md) for definitions of Mean, Median, StdDev, percentiles, MAD, CV, Delta, and Robust Z.

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 10.116 | 10.116 | 0.000 | 10.116 | 10.116 | 10.116 | 10.116 | 10.116 | 10.116 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 7.214 | 7.214 | 0.000 | 7.214 | 7.214 | 7.214 | 7.214 | 7.214 | 7.214 | 0.000 | 0.000 |
| Random Read GiB/s | 1 | 0.230 | 0.230 | 0.000 | 0.230 | 0.230 | 0.230 | 0.230 | 0.230 | 0.230 | 0.000 | 0.000 |
| Random Write GiB/s | 1 | 0.071 | 0.071 | 0.000 | 0.071 | 0.071 | 0.071 | 0.071 | 0.071 | 0.071 | 0.000 | 0.000 |

### GDS Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. Rows below `1.0%` absolute delta are suppressed from this table. See [Stats Explained](../../../stats-explained.md) for `Delta` and `Robust Z` definitions.

(none)

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.provenance.json>
- SHA-256: `4b39fe8546b281d5e707af26d3fb9c7fa2de0fee71667222b13aa4369cb1fe85`
- Bundle size: `12972` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-b200-fleet-medium-olympic
cd public-study-artifacts/gds-b200-fleet-medium-olympic
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.provenance.json
printf "%s  %s\n" "4b39fe8546b281d5e707af26d3fb9c7fa2de0fee71667222b13aa4369cb1fe85" "gds-b200-fleet-medium-olympic-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-b200-fleet-medium-olympic-2026-05-10.tar.gz | head
```
