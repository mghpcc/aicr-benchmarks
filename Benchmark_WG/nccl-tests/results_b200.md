# B200 NCCL Benchmark Results

**Hardware:** 8× NVIDIA B200 per node, NVLink 5.0 / NVSwitch (~900 GB/s per GPU per direction), 7× NDR NICs (400 Gb/s each = 350 GB/s aggregate per node per direction)

**Files:**
- 1-node: `out-1node/nvhpc-26.3-b0027-9175` — node b0027, 8 GPUs
- 2-node: `out-2node/nvhpc-26.3-b0029-9289` — nodes b0029 + b0030, 16 GPUs

Converged values taken at 16 GB message size (largest), best of out-of-place / in-place.

---

## Table 1: 1-Node B200 (b0027, 8× B200, NVLink 5.0 / NVSwitch)

| Benchmark | busbw (GB/s) | NVLink Max (GB/s) | % of NVLink Max |
|---|---|---|---|
| sendrecv | 666 | 900 | 74% |
| reduce | 701 | 900 | 78% |
| broadcast | 691 | 900 | 77% |
| gather | 717 | 900 | 80% |
| scatter | 746 | 900 | 83% |
| reduce_scatter | 695 | 900 | 77% |
| all_gather | 684 | 900 | 76% |
| all_reduce | 841 | 900 | **93%** |
| alltoall | 675 | 900 | 75% |
| hypercube | **FAILED** | — | — |

---

## Table 2: 2-Node B200 (b0029+b0030, 16× B200, NDR IB)

NDR max for sendrecv: GDRDMA bidirectional measured limit = **26.7 GB/s per direction per GPU** (hardware constant).
NDR max for all other collectives: 7 NICs × 50 GB/s = **350 GB/s aggregate per node per direction**.

| Benchmark | busbw (GB/s) | NDR Max (GB/s) | % of NDR Max |
|---|---|---|---|
| sendrecv | 26.6 | 26.7 (GDRDMA bidir) | **~100%** |
| reduce | 201 | 350 | 57% |
| broadcast | 202 | 350 | 58% |
| gather | 90.5 | 350 | 26% |
| scatter | 293 | 350 | 84% |
| reduce_scatter | 218 | 350 | 62% |
| all_gather | 218 | 350 | 62% |
| all_reduce | 170 | 350 | **49%** |
| alltoall | 39.8 | 350 | **11%** |
| hypercube | **FAILED** | — | — |

---

## Analysis

### 1-Node B200: Intra-node (NVLink) — Excellent Overall

All collectives reach **74–93% of NVLink max**, which is healthy. The busbw gap from 100% is normal: it reflects algorithm overhead (ring vs. tree vs. NVSwitch-optimal), startup latency folded into the timing, and the fact that busbw is normalized but not identical to raw fabric BW.

- **AllReduce at 93%** is the best result — NCCL's NVSwitch-aware algorithm fully exploits the NVSwitch all-to-all fabric instead of a sub-optimal ring, pushing busbw close to the theoretical ceiling.
- **SendRecv at 74%** is the lowest, but still good for intra-node. NVSwitch adds switching overhead for P2P traffic, and simultaneous bidirectional traffic can reduce peak unidirectional speed.
- **Hypercube FAILED**: Known **validation bug in nccl-tests 2.18.3**, not a hardware issue. The hardware is fine.

### 2-Node B200: Inter-node (NDR IB) — Mixed Results

**SendRecv — ~100% of GDRDMA bidir limit (26.6 / 26.7 GB/s):** This exactly matches the hardware-measured GDRDMA bidirectional ceiling. The B200 has a single PCIe Gen5 x16 port per GPU, and its DMA engine has a fixed HBM bandwidth budget of ~53.5 GB/s *total* shared between reads and writes. In bidirectional operation (sendrecv simultaneously sends and receives), each direction is capped at ~26.7 GB/s. **This is a silicon-level hardware limit — no NCCL tuning can overcome it.**

**AllGather + ReduceScatter at 62% (218 GB/s):** These are the healthiest inter-node collectives. Ring-based algorithms distribute traffic across all 7 NDR NICs evenly. The remaining 38% gap is due to protocol overhead (IB header, RDMA signaling) and imperfect load balancing across the 7 GPU-NIC pairs.

**AllReduce at 49% (170 GB/s) — SHARP is NOT active:** The clearest indicator is that allreduce busbw (170 GB/s) is *less than* all_gather busbw (218 GB/s). Without SHARP, allreduce is implemented as ReduceScatter + AllGather — two sequential IB traversals. With SHARP, reduction is offloaded to the InfiniBand switches in-flight, and allreduce becomes a single-pass operation that should approach or exceed 350 GB/s — roughly a **2× improvement**. SHARP infrastructure is confirmed ready on the fabric (`sharp_hello` passed, 153 OSTs available); this needs to be activated at the NCCL/job level.

**Scatter at 84% (293 GB/s) vs. Gather at 26% (90.5 GB/s) — Fan-out vs. Fan-in asymmetry:** Scatter (root fans out to all ranks) uses all 7 NDR NICs on the root node efficiently in parallel. Gather (all ranks fan in to one root) suffers because NCCL's gather algorithm cannot parallelize multi-GPU intra-node fan-in at the root side as effectively — the data funnel to a single root rank is algorithmically harder to pipeline across all NICs.

**Reduce and Broadcast at 57–58%:** Root-based collectives that only use IB in one direction. The gap from 100% reflects the same IB protocol overhead as AllGather.

**AllToAll at 11% (39.8 GB/s) — Severe inter-node bottleneck:** NCCL implements alltoall as point-to-point send/recv operations. With 16 GPUs across 2 nodes, the inter-node chunks are not fully pipelined across all NICs simultaneously. This is a **known NCCL algorithm limitation**, not a hardware fault — the same fabric delivers 218 GB/s for allgather.

**Hypercube FAILED** in both 1-node and 2-node — same nccl-tests 2.18.3 validation bug.

---

## Fixed Issues

These issues were diagnosed and resolved for this cluster. Performance above reflects the fixed state.

1. **`nvidia_peermem` installed** — Required for GPUDirect RDMA (GDR) over InfiniBand. Without it, NCCL falls back to CPU-bounce buffering for all inter-node transfers, reducing bandwidth from ~50 GB/s per NIC down to ~10–15 GB/s. GDR allows the NIC to DMA directly to/from GPU HBM over IB, which is what enables the 26.6 GB/s sendrecv and 218 GB/s allgather results above.

2. **ACS disabled (`iommu=off` in kernel boot)** — PCIe Access Control Services on CPU/platform switches can intercept all peer-to-peer GPU memory transactions and route them through the IOMMU, destroying NVLink and PCIe P2P performance. Setting `iommu=off` disables ACS system-wide, restoring native NVSwitch fabric throughput and enabling the intra-node results shown in Table 1.

---

## Deep Learning Application Performance Prediction

| Parallelism Type | Primary NCCL Op | 1-Node busbw | 2-Node busbw | Assessment |
|---|---|---|---|---|
| **Data Parallel (DDP)** | AllReduce | 841 GB/s | 170 GB/s | Intra-node excellent; inter-node limited — **SHARP would ~2× to ~350 GB/s** |
| **Pipeline Parallel** | SendRecv (P2P) | 666 GB/s | 26.6 GB/s | Inter-node capped at **hard hardware limit** (GDRDMA bidir, PCIe DMA engine) |
| **Tensor Parallel** | AllReduce, AllGather, ReduceScatter | 684–841 GB/s | 170–218 GB/s | Keep within one node; cross-node TP viable via AllGather+ReduceScatter at 218 GB/s |
| **MoE Parallel (expert dispatch)** | AllToAll | 675 GB/s | 39.8 GB/s | Inter-node alltoall **severely bottlenecked** (11% NDR); minimize cross-node expert routing |

**Key implications:**

- **Data Parallel:** Scale-out DDP will be gated on AllReduce across nodes. At 170 GB/s (SHARP off), inter-node gradient sync is the primary bottleneck for large models. **Activating SHARP is the highest-priority action for DDP scaling.**

- **Pipeline Parallel:** The 26.6 GB/s sendrecv ceiling means inter-node activation tensors are slow. A single GPU-NIC pair transfers ~26.6 GB/s bidirectionally — for a 1 GB activation tensor, that takes ~37 ms. Pipeline bubble scheduling must account for this hard constraint.

- **Tensor Parallel:** Intra-node TP (AllReduce at 841 GB/s) is near-optimal. If TP degree > 8 requires crossing nodes, the fall-through to AllGather+ReduceScatter at 218 GB/s is workable but ~4× slower than intra-node.

- **MoE Parallel:** At 39.8 GB/s inter-node, AllToAll is ~17× slower than intra-node (675 GB/s). Large-scale MoE with cross-node expert dispatch will be severely bandwidth-limited. Strategies: (a) constrain expert placement to single-node where possible, (b) use NVSHMEM-based or custom AllToAll that better pipelines NIC traffic, (c) increase MoE token batch size to amortize latency.
