# Single-node B200 GPU-count sweep — `out-1node-sweep/`

Date: 2026-06-03. Source: `sweep-gpus-1node.sh` (job 33169, node **b0012**, partition `b200-batch`, `--exclusive`).
Single MPI task, NCCL bus bandwidth swept over GPU counts 2→8 (`-g N`), all 10 collectives, message sizes 1M→16G (4× steps), nccl-tests 2.18.3 / NVHPC 26.3.

## Avg bus bandwidth (GB/s) vs number of GPUs

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
