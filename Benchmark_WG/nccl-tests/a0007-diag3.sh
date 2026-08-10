#!/bin/bash
# Third-stage diagnostic for the a0007 multi-GPU collapse.
#
# diag2 located the cliff between 5 and 6 GPUs:
#   5 GPU (0,1,2,3,4) = 10.4 GB/s   -> 4 on socket0 + 1 on socket1
#   6 GPU (0,1,2,3,4,5) = 0.18 GB/s -> 4 on socket0 + 2 on socket1
# Two hypotheses survive, and they are separable by socket composition:
#   H1  total GPU count >= 6 is what breaks (a count/ring-size effect)
#   H2  having >= 2 GPUs on socket 1 is what breaks (a socket-1 path effect)
# Every case below is <= 5 GPUs, so under H1 they should ALL be healthy and
# any collapse falsifies H1 and implicates socket 1.
#
# Socket 0 = GPUs 0,1,2,3 (PCIe domain 0000:)   Socket 1 = GPUs 4,5,6,7 (0001:)
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 60
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=200GB
#SBATCH -J a0007-diag3
#SBATCH -o out-1node-a0007/%x-%N-%J
#SBATCH --exclusive

cd "$SLURM_SUBMIT_DIR" || exit 1
source ./a0007-env.sh
banner

DMIN=4M
DMAX=16M
ITERS=5

quick() {
   local label="$1" devs="$2" ngpu="$3"; shift 3
   echo "%%%%%%%%% DIAG3=$label devices=$devs ngpus=$ngpu extra_env=$* %%%%%%%%%%"
   ( export CUDA_VISIBLE_DEVICES="$devs"
     for kv in "$@"; do export "$kv"; done
     timeout 400 mpirun -np 1 --mca btl_openib_warn_no_device_params_found 0 \
        $BUILD_DIR/sendrecv_perf -b $DMIN -e $DMAX -f 4 -n $ITERS -w 1 -g $ngpu
     echo "exit=$?" )
}

echo "################ PART A: socket-1 only (mirror of the healthy socket-0 cases) ################"
quick "2gpu-socket1-only" "4,5"     2   # mirror of 2gpu-socket0 (39 GB/s)
quick "3gpu-socket1-only" "4,5,6"   3
quick "4gpu-socket1-only" "4,5,6,7" 4   # mirror of 4gpu-socket0 (13 GB/s)

echo "################ PART B: mixed sockets, small counts ################"
quick "2plus2" "0,1,4,5"   4   # 2 socket0 + 2 socket1
quick "1plus2" "0,4,5"     3   # 1 socket0 + 2 socket1
quick "2plus1" "0,1,4"     3   # 2 socket0 + 1 socket1
quick "3plus1" "0,1,2,4"   4   # 3 socket0 + 1 socket1
quick "1plus4" "0,4,5,6,7" 5   # 1 socket0 + 4 socket1

echo "################ PART C: socket-1 internal pairs ################"
quick "pair-4-5" "4,5" 2
quick "pair-4-6" "4,6" 2
quick "pair-4-7" "4,7" 2
quick "pair-5-6" "5,6" 2
quick "pair-5-7" "5,7" 2
quick "pair-6-7" "6,7" 2

echo "################ PART D: socket-0 internal pairs (control) ################"
quick "pair-0-1" "0,1" 2
quick "pair-0-2" "0,2" 2
quick "pair-0-3" "0,3" 2
quick "pair-1-2" "1,2" 2
quick "pair-1-3" "1,3" 2
quick "pair-2-3" "2,3" 2

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
