# Verification Script Catalog

Purpose: map system verification implementation scripts to their normal Make entrypoints.

Use Make as the normal interface for verification. Direct script invocation is a low-level implementation interface for focused troubleshooting, explicit dry-runs, or Slurm-wrapper development.

Run verification commands from the repo root so `benchmark-settings.env` resolves through `SLURM_SUBMIT_DIR`.

## Normal Make Entrypoints

| Make target | Normal role |
| --- | --- |
| `make system-verify` | Benchmark-day system state capture across topology, GDS, and NCCL suite checks. |
| `make verify-topology` | Preview or submit GPU topology verification. |
| `make verify-gds` | Preview or submit GDS verification. |
| `make verify-nccl-suite` | Preview or submit the standard rank-per-GPU NCCL suite. |

## Script Roles

| Script | Called by | Direct use | Role |
| --- | --- | --- | --- |
| `run-gpu-topology-fleet.sh` | `make verify-topology` | Advanced | Dry-run-first fleet submitter for GPU topology evidence. |
| `run-gpu-topology.sh` | Slurm wrapper | Internal | Slurm-side GPU topology collector. |
| `run-gds-fleet.sh` | `make verify-gds` | Advanced | Dry-run-first fleet submitter for GDS readiness. |
| `run-gds.sh` | Slurm wrapper | Internal | Slurm-side GDS runner and parser wrapper. |
| `submit-nccl-suite.sh` | `make verify-nccl-suite` | Advanced | Dry-run-first NCCL suite scale/local/RDMA submit helper. |
| `run-nccl-suite.sh` | Slurm wrapper | Internal | Slurm-side standard NCCL suite runner. |
| `smoke-test-pytorch.sh` | setup smoke workflow | Internal | PyTorch container setup smoke check. |
| `smoke-test-hpc-benchmarks.sh` | setup smoke workflow | Internal | NVIDIA HPC Benchmarks container smoke check. |
| `smoke-test-elbencho.sh` | setup smoke workflow | Internal | Elbencho runtime smoke check. |
| `check-container-compat.sh` | setup gate | Internal | Container compatibility check. |

## Direct Script Rules

- Prefer the Make target unless a runbook section explicitly says direct script use is advanced troubleshooting.
- Keep dry-run behavior unless the script and runbook both say `--apply` is expected.
- Do not call Slurm-side runners directly from the laptop; they are normally invoked by Slurm wrappers.
- Keep generated raw and parsed evidence out of Git unless a review artifact is explicitly promoted.
