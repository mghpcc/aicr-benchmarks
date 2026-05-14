# DataLoader Make Interface

Purpose: run curated DataLoader jobs and sweeps through Make.

## One GPU Dry Run

<!-- aicr-test
id: dataloader-single-dry-run
suite: dataloader
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Dry run"
    - "dataloader"
-->
```bash
make benchmark-dataloader CLUSTER=rtxpro6000 GPU_COUNT=1 MODE=single NODELIST=a0002 DATALOADER_NUM_WORKERS=8 DATALOADER_RUN_ARGS="--warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0"
```

## Run On One GPU

Add `APPLY=1` only when you want to submit.

<!-- aicr-test
id: dataloader-one-gpu-short
suite: dataloader
kind: slurm-apply
safety: one-node
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Submitted"
-->
```bash
make benchmark-dataloader CLUSTER={{cluster}} GPU_COUNT=1 MODE=single NODELIST={{node}} APPLY=1 DATALOADER_NUM_WORKERS=8 DATALOADER_RUN_ARGS="--warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0"
```

## One Node Eight GPU Replicated

```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=replicated NODELIST=b0001 DATALOADER_BATCH_SIZES=256 DATALOADER_NUM_WORKERS=8 DATALOADER_PREFETCH_FACTORS=4
```

## One Node Eight GPU Sharded

```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=distributed-sharded NODELIST=b0001 DATALOADER_BATCH_SIZES=256 DATALOADER_NUM_WORKERS=16 DATALOADER_PREFETCH_FACTORS=4
```

## Multi-node Sharded

Use B200 `DATALOADER_NODES=1,2,4,8,16` and RTX
`DATALOADER_NODES=1,2,4,8` for scale-ladder studies.

```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=distributed-sharded DATALOADER_NODES=2 NODELIST=b0001,b0002 DATALOADER_BATCH_SIZES=256 DATALOADER_NUM_WORKERS=16 DATALOADER_PREFETCH_FACTORS=4
```

## Fleet Runs

Omit `NODELIST` only when Slurm should choose from the available node pool.

## Repeat Runs

```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=replicated NODELIST=b0001 DATALOADER_REPEAT_COUNT=5 DATALOADER_REPEAT_AGGREGATION=olympic
```

## ASCII Dashboard

DataLoader renders a Markdown report:

```bash
make render-dataloader CLUSTER=b200 DATE=today
```

## Custom Profiles

Use `PROFILE=small|medium|large` for intensity defaults and `DATALOADER_RUN_ARGS` for explicit runner overrides.

## Artifacts

DataLoader runs produce node or multi-node raw captures, parsed summaries, and rendered report artifacts.

Raw run directories:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/dataloader/<run_id>/
results/by-date/<date>/raw/<cluster>/multi-node/dataloader/<run_id>/
```

Canonical files:

```text
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-summary.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-env.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-command.sh
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-stdout.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-stderr.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-metrics.json
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/nvidia-smi-L.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/rank-metrics.tsv
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/ranks/rank-*/dataloader-metrics.json
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/ranks/rank-*/dataloader-stdout.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/ranks/rank-*/dataloader-stderr.txt
```

Wrapper, metadata, and parsed files:

```text
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/wrapper/slurm-<job_id>.out
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/wrapper/slurm-<job_id>.err
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/metadata/record.json
results/by-date/<date>/parsed/<cluster>/<scope-path>/dataloader/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/<scope-path>/dataloader/<run_id>/status.json
```

Rendered report files:

```text
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
results/reports/<date>/dataloader/dataloader-<cluster>-<date>.md
results/reports/<date>/dataloader/dataloader-summary-<cluster>-<date>.csv
results/reports/<date>/dataloader/dataloader-<cluster>-<date>.json
results/reports/<date>/dataloader/dataloader-throughput-<cluster>-<date>.png
results/reports/<date>/dataloader/dataloader-throughput-matrix-<cluster>-<date>.png
results/reports/<date>/dataloader/dataloader-imbalance-matrix-<cluster>-<date>.png
results/reports/<date>/dataloader/dataloader-candidate-scatter-<cluster>-<date>.png
results/reports/<date>/dataloader/dataloader-matrix-<cluster>-<date>.html
```

Examples describe expected artifacts and link reviewed studies rather than raw generated run trees.
