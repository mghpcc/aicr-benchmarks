# GPU Fryer Results

**Files:** `b0025-9553.out` (8× NVIDIA B200) | `a0001-9554.out` (8× NVIDIA RTX PRO 6000 Blackwell Server Edition)
Each file contains three back-to-back runs: **FP32 → BF16 → FP8**.

---

## Summary Table (per-GPU mean across 8 GPUs, in TFLOPS)

| GPU / Metric | **GPU memory** | **FP32 TFLOPS** | **BF16 TFLOPS** | **FP8 TFLOPS** |
|---|---|---|---|---|
| **B200** (b0025) | ~160 GB | **768** | **1,493** | **4,103** |
| **H200** (ref) | 144 GB | **368** | **713** | **1,468** |
| **RTX PRO 6000** (a0001) | ~85 GB | **205** | **419** | **881** |
| **L40S** (ref) | 48 GB | **98** | **198** | not supported |
| **B200 / H200** | — | **2.09×** | **2.09×** | **2.80×** |
| **B200 / RTX PRO 6000** | — | **3.75×** | **3.56×** | **4.66×** |
| **RTX PRO 6000 / L40S** | — | **2.09×** | **2.12×** | — |

Precision ratios: B200 → 1 : 1.94 : 5.34 (FP32 : BF16 : FP8); H200 → 1 : 1.94 : 3.99; RTX PRO 6000 → 1 : 2.04 : 4.30; L40S → 1 : 2.02 (FP32 : BF16, no FP8 Tensor Core).

---

## Per-GPU Converged TFLOPS

### B200 — b0025-9553

| GPU | FP32 (mean / max) | BF16 (mean / max) | FP8 (mean / max) | Peak temp |
|-----|-------------------|-------------------|------------------|-----------|
| #0 | 779.7 / 796.0 | 1,512.3 / 1,516.2 | 4,138.7 / 4,156.2 | 65°C |
| #1 | 771.3 / 787.3 | 1,511.5 / 1,516.2 | 4,135.8 / 4,150.7 | 66°C |
| #2 | 754.5 / 777.4 | 1,466.9 / 1,474.4 | **4,066.7** / 4,116.6 | **73°C** |
| #3 | 771.4 / 794.9 | 1,497.7 / 1,510.7 | 4,104.2 / 4,136.4 | 71°C |
| #4 | 770.6 / 787.3 | 1,501.8 / 1,506.3 | 4,115.3 / 4,147.4 | 66°C |
| #5 | 772.0 / 790.5 | 1,497.9 / 1,505.2 | 4,107.1 / 4,124.3 | 65°C |
| #6 | 769.2 / 783.9 | 1,478.1 / 1,494.2 | 4,090.6 / 4,127.6 | **73°C** |
| #7 | 757.8 / 771.9 | 1,473.8 / 1,481.0 | **4,063.0** / 4,105.6 | **73°C** |
| **8-GPU mean** | **768 / 786** | **1,493 / 1,501** | **4,103 / 4,133** | — |

GPUs #2, #6, #7 are consistently 1.5–2.5% below cohort across **all three precisions** and run ~7–8°C hotter — same three slots, same pattern in every run.

### RTX PRO 6000 Blackwell — a0001-9554

| GPU | FP32 (mean / max) | BF16 (mean / max) | FP8 (mean / max) | Peak temp |
|-----|-------------------|-------------------|------------------|-----------|
| #0 | 205.5 / 211.1 | 419.5 / 422.2 | 882.5 / 882.9 | 76°C |
| #1 | 202.8 / 207.8 | 413.6 / 417.8 | 882.5 / 882.9 | 75°C |
| #2 | 205.2 / 210.0 | 419.4 / 422.2 | 880.5 / 882.9 | 73°C |
| #3 | 204.6 / 210.0 | 418.8 / 421.1 | 882.8 / 884.0 | 75°C |
| #4 | 205.4 / 210.0 | 419.9 / 422.2 | 880.7 / 884.0 | 74°C |
| #5 | 205.3 / 210.0 | 419.7 / 422.2 | 880.7 / 882.9 | 75°C |
| #6 | 203.5 / 207.8 | 416.8 / 418.9 | 880.7 / 882.9 | 74°C |
| #7 | 205.9 / 211.1 | 421.4 / 424.4 | 880.6 / 882.9 | 75°C |
| **8-GPU mean** | **205 / 210** | **419 / 421** | **881 / 883** | — |

Extremely uniform across all 8 GPUs in all three precisions. Spread is <1.5% within each precision. GPU #1 is consistently the lowest performer (~0.7% below mean) across all three precisions; GPU #7 is the highest (~0.5% above mean).

---

## Performance — Outliers and Variation

- **B200**: GPUs #2, #6, #7 are simultaneously the slowest and the hottest in all three precisions — same trio, every time. Spread within the cohort: 1.8–3.1% depending on precision (largest spread in BF16). No throttling, so this reflects intrinsic chassis position (airflow, slot proximity).
- **RTX PRO 6000**: No persistent outlier. Variation <1.5% in every precision.

## Expected Ceiling Comparison

| | B200 (per-GPU dense Tensor Core peak)* | Achieved | fraction of peak |
|---|---|---|---|
| TF32 (FP32 input) | ~1,125 TFLOPS | 768 | 0.68× |
| BF16 | ~2,250 TFLOPS | 1,493 | 0.66× |
| FP8 | ~4,500 TFLOPS | 4,103 | 0.91× |

*Dense, no sparsity. B200 sparse peaks are 2× these values.

The B200 FP8 path achieves 91% of dense peak, which is excellent. FP32/BF16 at 66–68% is normal for cuBLAS GEMM on this matrix size. Numbers are consistent with healthy B200 Tensor Cores.

For the RTX PRO 6000 Blackwell Server Edition, official Tensor Core specs aren't in my reference data — but the FP32:BF16:FP8 ratio (1:2:4) and intra-machine uniformity (<1.5% spread) are textbook healthy.

## B200 vs. H200

| | FP32 | BF16 | FP8 |
|---|---|---|---|
| B200 (measured) | 768 TFLOPS | 1,493 TFLOPS | 4,103 TFLOPS |
| H200 (reference) | 368 TFLOPS | 713 TFLOPS | 1,468 TFLOPS |
| **B200 / H200** | **2.09×** | **2.09×** | **2.80×** |

The B200 delivers **~2.1× the throughput of an H200** in FP32 and BF16, consistent with Blackwell's generational leap over Hopper. The FP32:BF16 ratio is identical on both (1:1.94), confirming the same Tensor Core data-type scaling law. The gap widens sharply at FP8 — **2.8×** — because Blackwell's 5th-gen Tensor Cores have a substantially higher FP8 peak relative to Hopper's 4th-gen cores (B200 achieves 91% of dense peak vs H200's lower FP8 ceiling). For FP8-quantised inference workloads, the B200 advantage is disproportionately larger than the raw 2× marketing figure suggests.

## B200 vs. RTX PRO 6000 Blackwell

| | FP32 | BF16 | FP8 |
|---|---|---|---|
| B200 (measured) | 768 TFLOPS | 1,493 TFLOPS | 4,103 TFLOPS |
| RTX PRO 6000 (measured) | 205 TFLOPS | 419 TFLOPS | 881 TFLOPS |
| **B200 / RTX PRO 6000** | **3.75×** | **3.56×** | **4.66×** |

Despite sharing the same Blackwell architecture and generation, the B200 outperforms the RTX PRO 6000 by **3.6–3.7× in FP32/BF16** and **4.7× in FP8**. Both are measured on 8-GPU nodes under identical gpu-fryer workloads, so the gap directly reflects the silicon difference: the B200 is a full datacenter part (GH200/GB200 die with ~208 SMs at full Blackwell density), while the RTX PRO 6000 Blackwell Server Edition is a workstation/professional part with a substantially cut-down die. The FP8 gap (4.7×) is larger than the FP32/BF16 gap (3.6×) because the B200's FP8 utilisation is exceptionally high (91% of dense peak) while the RTX PRO 6000's FP8 path is proportionally more bandwidth-bound on its smaller die. Both GPUs pass all health checks and show consistent intra-node uniformity.

## RTX PRO 6000 Blackwell vs. L40S

| | FP32 | BF16 | FP8 |
|---|---|---|---|
| RTX PRO 6000 (measured) | 205 TFLOPS | 419 TFLOPS | 881 TFLOPS |
| L40S (reference) | 98 TFLOPS | 198 TFLOPS | N/A |
| **RTX PRO 6000 / L40S** | **2.09×** | **2.12×** | — |

The RTX PRO 6000 Blackwell delivers roughly **2.1× the dense Tensor Core throughput** of an L40S in both FP32 and BF16. This is consistent with the architectural generational jump: the L40S is Ada Lovelace (4th-gen Tensor Cores, no FP8 Tensor Core path), while the RTX PRO 6000 is Blackwell (5th-gen Tensor Cores with native FP8 support). The ~2× uplift in FP32/BF16 aligns with Blackwell's documented improvements in GEMM throughput and higher SM count relative to AD102. The L40S also has only 48 GB GDDR6 versus the RTX PRO 6000's 85 GB, which matters for large-model inference and fine-tuning.

The FP32:BF16 ratio is nearly identical on both GPUs (~1:2), confirming both execute the same Tensor Core data-type scaling. The RTX PRO 6000 adds an FP8 path (4.3× FP32) which the L40S lacks entirely, making it substantially more capable for quantised inference workloads.

---

## Thermals / Power

| | B200 peak temps | RTX PRO 6000 peak temps | Throttling |
|---|---|---|---|
| Coolest GPUs | #0, #1, #4, #5: 65–66°C | #2, #6: 73–74°C | None |
| Mid | #3: 71°C | #1, #3, #4, #5, #7: 75°C | None |
| Hottest | **#2, #6, #7: 73°C** | **#0: 76°C** | None |

No throttling (HW, Thermal SW, or Thermal HW) on any GPU in any precision run.

## Stability

- No ECC errors, XID events, or NaN/inf reported in any of the 6 sub-runs.
- Each sub-run shows a clean ramp-up phase (small matrix), a long stable plateau (steady-state at large matrix), and a brief cooldown dip on the final measurement (teardown artifact, not real degradation).
- "All GPUs seem healthy" reported by gpu-fryer at the end of each of the 6 sub-runs.

---

## Verdict per GPU (all three precisions combined)

| GPU | B200 (b0025) | RTX PRO 6000 (a0001) |
|-----|-------------|----------------------|
| #0 | **PASS** — top performer | **PASS** — uniform, hottest of cohort (76°C) |
| #1 | **PASS** — normal | **PASS** — slightly slowest (~0.7% below mean) but stable |
| #2 | **PASS** — 1.9–3% below peers, 7°C hotter — same 3 hot slots | **PASS** — uniform, coolest of cohort |
| #3 | **PASS** — normal | **PASS** — best in BF16/FP8 |
| #4 | **PASS** — normal | **PASS** — uniform |
| #5 | **PASS** — normal | **PASS** — uniform |
| #6 | **PASS** — 1.5–2% below peers, 7°C hotter | **PASS** — uniform, coolest of cohort |
| #7 | **PASS** — 1.9–3% below peers, 7°C hotter | **PASS** — best FP32/BF16 |

**Recommendation:** B200 GPUs #2, #6, #7 are in chassis positions with reduced airflow — they consistently run hotter and slightly slower across **every** precision. Not a failure (no throttling, within 3% of peers), but worth tracking. If the gap widens over time or any of these begins throttling, inspect the chassis airflow/cold-aisle for those slot positions. RTX PRO 6000 system shows no concerns of any kind.
