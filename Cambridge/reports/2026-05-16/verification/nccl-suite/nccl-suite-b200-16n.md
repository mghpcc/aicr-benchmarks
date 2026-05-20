# NCCL System Verification b200 2026-05-16 16n

- Index: [nccl-suite-b200.md](./nccl-suite-b200.md)
- Profile: `small`
- Scale: `16n`
- Submitted jobs: 10
- Completed jobs: 10/10
- Detailed rows: 40/40
- Passed rows: 40/40
- Status: `passed`
- Shape: `8 MPI ranks per node, 1 GPU per rank, 16 CPU cores per rank`

## Group Rows

| Node Group | Nodes | GPUs | Samples | Passes | Status | AR Olympic avg | AR min..max | AR drop min/max | RS Olympic avg | RS min..max | RS drop min/max | AG Olympic avg | AG min..max | AG drop min/max | A2A Olympic avg | A2A min..max | A2A drop min/max | Wrong | Aggregation | Jobs |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | 16 | 128 | 5/5 | 5/5 | `passed` | 197.943 | 196.690..198.830 | 196.690/198.830 | 198.743 | 197.870..199.150 | 197.870/199.150 | 198.827 | 198.480..199.050 | 198.480/199.050 | 26.663 | 26.620..26.670 | 26.620/26.670 | 0 | olympic avg | `21121,21208,21282,21355,21434` |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | 16 | 128 | 5/5 | 5/5 | `passed` | 198.240 | 196.750..198.800 | 196.750/198.800 | 197.833 | 196.720..198.330 | 196.720/198.330 | 198.187 | 198.100..198.320 | 198.100/198.320 | 26.667 | 26.630..26.690 | 26.630/26.690 | 0 | olympic avg | `21122,21209,21283,21356,21435` |

Bandwidth columns are largest-message `busbw` in GB/s.
Olympic avg columns aggregate passed samples for each node group. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

## Per-Op Statistics

Only passed rows with numeric largest-message `busbw` values are included. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

| Metric | n | Olympic avg | Min | Max | Dropped min/max | Aggregation |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| AR busbw | 10 | 198.012 | 196.690 | 198.830 | 196.690/198.830 | olympic avg from 8/10; dropped min/max |
| RS busbw | 10 | 198.241 | 196.720 | 199.150 | 196.720/199.150 | olympic avg from 8/10; dropped min/max |
| AG busbw | 10 | 198.480 | 198.100 | 199.050 | 198.100/199.050 | olympic avg from 8/10; dropped min/max |
| A2A busbw | 10 | 26.661 | 26.620 | 26.690 | 26.620/26.690 | olympic avg from 8/10; dropped min/max |

## Bandwidth Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for `Delta` and anomaly-label definitions.

(none)

## Rows Needing Review

- None

## Detailed Rows

| Entity | Scale | Run | Profile | Class | Op | GPU set | Rank shape | Ranks | -g | Status | Largest busbw | Max busbw | Wrong | RC | Hints | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `144313Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.830 | 198.830 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `144313Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.830 | 198.830 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `144313Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.330 | 198.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `144313Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 26.670 | 27.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `144827Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 196.750 | 196.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `144827Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.320 | 198.320 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `144827Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.300 | 198.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `144827Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 26.690 | 27.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `152715Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 196.690 | 196.690 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `152715Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.970 | 198.970 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `152715Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 199.150 | 199.150 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `152715Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 26.620 | 27.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `153219Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.800 | 198.800 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `153219Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.100 | 198.100 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `153219Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.330 | 198.330 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `153219Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 26.630 | 27.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `161103Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.240 | 198.240 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `161103Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.680 | 198.680 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `161103Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.810 | 198.810 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `161103Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 26.670 | 27.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `161612Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.530 | 198.530 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `161612Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.100 | 198.100 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `161612Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 196.720 | 196.720 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `161612Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 26.630 | 27.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `165505Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 197.860 | 197.860 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `165505Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.480 | 198.480 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `165505Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 199.090 | 199.090 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `165505Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 26.650 | 27.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `170007Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.440 | 198.440 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `170007Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.170 | 198.170 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `170007Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 196.930 | 196.930 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `170007Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 26.680 | 27.310 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `173853Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 197.730 | 197.730 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `173853Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 199.050 | 199.050 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `173853Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 197.870 | 197.870 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017` | `16n` | `173853Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 26.670 | 27.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `174355Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allreduce` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 197.750 | 197.750 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `174355Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `allgather` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.290 | 198.290 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `174355Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `reduce_scatter` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 198.270 | 198.270 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
| `b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | `16n` | `174355Z-r01` | `small` | `b200_scale_16n_8rank_1g` | `alltoall` | `all` | `8rank_1g_per_node` | 128 | 1 | `passed` | 26.690 | 27.300 | 0 | 0 | P2P,NET/IB,SYS,GDRDMA |  |
