# Phase 0 smoke test results (auto-generated 2026-07-13 17:54)

1.3b, 1 node x 8 B200, DP=8, GBS 1024, MBS 4, 20 iters, mock data.
Goal: verify every precision recipe runs (TE engaged, no NaN/OOM) before real sweeps.

| job | prec | status | iter | step_ms | tflops | speedup_vs_bf16 | mfu_bf16 | mfu_fp8 | fp8_arg | nan_iters | loss |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 152990 | bf16 | ok | 20 | 2877.3 | 771.7 | 1.0 | 34.3 | 17.1 | None/delayed | 0 | 7.448846E+00 |
| 152991 | fp8ds | ok | 20 | 2546.1 | 872.1 | 1.13 | 38.8 | 19.4 | hybrid/delayed | 0 | 7.349761E+00 |
| 152992 | fp8cs | ok | 20 | 2613.2 | 849.7 | 1.101 | 37.8 | 18.9 | hybrid/tensorwise | 0 | 7.486155E+00 |
| 152993 | mxfp8 | ok | 20 | 2616.7 | 848.5 | 1.1 | 37.7 | 18.9 | e4m3/mxfp8 | 0 | 7.521741E+00 |

Notes: tflops is analytic FLOPs/step-time (precision-independent, comparable
across rows). mfu_bf16 = tflops/2250, mfu_fp8 = tflops/4500 (%). At 1.3b the
FP8 speedup is expected to be modest (Amdahl); the 7b/13b phases are the
headline. 20-iter runs are smoke tests, not benchmark numbers.

Next steps: if all rows ok -> `bash submit_phase0b_mbs.sh` (MBS tuning),
then phase 1. If a recipe failed, see readme.md troubleshooting.
