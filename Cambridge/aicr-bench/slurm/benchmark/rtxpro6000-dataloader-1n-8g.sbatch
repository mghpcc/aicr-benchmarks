#!/usr/bin/env bash
#SBATCH --job-name=rtxpro6000-dataloader-1n-8g
#SBATCH --partition=GPU1
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:8
#SBATCH --time=01:00:00
#SBATCH --output=results/slurm/%x-%j.out
#SBATCH --error=results/slurm/%x-%j.err
set -euo pipefail

REPO_ROOT="${SLURM_SUBMIT_DIR:-$PWD}"
cd "$REPO_ROOT"

if [[ ! -f benchmark-settings.env ]]; then
  echo "ERROR: benchmark-settings.env not found in $REPO_ROOT" >&2
  echo "Submit this job from the repository root." >&2
  exit 1
fi

mkdir -p results/slurm
# shellcheck disable=SC1091
source benchmark-settings.env
export AICR_CLUSTER_NAME=rtxpro6000
if [[ -z "${CUDA_VISIBLE_DEVICES:-}" && -n "${SLURM_JOB_GPUS:-}" ]]; then
  export CUDA_VISIBLE_DEVICES="${SLURM_JOB_GPUS}"
fi
export DATALOADER_BATCH_SIZE="${DATALOADER_BATCH_SIZE:-256}"
export DATALOADER_NUM_WORKERS="${DATALOADER_NUM_WORKERS:-8}"
export DATALOADER_PREFETCH_FACTOR="${DATALOADER_PREFETCH_FACTOR:-4}"
export DATALOADER_PIN_MEMORY="${DATALOADER_PIN_MEMORY:-1}"
export DATALOADER_PERSISTENT_WORKERS="${DATALOADER_PERSISTENT_WORKERS:-1}"
export DATALOADER_WARMUP_BATCHES="${DATALOADER_WARMUP_BATCHES:-5}"
export DATALOADER_MEASURED_BATCHES="${DATALOADER_MEASURED_BATCHES:-10}"
export DATALOADER_MODE="${DATALOADER_MODE:-replicated}"
export DATALOADER_REQUESTED_GPU_COUNT="${DATALOADER_REQUESTED_GPU_COUNT:-8}"

exec ./scripts/benchmark/run-dataloader.sh "$@"
