#!/bin/bash
# Submit benchmark jobs with recommended global batch size (GBS = 128 x total_GPUs).
# micro-batch-size stays at 4; gradient accumulation steps = GBS / (micro_bs x DP) = 32.
# Usage: bash submit.sh

# ---- RTX-6000 (2B-param model) ----
sbatch -p GPU1 -N 1 -n 1 --gpus-per-node=rtx6000:1  $1 job.sh  128   #  1 GPU  total
sbatch -p GPU1 -N 1 -n 1 --gpus-per-node=rtx6000:2  $1 job.sh  256   #  2 GPUs total
sbatch -p GPU1 -N 1 -n 1 --gpus-per-node=rtx6000:4  $1 job.sh  512   #  4 GPUs total
sbatch -p GPU1 -N 1 -n 1 --gpus-per-node=rtx6000:8  $1 job.sh  1024  #  8 GPUs total
sbatch -p GPU1 -N 2 -n 2 --gpus-per-node=rtx6000:1  $1 job.sh  256   #  2 GPUs total (2 nodes)
sbatch -p GPU1 -N 2 -n 2 --gpus-per-node=rtx6000:2  $1 job.sh  512   #  4 GPUs total (2 nodes)
sbatch -p GPU1 -N 2 -n 2 --gpus-per-node=rtx6000:4  $1 job.sh  1024  #  8 GPUs total (2 nodes)
sbatch -p GPU1 -N 2 -n 2 --gpus-per-node=rtx6000:8  $1 job.sh  2048  #  16 GPUs total (2 nodes)

# ---- B200 (7B-param model) ----
sbatch -p GPU2 -N 1 -n 1 --gpus-per-node=b200:1  $1 job.sh  128   #  1 GPU  total
sbatch -p GPU2 -N 1 -n 1 --gpus-per-node=b200:2  $1 job.sh  256   #  2 GPUs total
sbatch -p GPU2 -N 1 -n 1 --gpus-per-node=b200:4  $1 job.sh  512   #  4 GPUs total
sbatch -p GPU2 -N 1 -n 1 --gpus-per-node=b200:8  $1 job.sh  1024  #  8 GPUs total
sbatch -p GPU2 -N 2 -n 2 --gpus-per-node=b200:1  $1 job.sh  256   #  2 GPUs total (2 nodes)
sbatch -p GPU2 -N 2 -n 2 --gpus-per-node=b200:2  $1 job.sh  512   #  4 GPUs total (2 nodes)
sbatch -p GPU2 -N 2 -n 2 --gpus-per-node=b200:4  $1 job.sh  1024  #  8 GPUs total (2 nodes)
sbatch -p GPU2 -N 2 -n 2 --gpus-per-node=b200:8  $1 job.sh  2048  #  16 GPUs total (2 nodes)
