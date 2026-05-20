# NCCL System Verification b200 2026-05-16 4n

- Index: [nccl-suite-b200.md](./nccl-suite-b200.md)
- Profile: `small`
- Scale: `4n`
- Submitted jobs: 40
- Completed jobs: 40/40
- Detailed rows: 160/160
- Passed rows: 160/160
- Status: `passed`
- Shape: `8 MPI ranks per node, 1 GPU per rank, 16 CPU cores per rank`

## Group Rows

| Node Group | Nodes | GPUs | Samples | Passes | Status | AR Olympic avg | AR min..max | AR drop min/max | RS Olympic avg | RS min..max | RS drop min/max | AG Olympic avg | AG min..max | AG drop min/max | A2A Olympic avg | A2A min..max | A2A drop min/max | Wrong | Aggregation | Jobs |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |
| `b0002,b0003,b0004,b0005` | 4 | 32 | 5/5 | 5/5 | `passed` | 215.723 | 215.460..215.900 | 215.460/215.900 | 213.030 | 212.620..213.850 | 212.620/213.850 | 212.553 | 212.060..213.760 | 212.060/213.760 | 33.320 | 33.320..33.320 | 33.320/33.320 | 0 | olympic avg | `21049,21196,21266,21337,21415` |
| `b0006,b0007,b0008,b0009` | 4 | 32 | 5/5 | 5/5 | `passed` | 215.730 | 215.450..215.880 | 215.450/215.880 | 212.477 | 211.750..212.900 | 211.750/212.900 | 212.120 | 211.720..212.910 | 211.720/212.910 | 33.317 | 33.310..33.320 | 33.310/33.320 | 0 | olympic avg | `21050,21197,21267,21338,21416` |
| `b0010,b0011,b0012,b0013` | 4 | 32 | 5/5 | 5/5 | `passed` | 215.713 | 215.390..215.960 | 215.390/215.960 | 213.043 | 212.750..213.290 | 212.750/213.290 | 213.007 | 212.590..213.760 | 212.590/213.760 | 33.320 | 33.320..33.320 | 33.320/33.320 | 0 | olympic avg | `21051,21198,21268,21339,21417` |
| `b0014,b0015,b0016,b0017` | 4 | 32 | 5/5 | 5/5 | `passed` | 215.863 | 215.350..216.260 | 215.350/216.260 | 213.110 | 212.720..213.660 | 212.720/213.660 | 213.480 | 213.220..213.600 | 213.220/213.600 | 33.310 | 33.310..33.320 | 33.310/33.320 | 0 | olympic avg | `21052,21199,21269,21340,21418` |
| `b0018,b0019,b0020,b0021` | 4 | 32 | 5/5 | 5/5 | `passed` | 215.690 | 215.460..215.970 | 215.460/215.970 | 212.993 | 211.170..213.440 | 211.170/213.440 | 212.940 | 211.890..213.950 | 211.890/213.950 | 33.320 | 33.310..33.320 | 33.310/33.320 | 0 | olympic avg | `21053,21200,21270,21341,21419` |
| `b0022,b0023,b0024,b0025` | 4 | 32 | 5/5 | 5/5 | `passed` | 215.580 | 215.270..215.980 | 215.270/215.980 | 213.323 | 212.790..213.970 | 212.790/213.970 | 213.487 | 211.790..213.870 | 211.790/213.870 | 33.320 | 33.320..33.330 | 33.320/33.330 | 0 | olympic avg | `21054,21201,21271,21342,21420` |
| `b0026,b0027,b0028,b0029` | 4 | 32 | 5/5 | 5/5 | `passed` | 215.693 | 215.000..216.050 | 215.000/216.050 | 213.253 | 212.730..213.620 | 212.730/213.620 | 213.143 | 212.310..213.610 | 212.310/213.610 | 33.320 | 33.320..33.320 | 33.320/33.320 | 0 | olympic avg | `21055,21202,21272,21343,21421` |
| `b0028,b0029,b0030,b0031` | 4 | 32 | 5/5 | 5/5 | `passed` | 215.857 | 215.740..216.090 | 215.740/216.090 | 212.960 | 212.270..213.700 | 212.270/213.700 | 213.293 | 212.770..213.670 | 212.770/213.670 | 33.320 | 33.310..33.320 | 33.310/33.320 | 0 | olympic avg | `21056,21203,21273,21345,21422` |

Bandwidth columns are largest-message `busbw` in GB/s.
Olympic avg columns aggregate passed samples for each node group. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

## Per-Op Statistics

Only passed rows with numeric largest-message `busbw` values are included. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

| Metric | n | Olympic avg | Min | Max | Dropped min/max | Aggregation |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| AR busbw | 40 | 215.724 | 215.000 | 216.260 | 215.000/216.260 | olympic avg from 38/40; dropped min/max |
| RS busbw | 40 | 213.017 | 211.170 | 213.970 | 211.170/213.970 | olympic avg from 38/40; dropped min/max |
| AG busbw | 40 | 212.997 | 211.720 | 213.950 | 211.720/213.950 | olympic avg from 38/40; dropped min/max |
| A2A busbw | 40 | 33.318 | 33.310 | 33.330 | 33.310/33.330 | olympic avg from 38/40; dropped min/max |

## Bandwidth Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for `Delta` and anomaly-label definitions.

(none)

## Rows Needing Review

- None

## Detailed Rows

| Entity | Scale | Run | Profile | Class | Op | GPU set | Rank shape | Ranks | -g | Status | Largest busbw | Max busbw | Wrong | RC | Hints | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| `b0002,b0003,b0004,b0005` | `4n` | `142308Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.900 | 215.900 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `142308Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.060 | 212.060 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `142308Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.850 | 213.850 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `142308Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `142313Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.630 | 215.630 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `142313Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.140 | 212.140 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `142313Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.900 | 212.900 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `142313Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `142318Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.630 | 215.630 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `142318Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.590 | 212.590 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `142318Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.000 | 213.000 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `142318Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `142323Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.880 | 215.880 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `142323Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.570 | 213.570 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `142323Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.660 | 213.660 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `142323Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.310 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `142328Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.910 | 215.910 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `142328Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.950 | 213.950 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `142328Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.270 | 213.270 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `142328Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `142333Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.820 | 215.820 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `142333Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.870 | 213.870 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `142333Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.350 | 213.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `142333Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `142338Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 216.000 | 216.000 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `142338Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.600 | 213.600 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `142338Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.390 | 213.390 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `142338Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `142809Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.740 | 215.740 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `142809Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.360 | 213.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `142809Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.110 | 213.110 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `142809Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `150740Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.460 | 215.460 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `150740Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.190 | 212.190 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `150740Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.890 | 212.890 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `150740Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `150745Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.720 | 215.720 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `150745Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 211.990 | 211.990 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `150745Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.170 | 212.170 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `150745Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `150750Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.830 | 215.830 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `150750Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.000 | 213.000 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `150750Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.840 | 212.840 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `150750Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `150755Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.960 | 215.960 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `150755Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.390 | 213.390 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `150755Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.720 | 212.720 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `150755Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.310 | 33.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `150800Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.570 | 215.570 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `150800Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.380 | 213.380 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `150800Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.740 | 212.740 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `150800Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `150805Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.270 | 215.270 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `150805Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 211.790 | 211.790 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `150805Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.970 | 213.970 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `150805Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `150810Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.000 | 215.000 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `150810Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.020 | 213.020 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `150810Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.330 | 213.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `150810Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `151240Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 216.090 | 216.090 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `151240Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.030 | 213.030 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `151240Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.340 | 213.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `151240Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `155128Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.520 | 215.520 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `155128Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.450 | 212.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `155128Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.340 | 213.340 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `155128Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `155133Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.450 | 215.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `155133Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.910 | 212.910 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `155133Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.630 | 212.630 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `155133Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.310 | 33.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `155138Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.390 | 215.390 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `155138Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.760 | 213.760 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `155138Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.750 | 212.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `155138Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `155143Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.750 | 215.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `155143Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.600 | 213.600 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `155143Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.130 | 213.130 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `155143Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `155148Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.590 | 215.590 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `155148Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.220 | 213.220 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `155148Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.970 | 212.970 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `155148Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.310 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `155153Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.980 | 215.980 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `155153Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.420 | 213.420 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `155153Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.030 | 213.030 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `155153Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `155158Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 216.050 | 216.050 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `155158Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.310 | 212.310 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `155158Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.040 | 213.040 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `155158Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `155631Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.990 | 215.990 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `155631Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.770 | 212.770 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `155631Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.270 | 212.270 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `155631Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `163515Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.780 | 215.780 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `163515Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.020 | 213.020 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `163515Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.860 | 212.860 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `163515Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `163520Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.880 | 215.880 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `163520Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.230 | 212.230 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `163520Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 211.750 | 211.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `163520Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `163525Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.680 | 215.680 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `163525Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.320 | 213.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `163525Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.290 | 213.290 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `163525Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `163530Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.350 | 215.350 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `163530Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.480 | 213.480 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `163530Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.090 | 213.090 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `163530Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.310 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `163536Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.970 | 215.970 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `163536Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.220 | 212.220 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `163536Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 211.170 | 211.170 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `163536Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `163540Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.530 | 215.530 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `163540Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.430 | 213.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `163540Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.790 | 212.790 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `163540Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.330 | 33.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `163545Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.260 | 215.260 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `163545Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.610 | 213.610 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `163545Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.620 | 213.620 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `163545Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `164020Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.820 | 215.820 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `164020Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.490 | 213.490 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `164020Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.430 | 212.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `164020Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `171903Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.870 | 215.870 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `171903Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.760 | 213.760 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `171903Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.620 | 212.620 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005` | `4n` | `171903Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.430 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `171908Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.840 | 215.840 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `171908Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 211.720 | 211.720 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `171908Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.630 | 212.630 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0006,b0007,b0008,b0009` | `4n` | `171908Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.310 | 33.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `171913Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.960 | 215.960 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `171913Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.700 | 212.700 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `171913Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.290 | 213.290 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013` | `4n` | `171913Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `171918Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 216.260 | 216.260 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `171918Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.220 | 213.220 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `171918Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.110 | 213.110 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0014,b0015,b0016,b0017` | `4n` | `171918Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.310 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `171923Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.460 | 215.460 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `171923Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 211.890 | 211.890 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `171923Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.440 | 213.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021` | `4n` | `171923Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `171928Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.390 | 215.390 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `171928Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.610 | 213.610 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `171928Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.590 | 213.590 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0022,b0023,b0024,b0025` | `4n` | `171928Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `171933Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.820 | 215.820 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `171933Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.810 | 212.810 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `171933Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 212.730 | 212.730 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0026,b0027,b0028,b0029` | `4n` | `171933Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.320 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `172410Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 215.760 | 215.760 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `172410Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.670 | 213.670 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `172410Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 213.700 | 213.700 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0028,b0029,b0030,b0031` | `4n` | `172410Z-r01` | `small` | `b200_scale_4n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 32 | 1 | `passed` | 33.310 | 33.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
