# NCCL System Verification rtxpro6000 2026-05-16 4n

- Index: [nccl-suite-rtxpro6000.md](./nccl-suite-rtxpro6000.md)
- Profile: `small`
- Scale: `4n`
- Submitted jobs: 20
- Completed jobs: 20/20
- Detailed rows: 80/80
- Passed rows: 80/80
- Status: `passed`
- Shape: `8 MPI ranks per node, 1 GPU per rank, 16 CPU cores per rank`

## Group Rows

| Node Group | Nodes | GPUs | Samples | Passes | Status | AR Olympic avg | AR min..max | AR drop min/max | RS Olympic avg | RS min..max | RS drop min/max | AG Olympic avg | AG min..max | AG drop min/max | A2A Olympic avg | A2A min..max | A2A drop min/max | Wrong | Aggregation | Jobs |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |
| `a0002,a0003,a0004,a0005` | 4 | 32 | 5/5 | 5/5 | `passed` | 24.303 | 24.270..24.380 | 24.270/24.380 | 24.237 | 24.170..24.350 | 24.170/24.350 | 24.467 | 24.410..24.550 | 24.410/24.550 | 11.820 | 11.780..11.820 | 11.780/11.820 | 0 | olympic avg | `21006,21057,21089,21117,21147` |
| `a0006,a0007,a0008,a0009` | 4 | 32 | 5/5 | 5/5 | `passed` | 24.383 | 24.280..24.430 | 24.280/24.430 | 24.287 | 24.250..24.380 | 24.250/24.380 | 24.550 | 24.520..24.590 | 24.520/24.590 | 11.813 | 11.810..11.830 | 11.810/11.830 | 0 | olympic avg | `21007,21058,21090,21118,21148` |
| `a0010,a0011,a0012,a0013` | 4 | 32 | 5/5 | 5/5 | `passed` | 24.330 | 24.180..24.380 | 24.180/24.380 | 24.173 | 24.090..24.360 | 24.090/24.360 | 24.487 | 24.460..24.560 | 24.460/24.560 | 11.817 | 11.750..11.830 | 11.750/11.830 | 0 | olympic avg | `21008,21059,21091,21119,21149` |
| `a0014,a0015,a0016,a0019` | 4 | 32 | 5/5 | 5/5 | `passed` | 24.133 | 23.820..24.430 | 23.820/24.430 | 24.220 | 24.120..24.280 | 24.120/24.280 | 24.237 | 24.150..24.290 | 24.150/24.290 | 11.813 | 11.790..11.830 | 11.790/11.830 | 0 | olympic avg | `21009,21060,21092,21120,21150` |

Bandwidth columns are largest-message `busbw` in GB/s.
Olympic avg columns aggregate passed samples for each node group. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

## Per-Op Statistics

Only passed rows with numeric largest-message `busbw` values are included. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for repeat aggregation and min/max definitions.

| Metric | n | Olympic avg | Min | Max | Dropped min/max | Aggregation |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| AR busbw | 20 | 24.298 | 23.820 | 24.430 | 23.820/24.430 | olympic avg from 18/20; dropped min/max |
| RS busbw | 20 | 24.238 | 24.090 | 24.380 | 24.090/24.380 | olympic avg from 18/20; dropped min/max |
| AG busbw | 20 | 24.445 | 24.150 | 24.590 | 24.150/24.590 | olympic avg from 18/20; dropped min/max |
| A2A busbw | 20 | 11.814 | 11.750 | 11.830 | 11.750/11.830 | olympic avg from 18/20; dropped min/max |

## Bandwidth Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for `Delta` and anomaly-label definitions.

(none)

## Rows Needing Review

- None

## Detailed Rows

| Entity | Scale | Run | Profile | Class | Op | GPU set | Rank shape | Ranks | -g | Status | Largest busbw | Max busbw | Wrong | RC | Hints | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
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
