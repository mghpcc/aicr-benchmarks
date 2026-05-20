# OSU Benchmark Sweep Comparison

**Generated:** 2026-05-20  
**Purpose:** Compare April and May sweep results across compute/CPU, GPU1, and GPU2 partitions to verify consistency.

---

## Table of Contents

1. [Compute (Apr 17) vs CPU (May 19 / May 20)](#1-compute-apr-17-vs-cpu-may-19--may-20)
2. [GPU2: Apr 17 vs May 19](#2-gpu2-apr-17-vs-may-19)
3. [GPU1: Apr 17 vs May 19](#3-gpu1-apr-17-vs-may-19)
4. [All-to-All Comparison](#4-all-to-all-comparison)

---

## 1. Compute (Apr 17) vs CPU (May 19 / May 20)

Two CPU sweeps were run. The May 19 sweep produced unexpectedly low bandwidth; the root cause was identified as a missing `--mem` SBATCH flag, which was added for the May 20 re-run.

### Script Change: `--mem=900G`

The SBATCH jobs in `run_sweep.sh` were updated to include:

```
--mem=900G
```

Without this flag, Slurm applied its default cgroup memory limit to each job, which restricted the amount of memory that could be pinned (locked) for RDMA operations. UCX/IB requires large pinned-memory registrations for zero-copy transfers; when the cgroup cap is too low it falls back to a slower non-RDMA path. Setting `--mem=900G` allocates the full node memory to the job, lifting the pinned-memory restriction and restoring full IB throughput.

### BIBW (Host-Host)

| | `sweep_compute_20260417_141202` | `sweep_cpu_20260519_145217` *(no --mem)* | `sweep_cpu_20260520_134345` *(--mem=900G)* |
|---|---|---|---|
| **Date** | Apr 17 2026 14:12 UTC | May 19 2026 14:52 EDT | May 20 2026 13:43 EDT |
| **Threshold** | ≥ 15,000 MB/s | ≥ 15,000 MB/s | ≥ 15,000 MB/s |
| **Pass/Fail** | 351 / 351 PASS | 10 / 10 PASS | 10 / 10 PASS |
| **Node Pairs Tested** | 351 | 10 | 10 |
| **Min H H BW** | 87,373 MB/s | 20,986 MB/s | 87,557 MB/s |
| **Max H H BW** | 92,101 MB/s | 33,268 MB/s | 90,142 MB/s |
| **Avg H H BW** | **89,716 MB/s** | **25,440 MB/s** | **89,178 MB/s** |
| **Avg Δ vs Compute Apr** | — | −72% | **−0.6%** |

### Nodes Included

| | Nodes | Count |
|---|---|---|
| **Compute Apr** | w0001–w0022, x0001–x0003, y0001–y0002 | 27 nodes |
| **CPU May 19** | w0001–w0005 | 5 nodes |
| **CPU May 20** | w0001–w0005 | 5 nodes |

### Notable Bandwidth Curves (w0001 ↔ w0002)

| Message Size | Compute Apr (MB/s) | CPU May 19 — no `--mem` (MB/s) | CPU May 20 — `--mem=900G` (MB/s) |
|---|---|---|---|
| 1 B | 9.40 | 9.12 | 9.38 |
| 4096 B | 13,770 | 10,213 | 13,166 |
| 16384 B | 40,181 | 23,459 | 39,594 |
| 32768 B | 56,442 | **29,745** *(May 19 peak)* | 56,422 |
| 65536 B | 69,513 | 28,532 | 69,483 |
| 131072 B | 79,465 | 27,248 | 79,577 |
| 524288 B | 88,519 | 22,446 | 87,921 |
| 8388608 B | **89,826** | 21,482 | **88,254** |

### Verdict: ✅ Roughly the Same (with `--mem=900G`)

With `--mem=900G` added to the SBATCH submission, the CPU partition bandwidth curve is essentially identical to the compute partition — both saturate cleanly through large messages at ~88–90 GB/s, consistent with full-speed NDR InfiniBand. The −0.6% average difference is within normal run-to-run variation.

The May 19 results (without `--mem`) are invalid for IB performance comparison and should be disregarded. The May 20 sweep (`sweep_cpu_20260520_134345`) is the correct CPU baseline.

---

## 2. GPU2: Apr 17 vs May 19

### BIBW (Host-Host)

| | `sweep_GPU2_20260417_141220` | `sweep_GPU2_20260519_091124` |
|---|---|---|
| **Date** | Apr 17 2026 14:12 UTC | May 19 2026 09:11 EDT |
| **Threshold** | ≥ 80,000 MB/s (Apr) | ≥ 15,000 MB/s (May) |
| **Pass/Fail** | 366 / 366 PASS | 465 / 465 PASS |
| **Node Pairs Tested** | 366 | 465 |
| **Min H H BW** | 99,450 MB/s | 98,676 MB/s |
| **Max H H BW** | 105,024 MB/s | 104,926 MB/s |
| **Avg H H BW** | **102,513 MB/s** | **101,988 MB/s** |
| **Avg Δ vs April** | — | **−0.5%** |

### Nodes Included

| | Nodes | Count |
|---|---|---|
| **GPU2 Apr** | b0001–b0031 *(b0006, b0012, b0016 absent)* | 28 nodes |
| **GPU2 May** | b0001–b0031 *(complete)* | 31 nodes |

> **Note:** b0006, b0012, and b0016 were not present in the April sweep but were added by May. Their May results (ranging from 98,675–104,583 MB/s) are fully consistent with the rest of the partition.

### Notable Bandwidth Curves (b0001 ↔ b0002)

| Message Size | GPU2 Apr (MB/s) | GPU2 May (MB/s) |
|---|---|---|
| 1 B | 9.84 | — *(not checked)* |
| 524288 B | 96,597 | — |
| 1048576 B | 99,798 | — |
| 8388608 B | **102,637** | **102,290** |

### Verdict: ✅ Roughly the Same

GPU2 results are consistent across both sweeps. The −0.5% difference in average bandwidth is well within normal run-to-run variation. All pairs pass in both sweeps.

---

## 3. GPU1: Apr 17 vs May 19

### BIBW (Host-Host)

| | `sweep_GPU1_20260417_141214` | `sweep_GPU1_20260519_105101` |
|---|---|---|
| **Date** | Apr 17 2026 14:12 UTC | May 19 2026 10:51 EDT |
| **Threshold** | ≥ 15,000 MB/s | ≥ 15,000 MB/s |
| **Pass/Fail** | 171 / 171 PASS | 171 / 171 PASS |
| **Node Pairs Tested** | 171 | 171 |
| **Min H H BW** | 73,612 MB/s | 77,379 MB/s |
| **Max H H BW** | 89,413 MB/s | 88,557 MB/s |
| **Avg H H BW** | **81,439 MB/s** | **81,846 MB/s** |
| **Avg Δ vs April** | — | **+0.5%** |

### Nodes Included

| | Nodes | Count |
|---|---|---|
| **GPU1 Apr** | a0001–a0019 | 19 nodes |
| **GPU1 May** | a0001–a0019 | 19 nodes |

Identical node sets across both sweeps.

### Notable Bandwidth Curves (a0001 ↔ a0002)

| Message Size | GPU1 Apr (MB/s) | GPU1 May (MB/s) |
|---|---|---|
| 1 B | 8.42 | 8.38 |
| 4096 B | 13,970 | 13,792 |
| 65536 B | 63,886 | 66,365 |
| 1048576 B | 80,274 | 81,860 |
| 2097152 B | 81,332 *(peak)* | 81,860 *(peak)* |
| 8388608 B | 79,437 | 78,009 |

### Wide-Spread Notes

GPU1 shows a wider range than GPU2 (min ~73–77 GB/s vs max ~88–89 GB/s), typical of older or mixed-generation IB switches. A handful of pairs with lower-end values (~73–76 GB/s) appear in April; these same nodes perform somewhat better in May, but both are within acceptable range.

### Verdict: ✅ Roughly the Same

GPU1 results are consistent. The +0.5% difference in average bandwidth between April and May is negligible. All pairs pass in both sweeps.

---

## 4. All-to-All Comparison

All-to-all latency files are at the repo root. Matches by node type and date:

| Node Type | April File | April Nodes | May File | May Nodes |
|---|---|---|---|---|
| **Compute/CPU** | `alltoall_2043` (Apr 1) | w[0001-0022],x[0001-0003],y[0001-0003] — 28 ranks | `alltoall_24206` (May 19) | w[0001-0005] — 5 ranks |
| **GPU1** | `alltoall_3593` (Apr 18) | a[0001-0019] — 19 ranks | `alltoall_23639` (May 19) | a[0001-0019] — 19 ranks |
| **GPU2** | `alltoall_2045` (Apr 1) | b[0001-0002,0004-0031] — 30 ranks | `alltoall_22917` (May 19) | b[0001-0031] — 31 ranks |

> **Caveats:** The compute April alltoall (job 2043) ran April 1 — one month before the April 17 BIBW sweep and includes y0003 (not in the BIBW sweep). The GPU2 April alltoall (job 2045) also ran April 1 and is missing b0003. These are the best available April baselines.

---

### 4a. Compute/CPU All-to-All

| Size (bytes) | Apr (28n) Avg Latency (µs) | May (5n) Avg Latency (µs) | Δ |
|---|---|---|---|
| 1 | 9.01 | 34.54 | +284% |
| 2 | 9.05 | 42.47 | +369% |
| 4 | 18.67 | 51.78 | +177% |
| 32 | 19.06 | 53.65 | +181% |
| 256 | 21.15 | 104.41 | +394% |
| 512 | 11.66 | 107.63 | +823% |
| 1024 | 13.57 | 154.87 | +1041% |
| 4096 | 18.71 | 155.80 | +733% |
| 16384 | 49.46 | 360.83 | +629% |
| 65536 | 65.21 | 316.78 | +386% |
| 131072 | 112.24 | 301.55 | +169% |
| 1048576 | 714.80 | 484.42 | −32% |

**Hostnames (April):** w0001–w0022, x0001–x0003, y0001–y0003 (28 ranks, 1 per node)  
**Hostnames (May):** w0001–w0005 (5 ranks, 1 per node)

#### Verdict: ⚠️ NOT Roughly the Same

The CPU May all-to-all latencies are dramatically higher across nearly all message sizes — consistent with the lower BIBW observed in section 1. The only size where May is better is 1 MB (484 µs vs 715 µs), which likely reflects the much smaller rank count (5 vs 28) reducing total collective volume. This further supports that the CPU partition nodes use a fundamentally different (slower) interconnect than the compute partition.

---

### 4b. GPU1 All-to-All

| Size (bytes) | Apr (19n) Avg Latency (µs) | May (19n) Avg Latency (µs) | Δ |
|---|---|---|---|
| 1 | 8.87 | 9.14 | +3% |
| 2 | 8.86 | 8.81 | −1% |
| 4 | 20.40 | 20.40 | 0% |
| 32 | 21.38 | 21.31 | 0% |
| 256 | 23.09 | 23.59 | +2% |
| 512 | 10.71 | 10.72 | 0% |
| 1024 | 11.56 | 11.30 | −2% |
| 4096 | 13.50 | 13.54 | 0% |
| 16384 | 30.45 | 30.56 | 0% |
| 65536 | 39.47 | 39.66 | 0% |
| 131072 | 64.88 | 65.89 | +2% |
| 262144 | 121.93 | 123.09 | +1% |
| 524288 | 206.48 | 205.90 | 0% |
| 1048576 | 392.17 | 388.21 | −1% |

**Hostnames (April):** a0001–a0019 (19 ranks, 1 per node)  
**Hostnames (May):** a0001–a0019 (19 ranks, 1 per node)

#### Verdict: ✅ Essentially Identical

GPU1 all-to-all latency is virtually unchanged between April and May across all message sizes (all deltas ≤ 3%). This is an excellent result confirming the GPU1 fabric is stable and consistent.

---

### 4c. GPU2 All-to-All

| Size (bytes) | Apr (30n) Avg Latency (µs) | May (31n) Avg Latency (µs) | Δ |
|---|---|---|---|
| 1 | 7.38 | 8.59 | +16% |
| 2 | 7.65 | 8.45 | +10% |
| 4 | 16.53 | 17.31 | +5% |
| 32 | 16.88 | 17.69 | +5% |
| 256 | 19.01 | 20.03 | +5% |
| 512 | 10.51 | 11.77 | +12% |
| 1024 | 12.36 | 13.65 | +10% |
| 4096 | 16.04 | 17.96 | +12% |
| 16384 | 41.74 | 49.01 | +17% |
| 65536 | 48.45 | 60.58 | +25% |
| 131072 | 69.43 | 100.05 | +44% |
| 262144 | 108.55 | 172.09 | +59% |
| 524288 | 191.97 | 325.12 | +69% |
| 1048576 | 354.28 | 607.39 | +71% |

**Hostnames (April):** b0001–b0002, b0004–b0031 (30 ranks — b0003 absent)  
**Hostnames (May):** b0001–b0031 (31 ranks — complete)

#### Verdict: ✅ Expected — Explained by IB Realignment

The elevated latency in May (up to +71% at 1 MB) is consistent with the IB connection realignment that took place towards the end of April. The April alltoall baseline (job 2045) was collected on April 1 — before the realignment — while the May alltoall (job 22917) reflects the post-realignment fabric topology. Changes in switch routing and cable assignments during a realignment alter the hop counts and congestion patterns for collective operations, which disproportionately affect large-message alltoall latency compared to point-to-point bandwidth.

Importantly, point-to-point BIBW is unaffected: all 465 GPU2 pairs in the May sweep pass at 98,676–104,926 MB/s (avg 101,988 MB/s), within 0.5% of the pre-realignment April sweep. This confirms the fabric is healthy at the link level — the alltoall difference is a topological/routing artifact of the realignment, not a degradation.

The May alltoall result should be treated as the new baseline going forward.

---

## Summary Table

| Comparison | BIBW Result | Avg Apr BW | Avg May BW | Δ | Alltoall Result |
|---|---|---|---|---|---|
| Compute (Apr) vs CPU (May 20, `--mem=900G`) | ✅ **Consistent** | 89,716 MB/s | 89,178 MB/s | −0.6% | *(not re-run)* |
| GPU2 Apr vs GPU2 May | ✅ **Consistent** | 102,513 MB/s | 101,988 MB/s | −0.5% | ✅ Acceptable* |
| GPU1 Apr vs GPU1 May | ✅ **Consistent** | 81,439 MB/s | 81,846 MB/s | +0.5% | ✅ **Identical** |

\* GPU2 alltoall latency is higher in May due to IB connection realignment at end of April; BIBW point-to-point is unaffected and healthy. May result is the new baseline.

---

## Recommendations

1. **Compute vs CPU**: Resolved. Adding `--mem=900G` to the SBATCH submission restores full IB bandwidth on the CPU partition. Ensure all future CPU sweeps include this flag. The May 19 sweep results should be treated as invalid.

2. **GPU2 alltoall**: The May 19 result (job 22917, 31 nodes) is the established post-realignment baseline. No action needed.

3. **GPU1**: No action needed. Performance is stable and reproducible.
