#!/usr/bin/env bash
#SBATCH --job-name=aicr-dataloader-primitive
#SBATCH --partition=rtx-batch
##SBATCH --partition=b200-batch
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --mem=0
#SBATCH --gres=gpu:rtx_pro_6000:8
##SBATCH --gres=gpu:b200:8
#SBATCH --time=01:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

# Keep one matching partition/GRES pair active:
#   RTX:  #SBATCH --partition=rtx-batch   and #SBATCH --gres=gpu:rtx_pro_6000:8
#   B200: #SBATCH --partition=b200-batch  and #SBATCH --gres=gpu:b200:8

looks_like_aicr_bench_root() {
  [[ -n "${1:-}" && -d "$1/scripts" && -f "$1/benchmark-settings.env.example" ]]
}

resolve_repo_root() {
  if looks_like_aicr_bench_root "${AICR_BMARK_DIR:-}"; then
    cd "$AICR_BMARK_DIR" && pwd -P
    return 0
  fi

  local script_dir=""
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  local candidate
  for candidate in "$script_dir/../../.." "$script_dir/../.." "$script_dir/.." "$script_dir"; do
    if looks_like_aicr_bench_root "$candidate"; then
      cd "$candidate" && pwd -P
      return 0
    fi
  done

  if looks_like_aicr_bench_root "${SLURM_SUBMIT_DIR:-}"; then
    cd "$SLURM_SUBMIT_DIR" && pwd -P
    return 0
  fi

  echo "ERROR: could not locate an AICR-Bench install root." >&2
  echo "Submit with: sbatch --mem=0 --export=ALL,AICR_BMARK_DIR=/path/to/aicr-bench $(basename "${BASH_SOURCE[0]}")" >&2
  return 1
}

REPO_ROOT="$(resolve_repo_root)"
export AICR_BMARK_DIR="$REPO_ROOT"
cd "$REPO_ROOT"

SETTINGS_FILE="${AICR_SETTINGS_FILE:-$AICR_BMARK_DIR/benchmark-settings.env}"
if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo "ERROR: settings file not found: $SETTINGS_FILE" >&2
  echo "Create one from benchmark-settings.env.example or set AICR_SETTINGS_FILE." >&2
  exit 1
fi

mkdir -p "$AICR_BMARK_DIR/results/slurm"
exec > >(tee -a "$AICR_BMARK_DIR/results/slurm/${SLURM_JOB_NAME:-aicr-dataloader-primitive}-${SLURM_JOB_ID:-manual}.out")
exec 2> >(tee -a "$AICR_BMARK_DIR/results/slurm/${SLURM_JOB_NAME:-aicr-dataloader-primitive}-${SLURM_JOB_ID:-manual}.err" >&2)

# shellcheck disable=SC1091
source "$SETTINGS_FILE"
# Optional when GPU auto-detection is not enough:
# export AICR_CLUSTER_NAME=rtxpro6000
# export AICR_CLUSTER_NAME=b200

# Keep exactly one exec line active. Align #SBATCH nodes, tasks, and GPUs with it.
exec ./scripts/benchmark/run-dataloader.sh --profile small --nodes 1 --mode replicated --requested-gpu-count 8
# exec ./scripts/benchmark/run-dataloader.sh --profile small --nodes 1 --mode single --requested-gpu-count 1 --gpu 0
# exec ./scripts/benchmark/run-dataloader.sh --profile medium --nodes 1 --mode replicated --requested-gpu-count 8
# exec ./scripts/benchmark/run-dataloader.sh --profile small --nodes 2 --mode distributed-sharded --requested-gpu-count 16
