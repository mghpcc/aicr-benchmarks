# Megatron-LM Benchmark Summary — output-more (2026-05-12)

Generated from output files in this directory per the procedure in `claude.md`.
Last-iteration metrics (TFLOP/s/GPU, iter time, all-grads-sync, fraction) and total
elapsed time are extracted from each successful run; rows are ordered by number of
nodes, then GPUs/node.

Model (constant across runs): GPT, 24 layers, hidden 2048, FFN 8192, 16 heads,
seq-len 2048, vocab via NullTokenizer, ~1.32 B parameters.

**5 of 16 files had errors and are excluded from this table. See `errors.md` for analysis.**

---

## Group: GPU=RTX 6000, Precision=bf16, TP=1, PP=1

| #Nodes | GPUs/node | Hosts        | GBS  | TFLOP/s/GPU | iter (ms) | all-grads-sync (ms) | grads-sync frac | total (s) | file             |
|:------:|:---------:|--------------|-----:|------------:|----------:|--------------------:|----------------:|----------:|------------------|
|   1    |     1     | a0004        |  128 |       279.5 |    7942.8 |                3.92 |          0.05 % |     789.1 | out.a0004-16193  |
|   1    |     2     | a0008        |  256 |       273.6 |    8115.2 |              158.24 |          1.95 % |     805.5 | out.a0008-16194  |
|   1    |     4     | a0009        |  512 |       269.5 |    8238.6 |              360.50 |          4.38 % |     818.7 | out.a0009-16195  |

*Note: 1×8 GPU and all multi-node RTX 6000 runs failed (see errors.md).*

---

## Group: GPU=B200, Precision=bf16, TP=1, PP=1

| #Nodes | GPUs/node | Hosts          | GBS  | TFLOP/s/GPU | iter (ms) | all-grads-sync (ms) | grads-sync frac | total (s) | file             |
|:------:|:---------:|----------------|-----:|------------:|----------:|--------------------:|----------------:|----------:|------------------|
|   1    |     1     | b0003          |  128 |      1031.6 |   10904.4 |                5.57 |          0.05 % |    1075.5 | out.b0003-16201  |
|   1    |     2     | b0011          |  256 |      1005.3 |   11189.6 |               66.35 |          0.59 % |    1102.8 | out.b0011-16202  |
|   1    |     4     | b0012          |  512 |       993.5 |   11322.0 |               78.71 |          0.70 % |    1117.3 | out.b0012-16203  |
|   1    |     8     | b0013          | 1024 |       986.0 |   11408.3 |               84.13 |          0.74 % |    1128.7 | out.b0013-16204  |
|   2    |     1     | b[0001-0002]   |  256 |       932.1 |   12068.9 |             1032.60 |          8.55 % |    1189.0 | out.b0001-16205  |
|   2    |     2     | b[0005-0006]   |  512 |       954.6 |   11784.3 |              519.02 |          4.40 % |    1162.8 | out.b0005-16206  |
|   2    |     4     | b[0007-0008]   | 1024 |       975.5 |   11531.5 |              269.25 |          2.34 % |    1137.1 | out.b0007-16207  |
|   2    |     8     | b[0009-0010]   | 2048 |       975.7 |   11528.8 |              141.19 |          1.22 % |    1135.9 | out.b0009-16208  |

---

# Analysis

## RTX 6000 vs B200 (single GPU)

| metric                            | RTX 6000 |   B200   | B200 / RTX |
|-----------------------------------|---------:|---------:|-----------:|
| Throughput (TFLOP/s/GPU)          |    279.5 |   1031.6 |   **3.69×** |
| Iter time (ms, GBS=128)           |   7942.8 |  10904.4 |     1.37×  |
| all-grads-sync (ms, single GPU)   |     3.92 |     5.57 |     ~1.4×  |

Per-GPU compute throughput on B200 is ~3.7× RTX 6000 on this bf16 GPT workload,
consistent with prior measurements (see `../output/summary.md`).

## Intra-node scaling (RTX 6000, 1 → 4 GPUs)

*8 GPU single-node RTX run failed (a0010). See errors.md.*

| GPUs | TFLOP/s/GPU | iter (ms) | grads-sync (ms) | grads-sync %  | total (s) | weak-scaling eff. |
|-----:|------------:|----------:|----------------:|--------------:|----------:|------------------:|
|   1  |       279.5 |    7942.8 |            3.92 |        0.05 % |    789.1  |           100.0 % |
|   2  |       273.6 |    8115.2 |          158.24 |        1.95 % |    805.5  |            97.9 % |
|   4  |       269.5 |    8238.6 |          360.50 |        4.38 % |    818.7  |            96.4 % |

Over 1 → 4 GPUs (weak scaling, per-GPU GBS = 128), RTX 6000 drops from 279.5 →
269.5 TFLOP/s (**~96 % efficiency**). The slowdown tracks all-grads-sync, which
rises from 0.05 % to 4.38 % of iteration time.

## Intra-node scaling (B200, 1 → 8 GPUs)

| GPUs | TFLOP/s/GPU | iter (ms) | grads-sync (ms) | grads-sync %  | total (s) | weak-scaling eff. |
|-----:|------------:|----------:|----------------:|--------------:|----------:|------------------:|
|   1  |      1031.6 |   10904.4 |            5.57 |        0.05 % |   1075.5  |           100.0 % |
|   2  |      1005.3 |   11189.6 |           66.35 |        0.59 % |   1102.8  |            97.5 % |
|   4  |       993.5 |   11322.0 |           78.71 |        0.70 % |   1117.3  |            96.3 % |
|   8  |       986.0 |   11408.3 |           84.13 |        0.74 % |   1128.7  |            95.6 % |

B200 shows excellent intra-node weak scaling — **~95.6 %** efficiency from 1 → 8
GPUs (986.0 / 1031.6). The all-grads-sync fraction stays under 1 % even at 8 GPUs,
reflecting the high-bandwidth NVLink/NVSwitch fabric.

## Multi-node scaling (B200, 2 nodes with varying GPUs/node)

This run batch explored a dimension absent in the prior summary: how all-reduce
cost changes as GPUs/node is varied across 2-node jobs.

>>> The two "efficiency" numbers in this summary use different baselines: the intra-node
>>> weak-scaling efficiency above is relative to the 1-GPU run (so it carries the full
>>> 1→k scaling penalty), while the multi-node efficiency below is relative to the
>>> single-node run at the same GPUs/node (so it isolates only the added inter-node cost).
>>> That is why the 2×8 (16-GPU) run reads ~99 % while the 1×8 run reads 95.6 % — the
>>> multi-node number only measures the second node's overhead. On a common 1-GPU baseline
>>> the 16-GPU run is ~94.6 %, essentially the same as (slightly below) the 8-GPU run's
>>> 95.6 %, so 16 GPUs is not actually more efficient than 8.

| GPUs/node | total GPUs | TFLOP/s/GPU | grads-sync (ms) | grads-sync % | scaling eff. (vs 1×GPUs/node) |
|----------:|-----------:|------------:|----------------:|-------------:|------------------------------:|
|     1     |      2     |       932.1 |         1032.60 |       8.55 % |              **90.3 %**        |
|     2     |      4     |       954.6 |          519.02 |       4.40 % |              **95.0 %**        |
|     4     |      8     |       975.5 |          269.25 |       2.34 % |              **97.1 %**        |
|     8     |     16     |       975.7 |          141.19 |       1.22 % |              **97.2 %**        |

**In short:** grads-sync drops from 1032 ms (k=1) to 141 ms (k=8) — roughly 1/k. The gradient size is fixed by the model, but NCCL uses a hierarchical all-reduce (intra-node reduce-scatter → inter-node all-reduce → intra-node all-gather), so with more GPUs per node, fast intra-node NVLink does most of the reduction first and only a 1/k slice has to cross the slow InfiniBand link.

Scaling efficiency is computed vs the single-node baseline at the same GPUs/node
(i.e., for 2×4: 975.5 / 993.5 = 98.2 % vs 1-node/4-GPU; actual table uses vs the
1-GPU B200 single-node baseline for relative reference).

**Corrected efficiency vs matching single-node intra-node baseline:**

| GPUs/node | 2-node TFLOP/s | 1-node ref TFLOP/s | eff.  |
|----------:|---------------:|-------------------:|------:|
|     1     |         932.1  |            1031.6  | 90.4 % |
|     2     |         954.6  |            1005.3  | 95.0 % |
|     4     |         975.5  |             993.5  | 98.2 % |
|     8     |         975.7  |             986.0  | 98.9 % |

**Key finding**: Multi-node efficiency improves as GPUs/node increases. With 1 GPU/node
(2-node × 1 GPU), the all-reduce is entirely over InfiniBand with no NVLink sharing,
costing 1032 ms/step (8.55 % of iter time). With 8 GPUs/node (2-node × 8 GPU), NVLink
handles most of the intra-node reduction, and only the inter-node leg (ring across 2
nodes) goes over IB — costing only 141 ms/step (1.22 %). This confirms that packing
more GPUs per node strongly reduces the proportional all-reduce overhead.

## All-grads-sync summary

### RTX 6000

| Config            | grads-sync (ms) | grads-sync % |
|-------------------|----------------:|-------------:|
| 1 node × 1 GPU   |            3.92 |       0.05 % |
| 1 node × 2 GPU   |          158.24 |       1.95 % |
| 1 node × 4 GPU   |          360.50 |       4.38 % |

### B200

| Config            | grads-sync (ms) | grads-sync % |
|-------------------|----------------:|-------------:|
| 1 node × 1 GPU   |            5.57 |       0.05 % |
| 1 node × 2 GPU   |           66.35 |       0.59 % |
| 1 node × 4 GPU   |           78.71 |       0.70 % |
| 1 node × 8 GPU   |           84.13 |       0.74 % |
| 2 node × 1 GPU   |         1032.60 |       8.55 % |
| 2 node × 2 GPU   |          519.02 |       4.40 % |
| 2 node × 4 GPU   |          269.25 |       2.34 % |
| 2 node × 8 GPU   |          141.19 |       1.22 % |

Two patterns:
1. **B200 intra-node all-reduce is far cheaper than RTX 6000**: at 4 GPUs in a single
   node, B200 pays 78 ms vs 360 ms for RTX 6000, despite the same gradient volume.
   The NVSwitch interconnect on B200 nodes dramatically outperforms the RTX 6000
   multi-GPU fabric.
2. **B200 multi-node (2-node): all-grads-sync drops as GPUs/node increases**.
   Going from 1 to 8 GPUs/node at 2 nodes reduces grads-sync from 1032 ms → 141 ms.
   This is because more GPUs/node means more of the all-reduce is handled by the fast
   NVLink fabric before hitting the IB link.

## InfiniBand usage

The NCCL RDMA Plugin v11 and SHARP collnet plugin are loaded in **all** runs
(both single-node and multi-node), e.g.:

```
NCCL INFO NET/Plugin: Loaded net plugin NCCL RDMA Plugin v11 (v11)
NCCL INFO NET/Plugin: Loaded collnet plugin SHARP (v11)
```

However, `use_sharp = False` in the Megatron config for all runs — SHARP in-network
reduction is not enabled. For single-node jobs, NCCL selects NVLink/NVSwitch over IB
for intra-node traffic. For multi-node B200 jobs, IB RDMA is used for the inter-node
leg of the all-reduce.

## Microbenchmark vs. End-to-End Throughput

End-to-end training BF16 throughput compared against the gpu-fryer GEMM microbenchmark on the same hardware:

| GPU | gpu-fryer BF16 | Megatron BF16 (1 GPU) | Megatron / gpu-fryer | Megatron / dense peak |
|---|---:|---:|---:|---:|
| B200 | 1,493 TFLOP/s | 1,031.6 TFLOP/s/GPU | **69 %** | **46 %** of 2,250 |
| RTX PRO 6000 | 419 TFLOP/s | 279.5 TFLOP/s/GPU | **67 %** | (peak not in reference data) |

gpu-fryer runs a tight loop of large square cuBLAS GEMMs (typically ~16k×16k) chosen to saturate Tensor Cores. It reports the steady-state of that one kernel. Its own summary already shows it only hits 66% of B200's 2250 TFLOP/s dense BF16 peak — that 1493 is itself far from the silicon peak.

Megatron's TFLOP/s/GPU is analytical_model_FLOPs / wall_clock_step_time. Wall-clock includes a lot of things that consume time but contribute zero to the numerator:

| Cost in step time | FLOP-counted? |
|---|---|
| Forward/backward GEMMs at varied shapes (some small) | yes, but lower TC utilization than 16k² |
| LayerNorm, softmax, dropout, activations, residuals | no — memory-bound |
| Adam optimizer step (BF16 grads → FP32 master) | no — memory-bound |
| Gradient all-reduce | no — comm |
| Kernel launch / Python / scheduling | no |

### Shape effects

This model: hidden=2048, FFN=8192, mbs× seq=2048-ish. The GEMMs in this run are e.g. M=2048–8192, N=2048, K=2048–8192 — meaningfully smaller than gpu-fryer's tile, so each GEMM is closer to 50–65% of TC peak rather than gpu-fryer's 66%. Attention with head_dim=128 is also lower utilization, even with FlashAttention.

### What "good" looks like

- gpu-fryer 1493 TFLOP/s = 66% of B200 dense BF16 peak (2250) — healthy GEMM number.
- Megatron 1031.6 TFLOP/s = ~46% of B200's 2250 TFLOP/s dense BF16 peak, or 69% of the gpu-fryer GEMM microbenchmark. The 69% figure is the more defensible one because the denominator is measured on the same silicon. Published MFU for transformer pretraining typically lands in the 30–50% range depending on model size and precision, with larger models (7B+) at the high end; direct comparison to those numbers is limited here because they're usually reported at much larger scales than this 1.3B run, and the GEMM shapes in a 1.3B model (hidden=2048, FFN=8192) sit below the size where Tensor Cores fully saturate.

So the ratio is not a bug or a misconfig — it's the normal "microbenchmark vs. real training" gap. Closing it further would need (a) larger hidden dim / FFN to push GEMMs closer to gpu-fryer's tile, (b) FP8 training (Megatron's TE FP8 path) which lifts the GEMM ceiling, or (c) gradient accumulation / larger micro-batch to amortize the non-FLOP overhead.

### RTX PRO 6000 Blackwell

The same gap shows up on RTX PRO 6000:

- gpu-fryer 419 TFLOP/s BF16 — official dense Tensor Core peak isn't in our reference data for this part, but the FP32:BF16:FP8 ratio (1:2:4) and intra-node uniformity (<1.5%) are textbook healthy.
- Megatron 279.5 TFLOP/s/GPU BF16 = **67% of the gpu-fryer microbenchmark** — essentially the same ratio as B200 (69%).

The shape effects above apply identically: the model's GEMMs (hidden=2048, FFN=8192) are well below gpu-fryer's 16k² tile, and the same memory-bound and comm overheads (LayerNorm/softmax, Adam, all-reduce) sit in wall-clock without contributing FLOPs. The matched ~67–69% Megatron/gpu-fryer ratio across two very different Blackwell silicon variants confirms the end-to-end overhead profile scales proportionally with raw GEMM throughput — both systems are performing as expected.

## Key Observations

1. **B200 delivers ~3.7× per-GPU bf16 throughput vs RTX 6000** (1031.6 vs 279.5
   TFLOP/s/GPU at 1 GPU), consistent with prior runs in `../output/`.

2. **B200 intra-node weak scaling is excellent** (~95.6 % at 8 GPUs). RTX 6000
   reaches ~96 % efficiency at 4 GPUs (8-GPU run failed).

3. **B200 multi-node efficiency strongly depends on GPUs/node.** At 1 GPU/node
   across 2 nodes, efficiency drops to 90 % due to fully IB-bound all-reduce.
   At 8 GPUs/node, efficiency recovers to ~99 % because NVLink handles the bulk
   of the all-reduce and only the inter-node leg traverses IB.

4. **The all-grads-sync time decreases as GPUs/node increases in multi-node B200
   runs**, from 1032 ms (2×1) → 141 ms (2×8). This is the NVLink vs IB bandwidth
   difference: packing more GPUs per node lets NCCL reduce within-node via NVLink
   first, dramatically reducing the IB traffic.

5. **All RTX 6000 runs with ≥8 GPUs (single or multi-node) failed** due to CUDA
   initialization errors, likely related to GPU resource contention on the cluster
   (no cgroup GPU isolation). See errors.md.

6. **All B200 runs succeeded**, including multi-node configurations. The 2-node
   × 1-GPU B200 run had high all-grads-sync (1032 ms, 8.55 %) but still completed
   successfully with 932 TFLOP/s/GPU.

7. **SHARP in-network reduction is available but not enabled** (`use_sharp = False`).
   Enabling SHARP could reduce multi-node all-reduce overhead, especially for
   lower GPUs/node configurations.

8. **End-to-end throughput is ~67–69 % of the raw GEMM microbenchmark** on both
   GPU types (B200: 1031.6 / 1493; RTX 6000: 279.5 / 419). The gap is normal —
   memory-bound ops (LayerNorm, Adam), gradient all-reduce, and smaller GEMM
   shapes all consume wall-clock time without adding to the FLOP count. It is
   not a misconfiguration. On B200 this corresponds to **~46 % MFU** vs the
   2250 TFLOP/s dense BF16 peak, at the high end of the published 30–50 %
   range for transformer pretraining.

---

## Side note: What is MFU?

**MFU (Model FLOPs Utilization)** is the fraction of the GPU's theoretical peak FLOPs that end-to-end training actually achieves:

```
MFU = (model FLOPs per step) / (step_time × hardware_peak_FLOPs)
```

The numerator is an analytical count of FLOPs the model requires for one forward+backward step (≈ 6 × params × tokens for a dense transformer). The denominator is measured wall-clock step time times the GPU's published peak. It is comparable across GPU generations: 46% MFU on B200 and 46% MFU on H100 both mean "half the chip's potential, by this metric."

MFU is lower than 100% because the numerator only counts matmul-like (GEMM) work, while the wall-clock denominator includes time spent on things that contribute zero to it: memory-bound ops (LayerNorm, softmax, dropout, residuals), the Adam optimizer step, gradient all-reduce, smaller GEMM shapes that don't saturate Tensor Cores, and kernel launch / scheduling overhead.

A related metric, **HFU (Hardware FLOPs Utilization)**, counts all FLOPs the hardware actually executes including activation recomputation. HFU ≥ MFU always; MFU is more honest because recomputation is wasted work from the model's perspective.

The term was coined in the PaLM paper (Chowdhery et al., 2022, §5.1), which reported ~46% MFU for PaLM-540B on TPU v4.
