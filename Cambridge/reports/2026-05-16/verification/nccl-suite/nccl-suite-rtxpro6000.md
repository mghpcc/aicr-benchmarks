# NCCL System Verification rtxpro6000 2026-05-16

This dashboard is an operator index for rank-per-GPU system verification. Use the per-scale drilldowns for job-shape detail and the by-node dashboard for benchmark candidate selection.

## Run Overview

| Field | Value |
| --- | --- |
| Profile | `small` |
| Scales | `1,2,4` |
| Repeat aggregation | `olympic` |
| GPU preflight filter | `enabled` |
| Submitted jobs | 140 |
| Completed jobs | 140/140 |
| Detailed rows | 560/560 |
| Passed rows | 560/560 |
| Status counts | `passed=560` |
| Rows needing review | 0 |
| Shape | `8 MPI ranks per node, 1 GPU per rank, 16 CPU cores per rank` |
| GPU preflight source | `latest same-day gpu-topology parsed summaries` |
| GPU preflight expected count | `8` |
| GPU preflight excluded nodes | 0 |

RTX NCCL scale coverage intentionally stops at `4n` for this verification deliverable. The same-day candidate pool had 16 passed nodes after state skips, and the standard RTX verification ladder for this campaign was `1n`, `2n`, and `4n`.

## Skipped Nodes

- `drained*`: a0017
- `mixed`: a0018


## Scale Coverage

| Scale | Jobs | Completed | Rows | Passes | Status | Drilldown |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| `1n` | 80 | 80/80 | 320/320 | 320/320 | `passed` | [1n](./nccl-suite-rtxpro6000-1n.md) |
| `2n` | 40 | 40/40 | 160/160 | 160/160 | `passed` | [2n](./nccl-suite-rtxpro6000-2n.md) |
| `4n` | 20 | 20/20 | 80/80 | 80/80 | `passed` | [4n](./nccl-suite-rtxpro6000-4n.md) |

## Fleet Olympic avgs

| Scale | AR Olympic avg | RS Olympic avg | AG Olympic avg | A2A Olympic avg |
| --- | ---: | ---: | ---: | ---: |
| `1n` | 21.852 | 19.796 | 24.766 | 7.150 |
| `2n` | 24.419 | 24.169 | 24.413 | 13.354 |
| `4n` | 24.298 | 24.238 | 24.445 | 11.814 |

Bandwidth columns are largest-message `busbw` in GB/s.
See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation definitions.

## Rows Needing Review

- None

## Benchmark Node Selection Notes

- Treat this NCCL report as communication-readiness evidence for the same-day by-node dashboard.
- Strict benchmark candidates are selected from the by-node JSON only when the overall node status is `passed`.
- No NCCL rows currently remove nodes from the strict candidate pool.

## Detailed Rows

| Entity | Scale | Run | Profile | Class | Op | GPU set | Rank shape | Ranks | -g | Status | Largest busbw | Max busbw | Wrong | RC | Hints | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| `a0002` | `1n` | `141025Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.780 | 21.780 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `141025Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.100 | 25.100 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `141025Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.740 | 19.750 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `141025Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.640 | 21.400 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `141031Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.900 | 21.900 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `141031Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.770 | 24.770 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `141031Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.880 | 19.880 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `141031Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.370 | 21.450 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `141037Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.620 | 21.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `141037Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.700 | 24.700 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `141037Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.760 | 19.760 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `141037Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.700 | 21.490 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `141040Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.980 | 21.980 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `141040Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.640 | 24.640 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `141040Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.880 | 19.890 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `141040Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.220 | 21.640 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `141046Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.860 | 21.860 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `141046Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.590 | 24.590 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `141046Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.740 | 19.740 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `141046Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.710 | 21.550 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `141052Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.550 | 21.550 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `141052Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.430 | 24.430 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `141052Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.630 | 19.630 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `141052Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.390 | 21.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `141055Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.910 | 21.910 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `141055Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.040 | 25.040 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `141055Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.740 | 19.740 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `141055Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.250 | 21.430 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `141102Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.950 | 21.950 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `141102Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.740 | 24.740 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `141102Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.950 | 19.950 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `141102Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.510 | 19.400 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `141107Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.970 | 21.970 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `141107Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.780 | 24.780 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `141107Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.930 | 19.950 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `141107Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.380 | 21.530 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `141110Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.940 | 21.940 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `141110Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.760 | 24.770 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `141110Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.830 | 19.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `141110Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.140 | 21.620 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `141116Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.940 | 21.940 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `141116Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.750 | 24.750 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `141116Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.850 | 19.850 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `141116Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.950 | 21.640 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `141122Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.940 | 21.940 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `141122Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.060 | 25.060 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `141122Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.830 | 19.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `141122Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 11.200 | 21.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `141125Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.880 | 21.880 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `141125Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.910 | 24.910 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `141125Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.810 | 19.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `141125Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.560 | 21.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `141131Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.700 | 21.700 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `141131Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.640 | 24.640 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `141131Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.650 | 19.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `141131Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.280 | 21.510 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `141137Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.860 | 21.860 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `141137Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.280 | 25.280 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `141137Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.800 | 19.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `141137Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.150 | 21.520 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `141143Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.650 | 21.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `141143Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.710 | 24.710 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `141143Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.760 | 19.760 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `141143Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.070 | 21.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `141333Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.510 | 24.510 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `141333Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.400 | 24.400 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `141333Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.140 | 24.140 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `141333Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.270 | 13.410 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `141338Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.560 | 24.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `141338Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.360 | 24.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `141338Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.280 | 24.280 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `141338Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.370 | 13.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `141343Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.430 | 24.430 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `141343Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.640 | 24.640 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `141343Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.310 | 24.310 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `141343Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.130 | 13.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `141348Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.510 | 24.510 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `141348Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.630 | 24.630 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `141348Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.230 | 24.230 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `141348Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.370 | 13.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `141353Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.460 | 24.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `141353Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.560 | 24.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `141353Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.160 | 24.160 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `141353Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.380 | 13.380 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `141358Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.430 | 24.430 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `141358Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.680 | 24.680 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `141358Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.310 | 24.310 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `141358Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.400 | 13.430 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `141403Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.520 | 24.530 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `141403Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.290 | 24.310 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `141403Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.300 | 24.300 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `141403Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.350 | 13.420 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `141408Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.320 | 24.380 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `141408Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.120 | 24.120 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `141408Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 23.990 | 24.020 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `141408Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.360 | 13.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `141600Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.280 | 24.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `141600Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.550 | 24.590 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `141600Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.200 | 24.200 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `141600Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.780 | 11.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `141605Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.280 | 24.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `141605Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.540 | 24.540 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `141605Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.380 | 24.380 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `141605Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.830 | 11.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `141610Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.320 | 24.400 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `141610Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.560 | 24.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `141610Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.090 | 24.140 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `141610Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.830 | 11.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `141615Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 23.960 | 24.200 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `141615Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.160 | 24.280 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `141615Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.160 | 24.160 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `141615Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.810 | 11.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `141917Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.830 | 21.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `141917Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.130 | 25.130 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `141917Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.760 | 19.770 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `141917Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 4.830 | 21.630 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `141922Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.860 | 21.860 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `141922Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.940 | 24.940 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `141922Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.860 | 19.870 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `141922Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 11.120 | 21.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `141928Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.710 | 21.720 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `141928Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.560 | 24.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `141928Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.730 | 19.730 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `141928Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.320 | 21.590 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `141932Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.950 | 21.950 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `141932Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.670 | 24.670 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `141932Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.920 | 19.920 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `141932Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.990 | 21.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `141937Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.750 | 21.750 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `141937Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.950 | 24.950 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `141937Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.680 | 19.690 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `141937Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 10.710 | 20.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `141942Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.500 | 21.500 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `141942Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.460 | 24.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `141942Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.690 | 19.690 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `141942Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.670 | 21.470 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `141947Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.810 | 21.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `141947Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.060 | 25.060 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `141947Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.770 | 19.780 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `141947Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.940 | 21.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `141952Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.720 | 21.720 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `141952Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.650 | 24.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `141952Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.900 | 19.900 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `141952Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.540 | 21.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `141957Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 22.010 | 22.010 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `141957Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.650 | 24.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `141957Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.980 | 19.990 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `141957Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.840 | 21.510 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `142002Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.840 | 21.840 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `142002Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.760 | 24.760 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `142002Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.830 | 19.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `142002Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.410 | 21.590 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `142007Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.800 | 21.800 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `142007Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.800 | 24.800 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `142007Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.870 | 19.870 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `142007Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.280 | 21.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `142012Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 22.000 | 22.000 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `142012Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.630 | 24.630 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `142012Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.820 | 19.840 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `142012Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.360 | 21.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `142017Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.980 | 21.980 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `142017Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.680 | 24.680 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `142017Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.850 | 19.850 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `142017Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.280 | 21.340 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `142022Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.520 | 21.520 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `142022Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.510 | 24.510 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `142022Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.650 | 19.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `142022Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.980 | 21.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `142029Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.850 | 21.850 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `142029Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.740 | 24.800 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `142029Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.770 | 19.780 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `142029Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.160 | 21.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `142032Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.760 | 21.780 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `142032Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.590 | 24.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `142032Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.760 | 19.760 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `142032Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.820 | 21.620 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `142224Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.420 | 24.420 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `142224Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.480 | 24.480 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `142224Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.190 | 24.190 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `142224Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.390 | 13.410 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `142229Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.400 | 24.400 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `142229Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.520 | 24.520 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `142229Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.200 | 24.210 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `142229Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.350 | 13.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `142234Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.460 | 24.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `142234Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.570 | 24.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `142234Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.130 | 24.130 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `142234Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.200 | 13.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `142239Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.410 | 24.420 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `142239Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.470 | 24.470 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `142239Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.290 | 24.300 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `142239Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.370 | 13.410 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `142244Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.510 | 24.510 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `142244Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.480 | 24.480 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `142244Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.010 | 24.010 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `142244Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.350 | 13.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `142249Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.380 | 24.380 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `142249Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.530 | 24.530 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `142249Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.320 | 24.320 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `142249Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.370 | 13.400 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `142254Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.460 | 24.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `142254Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.490 | 24.490 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `142254Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.030 | 24.150 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `142254Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.350 | 13.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `142259Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.030 | 24.120 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `142259Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.270 | 24.300 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `142259Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.010 | 24.040 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `142259Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.360 | 13.400 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `142452Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.310 | 24.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `142452Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.450 | 24.450 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `142452Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.250 | 24.250 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `142452Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.820 | 11.820 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `142457Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.410 | 24.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `142457Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.550 | 24.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `142457Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.310 | 24.310 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `142457Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.810 | 11.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `142502Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.380 | 24.380 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `142502Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.460 | 24.480 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `142502Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.360 | 24.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `142502Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.830 | 11.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `142507Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.430 | 24.450 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `142507Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.280 | 24.350 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `142507Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.120 | 24.120 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `142507Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.830 | 11.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `142809Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.830 | 21.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `142809Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.990 | 24.990 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `142809Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.730 | 19.740 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `142809Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.920 | 21.550 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `142814Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.980 | 21.980 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `142814Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.620 | 24.620 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `142814Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.790 | 19.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `142814Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.420 | 21.590 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `142819Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.780 | 21.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `142819Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.630 | 24.630 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `142819Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.730 | 19.730 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `142819Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.310 | 21.540 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `142824Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.910 | 21.910 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `142824Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.740 | 24.760 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `142824Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.910 | 19.910 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `142824Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.080 | 21.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `142829Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.810 | 21.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `142829Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.510 | 24.550 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `142829Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.730 | 19.730 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `142829Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.570 | 21.500 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `142834Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.640 | 21.640 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `142834Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.500 | 24.500 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `142834Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.610 | 19.620 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `142834Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.600 | 21.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `142839Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.780 | 21.780 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `142839Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.920 | 24.920 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `142839Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.700 | 19.710 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `142839Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.750 | 21.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `142844Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.990 | 21.990 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `142844Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.600 | 24.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `142844Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.890 | 19.890 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `142844Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 9.210 | 21.620 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `142849Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 22.040 | 22.040 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `142849Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.730 | 24.730 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `142849Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.990 | 20.000 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `142849Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.140 | 21.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `142854Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.910 | 21.910 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `142854Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.120 | 25.120 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `142854Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.810 | 19.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `142854Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.570 | 21.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `142859Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.990 | 21.990 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `142859Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.740 | 24.740 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `142859Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.870 | 19.870 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `142859Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.470 | 20.840 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `142904Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.930 | 21.930 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `142904Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.870 | 24.870 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `142904Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.850 | 19.860 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `142904Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.200 | 21.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `142909Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.940 | 21.940 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `142909Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.240 | 25.240 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `142909Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.840 | 19.840 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `142909Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.100 | 21.660 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `142914Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.760 | 21.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `142914Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.780 | 24.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `142914Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.630 | 19.630 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `142914Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 3.980 | 21.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `142919Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.820 | 21.820 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `142919Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.030 | 25.030 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `142919Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.730 | 19.750 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `142919Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.360 | 21.580 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `142924Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.710 | 21.710 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `142924Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.630 | 24.630 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `142924Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.760 | 19.760 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `142924Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.620 | 21.590 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `143116Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.390 | 24.410 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `143116Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.460 | 24.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `143116Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.180 | 24.180 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `143116Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.330 | 13.330 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `143121Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.430 | 24.450 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `143121Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.370 | 24.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `143121Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.140 | 24.140 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `143121Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.420 | 13.420 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `143126Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.400 | 24.410 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `143126Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.290 | 24.290 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `143126Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.310 | 24.310 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `143126Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.330 | 13.390 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `143131Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.540 | 24.590 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `143131Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.530 | 24.530 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `143131Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.190 | 24.190 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `143131Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.420 | 13.420 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `143136Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.370 | 24.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `143136Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.250 | 24.250 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `143136Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.160 | 24.160 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `143136Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.360 | 13.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `143141Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.520 | 24.520 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `143141Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.280 | 24.280 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `143141Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.120 | 24.120 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `143141Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.380 | 13.380 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `143146Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.410 | 24.410 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `143146Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.220 | 24.230 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `143146Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.270 | 24.270 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `143146Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.380 | 13.400 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `143151Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.150 | 24.190 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `143151Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.250 | 24.250 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `143151Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 23.850 | 23.910 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `143151Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.380 | 13.420 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `143343Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.380 | 24.380 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `143343Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.510 | 24.510 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `143343Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.350 | 24.350 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `143343Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.820 | 11.820 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `143348Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.430 | 24.490 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `143348Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.520 | 24.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `143348Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.270 | 24.270 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `143348Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.810 | 11.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `143353Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.180 | 24.310 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `143353Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.480 | 24.480 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `143353Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.130 | 24.130 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `143353Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.750 | 11.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `143358Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 23.820 | 24.100 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `143358Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.150 | 24.290 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `143358Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.280 | 24.280 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `143358Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.800 | 11.800 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `143646Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.910 | 21.910 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `143646Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.920 | 24.920 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `143646Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.710 | 19.740 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `143646Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.350 | 21.540 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `143651Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.970 | 21.970 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `143651Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.670 | 24.670 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `143651Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.790 | 19.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `143651Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.960 | 21.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `143656Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.920 | 21.920 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `143656Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.600 | 24.610 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `143656Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.660 | 19.670 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `143656Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.250 | 21.420 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `143701Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 22.010 | 22.010 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `143701Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.690 | 24.690 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `143701Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.970 | 19.970 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `143701Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.510 | 21.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `143706Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.830 | 21.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `143706Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.490 | 24.500 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `143706Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.730 | 19.730 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `143706Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 9.370 | 21.620 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `143711Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.490 | 21.490 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `143711Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.350 | 24.350 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `143711Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.650 | 19.660 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `143711Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.360 | 20.700 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `143716Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.870 | 21.870 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `143716Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.890 | 24.890 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `143716Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.740 | 19.750 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `143716Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 9.660 | 22.740 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `143721Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 22.070 | 22.070 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `143721Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.750 | 24.750 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `143721Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.930 | 19.930 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `143721Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.380 | 21.580 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `143729Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.910 | 21.910 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `143729Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.670 | 24.670 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `143729Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.980 | 19.990 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `143729Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.890 | 21.500 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `143731Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.860 | 21.860 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `143731Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.570 | 24.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `143731Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.820 | 19.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `143731Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.590 | 21.620 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `143736Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.980 | 21.980 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `143736Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.620 | 24.620 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `143736Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.900 | 19.910 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `143736Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 3.790 | 21.500 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `143741Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.970 | 21.970 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `143741Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.990 | 24.990 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `143741Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.820 | 19.820 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `143741Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.560 | 21.520 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `143746Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.990 | 21.990 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `143746Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.010 | 25.010 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `143746Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.800 | 19.820 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `143746Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.030 | 20.400 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `143751Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.790 | 21.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `143751Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.550 | 24.550 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `143751Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.640 | 19.640 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `143751Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 4.520 | 21.610 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `143756Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.890 | 21.890 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `143756Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.690 | 24.690 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `143756Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.780 | 19.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `143756Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.500 | 21.480 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `143801Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.650 | 21.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `143801Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.530 | 24.530 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `143801Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.730 | 19.730 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `143801Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.650 | 21.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `143953Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.500 | 24.500 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `143953Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.660 | 24.660 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `143953Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.120 | 24.120 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `143953Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.380 | 13.390 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `143958Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.480 | 24.520 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `143958Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.330 | 24.330 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `143958Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.230 | 24.230 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `143958Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.220 | 13.400 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `144003Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.520 | 24.530 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `144003Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.640 | 24.640 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `144003Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.190 | 24.190 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `144003Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.270 | 13.340 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `144008Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.440 | 24.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `144008Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.600 | 24.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `144008Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.180 | 24.180 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `144008Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.340 | 13.340 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `144013Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.350 | 24.350 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `144013Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.200 | 24.220 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `144013Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.080 | 24.080 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `144013Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.450 | 13.450 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `144018Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.460 | 24.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `144018Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.210 | 24.230 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `144018Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.110 | 24.110 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `144018Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.380 | 13.380 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `144023Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.500 | 24.500 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `144023Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.390 | 24.410 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `144023Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.180 | 24.220 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `144023Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.320 | 13.390 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `144028Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.090 | 24.140 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `144028Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.340 | 24.340 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `144028Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.110 | 24.190 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `144028Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.360 | 13.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `144220Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.320 | 24.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `144220Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.440 | 24.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `144220Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.260 | 24.260 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `144220Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.820 | 11.820 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `144225Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.320 | 24.350 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `144225Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.560 | 24.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `144225Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.250 | 24.300 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `144225Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.810 | 11.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `144230Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.350 | 24.420 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `144230Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.510 | 24.510 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `144230Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.090 | 24.090 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `144230Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.810 | 11.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `144235Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.260 | 24.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `144235Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.290 | 24.350 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `144235Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.260 | 24.260 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `144235Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.790 | 11.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `144522Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.880 | 21.880 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `144522Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.840 | 24.840 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `144522Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.750 | 19.750 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002` | `1n` | `144522Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.200 | 21.450 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `144528Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.870 | 21.870 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `144528Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.050 | 25.050 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `144528Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.800 | 19.800 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0003` | `1n` | `144528Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.740 | 21.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `144533Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.570 | 21.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `144533Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.550 | 24.550 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `144533Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.800 | 19.800 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004` | `1n` | `144533Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.410 | 21.540 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `144538Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 22.040 | 22.040 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `144538Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.790 | 24.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `144538Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.920 | 19.930 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0005` | `1n` | `144538Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 9.420 | 21.630 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `144543Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.790 | 21.790 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `144543Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.930 | 24.940 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `144543Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.730 | 19.750 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006` | `1n` | `144543Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.550 | 21.570 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `144548Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.580 | 21.590 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `144548Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.800 | 24.800 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `144548Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.600 | 19.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0007` | `1n` | `144548Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.540 | 21.520 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `144553Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.820 | 21.820 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `144553Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.150 | 25.150 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `144553Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.750 | 19.760 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008` | `1n` | `144553Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.070 | 22.760 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `144558Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.970 | 21.970 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `144558Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.610 | 24.610 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `144558Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.900 | 19.900 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0009` | `1n` | `144558Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.400 | 21.600 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `144603Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 22.070 | 22.070 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `144603Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.560 | 24.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `144603Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.960 | 19.960 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010` | `1n` | `144603Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 8.260 | 21.470 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `144608Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.960 | 21.960 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `144608Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.870 | 24.870 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `144608Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.800 | 19.800 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0011` | `1n` | `144608Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.940 | 21.630 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `144613Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.950 | 21.950 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `144613Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.690 | 24.690 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `144613Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.860 | 19.860 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012` | `1n` | `144613Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.550 | 20.990 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `144618Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.960 | 21.960 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `144618Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.130 | 25.130 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `144618Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.870 | 19.880 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0013` | `1n` | `144618Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.190 | 21.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `144623Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.940 | 21.940 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `144623Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.010 | 25.010 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `144623Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.800 | 19.800 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014` | `1n` | `144623Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 5.980 | 21.640 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `144629Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.710 | 21.710 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `144629Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.470 | 24.470 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `144629Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.640 | 19.640 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0015` | `1n` | `144629Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 7.800 | 20.650 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `144633Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.870 | 21.870 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `144633Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 25.050 | 25.050 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `144633Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.820 | 19.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016` | `1n` | `144633Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.180 | 21.530 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `144638Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 21.780 | 21.780 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `144638Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 24.580 | 24.580 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `144638Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 19.850 | 19.850 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0019` | `1n` | `144638Z-r01` | `small` | `rtxpro6000_scale_1n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 8 | 1 | `passed` | 6.050 | 21.560 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `144830Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.470 | 24.470 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `144830Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.520 | 24.520 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `144830Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.210 | 24.210 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003` | `2n` | `144830Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.350 | 13.350 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `144835Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.450 | 24.450 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `144835Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.280 | 24.280 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `144835Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.300 | 24.300 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0004,a0005` | `2n` | `144835Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.380 | 13.380 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `144840Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.580 | 24.590 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `144840Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.550 | 24.550 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `144840Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.170 | 24.170 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007` | `2n` | `144840Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.370 | 13.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `144845Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.340 | 24.340 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `144845Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.550 | 24.550 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `144845Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.140 | 24.140 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0008,a0009` | `2n` | `144845Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.360 | 13.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `144850Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.350 | 24.350 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `144850Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.160 | 24.160 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `144850Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.120 | 24.120 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011` | `2n` | `144850Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.310 | 13.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `144854Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.350 | 24.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `144854Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.340 | 24.340 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `144854Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.160 | 24.160 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0012,a0013` | `2n` | `144854Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.410 | 13.410 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `144900Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.360 | 24.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `144900Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.470 | 24.480 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `144900Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.330 | 24.330 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015` | `2n` | `144900Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.400 | 13.410 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `144905Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.280 | 24.280 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `144905Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 24.100 | 24.100 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `144905Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 23.680 | 23.700 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0016,a0019` | `2n` | `144905Z-r01` | `small` | `rtxpro6000_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 13.380 | 13.380 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `145057Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.270 | 24.290 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `145057Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.410 | 24.500 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `145057Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.170 | 24.180 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0002,a0003,a0004,a0005` | `4n` | `145057Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.820 | 11.820 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `145102Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.420 | 24.460 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `145102Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.590 | 24.620 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `145102Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.280 | 24.280 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0006,a0007,a0008,a0009` | `4n` | `145102Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.820 | 11.820 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `145107Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.320 | 24.370 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `145107Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.470 | 24.530 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `145107Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.300 | 24.300 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0010,a0011,a0012,a0013` | `4n` | `145107Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.810 | 11.810 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `145112Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.180 | 24.310 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `145112Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.270 | 24.360 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `145112Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 24.240 | 24.240 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
| `a0014,a0015,a0016,a0019` | `4n` | `145112Z-r01` | `small` | `rtxpro6000_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 11.830 | 11.830 | 0 | 0 | SHM,NET/IB,SYS,GDRDMA |  |
