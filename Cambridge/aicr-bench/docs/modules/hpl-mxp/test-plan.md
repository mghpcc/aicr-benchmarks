# HPL-MxP Test Plan

Purpose: define executable coverage and HPC replay expectations for the
HPL-MxP module.

HPL-MxP has a dry-run-first Slurm submitter, an allocation-side runner, curated
Make targets, and a report renderer. Default documentation tests prove help and
dry-run surfaces without launching Slurm jobs. Applied replay is explicit,
node-scoped, and starts with smoke rows.

## Current Coverage

- Documentation link and man-page coverage is checked by `make docs-link-check`.
- `make docs-test-plan-hpl-mxp` lists selected HPL-MxP `aicr-test` blocks
  without running them.
- `make docs-test-hpl-mxp` runs local help and dry-run examples.
- Command examples with `aicr-test` metadata cover submitter help and smoke
  dry-run paths.
- Report rendering is covered by the HPL-MxP renderer and benchmark registry
  validation, but full render replay still requires generated or restored
  result trees.

## Command Coverage

| Source | Command | Replay level | Acceptance |
| --- | --- | --- | --- |
| `scripts.md` | [submit-hpl-mxp.sh](../../../man/submit-hpl-mxp.md) `--help` | Local doctest | Help exposes presets and affinity controls. |
| `scripts.md` | [run-hpl-mxp.sh](../../../man/run-hpl-mxp.md) `--help` | Local replay | Help exposes matrix, process-grid, MPI, UCX, and HPL-MxP controls. |
| `make.md` | `make benchmark-hpl-mxp ... HPL_MXP_PRESET=smoke` | Local dry-run doctest | Prints resolved smoke shape, current partition, explicit node list, and `sbatch` command. |
| `make.md` | `make benchmark-hpl-mxp ... HPL_MXP_MEM=0` | Local dry-run doctest | Confirms full-node Slurm memory request is present in the dry-run command. |
| `examples.md` | smoke dry-run example | Local dry-run doctest | Prints the same dry-run contract from the examples page. |
| `make.md` | `make benchmark-hpl-mxp ... HPL_MXP_PRESET=weak-study` | AICR HPC dry-run replay | Resolves weak-study matrix ladder, process grid, derived NPS4 affinity, weak-scaling metadata, and repeat count. |
| `make.md` | `make benchmark-hpl-mxp ... HPL_MXP_SLOPPY_TYPE=FP8` | AICR HPC dry-run replay | Resolves an FP8 comparison row without changing the weak-study ladder controls. |
| `make.md` | `make benchmark-hpl-mxp ... CLUSTER=b200 HPL_MXP_SLOPPY_TYPE=FP4` | AICR HPC dry-run replay | Resolves a B200 FP4 comparison row without changing the weak-study ladder controls. |
| `make.md` | smoke `APPLY=1` | AICR HPC apply replay | Submits one smoke row on an explicit node and writes raw/parsed artifacts. |
| `studies.md` | publication requirements | Manual review | Keeps study pages tied to completed rows, rendered reports, artifacts, and provenance. |
| `make.md` | `make render-hpl-mxp ...` | AICR HPC render replay | Reads generated or restored HPL-MxP summaries and writes Markdown, CSV, and JSON report artifacts. |

## Replay Policy

- Local replay should use help and dry-run tests only.
- HPC replay may include smoke, staged, and weak-study apply rows after syncing to AICR HPC.
- Published campaign evidence should use `weak-study`, derived NPS4 affinity, and weak-scaling metadata.

## Local Replay

Run from the installed `aicr-bench` root:

```bash
make docs-link-check
make docs-test-plan-hpl-mxp
make docs-test-hpl-mxp
bash -n scripts/benchmark/run-hpl-mxp.sh scripts/benchmark/submit-hpl-mxp.sh
git diff --check
```

The default docs run should remain short. It may run help and dry-run commands.
It must not submit Slurm jobs, require GPUs, or require generated HPL-MxP result
trees.

## AICR HPC Smoke Replay

Run after syncing or freshly cloning the repo on AICR HPC and creating
`benchmark-settings.env` from the example file.

```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=<b-node> HPL_MXP_PRESET=smoke
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=<b-node> HPL_MXP_PRESET=smoke APPLY=1
```

Acceptance criteria:

- Slurm jobs complete with `COMPLETED 0:0`.
- Each parsed `status.json` is `passed`.
- Command, stdout, stderr, summary, GPU preflight, and GPU postflight captures
  exist for each row.
- Render replay succeeds for the generated date.

## Render Replay

Full render replay remains an AICR HPC validation step because it needs
completed HPL-MxP result trees or restored reviewed evidence.

```bash
make render-hpl-mxp CLUSTER=b200 DATE=<YYYY-MM-DD> REPEAT_AGGREGATION=standard
```

The renderer writes:

```text
results/reports/<date>/hpl-mxp/hpl-mxp-<cluster>-<date>.md
results/reports/<date>/hpl-mxp/hpl-mxp-summary-<cluster>-<date>.csv
results/reports/<date>/hpl-mxp/hpl-mxp-repeat-aggregation-<cluster>-<date>.csv
results/reports/<date>/hpl-mxp/hpl-mxp-report-<cluster>-<date>.json
```

## Benchmark Replay

Full benchmark replay is manual because HPL-MxP can consume large GPU
allocations for long-running rows.

Weak-study replay includes:

- B200 FP16 weak-study ladder rows at `1,2,4,8,16` nodes.
- B200 FP8 and FP4 comparison rows using the weak-study ladder.
- RTX PRO 6000 FP16 and FP8 rows at `1,2,4` nodes.
- Three or more repeats for published campaign rows.
- Standard repeat aggregation for the May 24 public comparison tables.

The aligned weak-study rows use the same 1024-aligned matrix ladder within
each node count for B200 FP16/FP8/FP4 and RTX FP16/FP8.

## Known Gaps

- Full HPL-MxP replay is HPC-only because it requires the NVIDIA HPC Benchmarks container and allocated GPUs.
- Default docs tests do not run the allocation-side HPL-MxP workload.
- Default docs tests do not render generated HPL-MxP result trees.
