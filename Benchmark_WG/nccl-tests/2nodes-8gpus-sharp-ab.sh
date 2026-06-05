#!/bin/bash
#SBATCH -p b200-batch
#SBATCH -t 30
#SBATCH -N 2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=8
#SBATCH --mem=200GB
#SBATCH --gpu-bind=closest
#SBATCH -J nvhpc-26.3-sharp-ab8
#SBATCH -o out-2node/%x-%N-%J

# Clean A/B AllReduce comparison at 16 GPUs (8 per node x 2 nodes), NCCL_DEBUG mostly off.
# Goal: make SHARP actually work at 8 GPU/node and measure if AllReduce beats Ring.
#
# KEY FIX vs earlier 8-GPU runs: exclude mlx5_12 as well. At 8 GPU/node NCCL maps GPU7
# to mlx5_12 (HCA 8), whose IB port is NOT on the SHARP tree -> sharpd rejects it with
# "Unknown port" / "Cannot create SHARP job(-11)" on rank 7, so CollNet never forms and
# the forced AllReduce dies with "no algorithm/protocol available". Excluding mlx5_12
# leaves exactly 8 SHARP-good NICs (mlx5_0..6 + mlx5_11) for the 8 GPUs.

BUILD_DIR=../build-nvhpc-26.3
module load nvhpc/26.3
export NVHPC_HOME=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3
export CUDA_HOME="$NVHPC_HOME/cuda"
export NCCL_HOME="$NVHPC_HOME/comm_libs/nccl"
export SHARP_HOME="$NVHPC_HOME/comm_libs/13.1/hpcx/hpcx-2.25.1/sharp"
export NCCL_PLUGIN_HOME="$NVHPC_HOME/comm_libs/13.1/hpcx/hpcx-2.25.1/nccl_rdma_sharp_plugin"
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$NCCL_HOME/lib:$NCCL_PLUGIN_HOME/lib:$SHARP_HOME/lib:$LD_LIBRARY_PATH
export LD_PRELOAD=/lib64/libnuma.so.1${LD_PRELOAD:+:$LD_PRELOAD}

# Exclude 4 mgmt NICs (mlx5_7..10) AND mlx5_12 (port not on SHARP tree -> rank 7 fix).
export NCCL_IB_HCA="^mlx5_7,mlx5_8,mlx5_9,mlx5_10,mlx5_12"
export SHARP_COLL_LOCK_ON_COMM_INIT=1

MIN_SIZE=1M; MAX_SIZE=16G; FACTOR=4; GPUS_PER_TASK=8
COMMON="-x LD_PRELOAD=$LD_PRELOAD -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH -x NCCL_IB_HCA=$NCCL_IB_HCA -x SHARP_COLL_LOCK_ON_COMM_INIT=$SHARP_COLL_LOCK_ON_COMM_INIT"

echo "%%%%%%%%% RUN A: SHARP OFF (default algo, Ring) %%%%%%%%%%"
mpirun -np $SLURM_NTASKS --bind-to none $COMMON -x NCCL_COLLNET_ENABLE=0 \
   --mca btl_openib_warn_no_device_params_found 0 \
   $BUILD_DIR/all_reduce_perf -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK

# Run B: SHARP ON, forced CollNet. NCCL_DEBUG=WARN catches a rank-7 SHARP failure without
# spamming the perf table; SHARP_COLL_LOG_LEVEL=2 prints only warnings/errors.
echo "%%%%%%%%% RUN B: SHARP ON (forced CollNet/SHARP) %%%%%%%%%%"
mpirun -np $SLURM_NTASKS --bind-to none $COMMON -x NCCL_COLLNET_ENABLE=1 \
   -x NCCL_ALGO=CollNetChain,CollNetDirect -x NCCL_PROTO=Simple \
   -x NCCL_DEBUG=WARN -x SHARP_COLL_LOG_LEVEL=2 \
   --mca btl_openib_warn_no_device_params_found 0 \
   $BUILD_DIR/all_reduce_perf -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK
