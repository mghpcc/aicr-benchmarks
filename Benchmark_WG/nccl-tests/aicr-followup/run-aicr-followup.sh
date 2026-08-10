#!/bin/bash
#SBATCH -N 2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=8
#SBATCH --mem=200G
#SBATCH -t 45
#SBATCH -J aicr-fu
#SBATCH -o aicr-followup-%J.out

# AICR follow-up after the Engaging counter-test.
# Engaging (healthy) reaches 48.7 GB/s/dir GPU bidirectional; AICR sits at 27.2.
# Relaxed ordering is eliminated on both clusters. The remaining structural difference is
# AICR's Broadcom PEX890xx Gen5 switch vs Engaging's Mellanox MT2910 bridge chain.
#
# Tests, per aicr-2node-ib-test.md:
#   0  rail affinity + full topology (was AICR's rail actually the PIX partner?)
#   1  direction isolation  -- which direction fails: NIC-reads-GPU or NIC-writes-GPU?
#   2  switch path contrast -- PIX (switch-local P2P) vs NODE (via root complex)
#   3  concurrency scaling  -- 1/2/4/8 pairs: per-port limit or shared switch resource?
#   4  unprivileged PCIe/firmware reads (root-only bits will be reported as unreadable)
#
# All read-only. Nothing is reconfigured.

set -u
cd "${SLURM_SUBMIT_DIR:-$(dirname "$0")}" || exit 1

SIZE=${SIZE:-8388608}
ITERS=${ITERS:-2000}
CUDA_LIB=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3/cuda/lib64
export LD_LIBRARY_PATH=$CUDA_LIB:${LD_LIBRARY_PATH:-}

nodes=($(scontrol show hostnames "$SLURM_JOB_NODELIST"))
SERVER=${nodes[0]}; CLIENT=${nodes[1]}

echo "################ AICR FOLLOW-UP ################"
echo "date   : $(date)"
echo "job    : ${SLURM_JOB_ID:-none}"
echo "nodes  : $SERVER (server) + $CLIENT (client)"
echo "size   : $SIZE   iters: $ITERS"
echo "perftest: $(ib_write_bw --version 2>&1 | head -1)"
echo
echo "Engaging reference (healthy): GPU bidir 48.7 GB/s/dir, GPU unidir 49.4, host bidir 47.6"
echo "AICR prior:                   GPU bidir 27.2 GB/s/dir, GPU unidir 47.5, host bidir 47.3"
echo

# =======================================================================
echo "=================== PART 0: topology + rail affinity ==================="
srun --overlap -N1 -n1 --nodelist="$SERVER" bash -c '
echo "--- host $(hostname)"
echo "--- 0a. nvidia-smi topo -m (GPU <-> NIC distances) ---"
nvidia-smi topo -m 2>/dev/null
echo
echo "--- 0b. PCIe bridge chain for every GPU ---"
for bdf in $(lspci -D -n | awk "\$2 ~ /^030[02]/ {print \$1}"); do
  echo "GPU-class device  $bdf  $(lspci -s ${bdf#0000:} 2>/dev/null | cut -d" " -f2- | cut -c1-40)"
  cur="/sys/bus/pci/devices/$bdf"
  for i in 1 2 3 4; do
    par=$(readlink -f "$cur/.." 2>/dev/null); bn=$(basename "$par")
    [[ "$bn" =~ ^[0-9a-f]{4}: ]] || break
    echo "    L$i $bn  $(lspci -s ${bn#0000:} 2>/dev/null | cut -d" " -f2- | cut -c1-62)"
    cur="$par"
  done
done
echo
echo "--- 0c. PCIe bridge chain for every 400Gb/s Mellanox NIC ---"
for b in $(lspci -D | grep -i "mellanox" | awk "{print \$1}"); do
  w=$(cat /sys/bus/pci/devices/$b/current_link_width 2>/dev/null)
  [ "$w" = "16" ] || continue
  echo "NIC $b (x$w)"
  cur="/sys/bus/pci/devices/$b"
  for i in 1 2 3 4; do
    par=$(readlink -f "$cur/.." 2>/dev/null); bn=$(basename "$par")
    [[ "$bn" =~ ^[0-9a-f]{4}: ]] || break
    echo "    L$i $bn  $(lspci -s ${bn#0000:} 2>/dev/null | cut -d" " -f2- | cut -c1-62)"
    cur="$par"
  done
done
echo
echo "--- 0d. rail rates ---"
ibstat 2>/dev/null | grep -E "^CA |Rate:" | paste - - | sed "s/^/  /"
echo
echo "--- 0e. lspci tree (abridged) ---"
lspci -t 2>/dev/null | head -60
'

# ---- resolve rails: one PIX partner of GPU0, one NODE-distance 400G rail ----
read -r PIXRAIL NODERAIL <<< "$(srun --overlap -N1 -n1 --nodelist="$SERVER" bash -c '
topo=$(nvidia-smi topo -m 2>/dev/null)
declare -A m
while read -r k v; do m[$k]=$v; done < <(echo "$topo" | sed -n "s/^ *\(NIC[0-9]*\): \(mlx5_[0-9]*\)$/\1 \2/p")
row=$(echo "$topo" | awk "/^GPU0/{print; exit}")
pix=""; node=""
idx=0
for f in $(echo "$row" | cut -f2-); do
  cand=${m[NIC$((idx-1))]:-}
  if [ -n "$cand" ]; then
    r=$(ibstat "$cand" 2>/dev/null | sed -n "s/.*Rate: *\([0-9]*\).*/\1/p" | head -1)
    if [ "$r" = "400" ]; then
      case "$f" in
        PIX|PXB) [ -z "$pix" ] && pix=$cand ;;
        NODE|SYS) [ -z "$node" ] && node=$cand ;;
      esac
    fi
  fi
  idx=$((idx+1))
done
echo "$pix $node"' 2>/dev/null | tail -1)"

PIXRAIL=${PIXRAIL:-mlx5_3}
echo
echo "resolved: PIX/PXB rail = $PIXRAIL   NODE-distance 400G rail = ${NODERAIL:-none}"
echo

declare -A R    # label -> Gb/s

# generic 2-sided runner: run <label> <server-extra-args> | <client-extra-args>
pair_run() {
  local label="$1" sargs="$2" cargs="$3" port="${4:-18515}"
  echo "########## $label ##########"
  echo "#   server: $sargs"
  echo "#   client: $cargs"
  srun --overlap -N1 -n1 --nodelist="$SERVER" \
    ib_write_bw -s $SIZE -n $ITERS -F --report_gbits -p $port $sargs \
    > /tmp/.s.$$ 2>&1 &
  local pid=$!
  sleep 4
  local out
  out=$(srun --overlap -N1 -n1 --nodelist="$CLIENT" \
    ib_write_bw -s $SIZE -n $ITERS -F --report_gbits -p $port $cargs "$SERVER" 2>&1)
  wait $pid
  echo "$out" | grep -E "^ *$SIZE |Failed|error|status"
  local bw
  bw=$(echo "$out" | awk -v s="$SIZE" '$1==s {print $4; exit}')
  if [ -n "$bw" ]; then R[$label]=$bw; else
    R[$label]="FAILED"
    echo "  !! server said:"; grep -viE "^ *$" /tmp/.s.$$ | tail -8 | sed 's/^/     /'
  fi
  rm -f /tmp/.s.$$
}

# =======================================================================
echo "=================== PART 1: direction isolation ==================="
echo "RDMA_WRITE: the CLIENT reads its local buffer and writes into the SERVER's buffer."
echo "  GPU on client only  -> NIC READS FROM GPU"
echo "  GPU on server only  -> NIC WRITES INTO GPU"
echo "Engaging-while-broken reference: reads 18.5, writes 35.8, host 47.4 GB/s"
echo
pair_run "P1_read_from_gpu"  "-d $PIXRAIL"                 "-d $PIXRAIL --use_cuda=0"
pair_run "P1_write_into_gpu" "-d $PIXRAIL --use_cuda=0"    "-d $PIXRAIL"
pair_run "P1_host_baseline"  "-d $PIXRAIL"                 "-d $PIXRAIL"
pair_run "P1_gpu_both_uni"   "-d $PIXRAIL --use_cuda=0"    "-d $PIXRAIL --use_cuda=0"
pair_run "P1_gpu_both_bidir" "-d $PIXRAIL --use_cuda=0 -b" "-d $PIXRAIL --use_cuda=0 -b"

# =======================================================================
echo
echo "=================== PART 2: switch path contrast ==================="
echo "PIX/PXB = GPU and NIC under the same PCIe switch (switch-local peer-to-peer)."
echo "NODE    = GPU reaches the NIC via the root complex (does NOT do switch-local P2P)."
echo "If the switch's P2P handling is the fault, NODE should behave differently."
echo
if [ -n "${NODERAIL:-}" ]; then
  pair_run "P2_node_gpu_uni"   "-d $NODERAIL --use_cuda=0"    "-d $NODERAIL --use_cuda=0"
  pair_run "P2_node_gpu_bidir" "-d $NODERAIL --use_cuda=0 -b" "-d $NODERAIL --use_cuda=0 -b"
  pair_run "P2_node_host_bidir" "-d $NODERAIL -b"             "-d $NODERAIL -b"
else
  echo "no NODE-distance 400 Gb/s rail found -- skipped"
fi

# =======================================================================
echo
echo "=================== PART 3: concurrency scaling ==================="
echo "N GPU/NIC pairs bidirectional at once. Per-pair rate constant => per-port limit."
echo "Per-pair rate falling as N grows => shared switch resource saturating."
echo
# map GPU index -> its PIX/PXB 400G rail, on the server
mapfile -t PAIRS < <(srun --overlap -N1 -n1 --nodelist="$SERVER" bash -c '
topo=$(nvidia-smi topo -m 2>/dev/null)
declare -A m
while read -r k v; do m[$k]=$v; done < <(echo "$topo" | sed -n "s/^ *\(NIC[0-9]*\): \(mlx5_[0-9]*\)$/\1 \2/p")
echo "$topo" | grep -E "^GPU[0-9]+" | while IFS= read -r row; do
  g=$(echo "$row" | awk "{print \$1}")
  idx=0; sel=""
  for f in $(echo "$row" | cut -f2-); do
    cand=${m[NIC$((idx-1))]:-}
    if [ -n "$cand" ] && { [ "$f" = "PIX" ] || [ "$f" = "PXB" ]; }; then
      r=$(ibstat "$cand" 2>/dev/null | sed -n "s/.*Rate: *\([0-9]*\).*/\1/p" | head -1)
      [ "$r" = "400" ] && sel=$cand
    fi
    idx=$((idx+1))
  done
  [ -n "$sel" ] && echo "${g#GPU} $sel"
done' 2>/dev/null)

echo "GPU -> PIX rail map (${#PAIRS[@]} pairs found):"
printf '   %s\n' "${PAIRS[@]}"
echo

scale_run() {
  local n="$1"
  echo "########## P3: $n pair(s) bidirectional, GPU memory ##########"
  local i port g rail
  local -a outs=()
  for ((i=0;i<n;i++)); do
    [ $i -ge ${#PAIRS[@]} ] && break
    g=$(echo "${PAIRS[$i]}" | awk '{print $1}')
    rail=$(echo "${PAIRS[$i]}" | awk '{print $2}')
    port=$((19000+i))
    srun --overlap -N1 -n1 --nodelist="$SERVER" \
      ib_write_bw -d "$rail" -s $SIZE -n $ITERS -F --report_gbits -b -p $port --use_cuda=$g \
      > /tmp/.ss.$$.$i 2>&1 &
  done
  sleep 5
  for ((i=0;i<n;i++)); do
    [ $i -ge ${#PAIRS[@]} ] && break
    g=$(echo "${PAIRS[$i]}" | awk '{print $1}')
    rail=$(echo "${PAIRS[$i]}" | awk '{print $2}')
    port=$((19000+i))
    srun --overlap -N1 -n1 --nodelist="$CLIENT" \
      ib_write_bw -d "$rail" -s $SIZE -n $ITERS -F --report_gbits -b -p $port --use_cuda=$g "$SERVER" \
      > /tmp/.cc.$$.$i 2>&1 &
  done
  wait
  local total=0 cnt=0 bw
  for ((i=0;i<n;i++)); do
    [ $i -ge ${#PAIRS[@]} ] && break
    bw=$(awk -v s="$SIZE" '$1==s {print $4; exit}' /tmp/.cc.$$.$i 2>/dev/null)
    rail=$(echo "${PAIRS[$i]}" | awk '{print $2}')
    if [ -n "$bw" ]; then
      printf "   pair %d (%s): %s Gb/s  = %.1f GB/s per direction\n" \
        "$i" "$rail" "$bw" "$(awk -v b=$bw 'BEGIN{print b/16}')"
      total=$(awk -v t=$total -v b=$bw 'BEGIN{print t+b}'); cnt=$((cnt+1))
    else
      printf "   pair %d (%s): FAILED\n" "$i" "$rail"
      grep -viE "^ *$" /tmp/.cc.$$.$i 2>/dev/null | tail -3 | sed 's/^/        /'
    fi
  done
  if [ "$cnt" -gt 0 ]; then
    R[P3_n${n}_perpair]=$(awk -v t=$total -v c=$cnt 'BEGIN{printf "%.2f", t/c}')
    R[P3_n${n}_total]=$total
    printf "   => %d pairs OK, mean per-pair %.1f GB/s/dir, node total %.1f GB/s/dir\n" \
      "$cnt" "$(awk -v t=$total -v c=$cnt 'BEGIN{print t/c/16}')" \
      "$(awk -v t=$total 'BEGIN{print t/16}')"
  fi
  rm -f /tmp/.ss.$$.* /tmp/.cc.$$.*
}

NGPU=$(nvidia-smi -L 2>/dev/null | wc -l)
echo "GPUs visible in this allocation: $NGPU"
if [ "$NGPU" -lt 2 ] || [ "${#PAIRS[@]}" -lt 2 ]; then
  echo "SKIPPED: concurrency scaling needs >=2 GPUs per node."
  echo "  (b200-devel caps a user at 2 GPUs total, so run this part on b200-batch"
  echo "   with --gpus-per-node=8. Parts 0/1/2/4 above are unaffected.)"
else
  for n in 1 2 4 8; do
    [ "$n" -le "${#PAIRS[@]}" ] || { echo "(skipping n=$n: only ${#PAIRS[@]} pairs available)"; continue; }
    scale_run $n; echo
  done
fi

# =======================================================================
echo "=================== PART 4: PCIe / firmware reads (unprivileged) ==================="
srun --overlap -N1 -n1 --nodelist="$SERVER" bash -c '
gpu=$(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader | head -1 | tr "A-Z" "a-z" | sed "s/^0000\{1,\}:/0000:/")
nic=$(lspci -D | grep -i mellanox | awk "{print \$1}" | head -1)
echo "--- 4a. DevCtl / MaxPayload / MaxReadReq / RlxdOrd (needs root; empty => NOT VISIBLE) ---"
for b in "$gpu" "$nic"; do
  echo "  device $b:"
  out=$(lspci -vvv -s "${b#0000:}" 2>/dev/null | grep -E "DevCtl|MaxPayload|MaxReadReq|RlxdOrd|NoSnoop|ACSCtl")
  if [ -n "$out" ]; then echo "$out" | sed "s/^/    /"; else echo "    (not visible -- unprivileged lspci omits the PCIe Express capability)"; fi
done
echo "--- 4b. config space readability ---"
echo "  GPU config bytes: $(dd if=/sys/bus/pci/devices/$gpu/config bs=1 count=4096 2>/dev/null | wc -c) of 4096"
echo "--- 4c. mlxconfig (root-only) ---"
mlxconfig -d "$nic" q 2>&1 | grep -iE "ORDERING|RELAX|ADVANCED_PCI|MAX_ACC" | sed "s/^/    /" || echo "    unavailable/denied"
echo "--- 4d. firmware version (AICR prior: 28.41.1000; Engaging: 28.49.1120) ---"
ibv_devinfo 2>/dev/null | grep -i fw_ver | sort -u | sed "s/^/    /"
'

# =======================================================================
echo
echo "################ RAW RESULT TABLE (Gb/s as reported) ################"
for k in "${!R[@]}"; do echo "RESULT $k ${R[$k]}"; done | sort
echo "################ END ################"
