#!/bin/bash
#SBATCH -p GPU1  # GPU1
#SBATCH -t 100
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8  # allocate all, restrict via CUDA_VISIBLE_DEVICES
#SBATCH --mem=200GB
#SBATCH -J nvhpc-26.3
#SBATCH -o out-1socket/%x-%N-%J
#SBATCH --exclusive

job_name=$SLURM_JOB_NAME
BUILD_DIR=../build-$job_name

module load nvhpc/26.3
export NVHPC_HOME=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3
export CUDA_HOME="$NVHPC_HOME/cuda"
export NCCL_HOME="$NVHPC_HOME/comm_libs/nccl"
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$NCCL_HOME/lib:$LD_LIBRARY_PATH

# GPUs 0-3: socket 0 (PCIe domain 0000:), GPUs 4-7: socket 1 (domain 0001:)
# 4 GPUs from socket 0 + 1 GPU from socket 1 to probe cross-socket P2P
export CUDA_VISIBLE_DEVICES=0,1,2,3,4

mpirun hostname
which mpirun
which nvcc
echo "Bin dir = $BUILD_DIR"

MIN_SIZE=1M
MAX_SIZE=16G
FACTOR=4
GPUS_PER_TASK=5

echo "num_cpu = num_mpi_tasks = $SLURM_NTASKS"
echo "num_gpu_per_task = $GPUS_PER_TASK"

#export NCCL_DEBUG=INFO

for program in sendrecv_perf reduce_perf broadcast_perf gather_perf scatter_perf  reduce_scatter_perf all_gather_perf all_reduce_perf alltoall_perf hypercube_perf
do
   echo "%%%%%%%%% $program %%%%%%%%%%"
   mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 $BUILD_DIR/$program -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK
done
