# Cambridge

Purpose: Cambridge AICR benchmark evidence package for public review.

Start with the [May 16, 2026 Cambridge report navigation](reports/2026-05-16/README.md). It links to the benchmark campaign results, system verification evidence, and memo conformance map.

## Resources

| Resource | Use |
| --- | --- |
| [aicr-bench](aicr-bench/README.md) | Public benchmark tooling, command docs, report renderers, validation checks, and repeatable Slurm + Apptainer workflows for AICR HPC systems. |
| [ImageNet dataset preparation](aicr-bench/docs/resources/imagenet.md) | ImageNet acquisition, validation split preparation, and layout checks for DataLoader and DDP. |

## aicr-bench

`aicr-bench` is the public benchmark and verification toolkit used to collect,
render, validate, and package the Cambridge evidence. It supports two public GPU
profiles: `rtxpro6000` nodes with 8x RTX PRO 6000 GPUs and `b200` nodes with 8x
B200 GPUs.

The toolkit has two layers:

- Scripts provide benchmark primitives for users building Slurm workflows,
  studies, reports, or automation.
- The Make interface composes those primitives into repeatable runs, dashboards,
  and repo-standard artifact layouts.

Supported modules include:

- System verification: GPU topology, GPU Direct Storage, and NCCL.
- Benchmark campaign workloads: Elbencho storage, PyTorch DataLoader,
  PyTorch Distributed Data Parallel ResNet-50, and HPL-MxP.
- Documentation and validation utilities: command references, docs checks,
  report renderers, artifact policy checks, and runtime/container guidance.
