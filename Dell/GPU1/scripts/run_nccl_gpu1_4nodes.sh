#!/bin/bash
#SBATCH --job-name=nccl_gpu1
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=8
#SBATCH --gres=gpu:rtx6000:8
#SBATCH --partition=GPU1
#SBATCH --time=00:30:00
#SBATCH --output=slurm-%x.%J.%N.out

set -x

DATESTRING=`date "+%Y-%m-%dT%H:%M:%S"`

SIF=/home/knevins/aicr-benchmarks/hpc-benchmarks_25.09.sif
NCCL_BIN=/workspace/microbenchmarks/nccl_tests.sh

echo "Running on hosts: $(echo $(scontrol show hostname))"
echo "$DATESTRING"

srun -N4 --ntasks-per-node=8 --exclusive --mpi=pmix \
    apptainer exec --nv \
    --no-mount /etc/localtime \
    --bind /var/spool/slurm/slurmd \
    "${SIF}" \
    ${NCCL_BIN} --op allreduce --test-params "-b 8 -e 128M -f 2 -g 1"

echo "Done"
echo "$DATESTRING"
