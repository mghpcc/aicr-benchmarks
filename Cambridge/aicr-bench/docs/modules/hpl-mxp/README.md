# HPL-MxP

Purpose: navigate the NVIDIA HPL-MxP benchmark module.

HPL-MxP runs NVIDIA HPC Benchmarks container shapes with explicit matrix size,
block size, process grid, [affinity controls](placement.md), residual
validation, and PFLOPS reporting.

## Benchmark-result role

HPL-MxP is a workload benchmark-result module once rows have completed,
rendered, and been linked to public artifacts and provenance. It is not a
verify-stack diagnostic module. Use GPU Topology, GDS, and NCCL readiness
evidence to interpret the platform context before comparing HPL-MxP public
result rows.

What HPL-MxP is not: treat HPL-MxP rows as workload benchmark-result evidence,
not verify-stack readiness evidence. Readiness, topology, communication, and
storage-path diagnostic claims belong on the GPU Topology, GDS, and NCCL study
pages. HPL-MxP rows assume those readiness checks already pass for the selected
nodes.

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
