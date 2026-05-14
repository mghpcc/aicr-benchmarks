# NCCL Default local B200

<!-- aicr-study-status: published -->

Purpose: B200 8-GPU local baseline.

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
- Scope: Focus rows: `b200_8rank_1g`.

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### NCCL Default local B200 Dashboard

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
| `b0003` | `1n` | `223453Z-r01` | `small` | `b200_8rank_1g` | `allreduce` | `all` | `8rank_1g` | 8 | 1 | `passed` | 729.650 | 729.650 | 0 | 0 | P2P,SYS | - |
| `b0003` | `1n` | `223453Z-r01` | `small` | `b200_8rank_1g` | `allgather` | `all` | `8rank_1g` | 8 | 1 | `passed` | 637.440 | 637.440 | 0 | 0 | P2P,SYS | - |
| `b0003` | `1n` | `223453Z-r01` | `small` | `b200_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g` | 8 | 1 | `passed` | 645.230 | 645.230 | 0 | 0 | P2P,SYS | - |
| `b0003` | `1n` | `223453Z-r01` | `small` | `b200_8rank_1g` | `alltoall` | `all` | `8rank_1g` | 8 | 1 | `passed` | 600.310 | 600.310 | 0 | 0 | P2P,SYS | - |

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
