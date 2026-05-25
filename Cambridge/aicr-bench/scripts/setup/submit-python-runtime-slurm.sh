#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/setup/submit-python-runtime-slurm.sh --cluster <b200|rtxpro6000> [--setup] [--apply] [--wait] [--partition <name>] [--gres <value|none>] [--nodelist <csv>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--mem <size>]

Default behavior is a dry run. The submitted job verifies that a compute-node
Slurm allocation uses the same direct repo Python runtime as login-node renders
and submitters.
Pass --setup to build or refresh the configured uv environment inside the Slurm
allocation before running the doctor/import checks.
Submissions default to --mem=0 so Slurm grants the job the node memory cgroup.
EOF
}

default_partition() {
  case "$1" in
    b200) printf 'b200-devel\n' ;;
    rtxpro6000) printf 'rtx-devel\n' ;;
    *) aicr_die "unsupported cluster: $1" ;;
  esac
}

default_gres() {
  case "$1" in
    b200) printf 'gpu:b200:1\n' ;;
    rtxpro6000) printf 'gpu:1\n' ;;
    *) aicr_die "unsupported cluster: $1" ;;
  esac
}

cluster=""
partition=""
gres=""
nodelist=""
time_limit="00:05:00"
cpus_per_task="2"
memory_request="${PYTHON_DOCTOR_MEM:-0}"
run_setup=0
apply=0
wait_for_completion=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) cluster="${2:-}"; shift 2 ;;
    --partition) partition="${2:-}"; shift 2 ;;
    --gres) gres="${2:-}"; shift 2 ;;
    --nodelist) nodelist="${2:-}"; shift 2 ;;
    --time) time_limit="${2:-}"; shift 2 ;;
    --cpus-per-task) cpus_per_task="${2:-}"; shift 2 ;;
    --mem) memory_request="${2:-}"; shift 2 ;;
    --setup) run_setup=1; shift ;;
    --apply) apply=1; shift ;;
    --wait) wait_for_completion=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$cluster" ]] || { usage; exit 2; }
aicr_assert_supported_cluster "$cluster"
[[ "$time_limit" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || aicr_die "--time must be HH:MM:SS"
[[ "$cpus_per_task" =~ ^[0-9]+$ && "$cpus_per_task" -gt 0 ]] || aicr_die "--cpus-per-task must be a positive integer"
[[ -n "$memory_request" ]] || aicr_die "--mem must not be empty"
[[ "$memory_request" =~ ^[0-9]+([KMGTP])?$ ]] || aicr_die "--mem must be a Slurm memory value such as 0, 512G, or 1T"

aicr_require_repo_root
aicr_require_settings_file
aicr_mkdirs
mkdir -p "${AICR_RESULTS_DIR}/slurm"

partition="${partition:-$(default_partition "$cluster")}"
gres="${gres:-$(default_gres "$cluster")}"

sbatch_path="slurm/setup/python-runtime-slurm.sbatch"
[[ -f "${AICR_BMARK_DIR}/${sbatch_path}" ]] || aicr_die "Missing Slurm script: ${sbatch_path}"

sbatch_cmd=(
  sbatch
  --parsable
  --partition="$partition"
  --nodes=1
  --ntasks=1
  --cpus-per-task="$cpus_per_task"
  --mem="$memory_request"
  --time="$time_limit"
  --job-name="${cluster}-python-runtime-slurm"
  --output="results/slurm/%x-%j.out"
  --error="results/slurm/%x-%j.err"
  --export="ALL,AICR_CLUSTER_NAME=${cluster},AICR_PYTHON_RUNTIME_SETUP=${run_setup}"
)
if [[ "$gres" != "none" ]]; then
  sbatch_cmd+=(--gres="$gres")
fi
if [[ -n "$nodelist" ]]; then
  sbatch_cmd+=(--nodelist="$nodelist")
fi
sbatch_cmd+=("$sbatch_path")

echo "Slurm Python runtime doctor submission"
echo "  Cluster     : ${cluster}"
echo "  Partition   : ${partition}"
echo "  GRES        : ${gres}"
if [[ -n "$nodelist" ]]; then
  echo "  Node list   : ${nodelist}"
fi
echo "  Time limit  : ${time_limit}"
echo "  CPUs/task   : ${cpus_per_task}"
echo "  Memory      : ${memory_request}"
echo "  Setup first : ${run_setup}"
printf '  Command     : '
printf '%q ' "${sbatch_cmd[@]}"
echo

if [[ "$apply" -eq 0 ]]; then
  echo "Dry run only. Pass --apply to submit."
  exit 0
fi

command -v sbatch >/dev/null 2>&1 || aicr_die "sbatch is required for --apply"

cd "$AICR_BMARK_DIR"
job_id="$("${sbatch_cmd[@]}")"
job_id="${job_id%%;*}"
[[ -n "$job_id" ]] || aicr_die "sbatch did not return a job ID"
echo "Submitted Slurm Python runtime doctor job ${job_id}"

if [[ "$wait_for_completion" -eq 1 ]]; then
  if ! command -v squeue >/dev/null 2>&1; then
    echo "squeue is not available; cannot wait for completion." >&2
    exit 0
  fi
  echo "Waiting for job ${job_id} to leave the Slurm queue."
  while true; do
    active="$(squeue -h -j "$job_id" -o "%i %T %N" 2>/dev/null || true)"
    if [[ -z "$active" ]]; then
      echo "Job ${job_id} is no longer queued or running."
      break
    fi
    echo "$active" | sed 's/^/  /'
    sleep 10
  done
  sleep 3

  latest_status="$(ls -td "results/setup/${cluster}/parsed/${AICR_CHECK_PYTHON_RUNTIME_SLURM}"/*/status.json 2>/dev/null | head -n 1 || true)"
  if [[ -n "$latest_status" ]]; then
    echo "Latest status: ${latest_status}"
    sed 's/^/  /' "$latest_status"
  else
    echo "No parsed status found yet under results/setup/${cluster}/parsed/${AICR_CHECK_PYTHON_RUNTIME_SLURM}/" >&2
  fi
fi
