# Cambridge

Purpose: Cambridge AICR benchmark evidence package for review.

Start with [SOW conformance 2026-05-16](sow-conformance-2026-05-16.md) for the requirement-by-requirement map. The package includes final benchmark summaries, May 16 system verification evidence, runbooks, selected public artifacts, and the embedded [aicr-bench](aicr-bench/README.md) tooling used to render and validate the reports.

## Benchmark Campaign Results

| Date Run | Cluster | Type | Status | Check Coverage | Report |
| --- | --- | --- | --- | ---: | --- |
| 2026-05-16 | rtxpro6000 | benchmarking | completed | 3/3 | [report](reports/2026-05-16/benchmarks/rtxpro6000.md) |
| 2026-05-16 | b200 | benchmarking | completed | 4/4 | [report](reports/2026-05-16/benchmarks/b200.md) |

Check Coverage counts benchmark categories with completed public result pages: rtxpro6000 covers DataLoader, ResNet-50 DDP, and HPL-MxP; b200 covers those three plus Elbencho storage. Runbooks are listed on the individual benchmark report pages.

## SOW Status

All tracked SOW requirements are met except the Elbencho peak-cluster shape, which is marked `Partial` in [SOW conformance](sow-conformance-2026-05-16.md#elbencho-storage). The current public Elbencho evidence includes five 30-node B200 samples on `b0002-b0031`; the remaining supplemental item is a future 31-node B200 peak-cluster row when `b0001` is available.

## System Verification Evidence

This section records the May 16, 2026 v2 system verification evidence used to select nodes for the weekend AICR benchmark campaign. It is readiness evidence for benchmark execution, not final benchmark certification evidence.

| Date | Cluster | Type | Status | Check Coverage | Campaign | Nodes | GPU Topology | GDS | NCCL Suite |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- |
| 2026-05-16 | rtxpro6000 | verification | passed | 4/4 | [report](reports/2026-05-16/verification/campaign/campaign-rtxpro6000-2026-05-16.md) | [report](reports/2026-05-16/verification/nodes/nodes-rtxpro6000-2026-05-16.md) | [report](reports/2026-05-16/verification/gpu-topology/gpu-topology-rtxpro6000.md) | [report](reports/2026-05-16/verification/gds/gds-rtxpro6000.md) | [report](reports/2026-05-16/verification/nccl-suite/nccl-suite-rtxpro6000.md) |
| 2026-05-16 | b200 | verification | passed | 4/4 | [report](reports/2026-05-16/verification/campaign/campaign-b200-2026-05-16.md) | [report](reports/2026-05-16/verification/nodes/nodes-b200-2026-05-16.md) | [report](reports/2026-05-16/verification/gpu-topology/gpu-topology-b200.md) | [report](reports/2026-05-16/verification/gds/gds-b200.md) | [report](reports/2026-05-16/verification/nccl-suite/nccl-suite-b200.md) |

Runbook and archive:

- [Verification runbook](verification-runbook-2026-05-16.md): provenance command trail for GPU topology, GDS, NCCL, archive, render, and validation evidence.
- [Verification report index](reports/2026-05-16/verification/README.md): curated public dashboard for the May 16 verification result.
- Public campaign manifest: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/75d7da2/verification/2026-05-16/aicr-verification-campaign-2026-05-16-manifest.json>

## Resources

- [aicr-bench](aicr-bench/README.md): AICR HPC support workflows, public command docs, report renderers, and validation checks.
- [ImageNet dataset preparation](aicr-bench/docs/resources/imagenet.md): operator-managed ImageNet acquisition, validation split preparation, and layout checks for DataLoader and DDP.
