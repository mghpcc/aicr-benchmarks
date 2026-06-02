# DDP Test Plan

Purpose: summarize executable coverage and replay expectations for the DDP module.

## Coverage

- Documentation link and man-page coverage is checked by `make docs-link-check`.
- Command examples with `aicr-test` metadata cover submitter help, dry-run, and Slurm primitive examples.
- Report rendering is covered by the DDP renderer and campaign registry validation.
- A local DDP report-shape fixture checks Markdown sections, repeat
  aggregation, generated CSV/JSON/PNG files, prepared-block GPU/cuFile
  disclosure, synthetic-label caveats, and public wording.
- Public wording checks cover DDP docs and generated reports.
- Input-pipeline study dry-runs print the effective input backend,
  dataset root, derived root, derived size, and prepared-input controls so
  mismatched study identity is visible before submit.

## Command Coverage

| Source | Command | Replay level | Acceptance |
| --- | --- | --- | --- |
| `scripts.md` | [run-ddp-resnet50.sh](../../../man/run-ddp-resnet50.md) `--help` | Local doctest | Help exposes launcher and runtime controls. |
| `scripts.md` | [submit-ddp-resnet50.sh](../../../man/submit-ddp-resnet50.md) `--help` | Local doctest | Help exposes `--mem`, repeat, launcher, and node-selection controls. |
| `scripts.md` | [submit-ddp-launcher-comparison.sh](../../../man/submit-ddp-launcher-comparison.md) `--help` | Local doctest | Help exposes scale-list and controlled-bind launcher controls. |
| `scripts.md` | [run-ddp-resnet50-workload.py](../../../man/run-ddp-resnet50-workload.md) `--help` | Local doctest | Help exposes input backends, DALI controls, synthetic GPU controls, precision, and layout. |
| `scripts.md` | [render-ddp-resnet50-report.py](../../../man/render-ddp-resnet50-report.md) `--help` | Local doctest | Help exposes report date, cluster, and output controls. |
| `make.md` | `make benchmark-ddp-resnet50 ...` | Local dry-run doctest | Prints dry-run mode and the selected launcher/input backend without submitting Slurm jobs. |
| `make.md` | `make benchmark-ddp-launcher-comparison ...` | Local dry-run doctest | Prints paired `torchrun` and controlled-bind `srun` rows without submitting Slurm jobs. |
| `make.md` | `make render-ddp-resnet50 ... DATE=<YYYY-MM-DD>` | AICR HPC render replay | Reads generated summaries and writes DDP report artifacts. |
| `test-plan.md` | `tests/scripts/check-ddp-report-shape-fixture.py` | Local fixture replay | Validates DDP renderer Markdown shape, repeat aggregation, output files, and public wording. |
| `examples.md` | `bash -n docs/modules/ddp/slurm-ddp-resnet50.sbatch` | Local doctest | Keeps the module-local Slurm primitive shell-parseable without submitting. |
| `examples.md` | Slurm primitive DDP example | AICR HPC apply doctest | Runs only with explicit apply mode and an explicit node. |
| `test-plan.md` | `bash scripts/report/check-artifact-policy.sh` | Local replay | Keeps generated raw result trees and public artifact bundles out of Git. |
| `test-plan.md` | `bash -n` on DDP shell scripts and module Slurm wrapper | Local replay | Runner, submitters, and wrapper remain shell-parseable. |
| `test-plan.md` | Public wording checks | Local replay | DDP docs and generated reports keep public study wording. |

## Replay Policy

- Local replay uses help and dry-run tests.
- HPC replay may include one-node `torchrun`, launcher-comparison, and selected multi-node rows after syncing to AICR HPC.
- Standard benchmark evidence uses `torchrun` and the PyTorch CPU
  DataLoader input backend unless a study is explicitly labeled otherwise.
- Full-node DDP rows use the submitter default `--mem=0` unless a memory
  diagnostic intentionally changes the Slurm cgroup.
- Multi-node DDP studies serialize jobs across B200 and RTX unless the
  study intentionally measures shared-storage or scheduler contention.

## Study Quality Requirements

Published DDP study pages meet these requirements:

- rows are selected by explicit job IDs and separated from older exploratory
  runs;
- dataset root, derived metadata, backend, and runtime shape match the stated
  study identity;
- all published table rows are passed and repeat-complete, with five-repeat
  Olympic aggregation unless the page states a stricter rule;
- excluded, cancelled, or failed jobs are recorded in provenance, and published
  aggregates use passed rows only;
- figures are generated from the same focused aggregate used by the tables;
- VAST and OSN bundle, provenance, checksum, and retrieve/verify commands are
  present before publication;
- pages label the evidence role as canonical ImageNet, prepared-input ceiling,
  synthetic GPU ceiling, or decode-stress training.
- prepared-block GPU/cuFile rows disclose synthetic GPU labels and distinguish
  prepared-tensor transport from DALI JPEG/GDS evidence.

## Replay Scope

- Full DDP campaign replay is HPC-only.
- Alternate input backends are study tools; the standard evidence path uses the
  CPU DataLoader backend.
