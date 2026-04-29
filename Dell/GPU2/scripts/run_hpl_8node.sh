#!/bin/bash
#SBATCH --job-name=hpl_8node_b200
#SBATCH --partition=GPU2
#SBATCH --nodes=8
#SBATCH --ntasks-per-node=8
#SBATCH --gres=gpu:b200:8
#SBATCH --exclusive
#SBATCH --time=04:00:00
#SBATCH --output=slurm-%x.%J.%N.out


SIF=${HOME}/aicr-benchmarks/hpc-benchmarks_26.02.sif

srun \
    --cpu-bind=none \
    --mpi=pmix \
    apptainer exec --nv \
    --bind /usr/lib64/libibverbs:/usr/lib64/libibverbs \
    --bind /etc/libibverbs.d:/etc/libibverbs.d \
    --bind /var/spool/slurm/slurmd \
    --no-mount /etc/localtime \
    ${SIF} \
    /workspace/hpl.sh --dat /workspace/hpl-linux-x86_64/sample-dat/HPL-64GPUs.dat