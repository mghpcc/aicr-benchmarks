# NCCL System Verification rtxpro6000 2026-05-16 2n

- Index: [nccl-suite-rtxpro6000.md](./nccl-suite-rtxpro6000.md)
- Profile: `small`
- Scale: `2n`
- Submitted jobs: 40
- Completed jobs: 40/40
- Detailed rows: 160/160
- Passed rows: 160/160
- Status: `passed`
- Shape: `8 MPI ranks per node, 1 GPU per rank, 16 CPU cores per rank`

## Group Rows

| Node Group | Nodes | GPUs | Samples | Passes | Status | AR Olympic avg | AR min..max | AR drop min/max | RS Olympic avg | RS min..max | RS drop min/max | AG Olympic avg | AG min..max | AG drop min/max | A2A Olympic avg | A2A min..max | A2A drop min/max | Wrong | Aggregation | Jobs |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |
| `a0002,a0003` | 2 | 16 | 5/5 | 5/5 | `passed` | 24.463 | 24.390..24.510 | 24.390/24.510 | 24.170 | 24.120..24.210 | 24.120/24.210 | 24.487 | 24.400..24.660 | 24.400/24.660 | 13.353 | 13.270..13.390 | 13.270/13.390 | 0 | olympic avg | `20998,21041,21077,21109,21139` |
| `a0004,a0005` | 2 | 16 | 5/5 | 5/5 | `passed` | 24.453 | 24.400..24.560 | 24.400/24.560 | 24.237 | 24.140..24.300 | 24.140/24.300 | 24.353 | 24.280..24.520 | 24.280/24.520 | 13.367 | 13.220..13.420 | 13.220/13.420 | 0 | olympic avg | `20999,21042,21078,21110,21140` |
| `a0006,a0007` | 2 | 16 | 5/5 | 5/5 | `passed` | 24.470 | 24.400..24.580 | 24.400/24.580 | 24.223 | 24.130..24.310 | 24.130/24.310 | 24.587 | 24.290..24.640 | 24.290/24.640 | 13.267 | 13.130..13.370 | 13.130/13.370 | 0 | olympic avg | `21000,21043,21079,21111,21141` |
| `a0008,a0009` | 2 | 16 | 5/5 | 5/5 | `passed` | 24.453 | 24.340..24.540 | 24.340/24.540 | 24.200 | 24.140..24.290 | 24.140/24.290 | 24.560 | 24.470..24.630 | 24.470/24.630 | 13.367 | 13.340..13.420 | 13.340/13.420 | 0 | olympic avg | `21001,21044,21080,21112,21142` |
| `a0010,a0011` | 2 | 16 | 5/5 | 5/5 | `passed` | 24.393 | 24.350..24.510 | 24.350/24.510 | 24.120 | 24.010..24.160 | 24.010/24.160 | 24.310 | 24.160..24.560 | 24.160/24.560 | 13.363 | 13.310..13.450 | 13.310/13.450 | 0 | olympic avg | `21002,21045,21081,21113,21143` |
| `a0012,a0013` | 2 | 16 | 5/5 | 5/5 | `passed` | 24.423 | 24.350..24.520 | 24.350/24.520 | 24.197 | 24.110..24.320 | 24.110/24.320 | 24.383 | 24.210..24.680 | 24.210/24.680 | 13.387 | 13.370..13.410 | 13.370/13.410 | 0 | olympic avg | `21003,21046,21082,21114,21144` |
| `a0014,a0015` | 2 | 16 | 5/5 | 5/5 | `passed` | 24.457 | 24.360..24.520 | 24.360/24.520 | 24.250 | 24.030..24.330 | 24.030/24.330 | 24.383 | 24.220..24.490 | 24.220/24.490 | 13.360 | 13.320..13.400 | 13.320/13.400 | 0 | olympic avg | `21004,21047,21083,21115,21145` |
| `a0016,a0019` | 2 | 16 | 5/5 | 5/5 | `passed` | 24.173 | 24.030..24.320 | 24.030/24.320 | 23.950 | 23.680..24.110 | 23.680/24.110 | 24.213 | 24.100..24.340 | 24.100/24.340 | 13.367 | 13.360..13.380 | 13.360/13.380 | 0 | olympic avg | `21005,21048,21084,21116,21146` |

Bandwidth columns are largest-message `busbw` in GB/s.
Olympic avg columns aggregate passed samples for each node group. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

## Per-Op Statistics

Only passed rows with numeric largest-message `busbw` values are included. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

| Metric | n | Olympic avg | Min | Max | Dropped min/max | Aggregation |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| AR busbw | 40 | 24.419 | 24.030 | 24.580 | 24.030/24.580 | olympic avg from 38/40; dropped min/max |
| RS busbw | 40 | 24.169 | 23.680 | 24.330 | 23.680/24.330 | olympic avg from 38/40; dropped min/max |
| AG busbw | 40 | 24.413 | 24.100 | 24.680 | 24.100/24.680 | olympic avg from 38/40; dropped min/max |
| A2A busbw | 40 | 13.354 | 13.130 | 13.450 | 13.130/13.450 | olympic avg from 38/40; dropped min/max |

## Bandwidth Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for `Delta` and anomaly-label definitions.

| Severity | Node Group | Metric | Value | Median | Delta |
| --- | --- | --- | ---: | ---: | ---: |
| low_tail | `a0016,a0019` | AR busbw | 24.173 | 24.453 | -1.1% |
| low_tail | `a0016,a0019` | RS busbw | 23.950 | 24.198 | -1.0% |

`Value` uses Olympic avg per node group before fleet-median comparison.

## Rows Needing Review

- None

## Detailed Rows

| Entity | Scale | Run | Profile | Class | Op | GPU set | Rank shape | Ranks | -g | Status | Largest busbw | Max busbw | Wrong | RC | Hints | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
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
