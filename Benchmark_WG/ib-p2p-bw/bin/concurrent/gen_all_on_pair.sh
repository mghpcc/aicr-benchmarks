#!/usr/bin/env bash
# Emit a TSV pair-list for use case 1: every GPU on nodeA paired (rail-
# aligned) with the same-index GPU on nodeB.
#
# Usage:
#   gen_all_on_pair.sh <nodeA> <nodeB> [gpu_list]
#     nodeA, nodeB  hostnames; nodeA != nodeB
#     gpu_list      either 'all' (default; means 0..7) or a comma-separated
#                   list of GPU indices in 0..7 (e.g. 0,2,4,6)
#
# Output: one TSV row per selected GPU index, with fields
#   nodeA  nodeB  gpuA  gpuB    (gpuA == gpuB; rail-aligned)
# plus a leading '# generator: ...' comment line summarizing the run
# parameters.  Pipe into bin/concurrent/submit_concurrent.sh.

set -euo pipefail

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") <nodeA> <nodeB> [gpu_list]
  gpu_list: 'all' (default) or comma-separated indices in 0..7
            e.g. 'all', '0,2,4,6'
EOF
  exit 1
}

[[ $# -ge 2 && $# -le 3 ]] || usage

nodeA="$1"
nodeB="$2"
gpu_list="${3:-all}"

if [[ "$nodeA" == "$nodeB" ]]; then
  echo "ERROR: nodeA and nodeB must differ (got both '$nodeA')" >&2
  exit 1
fi

case "$gpu_list" in
  all) gpus=(0 1 2 3 4 5 6 7) ;;
  *)
    IFS=',' read -ra gpus <<<"$gpu_list"
    for g in "${gpus[@]}"; do
      if ! [[ "$g" =~ ^[0-7]$ ]]; then
        echo "ERROR: gpu_list entry '$g' is not an integer in 0..7" >&2
        exit 1
      fi
    done
    ;;
esac

echo "# generator: gen_all_on_pair.sh ${nodeA} ${nodeB} ${gpu_list}"
echo "# pairs: ${#gpus[@]}"
for g in "${gpus[@]}"; do
  printf '%s\t%s\t%s\t%s\n' "$nodeA" "$nodeB" "$g" "$g"
done
