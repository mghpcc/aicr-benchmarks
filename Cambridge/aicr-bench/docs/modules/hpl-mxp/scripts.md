# HPL-MxP Script Interface

Purpose: document HPL-MxP primitives for custom Slurm workflows.

The HPL-MxP script layer exposes a guarded host-side Slurm submitter and an
allocation-side runner. The submitter resolves presets, matrix sizes, processor
grids, NPS4-derived affinity profiles, MPI controls, and repeat samples before
printing or submitting the Slurm job.

## Inspect The Interface

Allocation-side runner:

<!-- aicr-test
id: hpl-mxp-runner-help
suite: hpl-mxp
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--matrix-size"
    - "--cpu-affinity"
    - "--ucx-affinity"
-->
```bash
scripts/benchmark/run-hpl-mxp.sh --help
```

Host-side Slurm submitter:

<!-- aicr-test
id: hpl-mxp-submit-help
suite: hpl-mxp
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--preset"
    - "--affinity-profile"
-->
```bash
scripts/benchmark/submit-hpl-mxp.sh --help
```

Report renderer:

<!-- aicr-test
id: hpl-mxp-render-help
suite: hpl-mxp
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--repeat-aggregation"
    - "--job-id-min"
    - "--job-id-list"
-->
```bash
bash scripts/lib/run-repo-python.sh scripts/report/render-hpl-mxp-report.py --help
```

## Presets

| Preset | Use |
| --- | --- |
| `smoke` | Tiny row that confirms launch, parsing, and artifact layout. |
| `staged` | Smaller reviewed matrix ladder for controlled checks. |
| `campaign-candidate` | Compatibility preset for existing target-size rows. |
| `weak-study` | Reviewed weak-scaling ladder with derived NPS4 affinity. |

`weak-study` rows automatically resolve the reviewed `N`, `NB`, process
grid, derived NPS4 affinity, weak-scaling metadata, and HPL-MxP algorithm
controls unless the submitter rejects an unsafe override.

## Precision Axis

The public wrapper exposes HPL-MxP precision through `--sloppy-type`.

| Sloppy type | Precision |
| --- | --- |
| `FP16` | 16-bit floating point. |
| `FP8` | 8-bit floating point. |
| `FP4` | 4-bit floating point. |

The submitter accepts FP4 only for B200 rows.

## Direct Use

Use [submit-hpl-mxp.sh](../../../man/submit-hpl-mxp.md) for Slurm submissions
and [run-hpl-mxp.sh](../../../man/run-hpl-mxp.md) inside an existing allocation.
Weak-study rows should use `weak-study` and `--scaling-study weak`
unless another shape has been explicitly selected before collection. The
default `--affinity-profile derived-nps4` and default `--mem=0` must remain in
place for AICR GPU benchmark rows. FP8 comparison rows should set
`--sloppy-type FP8`; B200 FP4 comparison rows should set `--sloppy-type FP4`.

## Node Selection

[submit-hpl-mxp.sh](../../../man/submit-hpl-mxp.md) accepts either
`--nodelist` or `--from-node-report`. `--from-node-report` selects
strict-passed nodes for the requested cluster and count from the date-scoped
node report.

## Repeat Samples

Use `--repeat-count` and `--repeat-stagger-seconds` for independent samples of
the same row. Report rendering can aggregate repeated rows with standard or
Olympic policy. Use standard aggregation unless a study was explicitly
collected and documented for Olympic aggregation.

## Scaling Labels

Use `--scaling-study weak` for weak-study rows that are intended to be
interpreted as weak scaling. Use `--scaling-study exploratory` for smoke,
staged, and one-off rows. Use `--baseline-matrix-size` only when a strong- or
weak-scaling interpretation needs an explicit baseline recorded in the parsed
summary.

## Artifacts

Direct HPL-MxP runner and submitter runs write multi-node raw captures, parsed
summaries, Slurm output, and index records. Rendered reports are renderer or
Make outputs and are intentionally not listed here.

The submitter defaults to `--mem=0` for full-node Slurm rows so the HPL-MxP
container receives the node memory cgroup. Use a smaller `--mem` value only for
reviewed diagnostics.

Raw run directory:

```text
results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/
```

Canonical files:

```text
results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/canonical/hpl-mxp-command.txt
results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/canonical/hpl-mxp-stdout.txt
results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/canonical/hpl-mxp-stderr.txt
results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/canonical/hpl-mxp-summary.txt
results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/canonical/gpu-preflight.txt
results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/canonical/gpu-postflight.txt
```

Metadata, parsed, Slurm, and index files:

```text
results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/metadata/record.json
results/by-date/<date>/parsed/<cluster>/multi-node/hpl-mxp/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/multi-node/hpl-mxp/<run_id>/status.json
results/slurm/<job-name>-<job-id>.out
results/slurm/<job-name>-<job-id>.err
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
```
