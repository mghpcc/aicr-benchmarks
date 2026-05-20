# GPU Topology b200 2026-05-16

- Check: `gpu-topology`
- Cluster: `b200`
- Partition: `GPU2`
- Discovery time: `2026-05-16T13:00:07Z`
- Mode: `apply`

| Node | Slurm | Job | Run | Status | GPUs | Expected | Model | Count | Model OK | Topo | CPU | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | idle | 20503 | 130008Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0003 | idle | 20505 | 130010Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0004 | idle | 20507 | 130012Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0005 | idle | 20509 | 130014Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0006 | idle | 20511 | 130015Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0007 | idle | 20513 | 130018Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0008 | idle | 20515 | 130020Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0009 | idle | 20517 | 130022Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0010 | idle | 20519 | 130024Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0011 | idle | 20521 | 130026Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0012 | idle | 20523 | 130028Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0013 | idle | 20525 | 130030Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0014 | idle | 20527 | 130033Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0015 | idle | 20530 | 130034Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0016 | idle | 20532 | 130036Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0017 | idle | 20534 | 130038Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0018 | idle | 20535 | 130040Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0019 | idle | 20536 | 130042Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0020 | idle | 20537 | 130044Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0021 | idle | 20538 | 130046Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0022 | idle | 20539 | 130048Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0023 | idle | 20540 | 130050Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0024 | idle | 20541 | 130052Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0025 | idle | 20542 | 130054Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0026 | idle | 20544 | 130056Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0027 | idle | 20545 | 130058Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0028 | idle | 20546 | 130100Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0029 | idle | 20547 | 130102Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0030 | idle | 20548 | 130104Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |
| b0031 | idle | 20549 | 130106Z-r01 | passed | 8 | 8 | NVIDIA B200 | Pass | Pass | Pass | Pass |  |

## GPU Topology Intelligence

Topology and mlx5 affinity intelligence is report-only and does not change canonical `status.json` pass/fail.

| Node | Profile | GPU NUMA | mlx5 NUMA | GPU0 nearest NICs | GPU7 nearest NICs | GPU7 PIX NICs | GDS storage | Storage route | Storage mlx5 | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0003 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0004 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0005 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0006 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0007 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0008 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0009 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0010 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0011 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0012 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0013 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0014 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0015 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0016 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0017 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0018 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0019 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0020 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0021 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0022 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0023 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0024 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0025 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0026 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0027 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0028 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0029 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0030 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |
| b0031 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4 | PIX:mlx5_0 | PIX:mlx5_11, mlx5_12 | mlx5_11, mlx5_12 | nfs:storage0001.nfs:/work | - | - |  |

### Fleet Consistency

- Structured rows: `30/30`
- Majority signature count: `30/30`
- Outlier nodes: `(none)`
- Missing structured topology: `(none)`

Majority topology signature:

```text
gpu_numa=GPU0:1,GPU1:2,GPU2:3,GPU3:0,GPU4:5,GPU5:6,GPU6:7,GPU7:4|gpu_cpu=GPU0:16-31,GPU1:32-47,GPU2:48-63,GPU3:0-15,GPU4:80-95,GPU5:96-111,GPU6:112-127,GPU7:64-79|gpu_pix=GPU0:mlx5_0,GPU1:mlx5_1,GPU2:mlx5_2,GPU3:mlx5_3,GPU4:mlx5_4,GPU5:mlx5_5,GPU6:mlx5_6,GPU7:mlx5_11+mlx5_12|nic_numa=mlx5_0:,mlx5_1:,mlx5_2:,mlx5_3:,mlx5_4:,mlx5_5:,mlx5_6:,mlx5_7:,mlx5_8:,mlx5_9:,mlx5_10:,mlx5_11:,mlx5_12:|nic_cpu=mlx5_0:,mlx5_1:,mlx5_2:,mlx5_3:,mlx5_4:,mlx5_5:,mlx5_6:,mlx5_7:,mlx5_8:,mlx5_9:,mlx5_10:,mlx5_11:,mlx5_12:|ib_numa=mlx5_0:1,mlx5_1:2,mlx5_2:3,mlx5_3:0,mlx5_4:5,mlx5_5:6,mlx5_6:7,mlx5_7:4,mlx5_8:4,mlx5_9:4,mlx5_10:4,mlx5_11:4,mlx5_12:4|ib_cpu=mlx5_0:16-31,mlx5_1:32-47,mlx5_2:48-63,mlx5_3:0-15,mlx5_4:80-95,mlx5_5:96-111,mlx5_6:112-127,mlx5_7:64-79,mlx5_8:64-79,mlx5_9:64-79,mlx5_10:64-79,mlx5_11:64-79,mlx5_12:64-79|storage=source=storage0001.nfs:/work,fstype=nfs,route_dev=,route_mlx5=
```
