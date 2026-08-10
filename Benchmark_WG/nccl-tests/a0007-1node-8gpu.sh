#!/bin/bash
# Canonical 1-node NCCL suite on a0007 after the PCIe firmware update.
# All 8 GPUs (both sockets) — directly comparable to the pre-firmware
# out-2socket/ baseline (a0001, 8 GPUs) in results_rtx6000.md.
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 180
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-8gpu
#SBATCH -o out-1node-a0007/%x-%N-%J
#SBATCH --exclusive

cd "$SLURM_SUBMIT_DIR" || exit 1
source ./a0007-env.sh

# WORKAROUND (established by a0007-diag2.sh, job 335364): with default settings
# NCCL abandons the P2P path above 5 GPUs on this node and the fallback collapses
# to 0.04 GB/s. Forcing the P2P level to SYS keeps direct-pointer P2P in use and
# restores 8-GPU sendrecv to 32.7 GB/s. Every GPU pair here is SYS distance.
export NCCL_P2P_LEVEL=SYS
banner

GPUS_PER_TASK=8
export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7

echo "num_mpi_tasks     = $SLURM_NTASKS"
echo "num_gpu_per_task  = $GPUS_PER_TASK"
echo "CUDA_VISIBLE_DEVICES = $CUDA_VISIBLE_DEVICES"
mpirun hostname
which mpirun
which nvcc

for program in $PROGRAMS
do
   echo "%%%%%%%%% $program %%%%%%%%%%"
   mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
      $BUILD_DIR/$program -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK
done

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
