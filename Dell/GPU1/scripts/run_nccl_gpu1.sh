#!/bin/bash
#SBATCH --job-name=nccl_gpu1
#SBATCH --nodes=1
#SBATCH --partition=GPU1
#SBATCH --time=00:30:00
#SBATCH --exclusive
#SBATCH --output=slurm-%x.%J.%N.out

DATESTRING=`date "+%Y-%m-%dT%H:%M:%S"`

SIF=/home/knevins/aicr-benchmarks/hpc-benchmarks_25.09.sif
NCCL_BIN=/workspace/microbenchmarks/nccl_tests

echo "Running on hosts: $(echo $(scontrol show hostname))"
echo "$DATESTRING"

srun apptainer exec --nv \
  --no-mount /etc/localtime \
  "${SIF}" \
  ${NCCL_BIN}/all_reduce_perf -b 8 -e 8G -f 2 -g 8

echo "Done"
echo "$DATESTRING"
