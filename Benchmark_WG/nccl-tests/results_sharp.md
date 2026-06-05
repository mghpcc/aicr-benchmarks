# SHARP results — 2-node B200 AllReduce

**SHARP (in-network reduction on the IB switch) makes 2-node AllReduce 2.2× faster at
8 GPU/node.** Use it for data/tensor-parallel training at scale.

## 8 GPU/node × 2 nodes (16 GPUs) — 2.2× faster

Clean A/B, `all_reduce_perf` busbw (GB/s), out-of-place (job 36311, nodes b0020+b0024).

| Message size | Ring (no SHARP) | SHARP | Speedup |
|---|---|---|---|
| 256 MB  | 113.1 | 197.9 | 1.75× |
| 1 GB    | 116.5 | 258.4 | 2.22× |
| 4 GB    | 160.7 | 344.1 | 2.14× |
| **16 GB** | **162.7** | **357.2** | **2.20×** |
| **Avg (1MB–16GB)** | **81.1** | **160.6** | **1.98×** |

- Validation clean (0 wrong values).
- Peak **357 GB/s exceeds the ~214 GB/s GDRDMA bidirectional ceiling**: plain Ring is capped
  there by its two-pass (reduce-scatter + all-gather) PCIe load; SHARP reduces in the switch
  (single pass) and bypasses it. The win grows with message size (crossover ~4 MB).

## How to enable (8 GPU/node)

See `2nodes-8gpus-sharp-ab.sh`. Key settings:
- `NCCL_COLLNET_ENABLE=1`, `SHARP_COLL_LOCK_ON_COMM_INIT=1`
- `NCCL_ALGO=CollNetChain,CollNetDirect`, `NCCL_PROTO=Simple` (SHARP must be forced; NCCL's
  tuner otherwise prefers Ring)
- `NCCL_IB_HCA="^mlx5_7,mlx5_8,mlx5_9,mlx5_10,mlx5_12"` (use the 8 SHARP-good NICs)
- `LD_PRELOAD=/lib64/libnuma.so.1`; on shared nodes add `--bind-to none`

SHARP accelerates AllReduce / Reduce / ReduceScatter / AllGather / Broadcast only.

## 2 GPU/node × 2 nodes — not worth it

At low NIC count SHARP gives no benefit: AllReduce peaks at **75 GB/s vs 82 GB/s for Ring
(−9%)** at large sizes (job 36306). With only 2 NICs/node the aggregate isn't bottlenecked,
so Ring is already optimal. Use the default at 2–4 GPU/node; enable SHARP at 8 GPU/node.

_Data: jobs 36306 (2 GPU A/B), 36311 (8 GPU A/B), 2026-06-05, partition b200-batch.
Scripts: `2nodes-2gpus-sharp-ab.sh`, `2nodes-8gpus-sharp-ab.sh`._
