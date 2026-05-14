# Profiling & Benchmarking Modules

Purpose: catalog the public AICR-Bench modules and explain the two-layer interface model.

AICR-Bench exposes two public layers:

- Scripts are benchmark primitives for users building their own Slurm workflows, studies, reports, or automation.
- Make is the curated campaign driver that composes those primitives into repeatable runs, dashboards, and repo-standard artifact layouts.

Shared naming and workflow rules are in [Module conventions](conventions.md).

Each module has:

- `scripts.md`: primitive script interfaces.
- `make.md`: curated Make interface.
- `examples.md`: Slurm primitive examples, representative Make commands, and produced artifact lists.
- `studies.md`: fuller curated studies and reports.

Use the module pages when learning a workflow:

- [Make driver](make-driver.md)
- [GDS](gds/)
- [NCCL](nccl/)
- [DataLoader](dataloader/)
- [DDP ResNet-50](ddp/)
- [HPL-MxP](hpl-mxp/)
