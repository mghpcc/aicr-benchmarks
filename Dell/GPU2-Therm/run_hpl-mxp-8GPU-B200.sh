#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:8
#SBATCH --partition=GPU2

SCRATCH=/home/knevins/aicr-benchmarks/

apptainer run --no-mount /etc/localtime --nv \
  $SCRATCH/hpc-benchmarks_26.02.sif \
  mpirun --np 8 \
  /workspace/hpl-mxp.sh \
  --n 376832 \
  --nb 2048 \
  --nprow 2 \
  --npcol 4 \
  --nporder row \
  --gpu-affinity 0:1:2:3:4:5:6:7
