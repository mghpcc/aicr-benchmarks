# HPL-MxP

Purpose: navigate the NVIDIA HPL-MxP benchmark module.

HPL-MxP runs NVIDIA HPC Benchmarks container shapes with explicit matrix size,
block size, process grid, [affinity controls](placement.md), residual
validation, and PFLOPS reporting.

- [Script interface](scripts.md)
- [Make interface](make.md)
- [Examples](examples.md)
- [Studies](studies.md)
- [Test plan](test-plan.md)

The public module has two layers:

- `make benchmark-hpl-mxp` is the curated dry-run-first entrypoint for smoke,
  staged, campaign-candidate, and weak-study rows.
- [submit-hpl-mxp.sh](../../../man/submit-hpl-mxp.md) and
  [run-hpl-mxp.sh](../../../man/run-hpl-mxp.md) are the lower-level Slurm
  submission and allocation-side primitives.
