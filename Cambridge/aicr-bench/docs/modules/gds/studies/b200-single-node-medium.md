# GDS B200 Single-node medium

<!-- aicr-study-status: published -->

Purpose: B200 single-node `medium` profile run.

## Command Run

```bash
make verify-gds CLUSTER=b200 PROFILE=medium NODELIST=b0002 APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `b200`
- Profile: `medium`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `b0002`
- Slurm jobs: `16535`
- Run IDs: `214743Z-r01`
- Result: all rows/jobs in this study passed.
- Scope: B200 single-node `medium` profile with sequential and random phases.
- Sequential read: `9.694 GiB/s`
- Sequential write: `7.511 GiB/s`
- Random read: `0.248 GiB/s`
- Random write: `0.070 GiB/s`

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### GDS b200 2026-05-10

- Check: `gds`
- Cluster: `b200`
- Partition: `GPU2`
- Discovery time: `2026-05-10T21:47:39Z`
- Mode: `apply`
- GDS profile: `medium`
- Time limit: `01:00:00`

| Node | Slurm | Job | Run | Profile | Status | Platform | Sequential W/R | Sequential Read GiB/s | Sequential Write GiB/s | Random Read GiB/s | Random Write GiB/s | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | idle | 16535 | 214743Z-r01 | medium | passed | Pass | Pass/Pass | 9.694 | 7.511 | 0.248 | 0.070 |  |

### GDS Phase Details

| Node | Profile | Phase | Status | GiB/s | Latency us | Ops | Time s | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | medium | platform | Pass | - | - | - | - |  |
| b0002 | medium | sequential-write | Pass | 7.511 | 16592.677 | 28550 | 59.393 |  |
| b0002 | medium | sequential-read | Pass | 9.694 | 12892.135 | 36777 | 59.281 |  |
| b0002 | medium | random-write | Pass | 0.070 | 1734.557 | 1133121 | 61.441 |  |
| b0002 | medium | random-read | Pass | 0.248 | 491.369 | 3852545 | 59.156 |  |

### GDS Statistics

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 9.694 | 9.694 | 0.000 | 9.694 | 9.694 | 9.694 | 9.694 | 9.694 | 9.694 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 7.511 | 7.511 | 0.000 | 7.511 | 7.511 | 7.511 | 7.511 | 7.511 | 7.511 | 0.000 | 0.000 |
| Random Read GiB/s | 1 | 0.248 | 0.248 | 0.000 | 0.248 | 0.248 | 0.248 | 0.248 | 0.248 | 0.248 | 0.000 | 0.000 |
| Random Write GiB/s | 1 | 0.070 | 0.070 | 0.000 | 0.070 | 0.070 | 0.070 | 0.070 | 0.070 | 0.070 | 0.000 | 0.000 |

### GDS Anomalies

(none)

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-medium-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-medium-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-medium-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-medium-2026-05-10.provenance.json>
- SHA-256: `4f9e14375fa797e04f0d3fe9bdeb9873e2577b2c84e68434c926e36e37146d0b`
- Bundle size: `6680` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-b200-single-node-medium
cd public-study-artifacts/gds-b200-single-node-medium
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-medium-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-medium-2026-05-10.provenance.json
printf "%s  %s\n" "4f9e14375fa797e04f0d3fe9bdeb9873e2577b2c84e68434c926e36e37146d0b" "gds-b200-single-node-medium-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-b200-single-node-medium-2026-05-10.tar.gz | head
```
