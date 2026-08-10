#!/bin/bash
# Shared environment for the post-PCIe-firmware a0007 NCCL runs (2026-08-10).
# Sourced by a0007-*.sh. Does not touch any pre-existing script.

BUILD_DIR=../build-nvhpc-26.3

module load nvhpc/26.3
export NVHPC_HOME=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3
export CUDA_HOME="$NVHPC_HOME/cuda"
export NCCL_HOME="$NVHPC_HOME/comm_libs/nccl"
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$NCCL_HOME/lib:$LD_LIBRARY_PATH

# Driver 580 exposes multicast/fabric memory; without nvidia-imex running,
# ncclMemAlloc's fabric path fails ("unhandled cuda error" at common.cu:915).
export NCCL_NVLS_ENABLE=0

MIN_SIZE=1M
MAX_SIZE=16G
FACTOR=4

PROGRAMS="sendrecv_perf reduce_perf broadcast_perf gather_perf scatter_perf reduce_scatter_perf all_gather_perf all_reduce_perf alltoall_perf hypercube_perf"

banner() {
   echo "=============================================================="
   echo "JOBID    = $SLURM_JOB_ID"
   echo "JOBNAME  = $SLURM_JOB_NAME"
   echo "NODE     = $SLURMD_NODENAME"
   echo "DATE     = $(date -Is)"
   echo "BUILD    = $BUILD_DIR"
   echo "=============================================================="
}
