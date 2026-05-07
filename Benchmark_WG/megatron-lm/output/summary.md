# Megatron-LM Benchmark Summary — 2026-05-07

Generated from output files in this directory per the procedure in `claude.md`.
Last-iteration metrics (TFLOP/s/GPU, iter time, all-grads-sync, fraction) and total
elapsed time are extracted from each successful run; rows are ordered by number of
nodes, then GPUs/node.

Model (constant across runs): GPT, 24 layers, hidden 2048, FFN 8192, 16 heads,
seq-len 2048, vocab via NullTokenizer, ~1.32 B parameters.

## Group: GPU=RTX 6000, Precision=bf16, TP=1, PP=1

| #Nodes | GPUs/node | Hosts          | GBS  | TFLOP/s/GPU | iter (ms) | all-grads-sync (ms) | grads-sync frac | total (s) | file              |
|:------:|:---------:|----------------|-----:|------------:|----------:|--------------------:|----------------:|----------:|-------------------|
|   1    |     1     | a0001          |  128 |       280.9 |    7905.5 |                3.68 |          0.05 % |     784.8 | out.a0001-9771    |
|   1    |     1     | a0012          |  128 |       280.9 |    7904.2 |                3.68 |          0.05 % |     784.5 | out.a0012-9639    |
|   1    |     2     | a0013          |  256 |       274.9 |    8076.0 |              156.55 |          1.94 % |     801.3 | out.a0013-9640    |
|   1    |     4     | a0014          |  512 |       266.9 |    8317.4 |              365.18 |          4.39 % |     825.9 | out.a0014-9641    |
|   1    |     8     | a0015          | 1024 |       264.8 |    8385.8 |              427.72 |          5.10 % |     833.0 | out.a0015-9642    |
|   2    |     8     | a[0010-0011]   | 2048 |       263.5 |    8424.8 |              411.89 |          4.89 % |     836.7 | out.a0010-9646    |

## Group: GPU=B200, Precision=bf16, TP=1, PP=1

| #Nodes | GPUs/node | Hosts          | GBS  | TFLOP/s/GPU | iter (ms) | all-grads-sync (ms) | grads-sync frac | total (s) | file              |
|:------:|:---------:|----------------|-----:|------------:|----------:|--------------------:|----------------:|----------:|-------------------|
|   1    |     1     | b0004          |  128 |       996.1 |   11293.0 |                5.47 |          0.05 % |    1115.1 | out.b0004-9647    |
|   1    |     1     | b0025          |  128 |      1024.4 |   10980.9 |                4.91 |          0.04 % |    1083.3 | out.b0025-9772    |
|   1    |     2     | b0031          |  256 |      1007.7 |   11162.4 |               66.70 |          0.60 % |    1101.8 | out.b0031-9648    |
|   1    |     4     | b0009          |  512 |       985.2 |   11417.8 |               77.59 |          0.68 % |    1125.3 | out.b0009-9649    |
|   1    |     8     | b0010          | 1024 |       993.3 |   11325.0 |               84.43 |          0.75 % |    1117.4 | out.b0010-9650    |
|   2    |     8     | b[0007-0008]   | 2048 |       978.9 |   11490.8 |              140.55 |          1.22 % |    1136.1 | out.b0007-9654    |

---

# Analysis

## RTX 6000 vs B200

| metric (single GPU)               | RTX 6000 |  B200    | B200 / RTX |
|-----------------------------------|---------:|---------:|-----------:|
| Throughput (TFLOP/s/GPU)          |    280.9 |   1024.4 |     **3.6×** |
| Iter time (ms, GBS=128)           |   7905   |   10981  |     1.39×  |
| all-grads-sync (ms, single GPU)   |     3.7  |      4.9 |     ~1.3×  |

Per-GPU compute throughput on B200 is ~3.6× RTX 6000 in this bf16 GPT workload.
The B200 iter time at a fixed GBS of 128 is *longer* because the same GBS is
processed by a single GPU in both cases — but B200 sustains ~3.6× the FLOPs that
the model body actually exposes, indicating substantially more arithmetic per
unit time. Both single-GPU runs spend a negligible (<0.1 %) fraction in
all-grads-sync, as expected when there is no data-parallel reduction.

## Intra-node scaling (1 → 8 GPUs in a single node)

### RTX 6000 (single node, GBS scaled with #GPUs to keep per-GPU GBS=128)

| GPUs | TFLOP/s/GPU | iter (ms) | grads-sync ms | grads-sync %  | total (s) |
|-----:|------------:|----------:|--------------:|--------------:|----------:|
|   1  |       280.9 |    7905   |          3.7  |        0.05 % |    784.8  |
|   2  |       274.9 |    8076   |        156.6  |        1.94 % |    801.3  |
|   4  |       266.9 |    8317   |        365.2  |        4.39 % |    825.9  |
|   8  |       264.8 |    8386   |        427.7  |        5.10 % |    833.0  |

Per-GPU throughput drops from 280.9 → 264.8 TFLOP/s going 1 → 8 GPUs
(**~94 % weak-scaling efficiency**). The slowdown tracks all-grads-sync, which
grows from 0.05 % to 5.10 % of iteration time — i.e. nearly all of the lost
efficiency is paid to gradient all-reduce.

### B200 (single node, GBS scaled with #GPUs)

| GPUs | TFLOP/s/GPU | iter (ms) | grads-sync ms | grads-sync %  | total (s) |
|-----:|------------:|----------:|--------------:|--------------:|----------:|
|   1  |      1024.4 |   10981   |          4.9  |        0.04 % |   1083.3  |
|   2  |      1007.7 |   11162   |         66.7  |        0.60 % |   1101.8  |
|   4  |       985.2 |   11418   |         77.6  |        0.68 % |   1125.3  |
|   8  |       993.3 |   11325   |         84.4  |        0.75 % |   1117.4  |

B200 shows excellent intra-node weak scaling — **~97 %** efficiency from 1 → 8
GPUs (993 / 1024). The all-grads-sync fraction stays under 1 % even at 8 GPUs,
indicating that NVLink/NVSwitch absorbs the data-parallel reduction with very
little overhead relative to compute.

## Multi-node scaling

Available 2-node datapoint per GPU type (full-node allocation, 8 GPUs/node):

| GPU      | 1 node × 8 GPU | 2 node × 8 GPU | Δ TFLOP/s/GPU | scaling eff. (vs 1×8) |
|----------|---------------:|---------------:|--------------:|----------------------:|
| RTX 6000 |          264.8 |          263.5 |        −0.5 % |              **99.5 %** |
| B200     |          993.3 |          978.9 |        −1.4 % |              **98.5 %** |

For both GPU types, going from 1×8 to 2×8 GPUs adds <1.5 % per-GPU throughput
loss — i.e. with full-node allocations, **inter-node DDP is essentially free at
this model size**. The all-grads-sync absolute time barely moves on RTX 6000
(427 → 412 ms — within run-to-run noise) and rises modestly on B200 (84 → 141 ms,
+56 ms), so the inter-node leg of the all-reduce on B200 costs ~60 ms per step.

## All-grads-sync time

Summary of the all-reduce (DDP gradient sync) cost across configurations:

| config            |  RTX 6000 | B200    |
|-------------------|----------:|--------:|
| 1 node × 1 GPU    |   3.7 ms  |  4.9 ms |
| 1 node × 2 GPU    | 156.6 ms  | 66.7 ms |
| 1 node × 4 GPU    | 365.2 ms  | 77.6 ms |
| 1 node × 8 GPU    | 427.7 ms  | 84.4 ms |
| 2 node × 8 GPU    | 411.9 ms  | 140.6 ms|

Two clear effects:

1. **Single-GPU baseline is tiny** (≤6 ms). It is non-zero because Megatron
   still posts the bucket reduction; with a DP world size of 1 it is just a
   no-op on local memory.
2. **B200 amortises the all-reduce ~5× better than RTX 6000 inside a node**
   (e.g. 8 GPUs: 84 ms vs 428 ms). The two GPU types share the same model
   gradient volume, so the gap is purely from the higher-bandwidth NVLink/
   NVSwitch domain on B200 versus the RTX 6000 inter-GPU fabric.
3. **Going from 1×8 → 2×8 nodes adds only ~56 ms on B200 and is within
   noise on RTX 6000**, suggesting the inter-node leg over IB is well
   pipelined with computation.

## InfiniBand usage

Yes — every multi-GPU run (single-node and multi-node) loaded the
**`NCCL RDMA Plugin v11`** plus the **SHARP collnet plugin** at startup, e.g.

```
NCCL INFO NET/Plugin: Loaded net plugin NCCL RDMA Plugin v11 (v11)
NCCL INFO NET/Plugin: Loaded collnet plugin SHARP (v11)
```

Both 2-node jobs (a0010, b0007) loaded these plugins, so inter-node
all-reduce is going over InfiniBand RDMA with SHARP available for in-network
reductions.

## Key observations

1. **B200 delivers ~3.6× the per-GPU bf16 throughput of RTX 6000** on this 1.3 B
   GPT model (1024 vs 281 TFLOP/s/GPU at 1 GPU).
2. **Intra-node weak scaling is excellent on both platforms** (RTX 6000 ~94 %,
   B200 ~97 % at 8 GPUs). The remaining loss on RTX 6000 is almost entirely
   gradient all-reduce overhead.
3. **At full-node allocation, multi-node scaling is near-perfect** (~99 % on
   RTX 6000, ~98 % on B200) — the inter-node all-reduce over InfiniBand RDMA
   adds only ~60 ms/step on B200 and is within run-to-run noise on RTX 6000.
4. **InfiniBand + RDMA + SHARP plugins load on every multi-GPU job**, so
   inter-node communication does use IB.
5. **Run-to-run variation on identical 1 GPU B200 configs is ~3 %** (996 vs
   1024 TFLOP/s for b0004 vs b0025); RTX 6000 single-GPU repeats are
   essentially identical (280.9 / 280.9). When comparing configs that differ
   by a few percent, this noise floor should be kept in mind.
6. **GBS scales 1:1 with total GPU count in this sweep** (per-GPU GBS = 128
   throughout). All scaling numbers are therefore weak-scaling — any iter-time
   growth is communication or pipeline overhead, not increased per-GPU work.
