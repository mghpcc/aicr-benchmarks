#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/setup/submit-runtime-rebuild.sh [--apply] [--wait] [--wait-complete] [--partition <name>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--mem <size>] [--replace-current]

Default behavior is a dry run. Builder selection uses an exactly idle b200-batch
node. If b200-batch has no idle nodes, the helper fails unless --wait or --partition
is provided.
Runtime rebuild submissions default to --mem=0 so Slurm grants the job the node
memory cgroup.
EOF
}

expand_nodes() {
  local expr="$1"
  scontrol show hostnames "$expr"
}

first_idle_node_for_partition() {
  local partition="$1"
  local state nodespec node

  while IFS='|' read -r state nodespec; do
    [[ -n "$state" && -n "$nodespec" ]] || continue
    [[ "$state" == "idle" ]] || continue
    while IFS= read -r node; do
      [[ -n "$node" ]] || continue
      printf '%s\n' "$node"
      return 0
    done < <(expand_nodes "$nodespec")
  done < <(sinfo -h -p "$partition" -o '%T|%N' 2>/dev/null || true)

  return 1
}

apply=0
wait_for_idle=0
wait_for_completion=0
partition_override=""
time_limit="04:00:00"
cpus_per_task="16"
memory_request="${RUNTIME_MEM:-0}"
replace_current=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      apply=1
      shift
      ;;
    --wait)
      wait_for_idle=1
      shift
      ;;
    --wait-complete)
      wait_for_completion=1
      shift
      ;;
    --partition)
      partition_override="${2:-}"
      shift 2
      ;;
    --time)
      time_limit="${2:-}"
      shift 2
      ;;
    --cpus-per-task)
      cpus_per_task="${2:-}"
      shift 2
      ;;
    --mem)
      memory_request="${2:-}"
      shift 2
      ;;
    --replace-current)
      replace_current=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ "$time_limit" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || aicr_die "--time must be HH:MM:SS"
[[ "$cpus_per_task" =~ ^[0-9]+$ && "$cpus_per_task" -gt 0 ]] || aicr_die "--cpus-per-task must be a positive integer"
[[ -n "$memory_request" ]] || aicr_die "--mem must not be empty"
[[ "$memory_request" =~ ^[0-9]+([KMGTP])?$ ]] || aicr_die "--mem must be a Slurm memory value such as 0, 512G, or 1T"

aicr_require_repo_root
aicr_require_settings_file
mkdir -p "${AICR_RESULTS_DIR}/slurm"

sbatch_path="slurm/setup/rebuild-runtime.sbatch"
[[ -f "${AICR_BMARK_DIR}/${sbatch_path}" ]] || aicr_die "Missing Slurm script: ${sbatch_path}"

selected_partition=""
selected_node=""
selection_note=""

if [[ -n "$partition_override" ]]; then
  selected_partition="$partition_override"
  selection_note="explicit partition override"
else
  if selected_node="$(first_idle_node_for_partition b200-batch)"; then
    selected_partition="b200-batch"
    selection_note="idle b200-batch"
  elif [[ "$wait_for_idle" == "1" ]]; then
    selected_partition="b200-batch"
    selection_note="queued on b200-batch because --wait was provided"
  else
    echo "ERROR: no exactly-idle builder nodes found in b200-batch" >&2
    echo "Pass --wait to queue on b200-batch, or --partition <name> for an explicit override." >&2
    exit 1
  fi
fi

sbatch_cmd=(sbatch --parsable --partition="$selected_partition" --time="$time_limit" --cpus-per-task="$cpus_per_task" --mem="$memory_request")
if [[ -n "$selected_node" ]]; then
  sbatch_cmd+=(--nodelist="$selected_node")
fi
sbatch_cmd+=("$sbatch_path")
if [[ "$replace_current" == "1" ]]; then
  sbatch_cmd+=(--replace-current)
fi

echo "Runtime rebuild submission"
echo "  Runtime root : ${AICR_RUNTIME_ROOT}"
echo "  Selection    : ${selection_note}"
echo "  Partition    : ${selected_partition}"
if [[ -n "$selected_node" ]]; then
  echo "  Node         : ${selected_node}"
fi
echo "  Time limit   : ${time_limit}"
echo "  CPUs/task    : ${cpus_per_task}"
echo "  Memory       : ${memory_request}"
printf '  Command      : '
printf '%q ' "${sbatch_cmd[@]}"
echo

if [[ "$apply" == "0" ]]; then
  echo "Dry run only. Pass --apply to submit."
  exit 0
fi

cd "$AICR_BMARK_DIR"
job_id="$("${sbatch_cmd[@]}")"
job_id="${job_id%%;*}"
[[ -n "$job_id" ]] || aicr_die "sbatch did not return a job ID"
echo "Submitted runtime rebuild job ${job_id}"

if [[ "$wait_for_completion" == "1" ]]; then
  echo "Waiting for runtime rebuild job ${job_id} to leave the Slurm queue."
  while true; do
    active="$(squeue -h -j "$job_id" -o "%i %T %N" 2>/dev/null || true)"
    if [[ -z "$active" ]]; then
      echo "Runtime rebuild job ${job_id} is no longer queued or running."
      break
    fi
    echo "Still active:"
    echo "$active" | sed 's/^/  /'
    sleep 30
  done
  sleep 5
fi
