# GDS RTX Single-node large

Purpose: RTX single-node `large` profile run.

## Command Run

```bash
make verify-gds CLUSTER=rtxpro6000 PROFILE=large NODELIST=a0001 APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `rtxpro6000`
- Profile: `large`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `a0001`
- Slurm jobs: `16559`
- Run IDs: `225740Z-r01`
- Result: all promoted rows/jobs in this study passed.
- Scope: RTX single-node `large` profile with sequential, random, async, and CPU/GPU read phases.
- Sequential read: `9.573 GiB/s`
- Sequential write: `5.894 GiB/s`
- Random read: `0.254 GiB/s`
- Random write: `0.067 GiB/s`

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### GDS rtxpro6000 2026-05-10

- Check: `gds`
- Cluster: `rtxpro6000`
- Partition: `GPU1`
- Discovery time: `2026-05-10T22:57:36Z`
- Mode: `apply`
- GDS profile: `large`
- Time limit: `02:30:00`

| Node | Slurm | Job | Run | Profile | Status | Platform | Sequential W/R | Sequential Read GiB/s | Sequential Write GiB/s | Random Read GiB/s | Random Write GiB/s | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a0001 | idle | 16559 | 225740Z-r01 | large | passed | Pass | Pass/Pass | 9.573 | 5.894 | 0.254 | 0.067 |  |

### GDS Phase Details

| Node | Profile | Phase | Status | GiB/s | Latency us | Ops | Time s | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a0001 | large | platform | Pass | - | - | - | - |  |
| a0001 | large | sequential-write | Pass | 5.894 | 42390.145 | 44887 | 119.002 |  |
| a0001 | large | sequential-read | Pass | 9.573 | 26103.691 | 73380 | 119.768 |  |
| a0001 | large | random-write | Pass | 0.067 | 3662.190 | 2093741 | 119.838 |  |
| a0001 | large | random-read | Pass | 0.254 | 960.298 | 7951698 | 119.310 |  |
| a0001 | large | async-stream-write | Pass | 2.975 | 83957.054 | 22693 | 119.197 |  |
| a0001 | large | async-stream-read | Pass | 8.753 | 28544.741 | 67093 | 119.767 |  |
| a0001 | large | cpu-gpu-read | Pass | 10.635 | 23540.699 | 40506 | 59.513 |  |

### GDS Statistics

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 9.573 | 9.573 | 0.000 | 9.573 | 9.573 | 9.573 | 9.573 | 9.573 | 9.573 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 5.894 | 5.894 | 0.000 | 5.894 | 5.894 | 5.894 | 5.894 | 5.894 | 5.894 | 0.000 | 0.000 |
| Random Read GiB/s | 1 | 0.254 | 0.254 | 0.000 | 0.254 | 0.254 | 0.254 | 0.254 | 0.254 | 0.254 | 0.000 | 0.000 |
| Random Write GiB/s | 1 | 0.067 | 0.067 | 0.000 | 0.067 | 0.067 | 0.067 | 0.067 | 0.067 | 0.067 | 0.000 | 0.000 |

### GDS Anomalies

(none)

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-large-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-large-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-large-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-large-2026-05-10.provenance.json>
- SHA-256: `25804a0af54a6d1cd3d1ae670a4ecba320e5886d78ef87b7e310bcf765c6abb4`
- Bundle size: `7285` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-rtx-single-node-large
cd public-study-artifacts/gds-rtx-single-node-large
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-large-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-rtx-single-node-large-2026-05-10.provenance.json
printf "%s  %s\n" "25804a0af54a6d1cd3d1ae670a4ecba320e5886d78ef87b7e310bcf765c6abb4" "gds-rtx-single-node-large-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-rtx-single-node-large-2026-05-10.tar.gz | head
```

The matching provenance file is `gds-rtx-single-node-large-2026-05-10.provenance.json`.

## Generated Artifacts

<details>
<summary>Full generated artifact list from provenance</summary>

- `results/by-date/2026-05-10/parsed/rtxpro6000/nodes/a0001/gds/225740Z-r01/status.json` (66 bytes)
- `results/by-date/2026-05-10/parsed/rtxpro6000/nodes/a0001/gds/225740Z-r01/summary.json` (13118 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/gds-summary.txt` (5065 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/gdscheck-platform.txt` (4162 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/gdsio-async-stream-read.txt` (199 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/gdsio-async-stream-write.txt` (199 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/gdsio-cpu-gpu-read.txt` (200 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/gdsio-random-read.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/gdsio-random-write.txt` (196 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/gdsio-sequential-read.txt` (198 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/gdsio-sequential-write.txt` (198 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/nvidia-smi-L.txt` (808 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/canonical/nvidia-smi-topo-m.txt` (1359 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/metadata/record.json` (2480 bytes)
- `results/by-date/2026-05-10/raw/rtxpro6000/nodes/a0001/gds/225740Z-r01/wrapper/cufile.log` (0 bytes)
- `results/reports/2026-05-10/gds/225736Z-gds-rtxpro6000.json` (967 bytes)
- `results/reports/2026-05-10/gds/gds-rtx-single-node-large-dashboard.md` (2812 bytes)
- `results/slurm/rtx-gds-1n-8g-16559.err` (0 bytes)
- `results/slurm/rtx-gds-1n-8g-16559.out` (382 bytes)

</details>
