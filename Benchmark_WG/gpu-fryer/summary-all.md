# GPU Benchmark Summary
**Date:** 2026-05-05 | **Nodes:** 45 files (16 a-nodes, 29 b-nodes)

---

## A-nodes — NVIDIA RTX PRO 6000 Blackwell Server Edition
**Nodes:** a0004–a0019 (16 nodes, 8 GPUs each)

All 16 nodes are essentially identical — variation is under 1% across the fleet.

| Precision | Per-node throughput | Per-GPU |
|-----------|-------------------|---------|
| FP32      | ~205 TF           | ~26 TF  |
| BF16      | ~419 TF           | ~52 TF  |
| FP8       | ~881 TF           | ~110 TF |

No throttling. No errors. All runs completed normally.

---

## B-nodes — NVIDIA B200
**Nodes:** b0001–b0031, **excluding b0024 and b0027** (29 nodes, 8 GPUs each)

All 29 nodes are consistent — variation is under 2% across the fleet.

| Precision | Per-node throughput | Per-GPU |
|-----------|-------------------|---------|
| FP32      | ~767 TF           | ~96 TF  |
| BF16      | ~1491 TF          | ~186 TF |
| FP8       | ~4086 TF          | ~511 TF |

No throttling. No errors. All runs completed normally.

---

## Issues

| Node | Issue |
|------|-------|
| b0024 | **No output file** — job likely did not run |
| b0027 | **No output file** — job likely did not run |

---

## Notes
- B200 is roughly **4× faster** than the RTX PRO 6000 Blackwell across all precisions.
- All nodes within each group performed uniformly well; no individual node stands out as degraded.
