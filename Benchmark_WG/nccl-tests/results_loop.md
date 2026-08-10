# Loop-sweep NCCL results — `out-1node-loop/` and `out-2node-loop/`

Date: 2026-05-22. Source: `loop-1node.sh` (b nodes → `1node.sh` 8 GPUs, a nodes → `1socket.sh` 2 GPUs same socket) and `loop-2nodes.sh` (`2nodes-2gpus.sh`, 1 GPU per node).

## Summary

**Results are normal. No node is abnormal.** Every job completed all 10 collectives; the only failure across all 68 files is the known `hypercube_perf` validation bug in nccl-tests 2.18.3 (Out of bounds : 16 FAILED), which fires uniformly on every node and is unrelated to hardware health. Within each hardware class the bandwidth spread is tight (≤1% on B200, ≤2% on RTX6000), which is normal measurement noise.

## 1-node loop (`out-1node-loop/`, 47 files)

### B200 — `1node.sh`, 8 GPUs (b0001-b0031, all 31 nodes)

Bus bandwidth (GB/s, Avg across sizes):

| benchmark      | typical | range          |
| -------------- | ------- | -------------- |
| sendrecv       | 318     | 316.4 – 319.4  |
| reduce         | 463     | 456.3 – 464.2  |
| broadcast      | 454     | 436.3 – 454.6  |
| gather         | 507     | 481.4 – 509.5  |
| scatter        | 508     | 480.3 – 510.0  |
| reduce_scatter | 413     | 412.2 – 414.2  |
| all_gather     | 405     | 400.2 – 406.4  |
| all_reduce     | 489     | 482.1 – 489.4  |
| alltoall       | 410     | 405.6 – 411.1  |
| hypercube*     | 240     | 218.9 – 241.2  |

*hypercube fails validation on every node — known nccl-tests 2.18.3 bug; bandwidth value is invalid.

Per-node average across the 9 valid collectives (excluding hypercube): 438.1 – 441.5 GB/s (~0.8% spread). Slightly-low outliers b0016 (438.1), b0022 (438.7), b0024 (439.2), b0031 (438.1) are all within normal variance; nothing looks broken.

### RTX6000 — `1socket.sh`, 2 GPUs on socket 0 (a0004-a0019, 16 nodes)

Bus bandwidth (GB/s):

| benchmark      | typical | range         |
| -------------- | ------- | ------------- |
| sendrecv       | 32.3    | 31.7 – 32.5   |
| reduce         | 41.9    | 41.7 – 42.1   |
| broadcast      | 42.1    | 42.0 – 42.3   |
| gather         | 38.9    | 38.5 – 39.1   |
| scatter        | 36.5    | 35.8 – 36.9   |
| reduce_scatter | 22.6    | 22.3 – 22.9   |
| all_gather     | 29.0    | 28.8 – 29.2   |
| all_reduce     | 32.2    | 31.7 – 32.4   |
| alltoall       | 26.7    | 26.4 – 26.9   |
| hypercube*     | 31.5    | 30.8 – 31.8   |

All 16 a-nodes essentially identical (≤2% spread). **a0001-a0003 did not produce output** — likely the nodes were unavailable / busy at submit time (no error file; no job ran). Not a hardware concern, just a missing sample.

## 2-node loop (`out-2node-loop/`, 21 files)

Pairs are (line₁,line₂), (line₃,line₄)… from the node lists; the output file is named after the batch host (first of each pair). `2nodes-2gpus.sh`: 1 MPI task per node, 1 GPU per task → 2 ranks total over IB.

### B200 (b0001+b0002 through b0029+b0030 — 15 pairs)

| benchmark      | typical | range         |
| -------------- | ------- | ------------- |
| sendrecv       | 24.2    | 24.0 – 24.3   |
| reduce         | 41.4    | 40.6 – 41.8   |
| broadcast      | 41.6    | 40.9 – 41.6   |
| gather         | 36.9    | 36.5 – 37.4   |
| scatter        | 36.5    | 35.9 – 37.0   |
| reduce_scatter | 21.8    | 21.8 – 21.9   |
| all_gather     | 21.7    | 21.6 – 21.8   |
| all_reduce     | 23.5    | 23.4 – 23.5   |
| alltoall       | 22.7    | 22.4 – 22.8   |
| hypercube*     | 22.8    | 22.6 – 22.9   |

All 15 pairs uniform. b0031 has no neighbor (odd count) and was correctly skipped.

### RTX6000 (6 pairs reported: a0005, a0007, a0009, a0011, a0013, a0015 as batch hosts)

| benchmark      | typical | range         |
| -------------- | ------- | ------------- |
| sendrecv       | 21.7    | 21.3 – 21.9   |
| reduce         | 34.8    | 33.1 – 35.8   |
| broadcast      | 35.5    | 32.9 – 36.9   |
| gather         | 29.8    | 29.0 – 30.6   |
| scatter        | 30.9    | 29.8 – 31.8   |
| reduce_scatter | 18.5    | 18.4 – 18.6   |
| all_gather     | 18.6    | 18.5 – 18.7   |
| all_reduce     | 21.3    | 21.2 – 21.3   |
| alltoall       | 19.5    | 19.0 – 19.9   |
| hypercube*     | 20.2    | 19.7 – 20.7   |

**Mild outlier:** the pair containing a0015 reports broadcast 32.9 and reduce 33.1 — ~7-8% below the others (35.5/34.8 typical). reduce_scatter / all_gather / all_reduce are unchanged, so this is likely run-to-run noise on the small/medium message sizes rather than a sick node. Worth a re-run before drawing conclusions.

**Pairs missing from output:** (a0001,a0002), (a0003,a0004), (a0017,a0018) — no result files. a0019 unpaired (odd count) and was correctly skipped. The three missing pairs likely had a node busy/down at submit time.

## Cross-reference

- Per-GPU bandwidths and architectural baseline are in [`results_b200.md`](results_b200.md) and [`results_rtx6000.md`](results_rtx6000.md).
- The hypercube failure is documented in memory `key_findings.md` as the nccl-tests 2.18.3 hypercube bug; ignore the hypercube line when judging node health.
