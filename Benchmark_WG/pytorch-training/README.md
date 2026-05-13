# PyTorch DDP Scaling Benchmark

PyTorch Distributed Data Parallel (DDP) scaling benchmark for the AICR cluster. Measures throughput, scaling efficiency, and GPU activity for ResNet workloads across single-GPU, single-node multi-GPU, and multi-node multi-GPU configurations.

## When to use this benchmark

This benchmark answers: "How well does PyTorch DDP scale on our cluster for CNN-style workloads?"

Use it for:
- Cluster acceptance testing after hardware/software changes
- Comparing scaling behavior between different node types
- Investigating user-reported scaling issues
- Generating numbers for capacity planning or grant proposals

Do NOT use it for:
- End-to-end training time estimates (no data loading included)
- Inference benchmarking (different operation patterns)
- LLM-style transformer workloads (different communication patterns)
- Model accuracy or convergence testing

## Quick start

Assuming you have a working conda env with PyTorch (matching your target GPU's compute capability):

```bash
# Edit sbatch files for your partition, account, modules
# Then submit the full sweep:
./submit_sweep.sh

# After jobs complete:
python analyze_results.py results/
python visualize_results.py results/ --device-label "B200"
```

## What's measured

Each run writes a JSON file with:
- Per-step timing (mean, p50, p95, p99, stdev)
- Throughput (images/sec per GPU and global)
- Peak memory across ranks (min/mean/max/spread)
- GPU activity sampling from nvidia-smi during the bench window
- Straggler ratio across ranks

## Scaling modes

`SCALING=weak` (default): per-GPU batch fixed, global batch grows with world size. Tests whether each GPU stays busy.

`SCALING=strong`: global batch fixed, per-GPU batch shrinks with world size. Tests how much faster the same problem runs with more resources. The classic HPC speedup curve.

## Files

- `benchmark_ddp.py` — main script, launched via torchrun
- `run_1gpu.sbatch`, `run_1node_multigpu.sbatch`, `run_multinode.sbatch` — Slurm wrappers
- `submit_sweep.sh` — submit the full matrix of jobs
- `analyze_results.py` — text-format results aggregation
- `visualize_results.py` — PNG plot generation

## Configuration

Defaults in `submit_sweep.sh`:

- `MODEL=resnet50` — supports `resnet101`, `resnet152` as well
- `PER_GPU_BS=128` — fits 96GB cards comfortably; bump to 256+ on B200
- `GLOBAL_BS_LIST=(1024 2048)` — global batch sizes for strong scaling

> For ResNet-152 on ≤96GB cards, reduce to `PER_GPU_BS=64` and `GLOBAL_BS_LIST=(512 1024)`. Activation memory at the 1-GPU strong-scaling baseline is ~2.5x ResNet-50 at the same batch.

> **B200 memory note**: ResNet-50 at GLOBAL_BS=4096 reaches ~95% of B200's 180GB HBM on the 1-GPU baseline, creating allocator pressure that distorts strong-scaling efficiency numbers. For clean scaling results on B200, keep GLOBAL_BS ≤ 2048 for ResNet-50. ResNet-101/152 at default batches are well within the safe regime.

> **General OOM guidance**: if you hit OOM on the 1-GPU strong-scaling baseline, halve `GLOBAL_BS_LIST` values until it fits. If you hit OOM on multi-GPU runs, halve `PER_GPU_BS` instead. Aim for 1-GPU peak memory below 85% of GPU capacity for clean scaling numbers. Memory pressure inflates baseline step time and can produce misleading "superlinear" efficiency.

To change defaults, edit `submit_sweep.sh`:

```bash
MODEL="resnet50"
PER_GPU_BS=128
GLOBAL_BS_LIST=(1024 2048)
```

Or override per-job without editing files:

```bash
sbatch --export=ALL,SCALING=strong,GLOBAL_BS=2048,MODEL=resnet152 run_multinode.sbatch
```

## Cluster-specific notes (AICR)

The benchmark has been validated on:
- B200 nodes (sm_100)
- RTX Pro 6000 Blackwell nodes (sm_120)

Module/environment setup as currently used:

```bash
module load cuda/13.1
module load miniforge3
source activate <env>   # or: conda activate <env>
```

Required PyTorch version: 2.10.0+cu130 (or newer cu130 wheel) for both Blackwell variants. Verify with:

```bash
python -c "import torch; print(torch.cuda.get_arch_list())"
```

Both `sm_100` and `sm_120` should appear.

## Reference results

Validated runs on the AICR cluster (BF16, channels-last, no compile), strong scaling efficiency at 16 GPUs (2 nodes):

| Model      | Hardware       | Small batch     | Large batch     |
|------------|----------------|-----------------|-----------------|
| ResNet-50  | B200           | 65% (bs=1024)   | 77% (bs=2048)   |
| ResNet-101 | B200           | 58% (bs=1024)   | 72% (bs=2048)   |
| ResNet-152 | B200           | 56% (bs=1024)   | 70% (bs=2048)   |
| ResNet-50  | RTX Pro 6000   | ~100% (bs=1024) | ~100% (bs=2048) |
| ResNet-101 | RTX Pro 6000   | 68% (bs=512)    | 98% (bs=1024)   |
| ResNet-152 | RTX Pro 6000   | 69% (bs=512)    | 98% (bs=1024)   |

Weak scaling is healthy across all configurations: per-GPU throughput stays stable to 16 GPUs.

Key observations:
- B200 shows lower strong-scaling efficiency than RTX Pro 6000 across all three model sizes at matched batch sizes (e.g., ResNet-152 at GLOBAL_BS=1024: B200 56% vs RTX Pro 6000 98%). The most likely explanation is that B200's faster compute makes the same NCCL allreduce a larger fraction of step time.
- Larger global batches recover 12-14 percentage points of efficiency on B200, and ~30 percentage points on RTX Pro 6000 for ResNet-101/152.
- Most efficiency loss happens at the multi-node boundary (8 → 16 GPUs), pointing to inter-node communication as the bottleneck.
- Smaller batches reveal the communication-bound regime on both cards; B200 reaches that regime at moderate batches that don't trigger it on RTX Pro 6000.

*Note: RTX Pro 6000 ResNet-101/152 use smaller batches (512/1024) due to 96GB memory limits at the same per-GPU batch as B200 (180GB).*

## Troubleshooting

**NCCL hangs at init** in multi-node runs: check `NCCL_DEBUG=INFO` output for the chosen interface. If NCCL picked the management network instead of the high-speed NIC, set `NCCL_SOCKET_IFNAME` explicitly.

**CUDA init error on specific nodes** (`Unable to determine device handle`): the node has a GPU/driver issue. Exclude with `--exclude=<node>` and report to admins.

**OOM with ResNet-152**: see the ResNet-152 batch recommendations in the Configuration section. The 96GB cards cannot fit ResNet-152 at the default ResNet-50 batches.

**Straggler ratio > 1.10** in results: one rank is much slower than others. Usually NCCL/network, occasionally a faulty GPU. Check the per-rank stats in the JSON.

