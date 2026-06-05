#!/bin/bash
#SBATCH -p b200-batch
#SBATCH -t 30
#SBATCH -N 2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=2
#SBATCH --mem=200GB
#SBATCH --gpu-bind=closest
#SBATCH -J nvhpc-26.3-sharp-ab
#SBATCH -o out-2node/%x-%N-%J

# Clean A/B AllReduce comparison at 4 GPUs (2 per node x 2 nodes), NCCL_DEBUG OFF so
# the perf tables are not corrupted by interleaved debug. Answers: does SHARP improve
# 2-node AllReduce bandwidth?
#   Run A = SHARP OFF: NCCL_COLLNET_ENABLE=0, default algo (NCCL picks Ring/Tree)
#   Run B = SHARP ON : NCCL_COLLNET_ENABLE=1, NCCL_ALGO=CollNetChain,CollNetDirect forced

BUILD_DIR=../build-nvhpc-26.3
module load nvhpc/26.3
export NVHPC_HOME=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3
export CUDA_HOME="$NVHPC_HOME/cuda"
export NCCL_HOME="$NVHPC_HOME/comm_libs/nccl"
export SHARP_HOME="$NVHPC_HOME/comm_libs/13.1/hpcx/hpcx-2.25.1/sharp"
export NCCL_PLUGIN_HOME="$NVHPC_HOME/comm_libs/13.1/hpcx/hpcx-2.25.1/nccl_rdma_sharp_plugin"
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$NCCL_HOME/lib:$NCCL_PLUGIN_HOME/lib:$SHARP_HOME/lib:$LD_LIBRARY_PATH
export LD_PRELOAD=/lib64/libnuma.so.1${LD_PRELOAD:+:$LD_PRELOAD}

export NCCL_IB_HCA="^mlx5_7,mlx5_8,mlx5_9,mlx5_10"
export SHARP_COLL_LOCK_ON_COMM_INIT=1

MIN_SIZE=1M; MAX_SIZE=16G; FACTOR=4; GPUS_PER_TASK=2
COMMON="-x LD_PRELOAD=$LD_PRELOAD -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH -x NCCL_IB_HCA=$NCCL_IB_HCA -x SHARP_COLL_LOCK_ON_COMM_INIT=$SHARP_COLL_LOCK_ON_COMM_INIT"

echo "%%%%%%%%% RUN A: SHARP OFF (default algo, Ring) %%%%%%%%%%"
mpirun -np $SLURM_NTASKS --bind-to none $COMMON -x NCCL_COLLNET_ENABLE=0 \
   --mca btl_openib_warn_no_device_params_found 0 \
   $BUILD_DIR/all_reduce_perf -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK

echo "%%%%%%%%% RUN B: SHARP ON (forced CollNet/SHARP) %%%%%%%%%%"
mpirun -np $SLURM_NTASKS --bind-to none $COMMON -x NCCL_COLLNET_ENABLE=1 \
   -x NCCL_ALGO=CollNetChain,CollNetDirect -x NCCL_PROTO=Simple \
   --mca btl_openib_warn_no_device_params_found 0 \
   $BUILD_DIR/all_reduce_perf -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK
