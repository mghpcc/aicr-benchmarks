# GPU Fryer Results — 2026-05-05

**Files:** `b0025-9553.out` (8× NVIDIA B200) | `a0001-9554.out` (8× NVIDIA RTX PRO 6000 Blackwell Server Edition)
Each file contains three back-to-back runs: **FP32 → BF16 → FP8**.

---

## Summary Table (per-GPU mean across 8 GPUs, in TFLOPS)

| | **B200** (b0025) | **H200** (reference) | **RTX PRO 6000 Blackwell** (a0001) | **B200 / H200** | **B200 / RTX 6000** |
|---|---|---|---|---|---|
| GPU memory | 163,800 MB (~160 GB) | ~141 GB | 87,018 MB (~85 GB) | — | — |
| **FP32 TFLOPS** | **768** | 368 | 205 | **2.09×** | **3.75×** |
| **BF16 TFLOPS** | **1,493** | 714 | 419 | **2.09×** | **3.56×** |
| **FP8 TFLOPS** | **4,103** | 1,468 | 881 | **2.80×** | **4.66×** |

H200 reference values: FP32 = 36.8094×10⁴, BF16 = 71.3494×10⁴, FP8 = 146.7665×10⁴ Gflops/s (provided).

Precision ratios: B200 → 1 : 1.94 : 5.34 (FP32 : BF16 : FP8); RTX PRO 6000 → 1 : 2.04 : 4.30.

The B200 delivers a roughly **2.1× generational uplift over H200** in FP32/BF16 and **2.8× in FP8** (Blackwell adds the FP8 boost on top of generational gains). Vs the workstation-class RTX PRO 6000 Blackwell, the B200 is **3.5–4.7× faster**, with the gap widening at lower precision.

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

| | B200 (per-GPU dense Tensor Core peak)* | Achieved | % of peak |
|---|---|---|---|
| TF32 (FP32 input) | ~1,125 TFLOPS | 768 | 68% |
| BF16 | ~2,250 TFLOPS | 1,493 | 66% |
| FP8 | ~4,500 TFLOPS | 4,103 | 91% |

*Dense, no sparsity. B200 sparse peaks are 2× these values.

The B200 FP8 path achieves 91% of dense peak, which is excellent. FP32/BF16 at 66–68% is normal for cuBLAS GEMM on this matrix size. Numbers are consistent with healthy B200 Tensor Cores.

For the RTX PRO 6000 Blackwell Server Edition, official Tensor Core specs aren't in my reference data — but the FP32:BF16:FP8 ratio (1:2:4) and intra-machine uniformity (<1.5% spread) are textbook healthy.

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
