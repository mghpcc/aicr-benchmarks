#!/bin/bash
# Submit benchmark jobs with recommended global batch size (GBS = 128 x total_GPUs).
# micro-batch-size stays at 4; gradient accumulation steps = GBS / (micro_bs x DP) = 32.
# Usage: bash submit.sh [output_dir]
#   output_dir : directory for sbatch stdout files (default: output)
#                Overrides the `#SBATCH -o output/out.%N-%J` directive in job.sh.

OUTDIR=${1:-output}
mkdir -p "$OUTDIR"
OUT_FLAG="--output=$OUTDIR/out.%N-%J"

# ---- RTX-6000 (2B-param model) ----
sbatch -p rtx-batch -N 1 -n 1 --gpus-per-node=rtx_pro_6000:1  $OUT_FLAG job.sh 128   #  1 GPU  total
sbatch -p rtx-batch -N 1 -n 1 --gpus-per-node=rtx_pro_6000:2  $OUT_FLAG job.sh 256   #  2 GPUs total
sbatch -p rtx-batch -N 1 -n 1 --gpus-per-node=rtx_pro_6000:4  $OUT_FLAG job.sh 512   #  4 GPUs total
sbatch -p rtx-batch -N 1 -n 1 --gpus-per-node=rtx_pro_6000:8  $OUT_FLAG job.sh 1024  #  8 GPUs total
sbatch -p rtx-batch -N 2 -n 2 --gpus-per-node=rtx_pro_6000:1  $OUT_FLAG job.sh 256   #  2 GPUs total (2 nodes)
sbatch -p rtx-batch -N 2 -n 2 --gpus-per-node=rtx_pro_6000:2  $OUT_FLAG job.sh 512   #  4 GPUs total (2 nodes)
sbatch -p rtx-batch -N 2 -n 2 --gpus-per-node=rtx_pro_6000:4  $OUT_FLAG job.sh 1024  #  8 GPUs total (2 nodes)
sbatch -p rtx-batch -N 2 -n 2 --gpus-per-node=rtx_pro_6000:8  $OUT_FLAG job.sh 2048  #  16 GPUs total (2 nodes)

# ---- B200 (7B-param model) ----
sbatch -p b200-batch -N 1 -n 1 --gpus-per-node=b200:1  $OUT_FLAG job.sh 128   #  1 GPU  total
sbatch -p b200-batch -N 1 -n 1 --gpus-per-node=b200:2  $OUT_FLAG job.sh 256   #  2 GPUs total
sbatch -p b200-batch -N 1 -n 1 --gpus-per-node=b200:4  $OUT_FLAG job.sh 512   #  4 GPUs total
sbatch -p b200-batch -N 1 -n 1 --gpus-per-node=b200:8  $OUT_FLAG job.sh 1024  #  8 GPUs total
sbatch -p b200-batch -N 2 -n 2 --gpus-per-node=b200:1  $OUT_FLAG job.sh 256   #  2 GPUs total (2 nodes)
sbatch -p b200-batch -N 2 -n 2 --gpus-per-node=b200:2  $OUT_FLAG job.sh 512   #  4 GPUs total (2 nodes)
sbatch -p b200-batch -N 2 -n 2 --gpus-per-node=b200:4  $OUT_FLAG job.sh 1024  #  8 GPUs total (2 nodes)
sbatch -p b200-batch -N 2 -n 2 --gpus-per-node=b200:8  $OUT_FLAG job.sh 2048  #  16 GPUs total (2 nodes)
