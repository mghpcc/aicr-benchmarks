#!/bin/bash
# Discriminating test for the 4->8 GPU drop seen in results_a0007_postfw.md.
#
# With NCCL_P2P_LEVEL=SYS, ring/tree collectives run 34-43 GB/s on 4 GPUs within
# one socket but fall to ~13.6 GB/s on 8 GPUs spanning both sockets. Two
# explanations remain:
#   H1  GPU count  -- 8 ranks simply scale worse than 4
#   H2  socket crossing -- the ring must cross the inter-socket fabric, and the
#       two crossing links share an aggregate budget (~27 GB/s => ~13.6 each)
#
# CASE 2plus2 (0,1,4,5) has only FOUR GPUs but the same TWO socket crossings as
# the 8-GPU ring. It separates the hypotheses cleanly:
#   ring collectives ~13.6  -> H2, socket crossing is the cause
#   ring collectives ~34-43 -> H2 falsified, it is a count/scaling effect
#
# Also completes the two cases lost when job 335386 was cancelled.
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 150
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-xsock
#SBATCH -o out-1node-a0007/%x-%N-%J
#SBATCH --exclusive

cd "$SLURM_SUBMIT_DIR" || exit 1
source ./a0007-env.sh

# Same workaround as every other benchmark run in results_a0007_postfw.md.
export NCCL_P2P_LEVEL=SYS
banner

mpirun hostname

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

# The discriminating case: 4 GPUs, 2 per socket, 2 socket crossings.
run_case "4gpu-2plus2"      "0,1,4,5" 4
# Completes what job 335386 lost.
run_case "4gpu-socket1"     "4,5,6,7" 4
run_case "2gpu-crosssocket" "0,4"     2

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
