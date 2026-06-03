# Single-node B200 GPU-count sweep — `out-1node-sweep/`

Date: 2026-06-03. Source: `sweep-gpus-1node.sh` (job 33169, node **b0012**, partition `b200-batch`, `--exclusive`).
Single MPI task, NCCL bus bandwidth swept over GPU counts 2→8 (`-g N`), all 10 collectives, message sizes 1M→16G (4× steps), nccl-tests 2.18.3 / NVHPC 26.3.

## Table 1 — Avg bus bandwidth (GB/s) vs number of GPUs

Mean of busbw across *all* message sizes (1M → 16G). Useful for relative trends across GPU counts, but the small-message latency floor pulls these well below the peak — **not directly comparable to `results_b200.md`** (see Table 2).

| collective       |     2 |     3 |     4 |     5 |     6 |     7 |     8 |
| ---------------- | ----: | ----: | ----: | ----: | ----: | ----: | ----: |
| sendrecv         | 382.0 | 343.3 | 341.7 | 319.7 | 319.3 | 319.5 | 319.2 |
| reduce           | 511.9 | 494.2 | 488.8 | 482.9 | 475.8 | 469.6 | 463.4 |
| broadcast        | 505.3 | 482.2 | 476.4 | 472.3 | 465.5 | 459.0 | 453.5 |
| gather           | 440.2 | 460.1 | 496.7 | 473.9 | 507.6 | 501.6 | 506.0 |
| scatter          | 434.1 | 463.5 | 507.8 | 463.8 | 494.5 | 494.8 | 508.7 |
| reduce_scatter   | 323.9 | 386.4 | 409.4 | 409.0 | 412.5 | 410.1 | 413.5 |
| all_gather       | 332.8 | 378.7 | 404.5 | 405.3 | 407.5 | 404.1 | 405.4 |
| all_reduce       | 407.7 | 442.7 | 454.5 | 448.8 | 452.0 | 438.3 | 489.6 |
| alltoall         | 314.1 | 335.1 | 390.4 | 343.0 | 371.3 | 379.1 | 410.8 |
| hypercube*       | 330.8 |   n/a | 266.8 |   n/a |   n/a |   n/a | 239.9 |

\*`hypercube_perf` fails validation (`Out of bounds values : 16 FAILED`, `-nan` at several GPU counts) — the known nccl-tests 2.18.3 hypercube bug. Its bandwidth values are invalid and should be ignored; the bug is also what marks the Slurm job as `FAILED` (exit code 7 on the final hypercube run) even though all other collectives completed normally.

## Table 2 — Converged bus bandwidth (GB/s) at the largest message size (16 GB)

Busbw at the largest message size (best of out-of-place / in-place) — **same methodology as [`results_b200.md`](results_b200.md)**. This is the peak/converged number; compare these to the per-GPU NVLink ceiling, not Table 1.

| collective       |     2 |     3 |     4 |     5 |     6 |     7 |     8 |
| ---------------- | ----: | ----: | ----: | ----: | ----: | ----: | ----: |
| sendrecv         | 668.5 | 664.9 | 664.4 | 666.1 | 666.9 | 666.7 | 666.6 |
| reduce           | 711.8 | 701.3 | 701.1 | 701.5 | 701.4 | 701.6 | 701.4 |
| broadcast        | 711.0 | 686.5 | 688.6 | 688.6 | 689.5 | 688.1 | 689.3 |
| gather           | 707.7 | 716.4 | 716.0 | 717.4 | 718.2 | 717.8 | 717.3 |
| scatter          | 709.5 | 742.2 | 744.3 | 746.4 | 745.1 | 746.1 | 746.7 |
| reduce_scatter   | 547.2 | 659.4 | 666.7 | 675.1 | 678.6 | 682.6 | 694.8 |
| all_gather       | 584.0 | 648.1 | 667.5 | 670.1 | 674.5 | 675.3 | 684.1 |
| all_reduce       | 639.5 | 676.4 | 684.9 | 687.6 | 690.0 | 691.4 | 840.6 |
| alltoall         | 657.8 | 694.4 | 695.1 | 679.9 | 682.1 | 651.9 | 676.3 |
| hypercube*       |   n/a |   n/a |   n/a |   n/a |   n/a |   n/a |   n/a |

\*Same nccl-tests 2.18.3 hypercube validation bug — values invalid, omitted.

**The 8-GPU column of Table 2 matches `results_b200.md` Table 1 almost exactly** (sendrecv 666, reduce 701, broadcast ~690, gather 717, scatter 746/747, reduce_scatter 695, all_gather 684, all_reduce 841, alltoall 675), confirming the b0012 sweep reproduces the b0027 baseline.

### Why Table 1 ≪ Table 2

NCCL bus bandwidth ramps steeply with message size: small messages are latency-bound and run far below peak. Table 1 averages those low points in; Table 2 takes only the converged 16 GB value. Example — 8-GPU all_reduce busbw per size: 47 (1M) → 126 → 269 → 421 → 652 → 729 → 829 → **841 (16G)**; the all-sizes mean is **489.6** (Table 1) while the 16 GB peak is **840.6** (Table 2). `results_b200.md` uses the latter convention.

**Notable:** all_reduce only reaches the 841 GB/s NVLS/NVSwitch-optimal peak at the full 8 GPUs; at 2–7 GPUs it sits at ~640–691 GB/s (ring/tree path), so the NVSwitch-optimal AllReduce algorithm engages specifically at the full power-of-2 node.

## Notes

- **8-GPU column matches the established baseline** in [`results_loop.md`](results_loop.md) (sendrecv 319, reduce 463, broadcast 454, gather 506, scatter 509, reduce_scatter 413, all_gather 405, all_reduce 489, alltoall 411) — the sweep is consistent with prior full-node runs.
- **sendrecv** is highest at 2 GPUs (382, direct NVLink pair) and settles to ~319 once ≥5 GPUs share the fabric.
- **reduce / broadcast** decline monotonically with GPU count (more ranks in the chain): ~512→463 and ~505→454.
- **reduce_scatter / all_gather / all_reduce / alltoall** rise with GPU count as the all-to-all NVLink fabric is better utilized, plateauing by ~4–6 GPUs (all_reduce jumps to 490 at 8 GPUs).
- **gather / scatter** are noisier across counts (~434–509) with no clean monotonic trend.
- All values are full-node NVLink (intra-node); no IB involved.

## Cross-reference

- Full per-collective 8-GPU tables and architecture baseline: [`results_b200.md`](results_b200.md), [`results_loop.md`](results_loop.md).
- Hypercube validation failure documented in memory `key_findings.md` (nccl-tests 2.18.3 bug).
- Raw log: `out-1node-sweep/nvhpc-26.3-sweep-b0012-33169`.
