#!/usr/bin/env bash
#SBATCH --job-name=aicr-hpl-mxp-primitive
#SBATCH --partition=b200-batch
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --mem=0
#SBATCH --gres=gpu:b200:8
#SBATCH --time=00:30:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

# This primitive is a B200 smoke template. For routine rows, prefer
# make benchmark-hpl-mxp or scripts/benchmark/submit-hpl-mxp.sh so the
# submitter resolves the reviewed NPS4-derived placement.

REPO_ROOT="${AICR_BMARK_DIR:?set AICR_BMARK_DIR to your aicr-bench install root}"
cd "$REPO_ROOT"
source "${AICR_SETTINGS_FILE:-$REPO_ROOT/benchmark-settings.env}"

# Keep exactly one exec line active. Direct runner use must carry the reviewed
# NPS4-derived CPU, memory, GPU, and UCX maps explicitly.
exec ./scripts/benchmark/run-hpl-mxp.sh \
  --cluster b200 \
  --nodes 1 \
  --preset smoke \
  --matrix-size 8192 \
  --nb 1024 \
  --cpu-affinity 16-31:32-47:48-63:0-15:80-95:96-111:112-127:64-79 \
  --mem-affinity 1:2:3:0:5:6:7:4 \
  --ucx-affinity mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_6:mlx5_11
# exec ./scripts/benchmark/run-hpl-mxp.sh \
#   --cluster b200 \
#   --nodes 1 \
#   --preset weak-study \
#   --matrix-size 379904 \
#   --nb 2048 \
#   --nprow 4 \
#   --npcol 2 \
#   --scaling-study weak \
#   --cpu-affinity 16-31:32-47:48-63:0-15:80-95:96-111:112-127:64-79 \
#   --mem-affinity 1:2:3:0:5:6:7:4 \
#   --ucx-affinity mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_6:mlx5_11
