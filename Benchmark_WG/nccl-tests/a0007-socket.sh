#!/bin/bash
# Socket-scoped NCCL suites on a0007 after the PCIe firmware update.
# Reproduces the pre-firmware RTX6000 baseline configurations so the tables in
# results_rtx6000.md have a like-for-like post-firmware counterpart:
#   * 2 GPUs, socket 0        -> baseline out-1socket/nvhpc-26.3-a0001-9677
#   * 4 GPUs, socket 0        -> baseline out-1socket/nvhpc-26.3-a0008-9679
#   * 4 GPUs, socket 1        -> new, checks socket symmetry
#   * 2 GPUs, cross-socket    -> new, isolates the cross-NUMA penalty
# GPUs 0-3 are socket 0 (PCIe domain 0000:), GPUs 4-7 socket 1 (domain 0001:).
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 300
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-socket
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

run_case() {
   local label="$1" devs="$2" ngpu="$3"
   echo "################ CASE=$label DEVICES=$devs NGPUS=$ngpu ################"
   export CUDA_VISIBLE_DEVICES="$devs"
   for program in $PROGRAMS
   do
      echo "%%%%%%%%% CASE=$label $program %%%%%%%%%%"
      mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
         $BUILD_DIR/$program -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $ngpu
   done
}

run_case "2gpu-socket0"     "0,1"     2
run_case "4gpu-socket0"     "0,1,2,3" 4
run_case "4gpu-socket1"     "4,5,6,7" 4
run_case "2gpu-crosssocket" "0,4"     2

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
