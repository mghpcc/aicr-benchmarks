# NCCL System Verification b200 2026-05-16 2n

- Index: [nccl-suite-b200.md](./nccl-suite-b200.md)
- Profile: `small`
- Scale: `2n`
- Submitted jobs: 75
- Completed jobs: 75/75
- Detailed rows: 300/300
- Passed rows: 300/300
- Status: `passed`
- Shape: `8 MPI ranks per node, 1 GPU per rank, 16 CPU cores per rank`

## Group Rows

| Node Group | Nodes | GPUs | Samples | Passes | Status | AR Olympic avg | AR min..max | AR drop min/max | RS Olympic avg | RS min..max | RS drop min/max | AG Olympic avg | AG min..max | AG drop min/max | A2A Olympic avg | A2A min..max | A2A drop min/max | Wrong | Aggregation | Jobs |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |
| `b0002,b0003` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.613 | 388.260..389.100 | 388.260/389.100 | 213.877 | 213.450..214.160 | 213.450/214.160 | 213.603 | 213.150..214.440 | 213.150/214.440 | 50.327 | 50.300..50.360 | 50.300/50.360 | 0 | olympic avg | `21010,21181,21247,21320,21398` |
| `b0004,b0005` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.540 | 388.500..388.750 | 388.500/388.750 | 213.673 | 213.370..214.170 | 213.370/214.170 | 214.080 | 213.720..214.150 | 213.720/214.150 | 50.357 | 50.340..50.370 | 50.340/50.370 | 0 | olympic avg | `21011,21182,21248,21321,21399` |
| `b0006,b0007` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.750 | 388.460..389.000 | 388.460/389.000 | 213.800 | 213.290..214.180 | 213.290/214.180 | 213.590 | 212.930..213.810 | 212.930/213.810 | 50.363 | 50.320..50.380 | 50.320/50.380 | 0 | olympic avg | `21012,21183,21249,21322,21400` |
| `b0008,b0009` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.757 | 388.510..388.870 | 388.510/388.870 | 213.833 | 212.930..213.990 | 212.930/213.990 | 213.743 | 213.460..214.340 | 213.460/214.340 | 50.337 | 50.330..50.380 | 50.330/50.380 | 0 | olympic avg | `21013,21184,21250,21323,21401` |
| `b0010,b0011` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.747 | 388.490..388.960 | 388.490/388.960 | 213.877 | 213.530..214.270 | 213.530/214.270 | 213.743 | 213.500..214.060 | 213.500/214.060 | 50.377 | 50.360..50.400 | 50.360/50.400 | 0 | olympic avg | `21014,21185,21251,21324,21402` |
| `b0012,b0013` | 2 | 16 | 5/5 | 5/5 | `passed` | 389.000 | 388.790..389.180 | 388.790/389.180 | 213.573 | 213.150..213.780 | 213.150/213.780 | 213.630 | 213.210..213.760 | 213.210/213.760 | 50.363 | 50.320..50.380 | 50.320/50.380 | 0 | olympic avg | `21015,21186,21252,21325,21403` |
| `b0014,b0015` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.700 | 388.630..388.860 | 388.630/388.860 | 214.183 | 213.770..214.320 | 213.770/214.320 | 213.870 | 213.190..214.420 | 213.190/214.420 | 50.350 | 50.340..50.390 | 50.340/50.390 | 0 | olympic avg | `21016,21187,21253,21326,21404` |
| `b0016,b0017` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.797 | 388.490..388.960 | 388.490/388.960 | 213.673 | 213.120..214.360 | 213.120/214.360 | 213.573 | 213.070..214.030 | 213.070/214.030 | 50.360 | 50.340..50.370 | 50.340/50.370 | 0 | olympic avg | `21017,21188,21254,21327,21405` |
| `b0018,b0019` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.860 | 388.600..388.980 | 388.600/388.980 | 213.993 | 213.600..214.690 | 213.600/214.690 | 214.293 | 213.880..214.550 | 213.880/214.550 | 50.340 | 50.320..50.370 | 50.320/50.370 | 0 | olympic avg | `21018,21189,21255,21328,21406` |
| `b0020,b0021` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.947 | 388.740..389.220 | 388.740/389.220 | 214.067 | 213.630..214.750 | 213.630/214.750 | 213.523 | 212.890..214.370 | 212.890/214.370 | 50.357 | 50.340..50.390 | 50.340/50.390 | 0 | olympic avg | `21019,21190,21257,21329,21407` |
| `b0022,b0023` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.680 | 388.560..388.810 | 388.560/388.810 | 213.833 | 213.730..214.480 | 213.730/214.480 | 213.893 | 213.620..214.430 | 213.620/214.430 | 50.347 | 50.310..50.360 | 50.310/50.360 | 0 | olympic avg | `21020,21191,21258,21330,21408` |
| `b0024,b0025` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.817 | 388.600..389.250 | 388.600/389.250 | 213.253 | 212.750..213.440 | 212.750/213.440 | 213.303 | 213.030..213.830 | 213.030/213.830 | 50.357 | 50.340..50.370 | 50.340/50.370 | 0 | olympic avg | `21021,21192,21259,21331,21409` |
| `b0026,b0027` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.900 | 388.370..389.000 | 388.370/389.000 | 213.747 | 213.490..214.090 | 213.490/214.090 | 213.633 | 213.270..214.080 | 213.270/214.080 | 50.353 | 50.330..50.370 | 50.330/50.370 | 0 | olympic avg | `21022,21193,21260,21332,21410` |
| `b0028,b0029` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.543 | 388.320..388.640 | 388.320/388.640 | 213.853 | 213.320..214.300 | 213.320/214.300 | 213.903 | 213.490..214.090 | 213.490/214.090 | 50.347 | 50.330..50.390 | 50.330/50.390 | 0 | olympic avg | `21023,21194,21261,21333,21411` |
| `b0030,b0031` | 2 | 16 | 5/5 | 5/5 | `passed` | 388.920 | 388.460..389.080 | 388.460/389.080 | 213.763 | 213.450..213.980 | 213.450/213.980 | 213.813 | 213.410..214.410 | 213.410/214.410 | 50.360 | 50.320..50.370 | 50.320/50.370 | 0 | olympic avg | `21024,21195,21262,21334,21412` |

Bandwidth columns are largest-message `busbw` in GB/s.
Olympic avg columns aggregate passed samples for each node group. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

## Per-Op Statistics

Only passed rows with numeric largest-message `busbw` values are included. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

| Metric | n | Olympic avg | Min | Max | Dropped min/max | Aggregation |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| AR busbw | 75 | 388.762 | 388.260 | 389.250 | 388.260/389.250 | olympic avg from 73/75; dropped min/max |
| RS busbw | 75 | 213.795 | 212.750 | 214.750 | 212.750/214.750 | olympic avg from 73/75; dropped min/max |
| AG busbw | 75 | 213.750 | 212.890 | 214.550 | 212.890/214.550 | olympic avg from 73/75; dropped min/max |
| A2A busbw | 75 | 50.353 | 50.300 | 50.400 | 50.300/50.400 | olympic avg from 73/75; dropped min/max |

## Bandwidth Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for `Delta` and anomaly-label definitions.

(none)

## Rows Needing Review

- None

## Detailed Rows

| Entity | Scale | Run | Profile | Class | Op | GPU set | Rank shape | Ranks | -g | Status | Largest busbw | Max busbw | Wrong | RC | Hints | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| `b0002,b0003` | `2n` | `141720Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.750 | 388.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `141720Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.440 | 214.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `141720Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.860 | 213.860 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `141720Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `141725Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.550 | 388.550 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `141725Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.130 | 214.130 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `141725Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.170 | 214.170 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `141725Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `141730Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.930 | 388.930 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `141730Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.630 | 213.630 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `141730Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.180 | 214.180 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `141730Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `141735Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.860 | 388.860 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `141735Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.340 | 214.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `141735Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.920 | 213.920 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `141735Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `141740Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.800 | 388.800 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `141740Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.640 | 213.640 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `141740Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.730 | 213.730 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `141740Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `141745Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 389.150 | 389.150 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `141745Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.730 | 213.730 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `141745Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.720 | 213.720 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `141745Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.320 | 50.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `141750Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.650 | 388.650 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `141750Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.190 | 213.190 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `141750Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.170 | 214.170 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `141750Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `141755Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.830 | 388.830 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `141755Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.030 | 214.030 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `141755Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.120 | 213.120 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `141755Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `141800Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.600 | 388.600 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `141800Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.390 | 214.390 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `141800Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.690 | 214.690 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `141800Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.320 | 50.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `141805Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 389.140 | 389.140 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `141805Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 212.890 | 212.890 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `141805Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.630 | 213.630 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `141805Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `141810Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.740 | 388.740 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `141810Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.800 | 213.800 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `141810Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.810 | 213.810 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `141810Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `141815Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 389.250 | 389.250 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `141815Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.830 | 213.830 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `141815Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 212.750 | 212.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `141815Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `141820Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.870 | 388.870 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `141820Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.410 | 213.410 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `141820Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.770 | 213.770 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `141820Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `141825Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.640 | 388.640 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `141825Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.750 | 213.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `141825Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.980 | 213.980 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `141825Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.330 | 50.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `141830Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.930 | 388.930 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `141830Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.130 | 214.130 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `141830Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.770 | 213.770 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `141830Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `150153Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.640 | 388.640 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `150153Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.550 | 213.550 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `150153Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.160 | 214.160 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `150153Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.320 | 50.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `150158Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.560 | 388.560 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `150158Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.100 | 214.100 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `150158Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.370 | 213.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `150158Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `150203Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.490 | 388.490 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `150203Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.810 | 213.810 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `150203Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.290 | 213.290 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `150203Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `150208Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.730 | 388.730 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `150208Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.850 | 213.850 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `150208Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 212.930 | 212.930 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `150208Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.380 | 50.380 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `150213Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.960 | 388.960 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `150213Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.840 | 213.840 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `150213Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.210 | 214.210 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `150213Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.390 | 50.390 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `150218Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.850 | 388.850 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `150218Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.760 | 213.760 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `150218Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.150 | 213.150 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `150218Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `150223Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.630 | 388.630 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `150223Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.420 | 214.420 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `150223Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.300 | 214.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `150223Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `150229Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.960 | 388.960 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `150229Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.500 | 213.500 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `150229Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.500 | 213.500 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `150229Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `150233Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.840 | 388.840 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `150233Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.340 | 214.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `150233Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.600 | 213.600 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `150233Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `150238Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 389.220 | 389.220 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `150238Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.650 | 213.650 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `150238Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.170 | 214.170 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `150238Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `150243Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.560 | 388.560 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `150243Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.760 | 213.760 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `150243Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.730 | 213.730 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `150243Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `150248Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.600 | 388.600 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `150248Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.350 | 213.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `150248Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.440 | 213.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `150248Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `150253Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.910 | 388.910 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `150253Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.080 | 214.080 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `150253Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.980 | 213.980 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `150253Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `150258Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.480 | 388.480 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `150258Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.090 | 214.090 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `150258Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.320 | 213.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `150258Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `150303Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.460 | 388.460 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `150303Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.410 | 213.410 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `150303Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.450 | 213.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `150303Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `154540Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 389.100 | 389.100 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `154540Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.150 | 213.150 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `154540Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.100 | 214.100 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `154540Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.320 | 50.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `154545Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.510 | 388.510 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `154545Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.720 | 213.720 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `154545Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.950 | 213.950 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `154545Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `154550Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.830 | 388.830 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `154550Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.810 | 213.810 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `154550Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.150 | 214.150 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `154550Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.380 | 50.380 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `154555Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.870 | 388.870 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `154555Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.460 | 213.460 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `154555Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.610 | 213.610 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `154555Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `154600Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.490 | 388.490 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `154600Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.060 | 214.060 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `154600Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.270 | 214.270 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `154600Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `154605Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.790 | 388.790 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `154605Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.470 | 213.470 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `154605Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.780 | 213.780 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `154605Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.380 | 50.380 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `154610Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.740 | 388.740 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `154610Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.100 | 214.100 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `154610Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.770 | 213.770 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `154610Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `154615Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.490 | 388.490 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `154615Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.560 | 213.560 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `154615Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.080 | 214.080 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `154615Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `154620Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.890 | 388.890 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `154620Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.880 | 213.880 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `154620Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.360 | 214.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `154620Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `154625Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.880 | 388.880 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `154625Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.370 | 214.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `154625Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.080 | 214.080 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `154625Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `154630Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.810 | 388.810 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `154630Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.430 | 214.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `154630Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.480 | 214.480 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `154630Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.310 | 50.310 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `154635Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.780 | 388.780 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `154635Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.440 | 213.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `154635Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.300 | 213.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `154635Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `154640Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.370 | 388.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `154640Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.270 | 213.270 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `154640Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.490 | 213.490 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `154640Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `154645Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.320 | 388.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `154645Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.490 | 213.490 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `154645Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.940 | 213.940 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `154645Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.390 | 50.390 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `154650Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 389.080 | 389.080 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `154650Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.410 | 214.410 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `154650Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.980 | 213.980 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `154650Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.320 | 50.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `162928Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.260 | 388.260 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `162928Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.470 | 213.470 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `162928Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.670 | 213.670 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `162928Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `162933Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.500 | 388.500 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `162933Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.010 | 214.010 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `162933Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.530 | 213.530 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `162933Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `162938Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 389.000 | 389.000 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `162938Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 212.930 | 212.930 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `162938Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.500 | 213.500 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `162938Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.320 | 50.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `162943Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.510 | 388.510 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `162943Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.720 | 213.720 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `162943Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.970 | 213.970 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `162943Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.330 | 50.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `162948Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.760 | 388.760 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `162948Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.750 | 213.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `162948Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.690 | 213.690 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `162948Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `162953Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 389.000 | 389.000 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `162953Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.690 | 213.690 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `162953Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.650 | 213.650 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `162953Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `162958Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.860 | 388.860 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `162958Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.050 | 214.050 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `162958Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.080 | 214.080 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `162958Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.390 | 50.390 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `163003Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.770 | 388.770 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `163003Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.660 | 213.660 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `163003Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.440 | 213.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `163003Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `163008Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.850 | 388.850 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `163008Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.150 | 214.150 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `163008Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.620 | 213.620 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `163008Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `163013Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.740 | 388.740 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `163013Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.760 | 213.760 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `163013Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.950 | 213.950 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `163013Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.390 | 50.390 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `163018Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.640 | 388.640 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `163018Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.620 | 213.620 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `163018Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.730 | 213.730 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `163018Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.330 | 50.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `163023Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.890 | 388.890 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `163023Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.120 | 213.120 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `163023Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.230 | 213.230 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `163023Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `163028Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 389.000 | 389.000 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `163028Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.630 | 213.630 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `163028Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.090 | 214.090 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `163028Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.330 | 50.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `163033Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.550 | 388.550 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `163033Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.960 | 213.960 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `163033Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.300 | 214.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `163033Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `163038Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.920 | 388.920 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `163038Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.510 | 213.510 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `163038Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.930 | 213.930 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `163038Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `171315Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.450 | 388.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `171315Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.790 | 213.790 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `171315Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.450 | 213.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003` | `2n` | `171315Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.300 | 50.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `171320Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.750 | 388.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `171320Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.150 | 214.150 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `171320Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.540 | 213.540 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0004,b0005` | `2n` | `171320Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `171325Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.460 | 388.460 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `171325Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.330 | 213.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `171325Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.750 | 213.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007` | `2n` | `171325Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `171330Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.680 | 388.680 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `171330Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.660 | 213.660 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `171330Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.990 | 213.990 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0008,b0009` | `2n` | `171330Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.330 | 50.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `171335Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.680 | 388.680 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `171335Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.500 | 213.500 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `171335Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.530 | 213.530 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011` | `2n` | `171335Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.400 | 50.400 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `171340Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 389.180 | 389.180 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `171340Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.210 | 213.210 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `171340Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.350 | 213.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0012,b0013` | `2n` | `171340Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `171345Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.710 | 388.710 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `171345Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.460 | 213.460 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `171345Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.320 | 214.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015` | `2n` | `171345Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `171350Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.790 | 388.790 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `171350Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.070 | 213.070 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `171350Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.360 | 214.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017` | `2n` | `171350Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.370 | 50.370 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `171355Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.980 | 388.980 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `171355Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.550 | 214.550 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `171355Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.000 | 214.000 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019` | `2n` | `171355Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.340 | 50.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `171400Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.820 | 388.820 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `171400Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.160 | 213.160 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `171400Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.750 | 214.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0020,b0021` | `2n` | `171400Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.360 | 50.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `171405Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.660 | 388.660 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `171405Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.120 | 214.120 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `171405Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.960 | 213.960 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023` | `2n` | `171405Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `171410Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.780 | 388.780 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `171410Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.030 | 213.030 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `171410Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.230 | 213.230 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025` | `2n` | `171410Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `171415Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.920 | 388.920 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `171415Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.860 | 213.860 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `171415Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.490 | 213.490 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027` | `2n` | `171415Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `171421Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.600 | 388.600 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `171421Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 214.000 | 214.000 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `171421Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.640 | 213.640 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029` | `2n` | `171421Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.330 | 50.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `171426Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 388.910 | 388.910 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `171426Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.800 | 213.800 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `171426Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 213.590 | 213.590 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0030,b0031` | `2n` | `171426Z-r01` | `small` | `b200_scale_2n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 16 | 1 | `passed` | 50.350 | 50.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
