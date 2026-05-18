# GDS Make Interface

Purpose: run curated GDS validation jobs through the AICR-Bench Make driver.

Use Make when you want dry-run previews, explicit node targeting, repeat runs, and rendered GDS dashboards in the standard layout.

## One Node Dry Run

This previews the Slurm command and does not submit a job.

<!-- aicr-test
id: gds-dry-run-small-node
suite: gds
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Dry run"
-->
```bash
make verify-gds CLUSTER=b200 PROFILE=small NODELIST=b0001
```

## Run On One Node

Add `APPLY=1` only when you want to submit the Slurm job. Use `smoke` for
documentation replay and first-contact validation; use `small` or larger only
when you intentionally want a longer storage-backed check.

<!-- aicr-test
id: gds-one-node-smoke
suite: gds
kind: slurm-apply
safety: one-node
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Submitted"
-->
```bash
make verify-gds CLUSTER={{cluster}} PROFILE=smoke NODELIST={{node}} APPLY=1
```

## Fleet Runs

Fleet submissions default to a 30-second stagger between nodes to keep public
examples from becoming accidental filesystem stress tests. Override
`GDS_SUBMIT_STAGGER_SECONDS` only when you intentionally want a different launch
rate.

```bash
make verify-gds CLUSTER=b200 PROFILE=small APPLY=1
```

Fleet runs should be used only when you intend to run every selected idle node. Use `NODELIST` for targeted support work.

For promoted benchmark-style GDS studies, use dependency-chain stagger mode.
This spaces `sbatch` calls by five seconds, then uses Slurm
`afterany:<previous_job_id>` dependencies so Slurm starts only one selected GDS
job at a time:

<!-- aicr-test
id: gds-benchmark-stagger-dry-run
suite: gds
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "benchmark dependency chain"
    - "--dependency=afterany:<previous-gds-job-id>"
    - "sleep 5 between sbatch calls"
-->
```bash
AICR_GDS_FLEET_IDLE_NODES_CSV=b0001,b0002 make verify-gds CLUSTER=b200 PROFILE=smoke NODELIST=b0001,b0002 REPEAT_COUNT=2 REPEAT_AGGREGATION=olympic GDS_SUBMIT_STAGGER_SECONDS=benchmark
```

## Repeat Runs

```bash
make verify-gds CLUSTER=b200 PROFILE=small NODELIST=b0001 REPEAT_COUNT=3 REPEAT_AGGREGATION=standard
```

## ASCII Dashboard

```bash
make render-gds-ascii CLUSTER=b200 DATE=today
```

## Custom Profiles

```bash
AICR_GDS_PROFILE_CONFIG=/path/to/custom-gds.json \
  make verify-gds CLUSTER=b200 PROFILE=custom NODELIST=b0001 APPLY=1
```

## Artifacts

GDS runs produce node-level raw captures, parsed summaries, and optional fleet reports.

Node-level raw run directory:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/
```

Canonical files:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/canonical/nvidia-smi-L.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/canonical/nvidia-smi-topo-m.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/canonical/gds-summary.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/canonical/gdscheck-platform.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/canonical/gdsio-<phase>.txt
```

Wrapper and metadata files:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/wrapper/cufile.log
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/wrapper/slurm-<job_id>.out
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/wrapper/slurm-<job_id>.err
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/metadata/record.json
```

Parsed files:

```text
results/by-date/<date>/parsed/<cluster>/nodes/<node>/gds/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/nodes/<node>/gds/<run_id>/status.json
```

Fleet and report files:

```text
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
results/reports/<date>/gds/<manifest>.json
results/reports/<date>/gds-<cluster>.md
```

Public examples describe expected artifacts and link reviewed studies rather than raw generated run trees.
