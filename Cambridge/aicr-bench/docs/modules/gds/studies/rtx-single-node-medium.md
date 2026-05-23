# GDS RTX Single-node medium

<!-- aicr-study-status: published -->

Purpose: RTX single-node `medium` profile run.

## Command Run

```bash
make verify-gds CLUSTER=rtxpro6000 PROFILE=medium NODELIST=a0001 APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `rtxpro6000`
- Profile: `medium`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `a0001`
- Slurm jobs: `16556`
- Run IDs: `225306Z-r01`
- Result: all rows/jobs in this study passed.
- Scope: RTX single-node `medium` profile with sequential and random phases.
- Sequential read: `10.089 GiB/s`
- Sequential write: `7.180 GiB/s`
- Random read: `0.252 GiB/s`
- Random write: `0.070 GiB/s`

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### GDS rtxpro6000 2026-05-10

- Check: `gds`
- Cluster: `rtxpro6000`
- Partition: `GPU1` (now `rtx-batch`)
- Discovery time: `2026-05-10T22:53:03Z`
- Mode: `apply`
- GDS profile: `medium`
- Time limit: `01:00:00`

| Node | Slurm | Job | Run | Profile | Status | Platform | Sequential W/R | Sequential Read GiB/s | Sequential Write GiB/s | Random Read GiB/s | Random Write GiB/s | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a0001 | idle | 16556 | 225306Z-r01 | medium | passed | Pass | Pass/Pass | 10.089 | 7.180 | 0.252 | 0.070 |  |

### GDS Phase Details

| Node | Profile | Phase | Status | GiB/s | Latency us | Ops | Time s | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a0001 | medium | platform | Pass | - | - | - | - |  |
| a0001 | medium | sequential-write | Pass | 7.180 | 17353.284 | 27200 | 59.195 |  |
| a0001 | medium | sequential-read | Pass | 10.089 | 12386.721 | 38650 | 59.856 |  |
| a0001 | medium | random-write | Pass | 0.070 | 1746.555 | 1138289 | 62.156 |  |
| a0001 | medium | random-read | Pass | 0.252 | 484.192 | 3955630 | 59.852 |  |

### GDS Statistics

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 10.089 | 10.089 | 0.000 | 10.089 | 10.089 | 10.089 | 10.089 | 10.089 | 10.089 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 7.180 | 7.180 | 0.000 | 7.180 | 7.180 | 7.180 | 7.180 | 7.180 | 7.180 | 0.000 | 0.000 |
| Random Read GiB/s | 1 | 0.252 | 0.252 | 0.000 | 0.252 | 0.252 | 0.252 | 0.252 | 0.252 | 0.252 | 0.000 | 0.000 |
| Random Write GiB/s | 1 | 0.070 | 0.070 | 0.000 | 0.070 | 0.070 | 0.070 | 0.070 | 0.070 | 0.070 | 0.000 | 0.000 |

### GDS Anomalies

(none)

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-medium-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-medium-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-medium-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-medium-2026-05-10.provenance.json>
- SHA-256: `ff804170ec4b2f6b4455232ba78aa2a6406c936d28550414991e1c0e6f12fce5`
- Bundle size: `6519` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-rtx-single-node-medium
cd public-study-artifacts/gds-rtx-single-node-medium
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-medium-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-medium-2026-05-10.provenance.json
printf "%s  %s\n" "ff804170ec4b2f6b4455232ba78aa2a6406c936d28550414991e1c0e6f12fce5" "gds-rtx-single-node-medium-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-rtx-single-node-medium-2026-05-10.tar.gz | head
```
