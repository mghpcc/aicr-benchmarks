#!/usr/bin/env bash
#SBATCH --job-name=b200-nccl-suite-survey
#SBATCH --partition=GPU2
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:b200:8
#SBATCH --time=02:30:00
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

# shellcheck disable=SC1091
source benchmark-settings.env
export AICR_CLUSTER_NAME=b200
PEER_NODES_CSV="$(scontrol show hostnames "$SLURM_JOB_NODELIST" | paste -sd, -)"
export PEER_NODES_CSV
exec bash ./scripts/verify/run-nccl-suite.sh --scope survey --cluster b200 "$@"
