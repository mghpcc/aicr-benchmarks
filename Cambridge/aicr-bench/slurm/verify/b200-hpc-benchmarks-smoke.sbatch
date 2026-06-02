#!/usr/bin/env bash
#SBATCH --job-name=b200-hpc-benchmarks-smoke
#SBATCH --partition=b200-batch
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --mem=0
#SBATCH --gres=gpu:8
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
exec ./scripts/verify/smoke-test-hpc-benchmarks.sh "${HPCBENCH_IMAGE:-${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif}"
