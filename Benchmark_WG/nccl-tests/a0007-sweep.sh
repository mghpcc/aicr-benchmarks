#!/bin/bash
# GPU-count scaling sweep (2..8) on a0007 after the PCIe firmware update.
# Full benchmark suite at each GPU count, devices taken in order 0..N-1
# (so N<=4 stays on socket 0, N>=5 spans both sockets).
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 600
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-sweep
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
which mpirun

for GPUS_PER_TASK in 2 3 4 5 6 7 8
do
   echo "################ NGPUS=$GPUS_PER_TASK ################"
   for program in $PROGRAMS
   do
      echo "%%%%%%%%% NGPUS=$GPUS_PER_TASK $program %%%%%%%%%%"
      mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
         $BUILD_DIR/$program -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK
   done
done

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
