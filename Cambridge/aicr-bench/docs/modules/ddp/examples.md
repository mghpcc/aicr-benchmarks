# DDP Examples

This page shows a module-local Slurm workload, representative Make commands,
and the artifact classes produced by DDP ResNet-50 runs.

## Build Your Own Slurm Workload

This example starts from the script primitive directly. Keep one `exec` line
active and align the scheduler shape with the active launcher. Committed copy:
[slurm-ddp-resnet50.sbatch](slurm-ddp-resnet50.sbatch).

```bash
#!/usr/bin/env bash
#SBATCH --job-name=aicr-ddp-primitive
#SBATCH --partition=rtx-batch
##SBATCH --partition=b200-batch
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --mem=0
#SBATCH --gres=gpu:rtx_pro_6000:8
##SBATCH --gres=gpu:b200:8
#SBATCH --time=02:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

# Keep one matching partition/GRES pair active:
#   RTX:  #SBATCH --partition=rtx-batch   and #SBATCH --gres=gpu:rtx_pro_6000:8
#   B200: #SBATCH --partition=b200-batch  and #SBATCH --gres=gpu:b200:8

REPO_ROOT="${AICR_BMARK_DIR:?set AICR_BMARK_DIR to your aicr-bench install root}"
cd "$REPO_ROOT"
source "${AICR_SETTINGS_FILE:-$REPO_ROOT/benchmark-settings.env}"
# Optional when GPU auto-detection is not enough:
# export AICR_CLUSTER_NAME=rtxpro6000
# export AICR_CLUSTER_NAME=b200

# Keep exactly one exec line active. Align #SBATCH nodes and tasks with it.
# This is a minimal teaching shape. Study-quality rows use the tuned batch,
# worker, prefetch, warmup, and measured-iteration controls in the study pages.
exec ./scripts/benchmark/run-ddp-resnet50.sh --launcher torchrun --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0
# exec ./scripts/benchmark/run-ddp-resnet50.sh --launcher srun --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0
```

Select the scheduler partition/GRES pair, then submit the customized workload.
If the template was copied outside the install tree, pass the install root
explicitly:

```bash
sbatch --mem=0 --export=ALL,AICR_BMARK_DIR=/path/to/aicr-bench slurm-ddp-resnet50.sbatch
```

## Slurm Sbatch Scripts

Use the module-local primitive when you want a compact starting point. Use the
cluster-specific templates when you want the repo's cluster and launcher
defaults already spelled out.

- [slurm-ddp-resnet50.sbatch](slurm-ddp-resnet50.sbatch)
- [b200-ddp-resnet50-torchrun.sbatch](../../../slurm/benchmark/b200-ddp-resnet50-torchrun.sbatch)
- [b200-ddp-resnet50-srun.sbatch](../../../slurm/benchmark/b200-ddp-resnet50-srun.sbatch)
- [rtxpro6000-ddp-resnet50-torchrun.sbatch](../../../slurm/benchmark/rtxpro6000-ddp-resnet50-torchrun.sbatch)
- [rtxpro6000-ddp-resnet50-srun.sbatch](../../../slurm/benchmark/rtxpro6000-ddp-resnet50-srun.sbatch)

### Slurm Wrapper Syntax

The module-local primitive is shell-parseable without a Slurm allocation.

<!-- aicr-test
id: ddp-slurm-wrapper-syntax
suite: ddp
kind: local
safety: inspect
cwd: install-root
-->
```bash
bash -n docs/modules/ddp/slurm-ddp-resnet50.sbatch
```

## Using the Make Interface

### One-Node Dry Run

<!-- aicr-test
id: ddp-example-one-node-dry-run
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

Artifacts produced after `APPLY=1`:

- DDP command capture and rank metrics.
- Parsed throughput, epoch-time estimate, and status summaries.
- Rendered reports and charts after `make render-ddp-resnet50`.

### Multi-Node Submission

```bash
make benchmark-ddp-resnet50 CLUSTER=b200 NODES=4 NODELIST=b0002,b0003,b0004,b0005 APPLY=1 DDP_RUN_ARGS="--warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 8 --prefetch-factor 4"
```

Artifacts produced after `APPLY=1`:

- Multi-node DDP raw capture.
- Parsed rank and aggregate metrics.
- Study results and public artifacts are linked from [DDP studies](studies.md).

### Launcher Comparison Preview

Use this command to preview paired launcher submissions. Launcher-comparison
study rows use `--warmup-iters 100 --measured-iters 500` to match the module
timing standard.

```bash
make benchmark-ddp-launcher-comparison CLUSTER=b200 NODELIST=b0002,b0003,b0004,b0005 DDP_COMPARISON_SCALES=1,2,4 DDP_SRUN_CPU_BIND=none DDP_SRUN_MEM_BIND=none
```

## Render Or Replay Reports

```bash
make render-ddp-resnet50 CLUSTER=b200 DATE=2026-05-16
```

This rebuilds DDP ResNet-50 reports and figures from existing run summaries
under `results/by-date/<date>/...`. DDP studies and artifact bundles are
linked from [DDP studies](studies.md).
