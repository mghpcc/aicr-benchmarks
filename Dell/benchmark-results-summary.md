# MGHPCC AICR Benchmark Results Summary

**Test Date:** 2026-03-31 / 2026-04-01  
**Report Generated:** 2026-04-05

---

## Environment

| Cluster | Node Type | Count | CPU | GPU | Memory BW (Peak/GPU) | Network |
|---------|-----------|-------|-----|-----|----------------------|---------|
| **GPU1** | Dell XE7745 | 19 nodes (a0001–a0019) | 2× AMD EPYC 9575F (64C/128T) | 8× NVIDIA RTX PRO 6000 Blackwell PCIe (96 GB) | 1,597.6 GB/s | 2× ConnectX-7 NDR 400GbE (RDMA) |
| **GPU2** | Dell XE9685L | 31 nodes (b0001–b0031) | 2× AMD EPYC 9575F (64C/128T) | 8× NVIDIA B200 SXM (180 GB, HGX) | 7,672.3 GB/s | 9× ConnectX-7 NDR 400GbE (RDMA) |
| **Compute** | CPU-Only (w/x/y nodes) | 28 tested | 2× AMD EPYC 9575F (128 cores total) | — | — | — |

> **Note:** GPU1 node `a0016` was absent from all benchmark runs. GPU2 node `b0003` is currently offline.

---

## 1. HPL-MxP — GPU1 (Single Node, Mixed Precision)

**Binary:** NVIDIA HPL-MxP  
**Configuration:** N=430,080 · NB=2,048 · P=4 · Q=2 · SLOPPY-TYPE=FP16  
**Metric reported:** Total GFLOPS (all 8 GPUs), performance to report per spec  
**Nodes tested:** 18 of 19 (a0016 absent)

| Metric | Value |
|--------|-------|
| **Average** | **1,328 TFLOPS / node** (~166 TFLOPS/GPU) |
| Minimum | 1,318.7 TFLOPS (a0011) |
| Maximum | 1,333.0 TFLOPS (a0007) |
| Node-to-node spread | < 1.1% |

All 18 nodes **PASSED** residual checks.

> The LU GFLOPS (excluding iterative solver) averaged ~2,650 TFLOPS/node (~331 TFLOPS/GPU), reflecting the raw FP16 GEMM throughput.

<details>
<summary>Per-node results</summary>

| Node | TFLOPS (total) | TFLOPS/GPU |
|------|----------------|------------|
| a0001 | 1,329.1 | 166.1 |
| a0002 | 1,330.2 | 166.3 |
| a0003 | 1,330.6 | 166.3 |
| a0004 | 1,325.5 | 165.7 |
| a0005 | 1,330.5 | 166.3 |
| a0006 | 1,329.0 | 166.1 |
| a0007 | 1,333.0 | 166.6 |
| a0008 | 1,326.3 | 165.8 |
| a0009 | 1,332.5 | 166.6 |
| a0010 | 1,332.8 | 166.6 |
| a0011 | 1,318.7 | 164.8 |
| a0012 | 1,326.3 | 165.8 |
| a0013 | 1,327.7 | 166.0 |
| a0014 | 1,321.0 | 165.1 |
| a0015 | 1,328.9 | 166.1 |
| a0017 | 1,325.8 | 165.7 |
| a0018 | 1,328.0 | 166.0 |
| a0019 | 1,330.1 | 166.3 |

</details>

---

## 2. HPL — GPU2 (Single Node, FP64)

**Binary:** Standard HPL (NVIDIA HPC SDK)  
**Configuration:** N=401,408 · NB=2,048 · P=4 · Q=2  
**Metric reported:** GFLOPS (FP64)  
**Nodes tested:** 30 of 31 (b0003 offline)

| Metric | Value |
|--------|-------|
| **Average** | **272.0 TFLOPS / node** (~34.0 TFLOPS/GPU) |
| Minimum | 271.6 TFLOPS (b0012) |
| Maximum | 272.4 TFLOPS (b0004) |
| Node-to-node spread | < 0.3% |

All 30 nodes **PASSED** residual checks.

<details>
<summary>Per-node results</summary>

| Node | TFLOPS (total) | TFLOPS/GPU | Time (s) |
|------|----------------|------------|----------|
| b0001 | 271.9 | 34.0 | 158.56 |
| b0002 | 272.0 | 34.0 | 158.53 |
| b0003 | — | — | offline |
| b0004 | 272.4 | 34.1 | 158.27 |
| b0005 | 272.0 | 34.0 | 158.52 |
| b0006 | 272.2 | 34.0 | 158.39 |
| b0007 | 272.0 | 34.0 | 158.51 |
| b0008 | 271.8 | 34.0 | 158.63 |
| b0009 | 272.1 | 34.0 | 158.44 |
| b0010 | 271.9 | 34.0 | 158.56 |
| b0011 | 271.8 | 34.0 | 158.64 |
| b0012 | 271.6 | 34.0 | 158.75 |
| b0013 | 272.1 | 34.0 | 158.49 |
| b0014 | 271.8 | 34.0 | 158.65 |
| b0015 | 271.9 | 34.0 | 158.59 |
| b0016 | 271.7 | 34.0 | 158.70 |
| b0017 | 271.8 | 34.0 | 158.62 |
| b0018 | 271.9 | 34.0 | 158.57 |
| b0019 | 271.9 | 34.0 | 158.59 |
| b0020 | 272.0 | 34.0 | 158.54 |
| b0021 | 272.3 | 34.0 | 158.34 |
| b0022 | 272.0 | 34.0 | 158.52 |
| b0023 | 271.8 | 34.0 | 158.63 |
| b0024 | 272.0 | 34.0 | 158.55 |
| b0025 | 271.8 | 34.0 | 158.63 |
| b0026 | 272.1 | 34.0 | 158.50 |
| b0027 | 272.0 | 34.0 | 158.53 |
| b0028 | 272.0 | 34.0 | 158.51 |
| b0029 | 271.9 | 34.0 | 158.58 |
| b0030 | 272.0 | 34.0 | 158.50 |
| b0031 | 272.0 | 34.0 | 158.51 |

</details>

---

## 3. AMD HPL — Compute Nodes (CPU, FP64)

### 3a. Single-Node

**Binary:** AMD Zen HPL 2024-10-08 (AOCL BLIS)  
**Configuration:** N=184,900 · NB=384 · P=1 · Q=1 · OMP_NUM_THREADS=128 (1 MPI rank, 128 threads)  
**Metric reported:** GFLOPS (FP64, single-node, full dual-socket)  
**Nodes tested:** 28 (w0001–w0022, x0001–x0003, y0001–y0003)

| Metric | Value |
|--------|-------|
| **Average** | **8,763.9 GFLOPS / node** (8.8 TFLOPS) |
| Minimum | 8,614.7 GFLOPS / 8.6 TFLOPS |
| Maximum | 8,876.4 GFLOPS / 8.9 TFLOPS |
| Node-to-node spread | < 3.0% |

All 28 nodes **PASSED** residual checks.

---

### 3b. 28-Node Cluster Run

**Binary:** AMD Zen HPL 2024-10-08 (AOCL BLIS)  
**Configuration:** N=1,385,329 · NB=384 · P=4 · Q=7 · OMP_NUM_THREADS=128 (28 MPI ranks, 1 per node)  
**Metric reported:** GFLOPS (FP64, aggregate across all 28 nodes)  
**Run from:** w0001 (job 2073)

| Metric | Value |
|--------|-------|
| **Total GFLOPS** | **191,960 GFLOPS (192.0 TFLOPS)** |
| Per-node effective GFLOPS | 6,855.7 GFLOPS |
| Time | 9,233.4 seconds (~153.9 min) |
| Result | **PASSED** |

**Parallel efficiency vs. single-node baseline:**

| Metric | Value |
|--------|-------|
| Expected (28 × single-node avg) | 245,389 GFLOPS (245.4 TFLOPS) |
| Actual cluster total | 191,960 GFLOPS (192.0 TFLOPS) |
| **Parallel efficiency** | **78.2%** |
| Per-node in cluster vs. solo | 6,856 vs. 8,764 GFLOPS (−21.8%) |

> **Note:** N was increased from 978,432 to 1,385,329 (per-node memory footprint ~548 GB vs. ~274 GB previously) to improve the compute-to-communication ratio. This yielded a modest gain: +2.4% total GFLOPS (187.4 → 192.0 TFLOPS) and +1.8 pp parallel efficiency (76.4% → 78.2%). Parallel efficiency remains below the ≥85% target, suggesting MPI communication overhead — not problem sizing — is the dominant bottleneck. The next recommended step is verifying UCX/RDMA is routing over InfiniBand rather than Ethernet. The P×Q process grid (4×7) is also a candidate for further tuning.

---

## 4. NVIDIA STREAM GPU Benchmark (Single GPU, Per Node)

**Binary:** NVIDIA-STREAM 25.9.0  
**Configuration:** Array size = 1,000,000,000 elements · Device 0 only · Test type: CSAT  
**Metric reported:** MB/s per GPU (Device 0)

> Each test exercises a single GPU (Device 0) per node. Theoretical peak bandwidth listed is per-GPU.

### GPU1 — NVIDIA RTX PRO 6000 Blackwell (Theoretical Peak: 1,597.6 GB/s)

**Nodes tested:** 18 of 19 (a0016 absent)

#### FP32

| Operation | Avg (MB/s) | Min (MB/s) | Max (MB/s) | Avg % of Peak |
|-----------|-----------|-----------|-----------|---------------|
| Copy | 1,469,033 | 1,465,064 | 1,471,419 | 91.9% |
| Scale | 1,465,271 | 1,463,426 | 1,468,972 | 91.7% |
| Add | 1,483,053 | 1,481,388 | 1,484,955 | 92.8% |
| **Triad** | **1,486,218** | **1,482,536** | **1,490,645** | **93.0%** |

#### FP64

| Operation | Avg (MB/s) | Min (MB/s) | Max (MB/s) | Avg % of Peak |
|-----------|-----------|-----------|-----------|---------------|
| Copy | 1,469,951 | 1,466,228 | 1,475,653 | 92.0% |
| Scale | 1,469,264 | 1,467,089 | 1,475,658 | 91.9% |
| Add | 1,487,395 | 1,482,014 | 1,500,126 | 93.1% |
| **Triad** | **1,489,791** | **1,481,733** | **1,501,667** | **93.3%** |

---

### GPU2 — NVIDIA B200 SXM (Theoretical Peak: 7,672.3 GB/s)

**Nodes tested:** 30 of 31

#### FP32

| Operation | Avg (MB/s) | Min (MB/s) | Max (MB/s) | Avg % of Peak |
|-----------|-----------|-----------|-----------|---------------|
| Copy | 6,983,431 | 6,971,362 | 6,997,313 | 91.0% |
| Scale | 6,969,583 | 6,960,105 | 6,978,951 | 90.8% |
| Add | 7,133,155 | 7,074,404 | 7,218,063 | 93.0% |
| **Triad** | **7,178,193** | **7,070,803** | **7,232,541** | **93.6%** |

#### FP64

| Operation | Avg (MB/s) | Min (MB/s) | Max (MB/s) | Avg % of Peak |
|-----------|-----------|-----------|-----------|---------------|
| Copy | 7,093,092 | 7,062,546 | 7,101,365 | 92.5% |
| Scale | 7,093,177 | 7,081,451 | 7,101,466 | 92.5% |
| Add | 7,253,199 | 7,246,027 | 7,257,596 | 94.5% |
| **Triad** | **7,260,799** | **7,252,754** | **7,264,133** | **94.6%** |

---

## Summary Table

| Cluster | Test | Metric | Avg per Node | Notes |
|---------|------|--------|-------------|-------|
| GPU1 (XE7745) | HPL-MxP | Mixed-precision TFLOPS | 1,328 TFLOPS | 8× RTX PRO 6000; 18/19 nodes |
| GPU1 (XE7745) | STREAM FP64 Triad | GB/s (single GPU) | 1,490 GB/s | 93.3% of 1,597.6 GB/s peak |
| GPU1 (XE7745) | STREAM FP32 Triad | GB/s (single GPU) | 1,486 GB/s | 93.0% of 1,597.6 GB/s peak |
| GPU2 (XE9685L) | HPL (FP64) | TFLOPS | 272.0 TFLOPS | 8× B200 SXM; 30/31 nodes (b0003 offline) |
| GPU2 (XE9685L) | STREAM FP64 Triad | GB/s (single GPU) | 7,261 GB/s | 94.6% of 7,672.3 GB/s peak |
| GPU2 (XE9685L) | STREAM FP32 Triad | GB/s (single GPU) | 7,178 GB/s | 93.6% of 7,672.3 GB/s peak |
| Compute (w/x/y) | AMD HPL — single node (FP64) | TFLOPS/node | 8.8 TFLOPS | 128-core dual-socket; 28 nodes |
| Compute (w/x/y) | AMD HPL — 28-node cluster (FP64) | TFLOPS total | 192.0 TFLOPS | 78.2% parallel efficiency |

---

## Observations

- **GPU1 consistency:** RTX PRO 6000 Blackwell nodes show excellent node-to-node uniformity (< 1.1% spread on HPL-MxP). Node a0011 is the weakest performer but still within acceptable range.
- **GPU2 HPL coverage:** 30 of 31 B200 nodes tested (b0003 offline). All 30 show extremely consistent performance (< 0.3% spread), confirming a homogeneous cluster.
- **Memory bandwidth efficiency:** Both GPU types achieve ~93–95% of theoretical peak bandwidth on STREAM Triad — consistent with NVIDIA's published efficiency targets.
- **FP32 vs FP64 STREAM:** GPU1 shows near-identical FP32/FP64 results (expected for HBM/GDDR bandwidth). GPU2 FP64 Triad is ~1.1% higher than FP32, which is within normal variation.
- **Compute single-node performance:** The 28 CPU nodes show tight clustering (8.6–8.9 TFLOPS), consistent with AMD EPYC 9575F dual-socket expected throughput using AOCL-optimized BLIS.
- **Compute cluster parallel efficiency:** The 28-node HPL run (job 2073, N=1,385,329) achieved 192.0 TFLOPS against a 245.4 TFLOPS ideal (78.2% efficiency), up from 187.4 TFLOPS / 76.4% on the prior run (N=978,432). Increasing N improved the compute-to-communication ratio but only yielded a modest +1.8 pp gain, confirming MPI transport overhead as the dominant bottleneck. Parallel efficiency remains below the ≥85% target — the primary next step is verifying UCX/RDMA is routing over InfiniBand rather than Ethernet.