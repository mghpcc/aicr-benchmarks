# NCCL-Tests Benchmark Scripts

SLURM job scripts for running [nccl-tests](https://github.com/NVIDIA/nccl-tests) across a range of topologies. All scripts sweep message sizes from 1 MB to 16 GB (4x steps) and run every collective benchmark.

## Download

Clone from NVIDIA's GitHub and check out the version used here (2.18.3):

```bash
git clone https://github.com/NVIDIA/nccl-tests.git
cd nccl-tests
git checkout v2.18.3
```

## Install

Build from the repo root using NVHPC 26.3 + HPC-X MPI:

```bash
cd ..
bash build.sh
```

Output lands in `../build-nvhpc-26.3/`.

## Run

Submit jobs with `sbatch`. Override the partition at submission time with `-p GPU1` or `-p GPU2`.

### Single-node benchmarks

| Script | Partition | GPUs | Scope |
|--------|-----------|------|-------|
| `1node.sh` | GPU1 | 8 (all) | All-GPU intra-node (NVLink) |
| `1socket.sh` | GPU1 | 2 (GPUs 0–1) | Same-socket intra-socket P2P |
| `1socket-4gpu.sh` | GPU1 | 4 (GPUs 0–3) | Full socket 0 (PCIe domain `0000:`) |
| `2socket.sh` | GPU1 | 5 (GPUs 0–4) | Cross-socket P2P (4 from socket 0 + 1 from socket 1) |

```bash
sbatch -p GPU1 1node.sh
sbatch -p GPU1 1socket.sh
sbatch -p GPU1 1socket-4gpu.sh
sbatch -p GPU1 2socket.sh
```

### Multi-node benchmarks

| Script | Partition | Nodes | GPUs/node | Scope |
|--------|-----------|-------|-----------|-------|
| `2nodes-8gpus.sh` | GPU2 | 2 | 8 | Full inter-node (NVLink + IB/NDR) |
| `2nodes-2gpus.sh` | GPU2 | 2 | 1 | Single GPU per node (IB/NDR only) |

```bash
sbatch -p GPU2 2nodes-8gpus.sh
sbatch -p GPU2 2nodes-2gpus.sh
```

## Output

Logs are written to:
- `out-1node/` — single-node jobs
- `out-1socket/` — single-socket jobs
- `out-2node/` — multi-node jobs

Filename format: `<job-name>-<node>-<job-id>`

## Collectives

Each script runs all ten benchmarks in sequence:

```
sendrecv  reduce  broadcast  gather  scatter
reduce_scatter  all_gather  all_reduce  alltoall  hypercube
```

## Environment variables

Key variables (uncomment in the script to enable):

| Variable | Effect |
|----------|--------|
| `NCCL_DEBUG=INFO` | Verbose NCCL init and channel selection |
| `NCCL_DEBUG_SUBSYS=NET` | Network-layer debug (IB, SHARP) |
| `NCCL_COLLNET_ENABLE=1` | Enable SHARP offload on AllReduce |
| `SHARP_COLL_LOCK_ON_COMM_INIT=1` | Required alongside COLLNET_ENABLE |
| `NCCL_MIN_NCHANNELS=4` | Force minimum channel count |
| `NCCL_IB_QPS_PER_CONNECTION=4` | IB queue pairs per connection |

> **SHARP note:** `2nodes-*.sh` scripts load the SHARP library and preserve `IBext` as the net plugin. Do not set `NCCL_NET=IB`; it disables the `nccl_rdma_sharp_plugin` required for SHARP CollNet activation.
