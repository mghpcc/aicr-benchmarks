#!/usr/bin/env bash
# Submit a single SLURM job that runs many ib_write_bw point-to-point
# pairs concurrently inside one allocation.
#
# Reads a TSV pair-list from --file or stdin.  Each non-comment, non-
# blank row is "<nodeA>  <nodeB>  <gpuA>  <gpuB>" (whitespace separated;
# tabs or spaces both fine).  Comments start with '#'.
#
# Usage:
#   submit_concurrent.sh [--file PATH | -]
#                        [--name NAME] [--time HH:MM:SS]
#                        [--account ACCT] [--partition PART]
#                        [--max-pairs N] [--dry-run]
#
# Defaults:
#   --file       stdin (use '-' or omit)
#   --time       00:30:00
#   --account    $SBATCH_ACCOUNT or 'test'
#   --partition  $SBATCH_PARTITION or 'GPU2'
#   --max-pairs  64  (safety guard against accidental huge submissions)
#
# What this script does (no perftest is launched here; that's the
# sbatch driver's job):
#   1. Parse + validate the TSV.
#   2. Compute the unique node set across all rows.
#   3. Assign a unique TCP port per pair (18515 + i).
#   4. Materialize an augmented TSV (with ports) + a params file under
#      results_concurrent/<run_id>/, then exec sbatch with the
#      P2P_PAIRS_FILE / P2P_RUN_DIR env exported in.
#
# With --dry-run: do steps 1-3, print what would be submitted, exit 0.

set -euo pipefail

usage() {
  cat <<EOF
usage: $(basename "$0") [--file PATH | -] [--name NAME] [--time HH:MM:SS]
                          [--account ACCT] [--partition PART]
                          [--max-pairs N] [--dry-run]

Read a TSV pair-list from --file or stdin and submit a single SLURM
job that runs all listed pairs concurrently in one allocation.

TSV format (whitespace separated; tabs or spaces):
    nodeA  nodeB  gpuA  gpuB
    nodeA  nodeB  gpuA  gpuB
    ...
'#' lines and blank lines are ignored.

Options:
  --file PATH     read TSV from PATH ('-' = stdin; default if omitted)
  --name NAME     SLURM job name (default 'p2p_conc')
  --time HH:MM:SS SLURM walltime (default 00:30:00)
  --account ACCT  SLURM account (default \$SBATCH_ACCOUNT or 'test')
  --partition P   SLURM partition (default \$SBATCH_PARTITION or 'GPU2')
  --max-pairs N   refuse if pair count exceeds N (default 64)
  --dry-run       validate, print sbatch invocation, do not submit
  -h, --help      show this help

Examples:
  bin/concurrent/gen_all_on_pair.sh b0025 b0026 \\
    | $(basename "$0") --name allrails

  $(basename "$0") --file pairs.tsv

  bin/concurrent/gen_random_pair_sets.sh 4 8 rail \\
    | $(basename "$0") --dry-run
EOF
}

file=""
name="p2p_conc"
walltime="00:30:00"
acct="${SBATCH_ACCOUNT:-test}"
part="${SBATCH_PARTITION:-GPU2}"
max_pairs=64
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)        usage; exit 0 ;;
    --file)           [[ $# -ge 2 ]] || { echo "ERROR: --file needs an argument" >&2; exit 1; }; file="$2"; shift 2 ;;
    --file=*)         file="${1#--file=}"; shift ;;
    --name)           [[ $# -ge 2 ]] || { echo "ERROR: --name needs an argument" >&2; exit 1; }; name="$2"; shift 2 ;;
    --name=*)         name="${1#--name=}"; shift ;;
    --time)           [[ $# -ge 2 ]] || { echo "ERROR: --time needs an argument" >&2; exit 1; }; walltime="$2"; shift 2 ;;
    --time=*)         walltime="${1#--time=}"; shift ;;
    --account)        [[ $# -ge 2 ]] || { echo "ERROR: --account needs an argument" >&2; exit 1; }; acct="$2"; shift 2 ;;
    --account=*)      acct="${1#--account=}"; shift ;;
    --partition)      [[ $# -ge 2 ]] || { echo "ERROR: --partition needs an argument" >&2; exit 1; }; part="$2"; shift 2 ;;
    --partition=*)    part="${1#--partition=}"; shift ;;
    --max-pairs)      [[ $# -ge 2 ]] || { echo "ERROR: --max-pairs needs an argument" >&2; exit 1; }; max_pairs="$2"; shift 2 ;;
    --max-pairs=*)    max_pairs="${1#--max-pairs=}"; shift ;;
    --dry-run|-n)     dry_run=1; shift ;;
    -)                file="-"; shift ;;
    *)                echo "ERROR: unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if ! [[ "$max_pairs" =~ ^[0-9]+$ ]] || [[ "$max_pairs" -lt 1 ]]; then
  echo "ERROR: --max-pairs must be a positive integer (got '$max_pairs')" >&2
  exit 1
fi

# Read the TSV into memory so we can validate, count, and write out
# with ports without two passes over a possibly-stdin source.
input_label="$file"
if [[ -z "$file" || "$file" == "-" ]]; then
  input_label="<stdin>"
  input="$(cat)"
else
  if [[ ! -r "$file" ]]; then
    echo "ERROR: cannot read pair-list file '$file'" >&2
    exit 1
  fi
  input="$(<"$file")"
fi

# Capture the original header comments so we can preserve generator
# provenance in the materialized pairs.tsv.
orig_comments="$(printf '%s\n' "$input" | awk '/^[[:space:]]*#/ { print } /^[[:space:]]*$/ { next } /^[^#[:space:]]/ { exit }')"

A=(); B=(); GA=(); GB=(); nodes_seen=()
npairs=0
line_no=0
while IFS= read -r raw; do
  line_no=$((line_no + 1))
  trimmed="${raw#"${raw%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  [[ -z "$trimmed" ]] && continue
  [[ "${trimmed:0:1}" == "#" ]] && continue
  read -r f1 f2 f3 f4 extra <<<"$trimmed"
  if [[ -z "$f1" || -z "$f2" || -z "$f3" || -z "$f4" || -n "$extra" ]]; then
    echo "ERROR: line $line_no in $input_label: expected 4 fields 'nodeA nodeB gpuA gpuB', got: $raw" >&2
    exit 1
  fi
  if ! [[ "$f3" =~ ^[0-7]$ && "$f4" =~ ^[0-7]$ ]]; then
    echo "ERROR: line $line_no in $input_label: gpuA/gpuB must be in 0..7 (got '$f3' '$f4')" >&2
    exit 1
  fi
  if [[ "$f1" == "$f2" ]]; then
    echo "ERROR: line $line_no in $input_label: nodeA == nodeB ('$f1')" >&2
    exit 1
  fi
  A+=("$f1"); B+=("$f2"); GA+=("$f3"); GB+=("$f4")
  nodes_seen+=("$f1" "$f2")
  npairs=$((npairs + 1))
done <<<"$input"

if [[ "$npairs" -eq 0 ]]; then
  echo "ERROR: no pairs found in $input_label" >&2
  exit 1
fi

if [[ "$npairs" -gt "$max_pairs" ]]; then
  echo "ERROR: pair count ($npairs) exceeds --max-pairs ($max_pairs)." >&2
  echo "       Pass --max-pairs $npairs explicitly if this is intentional." >&2
  exit 1
fi

unique_nodes=()
while IFS= read -r n; do unique_nodes+=("$n"); done < <(printf '%s\n' "${nodes_seen[@]}" | sort -u)
nnodes="${#unique_nodes[@]}"
nodelist="$(IFS=','; echo "${unique_nodes[*]}")"

# Max number of pair-rows that touch any single node (across both
# nodeA and nodeB columns).  This becomes --ntasks-per-node so the
# K parallel server/client sruns each get their own task slot rather
# than queueing for one shared slot (which silently serializes the
# pairs and breaks the test).
max_per_node=0
for node in "${unique_nodes[@]}"; do
  count=$(printf '%s\n' "${nodes_seen[@]}" | grep -cFx "$node" || true)
  if [[ "$count" -gt "$max_per_node" ]]; then max_per_node="$count"; fi
done
[[ "$max_per_node" -lt 1 ]] && max_per_node=1

ts="$(date +%Y-%m-%d_%H%M%S)"
run_id="${ts}__npairs${npairs}__${name}"
ROOT="${SLURM_SUBMIT_DIR:-$PWD}"
run_dir="$ROOT/results_concurrent/$run_id"
slurm_out_base="$ROOT/results_concurrent/.slurm"
slurm_out_dir="$slurm_out_base"

if [[ "$dry_run" -eq 0 ]]; then
  mkdir -p "$run_dir"
fi

pairs_file="$run_dir/pairs.tsv"
{
  if [[ -n "$orig_comments" ]]; then
    printf '%s\n' "$orig_comments"
  fi
  echo "# materialized: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# fields: idx port nodeA nodeB gpuA gpuB"
  for ((i=0; i<npairs; i++)); do
    port=$((18515 + i))
    printf '%d\t%d\t%s\t%s\t%s\t%s\n' "$i" "$port" "${A[i]}" "${B[i]}" "${GA[i]}" "${GB[i]}"
  done
} > /tmp/pairs.$$.tsv

if [[ "$dry_run" -eq 0 ]]; then
  mv /tmp/pairs.$$.tsv "$pairs_file"
fi

# Optional jobid bucketing for the sbatch stdout (mirrors the existing
# single-pair wrapper).  Only used when scontrol is available.
if command -v scontrol >/dev/null 2>&1; then
  next_jobid="$(scontrol show config 2>/dev/null \
                | awk -F'=' '/^NextJobId[[:space:]]*=/ { gsub(/[[:space:]]/,"",$2); print $2; exit }')"
  if [[ "$next_jobid" =~ ^[0-9]+$ ]]; then
    bucket_lo=$(( (next_jobid / 2000) * 2000 ))
    bucket_hi=$(( bucket_lo + 1999 ))
    slurm_out_dir="$slurm_out_base/${bucket_lo}-${bucket_hi}"
  fi
fi
if [[ "$dry_run" -eq 0 ]]; then
  mkdir -p "$slurm_out_dir"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"   # the existing bin/ next door

if [[ "$dry_run" -eq 0 ]]; then
  cat > "$run_dir/params.txt" <<EOF
ts=$ts
run_id=$run_id
input=$input_label
npairs=$npairs
nnodes=$nnodes
nodelist=$nodelist
ntasks_per_node=$max_per_node
account=$acct
partition=$part
walltime=$walltime
name=$name
script_dir=$SCRIPT_DIR
helper_dir=$HELPER_DIR
EOF
fi

echo "# pairs:           $npairs"
echo "# nodes:           $nnodes ($nodelist)"
echo "# ntasks-per-node: $max_per_node  (max pairs touching any single node)"
echo "# run_dir:         $run_dir"
echo "# pairs.tsv (first 5 data rows):"
view_file="$( [[ "$dry_run" -eq 0 ]] && echo "$pairs_file" || echo /tmp/pairs.$$.tsv )"
grep -v '^#' "$view_file" | head -n 5 | sed 's/^/#   /'

if [[ "$dry_run" -eq 1 ]]; then
  cat <<EOF
# (dry run; no job submitted)
# would invoke:
sbatch \\
  --account=$acct \\
  --partition=$part \\
  --nodes=$nnodes \\
  --nodelist=$nodelist \\
  --ntasks-per-node=$max_per_node \\
  --time=$walltime \\
  --chdir=$ROOT \\
  --export=ALL,P2P_SCRIPT_DIR=$HELPER_DIR,P2P_CONC_SCRIPT_DIR=$SCRIPT_DIR,P2P_PAIRS_FILE=$pairs_file,P2P_RUN_DIR=$run_dir \\
  --output=$slurm_out_dir/p2p_conc-%j.out \\
  --job-name=$name \\
  $SCRIPT_DIR/p2p_concurrent.sbatch
EOF
  rm -f /tmp/pairs.$$.tsv
  exit 0
fi

exec sbatch \
  --account="$acct" \
  --partition="$part" \
  --nodes="$nnodes" \
  --nodelist="$nodelist" \
  --ntasks-per-node="$max_per_node" \
  --time="$walltime" \
  --chdir="$ROOT" \
  --export="ALL,P2P_SCRIPT_DIR=$HELPER_DIR,P2P_CONC_SCRIPT_DIR=$SCRIPT_DIR,P2P_PAIRS_FILE=$pairs_file,P2P_RUN_DIR=$run_dir" \
  --output="$slurm_out_dir/p2p_conc-%j.out" \
  --job-name="$name" \
  "$SCRIPT_DIR/p2p_concurrent.sbatch"
