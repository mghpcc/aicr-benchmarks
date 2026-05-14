# GDS B200 Single-node large

<!-- aicr-study-status: published -->

Purpose: B200 single-node `large` profile run.

## Command Run

```bash
make verify-gds CLUSTER=b200 PROFILE=large NODELIST=b0002 APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `b200`
- Profile: `large`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `b0002`
- Slurm jobs: `16536`
- Run IDs: `215245Z-r01`
- Result: all rows/jobs in this study passed.
- Scope: B200 single-node `large` profile with sequential, random, async, and CPU/GPU read phases.
- Sequential read: `9.382 GiB/s`
- Sequential write: `7.393 GiB/s`
- Random read: `0.254 GiB/s`
- Random write: `0.067 GiB/s`

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### GDS b200 2026-05-10

- Check: `gds`
- Cluster: `b200`
- Partition: `GPU2`
- Discovery time: `2026-05-10T21:52:42Z`
- Mode: `apply`
- GDS profile: `large`
- Time limit: `02:30:00`

| Node | Slurm | Job | Run | Profile | Status | Platform | Sequential W/R | Sequential Read GiB/s | Sequential Write GiB/s | Random Read GiB/s | Random Write GiB/s | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | idle | 16536 | 215245Z-r01 | large | passed | Pass | Pass/Pass | 9.382 | 7.393 | 0.254 | 0.067 |  |

### GDS Phase Details

| Node | Profile | Phase | Status | GiB/s | Latency us | Ops | Time s | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | large | platform | Pass | - | - | - | - |  |
| b0002 | large | sequential-write | Pass | 7.393 | 33749.719 | 56754 | 119.950 |  |
| b0002 | large | sequential-read | Pass | 9.382 | 26642.883 | 71652 | 119.335 |  |
| b0002 | large | random-write | Pass | 0.067 | 3627.665 | 2103290 | 119.250 |  |
| b0002 | large | random-read | Pass | 0.254 | 962.686 | 7943495 | 119.484 |  |
| b0002 | large | async-stream-write | Pass | 3.019 | 82729.219 | 23014 | 119.111 |  |
| b0002 | large | async-stream-read | Pass | 8.920 | 28006.999 | 68059 | 119.213 |  |
| b0002 | large | cpu-gpu-read | Pass | 13.466 | 18586.431 | 51504 | 59.760 |  |

### GDS Statistics

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 9.382 | 9.382 | 0.000 | 9.382 | 9.382 | 9.382 | 9.382 | 9.382 | 9.382 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 7.393 | 7.393 | 0.000 | 7.393 | 7.393 | 7.393 | 7.393 | 7.393 | 7.393 | 0.000 | 0.000 |
| Random Read GiB/s | 1 | 0.254 | 0.254 | 0.000 | 0.254 | 0.254 | 0.254 | 0.254 | 0.254 | 0.254 | 0.000 | 0.000 |
| Random Write GiB/s | 1 | 0.067 | 0.067 | 0.000 | 0.067 | 0.067 | 0.067 | 0.067 | 0.067 | 0.067 | 0.000 | 0.000 |

### GDS Anomalies

(none)

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-large-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-large-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-large-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-large-2026-05-10.provenance.json>
- SHA-256: `b41e9813b32eeb3cd8179c40a0aeff470f4429c97e70e795c8be8b0632be104a`
- Bundle size: `7446` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-b200-single-node-large
cd public-study-artifacts/gds-b200-single-node-large
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-large-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-single-node-large-2026-05-10.provenance.json
printf "%s  %s\n" "b41e9813b32eeb3cd8179c40a0aeff470f4429c97e70e795c8be8b0632be104a" "gds-b200-single-node-large-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-b200-single-node-large-2026-05-10.tar.gz | head
```
