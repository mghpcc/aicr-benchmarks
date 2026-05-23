# GDS B200 Custom gdsio

<!-- aicr-study-status: published -->

Purpose: B200 single-node custom `gdsio` argument run.

## Command Run

```bash
AICR_GDS_CUSTOM_GDSIO_ARGS="-x 0 -I 1 -d 0 -w 1 -m 0 -s 1G -i 1M" make verify-gds CLUSTER=b200 PROFILE=custom NODELIST=b0002 APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `b200`
- Profile: `custom`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `b0002`
- Slurm jobs: `16537`
- Run IDs: `220718Z-r01`
- Result: all rows/jobs in this study passed.
- Scope: Custom `gdsio` arguments supplied through `AICR_GDS_CUSTOM_GDSIO_ARGS`.
- Sequential read: `0.335 GiB/s`
- Sequential write: `0.335 GiB/s`

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### GDS b200 2026-05-10

- Check: `gds`
- Cluster: `b200`
- Partition: `GPU2` (now `b200-batch`)
- Discovery time: `2026-05-10T22:07:15Z`
- Mode: `apply`
- GDS profile: `custom`
- Time limit: `00:25:00`

| Node | Slurm | Job | Run | Profile | Status | Platform | Sequential W/R | Sequential Read GiB/s | Sequential Write GiB/s | Random Read GiB/s | Random Write GiB/s | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | idle | 16537 | 220718Z-r01 | custom | passed | - | - | 0.335 | 0.335 | - | - |  |

### GDS Statistics

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 0.335 | 0.335 | 0.000 | 0.335 | 0.335 | 0.335 | 0.335 | 0.335 | 0.335 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 0.335 | 0.335 | 0.000 | 0.335 | 0.335 | 0.335 | 0.335 | 0.335 | 0.335 | 0.000 | 0.000 |

### GDS Anomalies

(none)

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-custom-gdsio-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-custom-gdsio-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-custom-gdsio-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-custom-gdsio-2026-05-10.provenance.json>
- SHA-256: `4e40700314e06708dba9ab7e583394a50d475ffabd7cbc6a7a0906211f525ec6`
- Bundle size: `4420` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-b200-custom-gdsio
cd public-study-artifacts/gds-b200-custom-gdsio
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-custom-gdsio-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-custom-gdsio-2026-05-10.provenance.json
printf "%s  %s\n" "4e40700314e06708dba9ab7e583394a50d475ffabd7cbc6a7a0906211f525ec6" "gds-b200-custom-gdsio-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-b200-custom-gdsio-2026-05-10.tar.gz | head
```
