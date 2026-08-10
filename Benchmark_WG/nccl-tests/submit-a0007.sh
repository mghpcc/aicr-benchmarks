#!/bin/bash
# Submit the post-PCIe-firmware 1-node NCCL batch on a0007.
# Jobs are chained with --dependency=afterany so they run one at a time on the
# reserved node (each is --exclusive) and a failure does not stall the chain.
# Reservation shaohao_a0007 runs 2026-08-10T11:00 .. 2026-08-11T11:00.

cd "$(dirname "$0")" || exit 1
mkdir -p out-1node-a0007

SCRIPTS=(
  a0007-topo.sh
  a0007-1node-8gpu.sh
  a0007-socket.sh
  a0007-pair-matrix.sh
  a0007-sweep.sh
)

dep=""
jids=()
for s in "${SCRIPTS[@]}"; do
  if [ -z "$dep" ]; then
    jid=$(sbatch --parsable "$s")
  else
    jid=$(sbatch --parsable --dependency=afterany:"$dep" "$s")
  fi
  [ -z "$jid" ] && { echo "FAILED to submit $s" >&2; exit 1; }
  echo "$jid  $s"
  jids+=("$jid")
  dep="$jid"
done

printf '%s\n' "${jids[@]}" > out-1node-a0007/JOBIDS
echo "last job = $dep"
