#!/bin/bash
# FAST diagnostic for the 0.04 GB/s collapse seen on a0007 (job 335184) after
# the PCIe firmware update. Small message range so every case finishes in
# seconds instead of hours.
#
# Question 1: is the collapse universal, or only at 8 GPUs / cross-socket?
#   -> cases at 2 GPU same-socket, 2 GPU cross-socket, 4 GPU, 8 GPU.
# Question 2: is the P2P (peer BAR) path the broken one?
#   -> repeat with NCCL_P2P_DISABLE=1, which forces host staging. If host
#      staging is dramatically FASTER than P2P, the peer-BAR mapping is the
#      fault (e.g. lost write-combining / BAR relocated with wrong memory type),
#      which is exactly the class of thing a PCIe firmware update can change.
# Question 3: what transport does NCCL actually pick, and does the PCIe link
#      train to Gen5 under load?
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 45
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-diag
#SBATCH -o out-1node-a0007/%x-%N-%J
#SBATCH --exclusive

cd "$SLURM_SUBMIT_DIR" || exit 1
source ./a0007-env.sh
banner

# Small + short: 1M..64M, 5 iters. Enough to read a rate, cheap enough to loop.
DMIN=1M
DMAX=64M
ITERS=5

quick() {
   local label="$1" devs="$2" ngpu="$3"; shift 3
   echo "%%%%%%%%% DIAG=$label devices=$devs ngpus=$ngpu extra_env=$* %%%%%%%%%%"
   ( export CUDA_VISIBLE_DEVICES="$devs"
     for kv in "$@"; do export "$kv"; done
     timeout 300 mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
        $BUILD_DIR/sendrecv_perf -b $DMIN -e $DMAX -f 4 -n $ITERS -w 1 -g $ngpu
     echo "exit=$?" )
}

echo "################ PART 1: P2P (default) vs host staging ################"
quick "2gpu-socket0-p2p"      "0,1"             2
quick "2gpu-socket0-nop2p"    "0,1"             2 NCCL_P2P_DISABLE=1
quick "2gpu-crosssock-p2p"    "0,4"             2
quick "2gpu-crosssock-nop2p"  "0,4"             2 NCCL_P2P_DISABLE=1
quick "4gpu-socket0-p2p"      "0,1,2,3"         4
quick "4gpu-socket0-nop2p"    "0,1,2,3"         4 NCCL_P2P_DISABLE=1
quick "8gpu-p2p"              "0,1,2,3,4,5,6,7" 8
quick "8gpu-nop2p"            "0,1,2,3,4,5,6,7" 8 NCCL_P2P_DISABLE=1

echo "################ PART 2: PCIe link speed UNDER LOAD ################"
export CUDA_VISIBLE_DEVICES=0,1
( for i in 1 2 3 4 5 6 7 8 9 10; do
     nvidia-smi --query-gpu=index,pcie.link.gen.current,pcie.link.width.current,utilization.gpu \
                --format=csv,noheader | tr '\n' '|'; echo " t=$i"
     sleep 2
  done ) &
SAMPLER=$!
timeout 120 mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
   $BUILD_DIR/sendrecv_perf -b 64M -e 512M -f 2 -n 20 -w 2 -g 2
wait $SAMPLER 2>/dev/null

echo "################ PART 3: NCCL transport selection (DEBUG=INFO) ################"
export CUDA_VISIBLE_DEVICES=0,1
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,GRAPH,TUNING,ENV
timeout 180 mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
   $BUILD_DIR/sendrecv_perf -b 8M -e 8M -f 2 -n 3 -w 1 -g 2
unset NCCL_DEBUG NCCL_DEBUG_SUBSYS

echo "################ PART 4: baseline CUDA H2D/D2H + P2P check ################"
if command -v nvidia-smi >/dev/null; then
   nvidia-smi topo -p2p rw 2>/dev/null || echo "(nvidia-smi topo -p2p unsupported)"
fi

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
