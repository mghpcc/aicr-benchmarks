#!/bin/bash
#SBATCH --job-name=nccl_gpu2
#SBATCH --time=02:00:00
#SBATCH --partition=GPU2
#SBATCH --gres=gpu:b200:8
#SBATCH --output=slurm-%x.%J.%N.out

SIF="/home/knevins/aicr-benchmarks/hpc-benchmarks_25.09.sif"
NCCL_BIN=/workspace/microbenchmarks/nccl_tests

echo "Running on hosts: $(echo $(scontrol show hostname))"
echo "$DATESTRING"

# Default nccl-test arguments
TEST_ARGS="-dfloat -b8 -e16G -f2"

srun apptainer exec --nv \
  --no-mount /etc/localtime \
  "${SIF}" \
  ${NCCL_BIN}/all_reduce_perf ${TEST_ARGS}


echo COMPLETED  test
