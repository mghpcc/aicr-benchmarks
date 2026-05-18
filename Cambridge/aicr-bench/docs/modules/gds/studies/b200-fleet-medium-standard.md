# GDS B200 Fleet medium standard

<!-- aicr-study-status: published -->

Purpose: Repeated medium-profile B200 GDS fleet run with standard aggregation.

## Command Run

```bash
make verify-gds CLUSTER=b200 PROFILE=medium NODELIST=b0002 REPEAT_COUNT=3 APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `b200`
- Profile: `medium`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `b0002`
- Slurm jobs: `16540, 16542, 16543`
- Run IDs: `221749Z-r01, 222731Z-r01, 223238Z-r01`
- Result: all rows/jobs in this study passed.
- Focus: Standard repeated-run aggregation for one selected B200 node.

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

Copied from `results/reports/2026-05-10/gds/gds-b200-fleet-medium-standard-dashboard.md` in the artifact bundle.

### GDS b200 2026-05-10

- Check: `gds`
- Cluster: `b200`
- Partition: `GPU2`
- Discovery time: `2026-05-10T22:17:46Z`
- Mode: `apply`
- GDS profile: `medium`
- Time limit: `01:00:00`
- Repeat count: `3`
- Repeat aggregation: `standard`
- Round stagger seconds: `0`

| Node | Slurm | Samples | Passes | Status | Sequential Read med | Sequential Read min..max | Sequential Write med | Sequential Write min..max | Random Read med | Random Read min..max | Random Write med | Random Write min..max | Aggregation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | idle | 3/3 | 3/3 | passed | 9.502 | 9.337..9.602 | 7.267 | 7.221..7.375 | 0.238 | 0.218..0.245 | 0.070 | 0.070..0.073 | - |

Median columns aggregate passed numeric samples for each node.

### GDS Statistics

Only passed rows with numeric throughput values are included. Mean shows the overall level; median and MAD are preferred for anomaly detection because severe outliers can distort standard deviation.
See [Stats Explained](../../../stats-explained.md) for definitions of Mean, Median, StdDev, percentiles, MAD, CV, Delta, and Robust Z.

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 9.502 | 9.502 | 0.000 | 9.502 | 9.502 | 9.502 | 9.502 | 9.502 | 9.502 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 7.267 | 7.267 | 0.000 | 7.267 | 7.267 | 7.267 | 7.267 | 7.267 | 7.267 | 0.000 | 0.000 |
| Random Read GiB/s | 1 | 0.238 | 0.238 | 0.000 | 0.238 | 0.238 | 0.238 | 0.238 | 0.238 | 0.238 | 0.000 | 0.000 |
| Random Write GiB/s | 1 | 0.070 | 0.070 | 0.000 | 0.070 | 0.070 | 0.070 | 0.070 | 0.070 | 0.070 | 0.000 | 0.000 |

### GDS Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. Rows below `1.0%` absolute delta are suppressed from this table. See [Stats Explained](../../../stats-explained.md) for `Delta` and `Robust Z` definitions.

(none)

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.provenance.json>
- SHA-256: `b3a9bcfb890d106347fe48b0005b66adb5a5846cea2a2fe9aa15dcd176436887`
- Bundle size: `9856` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-b200-fleet-medium-standard
cd public-study-artifacts/gds-b200-fleet-medium-standard
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.provenance.json
printf "%s  %s\n" "b3a9bcfb890d106347fe48b0005b66adb5a5846cea2a2fe9aa15dcd176436887" "gds-b200-fleet-medium-standard-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-b200-fleet-medium-standard-2026-05-10.tar.gz | head
```
