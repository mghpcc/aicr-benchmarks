# Benchmark Script Catalog

Purpose: map benchmark implementation scripts to their normal Make entrypoints.

Use Make as the normal interface for verification and benchmark execution. Direct script invocation is a low-level implementation interface for debugging, focused tuning, or Slurm-wrapper development.

Run benchmark submission commands from the repo root so `benchmark-settings.env` resolves through `SLURM_SUBMIT_DIR`.

NCCL system verification and RTX NCCL diagnostics live under `scripts/verify/` and `scripts/debug/`; they are intentionally not cataloged as Benchmark 0-3 surfaces here.

## Normal Make Entrypoints

| Make target | Normal role |
| --- | --- |
| `make benchmark-dry-run-suite` | Benchmark submission preflight; prints planned `sbatch` shapes and submits no Slurm jobs. |
| `make benchmark-elbencho` | Preview or submit Benchmark 0 Elbencho storage rows. |
| `make benchmark-dataloader` | Preview or submit Benchmark 1 DataLoader sweeps and scale rows. |
| `make benchmark-ddp-resnet50` | Preview or submit Benchmark 2 ResNet-50 DDP rows. |
| `make benchmark-hpl-mxp` | Guarded HPL-MxP entrypoint; `HPL_MXP_PRESET` selects smoke, staged, campaign-candidate, or weak-study rows. |
| `make install-elbencho` | Preview or install the shared Elbencho runtime image. |

## Script Roles

| Script | Called by | Direct use | Role |
| --- | --- | --- | --- |
| `dry-run-suite.sh` | `make benchmark-dry-run-suite` | Operator preflight only | Prints DataLoader, DDP, HPL-MxP, and Elbencho submission shapes. Submits no jobs. |
| `submit-elbencho.sh` | `make benchmark-elbencho` | Advanced | Dry-run-first Slurm submit helper for reviewed Elbencho `PROFILE=<smoke|small>` command templates. |
| `run-elbencho.sh` | Slurm wrapper | Internal | Slurm-side Elbencho runner with raw/parsed artifact capture. |
| `install-elbencho-runtime.sh` | `make install-elbencho` | Advanced | Installs or checks the shared Elbencho Apptainer runtime. |
| `submit-dataloader.sh` | `make benchmark-dataloader` | Advanced | Dry-run-first Slurm submit helper for DataLoader rows. |
| `sweep-dataloader.sh` | DataLoader docs and tuning flows | Advanced | Fans list-based DataLoader sweeps through the submit helper. |
| `run-dataloader.sh` | Slurm wrapper | Internal | Slurm-side DataLoader runner with canonical artifacts and parser output. |
| `run-dataloader-workload.py` | `run-dataloader.sh` | Internal | In-container PyTorch DataLoader workload. |
| `prepare-dataloader-derived-dataset.py` | DataLoader input lab | Advanced | Builds explicit-root derived ImageNet subsets for pre-resized JPEG, NumPy shard, and DALI NumPy file input experiments. |
| `valprep.sh` | Dataset prep docs | Operator utility | Repo-local ImageNet validation-layout helper. |
| `submit-ddp-resnet50.sh` | `make benchmark-ddp-resnet50` | Advanced | Dry-run-first Slurm submit helper for `torchrun` or optional `srun` rows. |
| `submit-ddp-launcher-comparison.sh` | Launcher comparison workflows | Advanced | Focused DDP launcher-comparison submit helper. |
| `run-ddp-resnet50.sh` | Slurm wrapper | Internal | Slurm-side DDP runner and parser wrapper; supports PyTorch CPU DataLoader, DALI GPU decode, and synthetic GPU input backends. |
| `run-ddp-resnet50-workload.py` | `run-ddp-resnet50.sh` | Internal | In-container fixed-iteration ResNet-50 workload with selectable input backend. |
| `submit-hpl-mxp.sh` | `make benchmark-hpl-mxp` | Advanced | Dry-run-first HPL-MxP submit helper for B200 and RTX, including the weak-study preset and derived affinity profile. |
| `run-hpl-mxp.sh` | Slurm wrapper | Internal | Slurm-side HPL-MxP runner with GPU preflight, affinity metadata, and parsed summaries. |
| `select-benchmark-nodes.py` | submit helpers | Advanced | Selects strict-passed B200/RTX nodes from date-scoped by-node reports. |
| `select-b200-benchmark-nodes.py` | compatibility workflows | Advanced | B200-focused node selector retained for older workflows. |

## Direct Script Rules

- Prefer the Make target unless a runbook section explicitly says direct script use is advanced troubleshooting.
- Keep dry-run behavior unless the script and runbook both say `--apply` is expected.
- Do not call Slurm-side `run-*` scripts directly from the laptop; they are normally invoked by Slurm wrappers.
- Keep generated raw and parsed evidence out of Git unless a review artifact is explicitly promoted.
- Slurm submitter paths default to `--mem=0` so Slurm grants node memory
  instead of the partition per-CPU memory default.
- DataLoader and DDP JPEG backend rows reject mismatched derived JPEG metadata
  when `--derived-root` or `--derived-image-size` points at a different size
  than `--dataset-root`.
