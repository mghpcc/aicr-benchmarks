# DataLoader Make Interface

Purpose: run curated DataLoader campaign shapes through Make.

`benchmark-dataloader` is the curated Make campaign target. It delegates to the
matrix sweep submitter, even when the requested shape contains only one matrix
point. Use [submit-dataloader.sh](../../../man/submit-dataloader.md) directly
when you need a single host-side Slurm submission primitive.

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

## One Node Eight GPU Dry Run

<!-- aicr-test
id: dataloader-replicated-dry-run
suite: dataloader
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Mode           : replicated"
    - "requested-gpu-count 8"
-->
```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=replicated NODELIST=b0001 DATALOADER_BATCH_SIZES=256 DATALOADER_NUM_WORKERS=8 DATALOADER_PREFETCH_FACTORS=4 DATALOADER_RUN_ARGS="--warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0"
```

## Two Node Sharded Dry Run

<!-- aicr-test
id: dataloader-two-node-sharded-dry-run
suite: dataloader
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Mode           : distributed-sharded"
    - "--nodes=2"
    - "requested-gpu-count 16"
-->
```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=distributed-sharded DATALOADER_NODES=2 NODELIST=b0001,b0002 DATALOADER_BATCH_SIZES=256 DATALOADER_NUM_WORKERS=16 DATALOADER_PREFETCH_FACTORS=4 DATALOADER_RUN_ARGS="--warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0"
```

## Input Backend Dry Run

<!-- aicr-test
id: dataloader-input-backend-dry-run
suite: dataloader
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Input backends : pytorch-cpu-dataloader,dali-gpu-decode,numpy-uint8-shards,numpy-fp16-shards,numpy-fp16-blocks-pytorch,dali-numpy-fp16-cpu,dali-numpy-fp16-gds,dali-numpy-fp16-blocks-cpu,dali-numpy-fp16-blocks-gds"
    - "backend=dali-gpu-decode"
    - "backend=numpy-uint8-shards"
    - "backend=numpy-fp16-shards"
    - "backend=numpy-fp16-blocks-pytorch"
    - "backend=dali-numpy-fp16-cpu"
    - "backend=dali-numpy-fp16-gds"
    - "backend=dali-numpy-fp16-blocks-cpu"
    - "backend=dali-numpy-fp16-blocks-gds"
-->
```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=1 MODE=single NODELIST=b0001 DATALOADER_INPUT_BACKENDS=pytorch-cpu-dataloader,dali-gpu-decode,numpy-uint8-shards,numpy-fp16-shards,numpy-fp16-blocks-pytorch,dali-numpy-fp16-cpu,dali-numpy-fp16-gds,dali-numpy-fp16-blocks-cpu,dali-numpy-fp16-blocks-gds DATALOADER_BATCH_SIZES=64 DATALOADER_NUM_WORKERS=4 DATALOADER_PREFETCH_FACTORS=2 DATALOADER_DALI_NUM_THREADS=2 DATALOADER_RUN_ARGS="--derived-root $PWD/scratch/derived-datasets/dataloader-lab --derived-image-size 224 --derived-samples-per-class 16 --warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0"
```

## Derived Dataset Prep Dry Run

Derived dataset prep is CPU and filesystem work. Use the CPU-queue wrapper; it
submits no Slurm job unless `APPLY=1`, and submitted jobs still run planner-only
unless `DATALOADER_PREP_WRITE=1`.
See [Derived ImageNet Datasets](derived-datasets.md) for the dataset purpose,
storage policy, and apply workflow.

<!-- aicr-test
id: dataloader-derived-prep-cpu-dry-run
suite: dataloader
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Partition   : cpu"
    - "Prep write  : 0"
    - "dataloader-derived-dataset-cpu.sbatch"
    - "Dry run only"
-->
```bash
make prep-dataloader-derived-dataset DATALOADER_PREP_DATASET_ROOT=tests/fixtures/dataloader/imagefolder-dry-run DATALOADER_PREP_DERIVED_ROOT=/tmp/aicr-dataloader-derived-docs DATALOADER_PREP_FORMATS=procedural-jpeg DATALOADER_PREP_IMAGE_SIZE_LIST=224 DATALOADER_PREP_SAMPLES_PER_CLASS=1
```

## Run On One GPU

Add `APPLY=1` only when you want to submit.

The following `APPLY=1` examples are short smoke runs. Published benchmark rows
use at least `100` warmup and `500` measured batches unless the study page
states a different run shape.

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
make benchmark-dataloader CLUSTER={{cluster}} GPU_COUNT=1 MODE=single NODELIST={{node}} APPLY=1 DATALOADER_NUM_WORKERS=8 DATALOADER_RUN_ARGS="--warmup-batches 20 --measured-batches 100 --byte-estimate-sample-count 0"
```

## Run One Node Eight GPU

<!-- aicr-test
id: dataloader-one-node-replicated-short
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
make benchmark-dataloader CLUSTER={{cluster}} GPU_COUNT=8 MODE=replicated NODELIST={{node}} APPLY=1 DATALOADER_BATCH_SIZES=256 DATALOADER_NUM_WORKERS=8 DATALOADER_PREFETCH_FACTORS=4 DATALOADER_RUN_ARGS="--warmup-batches 20 --measured-batches 100 --byte-estimate-sample-count 0"
```

## Run Two Node Sharded Smoke

<!-- aicr-test
id: dataloader-two-node-sharded-short
suite: dataloader
kind: slurm-apply
safety: two-node
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Submitted"
-->
```bash
make benchmark-dataloader CLUSTER={{cluster}} GPU_COUNT=8 MODE=distributed-sharded DATALOADER_NODES=2 NODELIST={{nodes2}} APPLY=1 DATALOADER_BATCH_SIZES=256 DATALOADER_NUM_WORKERS=8 DATALOADER_PREFETCH_FACTORS=4 DATALOADER_RUN_ARGS="--warmup-batches 20 --measured-batches 100 --byte-estimate-sample-count 0"
```

## Scale Ladder Dry Run

Use `DATALOADER_NODES=1,2,4,8,16` for B200 and RTX scale-ladder studies.

```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=distributed-sharded DATALOADER_NODES=1,2,4,8,16 NODELIST=b0001,b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0013,b0014,b0015,b0016,b0017 DATALOADER_BATCH_SIZES=256 DATALOADER_NUM_WORKERS=16 DATALOADER_PREFETCH_FACTORS=4
```

## Node Selection

Use explicit `NODELIST` for documentation tests and applied smoke runs. Omit
`NODELIST` only when Slurm should choose from the available node pool.

## Repeat Runs

```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=replicated NODELIST=b0001 DATALOADER_REPEAT_COUNT=5 DATALOADER_REPEAT_AGGREGATION=olympic
```

## Rendered Report

DataLoader renders a Markdown report:

```bash
make render-dataloader CLUSTER=b200 DATE=today
```

The input-pipeline lab renderer is separate from the standard
DataLoader report:

```bash
make render-dataloader-input-lab CLUSTER=b200 DATE=today
```

Study-specific renderers that are not Make targets, such as the standard
ImageNet DALI optimization renderer, are documented on the
[scripts page](scripts.md) and in the command reference.

Input-path terminology and DALI, derived JPEG, and prepared-input
interpretation are summarized in
[Input Pipeline Reference](input-pipeline-reference.md).

## Custom Profiles

Use `PROFILE=medium|large` or `DATALOADER_PROFILE=small|medium|large` for
workload-intensity defaults, and `DATALOADER_RUN_ARGS` for explicit runner
overrides. `DATALOADER_BATCH_SIZES`, `DATALOADER_NUM_WORKERS`, and
`DATALOADER_PREFETCH_FACTORS` remain sweep axes. Use
`DATALOADER_DALI_GDS_CHUNK_SIZE`,
`DATALOADER_DALI_NUMPY_READER_PREFETCH_QUEUE_DEPTHS`,
`DATALOADER_CUFILE_LOG_PATH`, and `DATALOADER_CUFILE_LOG_LEVEL` only for DALI
NumPy GPU/O_DIRECT reader rows.

## Artifacts

DataLoader runs produce node or multi-node raw captures, parsed summaries, and
rendered report artifacts.

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
results/reports/<date>/dataloader/dataloader-report-<cluster>-<date>.json
results/reports/<date>/dataloader/dataloader-throughput-<cluster>-<date>.png
results/reports/<date>/dataloader/dataloader-rank-imbalance-<cluster>-<date>.png
```

Examples describe expected artifacts and link reviewed studies rather than raw
generated run trees.
