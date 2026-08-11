#!/bin/bash
# Why are scatter and alltoall ~1-2 GB/s from 4 GPUs upward, when gather (scatter's
# exact mirror) runs at 42-45 and the pre-update a0008 baseline had scatter at 50.6?
#
# Observed so far (all NCCL_P2P_LEVEL=SYS, converged 16 GB):
#            2 GPU   4 GPU/1sock  4 GPU/2+2  8 GPU
#   gather   48.74   44.66        43.96      41.79   healthy everywhere
#   scatter  48.64    1.85         1.16       0.94   healthy at 2, broken from 4
#   alltoall 37.71    2.38         1.47       1.01   same shape
#
# Each of those is a SINGLE measurement, so step one is repeatability.
#
# Structural note motivating PART D: scatter, gather and alltoall are all built from
# grouped ncclSend/ncclRecv. The failing ones (scatter, alltoall) are patterns where
# ONE rank sends to MANY peers concurrently; the healthy one (gather) is many-to-one,
# and sendrecv is one-to-one. So the suspect is concurrent multi-peer *transmit*,
# which is what the chunk-size and channel knobs govern.
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 240
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-scatdbg
#SBATCH -o out-1node-a0007/%x-%N-%J
#SBATCH --exclusive

cd "$SLURM_SUBMIT_DIR" || exit 1
source ./a0007-env.sh
export NCCL_P2P_LEVEL=SYS
banner

# Small range keeps every case to seconds even at 1 GB/s.
DMIN=64M
DMAX=256M
ITERS=5

probe() {
   local label="$1" devs="$2" ngpu="$3" prog="$4"; shift 4
   echo "%%%%%%%%% SCATDBG=$label prog=$prog devices=$devs ngpus=$ngpu extra_env=$* %%%%%%%%%%"
   ( export CUDA_VISIBLE_DEVICES="$devs"
     for kv in "$@"; do export "$kv"; done
     timeout 400 mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
        $BUILD_DIR/${prog}_perf -b $DMIN -e $DMAX -f 4 -n $ITERS -w 1 -g $ngpu
     echo "exit=$?" )
}

echo "################ PART A: repeatability (3x, 4 GPU socket 0) ################"
for rep in 1 2 3; do
   probe "rep$rep-scatter"  "0,1,2,3" 4 scatter
   probe "rep$rep-alltoall" "0,1,2,3" 4 alltoall
   probe "rep$rep-gather"   "0,1,2,3" 4 gather
done

echo "################ PART B: GPU-count threshold, socket 0 first ################"
probe "n2-scatter" "0,1"     2 scatter
probe "n3-scatter" "0,1,2"   3 scatter
probe "n4-scatter" "0,1,2,3" 4 scatter
probe "n2-alltoall" "0,1"     2 alltoall
probe "n3-alltoall" "0,1,2"   3 alltoall
probe "n4-alltoall" "0,1,2,3" 4 alltoall
# gather control at the same counts - expected healthy throughout
probe "n3-gather" "0,1,2"   3 gather
probe "n4-gather" "0,1,2,3" 4 gather

echo "################ PART C: message-size curve, 4 GPU (is it size-dependent?) ################"
for prog in scatter gather alltoall; do
   echo "%%%%%%%%% SCATDBG=curve-$prog prog=$prog devices=0,1,2,3 ngpus=4 extra_env= %%%%%%%%%%"
   ( export CUDA_VISIBLE_DEVICES=0,1,2,3
     timeout 600 mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
        $BUILD_DIR/${prog}_perf -b 1M -e 1G -f 2 -n 5 -w 1 -g 4
     echo "exit=$?" )
done

echo "################ PART D: knob sweep on scatter, 4 GPU socket 0 ################"
probe "knob-proto-simple"  "0,1,2,3" 4 scatter NCCL_PROTO=Simple
probe "knob-proto-ll"      "0,1,2,3" 4 scatter NCCL_PROTO=LL
probe "knob-proto-ll128"   "0,1,2,3" 4 scatter NCCL_PROTO=LL128
probe "knob-nchan-1"       "0,1,2,3" 4 scatter NCCL_MAX_NCHANNELS=1
probe "knob-nchan-4"       "0,1,2,3" 4 scatter NCCL_MAX_NCHANNELS=4
probe "knob-nchan-8"       "0,1,2,3" 4 scatter NCCL_MAX_NCHANNELS=8
probe "knob-buffsize-8M"   "0,1,2,3" 4 scatter NCCL_BUFFSIZE=8388608
probe "knob-buffsize-32M"  "0,1,2,3" 4 scatter NCCL_BUFFSIZE=33554432
probe "knob-chunk-1M"      "0,1,2,3" 4 scatter NCCL_P2P_NET_CHUNKSIZE=1048576
probe "knob-p2p-disable"   "0,1,2,3" 4 scatter NCCL_P2P_DISABLE=1
probe "knob-p2plevel-phb"  "0,1,2,3" 4 scatter NCCL_P2P_LEVEL=PHB
# same two knobs on alltoall, to see whether it responds identically
probe "knob-alltoall-nchan1"    "0,1,2,3" 4 alltoall NCCL_MAX_NCHANNELS=1
probe "knob-alltoall-buffsize"  "0,1,2,3" 4 alltoall NCCL_BUFFSIZE=33554432

echo "################ PART E: NCCL_DEBUG=INFO, scatter vs gather at 4 GPUs ################"
for prog in scatter gather; do
   echo "%%%%%%%%% SCATDBG=debuginfo-$prog prog=$prog devices=0,1,2,3 ngpus=4 %%%%%%%%%%"
   ( export CUDA_VISIBLE_DEVICES=0,1,2,3
     export NCCL_DEBUG=INFO
     export NCCL_DEBUG_SUBSYS=INIT,GRAPH,TUNING,ENV,P2P
     timeout 400 mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
        $BUILD_DIR/${prog}_perf -b 64M -e 64M -f 2 -n 3 -w 1 -g 4
     echo "exit=$?" )
done

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
