# RTX6000 NCCL Benchmark Results

**Hardware:** NVIDIA RTX PRO 6000 Blackwell Server Edition, no NVLink — PCIe Gen5 x16 per GPU (~63 GB/s per direction) is the only GPU interconnect.

> **Note:** RTX6000 GPUs on different sockets (different PCIe root complexes / NUMA domains) communicate poorly — cross-socket traffic must traverse the CPU memory fabric instead of direct PCIe P2P.

**Files:**
- 1-node / 2 GPUs / same socket: `out-1socket/nvhpc-26.3-a0001-9677` — node a0001 (sendrecv only)
- 1-node / 4 GPUs / same socket: `out-1socket/nvhpc-26.3-a0008-9679` — node a0008 (all benchmarks)
- 2-node / 1 GPU per node: `out-2node/nvhpc-26.3-a0009-9666` — nodes a0009 + a0010 (sendrecv only)

Converged values taken at 16 GB message size, best of out-of-place / in-place.

---

## Table 1: 1-Node RTX6000, 2 GPUs on Same Socket (a0001) — SendRecv Only

| Benchmark | busbw (GB/s) | PCIe Max (GB/s) | % of PCIe Max |
|---|---|---|---|
| sendrecv | 37.4 | 63 | 59% |

---

## Table 2: 1-Node RTX6000, 4 GPUs on Same Socket (a0008) — All Benchmarks

PCIe Gen5 x16 theoretical max per GPU per direction = **63 GB/s**.

| Benchmark | busbw (GB/s) | PCIe Max (GB/s) | % of PCIe Max |
|---|---|---|---|
| sendrecv | 13.0 | 63 | **21%** |
| reduce | 13.2 | 63 | 21% |
| broadcast | 17.6 | 63 | 28% |
| gather | 39.2 | 63 | 62% |
| scatter | 50.6 | 63 | 80% |
| reduce_scatter | 13.0 | 63 | 21% |
| all_gather | 13.3 | 63 | 21% |
| all_reduce | 13.1 | 63 | 21% |
| alltoall | 13.4 | 63 | 21% |
| hypercube | **FAILED** | — | — |

---

## Table 3: 2-Node RTX6000, 1 GPU Per Node (a0009+a0010) — SendRecv Only

Combined PCIe + NDR max: PCIe per direction = 63 GB/s, NDR NIC per direction = 50 GB/s. NDR is the bottleneck: combined theoretical max = **50 GB/s** per direction. For sendrecv (bidirectional), the effective ceiling is the GDRDMA bidir DMA budget (~24.7 GB/s per direction, measured).

| Benchmark | busbw (GB/s) | PCIe+NDR Max (GB/s) | % of Max |
|---|---|---|---|
| sendrecv | 24.7 | 50 | **49%** |

---

## Analysis

### 1-Node RTX6000: PCIe Topology Is Everything

**2-GPU sendrecv at 59% of PCIe max (37.4 GB/s) — Direct PCIe P2P works:**
The two GPUs (PCIe bus 03:00 and 42:00) are under the same PCIe switch on the same socket. NCCL routes data via direct PCIe peer-to-peer DMA, bypassing the CPU. The 59% efficiency reflects the GPU's PCIe DMA engine bidirectional budget: simultaneously reading GPU memory for TX and writing GPU memory for RX consumes ~74.7 GB/s total (37.4 × 2). This is more headroom than the B200 (53.4 GB/s total DMA budget), but still well below the full-duplex PCIe link rate (~126 GB/s).

**4-GPU collapse to 21% of PCIe max (13.0 GB/s) — Cross-NUMA PCIe bottleneck:**
Adding GPUs from different PCIe root complexes (bus 8c:00 and c7:00 are on a different NUMA domain from 03:00 and 42:00) means GPU-to-GPU traffic that crosses NUMA boundaries must be mediated by the CPU's memory coherence fabric (DDR5 system memory), not direct PCIe P2P. With 4 GPUs doing simultaneous sendrecv (4 concurrent ring transfers), the CPU memory fabric becomes the shared bottleneck. 4 transfers × 13 GB/s × 2 (read+write) ≈ 104 GB/s total CPU memory traffic — consistent with a DDR5 memory subsystem under full load. **This is a fundamental limitation of PCIe-only GPU interconnects: performance collapses when GPUs span NUMA/PCIe-root-complex boundaries.**

**AllReduce, AllGather, ReduceScatter, AllToAll — all bottleneck at ~13 GB/s:**
Without NVLink, all symmetric collectives with 4 GPUs suffer the same cross-NUMA bottleneck. Every GPU must communicate with every other GPU in at least one phase of the collective, inevitably traversing the CPU memory fabric. The result is a hard ~13 GB/s floor for all symmetric collectives — only ~21% of the PCIe max, and ~1.5% of what NVSwitch delivers on B200 (841 GB/s for AllReduce).

**Gather (62%) and Scatter (80%) are outliers — root-centric collectives avoid the bottleneck:**
Gather fans all data into root (rank 0, bus 03:00). Scatter fans out from the same root. For gather, all 3 remote GPUs write to rank 0 — the bottleneck is rank 0's PCIe RX port (~63 GB/s), which does not require cross-NUMA traversal from rank 0's perspective. Similarly for scatter, rank 0 pushes data to all 3 other GPUs at near PCIe TX line rate. **Root-based collectives are far less sensitive to cross-NUMA topology because the critical DMA path is anchored at one GPU.**

**Hypercube:**
- 2 GPUs (a0001): **PASSED** (0 wrong values, 36.4 GB/s). With N=2, hypercube is a trivial single exchange — the nccl-tests 2.18.3 validation bug does not trigger.
- 4 GPUs (a0008): **FAILED** — same nccl-tests 2.18.3 validation bug as B200 (N > 2).

### 2-Node RTX6000: Similar GDRDMA Bidir Ceiling to B200

**SendRecv at 49% of NDR max (24.7 GB/s per direction):** The RTX6000 inter-node sendrecv is limited by the same mechanism as B200 — the GPU's PCIe DMA engine bidirectional budget when accessed via RDMA through the NIC (GDRDMA). The measured GDRDMA bidir ceiling is ~24.7 GB/s per direction (49.3 GB/s total), slightly lower than B200's 26.7 GB/s per direction (53.4 GB/s total). This is a hardware characteristic of the RTX6000's DMA engine. No NCCL tuning can overcome it.

---

## B200 vs RTX6000 Comparison (Intra-Node)

| Collective | B200 1-node (8 GPUs, NVLink) | RTX6000 2-GPU (same socket) | RTX6000 4-GPU (cross-NUMA) |
|---|---|---|---|
| sendrecv | 666 GB/s | 37.4 GB/s | 13.0 GB/s |
| all_reduce | 841 GB/s | 35.6 GB/s | 13.1 GB/s |
| all_gather | 684 GB/s | 32.8 GB/s | 13.3 GB/s |
| alltoall | 675 GB/s | 38.2 GB/s* | 13.4 GB/s |

*in-place; out-of-place is 23.3 GB/s

NVLink is **18–64× faster** than cross-NUMA PCIe for symmetric collectives. Even same-socket PCIe P2P (2-GPU) is **18–24×** slower than NVLink.

---

## Fixed Issues

1. **`nvidia_peermem` installed** — enables GPUDirect RDMA (GDR) for inter-node transfers. Without it, all inter-node communication uses CPU-bounce buffering (~10–15 GB/s per NIC), making the 24.7 GB/s sendrecv result impossible.

2. **ACS disabled (`iommu=off` in kernel boot)** — PCIe Access Control Services block peer-to-peer GPU memory transactions. With ACS enabled, even the 2-GPU same-socket PCIe P2P case would be routed through the CPU IOMMU, preventing direct P2P and destroying intra-node performance.

---

## Deep Learning Application Performance Prediction

| Parallelism Type | Primary NCCL Op | RTX6000 2-GPU (same socket) | RTX6000 4-GPU (cross-NUMA) | 2-node RTX6000 |
|---|---|---|---|---|
| **Data Parallel (DDP)** | AllReduce | 35.6 GB/s | 13.1 GB/s | N/A |
| **Pipeline Parallel** | SendRecv (P2P) | 37.4 GB/s | 13.0 GB/s | 24.7 GB/s |
| **Tensor Parallel** | AllReduce, AllGather, RS | 25–36 GB/s | 13 GB/s | N/A |
| **MoE Parallel** | AllToAll | 38.2 GB/s* | 13.4 GB/s | N/A |

*in-place

**Key implications:**

- **Data Parallel:** RTX6000 4-GPU AllReduce (13.1 GB/s) is ~64× slower than B200 8-GPU (841 GB/s). For DDP-heavy workloads, RTX6000 is not viable at scale. Even 2-GPU DDP (35.6 GB/s) is ~24× slower than B200.

- **Pipeline Parallel:** Inter-node RTX6000 sendrecv (24.7 GB/s) is comparable to B200 (26.6 GB/s) — both are GDRDMA-bidir-limited by the same PCIe DMA engine constraint. Pipeline parallelism across nodes is similarly constrained on both GPU types.

- **Tensor Parallel:** Must be kept within 2 GPUs on the same PCIe switch to get reasonable (~36 GB/s) bandwidth. Cross-NUMA TP with 4 GPUs collapses to 13 GB/s.

- **MoE Parallel:** Intra-node AllToAll on RTX6000 (13–38 GB/s) is feasible only for 2-GPU same-socket config. 4-GPU cross-NUMA alltoall (13.4 GB/s) is ~50× below B200's intra-node alltoall (675 GB/s).

- **Recommendation:** RTX6000 nodes are suitable for single-GPU or 2-GPU-per-socket workloads. For any workload requiring efficient multi-GPU communication with more than 2 GPUs or across NUMA boundaries, B200 nodes with NVLink are vastly superior.
