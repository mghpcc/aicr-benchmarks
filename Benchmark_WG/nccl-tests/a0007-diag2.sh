#!/bin/bash
# Follow-up to a0007-diag.sh (job 335360), which showed the 0.04 GB/s collapse
# is confined to the 8-GPU case: 2 GPU = 39 GB/s, 4 GPU = 13 GB/s, 8 GPU = 0.04.
#
# PART A  find the GPU-count threshold (5,6,7,8).
# PART B  leave-one-out: run 7 GPUs eight times, each time excluding a different
#         GPU. If excluding one particular GPU restores throughput, that GPU or
#         its PCIe path is the culprit rather than the 8-GPU config as such.
# PART C  NCCL_DEBUG=INFO at 8 GPUs -- ring/transport construction, the piece
#         diag1 only captured for 2 GPUs.
# PART D  knob sweep at 8 GPUs to see what, if anything, recovers it.
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 90
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-diag2
#SBATCH -o out-1node-a0007/%x-%N-%J
#SBATCH --exclusive

cd "$SLURM_SUBMIT_DIR" || exit 1
source ./a0007-env.sh
banner

# Deliberately tiny: at 0.04 GB/s a 64M message costs ~2 s/iter, so keep the
# range short enough that even a fully collapsed case returns in seconds.
DMIN=4M
DMAX=16M
ITERS=5

quick() {
   local label="$1" devs="$2" ngpu="$3"; shift 3
   echo "%%%%%%%%% DIAG2=$label devices=$devs ngpus=$ngpu extra_env=$* %%%%%%%%%%"
   ( export CUDA_VISIBLE_DEVICES="$devs"
     for kv in "$@"; do export "$kv"; done
     timeout 400 mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
        $BUILD_DIR/sendrecv_perf -b $DMIN -e $DMAX -f 4 -n $ITERS -w 1 -g $ngpu
     echo "exit=$?" )
}

echo "################ PART A: GPU-count threshold ################"
quick "5gpu" "0,1,2,3,4"         5
quick "6gpu" "0,1,2,3,4,5"       6
quick "7gpu" "0,1,2,3,4,5,6"     7
quick "8gpu" "0,1,2,3,4,5,6,7"   8

echo "################ PART B: leave-one-out (7 GPUs, drop GPU i) ################"
for drop in 0 1 2 3 4 5 6 7; do
   devs=$(seq -s, 0 7 | tr ',' '\n' | grep -v "^$drop$" | paste -sd,)
   quick "7gpu-drop$drop" "$devs" 7
done

echo "################ PART C: NCCL_DEBUG=INFO at 8 GPUs ################"
( export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
  export NCCL_DEBUG=INFO
  export NCCL_DEBUG_SUBSYS=INIT,GRAPH,TUNING,ENV
  timeout 400 mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
     $BUILD_DIR/sendrecv_perf -b 4M -e 4M -f 2 -n 3 -w 1 -g 8
  echo "exit=$?" )

echo "################ PART D: knob sweep at 8 GPUs ################"
quick "8gpu-p2p-disable"  "0,1,2,3,4,5,6,7" 8 NCCL_P2P_DISABLE=1
quick "8gpu-shm-disable"  "0,1,2,3,4,5,6,7" 8 NCCL_SHM_DISABLE=1
quick "8gpu-p2plevel-sys" "0,1,2,3,4,5,6,7" 8 NCCL_P2P_LEVEL=SYS
quick "8gpu-p2plevel-0"   "0,1,2,3,4,5,6,7" 8 NCCL_P2P_LEVEL=0
quick "8gpu-algo-ring"    "0,1,2,3,4,5,6,7" 8 NCCL_ALGO=Ring
quick "8gpu-nchannels-1"  "0,1,2,3,4,5,6,7" 8 NCCL_MAX_NCHANNELS=1
quick "8gpu-proto-simple" "0,1,2,3,4,5,6,7" 8 NCCL_PROTO=Simple

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
