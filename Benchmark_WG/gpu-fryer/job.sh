#!/bin/bash
#SBATCH -p GPU2  # 2 # 1  #2  # GPU1
#SBATCH -t 01:00:00
#SBATCH --mem=300GB
#SBATCH -N 1
#SBATCH -n 1  # 8  # 8
#SBATCH -c 8  # tokio needs >1 worker so timer/progress tasks aren't starved by burn_gpu loop
#SBATCH --gres=gpu:1  # b200:1  #rtx6000:8   # b200:8
#SBATCH -o output/%N-%J.out

which singularity
singularity --version

SING_BASE="singularity exec --nv -B /lib64:/home/shaohao/lib64"
#SIF="/home/shaohao_mit/benchmarks/image/gpu-fryer_1.1.0.sif"
SIF="/home/shaohao_mit/benchmarks/image/gpu-fryer_sha-704ba85.sif"
FLAGS="--nvml-lib-path /home/shaohao/lib64/libnvidia-ml.so.1"
ELAPSE="300"

echo "Number of GPUs = $SLURM_GPUS $SLURM_GPUS_ON_NODE"

SING_CMD="$SING_BASE $PRESERVE"

echo "======== Run with fp32 =========="
$SING_CMD $SIF gpu-fryer --use-fp32 $FLAGS $ELAPSE
echo "======== Run with bf16 =========="
$SING_CMD $SIF gpu-fryer --use-bf16 $FLAGS $ELAPSE
echo "======== Run with fp8  =========="
$SING_CMD $SIF gpu-fryer --use-fp8 $FLAGS $ELAPSE
