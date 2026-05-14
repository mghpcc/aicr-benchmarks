# GDS RTX Single-node small

<!-- aicr-study-status: published -->

Purpose: RTX single-node `small` profile run.

## Command Run

```bash
make verify-gds CLUSTER=rtxpro6000 PROFILE=small NODELIST=a0001 APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `rtxpro6000`
- Profile: `small`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `a0001`
- Slurm jobs: `16554`
- Run IDs: `225234Z-r01`
- Result: all rows/jobs in this study passed.
- Scope: RTX single-node `small` profile.
- Sequential read: `8.698 GiB/s`
- Sequential write: `5.150 GiB/s`

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### GDS rtxpro6000 2026-05-10

- Check: `gds`
- Cluster: `rtxpro6000`
- Partition: `GPU1`
- Discovery time: `2026-05-10T22:52:31Z`
- Mode: `apply`
- GDS profile: `small`
- Time limit: `00:25:00`

| Node | Slurm | Job | Run | Profile | Status | Platform | Sequential W/R | Sequential Read GiB/s | Sequential Write GiB/s | Random Read GiB/s | Random Write GiB/s | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a0001 | idle | 16554 | 225234Z-r01 | small | passed | Pass | Pass/Pass | 8.698 | 5.150 | - | - |  |

### GDS Phase Details

| Node | Profile | Phase | Status | GiB/s | Latency us | Ops | Time s | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a0001 | small | platform | Pass | - | - | - | - |  |
| a0001 | small | sequential-write | Pass | 5.150 | 11661.718 | 999 | 3.031 |  |
| a0001 | small | sequential-read | Pass | 8.698 | 7362.206 | 898 | 1.613 |  |

### GDS Statistics

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 8.698 | 8.698 | 0.000 | 8.698 | 8.698 | 8.698 | 8.698 | 8.698 | 8.698 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 5.150 | 5.150 | 0.000 | 5.150 | 5.150 | 5.150 | 5.150 | 5.150 | 5.150 | 0.000 | 0.000 |

### GDS Anomalies

(none)

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-small-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-small-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-small-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-small-2026-05-10.provenance.json>
- SHA-256: `dec769e4ed58b9158fb0924e81782d8747fb841a8dfda1ec80ca20e7de33ff23`
- Bundle size: `5916` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-rtx-single-node-small
cd public-study-artifacts/gds-rtx-single-node-small
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-small-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-small-2026-05-10.provenance.json
printf "%s  %s\n" "dec769e4ed58b9158fb0924e81782d8747fb841a8dfda1ec80ca20e7de33ff23" "gds-rtx-single-node-small-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-rtx-single-node-small-2026-05-10.tar.gz | head
```
