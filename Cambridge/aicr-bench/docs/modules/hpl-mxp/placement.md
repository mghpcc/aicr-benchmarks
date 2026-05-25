# HPL-MxP Placement

Purpose: document the reviewed HPL-MxP rank, CPU, memory, GPU, and UCX/NIC
placement policy.

HPL-MxP public rows use one MPI rank per GPU. The `derived-nps4` placement
profile maps those eight ranks to GPU, CPU, memory, and UCX/NIC locality on
the B200 and RTX PRO 6000 nodes.

These maps are derived from the published
[GPU topology readiness](../gpu-topology/studies.md) evidence. Representative
GPU topology diagrams are available for
[B200](../gpu-topology/topology-map.md#b200-example) and
[RTX PRO 6000](../gpu-topology/topology-map.md#rtx-pro-6000-example); they show
GPU, NUMA, and resolved IB fabric mlx5 locality.

## Rank Maps

| Map | Value |
| --- | --- |
| GPU affinity | `0:1:2:3:4:5:6:7` |
| CPU affinity | `16-31:32-47:48-63:0-15:80-95:96-111:112-127:64-79` |
| Memory affinity | `1:2:3:0:5:6:7:4` |

## UCX/NIC Maps

| Platform | UCX/NIC affinity |
| --- | --- |
| B200 | `mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_6:mlx5_11` |
| RTX PRO 6000 | `mlx5_0:mlx5_0:mlx5_0:mlx5_0:mlx5_3:mlx5_3:mlx5_3:mlx5_3` |

## How It Is Applied

Use `HPL_MXP_AFFINITY_PROFILE=derived-nps4` with
`make benchmark-hpl-mxp`, or `--affinity-profile derived-nps4` with
[submit-hpl-mxp.sh](../../../man/submit-hpl-mxp.md). The submitter resolves the
CPU, memory, and UCX/NIC maps for the selected platform. The allocation-side
runner always passes GPU affinity `0:1:2:3:4:5:6:7` to the NVIDIA HPL-MxP
container entrypoint.

Representative command examples may keep explicit `--cpu-affinity`,
`--mem-affinity`, and `--ucx-affinity` flags when the page is documenting a
specific reproduced row.
