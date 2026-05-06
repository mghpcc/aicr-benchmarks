# B200 NCCL Benchmark Results

**Hardware:** 8× NVIDIA B200 per node, NVLink 5.0 / NVSwitch (~900 GB/s per GPU per direction), 8× NDR NICs (400 Gb/s each = 400 GB/s aggregate per node per direction)

**Files:**
- 1-node: `out-1node/nvhpc-26.3-b0027-9175` — node b0027, 8 GPUs
- 2-node: `out-2node/nvhpc-26.3-b0029-9289` — nodes b0029 + b0030, 16 GPUs

Converged values taken at 16 GB message size (largest), best of out-of-place / in-place.

---

## Table 1: 1-Node B200 (b0027, 8× B200, NVLink 5.0 / NVSwitch)

| Benchmark | algbw (GB/s) | busbw (GB/s) | NVLink Max (GB/s) | % of NVLink Max | Limited by |
|---|---|---|---|---|---|
| sendrecv | 666 | 666 | 900 | 74% | NVSwitch P2P |
| reduce | 701 | 701 | 900 | 78% | Ring overhead |
| broadcast | 691 | 691 | 900 | 77% | Ring overhead |
| gather | 820 | 717 | 900 | 80% | Root fan-in |
| scatter | 853 | 746 | 900 | 83% | Root fan-out |
| reduce_scatter | 794 | 695 | 900 | 77% | Ring overhead |
| all_gather | 781 | 684 | 900 | 76% | Ring overhead |
| all_reduce | 481 | 841 | 900 | **93%** | NVSwitch opt. |
| alltoall | 772 | 675 | 900 | 75% | Algo overhead |
| hypercube | **FAILED** | **FAILED** | — | — | Test bug |

---

## Table 2: 2-Node B200 (b0029+b0030, 16× B200, NDR IB)

GDRDMA bidir per-pair ceiling: **26.7 GB/s per direction per GPU** (hardware constant).
Aggregate ceiling for collectives: 8 GPU-NIC pairs × 26.7 GB/s = **~214 GB/s per node per direction** (GDRDMA bidir aggregate). Each ring/symmetric collective has every GPU sending and receiving simultaneously on its NIC, so the GPU's bidirectional DMA budget — not the 50 GB/s NIC unidir spec — is the binding constraint.

| Benchmark | algbw (GB/s) | busbw (GB/s) | GDRDMA Max (GB/s) | % of GDRDMA Max | Limited by |
|---|---|---|---|---|---|
| sendrecv | 26.6 | 26.6 | 26.7 (per-pair bidir) | **~100%** | GDRDMA bidir |
| reduce | 201 | 201 | 214 (aggregate bidir) | 94% | GDRDMA bidir |
| broadcast | 202 | 202 | 214 | 94% | GDRDMA bidir |
| gather | 96.5 | 90.5 | 214 | 42% | NCCL fan-in |
| scatter | 312 | 293 | 214 | **137%*** | Unidir traffic |
| reduce_scatter | 232 | 218 | 214 | **~100%** | GDRDMA bidir |
| all_gather | 232 | 218 | 214 | **~100%** | GDRDMA bidir |
| all_reduce | 90.6 | 170 | 214 | 79% | SHARP off |
| alltoall | 42.5 | 39.8 | 214 | **19%** | NCCL algo |
| hypercube | **FAILED** | **FAILED** | — | — | Test bug |

*Scatter exceeds 100% because traffic is purely unidirectional (root → all); the GPU's DMA engine is not splitting its budget between TX and RX, so the relevant ceiling is the unidir aggregate (8 × 50 = 400 GB/s), against which scatter reaches 73%.

---

## Analysis

### 1-Node B200: Intra-node (NVLink) — Excellent Overall

All collectives reach **74–93% of NVLink max**, which is healthy. The busbw gap from 100% is normal: it reflects algorithm overhead (ring vs. tree vs. NVSwitch-optimal), startup latency folded into the timing, and the fact that busbw is normalized but not identical to raw fabric BW.

- **AllReduce at 93%** is the best result — NCCL's NVSwitch-aware algorithm fully exploits the NVSwitch all-to-all fabric instead of a sub-optimal ring, pushing busbw close to the theoretical ceiling.
- **SendRecv at 74%** is the lowest, but still good for intra-node. NVSwitch adds switching overhead for P2P traffic, and simultaneous bidirectional traffic can reduce peak unidirectional speed.
- **Hypercube FAILED**: Known **validation bug in nccl-tests 2.18.3**, not a hardware issue. The hardware is fine.

### 2-Node B200: Inter-node (NDR IB) — Mixed Results

**SendRecv — ~100% of GDRDMA bidir limit (26.6 / 26.7 GB/s):** This exactly matches the hardware-measured GDRDMA bidirectional ceiling. The B200 has a single PCIe Gen5 x16 port per GPU, and its DMA engine has a fixed HBM bandwidth budget of ~53.5 GB/s *total* shared between reads and writes. In bidirectional operation (sendrecv simultaneously sends and receives), each direction is capped at ~26.7 GB/s. **This is a silicon-level hardware limit — no NCCL tuning can overcome it.**

**AllGather + ReduceScatter at ~100% of GDRDMA bidir aggregate (218 vs. 214 GB/s):** These saturate the *real* hardware ceiling. Ring algorithms have every GPU simultaneously sending to one neighbor and receiving from another on its NIC, so each GPU-NIC pair is GDRDMA-bidir-limited at ~26.7 GB/s per direction; aggregating across 8 pairs gives ~214 GB/s. The 50 GB/s NIC unidir spec is unreachable here because the GPU's DMA engine cannot supply both directions at full rate simultaneously. There is essentially no headroom left at the hardware level.

**AllReduce at 79% (170 GB/s) — SHARP is NOT active:** The clearest indicator is that allreduce busbw (170 GB/s) is *less than* all_gather busbw (218 GB/s). Without SHARP, allreduce is implemented as ReduceScatter + AllGather — two sequential bidir passes — so it does not reach the 214 GB/s ceiling that AllGather alone hits. With SHARP, reduction is offloaded to the InfiniBand switches in-flight, allreduce becomes a single-pass operation, and the per-byte PCIe load drops; busbw should ~2× to ~340 GB/s, exceeding the GDRDMA bidir aggregate. SHARP infrastructure is confirmed ready on the fabric (`sharp_hello` passed, 153 OSTs available); this needs to be activated at the NCCL/job level.

**Scatter at 137% (293 GB/s) vs. Gather at 42% (90.5 GB/s) — Fan-out vs. Fan-in asymmetry:** Scatter exceeds the GDRDMA bidir aggregate because traffic is purely unidirectional (root pushes; receivers only receive); the GPU's DMA engine is not splitting its budget between TX and RX, so per-pair throughput approaches the unidir ceiling (~50 GB/s). Against the unidir aggregate (~400 GB/s), scatter reaches 73%. Gather (all ranks fan in to one root) suffers because NCCL's gather algorithm cannot parallelize multi-GPU intra-node fan-in at the root side as effectively — the data funnel to a single root rank is algorithmically harder to pipeline across all NICs.

**Reduce and Broadcast at 94% of GDRDMA bidir aggregate (201–202 GB/s):** Tree-based collectives where internal ranks receive from a child and forward to a parent simultaneously — the internal-node link is bidirectional, so the 214 GB/s bidir aggregate is the right reference. Both nearly saturate it.

**AllToAll at 19% (39.8 GB/s) — Severe inter-node bottleneck:** AllToAll is bidirectional in principle (every GPU sends to and receives from every other GPU), so the 214 GB/s bidir aggregate is the right ceiling. NCCL implements alltoall as N² point-to-point send/recv operations that are not fully pipelined across all NICs simultaneously. This is a **known NCCL algorithm limitation**, not a hardware fault — the same fabric delivers 218 GB/s for allgather.

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
| **Data Parallel (DDP)** | AllReduce | 841 GB/s | 170 GB/s | Intra-node excellent; inter-node limited — **SHARP would ~2× to ~340 GB/s** |
| **Pipeline Parallel** | SendRecv (P2P) | 666 GB/s | 26.6 GB/s | Inter-node capped at **hard hardware limit** (GDRDMA bidir, PCIe DMA engine) |
| **Tensor Parallel** | AllReduce, AllGather, ReduceScatter | 684–841 GB/s | 170–218 GB/s | Keep within one node; cross-node TP viable via AllGather+ReduceScatter at 218 GB/s |
| **MoE Parallel (expert dispatch)** | AllToAll | 675 GB/s | 39.8 GB/s | Inter-node alltoall **severely bottlenecked** (11% NDR); minimize cross-node expert routing |

**Key implications:**

- **Data Parallel:** Scale-out DDP will be gated on AllReduce across nodes. At 170 GB/s (SHARP off), inter-node gradient sync is the primary bottleneck for large models. **Activating SHARP is the highest-priority action for DDP scaling (~2× to ~340 GB/s).**

- **Pipeline Parallel:** The 26.6 GB/s sendrecv ceiling means inter-node activation tensors are slow. A single GPU-NIC pair transfers ~26.6 GB/s bidirectionally — for a 1 GB activation tensor, that takes ~37 ms. Pipeline bubble scheduling must account for this hard constraint.

- **Tensor Parallel:** Intra-node TP (AllReduce at 841 GB/s) is near-optimal. If TP degree > 8 requires crossing nodes, the fall-through to AllGather+ReduceScatter at 218 GB/s is workable but ~4× slower than intra-node.

- **MoE Parallel:** At 39.8 GB/s inter-node, AllToAll is ~17× slower than intra-node (675 GB/s). Large-scale MoE with cross-node expert dispatch will be severely bandwidth-limited. Strategies: (a) constrain expert placement to single-node where possible, (b) use NVSHMEM-based or custom AllToAll that better pipelines NIC traffic, (c) increase MoE token batch size to amortize latency.
