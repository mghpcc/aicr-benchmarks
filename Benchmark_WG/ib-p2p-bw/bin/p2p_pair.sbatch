#!/usr/bin/env bash
#SBATCH --job-name=p2p
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --time=00:15:00
#SBATCH --output=results/.slurm/p2p-%j.out
#
# One-pair point-to-point IB+CUDA bandwidth test.
#
# Usage (preferred -- via wrapper that sets account/partition/nodelist):
#   bin/submit_p2p_pair.sh <nodeA> <nodeB> <gpuA> <gpuB>
#
# Usage (direct):
#   sbatch --account=ACCT --partition=PART --nodelist=A,B \
#          bin/p2p_pair.sbatch <nodeA> <nodeB> <gpuA> <gpuB>
#
# Both sides use ib_write_bw (perftest tools must match on the wire; mixing
# ib_read_bw/ib_write_bw fails with IBV_WC_REM_OP_ERR / syndrome 0x8a because
# the read-side MR is not registered with WRITE access).
#
#   - server side (nodeA): ib_write_bw -d <nicA> --use_cuda=<gpuA> -q 8 -a --report_gbits
#   - client side (nodeB): ib_write_bw -d <nicB> --use_cuda=<gpuB> -q 8 -a --report_gbits <nodeA>
#
# This measures RDMA-WRITE bandwidth from client (nodeB) to server (nodeA).
# One direction per job.  To test the reverse direction submit a second job
# with nodeA / nodeB swapped.

set -euo pipefail

usage() {
  cat >&2 <<EOF
usage: sbatch [...] $(basename "$0") <nodeA> <nodeB> <gpuA> <gpuB>
  nodeA  hostname of server side  (runs ib_write_bw, no host arg)
  nodeB  hostname of client side  (runs ib_write_bw, connects to nodeA)
  gpuA   CUDA device index on nodeA
  gpuB   CUDA device index on nodeB
EOF
  exit 1
}

[[ $# -eq 4 ]] || usage

nodeA="$1"; nodeB="$2"; gpuA="$3"; gpuB="$4"

# Locate the helper scripts. SLURM copies the sbatch body to its spool dir
# before executing it, so ${BASH_SOURCE[0]} no longer points to bin/.
# The submit wrapper exports P2P_SCRIPT_DIR for us; fall back to BASH_SOURCE
# only for the case of a direct (non-wrapper) sbatch invocation.
if [[ -n "${P2P_SCRIPT_DIR:-}" ]]; then
  SCRIPT_DIR="$P2P_SCRIPT_DIR"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
fi
if [[ ! -f "$SCRIPT_DIR/select_nic_for_gpu.sh" ]]; then
  echo "ERROR: cannot find helper scripts at SCRIPT_DIR='$SCRIPT_DIR'." >&2
  echo "       Submit via bin/submit_p2p_pair.sh, or pass" >&2
  echo "       --export=ALL,P2P_SCRIPT_DIR=/abs/path/to/bin to sbatch." >&2
  exit 1
fi

# Output goes under the directory the user ran submit from.
ROOT="${SLURM_SUBMIT_DIR:-$PWD}"
cd "$ROOT"

ts="$(date +%Y-%m-%d_%H%M%S)"
server_dir="${nodeA}-gpu${gpuA}"
client_dir="${nodeB}"
pair_dir="${nodeA}-gpu${gpuA}__${nodeB}-gpu${gpuB}"
outdir="$ROOT/results/${server_dir}/${client_dir}/${pair_dir}/${ts}"
mkdir -p "$outdir" "$ROOT/results/.slurm"

{
  echo "ts=$ts"
  echo "nodeA=$nodeA  gpuA=$gpuA"
  echo "nodeB=$nodeB  gpuB=$gpuB"
  echo "SLURM_JOB_ID=${SLURM_JOB_ID:-}"
  echo "SLURM_JOB_NODELIST=${SLURM_JOB_NODELIST:-}"
} > "$outdir/params.txt"

echo "[1/5] resolving rail-correct NIC + NUMA on each side"
read -r nicA numaA < <(srun -N1 -w "$nodeA" --ntasks=1 \
  bash "$SCRIPT_DIR/select_nic_for_gpu.sh" "$gpuA")
read -r nicB numaB < <(srun -N1 -w "$nodeB" --ntasks=1 \
  bash "$SCRIPT_DIR/select_nic_for_gpu.sh" "$gpuB")

cat > "$outdir/nic_selection.txt" <<EOF
$nodeA gpu=$gpuA nic=$nicA numa=$numaA
$nodeB gpu=$gpuB nic=$nicB numa=$numaB
EOF
echo "  $nodeA gpu$gpuA -> $nicA (numa=$numaA)"
echo "  $nodeB gpu$gpuB -> $nicB (numa=$numaB)"

echo "[2/5] capturing nvidia-smi topo -m on each node"
srun -N1 -w "$nodeA" --ntasks=1 nvidia-smi topo -m > "$outdir/topo.${nodeA}.txt"
srun -N1 -w "$nodeB" --ntasks=1 nvidia-smi topo -m > "$outdir/topo.${nodeB}.txt"

echo "[3/5] recording IB switch path (best effort)"
bash "$SCRIPT_DIR/record_switch_path.sh" \
  "$nodeA" "$nicA" "$nodeB" "$nicB" \
  > "$outdir/switch_path.txt" 2>&1 || true

echo "[4/5] running perftest"
server_log="$outdir/server.${nodeA}.ib_write_bw.log"
client_log="$outdir/client.${nodeB}.ib_write_bw.log"

srun -N1 -w "$nodeA" --ntasks=1 \
  bash "$SCRIPT_DIR/run_perftest.sh" \
    ib_write_bw "$nicA" "$gpuA" "$numaA" \
  > "$server_log" 2>&1 &
server_pid=$!

# Give the server a moment to bind its listening socket before the client connects.
sleep 3

set +e
srun -N1 -w "$nodeB" --ntasks=1 \
  bash "$SCRIPT_DIR/run_perftest.sh" \
    ib_write_bw "$nicB" "$gpuB" "$numaB" "$nodeA" \
  > "$client_log" 2>&1
client_rc=$?

wait "$server_pid"
server_rc=$?
set -e

echo "[5/5] summarizing"
{
  echo "# point-to-point IB+CUDA bandwidth test"
  echo "# pair:    ${nodeA} gpu${gpuA}  <->  ${nodeB} gpu${gpuB}"
  echo "# server:  ib_write_bw on ${nodeA} via ${nicA} (numa=${numaA}) rc=${server_rc}"
  echo "# client:  ib_write_bw on ${nodeB} via ${nicB} (numa=${numaB}) rc=${client_rc}"
  echo "# direction: ${nodeB} -> ${nodeA}  (client writes to server)"
  echo "# ts:      ${ts}"
  echo
  echo "# last data row from client log:"
  echo "# columns: server_node server_gpu client_node client_gpu #bytes #iterations BW_peak BW_avg MsgRate"
  awk -v prefix="${nodeA} gpu${gpuA} ${nodeB} gpu${gpuB}" '
    /^[[:space:]]*[0-9]+[[:space:]]+[0-9]+[[:space:]]+[0-9.]+/ { last=$0 }
    END {
      if (last != "") {
        sub(/^[[:space:]]+/, "", last)
        print prefix, last
      } else {
        print prefix, "(no data row found)"
      }
    }
  ' "$client_log"
} > "$outdir/summary.txt"

cat "$outdir/summary.txt"
exit "$client_rc"
