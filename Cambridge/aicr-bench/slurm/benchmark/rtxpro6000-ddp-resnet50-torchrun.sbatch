#!/usr/bin/env bash
#SBATCH --job-name=rtxpro6000-ddp-r50-torchrun
#SBATCH --partition=rtx-batch
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=128
#SBATCH --mem=0
#SBATCH --gres=gpu:rtx_pro_6000:8
#SBATCH --time=02:00:00
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

exec ./scripts/benchmark/run-ddp-resnet50.sh --launcher torchrun "$@"
