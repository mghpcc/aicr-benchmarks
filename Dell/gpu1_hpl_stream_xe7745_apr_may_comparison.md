# GPU1 XE7745 — HPL-MxP & STREAM Comparison (April vs. May)

**Purpose:** Verify that image changes made between the April and May benchmark runs did not meaningfully impact performance on GPU1 nodes.

| | April Run | May Run |
|---|---|---|
| **Image tag** | `xe7745-20260415T203937` | `xe7745-20260510T060134` |
| **HPL-MxP data** | `GPU1/hpl-mxp-xe7745-20260415T203937/` | `GPU1/hpl-mxp-xe7745-20260510T060134/` |
| **STREAM data** | `GPU1/stream-xe7745-20260415T203937/` | `GPU1/stream-xe7745-20260510T060134/` |
| **Nodes tested** | 19 (a0001–a0019) | 19 (a0001–a0019) |

---

## 1. HPL-MxP (Single Node, Mixed Precision)

**Configuration:** N=430,080 · NB=2,048 · P=4 · Q=2 · SLOPPY-TYPE=FP16 · 8 GPUs/node  
**Metric reported:** Total GFLOPS (all 8 GPUs), the HPL-MxP performance to report per spec  
All 19 nodes **PASSED** residual checks in both runs.

### Summary Statistics

| Metric | April | May | Delta |
|--------|-------|-----|-------|
| Mean (TFLOPS/node) | 1,328.7 | 1,330.2 | +0.12% |
| Std Dev (TFLOPS) | 3.6 | 4.8 | — |
| Min (TFLOPS/node) | 1,322.5 (a0018) | 1,321.4 (a0017) | — |
| Max (TFLOPS/node) | 1,335.3 (a0010) | 1,338.0 (a0012) | — |
| Node-to-node spread | < 1.0% | < 1.3% | — |

### Per-Node Results

| Node | Apr TFLOPS | Apr TFLOPS/GPU | May TFLOPS | May TFLOPS/GPU | Delta% | Note |
|:-----|----------:|---------------:|----------:|---------------:|-------:|:-----|
| a0001 | 1,330.2 | 166.3 | 1,332.9 | 166.6 | +0.20% | |
| a0002 | 1,333.6 | 166.7 | 1,336.4 | 167.0 | +0.21% | |
| a0003 | 1,331.9 | 166.5 | 1,333.7 | 166.7 | +0.14% | |
| a0004 | 1,328.0 | 166.0 | 1,327.7 | 166.0 | -0.02% | |
| a0005 | 1,332.1 | 166.5 | 1,329.2 | 166.1 | -0.22% | |
| a0006 | 1,324.9 | 165.6 | 1,326.9 | 165.9 | +0.15% | |
| a0007 | 1,330.7 | 166.3 | 1,330.3 | 166.3 | -0.03% | |
| a0008 | 1,331.9 | 166.5 | 1,331.5 | 166.4 | -0.03% | |
| a0009 | 1,326.3 | 165.8 | 1,335.3 | 166.9 | **+0.68%** | Largest positive delta |
| a0010 | 1,335.3 | 166.9 | 1,337.8 | 167.2 | +0.19% | |
| a0011 | 1,325.5 | 165.7 | 1,322.0 | 165.3 | -0.26% | |
| a0012 | 1,331.3 | 166.4 | 1,338.0 | 167.2 | **+0.50%** | |
| a0013 | 1,325.4 | 165.7 | 1,328.7 | 166.1 | +0.25% | |
| a0014 | 1,328.8 | 166.1 | 1,326.1 | 165.8 | -0.20% | |
| a0015 | 1,329.3 | 166.2 | 1,327.7 | 165.9 | -0.12% | |
| a0016 | 1,325.3 | 165.7 | 1,332.7 | 166.6 | **+0.56%** | |
| a0017 | 1,328.7 | 166.1 | 1,321.4 | 165.2 | **-0.55%** | Largest negative delta |
| a0018 | 1,322.5 | 165.3 | 1,326.4 | 165.8 | +0.29% | |
| a0019 | 1,322.8 | 165.4 | 1,329.3 | 166.2 | +0.49% | |

### Node Highlights

**a0009 (+0.68%)** — Largest HPL-MxP gain. STREAM FP32 Triad was effectively flat (-0.05%) and FP64 also flat (-0.01%) for the same node, indicating the HPL delta is run-to-run noise rather than a systematic performance change.

**a0017 (-0.55%)** — Largest HPL-MxP drop. STREAM FP32 Triad was essentially flat (-0.02%) and FP64 flat (+0.04%), again confirming this reflects benchmark variability rather than hardware degradation.

**a0012 (+0.50% HPL)** — Showed the highest May HPL-MxP result (1,338.0 TFLOPS) but was -0.76% on STREAM FP64 Triad, with opposite signs across benchmarks confirming uncorrelated noise.

---

## 2. STREAM FP32 (Single GPU — Device 0, Per Node)

**Configuration:** Array size = 1,000,000,000 elements (float) · Device 0 · CSAT  
**Theoretical peak:** 1,597,600 MB/s per GPU  
**Metric:** Triad MB/s (primary), Copy MB/s (secondary)

### Summary Statistics

| Metric | April | May | Delta |
|--------|-------|-----|-------|
| Mean Triad (MB/s) | 1,486,829 | 1,485,887 | **-0.06%** |
| Std Dev (MB/s) | 3,053 | 3,132 | — |
| Min Triad (MB/s) | 1,482,530 (a0004/a0013) | 1,481,593 (a0007) | — |
| Max Triad (MB/s) | 1,490,254 (a0019) | 1,490,633 (a0008) | — |
| % of Peak (mean) | 93.1% | 93.0% | — |

### Per-Node Results

| Node | Apr Triad (MB/s) | May Triad (MB/s) | Triad Δ% | Apr Copy (MB/s) | May Copy (MB/s) | Copy Δ% |
|:-----|----------------:|-----------------:|---------:|----------------:|----------------:|--------:|
| a0001 | 1,488,391 | 1,483,081 | -0.36% | 1,470,043 | 1,466,147 | -0.27% |
| a0002 | 1,483,462 | 1,489,490 | +0.41% | 1,468,972 | 1,469,482 | +0.03% |
| a0003 | 1,489,313 | 1,483,844 | -0.37% | 1,468,662 | 1,470,009 | +0.09% |
| a0004 | 1,482,530 | 1,483,486 | +0.06% | 1,469,758 | 1,468,964 | -0.05% |
| a0005 | 1,482,712 | 1,483,838 | +0.08% | 1,469,188 | 1,471,696 | +0.17% |
| a0006 | 1,489,112 | 1,483,269 | -0.39% | 1,470,035 | 1,468,653 | -0.09% |
| a0007 | 1,489,118 | 1,481,593 | **-0.51%** | 1,469,214 | 1,465,382 | -0.26% |
| a0008 | 1,489,118 | 1,490,633 | +0.10% | 1,468,938 | 1,469,758 | +0.06% |
| a0009 | 1,483,832 | 1,483,093 | -0.05% | 1,468,627 | 1,469,741 | +0.08% |
| a0010 | 1,489,887 | 1,489,697 | -0.01% | 1,469,197 | 1,464,807 | -0.30% |
| a0011 | 1,483,838 | 1,488,739 | +0.33% | 1,470,009 | 1,469,758 | -0.02% |
| a0012 | 1,488,745 | 1,484,778 | -0.27% | 1,468,386 | 1,472,572 | +0.29% |
| a0013 | 1,482,530 | 1,490,070 | **+0.51%** | 1,470,606 | 1,464,258 | -0.43% |
| a0014 | 1,489,875 | 1,482,905 | **-0.47%** | 1,469,223 | 1,470,043 | +0.06% |
| a0015 | 1,488,934 | 1,488,550 | -0.03% | 1,470,588 | 1,470,043 | -0.04% |
| a0016 | 1,489,685 | 1,488,550 | -0.08% | 1,470,312 | 1,469,490 | -0.06% |
| a0017 | 1,484,202 | 1,483,844 | -0.02% | 1,468,895 | 1,468,912 | +0.00% |
| a0018 | 1,484,220 | 1,483,269 | -0.06% | 1,471,116 | 1,464,523 | -0.45% |
| a0019 | 1,490,254 | 1,489,118 | -0.08% | 1,468,662 | 1,469,214 | +0.04% |

### Node Highlights

**a0013 (+0.51% Triad)** — Largest FP32 Triad gain. Copy bandwidth was -0.43% on the same node, with opposing signs indicating measurement noise rather than a real bandwidth change.

**a0007 (-0.51% Triad)** — Largest FP32 Triad drop, with Copy also slightly lower (-0.26%). However, HPL-MxP was effectively flat (-0.03%) on this node, suggesting this is within the expected variance for this GPU rather than a hardware issue.

**a0014 (-0.47% Triad)** — Copy was actually +0.06%, again showing no consistent directional change.

---

## 3. STREAM FP64 (Single GPU — Device 0, Per Node)

**Configuration:** Array size = 1,000,000,000 elements (double) · Device 0 · CSAT  
**Theoretical peak:** 1,597,600 MB/s per GPU  
**Metric:** Triad MB/s (primary), Copy MB/s (secondary)

### Summary Statistics

| Metric | April | May | Delta |
|--------|-------|-----|-------|
| Mean Triad (MB/s) | 1,489,872 | 1,490,185 | **+0.02%** |
| Std Dev (MB/s) | 4,563 | 2,908 | — |
| Min Triad (MB/s) | 1,481,642 (a0004) | 1,488,040 (a0014) | — |
| Max Triad (MB/s) | 1,501,381 (a0005) | 1,501,673 (a0010) | — |
| % of Peak (mean) | 93.3% | 93.3% | — |

### Per-Node Results

| Node | Apr Triad (MB/s) | May Triad (MB/s) | Triad Δ% | Apr Copy (MB/s) | May Copy (MB/s) | Copy Δ% |
|:-----|----------------:|-----------------:|---------:|----------------:|----------------:|--------:|
| a0001 | 1,490,020 | 1,488,890 | -0.08% | 1,471,740 | 1,468,985 | -0.19% |
| a0002 | 1,491,155 | 1,490,971 | -0.01% | 1,471,203 | 1,471,198 | -0.00% |
| a0003 | 1,489,647 | 1,489,836 | +0.01% | 1,466,641 | 1,468,162 | +0.10% |
| a0004 | 1,481,642 | 1,491,635 | **+0.67%** | 1,470,368 | 1,471,337 | +0.07% |
| a0005 | 1,501,381 | 1,488,890 | **-0.83%** | 1,475,928 | 1,467,881 | -0.55% |
| a0006 | 1,489,064 | 1,488,701 | -0.02% | 1,470,644 | 1,468,985 | -0.11% |
| a0007 | 1,489,647 | 1,490,405 | +0.05% | 1,468,170 | 1,468,709 | +0.04% |
| a0008 | 1,490,112 | 1,489,455 | -0.04% | 1,470,398 | 1,470,644 | +0.02% |
| a0009 | 1,489,742 | 1,489,647 | -0.01% | 1,467,886 | 1,468,170 | +0.02% |
| a0010 | 1,489,662 | 1,501,673 | **+0.81%** | 1,471,904 | 1,476,773 | +0.33% |
| a0011 | 1,489,174 | 1,489,446 | +0.02% | 1,471,471 | 1,470,238 | -0.08% |
| a0012 | 1,500,036 | 1,488,606 | **-0.76%** | 1,477,327 | 1,467,894 | -0.64% |
| a0013 | 1,488,524 | 1,489,836 | +0.09% | 1,468,709 | 1,468,576 | -0.01% |
| a0014 | 1,481,915 | 1,488,039 | +0.41% | 1,472,316 | 1,468,162 | -0.28% |
| a0015 | 1,488,603 | 1,488,795 | +0.01% | 1,467,881 | 1,469,538 | +0.11% |
| a0016 | 1,489,549 | 1,489,378 | -0.01% | 1,468,847 | 1,468,985 | +0.01% |
| a0017 | 1,489,174 | 1,489,836 | +0.04% | 1,468,852 | 1,470,649 | +0.12% |
| a0018 | 1,488,982 | 1,489,928 | +0.06% | 1,469,538 | 1,469,128 | -0.03% |
| a0019 | 1,489,549 | 1,489,552 | +0.00% | 1,465,266 | 1,470,506 | +0.36% |

### Node Highlights

**a0010 (+0.81% Triad)** — Largest FP64 Triad gain. Copy was also up (+0.33%), which could suggest slightly favorable conditions during the May run. HPL-MxP for this node was +0.19%, providing no corroboration of a systematic hardware change.

**a0005 (-0.83% Triad)** — Largest FP64 Triad drop, and Copy also lower (-0.55%). Notably, this node had the highest April FP64 Triad result (1,501,381 MB/s), suggesting the April run may have measured a favorable transient. The May result (1,488,890 MB/s) is close to the node-wide average and more representative.

**a0012 (-0.76% Triad, -0.64% Copy)** — The only node where both FP64 metrics declined by a meaningful amount. However, its HPL-MxP result improved by +0.50%, ruling out any hardware degradation.

---

## 4. Overall Summary

| Benchmark | April Mean | May Mean | Mean Delta | Max Delta | Min Delta | Verdict |
|-----------|-----------|---------|-----------|----------|----------|---------|
| HPL-MxP (TFLOPS/node) | 1,328.7 | 1,330.2 | **+0.12%** | +0.68% | -0.55% | Consistent |
| STREAM FP32 Triad (MB/s) | 1,486,829 | 1,485,887 | **-0.06%** | +0.51% | -0.51% | Consistent |
| STREAM FP64 Triad (MB/s) | 1,489,872 | 1,490,185 | **+0.02%** | +0.81% | -0.83% | Consistent |

### Conclusions

- **Performance is stable across the image change.** No benchmark shows a mean shift greater than ±0.15% between April and May. All per-node deltas are within ±1%, well below the typical threshold for flagging a regression.
- **Node-to-node spread exceeds run-to-run variation.** The standard deviation within a single run (~3–5 TFLOPS on HPL-MxP, ~3,000 MB/s on STREAM) is larger than the mean April-to-May delta, confirming that the observed per-node differences are dominated by benchmark noise rather than image differences.
- **No node shows systematic degradation across all three tests.** Nodes with the largest HPL-MxP drops (a0017, a0011) were flat on STREAM, and vice versa. The absence of correlated drops across benchmarks rules out hardware issues on any individual node.
- **All 19 nodes passed HPL-MxP correctness checks** in both runs.
