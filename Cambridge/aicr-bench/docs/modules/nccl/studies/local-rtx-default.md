# NCCL Default local RTX

<!-- aicr-study-status: published -->

Purpose: RTX 8-GPU local baseline.

## Command Run

```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=rtxpro6000 PROFILE=small NODELIST=a0002 APPLY=1
```

## Result Summary

- Module: `nccl`
- Cluster: `rtxpro6000`
- Profile: `small`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `a0002`
- Slurm jobs: `16553`
- Run IDs: `225232Z-r01`
- Result: all rows/jobs in this study passed.
- Scope: Focus rows: `rtx_8rank_1g`.

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### NCCL Default local RTX Dashboard

- Cluster: `rtxpro6000`
- Profile: `small`
- Jobs: `16553`
- Runs: `225232Z-r01`
- Nodes: `a0002`

### Rows Needing Review

- None

### Detailed Rows

Bandwidth values are `nccl-tests` `busbw` in GB/s.

| Entity | Node count | Run | Profile | Class | Op | GPU set | Rank shape | Ranks | -g | Status | Largest busbw (GB/s) | Max busbw (GB/s) | Wrong | RC | Hints | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_8rank_1g` | `allreduce` | `all` | `8rank_1g` | 8 | 1 | `passed` | 23.600 | 23.600 | 0 | 0 | SHM,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_8rank_1g` | `allgather` | `all` | `8rank_1g` | 8 | 1 | `passed` | 28.580 | 28.580 | 0 | 0 | SHM,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g` | 8 | 1 | `passed` | 20.690 | 20.690 | 0 | 0 | SHM,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_8rank_1g` | `alltoall` | `all` | `8rank_1g` | 8 | 1 | `passed` | 19.230 | 25.340 | 0 | 0 | SHM,SYS | - |

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-rtx-local-suite-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-rtx-local-suite-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-rtx-local-suite-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-rtx-local-suite-2026-05-10.provenance.json>
- SHA-256: `597434c2a74d21709c72cf1bcf24003bb17ab846c7f6cccd1f89356f39b1d771`
- Bundle size: `88576` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/nccl-rtx-local-suite
cd public-study-artifacts/nccl-rtx-local-suite
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-rtx-local-suite-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/nccl/2026-05-10/nccl-rtx-local-suite-2026-05-10.provenance.json
printf "%s  %s\n" "597434c2a74d21709c72cf1bcf24003bb17ab846c7f6cccd1f89356f39b1d771" "nccl-rtx-local-suite-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf nccl-rtx-local-suite-2026-05-10.tar.gz | head
```
