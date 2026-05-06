#!/bin/bash
#SBATCH -p GPU2  #2  # GPU1
#SBATCH -t 100
#SBATCH -N 2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --mem=50GB
#SBATCH --gpu-bind=closest
#SBATCH -J nvhpc-26.3
#SBATCH -o out-2node/%x-%N-%J
#SBATCH --exclusive

job_name=$SLURM_JOB_NAME
BUILD_DIR=../build-$job_name

module load nvhpc/26.3
export NVHPC_HOME=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3
export CUDA_HOME="$NVHPC_HOME/cuda"
export NCCL_HOME="$NVHPC_HOME/comm_libs/nccl"
export SHARP_HOME="$NVHPC_HOME/comm_libs/13.1/hpcx/hpcx-2.25.1/sharp"
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$NCCL_HOME/lib:$SHARP_HOME/lib:$LD_LIBRARY_PATH

# IBext (nccl_rdma_sharp_plugin) must remain as the net plugin for SHARP collnet to activate.
# Do NOT strip it or override with NCCL_NET=IB.

mpirun hostname
which mpirun
which nvcc
echo "Bin dir = $BUILD_DIR"

MIN_SIZE=1M
MAX_SIZE=16G
FACTOR=4
GPUS_PER_TASK=1

echo "num_cpu = num_mpi_tasks = $SLURM_NTASKS"
echo "num_gpu_per_task = $GPUS_PER_TASK"

#export NCCL_DEBUG=INFO
#export NCCL_DEBUG_SUBSYS=NET
#export NCCL_MIN_NCHANNELS=4
# NCCL_NET=IB disabled: IBext must be the net plugin for SHARP to work.
#export NCCL_NET=IB
#export NCCL_NET_SHARED_COMMS=0
#export NCCL_IB_QPS_PER_CONNECTION=4
#export NCCL_NCHANNELS_PER_NET_PEER=4

# SHARP: offload AllReduce to IB switch hardware, bypassing GDRDMA bidirectional bottleneck.
# Requires IBext as the net plugin (see above).
#export NCCL_COLLNET_ENABLE=1
#export SHARP_COLL_LOCK_ON_COMM_INIT=1

# export CUDA_VISIBLE_DEVICES=3 
# export NCCL_IB_HCA=mlx5_3      

for program in sendrecv_perf reduce_perf broadcast_perf gather_perf scatter_perf  reduce_scatter_perf all_gather_perf all_reduce_perf alltoall_perf hypercube_perf
do
   echo "%%%%%%%%% $program %%%%%%%%%%"
   mpirun -np $SLURM_NTASKS --mca btl_openib_warn_no_device_params_found 0 $BUILD_DIR/$program -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK
done

