# GPU Topology Readiness Dashboard - 2026-05-16

<!-- aicr-study-status: published -->

Purpose: summarize module-local GPU topology readiness evidence for the Cambridge benchmark campaign.

GPU topology is readiness evidence, not a performance study. It records whether
the selected nodes expose the expected GPUs and whether the fleet has coherent
CPU/GPU/NIC topology before benchmark execution.

## Summary

| Cluster | Nodes Considered | Passed | Skipped | Expected GPUs Per Node | Fleet Consistency |
| --- | ---: | ---: | ---: | ---: | --- |
| B200 | 30 | 30 | 0 | 8 | 30/30 majority signature |
| RTX Pro 6000 | 18 | 16 | 2 | 8 | 16/16 majority signature |

## B200 Readiness

The B200 topology collection covered `b0002-b0031`. Every collected node
reported eight NVIDIA B200 GPUs, passed the GPU model and count checks, and
contributed structured CPU/GPU/NIC topology rows.

| Signal | Result |
| --- | --- |
| Passed nodes | 30 |
| Skipped nodes | 0 |
| GPU count | 8/8 on every collected node |
| GPU model check | Pass on every collected node |
| Topology parse | Pass on every collected node |
| CPU topology parse | Pass on every collected node |
| Structured topology rows | 30/30 |
| Majority topology signature | 30/30 |
| Outlier nodes | None |

Representative B200 topology pattern:

```text
GPU NUMA: 0:1, 1:2, 2:3, 3:0, 4:5, 5:6, 6:7, 7:4
GPU7 PIX NICs: mlx5_11, mlx5_12
Storage path observed: nfs:storage0001.nfs:/work
```

## RTX Pro 6000 Readiness

The RTX Pro 6000 topology collection considered `a0002-a0019`. Sixteen nodes
were collected successfully. Two nodes were skipped because their Slurm states
were not ready for collection at the time of the run.

| Signal | Result |
| --- | --- |
| Passed nodes | 16 |
| Skipped nodes | 2 |
| Skipped states | `a0017` drained, `a0018` mixed |
| GPU count | 8/8 on every collected node |
| GPU model check | Pass on every collected node |
| Topology parse | Pass on every collected node |
| CPU topology parse | Pass on every collected node |
| Structured topology rows | 16/16 |
| Majority topology signature | 16/16 |
| Outlier nodes | None |

Representative RTX topology pattern:

```text
GPU NUMA: 0:1, 1:2, 2:3, 3:0, 4:5, 5:6, 6:7, 7:4
Nearest NIC pattern on collected nodes: SYS for GPU0/GPU7, PIX examples on GPU2/GPU3/GPU4
Skipped nodes: a0017, a0018
```

## Readiness Use

This dashboard answers a narrow question: whether topology evidence was
sufficient to use these nodes for benchmark and test interpretation. It does
not rank nodes, tune parameters, or claim a performance result.

For future collections, use [run-gpu-topology-fleet.sh](../../../../man/run-gpu-topology-fleet.md)
or `make verify-topology`, then summarize the node counts, skipped nodes,
majority signature count, and outliers in this same module-local format.

## Artifact Bundle

| Item | Path |
| --- | --- |
| VAST bundle | `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/e116635/gpu-topology/2026-05-16/gpu-topology-readiness-dashboard-2026-05-16.tar.gz` |
| VAST provenance | `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/e116635/gpu-topology/2026-05-16/gpu-topology-readiness-dashboard-2026-05-16-provenance.json` |
| OSN bundle | <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/e116635/gpu-topology/2026-05-16/gpu-topology-readiness-dashboard-2026-05-16.tar.gz> |
| OSN provenance | <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/e116635/gpu-topology/2026-05-16/gpu-topology-readiness-dashboard-2026-05-16-provenance.json> |
| OSN checksum | <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/e116635/gpu-topology/2026-05-16/gpu-topology-readiness-dashboard-2026-05-16.sha256> |
| SHA-256 | `4dc9e0467a264423abca821a04f8e838607e55c509b77dd2fcc062b0edcc57f1` |

The artifact path uses public commit `e116635`; later documentation commits may
clarify prose while preserving this evidence bundle.

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gpu-topology-readiness-dashboard
cd public-study-artifacts/gpu-topology-readiness-dashboard
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/e116635/gpu-topology/2026-05-16/gpu-topology-readiness-dashboard-2026-05-16.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/e116635/gpu-topology/2026-05-16/gpu-topology-readiness-dashboard-2026-05-16.sha256
sha256sum -c gpu-topology-readiness-dashboard-2026-05-16.sha256
tar -tzf gpu-topology-readiness-dashboard-2026-05-16.tar.gz | head
```
