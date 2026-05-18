#!/usr/bin/env bash
#SBATCH --job-name=rtx-nccl-suite-scale
#SBATCH --partition=GPU1
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:rtx_pro_6000:8
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
export AICR_CLUSTER_NAME=rtxpro6000
PEER_NODES_CSV="$(scontrol show hostnames "$SLURM_JOB_NODELIST" | paste -sd, -)"
export PEER_NODES_CSV
exec bash ./scripts/verify/run-nccl-suite.sh --scope scale --cluster rtxpro6000 "$@"
