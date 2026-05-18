#!/usr/bin/env bash
#SBATCH --job-name=b200-gpu-topology-1n-8g
#SBATCH --partition=GPU2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:b200:8
#SBATCH --time=00:10:00
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
source benchmark-settings.env
export AICR_CLUSTER_NAME=b200
exec ./scripts/verify/run-gpu-topology.sh
