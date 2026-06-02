# DDP Make Interface

Use these Make targets to dry-run, submit, and render DDP ResNet-50 benchmark
jobs.

`benchmark-ddp-resnet50` runs a single selected DDP ResNet-50 shape through
[submit-ddp-resnet50.sh](../../../man/submit-ddp-resnet50.md). Use
[submit-ddp-launcher-comparison.sh](../../../man/submit-ddp-launcher-comparison.md)
or `benchmark-ddp-launcher-comparison` when you need paired launcher rows.

## One-Node Dry Run

<!-- aicr-test
id: ddp-one-node-dry-run
suite: ddp
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Dry run"
    - "DDP ResNet-50"
-->
```bash
make benchmark-ddp-resnet50 CLUSTER=rtxpro6000 NODES=1 NODELIST=a0002 DDP_RUN_ARGS="--warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0"
```

## Run One Shape

Add `APPLY=1` only when you want to submit.

```bash
make benchmark-ddp-resnet50 CLUSTER=b200 NODES=4 NODELIST=b0002,b0003,b0004,b0005 APPLY=1 DDP_RUN_ARGS="--warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 8 --prefetch-factor 4"
```

Full-node DDP examples should keep the submitter default `--mem=0` unless a
memory-cgroup diagnostic intentionally changes the request. This gives the
Slurm job the full node memory allocation instead of a small per-CPU default.

Multi-node DDP throughput is easiest to interpret when B200 and RTX jobs do not
overlap with other storage-intensive submissions. Submit one multi-node DDP job
at a time unless a study explicitly measures storage or scheduler contention.

## Intensity Shape

DDP intentionally uses explicit `DDP_RUN_ARGS` instead of named
`smoke`/`small`/`medium`/`large` profiles. Training studies need the batch,
input backend, warmup/measured iterations, precision, and layout to be visible
in the command. Use at least `100` warmup iterations and `500` measured
iterations for public study rows. Shorter runs are quick checks and should be
labeled that way before publication.

## Launcher Comparison

Use this target to submit paired `torchrun` and controlled-bind `srun` rows for
the selected scale ladder.

<!-- aicr-test
id: ddp-launcher-comparison-dry-run
suite: ddp
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "DDP launcher comparison"
    - "controlled-bind"
    - "--mem=0"
-->
```bash
make benchmark-ddp-launcher-comparison CLUSTER=b200 NODELIST=b0002,b0003,b0004,b0005 DDP_COMPARISON_SCALES=1,2,4 DDP_SRUN_CPU_BIND=none DDP_SRUN_MEM_BIND=none
```

## Node Selection

Omit `NODELIST` only when using `FROM_NODE_REPORT=1` to select strict-passed
nodes from the node report.

```bash
make benchmark-ddp-resnet50 CLUSTER=b200 NODES=2 FROM_NODE_REPORT=1 NODE_REPORT_DATE=today
```

## Repeat Runs

```bash
make benchmark-ddp-resnet50 CLUSTER=b200 NODES=2 NODELIST=b0002,b0003 DDP_REPEAT_COUNT=5 DDP_REPEAT_STAGGER_SECONDS=30
```

## Render Existing Results

```bash
make render-ddp-resnet50 CLUSTER=b200 DATE=2026-05-16
```

## Custom Runner Arguments

Use `DDP_RUN_ARGS` for explicit runner overrides such as input backend,
iteration count, batch size, workers, precision, or layout. The standard
benchmark path keeps `--input-backend pytorch-cpu-dataloader`.

## Standard Versus Study Inputs

Use `torchrun` with `pytorch-cpu-dataloader` for the standard public benchmark
path. DALI, NumPy shard, synthetic GPU, and synthetic large-JPEG rows are
study inputs: they answer labeled questions about backend crossover, prepared
input ceilings, or decode pressure, and should not be mixed into the standard
CPU DataLoader benchmark path without a study page that explains the claim.

## Artifacts

DDP Make runs produce multi-node raw captures, parsed summaries, and rendered
report artifacts.

Raw run directory:

```text
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/
```

Canonical files:

```text
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ddp-resnet50-summary.txt
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ddp-resnet50-env.txt
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ddp-resnet50-command.sh
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ddp-resnet50-stdout.txt
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ddp-resnet50-stderr.txt
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/nvidia-smi-L.txt
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/rank-metrics.tsv
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ranks/rank-*/ddp-resnet50-metrics.json
```

Wrapper, metadata, and parsed files:

```text
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/wrapper/slurm-<job_id>.out
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/wrapper/slurm-<job_id>.err
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/metadata/record.json
results/by-date/<date>/parsed/<cluster>/multi-node/ddp-resnet50/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/multi-node/ddp-resnet50/<run_id>/status.json
```

Rendered report files:

```text
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
results/reports/<date>/ddp/ddp-resnet50-<cluster>-<date>.md
results/reports/<date>/ddp/ddp-resnet50-summary-<cluster>-<date>.csv
results/reports/<date>/ddp/ddp-resnet50-repeat-aggregation-<cluster>-<date>.csv
results/reports/<date>/ddp/ddp-resnet50-report-<cluster>-<date>.json
results/reports/<date>/ddp/ddp-resnet50-throughput-<cluster>-<date>.png
results/reports/<date>/ddp/ddp-resnet50-scaling-<cluster>-<date>.png
```
