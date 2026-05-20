# May 16, 2026 System Verification

Purpose: summarize the public v2 system verification result for Cambridge benchmark readiness.

This result verifies that same-day GPU topology, GDS, NCCL suite, and archive evidence were collected before benchmark workloads. It is not final benchmark certification evidence.

| Date | Cluster | Type | Status | Check Coverage | Campaign | Nodes | GPU Topology | GDS | NCCL Suite |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- |
| 2026-05-16 | rtxpro6000 | verification | passed | 4/4 | [report](campaign/campaign-rtxpro6000-2026-05-16.md) | [report](nodes/nodes-rtxpro6000-2026-05-16.md) | [report](gpu-topology/gpu-topology-rtxpro6000.md) | [report](gds/gds-rtxpro6000.md) | [report](nccl-suite/nccl-suite-rtxpro6000.md) |
| 2026-05-16 | b200 | verification | passed | 4/4 | [report](campaign/campaign-b200-2026-05-16.md) | [report](nodes/nodes-b200-2026-05-16.md) | [report](gpu-topology/gpu-topology-b200.md) | [report](gds/gds-b200.md) | [report](nccl-suite/nccl-suite-b200.md) |

## Public Bundles

| Cluster | Bundle | Checksum | Manifest | SHA256 |
| --- | --- | --- | --- | --- |
| rtxpro6000 | [tar.zst](https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/75d7da2/verification/2026-05-16/aicr-verification-campaign-2026-05-16-rtxpro6000.tar.zst) | [sha256](https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/75d7da2/verification/2026-05-16/aicr-verification-campaign-2026-05-16-rtxpro6000.tar.zst.sha256) | [json](https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/75d7da2/verification/2026-05-16/aicr-verification-campaign-2026-05-16-rtxpro6000-manifest.json) | `0fd3a1e3908608303e1f8d587e778b04ef1fe902ec8b9e275d16d89050014239` |
| b200 | [tar.zst](https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/75d7da2/verification/2026-05-16/aicr-verification-campaign-2026-05-16-b200.tar.zst) | [sha256](https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/75d7da2/verification/2026-05-16/aicr-verification-campaign-2026-05-16-b200.tar.zst.sha256) | [json](https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/75d7da2/verification/2026-05-16/aicr-verification-campaign-2026-05-16-b200-manifest.json) | `372fb6e334d0e4333dab1295309823d5f1f268fe7266ab9a927446c49e56af84` |

Top-level campaign manifest: [json](https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/75d7da2/verification/2026-05-16/aicr-verification-campaign-2026-05-16-manifest.json).

## Audit Boundary

These public pages are curated verification evidence for benchmark readiness. Public bundles retain report and manifest evidence; private VAST archives retain raw Slurm and operator-debug material for audit.

Candidate-node counts are derived from by-node JSON entries with overall `passed` status: rtxpro6000 has `16` strict candidates from `18` enumerated nodes, and b200 has `30` strict candidates from `30` enumerated nodes.
