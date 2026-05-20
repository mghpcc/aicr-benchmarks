# AICR Benchmarking SOW Conformance - 2026-05-16

This page maps the AICR Benchmarking Campaign Expected Metrics and Results memo (v2, February 27, 2026) to the public Cambridge benchmark evidence.

The May 16 campaign collected benchmark evidence with parameters tuned from the system behavior observed during commissioning, including improved DataLoader scaling settings. The May 17 supplemental rows then filled in the exact memo-listed shapes and comparison points where the campaign evidence was broader, better tuned, or a superset of the requested grid.

Status terms: `Met`, `Met (superset)`, `Met with supplemental evidence`, `Partial`.

OFAT means one-factor-at-a-time: a sweep that varies one benchmark parameter while holding the rest of the run shape fixed.

## System Verification

| Requirement | May 16 campaign evidence | May 17 supplemental evidence | Status |
| --- | --- | --- | --- |
| Verified benchmark node pool before benchmark publication | [System verification evidence](README.md#system-verification-evidence) with per-cluster dashboards, node dashboards, archive manifests, and checksums | None | Met |
| Public readiness and provenance evidence | [Verification report index](reports/2026-05-16/verification/README.md) and [verification runbook](verification-runbook-2026-05-16.md) | None | Met |

## DataLoader

| Requirement | May 16 campaign evidence | May 17 supplemental evidence | Status |
| --- | --- | --- | --- |
| ImageNet ILSVRC2012 dataset, approximately 1.28M training images | [ImageNet dataset preparation](aicr-bench/docs/resources/imagenet.md) documents acquisition, validation-split preparation, layout checks, and the validated `1,281,167` training-image count; [B200](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#run-shape) and [RTX](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#run-shape) run-shape tables confirm campaign use | None | Met |
| PyTorch CPU DataLoader with `torchvision.datasets.ImageFolder` | [B200 DataLoader](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#run-shape) and [RTX DataLoader](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#run-shape) report PyTorch CPU ImageFolder input | None | Met |
| Scope: B200 and RTX Pro 6000 | Cluster benchmark summaries include completed DataLoader rows for [B200](reports/2026-05-16/benchmarks/b200.md#benchmark-results) and [RTX Pro 6000](reports/2026-05-16/benchmarks/rtxpro6000.md#benchmark-results) | None | Met |
| `num_workers` sweep `{2,4,8,16,32}` | May 16 campaign collected worker OFAT rows in [B200](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#ofat-sweep-coverage) and [RTX](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#ofat-sweep-coverage) coverage tables | SOW-value rows in [B200 supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#sow-shape-supplemental-rows) and [RTX supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#sow-shape-supplemental-rows): `{2,4,8,32}` plus May 17 `16` baseline | Met with supplemental evidence |
| `batch_size` sweep `{64,128,256,512}` | May 16 campaign collected batch OFAT rows in [B200](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#ofat-sweep-coverage) and [RTX](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#ofat-sweep-coverage) coverage tables | SOW-value rows in [B200 supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#sow-shape-supplemental-rows) and [RTX supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#sow-shape-supplemental-rows): `{64,128,256,512}` | Met with supplemental evidence |
| `prefetch_factor` sweep `{2,4,8}` | May 16 campaign collected `{2,4,6,8}` in [B200](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#ofat-sweep-coverage) and [RTX](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#ofat-sweep-coverage) coverage tables | SOW-value rows in [B200 supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#sow-shape-supplemental-rows) and [RTX supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#sow-shape-supplemental-rows) collected `{2,8}` with May 17 baseline `4` | Met (superset) |
| `pin_memory` `{True,False}` | May 16 campaign collected both values in [B200](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#ofat-sweep-coverage) and [RTX](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#ofat-sweep-coverage) coverage tables | SOW-value pin comparison in [B200 supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#sow-shape-supplemental-rows) and [RTX supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#sow-shape-supplemental-rows) collected at the SOW base shape | Met |
| Concurrent nodes `{1,4,8,16}` | [B200 final scale](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#final-scale-results) collected `{1,2,4,8,16}`; [RTX final scale](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#final-scale-results) collected `{1,2,4}` | [B200 supplemental scale](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#sow-shape-result-summary) collected `{4,8,16}` at batch `512`; [RTX supplemental scale](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#sow-shape-result-summary) collected `{4,8,16}` at batch `512` | Met with supplemental evidence |
| Images/sec per GPU, per node, and aggregate | Published in [B200 final scale](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#final-scale-results) and [RTX final scale](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#final-scale-results) result tables | Collected in [B200 supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#sow-shape-result-summary) and [RTX supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#sow-shape-result-summary) result tables | Met |
| Batch load time in ms/batch | Published as `Load ms/batch` in [B200 final scale](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#final-scale-results) and [RTX final scale](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#final-scale-results) tables | Supplemental rows retain the same raw metric in the linked [B200](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#artifacts-and-provenance) and [RTX](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#artifacts-and-provenance) CSV/JSON artifacts | Met |
| Workload-observed VAST read bandwidth aggregate | Published as `Estimated VAST read GB/s from JPEG bytes` in [B200 final scale](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#final-scale-results) and [RTX final scale](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#final-scale-results), computed from ImageFolder JPEG bytes consumed by the DataLoader workload | Collected in [B200 supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#sow-shape-result-summary) and [RTX supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#sow-shape-result-summary) result tables | Met |
| CPU utilization per worker process | Published as worker mean CPU utilization in [B200 final scale](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#final-scale-results) and [RTX final scale](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#final-scale-results) tables | Collected in [B200 supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#sow-shape-result-summary) and [RTX supplemental](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#sow-shape-result-summary) result tables | Met |

Supplemental rows: [B200 DataLoader](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md#sow-shape-supplemental-rows), [RTX DataLoader](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md#sow-shape-supplemental-rows).

## ResNet-50 DDP

| Requirement | May 16 campaign evidence | May 17 supplemental evidence | Status |
| --- | --- | --- | --- |
| ResNet-50 model | [B200 DDP](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-b200-2026-05-16.md) and [RTX DDP](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-rtxpro6000-2026-05-16.md) reports | None | Met |
| PyTorch DDP with NCCL backend and `torchrun` | DDP [B200 run shape](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-b200-2026-05-16.md#run-shape), [RTX run shape](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-rtxpro6000-2026-05-16.md#run-shape), and command runbooks | None | Met |
| ImageNet ILSVRC2012 dataset | [B200 DDP](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-b200-2026-05-16.md#run-shape) and [RTX DDP](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-rtxpro6000-2026-05-16.md#run-shape) run-shape tables report ImageNet input | None | Met |
| B200 scale `{1,4,8,16}` nodes | [B200 DDP result table](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-b200-2026-05-16.md#results) includes `{1,4,8,16}` | None | Met |
| RTX Pro 6000 scale `{1,4}` nodes | [RTX DDP result table](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-rtxpro6000-2026-05-16.md#results) includes `{1,2,4}` | None | Met (superset) |
| Training throughput in images/sec | Published for every DDP row in [B200 results](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-b200-2026-05-16.md#results) and [RTX results](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-rtxpro6000-2026-05-16.md#results) | None | Met |
| Time per epoch in minutes | Published as `Epoch min` in [B200 results](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-b200-2026-05-16.md#results) and [RTX results](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-rtxpro6000-2026-05-16.md#results) | None | Met |
| Scaling efficiency | Published as `Scaling efficiency %` in [B200 results](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-b200-2026-05-16.md#results) and [RTX results](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-rtxpro6000-2026-05-16.md#results) | None | Met |

## HPL-MxP

| Requirement | May 16 campaign evidence | May 17 supplemental evidence | Status |
| --- | --- | --- | --- |
| NVIDIA HPC Benchmarks 25.04 or newer, Apptainer/Singularity | NVIDIA HPC Benchmarks 26.02 with Apptainer in [B200 HPL-MxP](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md) and [RTX HPL-MxP](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md) | None | Met |
| FP16 LU with FP64 iterative refinement | `workspace-fp16` preset and residual pass counts in [B200 run shape/results](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md#run-shape) and [RTX run shape/results](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md#run-shape) | None | Met |
| Problem size near 90% of GPU memory | May 16 HPC Benchmarks weak-scaling matrix ladder in [B200 matrix ladder](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md#matrix-ladder) and [RTX matrix ladder](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md#matrix-ladder) | 3-sample SOW-shape supplemental evidence in [B200 supplemental rows](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md#sow-shape-supplemental-rows) and [RTX supplemental rows](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md#sow-shape-supplemental-rows) | Met with supplemental evidence |
| B200 scale `{1,4,16}` nodes | [B200 HPL-MxP results](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md#results) include `{1,2,4,8,16}` | [B200 SOW-shape rows](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md#sow-shape-supplemental-rows) include `{1,4,16}` | Met (superset) |
| RTX Pro 6000 scale `{1,4}` nodes | [RTX HPL-MxP results](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md#results) include `{1,2,4}` | [RTX SOW-shape rows](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md#sow-shape-supplemental-rows) include `{1,4}` | Met (superset) |
| Performance in PFLOPS, FP64-equivalent | Published for every HPL-MxP row in [B200 results](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md#results) and [RTX results](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md#results) | Published for [B200 supplemental](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md#sow-shape-supplemental-rows) and [RTX supplemental](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md#sow-shape-supplemental-rows) rows | Met |
| Residual check pass/fail | Published as residual pass count in [B200 results](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md#results) and [RTX results](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md#results) | Published for [B200 supplemental](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md#sow-shape-supplemental-rows) and [RTX supplemental](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md#sow-shape-supplemental-rows) rows | Met |

Supplemental rows: [B200 HPL-MxP](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md#sow-shape-supplemental-rows), [RTX HPL-MxP](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md#sow-shape-supplemental-rows).

## Elbencho Storage

| Requirement | May 17 campaign evidence | Pending supplemental evidence | Status |
| --- | --- | --- | --- |
| B200 storage benchmark scope | [B200 Elbencho](reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md) uses B200 GPU2 client nodes and `/scratch/csim/elbencho` target root | None | Met |
| Small-block workload | [One-node small-block sweep](reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md#one-node-parameter-sweep-table) collected threads `32,64,128` by I/O depth `16,32`; [selected repeat rows](reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md#confirmation-repeat-results) collected five samples | None | Met |
| Small-file workload | [One-node small-file sweep](reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md#one-node-parameter-sweep-table) collected threads `32,64,128` by I/O depth `16,32`; [selected repeat rows](reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md#confirmation-repeat-results) collected five samples | None | Met |
| Metadata workload | [One-node metadata sweep](reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md#one-node-parameter-sweep-table) collected threads `32,64,128` without an explicit I/O-depth option; [selected repeat rows](reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md#confirmation-repeat-results) collected five samples | None | Met |
| Peak-cluster workload | [30-node peak-cluster rows](reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md#30-node-peak-cluster-results) collected five samples on `b0002-b0031` | 31-node peak-cluster row when `b0001` is available | Partial |
| Reported storage metrics | [B200 Elbencho](reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md#one-node-parameter-sweep-table) reports read/write MiB/s, read/write IOPS where applicable, small-file operation rates, and metadata operation rates | None | Met |

## Public Evidence Index

| Evidence | Location |
| --- | --- |
| B200 benchmark summary | [reports/2026-05-16/benchmarks/b200.md](reports/2026-05-16/benchmarks/b200.md) |
| RTX Pro 6000 benchmark summary | [reports/2026-05-16/benchmarks/rtxpro6000.md](reports/2026-05-16/benchmarks/rtxpro6000.md) |
| B200 DataLoader | [reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md](reports/2026-05-16/benchmarks/dataloader/dataloader-b200-2026-05-16.md) |
| RTX DataLoader | [reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md](reports/2026-05-16/benchmarks/dataloader/dataloader-rtxpro6000-2026-05-16.md) |
| B200 ResNet-50 DDP | [reports/2026-05-16/benchmarks/ddp/ddp-resnet50-b200-2026-05-16.md](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-b200-2026-05-16.md) |
| RTX ResNet-50 DDP | [reports/2026-05-16/benchmarks/ddp/ddp-resnet50-rtxpro6000-2026-05-16.md](reports/2026-05-16/benchmarks/ddp/ddp-resnet50-rtxpro6000-2026-05-16.md) |
| B200 HPL-MxP | [reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-b200-2026-05-16.md) |
| RTX HPL-MxP | [reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md](reports/2026-05-16/benchmarks/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md) |
| B200 Elbencho | [reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md](reports/2026-05-17/benchmarks/elbencho/elbencho-b200-2026-05-17.md) |
| Verification report index | [reports/2026-05-16/verification/README.md](reports/2026-05-16/verification/README.md) |
