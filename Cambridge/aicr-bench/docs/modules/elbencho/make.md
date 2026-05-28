# Elbencho Make Interface

Purpose: run curated Elbencho storage workloads through Make.

`benchmark-elbencho` is the Make front door for Elbencho. It delegates to
[submit-elbencho.sh](../../../man/submit-elbencho.md), prints the planned Slurm
command before submission, and serializes repeats with dependency chaining.

## Runtime Install Preview

```bash
make install-elbencho
```

Add `APPLY=1` only when you want to install or refresh the runtime image. The
Elbencho image is optional and is not pulled by the default container install
workflow. For private runtime roots, build it first with `make install-elbencho
APPLY=1`, or use `make install-containers INSTALL_ELBENCHO_CONTAINER=1 APPLY=1`.

## One-Node Small-Block Dry Run

<!-- aicr-test
id: elbencho-small-block-dry-run
suite: elbencho
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Elbencho submission dry run"
    - "small-block"
-->
```bash
ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho \
make benchmark-elbencho CLUSTER=b200 WORKLOAD=small-block NODES=1 NODELIST=b0002 ELBENCHO_PROFILE=small ELBENCHO_CPUS_PER_TASK=128
```

## Run A One-Node Workload

Add `APPLY=1` only when you want to submit.

```bash
ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho \
make benchmark-elbencho CLUSTER=b200 WORKLOAD=metadata NODES=1 NODELIST=b0002 ELBENCHO_PROFILE=small ELBENCHO_CPUS_PER_TASK=128 APPLY=1
```

## Peak-Cluster Row

```bash
ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho \
make benchmark-elbencho CLUSTER=b200 WORKLOAD=peak-cluster NODES=30 NODELIST=b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031 ELBENCHO_PROFILE=small ELBENCHO_CPUS_PER_TASK=128
```

## Node Selection

Omit `NODELIST` only when using `FROM_NODE_REPORT=1` to select strict-passed
nodes from the node report.

```bash
ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho \
make benchmark-elbencho CLUSTER=b200 WORKLOAD=peak-cluster NODES=30 FROM_NODE_REPORT=1 NODE_REPORT_DATE=today ELBENCHO_PROFILE=small ELBENCHO_CPUS_PER_TASK=128
```

## Repeat Runs

```bash
ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho \
make benchmark-elbencho CLUSTER=b200 WORKLOAD=small-block NODES=1 NODELIST=b0002 ELBENCHO_PROFILE=small ELBENCHO_REPEAT_COUNT=5 ELBENCHO_REPEAT_STAGGER_SECONDS=30
```

## Render Existing Results

```bash
scripts/report/render-elbencho-report.py --date 2026-05-17 --cluster b200 --both --write
```

The rendered B200 rows are summarized in the
[B200 Elbencho storage study](studies/b200-storage-2026-05-17.md).

## Custom Controls

Use `ELBENCHO_TARGET_ROOT`, `ELBENCHO_SIZE`, `ELBENCHO_BLOCK`,
`ELBENCHO_THREADS`, `ELBENCHO_IODEPTH`, `ELBENCHO_FILE_PATTERN`,
`ELBENCHO_FILES`, and `ELBENCHO_DIRS` to tune profile templates. Make defaults
to `ELBENCHO_MEM=0`; keep that full-node memory request for benchmark rows
unless the run is a memory diagnostic. GPU batch jobs default to the cluster
full-node GPU GRES; set `ELBENCHO_GRES=<gres>` only for reviewed site-specific
scheduling cases. Use `ELBENCHO_CMD` only for expert overrides and label those
rows clearly.

## Artifacts

Elbencho Make runs produce multi-node raw captures, parsed summaries, Slurm
output, and rendered report artifacts.

Raw run directory:

```text
results/by-date/<date>/raw/<cluster>/multi-node/elbencho/<run_id>/
```

Canonical files:

```text
results/by-date/<date>/raw/<cluster>/multi-node/elbencho/<run_id>/canonical/elbencho-command.txt
results/by-date/<date>/raw/<cluster>/multi-node/elbencho/<run_id>/canonical/elbencho-stdout.txt
results/by-date/<date>/raw/<cluster>/multi-node/elbencho/<run_id>/canonical/elbencho-stderr.txt
results/by-date/<date>/raw/<cluster>/multi-node/elbencho/<run_id>/canonical/elbencho-summary.txt
```

Metadata, parsed, and Slurm files:

```text
results/by-date/<date>/raw/<cluster>/multi-node/elbencho/<run_id>/metadata/record.json
results/by-date/<date>/parsed/<cluster>/multi-node/elbencho/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/multi-node/elbencho/<run_id>/status.json
results/slurm/<job-name>-<job-id>.out
results/slurm/<job-name>-<job-id>.err
```

Rendered report files:

```text
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
results/reports/<date>/elbencho-<cluster>.md
```
