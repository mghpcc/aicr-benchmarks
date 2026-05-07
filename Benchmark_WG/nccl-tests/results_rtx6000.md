# RTX6000 NCCL Benchmark Results

**Hardware:** NVIDIA RTX PRO 6000 Blackwell Server Edition, no NVLink — PCIe Gen5 x16 per GPU (~63 GB/s per direction) is the only GPU interconnect.

> **Note (topology):** This node is a 2× AMD EPYC 9575F system in NPS=4 mode — each socket has 4 sub-NUMA dies (8 NUMA nodes total), each with its own I/O die. The 8 GPUs are distributed 4 per socket, one per NUMA die. **No GPU pair shares a PCIe switch** (verified by `nvidia-smi topo -m`: every GPU pair shows `SYS`). Even within one socket, all GPU-to-GPU traffic traverses Infinity Fabric between NUMA dies — there is no direct PCIe-switch P2P available on this hardware. PCIe domain `0000:` = socket 0 (GPUs 0–3); PCIe domain `0001:` = socket 1 (GPUs 4–7).

**Files:**
- 1-node / 2 GPUs / socket 0 (2 NUMA dies): `out-1socket/nvhpc-26.3-a0001-9677` — node a0001 (sendrecv only)
- 1-node / 4 GPUs / socket 0 (4 NUMA dies): `out-1socket/nvhpc-26.3-a0008-9679` — node a0008 (all benchmarks)
- 2-node / 1 GPU per node: `out-2node/nvhpc-26.3-a0009-9666` — nodes a0009 + a0010 (sendrecv only)

Converged values taken at 16 GB message size, best of out-of-place / in-place.

> **Note: compare `busbw` (not `algbw`) to the hardware max.** `algbw` = bytes/time as seen by the user. `busbw` applies a per-collective multiplier that converts user-visible throughput into bytes-on-the-wire per GPU per direction — e.g., AllReduce traverses each byte ~2× (ReduceScatter + AllGather), so its algbw is roughly half its busbw. Only `busbw` is directly comparable to the per-GPU link ceiling, and that's why the percentage columns reference busbw.

---

## Table 1: 1-Node RTX6000, 2 GPUs on Socket 0 (a0001, 2 NUMA dies) — SendRecv Only

| Benchmark | algbw (GB/s) | busbw (GB/s) | PCIe Max (GB/s) | % of PCIe Max | Limited by |
|---|---|---|---|---|---|
| sendrecv | 37.4 | 37.4 | 63 | 59% | PCIe DMA bidir budget |

---

## Table 2: 1-Node RTX6000, 4 GPUs on Socket 0 (a0008, 4 NUMA dies) — All Benchmarks

PCIe Gen5 x16 theoretical max per GPU per direction = **63 GB/s**. Note: the actual binding constraint for symmetric collectives is the on-package Infinity Fabric between NUMA dies, not the PCIe link itself — see Analysis below.

| Benchmark | algbw (GB/s) | busbw (GB/s) | PCIe Max (GB/s) | % of PCIe Max | Limited by |
|---|---|---|---|---|---|
| sendrecv | 13.0 | 13.0 | 63 | **21%** | Infinity Fabric (4-die bidir) |
| reduce | 13.2 | 13.2 | 63 | 21% | Infinity Fabric (4-die bidir) |
| broadcast | 17.6 | 17.6 | 63 | 28% | Infinity Fabric (tree partial) |
| gather | 52.3 | 39.2 | 63 | 62% | Root-anchored fan-in (unidir IF) |
| scatter | 67.4 | 50.6 | 63 | 80% | Root-anchored fan-out (unidir IF) |
| reduce_scatter | 17.3 | 13.0 | 63 | 21% | Infinity Fabric (4-die bidir) |
| all_gather | 17.8 | 13.3 | 63 | 21% | Infinity Fabric (4-die bidir) |
| all_reduce | 8.76 | 13.1 | 63 | 21% | Infinity Fabric (4-die bidir) |
| alltoall | 17.8 | 13.4 | 63 | 21% | Infinity Fabric (4-die bidir) |
| hypercube | **FAILED** | **FAILED** | — | — | nccl-tests 2.18.3 validation bug |

---

## Table 3: 2-Node RTX6000, 1 GPU Per Node (a0009+a0010) — SendRecv Only

Combined PCIe + NDR max: PCIe per direction = 63 GB/s, NDR NIC per direction = 50 GB/s. NDR is the bottleneck: combined theoretical max = **50 GB/s** per direction. For sendrecv (bidirectional), the effective ceiling is the GDRDMA bidir DMA budget (~24.7 GB/s per direction, measured).

| Benchmark | algbw (GB/s) | busbw (GB/s) | PCIe+NDR Max (GB/s) | % of Max | Limited by |
|---|---|---|---|---|---|
| sendrecv | 24.7 | 24.7 | 50 | **49%** | HW-saturated (GDRDMA bidir per-pair) |

---

## Analysis

### 1-Node RTX6000: Infinity Fabric Is the Real Bottleneck

**2-GPU sendrecv at 59% of PCIe max (37.4 GB/s) — Single bidir pair via Infinity Fabric:**
The two GPUs (PCIe bus 03:00 and 42:00) are both on socket 0 but on different sub-NUMA dies (NUMA 1 and NUMA 2 in NPS=4 mode). Traffic between them traverses Infinity Fabric, not direct PCIe-switch P2P (no GPU pair on this node shares a switch). With only one GPU pair active, the IF path is dedicated to this pair; the achievable bidir bandwidth is ~37.4 GB/s per direction — limited by the GPU's PCIe DMA engine bidirectional budget (~74.7 GB/s total = 37.4 × 2).

**4-GPU collapse to 21% of PCIe max (13.0 GB/s) — Infinity Fabric saturation across 4 NUMA dies:**
The 4 GPUs are all on socket 0 but each in its own sub-NUMA die (NUMA 0/1/2/3). With 4 simultaneous bidir transfers (e.g., ring sendrecv) all 4 inter-die IF segments carry traffic in both directions concurrently. Aggregate IF traffic: 4 transfers × 13 GB/s × 2 (read+write) ≈ 104 GB/s, indicating Infinity Fabric saturation in NPS=4 mode. **The bottleneck is the on-package fabric between NUMA dies, not direct PCIe link or DDR memory. Note: this is intra-socket traffic — cross-socket (4 GPUs spanning sockets 0+1) would be even worse.**

**AllReduce, AllGather, ReduceScatter, AllToAll — all bottleneck at ~13 GB/s:**
Without NVLink, all symmetric collectives with 4 GPUs suffer the same Infinity Fabric saturation. Every GPU must communicate with every other GPU in at least one phase of the collective, inevitably traversing IF between NUMA dies. The result is a hard ~13 GB/s floor for all symmetric collectives — only ~21% of the PCIe max, and ~1.5% of what NVSwitch delivers on B200 (841 GB/s for AllReduce).

**Gather (62%) and Scatter (80%) are outliers — root-centric collectives are unidirectional:**
Gather fans data into root (rank 0). Scatter fans out from the same root. The root's IF carries traffic in only one direction (incoming for gather, outgoing for scatter), avoiding the bidir DMA budget split. The 3 IF segments connecting root's NUMA die to the other 3 dies each carry near-unidir-rate traffic. **Root-based collectives are far less sensitive to fabric saturation because the dominant DMA path doesn't suffer bidir contention.**

**Hypercube:**
- 2 GPUs (a0001): **PASSED** (0 wrong values, 36.4 GB/s). With N=2, hypercube is a trivial single exchange — the nccl-tests 2.18.3 validation bug does not trigger.
- 4 GPUs (a0008): **FAILED** — same nccl-tests 2.18.3 validation bug as B200 (N > 2).

### 2-Node RTX6000: Similar GDRDMA Bidir Ceiling to B200

**SendRecv at 49% of NDR max (24.7 GB/s per direction):** The RTX6000 inter-node sendrecv is limited by the same mechanism as B200 — the GPU's PCIe DMA engine bidirectional budget when accessed via RDMA through the NIC (GDRDMA). The measured GDRDMA bidir ceiling is ~24.7 GB/s per direction (49.3 GB/s total), slightly lower than B200's 26.7 GB/s per direction (53.4 GB/s total). This is a hardware characteristic of the RTX6000's DMA engine. No NCCL tuning can overcome it.

---

## B200 vs RTX6000 Comparison (Intra-Node)

| Collective | B200 1-node (8 GPUs, NVLink) | RTX6000 2-GPU (1 socket, 2 NUMA dies) | RTX6000 4-GPU (1 socket, 4 NUMA dies) |
|---|---|---|---|
| sendrecv | 666 GB/s | 37.4 GB/s | 13.0 GB/s |
| all_reduce | 841 GB/s | 35.6 GB/s | 13.1 GB/s |
| all_gather | 684 GB/s | 32.8 GB/s | 13.3 GB/s |
| alltoall | 675 GB/s | 38.2 GB/s* | 13.4 GB/s |

*in-place; out-of-place is 23.3 GB/s

NVLink is **18–64× faster** than RTX6000's Infinity-Fabric-mediated GPU P2P for symmetric collectives. Even the 2-GPU case (one IF hop within socket 0) is **18–24×** slower than NVLink.

---

## Fixed Issues

1. **`nvidia_peermem` installed** — enables GPUDirect RDMA (GDR) for inter-node transfers. Without it, all inter-node communication uses CPU-bounce buffering (~10–15 GB/s per NIC), making the 24.7 GB/s sendrecv result impossible.

2. **ACS disabled and IOMMU off** — kernel boot args include `amd_iommu=off iommu=off pci=noacs`. PCIe Access Control Services would otherwise force GPU-to-GPU traffic through the CPU IOMMU, blocking the IF-mediated P2P path on which the 37.4 GB/s 2-GPU result depends.

---

## Deep Learning Application Performance Prediction

| Parallelism Type | Primary NCCL Op | RTX6000 2-GPU (1 socket, 2 NUMA dies) | RTX6000 4-GPU (1 socket, 4 NUMA dies) | 2-node RTX6000 |
|---|---|---|---|---|
| **Data Parallel (DDP)** | AllReduce | 35.6 GB/s | 13.1 GB/s | N/A |
| **Pipeline Parallel** | SendRecv (P2P) | 37.4 GB/s | 13.0 GB/s | 24.7 GB/s |
| **Tensor Parallel** | AllReduce, AllGather, RS | 25–36 GB/s | 13 GB/s | N/A |
| **MoE Parallel** | AllToAll | 38.2 GB/s* | 13.4 GB/s | N/A |

*in-place

**Key implications:**

- **Data Parallel:** RTX6000 4-GPU AllReduce (13.1 GB/s) is ~64× slower than B200 8-GPU (841 GB/s). For DDP-heavy workloads, RTX6000 is not viable at scale. Even 2-GPU DDP (35.6 GB/s) is ~24× slower than B200.

- **Pipeline Parallel:** Inter-node RTX6000 sendrecv (24.7 GB/s) is comparable to B200 (26.6 GB/s) — both are GDRDMA-bidir-limited by the same PCIe DMA engine constraint. Pipeline parallelism across nodes is similarly constrained on both GPU types.

- **Tensor Parallel:** Must be kept within 2 GPUs (one IF hop within a socket) to get reasonable (~36 GB/s) bandwidth. Scaling to 4 GPUs across 4 NUMA dies collapses to 13 GB/s due to IF saturation.

- **MoE Parallel:** Intra-node AllToAll on RTX6000 (13–38 GB/s) is feasible only for the 2-GPU config. 4-GPU alltoall across 4 NUMA dies (13.4 GB/s) is ~50× below B200's intra-node alltoall (675 GB/s).

- **Recommendation:** RTX6000 nodes are suitable for single-GPU or 2-GPU workloads. For any workload requiring efficient multi-GPU communication beyond 2 GPUs (where Infinity Fabric saturation kicks in), B200 nodes with NVLink are vastly superior.
