# AICR-Bench

AICR-Bench install tree with Slurm + Apptainer workflows for focused GPU support checks on AICR HPC systems.

Supported GPU profiles:

- `rtxpro6000`: GPU1 partition, nodes `a0001-a0019`, 8x RTX PRO 6000.
- `b200`: GPU2 partition, nodes `b0001-b0031`, 8x B200.

Run commands from this install root so `benchmark-settings.env` resolves through `SLURM_SUBMIT_DIR`. Runtime assets live outside Git checkouts under `/work/aicr/commissioning/benchmarks/runtime` by default and are refreshed only by explicit operator action.

The public docs use a two-layer model. Scripts are benchmark primitives for users building their own Slurm workflows, studies, reports, or automation. Make is the curated campaign driver that composes those primitives into repeatable runs, dashboards, and repo-standard artifact layouts.

## Use

Run AICR-Bench commands from the `Cambridge/aicr-bench` directory:

```bash
cd Cambridge/aicr-bench
cp benchmark-settings.env.example benchmark-settings.env
make setup-python-local
make doctor-python
```

## Profiling & Benchmarking Modules

- [Make driver](docs/modules/make-driver.md)
- [GPU Topology](docs/modules/gpu-topology/)
- [GPU Direct Storage (GDS)](docs/modules/gds/)
- [NVIDIA Collective Communications Library (NCCL)](docs/modules/nccl/)
- [PyTorch DataLoader](docs/modules/dataloader/)
- [PyTorch Distributed Data Parallel (DDP)](docs/modules/ddp/)
- [HPL-MxP](docs/modules/hpl-mxp/)
- [Elbencho](docs/modules/elbencho/)

## Reference

- [Command reference](man/README.md)
- [Module conventions](docs/modules/conventions.md)
- [Resources](docs/resources/README.md)
- [Runtime assets and containers](docs/runtime.md)
