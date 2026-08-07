#!/bin/bash
#SBATCH -p b200-devel
#SBATCH -N 2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --mem=32G
#SBATCH -t 20
#SBATCH -J gdr-sides
#SBATCH -o out-diag/%x-%J

# Localise the bidirectional GDRDMA collapse: is it one endpoint or does it need GPU
# memory on both sides?
#
# perftest takes --use_cuda per side independently, so we can mix host and GPU buffers:
#
#   A  GPU  <-> GPU   bidir   -- the known bad case (~27 GB/s/dir)
#   B  GPU  <-> HOST  bidir   -- only the server touches GPU memory
#   C  HOST <-> GPU   bidir   -- only the client touches GPU memory
#   D  HOST <-> HOST  bidir   -- the known good case (~47 GB/s/dir)
#
# In bidirectional RDMA-write each side both READS its local buffer (to send) and has the
# peer WRITE into it, so a single GPU-side endpoint already mixes reads and writes.
# If B and C collapse like A, the defect is per-endpoint concurrency -- consistent with
# PCIe relaxed ordering being off. If only A collapses, it needs both ends.

mkdir -p out-diag
CUDA_LIB=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3/cuda/lib64
SIZE=8388608
ITERS=2000
NIC=${NIC_FORCE:-mlx5_3}

nodes=($(scontrol show hostnames "$SLURM_JOB_NODELIST"))
SERVER=${nodes[0]}; CLIENT=${nodes[1]}
echo "server=$SERVER client=$CLIENT rail=$NIC size=$SIZE iters=$ITERS"
echo "(perftest prints bidirectional rows as the SUM of both directions)"

run() {
  local label="$1" sflag="$2" cflag="$3"
  echo; echo "########## $label ##########"
  echo "# server flags: '$sflag'   client flags: '$cflag'"
  srun --overlap -N1 -n1 --nodelist="$SERVER" \
    env LD_LIBRARY_PATH=$CUDA_LIB:$LD_LIBRARY_PATH \
    ib_write_bw -d "$NIC" -s $SIZE -n $ITERS -F --report_gbits -b $sflag \
    > out-diag/.s.$$ 2>&1 &
  local pid=$!
  sleep 4
  srun --overlap -N1 -n1 --nodelist="$CLIENT" \
    env LD_LIBRARY_PATH=$CUDA_LIB:$LD_LIBRARY_PATH \
    ib_write_bw -d "$NIC" -s $SIZE -n $ITERS -F --report_gbits -b $cflag "$SERVER" 2>&1 \
    | grep -E "^ *$SIZE |Failed|error"
  wait $pid
  rm -f out-diag/.s.$$
}

run "A. GPU  <-> GPU   (known bad)"   "--use_cuda=0" "--use_cuda=0"
run "B. GPU  <-> HOST  (server GPU only)" "--use_cuda=0" ""
run "C. HOST <-> GPU   (client GPU only)" "" "--use_cuda=0"
run "D. HOST <-> HOST  (known good)"  "" ""
