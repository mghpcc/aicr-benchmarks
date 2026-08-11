#!/bin/bash
# Complete the 1..8 GPU-count series on a0007 with NCCL_P2P_LEVEL=SYS.
#
# Already measured with the workaround, so NOT repeated here:
#   2 GPU  -> job 335386 (case 2gpu-socket0)
#   4 GPU  -> job 335386 (case 4gpu-socket0)
#   8 GPU  -> job 335385
# This job runs only the missing counts: 1, 3, 5, 6, 7.
#
# Devices are taken in order 0..N-1, matching how the 2/4/8 runs were done, so
# the series is internally consistent: N<=4 stays on socket 0, N>=5 spans both.
#
# NOTE: submitted WITHOUT --reservation. Reservation shaohao_a0007 ended
# 2026-08-11T11:00 and this sweep needs several hours, so it queues on
# rtx-batch for a0007 normally.
#SBATCH -p rtx-batch
#SBATCH -w a0007
#SBATCH -t 480
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-counts
#SBATCH -o out-1node-a0007/%x-%N-%J
#SBATCH --exclusive

cd "$SLURM_SUBMIT_DIR" || exit 1
source ./a0007-env.sh

# Mandatory on this node: without it any group with >=3 GPUs and >=2 on socket 1
# collapses to 0.04 GB/s. See the headline section of results_a0007_postfw.md.
export NCCL_P2P_LEVEL=SYS
banner
echo "NCCL_P2P_LEVEL = $NCCL_P2P_LEVEL"

mpirun hostname
which mpirun

for GPUS_PER_TASK in 1 3 5 6 7
do
   devs=$(seq -s, 0 $((GPUS_PER_TASK-1)))
   echo "################ CASE=${GPUS_PER_TASK}gpu DEVICES=$devs NGPUS=$GPUS_PER_TASK ################"
   export CUDA_VISIBLE_DEVICES="$devs"
   for program in $PROGRAMS
   do
      echo "%%%%%%%%% CASE=${GPUS_PER_TASK}gpu $program %%%%%%%%%%"
      mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
         $BUILD_DIR/$program -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK
   done
done

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
