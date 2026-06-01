# DataLoader Test Plan

Purpose: define executable coverage and HPC replay levels for the DataLoader
module.

DataLoader has one-job and sweep submitters, local and multi-node modes, input
backend experiments, derived dataset helpers, repeat aggregation, and report
renderers. Default documentation tests cover help, inspect, dry-run, fixture,
and renderer surfaces without launching Slurm jobs. Applied tests are explicit,
small, and node-scoped.

## Current Coverage

- `make docs-link-check` checks public documentation, man-page inventory,
  script links, fixture hygiene, and node-name examples.
- `make docs-test-plan-dataloader` lists DataLoader `aicr-test`
  blocks without running them.
- `make docs-test-dataloader` runs local help, inspect, dry-run, renderer-help,
  derived-planner dry-run, and fixture replay tests.
- `DOCS_APPLY=1 NODELIST=<node> make docs-test-dataloader` enables one-node
  single-GPU and one-node eight-GPU apply tests.
- `DOCS_APPLY=1 NODELIST=<node1>,<node2> make docs-test-dataloader` enables the
  two-node distributed-sharded apply test.

## Command Coverage

| Source | Command | Replay level | Acceptance |
| --- | --- | --- | --- |
| `scripts.md` | [run-dataloader.sh](../../../man/run-dataloader.md) `--help` | Local doctest | Help exposes input backend and profile inspection controls. |
| `scripts.md` | [submit-dataloader.sh](../../../man/submit-dataloader.md) `--help` | Local doctest | Help exposes mode, GPU count, and profile controls. |
| `scripts.md` | [sweep-dataloader.sh](../../../man/sweep-dataloader.md) `--help` | Local doctest | Help exposes input-backend and DALI sweep axes. |
| `scripts.md` | [run-dataloader-workload.py](../../../man/run-dataloader-workload.md) `--help` | Local doctest | Help exposes low-level input backend and output controls. |
| `scripts.md` | `submit-dataloader.sh --profile small --inspect-profile` | Local doctest | Prints the reviewed small profile without submitting. |
| `scripts.md` | [prepare-dataloader-derived-dataset.py](../../../man/prepare-dataloader-derived-dataset.md) `--help` | Local doctest | Help exposes `--formats`, dry-run, and `--apply`. |
| `scripts.md` | [submit-dataloader-derived-dataset.sh](../../../man/submit-dataloader-derived-dataset.md) `--help` | Local doctest | Help exposes CPU Slurm, `--write`, and partition controls. |
| `scripts.md` | derived dataset planner dry-run | Local doctest | Uses a tiny ImageFolder-shaped fixture and does not write outputs. |
| `scripts.md` | [render-dataloader-report.py](../../../man/render-dataloader-report.md) `--help` | Local doctest | Help exposes smoke filtering and repeat aggregation controls. |
| `scripts.md` | [render-dataloader-input-lab-report.py](../../../man/render-dataloader-input-lab-report.md) `--help` | Local doctest | Help exposes baseline and input-backend filters. |
| `scripts.md` | [render-dataloader-dali-standard-imagenet-report.py](../../../man/render-dataloader-dali-standard-imagenet-report.md) `--help` | Local doctest | Help exposes standard ImageNet DALI optimization report controls. |
| `scripts.md` | DataLoader input-backend contract fixture | Local fixture replay | Imports the shared helper and validates NumPy shard, PyTorch NumPy block, and DALI NumPy file/block backend mapping and missing-input errors. |
| `scripts.md` | Input-lab report fixture | Local fixture replay | Renders a tiny synthetic input-lab result tree and validates Markdown, CSV, JSON, and PNG outputs. |
| `make.md` | `make benchmark-dataloader ... GPU_COUNT=1 MODE=single` | Local dry-run doctest | Prints a one-GPU dry-run `sbatch` command. |
| `make.md` | `make benchmark-dataloader ... GPU_COUNT=8 MODE=replicated` | Local dry-run doctest | Prints one-node, eight-GPU replicated shape. |
| `make.md` | `make benchmark-dataloader ... DATALOADER_NODES=2 MODE=distributed-sharded` | Local dry-run doctest | Prints two-node sharded shape and 16 requested GPUs. |
| `make.md` | `DATALOADER_INPUT_BACKENDS=...` | Local dry-run doctest | Prints PyTorch, DALI JPEG, NumPy shard, PyTorch NumPy block, and DALI NumPy file/block backend sweep points. |
| `make.md` | `make prep-dataloader-derived-dataset ...` | Local dry-run doctest | Prints CPU partition, planner mode, and no derived-data writes. |
| `examples.md` | worker sweep dry-run | Local dry-run doctest | Prints worker-count sweep points. |
| `examples.md` | B200 scale ladder dry-run | Local dry-run doctest | Prints `1,2,4,8,16` node ladder without submitting. |
| `examples.md` | `bash -n docs/modules/dataloader/slurm-dataloader.sbatch` | Local doctest | Keeps the module-local Slurm primitive shell-parseable without submitting. |
| `examples.md` | Olympic aggregation fixture | Local fixture replay | Validates repeat trimming and paired metrics. |
| `examples.md` | report-shape fixture | Local fixture replay | Validates rendered Markdown shape without live results. |
| `make.md` | one-GPU `APPLY=1` | AICR HPC apply doctest | Submits only with `DOCS_APPLY=1` and one explicit node. |
| `make.md` | one-node eight-GPU `APPLY=1` | AICR HPC apply doctest | Submits only with `DOCS_APPLY=1` and one explicit node. |
| `make.md` | two-node sharded `APPLY=1` | AICR HPC apply doctest | Submits only with `DOCS_APPLY=1` and two explicit nodes. |
| `make.md` | `make render-dataloader ... DATE=<YYYY-MM-DD>` | AICR HPC render replay | Reads generated parsed summaries and writes report artifacts. |
| `make.md` | `make render-dataloader-input-lab ... DATE=<YYYY-MM-DD>` | AICR HPC render replay | Reads generated input-lab rows and writes lab report artifacts. |
| `studies.md` | derived dataset helper `--apply` | Manual/HPC review | Materializes bounded JPEG and NumPy lab inputs only after dry-run storage review. |
| `derived-datasets.md` | derived dataset dry-run and apply workflow | Manual/HPC review | Documents when derived JPEG and NumPy inputs are used and keeps write mode explicit. |
| `make.md` | `make prep-dataloader-derived-dataset APPLY=1` | AICR HPC apply review | Submits a CPU-queue planner job that still writes no derived outputs unless `DATALOADER_PREP_WRITE=1`. |
| `examples.md` | one-node optimization workflow | Manual/HPC review | Runs batch, worker, prefetch, and repeat sweeps only after dry-run shape review. |
| `make.md` | repeat/Olympic `APPLY=1` | Manual/HPC review | Submits repeated finalist rows and validates renderer aggregation. |
| `studies.md` | full DALI/NumPy input-lab replay | Manual/HPC review | Exercises derived JPEG, DALI, NumPy shard, and DALI NumPy file rows outside default doctests. |

## Local Replay

Run from the installed `aicr-bench` root:

```bash
make docs-link-check
make docs-test-plan-dataloader
make docs-test-dataloader
bash scripts/report/check-artifact-policy.sh
bash -n scripts/benchmark/run-dataloader.sh scripts/benchmark/submit-dataloader.sh scripts/benchmark/sweep-dataloader.sh docs/modules/dataloader/slurm-dataloader.sbatch
git diff --check
```

The default docs run should remain short. It may run help commands, dry-runs,
fixtures, and renderer help. It must not submit Slurm jobs, generate derived
datasets, or require restored benchmark result trees.

## AICR HPC Smoke Replay

Run after syncing or freshly cloning the repo on AICR HPC and creating
`benchmark-settings.env` from the example file.

B200 smoke:

```bash
DOCS_APPLY=1 CLUSTER=b200 NODELIST=<b-node-1>,<b-node-2> make docs-test-dataloader
make render-dataloader CLUSTER=b200 DATE=<YYYY-MM-DD>
```

RTX smoke:

```bash
DOCS_APPLY=1 CLUSTER=rtxpro6000 NODELIST=<a-node-1>,<a-node-2> make docs-test-dataloader
make render-dataloader CLUSTER=rtxpro6000 DATE=<YYYY-MM-DD>
```

Acceptance criteria:

- Slurm jobs complete with `COMPLETED 0:0`.
- Each parsed `status.json` is `passed`.
- One-node replicated rows have eight rank metrics.
- Two-node distributed-sharded rows have 16 rank metrics.
- Render replay succeeds for the generated date.

## Render Replay

The main renderer has a local `--help` doctest. Full render replay remains an
AICR HPC validation step because it needs completed DataLoader result trees or
restored reviewed evidence.

```bash
make render-dataloader CLUSTER=b200 DATE=<YYYY-MM-DD>
make render-dataloader CLUSTER=rtxpro6000 DATE=<YYYY-MM-DD>
```

The main renderer writes:

```text
results/reports/<date>/dataloader/dataloader-<cluster>-<date>.md
results/reports/<date>/dataloader/dataloader-summary-<cluster>-<date>.csv
results/reports/<date>/dataloader/dataloader-report-<cluster>-<date>.json
results/reports/<date>/dataloader/dataloader-throughput-<cluster>-<date>.png
results/reports/<date>/dataloader/dataloader-rank-imbalance-<cluster>-<date>.png
```

The input-pipeline lab renderer is separate and writes under
`results/reports/<date>/dataloader-input-lab/`.

```bash
make render-dataloader-input-lab CLUSTER=b200 DATE=<YYYY-MM-DD>
make render-dataloader-input-lab CLUSTER=rtxpro6000 DATE=<YYYY-MM-DD>
```

## Campaign Replay

Full campaign replay is manual because it can run for hours and may require
reviewed result trees, explicit node lists, and prepared derived datasets.

Campaign-shaped replay includes:

- Single-GPU surface scans for batch, workers, and prefetch.
- One-node eight-GPU replicated scans with repeated finalist rows.
- Multi-node distributed-sharded scale rows.
- Optional DALI, NumPy shard, and DALI NumPy file derived-input lab sweeps.
- Bounded derived-dataset `--apply` runs after storage-estimate review.
- Repeat/Olympic rows for reported configurations.
- Prepared-tensor GPU/cuFile transport rows with matching dataset, node, image
  size, batch size, backend settings, and measured-iteration shape across
  compared rows.

Prepared-tensor transport replay uses at least 100 warmup batches and 500
measured batches, repeated rows with declared aggregation, same-node
`verify-gds` PASS evidence, and archived cuFile logs for GPU/cuFile rows. The
published prepared-tensor transport ladder includes size `256` for
`numpy-fp16-blocks-pytorch` and `dali-numpy-fp16-blocks-gds`, followed by the
reported `384`, `512`, and `1024` rows.

Shared metric definitions, input-representation notes, and derived-dataset
commands live in
[Input Pipeline Reference](input-pipeline-reference.md) and
[Derived ImageNet Datasets](derived-datasets.md).

Use the reviewed study pages for campaign provenance and exact command shapes.

## Outside Default Tests

- Default docs tests skip Slurm submission.
- Default docs tests skip derived-dataset generation and DALI/NumPy apply
  workloads.
- Repeat and Olympic DataLoader applies are not default docs tests; committed
  fixtures prove aggregation behavior, and applied repeats remain manual HPC
  replay.
- Full render replay depends on runtime result trees and remains AICR HPC
  validation.
- Full May campaign replay remains manual benchmark evidence work, not module
  documentation replay.
- `synthetic-gpu` is DDP-only. DataLoader owns PyTorch CPU, DALI JPEG, NumPy
  shard, and DALI NumPy file paths. The DALI NumPy file path is the
  prepared-tensor transport path. CPU-reader and GPU/O_DIRECT-reader rows cover
  prepared-tensor transport, while DALI JPEG rows cover decode and input
  pipeline behavior for JPEG files.
