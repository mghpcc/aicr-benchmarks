# Elbencho Script Interface

Purpose: document Elbencho benchmark primitives.

Elbencho exposes a runtime installer, host-side Slurm submitter, allocation-side
runner, and report renderer. The submitter is dry-run first and serializes
repeat samples with Slurm dependencies so storage jobs do not compete with each
other unless concurrency is part of an explicitly labeled experiment.

## Inspect The Interface

Runtime installer:

```bash
scripts/benchmark/install-elbencho-runtime.sh --help
```

Allocation-side runner:

```bash
scripts/benchmark/run-elbencho.sh --help
```

Host-side Slurm submitter:

<!-- aicr-test
id: elbencho-submit-help
suite: elbencho
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--workload"
    - "--repeat-count"
-->
```bash
scripts/benchmark/submit-elbencho.sh --help
```

Report renderer:

```bash
scripts/report/render-elbencho-report.py --help
```

## Workloads

| Workload | Use |
| --- | --- |
| `small-block` | Single-node small-block read/write throughput and IOPS. |
| `small-file` | Single-node small-file create/read/delete behavior. |
| `metadata` | Single-node metadata operation-rate measurement. |
| `peak-cluster` | Multi-node peak-cluster storage row. |

## Profiles

| Profile | Use |
| --- | --- |
| `smoke` | Small launch and parser proof. |
| `small` | Study template for promoted rows. |

## Direct Use

Use [install-elbencho-runtime.sh](../../../man/install-elbencho-runtime.md) to
preview or install the Apptainer runtime. Use
[submit-elbencho.sh](../../../man/submit-elbencho.md) for Slurm submissions and
[run-elbencho.sh](../../../man/run-elbencho.md) inside an existing allocation.
Use [render-elbencho-report.py](../../../man/render-elbencho-report.md) to
summarize parsed rows.

The Elbencho container is optional and is not part of the default runtime image
set. For private runtime roots, build or pull it before Elbencho smoke or
benchmark rows with `make install-elbencho APPLY=1`, or with
`make install-containers INSTALL_ELBENCHO_CONTAINER=1 APPLY=1` when using the
container install workflow.

## Storage Pressure And Repeats

Elbencho intentionally drives shared storage. Keep promoted benchmark-style
repeat samples serialized with the submitter's dependency chain unless the study
is explicitly measuring concurrent pressure. Lower submit staggering and
concurrent independent jobs change the storage pressure being measured.

## Artifacts

Direct Elbencho runner and submitter runs write multi-node raw captures, parsed
summaries, Slurm output, and index records. Study bundles and rendered result
links are listed from [Elbencho studies](studies.md).

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

Metadata, parsed, Slurm, and index files:

```text
results/by-date/<date>/raw/<cluster>/multi-node/elbencho/<run_id>/metadata/record.json
results/by-date/<date>/parsed/<cluster>/multi-node/elbencho/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/multi-node/elbencho/<run_id>/status.json
results/slurm/<job-name>-<job-id>.out
results/slurm/<job-name>-<job-id>.err
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
```
