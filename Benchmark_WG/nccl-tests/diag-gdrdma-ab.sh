#!/bin/bash
#SBATCH -p b200-devel
#SBATCH -N 2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --mem=32G
#SBATCH -t 25
#SBATCH -J gdr-ab
#SBATCH -o out-diag/%x-%J

# Decisive test for the AICR inter-node question:
#   is the ~26.7 GB/s/dir bidirectional GDRDMA rate a property of the GPU (silicon),
#   or of this cluster's GPU<->NIC path (configuration)?
#
# Four measurements on the SAME NIC, same nodes, same message size:
#   host  unidir / host  bidir   -- what the NIC + fabric can do with no GPU involved
#   GPU   unidir / GPU   bidir   -- what the GDRDMA path can do
#
# If host bidir holds ~line rate while GPU bidir halves, the defect is in the P2P path.
# If BOTH host and GPU bidir behave the same way, the fabric/NIC is the limit, not the GPU.
#
# Unlike the earlier test-gdrdma.sh, this picks the NIC with PIX affinity to the
# allocated GPU instead of hardcoding mlx5_0 (which on b0029 is NODE, not PIX, from the
# GPU at 72:00 -- i.e. that test measured a cross-host-bridge path).

mkdir -p out-diag
CUDA_LIB=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3/cuda/lib64
SIZE=8388608          # 8 MiB -- large enough to be asymptotic
ITERS=2000

nodes=($(scontrol show hostnames "$SLURM_JOB_NODELIST"))
SERVER=${nodes[0]}
CLIENT=${nodes[1]}
echo "server=$SERVER  client=$CLIENT  size=${SIZE}B iters=$ITERS"

# Resolve, on a given node, the NIC that is PIX (single PCIe bridge) from CUDA device 0,
# restricted to 400 Gb/s rails. Falls back to the first 400 Gb/s rail.
pick_nic() {
  srun --overlap -N1 -n1 --nodelist="$1" bash -c '
    topo=$(nvidia-smi topo -m 2>/dev/null)
    # map NIC<n> -> mlx5_<x>
    declare -A m
    while read -r k v; do m[$k]=$v; done < <(echo "$topo" | sed -n "s/^ *\(NIC[0-9]*\): \(mlx5_[0-9]*\)$/\1 \2/p")
    row=$(echo "$topo" | awk "/^GPU0/{print; exit}")
    hdr=$(echo "$topo" | awk "/GPU0/{print; exit}" | head -1)
    best=""
    idx=0
    for f in $(echo "$row" | cut -f2-); do
      if [ "$f" = "PIX" ]; then
        nic="NIC$((idx-1))"
        cand=${m[$nic]}
        if [ -n "$cand" ]; then
          rate=$(ibstat "$cand" 2>/dev/null | sed -n "s/.*Rate: *\([0-9]*\).*/\1/p" | head -1)
          [ "$rate" = "400" ] && best=$cand
        fi
      fi
      idx=$((idx+1))
    done
    if [ -z "$best" ]; then
      for c in $(ibstat -l 2>/dev/null); do
        r=$(ibstat "$c" 2>/dev/null | sed -n "s/.*Rate: *\([0-9]*\).*/\1/p" | head -1)
        [ "$r" = "400" ] && { best=$c; break; }
      done
    fi
    bus=$(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader 2>/dev/null | head -1)
    echo "$best $bus"
  ' 2>/dev/null | tail -1
}

read -r SNIC SBUS <<< "$(pick_nic "$SERVER")"
read -r CNIC CBUS <<< "$(pick_nic "$CLIENT")"
echo "PIX-affinity resolution: $SERVER gpu=$SBUS -> $SNIC ; $CLIENT gpu=$CBUS -> $CNIC"

# Server and client must sit on the SAME rail: different rails are on different IB
# subnets here and the connection fails with status 12 (transport retry exceeded).
# NIC_FORCE lets us pin one rail on both sides; default to the server's PIX rail.
NIC=${NIC_FORCE:-$SNIC}
SNIC=$NIC; CNIC=$NIC
echo "using rail: $NIC on both nodes"
[ -z "$NIC" ] && { echo "FATAL: could not resolve a 400 Gb/s rail"; exit 1; }
echo "(note: GPU<->NIC affinity is PIX on $SERVER; on $CLIENT the allocated GPU is"
echo " whatever SLURM gave us, so the client side may not be PIX -- reported above.)"

run_pair() {
  local label="$1"; shift
  local extra="$*"
  echo
  echo "########## $label ##########"
  echo "# args: $extra"
  srun --overlap -N1 -n1 --nodelist="$SERVER" \
    env LD_LIBRARY_PATH=$CUDA_LIB:$LD_LIBRARY_PATH \
    ib_write_bw -d "$SNIC" -s $SIZE -n $ITERS -F --report_gbits $extra \
    > out-diag/.srv.$$ 2>&1 &
  local spid=$!
  sleep 4
  srun --overlap -N1 -n1 --nodelist="$CLIENT" \
    env LD_LIBRARY_PATH=$CUDA_LIB:$LD_LIBRARY_PATH \
    ib_write_bw -d "$CNIC" -s $SIZE -n $ITERS -F --report_gbits $extra "$SERVER" 2>&1 \
    | grep -vE "^(Perftest|initializing|Listing|CUDA device|creating|making|allocated|destroying|\[pid)"
  wait $spid
  rm -f out-diag/.srv.$$
}

run_pair "1. HOST memory, UNIDIRECTIONAL"
run_pair "2. HOST memory, BIDIRECTIONAL"  -b
run_pair "3. GPU memory (GDRDMA), UNIDIRECTIONAL"  --use_cuda=0
run_pair "4. GPU memory (GDRDMA), BIDIRECTIONAL"   --use_cuda=0 -b

echo
echo "########## NOTE ##########"
echo "perftest reports BIDIRECTIONAL rows as the SUM of both directions;"
echo "divide by 2 to compare against the unidirectional rows."
