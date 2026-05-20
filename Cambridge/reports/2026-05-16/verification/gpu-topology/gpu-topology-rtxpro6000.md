# GPU Topology rtxpro6000 2026-05-16

- Check: `gpu-topology`
- Cluster: `rtxpro6000`
- Partition: `GPU1`
- Discovery time: `2026-05-16T13:00:07Z`
- Mode: `apply`

| Node | Slurm | Job | Run | Status | GPUs | Expected | Model | Count | Model OK | Topo | CPU | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a0002 | idle | 20504 | 130008Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0003 | idle | 20506 | 130010Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0004 | idle | 20508 | 130012Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0005 | idle | 20510 | 130015Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0006 | idle | 20512 | 130015Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0007 | idle | 20514 | 130018Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0008 | idle | 20516 | 130020Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0009 | idle | 20518 | 130022Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0010 | idle | 20520 | 130024Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0011 | idle | 20522 | 130026Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0012 | idle | 20524 | 130028Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0013 | idle | 20526 | 130030Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0014 | idle | 20528 | 130033Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0015 | idle | 20529 | 130034Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0016 | idle | 20531 | 130036Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |
| a0017 | drained* | - | - | skipped | - | - | - | - | - | - | - |  |
| a0018 | mixed | - | - | skipped | - | - | - | - | - | - | - |  |
| a0019 | idle | 20533 | 130038Z-r01 | passed | 8 | 8 | NVIDIA RTX PRO 6000 Blackwell Server Edition | Pass | Pass | Pass | Pass |  |

## GPU Topology Intelligence

Topology and mlx5 affinity intelligence is report-only and does not change canonical `status.json` pass/fail.

| Node | Profile | GPU NUMA | mlx5 NUMA | GPU0 nearest NICs | GPU7 nearest NICs | GPU7 PIX NICs | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| a0002 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0003 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0004 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0005 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0006 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0007 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0008 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0009 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0010 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0011 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0012 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0013 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0014 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0015 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0016 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |
| a0019 | Pass | 0:1,1:2,2:3,3:0,4:5,5:6,6:7,7:4 | mlx5_0:3,mlx5_3:5,mlx5_bond_0:0 | SYS:mlx5_0, NIC2, mlx5_3 | SYS:mlx5_0, NIC2, mlx5_3 | - |  |

### Fleet Consistency

- Structured rows: `16/16`
- Majority signature count: `16/16`
- Outlier nodes: `(none)`
- Missing structured topology: `(none)`

Majority topology signature:

```text
gpu_numa=GPU0:1,GPU1:2,GPU2:3,GPU3:0,GPU4:5,GPU5:6,GPU6:7,GPU7:4|gpu_cpu=GPU0:16-31,GPU1:32-47,GPU2:48-63,GPU3:0-15,GPU4:80-95,GPU5:96-111,GPU6:112-127,GPU7:64-79|gpu_pix=GPU0:,GPU1:,GPU2:mlx5_0,GPU3:NIC2,GPU4:mlx5_3,GPU5:,GPU6:,GPU7:|nic_numa=mlx5_0:,NIC2:,mlx5_3:|nic_cpu=mlx5_0:,NIC2:,mlx5_3:|ib_numa=mlx5_0:3,mlx5_3:5,mlx5_bond_0:0|ib_cpu=mlx5_0:48-63,mlx5_3:80-95,mlx5_bond_0:0-15|storage=source=,fstype=,route_dev=,route_mlx5=
```

## Skipped Nodes

- `drained*`: a0017
- `mixed`: a0018
