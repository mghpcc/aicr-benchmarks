#!/usr/bin/env bash
# TEMPLATE: Replace --partition and --gres placeholders before submitting.
#SBATCH --job-name=aicr-ddp-primitive
#SBATCH --partition=<rtx-batch-or-b200-batch>
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --mem=0
#SBATCH --gres=<gpu-type-and-count>
#SBATCH --time=02:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

# Replace the partition and GRES placeholders before submitting.
# AICR HPC scheduler examples:
#   RTX:  #SBATCH --partition=rtx-batch and #SBATCH --gres=gpu:rtx_pro_6000:8
#   B200: #SBATCH --partition=b200-batch and #SBATCH --gres=gpu:b200:8

REPO_ROOT="${AICR_BMARK_DIR:?set AICR_BMARK_DIR to your aicr-bench install root}"
cd "$REPO_ROOT"
source "${AICR_SETTINGS_FILE:-$REPO_ROOT/benchmark-settings.env}"
# Optional when GPU auto-detection is not enough:
# export AICR_CLUSTER_NAME=rtxpro6000
# export AICR_CLUSTER_NAME=b200

# Keep exactly one exec line active. Align #SBATCH nodes and tasks with it.
exec ./scripts/benchmark/run-ddp-resnet50.sh --launcher torchrun --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0
# exec ./scripts/benchmark/run-ddp-resnet50.sh --launcher srun --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0
