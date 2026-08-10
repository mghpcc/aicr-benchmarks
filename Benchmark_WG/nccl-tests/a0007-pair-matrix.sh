#!/bin/bash
# Pairwise GPU-to-GPU sendrecv matrix on a0007 after the PCIe firmware update.
# All 28 unique GPU pairs, 2 GPUs per run. sendrecv is bidirectional, so each
# row reports the per-direction DMA budget on that exact PCIe path — this is the
# measurement most likely to move if the firmware changed PCIe behaviour.
# GPUs 0-3 = socket 0, GPUs 4-7 = socket 1.
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 300
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-pairs
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

mpirun hostname

for i in 0 1 2 3 4 5 6 7
do
   for j in 0 1 2 3 4 5 6 7
   do
      [ "$j" -le "$i" ] && continue
      export CUDA_VISIBLE_DEVICES="$i,$j"
      echo "%%%%%%%%% PAIR=$i-$j sendrecv_perf %%%%%%%%%%"
      mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
         $BUILD_DIR/sendrecv_perf -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g 2
   done
done

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
