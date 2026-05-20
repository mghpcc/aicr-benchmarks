# NCCL System Verification b200 2026-05-16 8n

- Index: [nccl-suite-b200.md](./nccl-suite-b200.md)
- Profile: `small`
- Scale: `8n`
- Submitted jobs: 20
- Completed jobs: 20/20
- Detailed rows: 80/80
- Passed rows: 80/80
- Status: `passed`
- Shape: `8 MPI ranks per node, 1 GPU per rank, 16 CPU cores per rank`

## Group Rows

| Node Group | Nodes | GPUs | Samples | Passes | Status | AR Olympic avg | AR min..max | AR drop min/max | RS Olympic avg | RS min..max | RS drop min/max | AG Olympic avg | AG min..max | AG drop min/max | A2A Olympic avg | A2A min..max | A2A drop min/max | Wrong | Aggregation | Jobs |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | 8 | 64 | 5/5 | 5/5 | `passed` | 199.493 | 199.160..199.750 | 199.160/199.750 | 204.440 | 203.790..204.920 | 203.790/204.920 | 203.917 | 202.850..204.650 | 202.850/204.650 | 28.693 | 28.650..28.710 | 28.650/28.710 | 0 | olympic avg | `21085,21204,21278,21347,21427` |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | 8 | 64 | 5/5 | 5/5 | `passed` | 199.800 | 198.450..199.960 | 198.450/199.960 | 204.777 | 203.840..205.160 | 203.840/205.160 | 204.843 | 203.310..204.980 | 203.310/204.980 | 28.720 | 28.710..28.720 | 28.710/28.720 | 0 | olympic avg | `21086,21205,21279,21348,21428` |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | 8 | 64 | 5/5 | 5/5 | `passed` | 199.877 | 199.330..200.030 | 199.330/200.030 | 204.917 | 202.820..205.410 | 202.820/205.410 | 204.697 | 204.650..204.990 | 204.650/204.990 | 28.693 | 28.660..28.720 | 28.660/28.720 | 0 | olympic avg | `21087,21206,21280,21349,21429` |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | 8 | 64 | 5/5 | 5/5 | `passed` | 199.650 | 198.310..199.920 | 198.310/199.920 | 204.110 | 202.210..204.630 | 202.210/204.630 | 204.473 | 204.110..204.700 | 204.110/204.700 | 28.697 | 28.650..28.720 | 28.650/28.720 | 0 | olympic avg | `21088,21207,21281,21350,21430` |

Bandwidth columns are largest-message `busbw` in GB/s.
Olympic avg columns aggregate passed samples for each node group. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

## Per-Op Statistics

Only passed rows with numeric largest-message `busbw` values are included. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

| Metric | n | Olympic avg | Min | Max | Dropped min/max | Aggregation |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| AR busbw | 20 | 199.613 | 198.310 | 200.030 | 198.310/200.030 | olympic avg from 18/20; dropped min/max |
| RS busbw | 20 | 204.438 | 202.210 | 205.410 | 202.210/205.410 | olympic avg from 18/20; dropped min/max |
| AG busbw | 20 | 204.455 | 202.850 | 204.990 | 202.850/204.990 | olympic avg from 18/20; dropped min/max |
| A2A busbw | 20 | 28.699 | 28.650 | 28.720 | 28.650/28.720 | olympic avg from 18/20; dropped min/max |

## Bandwidth Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for `Delta` and anomaly-label definitions.

(none)

## Rows Needing Review

- None

## Detailed Rows

| Entity | Scale | Run | Profile | Class | Op | GPU set | Rank shape | Ranks | -g | Status | Largest busbw | Max busbw | Wrong | RC | Hints | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `143320Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.740 | 199.740 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `143320Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.360 | 204.360 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `143320Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.670 | 204.670 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `143320Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.710 | 28.840 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `143325Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 198.450 | 198.450 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `143325Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 203.310 | 203.310 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `143325Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.310 | 204.310 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `143325Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.720 | 28.890 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `143330Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.670 | 199.670 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `143330Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.670 | 204.670 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `143330Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 205.120 | 205.120 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `143330Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.660 | 29.040 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `143815Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.690 | 199.690 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `143815Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.110 | 204.110 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `143815Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 203.240 | 203.240 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `143815Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.670 | 29.040 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `151723Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.750 | 199.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `151723Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.200 | 204.200 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `151723Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.810 | 204.810 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `151723Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.650 | 29.040 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `151729Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.720 | 199.720 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `151729Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.850 | 204.850 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `151729Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 205.020 | 205.020 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `151729Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.710 | 29.040 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `151733Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 200.030 | 200.030 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `151733Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.650 | 204.650 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `151733Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 202.820 | 202.820 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `151733Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.660 | 28.790 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `152221Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.730 | 199.730 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `152221Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.420 | 204.420 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `152221Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.630 | 204.630 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `152221Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.650 | 29.050 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `160110Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.440 | 199.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `160110Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 202.850 | 202.850 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `160110Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 203.790 | 203.790 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `160110Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.660 | 28.780 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `160115Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.820 | 199.820 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `160115Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.930 | 204.930 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `160115Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 205.160 | 205.160 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `160115Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.720 | 28.810 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `160120Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 200.030 | 200.030 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `160120Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.660 | 204.660 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `160120Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 205.320 | 205.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `160120Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.720 | 29.060 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `160558Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.920 | 199.920 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `160558Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.420 | 204.420 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `160558Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 202.210 | 202.210 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `160558Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.710 | 28.900 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `164514Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.300 | 199.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `164514Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 203.190 | 203.190 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `164514Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.920 | 204.920 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `164514Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.710 | 29.050 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `164518Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.960 | 199.960 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `164518Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.980 | 204.980 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `164518Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 203.840 | 203.840 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `164518Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.720 | 29.040 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `164523Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.930 | 199.930 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `164523Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.760 | 204.760 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `164523Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 205.410 | 205.410 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `164523Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.700 | 29.050 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `165006Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 198.310 | 198.310 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `165006Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.580 | 204.580 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `165006Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.480 | 204.480 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `165006Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.710 | 28.860 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `172900Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.160 | 199.160 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `172900Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.650 | 204.650 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `172900Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 203.840 | 203.840 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009` | `8n` | `172900Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.710 | 29.040 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `172905Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.860 | 199.860 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `172905Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.750 | 204.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `172905Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 205.000 | 205.000 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `8n` | `172905Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.720 | 29.050 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `172910Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.330 | 199.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `172910Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.990 | 204.990 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `172910Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.310 | 204.310 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025` | `8n` | `172910Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.720 | 29.050 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `173358Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 199.530 | 199.530 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `173358Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.700 | 204.700 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `173358Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 204.610 | 204.610 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `8n` | `173358Z-r01` | `small` | `b200_scale_8n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 64 | 1 | `passed` | 28.720 | 28.890 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
