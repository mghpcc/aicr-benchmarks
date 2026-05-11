#!/bin/bash
# Submit benchmark jobs using job_all.sh (universal replacement for job.sh
# that fixes the 2-node sub-allocation hang for 2 x {1,2,4} GPUs/node).
# Recommended global batch size: GBS = 128 x total_GPUs.
# micro-batch-size stays at 4; gradient accumulation steps = GBS / (micro_bs x DP) = 32.
# Usage: bash submit_all.sh [output_dir]
#   output_dir : directory for sbatch stdout files (default: output)
#                Overrides the `#SBATCH -o output/out.%N-%J` directive in job_all.sh.

OUTDIR=${1:-output}
mkdir -p "$OUTDIR"
OUT_FLAG="--output=$OUTDIR/out.%N-%J"

# ---- RTX-6000 (2B-param model) ----
sbatch -p GPU1 -N 1 -n 1 --gpus-per-node=rtx6000:1  $OUT_FLAG job_all.sh 128   #  1 GPU  total
sbatch -p GPU1 -N 1 -n 1 --gpus-per-node=rtx6000:2  $OUT_FLAG job_all.sh 256   #  2 GPUs total
sbatch -p GPU1 -N 1 -n 1 --gpus-per-node=rtx6000:4  $OUT_FLAG job_all.sh 512   #  4 GPUs total
sbatch -p GPU1 -N 1 -n 1 --gpus-per-node=rtx6000:8  $OUT_FLAG job_all.sh 1024  #  8 GPUs total
sbatch -p GPU1 -N 2 -n 2 --gpus-per-node=rtx6000:1  $OUT_FLAG job_all.sh 256   #  2 GPUs total (2 nodes)
sbatch -p GPU1 -N 2 -n 2 --gpus-per-node=rtx6000:2  $OUT_FLAG job_all.sh 512   #  4 GPUs total (2 nodes)
sbatch -p GPU1 -N 2 -n 2 --gpus-per-node=rtx6000:4  $OUT_FLAG job_all.sh 1024  #  8 GPUs total (2 nodes)
sbatch -p GPU1 -N 2 -n 2 --gpus-per-node=rtx6000:8  $OUT_FLAG job_all.sh 2048  #  16 GPUs total (2 nodes)

# ---- B200 (7B-param model) ----
sbatch -p GPU2 -N 1 -n 1 --gpus-per-node=b200:1  $OUT_FLAG job_all.sh 128   #  1 GPU  total
sbatch -p GPU2 -N 1 -n 1 --gpus-per-node=b200:2  $OUT_FLAG job_all.sh 256   #  2 GPUs total
sbatch -p GPU2 -N 1 -n 1 --gpus-per-node=b200:4  $OUT_FLAG job_all.sh 512   #  4 GPUs total
sbatch -p GPU2 -N 1 -n 1 --gpus-per-node=b200:8  $OUT_FLAG job_all.sh 1024  #  8 GPUs total
sbatch -p GPU2 -N 2 -n 2 --gpus-per-node=b200:1  $OUT_FLAG job_all.sh 256   #  2 GPUs total (2 nodes)
sbatch -p GPU2 -N 2 -n 2 --gpus-per-node=b200:2  $OUT_FLAG job_all.sh 512   #  4 GPUs total (2 nodes)
sbatch -p GPU2 -N 2 -n 2 --gpus-per-node=b200:4  $OUT_FLAG job_all.sh 1024  #  8 GPUs total (2 nodes)
sbatch -p GPU2 -N 2 -n 2 --gpus-per-node=b200:8  $OUT_FLAG job_all.sh 2048  #  16 GPUs total (2 nodes)
