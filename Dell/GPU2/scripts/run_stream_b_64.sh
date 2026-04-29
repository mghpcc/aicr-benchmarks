#!/bin/bash
#SBATCH --job-name=stream_benchmark_fp64
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:15:00
#SBATCH --partition=GPU2
#SBATCH --gres=gpu:8
#SBATCH --output=slurm-%x.%J.%N.out

echo "Job started at: $(date "+%Y-%m-%dT%H:%M:%S")"
echo "Running on hosts: $(scontrol show hostname)"

SIF=/home/knevins/aicr-benchmarks/hpc-benchmarks_25.09.sif

srun --cpu-bind=none --mpi=pmix --gres=gpu:8 \
    apptainer exec --nv --no-mount /etc/localtime \
    ${SIF} \
    /workspace/stream-gpu-test.sh \
    --d 0 \
    --n 1000000000 \
    --t CSAT

echo "Job finished at: $(date "+%Y-%m-%dT%H:%M:%S")"