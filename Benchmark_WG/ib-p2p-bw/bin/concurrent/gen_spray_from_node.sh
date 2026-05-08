#!/usr/bin/env bash
# Emit a TSV pair-list for use case 2: a single source node "sprays"
# its GPUs at randomly chosen remote (node, gpu) targets across the
# cluster.
#
# Usage:
#   gen_spray_from_node.sh <source_node> [count] [--exclude-nodes HOSTLIST]
#
#     source_node     hostname of the node whose GPUs are the senders
#     count           number of (sourceGpu -> remote) pairs to emit
#                     default 8 (= every GPU on the source node)
#     --exclude-nodes drop these nodes from the target population.
#                     HOSTLIST may be comma-separated names, a Slurm
#                     bracketed hostlist (e.g. b[0010-0012]), or a mix.
#                     Expansion uses 'scontrol show hostnames'.
#
# Source-side GPU index is taken sequentially from 0..count-1 on the
# source node (so count <= 8).  Each emitted row is one independent
# pair: (source_node, gpu_i) -> (random_target_node, random_target_gpu),
# with target_node != source_node.  Pairings may collide on the same
# remote node/GPU; that's by design (high-fan-out spray).
#
# Reproducibility (matches submit_random_pairs.sh):
#   - If P2P_SEED is set, it's used as the awk PRNG seed.
#   - If unset, a fresh seed is generated per call and printed.
#   - The seed used is always echoed in a '# seed: ...' comment row.

set -euo pipefail

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") <source_node> [count] [--exclude-nodes HOSTLIST]
  source_node     hostname of the source node
  count           number of pairs to emit (default 8; max 8)
  --exclude-nodes drop these nodes from the target population
                  (comma list, Slurm bracketed hostlist, or mix)

env:
  P2P_SEED        if set, used as PRNG seed for reproducibility
EOF
  exit 1
}

NODE_LO=1
NODE_HI=31
GPU_LO=0
GPU_HI=7

exclude_input=""
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --exclude-nodes)
      [[ $# -ge 2 ]] || { echo "ERROR: --exclude-nodes requires an argument" >&2; exit 1; }
      exclude_input="$2"; shift 2 ;;
    --exclude-nodes=*)
      exclude_input="${1#--exclude-nodes=}"; shift ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2; usage ;;
    *)
      positional+=("$1"); shift ;;
  esac
done

[[ ${#positional[@]} -ge 1 && ${#positional[@]} -le 2 ]] || usage

source_node="${positional[0]}"
count="${positional[1]:-8}"

if ! [[ "$count" =~ ^[0-9]+$ ]] || [[ "$count" -lt 1 || "$count" -gt 8 ]]; then
  echo "ERROR: count must be an integer in 1..8 (got '$count')" >&2
  exit 1
fi

excluded=()
if [[ -n "$exclude_input" ]]; then
  if command -v scontrol >/dev/null 2>&1; then
    while IFS= read -r host; do
      [[ -n "$host" ]] && excluded+=("$host")
    done < <(scontrol show hostnames "$exclude_input")
  elif [[ "$exclude_input" == *"["* ]]; then
    echo "ERROR: --exclude-nodes value '$exclude_input' uses bracketed" >&2
    echo "       hostlist syntax which requires 'scontrol' (not on PATH)." >&2
    exit 1
  else
    IFS=',' read -ra excluded <<<"$exclude_input"
  fi
fi
exclude_csv=""
[[ ${#excluded[@]} -gt 0 ]] && exclude_csv="$(IFS=','; echo "${excluded[*]}")"

seed="${P2P_SEED:-${RANDOM}${RANDOM}${RANDOM}}"

echo "# generator: gen_spray_from_node.sh ${source_node} ${count}$( [[ -n "$exclude_csv" ]] && echo " --exclude-nodes ${exclude_csv}" )"
echo "# seed: ${seed}"
[[ ${#excluded[@]} -gt 0 ]] && echo "# excluded: ${excluded[*]}"

awk -v src="$source_node" \
    -v count="$count" \
    -v seed="$seed" \
    -v lo="$NODE_LO" -v hi="$NODE_HI" \
    -v glo="$GPU_LO" -v ghi="$GPU_HI" \
    -v exclude_csv="$exclude_csv" '
  BEGIN {
    srand(seed + 0)
    if (exclude_csv != "") {
      n_ex = split(exclude_csv, ex_arr, ",")
      for (i = 1; i <= n_ex; i++) excluded[ex_arr[i]] = 1
    }
    excluded[src] = 1
    n = 0
    for (a = lo; a <= hi; a++) {
      sa = sprintf("b%04d", a)
      if (sa in excluded) continue
      for (g = glo; g <= ghi; g++) {
        n++
        T[n] = sa
        TG[n] = g
      }
    }
    if (n == 0) {
      print "ERROR: target population is empty after exclusions" > "/dev/stderr"
      exit 1
    }
    for (i = 0; i < count; i++) {
      pick = int(rand() * n) + 1
      printf "%s\t%s\t%d\t%d\n", src, T[pick], i, TG[pick]
    }
  }
'
