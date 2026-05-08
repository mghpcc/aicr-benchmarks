#!/usr/bin/env bash
#SBATCH --job-name=p2p_conc
#
# Concurrent multi-pair point-to-point IB+CUDA bandwidth driver.
#
# Submitted via bin/concurrent/submit_concurrent.sh, which always
# passes --ntasks-per-node=<max pairs touching any single node> at
# submit time so the K parallel server/client sruns each get their
# own task slot.  Direct sbatch invocation must do the same -- a
# bare sbatch will default to 1 task per node, in which case the
# parallel sruns silently serialize (steps queue) and no perftest
# run completes a measurement.
#
# The submitter exports:
#   P2P_PAIRS_FILE       absolute path to materialized TSV (idx port nodeA nodeB gpuA gpuB)
#   P2P_RUN_DIR          absolute path to the per-run output directory
#   P2P_SCRIPT_DIR       absolute path to bin/ (parent of bin/concurrent/)
#   P2P_CONC_SCRIPT_DIR  absolute path to bin/concurrent/
#
# All pairs run inside this single SLURM allocation.  Each pair gets a
# unique TCP port (column 2 of the materialized TSV) so multiple
# servers/clients on the same node don't collide.  Both sides use
# ib_write_bw -- mixing ib_read_bw and ib_write_bw is protocol-
# incompatible (see provenance/04_pitfalls.md item 1).  To measure
# read-bandwidth instead, change the two perftest commands below to
# ib_read_bw on both sides.

set -uo pipefail

: "${P2P_PAIRS_FILE:?must be set by submit_concurrent.sh}"
: "${P2P_RUN_DIR:?must be set by submit_concurrent.sh}"
: "${P2P_SCRIPT_DIR:?must be set by submit_concurrent.sh}"

cd "${SLURM_SUBMIT_DIR:-$PWD}"

if [[ ! -f "$P2P_SCRIPT_DIR/select_nic_for_gpu.sh" ]]; then
  echo "ERROR: cannot find helper scripts at P2P_SCRIPT_DIR='$P2P_SCRIPT_DIR'." >&2
  echo "       Submit via bin/concurrent/submit_concurrent.sh." >&2
  exit 1
fi

mkdir -p "$P2P_RUN_DIR"
cd "$P2P_RUN_DIR"

echo "[0/6] inputs"
echo "  pairs file:  $P2P_PAIRS_FILE"
echo "  run dir:     $P2P_RUN_DIR"
echo "  job id:      ${SLURM_JOB_ID:-?}"
echo "  nodelist:    ${SLURM_JOB_NODELIST:-?}"

# Read the pair list into parallel arrays (skip comment/blank lines).
IDX=(); PORT=(); A=(); B=(); GA=(); GB=()
while IFS=$'\t ' read -r f1 f2 f3 f4 f5 f6 _; do
  case "$f1" in ''|\#*) continue ;; esac
  IDX+=("$f1"); PORT+=("$f2"); A+=("$f3"); B+=("$f4"); GA+=("$f5"); GB+=("$f6")
done < "$P2P_PAIRS_FILE"
K="${#IDX[@]}"
if [[ "$K" -eq 0 ]]; then
  echo "ERROR: no pair rows parsed from $P2P_PAIRS_FILE" >&2
  exit 1
fi
echo "  pair count:  $K"

# ---- [1/6] resolve rail-correct NIC + NUMA per unique (node, gpu) ----
echo "[1/6] resolving NIC + NUMA for each unique (node, gpu)"
nic_select_log="$P2P_RUN_DIR/nic_selection.txt"
: > "$nic_select_log"
NIC_A=(); NUMA_A=(); NIC_B=(); NUMA_B=()
declare_cache=()  # parallel array of "node:gpu=nic numa" strings
cache_lookup() {
  local key="$1"
  local entry
  for entry in "${declare_cache[@]}"; do
    [[ "${entry%%=*}" == "$key" ]] && { echo "${entry#*=}"; return 0; }
  done
  return 1
}
for i in $(seq 0 $((K - 1))); do
  for side in A B; do
    if [[ "$side" == "A" ]]; then node="${A[i]}"; gpu="${GA[i]}"
    else                          node="${B[i]}"; gpu="${GB[i]}"
    fi
    key="$node:$gpu"
    if cached="$(cache_lookup "$key")"; then
      :
    else
      cached="$(srun -N1 -w "$node" --ntasks=1 \
        bash "$P2P_SCRIPT_DIR/select_nic_for_gpu.sh" "$gpu" 2>/dev/null || echo "ERR ?")"
      declare_cache+=("$key=$cached")
      echo "$node gpu=$gpu $cached" >> "$nic_select_log"
    fi
    nic="${cached%% *}"
    numa="${cached#* }"; [[ "$numa" == "$cached" ]] && numa=""
    if [[ "$side" == "A" ]]; then NIC_A+=("$nic"); NUMA_A+=("$numa")
    else                          NIC_B+=("$nic"); NUMA_B+=("$numa")
    fi
  done
done
cat "$nic_select_log"

# ---- [2/6] capture nvidia-smi topo -m once per unique node ----
echo "[2/6] capturing nvidia-smi topo -m on each unique node"
unique_nodes="$(printf '%s\n' "${A[@]}" "${B[@]}" | sort -u)"
for node in $unique_nodes; do
  srun -N1 -w "$node" --ntasks=1 nvidia-smi topo -m \
    > "$P2P_RUN_DIR/topo.${node}.txt" 2>&1 || true
done

# ---- [3/6] best-effort switch path per pair ----
echo "[3/6] recording IB switch paths (best effort)"
for i in $(seq 0 $((K - 1))); do
  bash "$P2P_SCRIPT_DIR/record_switch_path.sh" \
    "${A[i]}" "${NIC_A[i]}" "${B[i]}" "${NIC_B[i]}" \
    > "$P2P_RUN_DIR/switch_path.${i}.txt" 2>&1 || true
done

# ---- [4/6] start all servers in parallel ----
# The bash -c string runs on the compute node, so the `command -v
# numactl` check there gives the right local answer (matches the
# fallback in bin/run_perftest.sh).
echo "[4/6] starting $K servers in parallel"
SERVER_PIDS=()
for i in $(seq 0 $((K - 1))); do
  port="${PORT[i]}"
  nic="${NIC_A[i]}"; gpu="${GA[i]}"; numa="${NUMA_A[i]}"
  log="$P2P_RUN_DIR/server.${i}.${A[i]}.log"

  perftest="ib_write_bw -d $nic --use_cuda=$gpu -q 8 -a --report_gbits -p $port"
  if [[ -n "$numa" && "$numa" != "N/A" ]]; then
    cmd="if command -v numactl >/dev/null 2>&1; then exec numactl --cpunodebind=$numa --membind=$numa $perftest; else exec $perftest; fi"
  else
    cmd="exec $perftest"
  fi

  srun --overlap -N1 -w "${A[i]}" --ntasks=1 bash -c "$cmd" > "$log" 2>&1 &
  SERVER_PIDS+=($!)
  echo "  pair $i: server on ${A[i]} gpu${gpu} nic=$nic numa=${numa:--} port=$port"
done

# Give each server a moment to bind before clients try to connect.
sleep 5

# ---- [5/6] start all clients in parallel ----
echo "[5/6] starting $K clients in parallel"
CLIENT_PIDS=()
for i in $(seq 0 $((K - 1))); do
  port="${PORT[i]}"
  nic="${NIC_B[i]}"; gpu="${GB[i]}"; numa="${NUMA_B[i]}"
  log="$P2P_RUN_DIR/client.${i}.${B[i]}.log"
  host="${A[i]}"

  perftest="ib_write_bw -d $nic --use_cuda=$gpu -q 8 -a --report_gbits -p $port $host"
  if [[ -n "$numa" && "$numa" != "N/A" ]]; then
    cmd="if command -v numactl >/dev/null 2>&1; then exec numactl --cpunodebind=$numa --membind=$numa $perftest; else exec $perftest; fi"
  else
    cmd="exec $perftest"
  fi

  srun --overlap -N1 -w "${B[i]}" --ntasks=1 bash -c "$cmd" > "$log" 2>&1 &
  CLIENT_PIDS+=($!)
  echo "  pair $i: client on ${B[i]} gpu${gpu} nic=$nic numa=${numa:--} -> ${A[i]}:$port"
done

# Wait for all clients (they finish first; perftest exits after the run).
CLIENT_RC=()
for i in $(seq 0 $((K - 1))); do
  if wait "${CLIENT_PIDS[i]}"; then CLIENT_RC+=(0); else CLIENT_RC+=($?); fi
done

# Then reap servers (they exit when their client disconnects).
SERVER_RC=()
for i in $(seq 0 $((K - 1))); do
  if wait "${SERVER_PIDS[i]}"; then SERVER_RC+=(0); else SERVER_RC+=($?); fi
done

# ---- [6/6] summarize per pair + aggregate ----
echo "[6/6] summarizing"
agg="$P2P_RUN_DIR/summary.txt"
{
  echo "# concurrent point-to-point IB+CUDA bandwidth test"
  echo "# job id:    ${SLURM_JOB_ID:-?}"
  echo "# pairs:     $K"
  echo "# direction: client (B) -> server (A) per row, ib_write_bw both sides"
  echo "# columns:   server_node server_gpu client_node client_gpu #bytes #iterations BW_peak BW_avg MsgRate (Gb/s)"
  echo
} > "$agg"

total_bw=0
parsed=0
for i in $(seq 0 $((K - 1))); do
  per="$P2P_RUN_DIR/summary.${i}.txt"
  client_log="$P2P_RUN_DIR/client.${i}.${B[i]}.log"
  prefix="${A[i]} gpu${GA[i]} ${B[i]} gpu${GB[i]}"
  awk -v prefix="$prefix" '
    /^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9.]+/ { last=$0 }
    END {
      if (last != "") {
        sub(/^[[:space:]]+/, "", last)
        print prefix, last
      } else {
        print prefix, "(no data row found)"
      }
    }
  ' "$client_log" > "$per"

  cat "$per" >> "$agg"

  # Pull BW_avg (8th whitespace token after the 4-token prefix = field 8 of the data row).
  bw="$(awk '{
    if (NF >= 8 && $5 ~ /^[0-9]+$/) { print $8 }
  }' "$per")"
  if [[ -n "$bw" ]]; then
    total_bw="$(awk -v t="$total_bw" -v b="$bw" 'BEGIN{ printf "%.3f", t + b }')"
    parsed=$((parsed + 1))
  fi
done

{
  echo
  echo "# parsed BW_avg from $parsed / $K pairs"
  echo "# aggregate BW_avg sum (Gb/s): $total_bw"
} >> "$agg"

cat "$agg"

# Exit non-zero if any client failed.
fail=0
for rc in "${CLIENT_RC[@]}"; do
  [[ "$rc" -ne 0 ]] && fail=1
done
exit "$fail"
