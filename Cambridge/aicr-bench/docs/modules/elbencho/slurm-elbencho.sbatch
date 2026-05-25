#!/usr/bin/env bash
#SBATCH --job-name=aicr-elbencho-primitive
#SBATCH --partition=<rtx-batch-or-b200-batch>
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=64
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --time=01:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

REPO_ROOT="${AICR_BMARK_DIR:?set AICR_BMARK_DIR to your aicr-bench install root}"
cd "$REPO_ROOT"
source "${AICR_SETTINGS_FILE:-$REPO_ROOT/benchmark-settings.env}"

export ELBENCHO_TARGET_ROOT="${ELBENCHO_TARGET_ROOT:-/scratch/$USER/elbencho}"

# Keep exactly one exec line active. Use the committed profile templates first.
exec ./scripts/benchmark/run-elbencho.sh --cluster b200 --workload small-block --profile small --command "$(cat configs/elbencho/profiles/small/small-block.sh)"
# exec ./scripts/benchmark/run-elbencho.sh --cluster b200 --workload metadata --profile small --command "$(cat configs/elbencho/profiles/small/metadata.sh)"
