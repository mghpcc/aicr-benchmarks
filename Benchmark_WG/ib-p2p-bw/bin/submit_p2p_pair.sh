#!/usr/bin/env bash
# Submit a single-pair p2p_pair.sbatch job.
#
# Usage: submit_p2p_pair.sh <nodeA> <nodeB> <gpuA> <gpuB>
#
# Defaults (override via env):
#   SBATCH_ACCOUNT=test
#   SBATCH_PARTITION=GPU2

set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $(basename "$0") <nodeA> <nodeB> <gpuA> <gpuB>" >&2
  exit 1
fi

nodeA="$1"; nodeB="$2"; gpuA="$3"; gpuB="$4"

acct="${SBATCH_ACCOUNT:-test}"
part="${SBATCH_PARTITION:-GPU2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bucket the SLURM stdout files by job id, 2000 ids per directory:
#   results/.slurm/0-1999/, results/.slurm/2000-3999/, ...
# The bucket is chosen from `scontrol show config | NextJobId`. If the
# real jobid lands across the next 2000-boundary the file is at most one
# bucket off; the file's own name still encodes the actual jobid.
slurm_out_base="$PWD/results/.slurm"
slurm_out_dir="$slurm_out_base"
if command -v scontrol >/dev/null 2>&1; then
  next_jobid="$(scontrol show config 2>/dev/null \
                | awk -F'=' '/^NextJobId[[:space:]]*=/ { gsub(/[[:space:]]/,"",$2); print $2; exit }')"
  if [[ "$next_jobid" =~ ^[0-9]+$ ]]; then
    bucket_lo=$(( (next_jobid / 2000) * 2000 ))
    bucket_hi=$(( bucket_lo + 1999 ))
    slurm_out_dir="$slurm_out_base/${bucket_lo}-${bucket_hi}"
  fi
fi
mkdir -p "$slurm_out_dir"

# - --chdir pins the job's cwd to the submit dir (some sites' default cwd is the slurmd spool)
# - P2P_SCRIPT_DIR lets the sbatch find its helper scripts regardless of where
#   slurmd copies the script body
exec sbatch \
  --account="$acct" \
  --partition="$part" \
  --nodes=2 \
  --nodelist="${nodeA},${nodeB}" \
  --chdir="$PWD" \
  --export="ALL,P2P_SCRIPT_DIR=$SCRIPT_DIR" \
  --output="${slurm_out_dir}/p2p-%j.out" \
  --job-name="p2p_${nodeA}_${nodeB}_g${gpuA}g${gpuB}" \
  "$SCRIPT_DIR/p2p_pair.sbatch" "$nodeA" "$nodeB" "$gpuA" "$gpuB"
