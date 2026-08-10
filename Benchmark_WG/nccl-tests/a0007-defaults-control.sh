#!/bin/bash
# CONTROL RUN — the missing cell in the comparison.
#
# results_a0007_postfw.md compares a0008 (pre-firmware, NCCL DEFAULTS) against
# a0007 (post-firmware, NCCL_P2P_LEVEL=SYS). Two variables change at once —
# the firmware/node AND the NCCL P2P setting — so no difference between those
# two columns can be attributed to the firmware. The comparison is confounded.
#
# This job supplies the missing cell: a0007, NCCL DEFAULTS, all collectives.
#
#             | NCCL defaults              | NCCL_P2P_LEVEL=SYS
#   a0008 pre | have (results_rtx6000.md)  | impossible (node since updated)
#   a0007 post| THIS JOB                   | have (job 335386)
#
# With it the effects separate:
#   a0007 defaults  vs  a0007 SYS       -> effect of the NCCL setting alone
#   a0007 defaults  vs  a0008 defaults  -> effect of firmware + node alone
#
# Only 2 and 4 GPU on socket 0 are used: those configurations do NOT trigger the
# socket-1 collapse, so they run at usable speed even at defaults.
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 150
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-defaults
#SBATCH -o out-1node-a0007/%x-%N-%J
#SBATCH --exclusive

cd "$SLURM_SUBMIT_DIR" || exit 1
source ./a0007-env.sh

# DELIBERATELY NOT SETTING NCCL_P2P_LEVEL. This run must use NCCL defaults so it
# is directly comparable to the a0008 pre-firmware baseline.
unset NCCL_P2P_LEVEL
banner
echo "NCCL_P2P_LEVEL is intentionally UNSET for this control run"

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

run_case "4gpu-socket0-DEFAULTS" "0,1,2,3" 4
run_case "2gpu-socket0-DEFAULTS" "0,1"     2

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
