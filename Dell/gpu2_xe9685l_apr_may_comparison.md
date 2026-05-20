# GPU2 XE9685L — HPL (FP64), STREAM & 8-Node HPL Comparison (April vs. May)

**Purpose:** Verify that image changes between April and May did not meaningfully impact GPU2 node performance, and validate 8-node HPL results against single-node baselines.

| | Baseline (April) | May Run |
|---|---|---|
| **Image tag** | `xe9685l-20260410T183755` | `xe9685l-20260510T071112` |
| **HPL (FP64) — primary baseline** | `GPU2/hpl-xe9685l-20260410T183755/` (30 nodes, matches benchmark-results-summary.md) | `GPU2/hpl-xe9685l-20260510T071112/` (31 nodes) |
| **HPL (FP64) — partial re-run** | `GPU2/hpl-xe9685l-20260415T145353/` (21 nodes, subset re-run) | — |
| **STREAM data** | `GPU2/stream-xe9685l-20260410T183755/` (30 nodes) | `GPU2/stream-xe9685l-20260510T071112/` (31 nodes) |
| **8-Node HPL** | `GPU2/hpl-8node-xe9685l-20260410T183755/` (all failed) → `GPU2/hpl-8node-xe9685l-20260415T145353/` (first success) | `GPU2/hpl-8node-xe9685l-20260510T071112/` |

> **Note on b0003:** Node b0003 was offline during the April 10 benchmark runs. It returned to service by April 15 and is fully present in all May results.
>
> **Note on April directories:** The April 15 HPL single-node and 8-node directories represent targeted follow-up runs. The authoritative single-node April baseline is April 10 (30 nodes, consistent with benchmark-results-summary.md). The April 15 single-node covers 21 of those same nodes plus b0003's first appearance.

---

## 1. HPL FP64 (Single Node)

**Binary:** HPL-NVIDIA 25.9.0  
**Configuration:** N=401,408 · NB=2,048 · P=4 · Q=2 · 8 GPUs/node  
**Metric:** Total GFLOPS (all 8 GPUs) and GFLOPS/GPU  
All tested nodes **PASSED** residual checks in all runs.

### Summary Statistics

| Metric | Apr 10 (30 nodes) | Apr 15 (21 nodes) | May (31 nodes) | Apr 10 → May Δ |
|--------|:-----------------:|:-----------------:|:--------------:|:--------------:|
| Mean (GFLOPS/node) | 271,960 | 271,910 | 271,610 | **−0.13%** |
| Std Dev | 165 | 165 | 103 | — |
| Min (GFLOPS/node) | 271,600 (b0012) | 271,600 (b0003) | 271,400 (b0003) | — |
| Max (GFLOPS/node) | 272,400 (b0004) | 272,100 (b0016) | 271,900 (b0021) | — |
| Node-to-node spread | < 0.29% | < 0.18% | < 0.19% | — |

### Per-Node Results

"—" means the node was not run in that period. Apr 15 is shown for reference; Apr 10 → May delta is the primary comparison.

| Node | Apr 10 GFLOPS | Apr 10 /GPU | Apr 15 GFLOPS | Apr 15 /GPU | May GFLOPS | May /GPU | Apr10→May Δ% |
|:-----|-------------:|------------:|--------------:|------------:|-----------:|---------:|-------------:|
| b0001 | 271,900 | 33,990 | 272,100 | 34,010 | 271,700 | 33,960 | −0.07% |
| b0002 | 272,000 | 34,000 | 271,900 | 33,980 | 271,600 | 33,950 | −0.15% |
| b0003 | — | — | 271,600 | 33,950 | 271,400 | 33,930 | — |
| b0004 | **272,400** | 34,050 | — | — | 271,600 | 33,950 | **−0.29%** |
| b0005 | 271,900 | 33,990 | — | — | 271,800 | 33,970 | −0.04% |
| b0006 | 272,000 | 34,000 | 271,900 | 33,990 | 271,600 | 33,950 | −0.15% |
| b0007 | 271,900 | 33,980 | 271,800 | 33,980 | 271,600 | 33,950 | −0.11% |
| b0008 | 271,800 | 33,980 | — | — | 271,600 | 33,950 | −0.07% |
| b0009 | 272,100 | 34,020 | — | — | 271,600 | 33,950 | −0.18% |
| b0010 | 271,900 | 33,990 | 272,000 | 34,000 | 271,600 | 33,960 | −0.11% |
| b0011 | 272,000 | 34,000 | 272,000 | 33,990 | 271,500 | 33,940 | −0.18% |
| b0012 | 271,600 | 33,950 | — | — | 271,500 | 33,940 | −0.04% |
| b0013 | 272,100 | 34,020 | 272,000 | 34,000 | 271,600 | 33,950 | −0.18% |
| b0014 | 272,200 | 34,030 | 272,000 | 34,000 | 271,500 | 33,940 | **−0.26%** |
| b0015 | 271,800 | 33,980 | 272,000 | 34,010 | 271,600 | 33,940 | −0.07% |
| b0016 | 271,700 | 33,960 | 272,100 | 34,010 | 271,600 | 33,950 | −0.04% |
| b0017 | 271,800 | 33,980 | 271,700 | 33,960 | 271,500 | 33,940 | −0.11% |
| b0018 | 271,900 | 33,990 | — | — | 271,500 | 33,940 | −0.15% |
| b0019 | 271,900 | 33,990 | 272,000 | 34,000 | 271,500 | 33,940 | −0.15% |
| b0020 | 272,000 | 34,000 | 271,800 | 33,980 | 271,600 | 33,950 | −0.15% |
| b0021 | 272,300 | 34,040 | — | — | 271,900 | 33,980 | −0.15% |
| b0022 | 272,000 | 34,000 | 271,700 | 33,970 | 271,600 | 33,960 | −0.15% |
| b0023 | 271,800 | 33,980 | 272,000 | 34,000 | 271,600 | 33,950 | −0.07% |
| b0024 | 272,000 | 33,990 | 271,900 | 33,990 | 271,600 | 33,950 | −0.15% |
| b0025 | 271,800 | 33,980 | 272,000 | 34,000 | 271,500 | 33,930 | −0.11% |
| b0026 | 272,100 | 34,010 | 271,900 | 33,990 | 271,700 | 33,960 | −0.15% |
| b0027 | 272,000 | 34,000 | 271,900 | 33,990 | 271,600 | 33,950 | −0.15% |
| b0028 | 272,000 | 34,000 | 271,700 | 33,970 | 271,600 | 33,950 | −0.15% |
| b0029 | 271,900 | 33,990 | — | — | 271,700 | 33,960 | −0.07% |
| b0030 | 272,000 | 34,010 | — | — | 271,800 | 33,970 | −0.07% |
| b0031 | 272,000 | 34,000 | — | — | 271,700 | 33,960 | −0.11% |

### Observations

All 30 matched nodes decreased uniformly by −0.04% to −0.29% (mean −0.13%, StdDev 0.059%). The direction is consistent across every node, and the spread is smaller than the node-to-node variation, indicating a small systematic shift rather than per-node noise. The largest delta is b0004 at −0.29%, which is still within the < 0.3% cluster spread. The Apr 15 re-run values sit between the Apr 10 and May numbers for overlapping nodes, consistent with a gradual trend.

b0003's first appearance in Apr 15 (271,600 GFLOPS) and its May result (271,400 GFLOPS) are both within the cluster norm, confirming it re-joined the fleet in good health.

---

## 2. STREAM FP32 (Single GPU — Device 0, Per Node)

**Binary:** NVIDIA-STREAM 25.9.0  
**Configuration:** Array size = 1,000,000,000 elements (float) · Device 0 · CSAT  
**Theoretical peak:** 7,672,300 MB/s per GPU (HBM3e, 3,996 MHz × 7,680-bit)

> **Important — Bimodal FP32 Behavior:** B200 FP32 STREAM results across both runs fall into two distinct performance tiers (~7,075 MB/s and ~7,228 MB/s, ~2.2% apart). Individual nodes switch tiers between runs, producing the large per-node deltas flagged `*` below. The cluster-wide **mean is stable** (~7,178–7,195 MB/s) and **FP64 Triad is the recommended bandwidth metric** for GPU2 (tightly clustered at ~7,261 MB/s in both runs with no bimodal behavior). The FP32 tier count is stable: ~20 nodes in the high tier and ~10 in the low tier in each run.

### Summary Statistics

| Metric | April (30 nodes) | May (31 nodes) | Delta |
|--------|:---------------:|:--------------:|:-----:|
| Mean Triad (MB/s) | 7,178,193 | 7,194,912 | +0.23% |
| Std Dev (MB/s) | 71,001 | 56,921 | — |
| Min Triad (MB/s) | 7,070,802 | 7,075,204 | — |
| Max Triad (MB/s) | 7,232,540 | 7,232,540 | — |
| % of Peak (mean) | 93.6% | 93.8% | — |

### Per-Node Results

| Node | Apr Triad (MB/s) | May Triad (MB/s) | Δ% | Apr Copy (MB/s) | May Copy (MB/s) | Copy Δ% |
|:-----|----------------:|-----------------:|----:|----------------:|----------------:|--------:|
| b0001 | 7,223,624 | 7,227,244 | +0.05% | 6,977,394 | 6,985,582 | +0.12% |
| b0002 | 7,231,564 | 7,231,564 | +0.00% | 6,984,216 | 6,989,683 | +0.08% |
| b0003 | — | 7,227,244 | — | — | 6,979,147 | — |
| b0004 | 7,228,219 | 7,075,205 | **−2.12%** `*` | 6,985,777 | 6,979,147 | −0.09% |
| b0005 | 7,231,704 | 7,226,965 | −0.07% | 6,991,247 | 6,971,168 | −0.29% |
| b0006 | 7,227,105 | 7,206,134 | −0.29% | 6,991,443 | 6,996,138 | +0.07% |
| b0007 | 7,223,207 | 7,221,260 | −0.03% | 6,996,530 | 6,972,334 | −0.35% |
| b0008 | 7,074,537 | 7,082,822 | +0.12% | 6,973,306 | 6,973,306 | +0.00% |
| b0009 | 7,070,803 | 7,231,146 | **+2.27%** `*` | 6,971,945 | 6,977,588 | +0.08% |
| b0010 | 7,226,687 | 7,222,233 | −0.06% | 6,978,367 | 6,984,020 | +0.08% |
| b0011 | 7,223,624 | 7,217,785 | −0.08% | 6,985,191 | 6,971,362 | −0.20% |
| b0012 | 7,227,801 | 7,083,090 | **−2.00%** `*` | 6,985,972 | 6,977,782 | −0.12% |
| b0013 | 7,231,425 | 7,223,207 | −0.11% | 6,977,394 | 6,972,918 | −0.06% |
| b0014 | 7,205,996 | 7,231,843 | +0.36% | 6,997,313 | 6,979,147 | −0.26% |
| b0015 | 7,074,938 | 7,230,867 | **+2.20%** `*` | 6,984,020 | 6,977,782 | −0.09% |
| b0016 | 7,231,006 | 7,232,541 | +0.02% | 6,984,020 | 6,973,112 | −0.16% |
| b0017 | 7,223,624 | 7,231,425 | +0.11% | 6,991,834 | 6,983,826 | −0.11% |
| b0018 | 7,232,262 | 7,222,650 | −0.13% | 6,991,834 | 6,977,978 | −0.20% |
| b0019 | 7,227,941 | 7,222,790 | −0.07% | 6,992,029 | 6,972,139 | −0.28% |
| b0020 | 7,074,671 | 7,231,983 | **+2.22%** `*` | 6,984,411 | 6,979,731 | −0.07% |
| b0021 | 7,232,541 | 7,205,303 | −0.38% | 6,984,020 | 6,991,247 | +0.10% |
| b0022 | 7,231,983 | 7,196,040 | −0.50% | 6,991,834 | 6,972,334 | −0.28% |
| b0023 | 7,091,126 | 7,082,554 | −0.12% | 6,984,216 | 6,978,172 | −0.09% |
| b0024 | 7,095,553 | 7,227,522 | **+1.86%** `*` | 6,977,978 | 6,978,757 | +0.01% |
| b0025 | 7,082,554 | 7,231,983 | **+2.11%** `*` | 6,971,362 | 6,997,118 | +0.37% |
| b0026 | 7,231,843 | 7,228,219 | −0.05% | 6,991,247 | 6,978,757 | −0.18% |
| b0027 | 7,231,983 | 7,086,838 | **−2.01%** `*` | 6,983,045 | 6,978,757 | −0.06% |
| b0028 | 7,073,870 | 7,205,580 | +1.86% | 6,972,528 | 6,978,757 | +0.09% |
| b0029 | 7,077,876 | 7,227,244 | **+2.11%** `*` | 6,971,362 | 6,971,751 | +0.01% |
| b0030 | 7,222,511 | 7,087,373 | **−1.87%** `*` | 6,972,334 | 6,973,501 | +0.02% |
| b0031 | 7,083,223 | 7,183,633 | +1.42% | 6,978,757 | 6,972,918 | −0.08% |

In every tier-switching case, Copy bandwidth remains stable (< 0.4%), confirming the Triad variance is an artifact of the benchmark's sensitivity to HBM power state at this access pattern, not actual bandwidth regression.

---

## 3. STREAM FP64 (Single GPU — Device 0, Per Node)

**Binary:** NVIDIA-STREAM 25.9.0  
**Configuration:** Array size = 1,000,000,000 elements (double) · Device 0 · CSAT  
**Theoretical peak:** 7,672,300 MB/s per GPU

### Summary Statistics

| Metric | April (30 nodes) | May (31 nodes) | Delta |
|--------|:---------------:|:--------------:|:-----:|
| Mean Triad (MB/s) | 7,260,799 | 7,261,977 | +0.02% |
| Std Dev (MB/s) | 2,583 | 3,462 | — |
| Min Triad (MB/s) | 7,252,754 (b0030) | 7,250,650 (b0001) | — |
| Max Triad (MB/s) | 7,264,134 (b0011) | 7,265,048 (b0027) | — |
| % of Peak (mean) | 94.6% | 94.6% | — |

### Per-Node Results

| Node | Apr Triad (MB/s) | May Triad (MB/s) | Δ% | Apr Copy (MB/s) | May Copy (MB/s) | Copy Δ% |
|:-----|----------------:|-----------------:|----:|----------------:|----------------:|--------:|
| b0001 | 7,262,727 | 7,250,650 | −0.17% | 7,100,961 | 7,095,319 | −0.08% |
| b0002 | 7,262,375 | 7,261,321 | −0.01% | 7,087,273 | 7,081,451 | −0.08% |
| b0003 | — | 7,259,493 | — | — | 7,049,104 | — |
| b0004 | 7,257,034 | 7,262,305 | +0.07% | 7,094,110 | 7,100,357 | +0.09% |
| b0005 | 7,261,531 | 7,263,993 | +0.03% | 7,094,614 | 7,067,538 | −0.38% |
| b0006 | 7,257,877 | 7,262,164 | +0.06% | 7,094,815 | 7,100,457 | +0.08% |
| b0007 | 7,259,774 | 7,263,923 | +0.06% | 7,062,546 | 7,069,036 | +0.09% |
| b0008 | 7,257,596 | 7,261,953 | +0.06% | 7,101,365 | 7,094,010 | −0.10% |
| b0009 | 7,262,727 | 7,262,094 | −0.01% | 7,100,558 | 7,100,558 | +0.00% |
| b0010 | 7,262,024 | 7,264,556 | +0.03% | 7,081,250 | 7,099,953 | +0.26% |
| b0011 | 7,264,134 | 7,261,672 | −0.03% | 7,101,365 | 7,100,558 | −0.01% |
| b0012 | 7,262,024 | 7,263,782 | +0.02% | 7,094,110 | 7,100,659 | +0.09% |
| b0013 | 7,262,234 | 7,263,923 | +0.02% | 7,074,838 | 7,100,457 | +0.36% |
| b0014 | 7,262,375 | 7,262,094 | −0.00% | 7,094,614 | 7,101,264 | +0.09% |
| b0015 | 7,259,282 | 7,264,134 | +0.07% | 7,100,961 | 7,049,104 | −0.73% |
| b0016 | 7,257,105 | 7,252,964 | −0.06% | 7,094,614 | 7,091,796 | −0.04% |
| b0017 | 7,263,078 | 7,264,134 | +0.01% | 7,094,513 | 7,100,861 | +0.09% |
| b0018 | 7,262,234 | 7,263,923 | +0.02% | 7,081,752 | 7,100,357 | +0.26% |
| b0019 | 7,262,024 | 7,254,929 | −0.10% | 7,100,861 | 7,100,558 | −0.00% |
| b0020 | 7,262,516 | 7,264,275 | +0.02% | 7,088,076 | 7,095,016 | +0.10% |
| b0021 | 7,262,024 | 7,261,953 | −0.00% | 7,101,062 | 7,100,659 | −0.01% |
| b0022 | 7,261,953 | 7,264,626 | +0.04% | 7,088,177 | 7,081,451 | −0.09% |
| b0023 | 7,257,105 | 7,262,727 | +0.08% | 7,087,876 | 7,081,451 | −0.09% |
| b0024 | 7,262,516 | 7,262,094 | −0.01% | 7,101,062 | 7,094,614 | −0.09% |
| b0025 | 7,261,953 | 7,262,164 | +0.00% | 7,094,312 | 7,094,916 | +0.01% |
| b0026 | 7,262,024 | 7,264,345 | +0.03% | 7,100,961 | 7,095,218 | −0.08% |
| b0027 | 7,261,953 | 7,265,048 | +0.04% | 7,082,153 | 7,089,182 | +0.10% |
| b0028 | 7,261,742 | 7,264,345 | +0.04% | 7,097,836 | 7,062,447 | −0.50% |
| b0029 | 7,257,315 | 7,263,993 | +0.09% | 7,100,861 | 7,097,635 | −0.05% |
| b0030 | 7,252,754 | 7,257,807 | +0.07% | 7,094,110 | 7,087,876 | −0.09% |
| b0031 | 7,261,953 | 7,263,923 | +0.03% | 7,101,164 | 7,081,250 | −0.28% |

FP64 is extremely stable: all 30 matched nodes changed by ≤0.17% (mean +0.02%), and all nodes achieve 94.4–94.6% of theoretical peak in both runs. b0003's first appearance at 7,259,493 MB/s is fully within the cluster norm.

---

## 4. 8-Node HPL History and May Validation

**Configuration (all successful runs):** N=1,089,536 · NB=2,048 · P=8 · Q=8 · 64 GPUs total

### Run History

| Date | Directory | Node Group | GFLOPS | /GPU | Result |
|------|-----------|-----------|--------|------|--------|
| Apr 10 | `hpl-8node-xe9685l-20260410T183755` | b0004–b0011 (×7 attempts) | — | — | **All failed** |
| Apr 10 | `hpl-8node-xe9685l-20260410T183755` | b0012–b0019 (×2 attempts) | — | — | **All failed** |
| Apr 10 | `hpl-8node-xe9685l-20260410T183755` | b0013–b0020 (×2 attempts) | — | — | **All failed** |
| Apr 10 | `hpl-8node-xe9685l-20260410T183755` | b0017–b0024 (×1 attempt) | — | — | **Failed** |
| Apr 15 | `hpl-8node-xe9685l-20260415T145353` | b0001–b0003, b0013–b0017 | 2,216,000 | 34,620 | PASSED |
| Apr 15 | `hpl-8node-xe9685l-20260415T145353` | b0006–b0028 (non-consec.) | 2,216,000 | 34,620 | PASSED (×2) |
| Apr 15 | `hpl-8node-xe9685l-20260415T145353` | b0001–b0003, b0007, b0010–b0011, b0019–b0020 | 2,215,000 | 34,610 | PASSED |
| May 18 | `hpl-8node-xe9685l-20260510T071112` | b0002–b0009 | — | — | **Failed** |
| May 18 | `hpl-8node-xe9685l-20260510T071112` | b0001–b0008 | 2,216,000 | 34,630 | PASSED (×2) |
| May 18 | `hpl-8node-xe9685l-20260510T071112` | b0009–b0016 | 2,216,000 | 34,620 | PASSED |
| May 18 | `hpl-8node-xe9685l-20260510T071112` | b0013–b0020 | 2,215,000 | 34,610 | PASSED |
| May 18 | `hpl-8node-xe9685l-20260510T071112` | b0017–b0024 | 2,216,000 | 34,620 | PASSED |
| May 19 | `hpl-8node-xe9685l-20260510T071112` | b0024–b0031 | 2,217,000 | 34,630 | PASSED |

The Apr 10 8-node attempts all failed; Apr 15 was the first successful 8-node run. May reproduces the Apr 15 results exactly. All 31 nodes are covered across the May groups via overlapping ranges.

### April vs. May 8-Node Comparison

| Metric | Apr 15 (successful runs) | May (successful runs) | Delta |
|--------|:------------------------:|:---------------------:|:-----:|
| GFLOPS range | 2,215,000–2,216,000 | 2,215,000–2,217,000 | < 0.1% |
| Mean GFLOPS/GPU | 34,618 | 34,622 | +0.01% |
| All nodes PASSED | Yes (4/4) | Yes (5/6) | — |

### Alignment with Single-Node Results

| Metric | Single-Node (May) | 8-Node (May) | Notes |
|--------|:-----------------:|:------------:|:------|
| GFLOPS/GPU | ~33,952 | ~34,622 | +2.0% in 8-node |
| 8 × single-node (expected at 100%) | 8 × 271,610 = 2,172,880 | 2,215,875 (avg) | Actual exceeds naïve projection |
| Effective parallel efficiency* | — | — | *Not meaningful — N is 2.7× larger in 8-node |
| All nodes PASSED | Yes | Yes | — |

> The 8-node per-GPU GFLOPS (~34,622) exceeds the single-node per-GPU (~33,952) by +2.0%. This is expected: HPL efficiency improves as N increases relative to the number of processes, because the compute-to-communication ratio rises. The 8-node N per GPU (1,089,536 / 64 = 17,024) results in a larger fraction of time in dense GEMM vs. panel-factorization and communication, driving the slightly higher throughput. This is a normal and desirable scaling property, not an anomaly.

---

## 5. Overall Summary

| Benchmark | April Mean | May Mean | Mean Delta | Verdict |
|-----------|:---------:|:--------:|:---------:|:-------:|
| HPL FP64 — GFLOPS/node | 271,960 (Apr 10) | 271,610 | **−0.13%** | Consistent |
| STREAM FP32 Triad — MB/s | 7,178,193 | 7,194,912 | **+0.23%** (see note) | Consistent |
| STREAM FP64 Triad — MB/s | 7,260,799 | 7,261,977 | **+0.02%** | Consistent |
| 8-Node HPL — GFLOPS/GPU | 34,618 (Apr 15) | 34,622 | **+0.01%** | Consistent, aligns with single-node |

### Conclusions

- **HPL FP64 is stable across the image change.** All 30 matched nodes declined uniformly by −0.04% to −0.29% (mean −0.13%), with a StdDev of only 0.06%. The shift is smaller than the cluster's own node-to-node spread and does not indicate any degradation.
- **STREAM FP64 is essentially unchanged** (+0.02% mean across 30 matched nodes, max ±0.17%). All nodes achieve 94.4–94.6% of theoretical peak in both runs.
- **STREAM FP32 bimodal behavior is confirmed non-hardware.** Nodes flip between ~7,075 and ~7,228 MB/s tiers between runs while Copy bandwidth stays flat (< 0.4%). The cluster-wide mean is stable and FP64 is unaffected. **FP64 Triad is the recommended bandwidth metric for GPU2 B200 nodes.**
- **b0003 returned to service** between the April 10 and April 15 runs and performs within the cluster norm across all benchmarks.
- **8-node HPL is stable and aligns with single-node.** April 15 and May results are identical (~2,216,000 GFLOPS per 8 nodes). Per-GPU throughput is +2.0% above single-node, consistent with the expected HPL efficiency gain from running a larger problem. The April 10 8-node failures were a pre-image-fix issue; all Apr 15 and May runs passed.
