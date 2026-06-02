#!/usr/bin/env bash
#SBATCH --job-name=dataloader-derived-dataset
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=0
#SBATCH --time=04:00:00
#SBATCH --output=results/setup/%x-%j.out
#SBATCH --error=results/setup/%x-%j.err
set -euo pipefail

REPO_ROOT="${SLURM_SUBMIT_DIR:-$PWD}"
cd "$REPO_ROOT"

if [[ ! -f benchmark-settings.env ]]; then
  echo "ERROR: benchmark-settings.env not found in $REPO_ROOT" >&2
  echo "Submit this job from the repository root." >&2
  exit 1
fi

mkdir -p results/setup
# shellcheck disable=SC1091
source benchmark-settings.env

echo "AICR DataLoader derived dataset prep"
echo "host=$(hostname -s 2>/dev/null || hostname)"
echo "submit_dir=${SLURM_SUBMIT_DIR:-}"
echo "job_id=${SLURM_JOB_ID:-}"
echo "partition=${SLURM_JOB_PARTITION:-}"
echo "cpus_per_task=${SLURM_CPUS_PER_TASK:-}"
echo "args=$*"
echo

exec bash scripts/lib/run-repo-python.sh scripts/benchmark/prepare-dataloader-derived-dataset.py "$@"
