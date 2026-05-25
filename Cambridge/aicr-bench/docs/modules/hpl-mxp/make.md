# HPL-MxP Make Interface

Purpose: run curated HPL-MxP benchmark shapes through Make.

`benchmark-hpl-mxp` is the guarded Make front door for HPL-MxP. It delegates to
[submit-hpl-mxp.sh](../../../man/submit-hpl-mxp.md), which resolves presets and
prints the planned Slurm command before submission.

## Smoke Dry Run

<!-- aicr-test
id: hpl-mxp-smoke-dry-run
suite: hpl-mxp
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "HPL-MxP dry run"
    - "Preset      : smoke"
    - "Slurm mem   : 0"
-->
```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=b0002 HPL_MXP_PRESET=smoke
```

## Run A Smoke Row

HPL-MxP defaults to the NPS4-derived topology profile. Add `APPLY=1` only
when you want to submit.

```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=b0002 HPL_MXP_PRESET=smoke APPLY=1
```

## Weak-Study Row

Use this shape for weak-study rows.

`weak-study` resolves the reviewed matrix size, `NB=2048`, process grid,
derived NPS4 affinity, weak-scaling metadata, and HPL-MxP algorithm controls.

```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=4 NODELIST=b0002,b0006,b0007,b0008 HPL_MXP_PRESET=weak-study HPL_MXP_REPEAT_COUNT=3
```

## Explicit Matrix Override

```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=4 NODELIST=b0002,b0006,b0007,b0008 HPL_MXP_PRESET=staged HPL_MXP_MATRIX_SIZE=750000 HPL_MXP_NB=2048 HPL_MXP_NPROW=4 HPL_MXP_NPCOL=8
```

## Low-Precision Rows

Use these to run low-precision rows without changing the weak-study matrix
controls.

```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=b0002 HPL_MXP_PRESET=weak-study HPL_MXP_SLOPPY_TYPE=FP8
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=b0002 HPL_MXP_PRESET=weak-study HPL_MXP_SLOPPY_TYPE=FP4
```

## Node Selection

Omit `NODELIST` only when using `FROM_NODE_REPORT=1` to select strict-passed
nodes from the node report.

```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=4 FROM_NODE_REPORT=1 NODE_REPORT_DATE=today HPL_MXP_PRESET=weak-study HPL_MXP_AFFINITY_PROFILE=derived-nps4 HPL_MXP_SCALING_STUDY=weak
```

## Render Existing Results

```bash
make render-hpl-mxp CLUSTER=b200 DATE=<YYYY-MM-DD> REPEAT_AGGREGATION=standard
```

For a same-day closeout that must exclude earlier rows, add job-id filters:

```bash
make render-hpl-mxp CLUSTER=b200 DATE=<YYYY-MM-DD> REPEAT_AGGREGATION=standard HPL_MXP_RENDER_JOB_ID_MIN=28201 HPL_MXP_RENDER_JOB_ID_MAX=28264
```

## Custom Controls

Use `HPL_MXP_MATRIX_SIZE`, `HPL_MXP_NB`, `HPL_MXP_NPROW`, `HPL_MXP_NPCOL`,
`HPL_MXP_TIME`, `HPL_MXP_MEM`, `HPL_MXP_SLOPPY_TYPE`, `HPL_MXP_TEST_LOOP`,
`HPL_MXP_REPEAT_COUNT`, MPI/UCX variables, HPL-MxP algorithm variables, and
explicit affinity variables for controlled replays. The default
`HPL_MXP_AFFINITY_PROFILE=derived-nps4` must remain in place for AICR GPU
benchmark rows.

`HPL_MXP_MEM=0` is the default full-node Slurm memory request. Override it only
for reviewed diagnostics.

`HPL_MXP_SLOPPY_TYPE=FP4` is accepted only for B200 rows in the public wrapper.

## Artifacts

HPL-MxP Make runs produce multi-node raw captures, parsed summaries, Slurm
output, and rendered report artifacts.

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

Metadata, parsed, and Slurm files:

```text
results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/metadata/record.json
results/by-date/<date>/parsed/<cluster>/multi-node/hpl-mxp/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/multi-node/hpl-mxp/<run_id>/status.json
results/slurm/<job-name>-<job-id>.out
results/slurm/<job-name>-<job-id>.err
```

Rendered report files:

```text
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
results/reports/<date>/hpl-mxp/hpl-mxp-<cluster>-<date>.md
results/reports/<date>/hpl-mxp/hpl-mxp-summary-<cluster>-<date>.csv
results/reports/<date>/hpl-mxp/hpl-mxp-repeat-aggregation-<cluster>-<date>.csv
results/reports/<date>/hpl-mxp/hpl-mxp-report-<cluster>-<date>.json
```
