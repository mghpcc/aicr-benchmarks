# NCCL RTX pair policy

Purpose: RTX local pair-policy run.

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
- Scope: Focus rows: `rtx_pair_policy` from the shared RTX local suite bundle.

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### NCCL RTX pair policy Dashboard

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
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `allreduce` | `0,1` | `1proc_2g` | 1 | 2 | `passed` | 34.380 | 34.770 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `allgather` | `0,1` | `1proc_2g` | 1 | 2 | `passed` | 33.900 | 33.900 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `reduce_scatter` | `0,1` | `1proc_2g` | 1 | 2 | `passed` | 24.570 | 25.180 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `sendrecv` | `0,1` | `1proc_2g` | 1 | 2 | `passed` | 37.200 | 37.440 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `allreduce` | `2,3` | `1proc_2g` | 1 | 2 | `passed` | 34.470 | 35.160 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `allgather` | `2,3` | `1proc_2g` | 1 | 2 | `passed` | 33.330 | 33.340 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `reduce_scatter` | `2,3` | `1proc_2g` | 1 | 2 | `passed` | 25.200 | 25.200 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `sendrecv` | `2,3` | `1proc_2g` | 1 | 2 | `passed` | 37.010 | 37.380 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `allreduce` | `4,5` | `1proc_2g` | 1 | 2 | `passed` | 34.700 | 35.380 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `allgather` | `4,5` | `1proc_2g` | 1 | 2 | `passed` | 35.400 | 35.400 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `reduce_scatter` | `4,5` | `1proc_2g` | 1 | 2 | `passed` | 24.690 | 24.690 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `sendrecv` | `4,5` | `1proc_2g` | 1 | 2 | `passed` | 37.080 | 37.250 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `allreduce` | `6,7` | `1proc_2g` | 1 | 2 | `passed` | 34.980 | 35.900 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `allgather` | `6,7` | `1proc_2g` | 1 | 2 | `passed` | 35.290 | 35.290 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `reduce_scatter` | `6,7` | `1proc_2g` | 1 | 2 | `passed` | 24.710 | 24.710 | 0 | 0 | P2P,SYS | - |
| `a0002` | `1n` | `225232Z-r01` | `small` | `rtx_pair_policy` | `sendrecv` | `6,7` | `1proc_2g` | 1 | 2 | `passed` | 37.400 | 37.690 | 0 | 0 | P2P,SYS | - |

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

The matching provenance file is `nccl-rtx-local-suite-2026-05-10.provenance.json`.

## Generated Artifacts
