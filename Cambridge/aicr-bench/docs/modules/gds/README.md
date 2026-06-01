# GPU Direct Storage

Purpose: navigate the public GDS module.

GDS validates host CUDA/GDS tooling with `gdscheck -p` and profile-selected `gdsio` phases.

## Verify-stack role

This module is part of the AICR verify stack. Use it to validate hardware,
storage, or communication readiness before interpreting workload benchmark
modules. Treat collected rates, topology signatures, and pass/fail rows as
validation evidence, not benchmark-result evidence.

GDS is a storage-backed readiness check for CUDA/GDS and filesystem behavior.
It belongs with GPU Topology and NCCL as validation evidence, not as a
standalone benchmark-result module.

- [Script interface](scripts.md)
- [Make interface](make.md)
- [Examples](examples.md)
- [Studies](studies.md)
- [Test plan](test-plan.md)

Examples start with the Slurm primitive file for custom automation, then show the curated Make implementation.
