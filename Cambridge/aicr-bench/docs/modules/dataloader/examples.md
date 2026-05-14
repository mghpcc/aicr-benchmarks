# DataLoader Examples

Purpose: provide a Slurm primitive workload, compact DataLoader Make examples, and expected artifact classes.

## Build Your Own Slurm Workload

This example starts from the script primitive directly. Keep one `exec` line active and comment out the others while customizing. Committed copy: [slurm-dataloader.sbatch](slurm-dataloader.sbatch).

```bash
#!/usr/bin/env bash
#SBATCH --job-name=aicr-dataloader-primitive
#SBATCH --partition=<GPU1-or-GPU2>
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --gres=<gpu-type-and-count>
#SBATCH --time=01:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

# Replace the partition and GRES placeholders before submitting.
# AICR HPC scheduler examples:
#   RTX:  #SBATCH --partition=GPU1 and #SBATCH --gres=gpu:rtxpro6000:8
#   B200: #SBATCH --partition=GPU2 and #SBATCH --gres=gpu:b200:8

REPO_ROOT="${AICR_BMARK_DIR:?set AICR_BMARK_DIR to your aicr-bench install root}"
cd "$REPO_ROOT"
source "${AICR_SETTINGS_FILE:-$REPO_ROOT/benchmark-settings.env}"
# Optional when GPU auto-detection is not enough:
# export AICR_CLUSTER_NAME=rtxpro6000
# export AICR_CLUSTER_NAME=b200

# Keep exactly one exec line active. Align #SBATCH nodes, tasks, and GPUs with it.
exec ./scripts/benchmark/run-dataloader.sh --profile large --nodes 1 --mode replicated --requested-gpu-count 8
# exec ./scripts/benchmark/run-dataloader.sh --profile large --nodes 1 --mode single --requested-gpu-count 1 --gpu 0
# exec ./scripts/benchmark/run-dataloader.sh --profile medium --nodes 1 --mode replicated --requested-gpu-count 8
# exec ./scripts/benchmark/run-dataloader.sh --profile large --nodes 2 --mode distributed-sharded --requested-gpu-count 16
```

Replace the scheduler placeholders, then submit the customized workload. If the template was copied outside the install tree, pass the install root explicitly:

```bash
sbatch --export=ALL,AICR_BMARK_DIR=/path/to/aicr-bench slurm-dataloader.sbatch
```

## Using the Make Interface

### One GPU Dry Run

<!-- aicr-test
id: dataloader-example-single-dry-run
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

Artifacts produced after `APPLY=1`:

- DataLoader command and environment capture.
- Rank metrics JSON.
- Rendered DataLoader report.
- Reviewed evidence and downloadable bundles live in [DataLoader studies](studies.md).

### Worker Sweep

<!-- aicr-test
id: dataloader-worker-sweep-dry-run
suite: dataloader
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Sweep point"
    - "workers=8"
-->
```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=replicated NODELIST=b0001 DATALOADER_BATCH_SIZES=64 DATALOADER_NUM_WORKERS=8,12,16,24,32 DATALOADER_PREFETCH_FACTORS=2 DATALOADER_PIN_MEMORY=1 DATALOADER_PERSISTENT_WORKERS=1 DATALOADER_CPUS_PER_TASK=16 DATALOADER_RUN_ARGS="--warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0"
```

Artifacts produced after `APPLY=1`:

- One submitted job per worker-count point.
- Per-point parsed throughput metrics.
- Reviewed tuning evidence lives in [DataLoader studies](studies.md).

### B200 Scale Sweep

<!-- aicr-test
id: dataloader-b200-scale-sweep-dry-run
suite: dataloader
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Nodes          : 1,2,4,8,16"
    - "Dry run only"
-->
```bash
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=distributed-sharded DATALOADER_NODES=1,2,4,8,16 NODELIST=b0001,b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0013,b0014,b0015,b0016,b0017 DATALOADER_BATCH_SIZES=64 DATALOADER_NUM_WORKERS=8 DATALOADER_PREFETCH_FACTORS=2 DATALOADER_PIN_MEMORY=1 DATALOADER_PERSISTENT_WORKERS=1 DATALOADER_CPUS_PER_TASK=16 DATALOADER_RUN_ARGS="--warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0"
```

Artifacts produced after `APPLY=1`:

- One submitted job per scale point.
- Parsed scale rows for the rendered report.
- Reviewed scale evidence lives in [DataLoader studies](studies.md).

### One-node Optimization Validation

Use a cheap single-GPU batch sweep to find the plateau region first. Then use
one-node, eight-GPU replicated sweeps to measure jitter and tune the real
multi-rank workload. A focused full matrix validates the one-node replicated
sweet spot after staged tuning. These examples are dry-runs until `APPLY=1` or
`--apply` is added.

Staged single-GPU batch sweep:

```bash
make benchmark-dataloader CLUSTER=b200 PROFILE=medium GPU_COUNT=1 MODE=single NODELIST=b0002 DATALOADER_BATCH_SIZES=256,512,768,1024 DATALOADER_NUM_WORKERS=16 DATALOADER_PREFETCH_FACTORS=4 DATALOADER_CPUS_PER_TASK=16 DATALOADER_REPEAT_COUNT=1
```

For single-GPU orientation, the larger batch sizes are plateau probes. Use them
to understand where throughput stops improving before choosing the one-node
replicated search space.

One-node replicated jitter pass:

```bash
make benchmark-dataloader CLUSTER=b200 PROFILE=medium GPU_COUNT=8 MODE=replicated NODELIST=b0002 DATALOADER_BATCH_SIZES=256,512,768,1024 DATALOADER_NUM_WORKERS=16 DATALOADER_PREFETCH_FACTORS=4 DATALOADER_CPUS_PER_TASK=16 DATALOADER_REPEAT_COUNT=5 DATALOADER_RUN_ARGS="--warmup-batches 100 --measured-batches 500"
```

Worker-count discovery after the jitter pass explains whether the default
workers `16` should move. Keep this broad worker sweep as a one-time discovery
step, not the repeated validation shape:

```bash
make benchmark-dataloader CLUSTER=b200 PROFILE=medium GPU_COUNT=8 MODE=replicated NODELIST=b0002 DATALOADER_BATCH_SIZES=512,768,1024 DATALOADER_NUM_WORKERS=8,12,16,24,32 DATALOADER_PREFETCH_FACTORS=4 DATALOADER_CPUS_PER_TASK=16 DATALOADER_REPEAT_COUNT=1 DATALOADER_RUN_ARGS="--warmup-batches 100 --measured-batches 500"
```

Final repeated one-node batch/prefetch scan with workers fixed at `16`:

```bash
scripts/benchmark/sweep-dataloader.sh --cluster b200 --profile medium --gpu-count 8 --mode replicated --nodelist b0002 --batch-size-list 384,512,640,768,896,1024 --num-workers-list 16 --prefetch-factor-list 2,4,8 --pin-memory-list 1 --persistent-workers-list 1 --cpus-per-task 16 --repeat-count 5 -- --warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0
```

Add `--apply` only after the dry-run shows the expected `90` one-node jobs.
Use `896` and `1024` as one-node ceiling comparators; scale candidates should
normally come from `384,512,640,768` unless larger batches validate cleanly.

### Synthetic Olympic Aggregation Fixture

The DataLoader renderer has a committed synthetic known-answer fixture for the
Olympic repeat rule. It is not benchmark evidence. It exists so executable docs
can prove that the renderer drops the lowest and highest throughput samples,
then computes paired metrics from the retained jobs.

<!-- aicr-test
id: dataloader-synthetic-olympic-fixture
suite: dataloader
kind: local
safety: inspect
cwd: install-root
expect:
  mode: contains
  patterns:
    - "fixture=dataloader-olympic-repeat-known-answer"
    - "aggregated_config_count=1"
    - "olympic_samples_per_second=120.00"
    - "rank_imbalance_percent=3.00"
    - "dropped_samples_per_second=100.00/140.00"
-->
```bash
python3 tests/scripts/check-dataloader-olympic-fixture.py
```

The same fixture also checks the rendered Markdown and interactive HTML report
shape. This proves the renderer keeps the expected sections and labels without
using live benchmark results.

<!-- aicr-test
id: dataloader-synthetic-report-shape-fixture
suite: dataloader
kind: local
safety: inspect
cwd: install-root
expect:
  mode: contains
  patterns:
    - "fixture=dataloader-olympic-repeat-known-answer"
    - "markdown_shape=passed"
    - "interactive_html_shape=passed"
-->
```bash
python3 tests/scripts/check-dataloader-report-shape-fixture.py
```

Artifacts produced after applied collection:

- Single-GPU surface rows and one-node 8-GPU replicated rows in the rendered
  DataLoader report.
- Submitted job count and wall-clock campaign time for each stage.
- Curated study pages for B200 and RTX that separate one-GPU discovery,
  one-node validation, and multi-node scale plans.
