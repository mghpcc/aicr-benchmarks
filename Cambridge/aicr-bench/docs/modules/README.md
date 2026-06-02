# Verification & Benchmarking Modules

Purpose: catalog the public AICR-Bench modules and explain the two-layer interface model.

AICR-Bench exposes two public layers:

- Scripts are workflow primitives for users building their own Slurm workflows, studies, reports, or automation.
- Make is the curated campaign driver that composes those primitives into repeatable runs, dashboards, and repo-standard artifact layouts.

Shared naming and workflow rules are in [Module conventions](conventions.md).

Each module has:

- `scripts.md`: primitive script interfaces.
- `make.md`: curated Make interface.
- `examples.md`: Slurm primitive examples, representative Make commands, and produced artifact lists.
- `studies.md`: fuller curated studies and reports.
- `test-plan.md`: executable coverage, HPC replay steps, known gaps, and acceptance criteria.

Use the module pages when learning a workflow:

- [Make driver](make-driver.md)
- [Install-tree GPU smoke suite](install-smoke.md)
- Verification and diagnostics
  - [GPU Topology](gpu-topology/)
  - [GPU Direct Storage (GDS)](gds/)
  - [NVIDIA Collective Communications Library (NCCL)](nccl/)
- Benchmarking
  - [Elbencho Storage Benchmarking](elbencho/)
  - [PyTorch DataLoader](dataloader/)
  - [PyTorch Distributed Data Parallel (DDP)](ddp/)
  - [HPL-MxP](hpl-mxp/)
