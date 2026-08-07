#!/bin/bash
#SBATCH -N 2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --mem=32G
#SBATCH -t 20
#SBATCH -J gdr-ro
#SBATCH -o out-diag/%x-%J

# Does MR-level PCIe relaxed ordering change anything on this fabric?
#
# perftest >= 6.x registers MRs with IBV_ACCESS_RELAXED_ORDERING by DEFAULT and offers
# --disable_pcie_relaxed to turn it off. So the earlier A/B (job 300708) already ran
# with RO requested -- and GPU bidir still collapsed to 27.2 GB/s/dir.
#
# Matrix: {host,gpu} x {RO default-on, RO disabled}, all bidirectional, same rail.
#   - If GPU bidir is identical with and without RO -> RO never reaches the wire for
#     this path (NIC DevCtl.RlxdOrd cleared, firmware force_strict, or stripped at the
#     switch/GPU) -- the defect is *upstream* of the MR flag.
#   - If disabling RO makes HOST bidir collapse too -> RO is effective for host traffic
#     and specifically ineffective for GPU traffic.

mkdir -p out-diag
CUDA_LIB=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3/cuda/lib64
SIZE=8388608
ITERS=2000
NIC=${NIC_FORCE:-mlx5_3}

nodes=($(scontrol show hostnames "$SLURM_JOB_NODELIST"))
SERVER=${nodes[0]}; CLIENT=${nodes[1]}
echo "server=$SERVER client=$CLIENT rail=$NIC size=$SIZE iters=$ITERS"
echo "perftest: $(ib_write_bw --version 2>&1 | head -1)"
echo "(bidirectional rows are the SUM of both directions; divide by 2)"

run() {
  local label="$1"; shift
  echo; echo "########## $label ##########"
  srun --overlap -N1 -n1 --nodelist="$SERVER" \
    env LD_LIBRARY_PATH=$CUDA_LIB:$LD_LIBRARY_PATH \
    ib_write_bw -d "$NIC" -s $SIZE -n $ITERS -F --report_gbits -b "$@" \
    > out-diag/.s.$$ 2>&1 &
  local pid=$!
  sleep 4
  srun --overlap -N1 -n1 --nodelist="$CLIENT" \
    env LD_LIBRARY_PATH=$CUDA_LIB:$LD_LIBRARY_PATH \
    ib_write_bw -d "$NIC" -s $SIZE -n $ITERS -F --report_gbits -b "$@" "$SERVER" 2>&1 \
    | grep -E "^ *$SIZE |Failed|error|relax"
  wait $pid
  rm -f out-diag/.s.$$
}

run "1. HOST bidir, RO on (default)"
run "2. HOST bidir, RO DISABLED"      --disable_pcie_relaxed
run "3. GPU  bidir, RO on (default)"  --use_cuda=0
run "4. GPU  bidir, RO DISABLED"      --use_cuda=0 --disable_pcie_relaxed
run "5. GPU  unidir check, RO DISABLED (drop -b manually below)"
# unidirectional GPU with RO disabled, for completeness:
echo; echo "########## 6. GPU unidir, RO DISABLED ##########"
srun --overlap -N1 -n1 --nodelist="$SERVER" \
  env LD_LIBRARY_PATH=$CUDA_LIB:$LD_LIBRARY_PATH \
  ib_write_bw -d "$NIC" -s $SIZE -n $ITERS -F --report_gbits --use_cuda=0 --disable_pcie_relaxed \
  > out-diag/.s.$$ 2>&1 &
pid=$!
sleep 4
srun --overlap -N1 -n1 --nodelist="$CLIENT" \
  env LD_LIBRARY_PATH=$CUDA_LIB:$LD_LIBRARY_PATH \
  ib_write_bw -d "$NIC" -s $SIZE -n $ITERS -F --report_gbits --use_cuda=0 --disable_pcie_relaxed "$SERVER" 2>&1 \
  | grep -E "^ *$SIZE |Failed|error"
wait $pid; rm -f out-diag/.s.$$
