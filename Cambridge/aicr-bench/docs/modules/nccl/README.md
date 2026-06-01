# NCCL

Purpose: navigate the NCCL module.

NCCL exercises local, RDMA, and rank-per-GPU scale communication paths with the fully instrumented NCCL suite.

## Verify-stack role

This module is part of the AICR verify stack. Use it to validate hardware,
storage, or communication readiness before interpreting workload benchmark
modules. Treat collected rates, topology signatures, and pass/fail rows as
validation evidence, not benchmark-result evidence.

NCCL is the communication validation layer for local GPU, RDMA, and rank-per-GPU
scale paths. It belongs with GPU Topology and GDS as verify-stack evidence, not
as a standalone benchmark-result module.

- [Script interface](scripts.md)
- [Make interface](make.md)
- [Examples](examples.md)
- [Studies](studies.md)
- [Test plan](test-plan.md)

Examples start with the Slurm primitive file for custom automation, then show the curated Make implementation.
