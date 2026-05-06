#!/usr/bin/env bash
# Best-effort recording of the InfiniBand switch path between two HCAs.
#
# Usage: record_switch_path.sh <nodeA> <nicA> <nodeB> <nicB>
#
# Steps:
#   1. Read the LID for each (node, nic) via `ibstat`.
#   2. Run `ibtracert <lidA> <lidB>` to dump the hop list.
#
# This script must be run from inside an active SLURM job (uses srun -w).
# It always exits 0 -- failure to introspect the fabric is logged but
# must not fail the bandwidth test.

set -uo pipefail

nodeA="${1:?missing nodeA}"
nicA="${2:?missing nicA}"
nodeB="${3:?missing nodeB}"
nicB="${4:?missing nicB}"

get_lid() {
  local node="$1" nic="$2"
  srun -N1 -w "$node" --ntasks=1 ibstat "$nic" 2>/dev/null \
    | awk '
        /^[[:space:]]*Port 1:/ { p=1; next }
        p && /Base lid:/        { print $NF; exit }
      '
}

lidA="$(get_lid "$nodeA" "$nicA" 2>/dev/null || true)"
lidB="$(get_lid "$nodeB" "$nicB" 2>/dev/null || true)"

echo "nodeA=${nodeA} nic=${nicA} lid=${lidA:-?}"
echo "nodeB=${nodeB} nic=${nicB} lid=${lidB:-?}"
echo

if [[ -z "$lidA" || -z "$lidB" ]]; then
  echo "(skipping ibtracert: missing LID on at least one side)"
  exit 0
fi

if ! command -v ibtracert >/dev/null 2>&1; then
  echo "(skipping ibtracert: not on PATH)"
  exit 0
fi

echo "# ibtracert ${lidA} ${lidB}"
ibtracert "$lidA" "$lidB" 2>&1 || \
  echo "(ibtracert returned non-zero; the cluster's SM may restrict it for unprivileged users)"
