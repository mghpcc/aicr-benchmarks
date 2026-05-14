# NCCL B200 local 1 process 8 GPUs

<!-- aicr-study-status: published -->

Purpose: B200 local one-process eight-GPU run.

## Command Run

```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0003 APPLY=1
```

## Result Summary

- Module: `nccl`
- Cluster: `b200`
- Profile: `small`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `b0003`
- Slurm jobs: `16544`
- Run IDs: `223453Z-r01`
- Result: all rows/jobs in this study passed.
- Scope: Focus rows: `b200_1proc_8g` from the shared B200 local suite bundle.

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### NCCL B200 local 1 process 8 GPUs Dashboard

- Cluster: `b200`
- Profile: `small`
- Jobs: `16544`
- Runs: `223453Z-r01`
- Nodes: `b0003`

### Rows Needing Review

- None

### Detailed Rows

Bandwidth values are `nccl-tests` `busbw` in GB/s.

| Entity | Node count | Run | Profile | Class | Op | GPU set | Rank shape | Ranks | -g | Status | Largest busbw (GB/s) | Max busbw (GB/s) | Wrong | RC | Hints | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| `b0003` | `1n` | `223453Z-r01` | `small` | `b200_1proc_8g` | `allreduce` | `all` | `1proc_8g` | 1 | 8 | `passed` | 728.020 | 728.020 | 0 | 0 | P2P,SYS | - |
| `b0003` | `1n` | `223453Z-r01` | `small` | `b200_1proc_8g` | `allgather` | `all` | `1proc_8g` | 1 | 8 | `passed` | 635.400 | 635.400 | 0 | 0 | P2P,SYS | - |
| `b0003` | `1n` | `223453Z-r01` | `small` | `b200_1proc_8g` | `reduce_scatter` | `all` | `1proc_8g` | 1 | 8 | `passed` | 644.850 | 644.850 | 0 | 0 | P2P,SYS | - |
| `b0003` | `1n` | `223453Z-r01` | `small` | `b200_1proc_8g` | `alltoall` | `all` | `1proc_8g` | 1 | 8 | `passed` | 598.650 | 598.650 | 0 | 0 | P2P,SYS | - |

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-b200-local-suite-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-b200-local-suite-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-b200-local-suite-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-b200-local-suite-2026-05-10.provenance.json>
- SHA-256: `570ffb67e545198f62901d0c5da3b929df08ce5e76b432ea9ed68a2961bf1130`
- Bundle size: `390992` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/nccl-b200-local-suite
cd public-study-artifacts/nccl-b200-local-suite
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-b200-local-suite-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-b200-local-suite-2026-05-10.provenance.json
printf "%s  %s\n" "570ffb67e545198f62901d0c5da3b929df08ce5e76b432ea9ed68a2961bf1130" "nccl-b200-local-suite-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf nccl-b200-local-suite-2026-05-10.tar.gz | head
```
