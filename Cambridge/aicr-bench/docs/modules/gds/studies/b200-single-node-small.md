# GDS B200 Single-node small

<!-- aicr-study-status: published -->

Purpose: B200 single-node `small` profile run.

## Command Run

```bash
make verify-gds CLUSTER=b200 PROFILE=small NODELIST=b0002 APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `b200`
- Profile: `small`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `b0002`
- Slurm jobs: `16534`
- Run IDs: `214655Z-r01`
- Result: all rows/jobs in this study passed.
- Scope: B200 single-node `small` profile.
- Sequential read: `8.884 GiB/s`
- Sequential write: `5.255 GiB/s`

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### GDS b200 2026-05-10

- Check: `gds`
- Cluster: `b200`
- Partition: `GPU2` (now `b200-batch`)
- Discovery time: `2026-05-10T21:46:52Z`
- Mode: `apply`
- GDS profile: `small`
- Time limit: `00:25:00`

| Node | Slurm | Job | Run | Profile | Status | Platform | Sequential W/R | Sequential Read GiB/s | Sequential Write GiB/s | Random Read GiB/s | Random Write GiB/s | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | idle | 16534 | 214655Z-r01 | small | passed | Pass | Pass/Pass | 8.884 | 5.255 | - | - |  |

### GDS Phase Details

| Node | Profile | Phase | Status | GiB/s | Latency us | Ops | Time s | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | small | platform | Pass | - | - | - | - |  |
| b0002 | small | sequential-write | Pass | 5.255 | 11413.421 | 1015 | 3.018 |  |
| b0002 | small | sequential-read | Pass | 8.884 | 7011.456 | 1003 | 1.764 |  |

### GDS Statistics

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 8.884 | 8.884 | 0.000 | 8.884 | 8.884 | 8.884 | 8.884 | 8.884 | 8.884 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 5.255 | 5.255 | 0.000 | 5.255 | 5.255 | 5.255 | 5.255 | 5.255 | 5.255 | 0.000 | 0.000 |

### GDS Anomalies

(none)

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-small-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-small-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-small-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-small-2026-05-10.provenance.json>
- SHA-256: `91e733417e1ecd876073f035bdc193052aa88c695e5cfcaf27a8c1c2868b4b62`
- Bundle size: `6066` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-b200-single-node-small
cd public-study-artifacts/gds-b200-single-node-small
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-small-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-small-2026-05-10.provenance.json
printf "%s  %s\n" "91e733417e1ecd876073f035bdc193052aa88c695e5cfcaf27a8c1c2868b4b62" "gds-b200-single-node-small-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-b200-single-node-small-2026-05-10.tar.gz | head
```
