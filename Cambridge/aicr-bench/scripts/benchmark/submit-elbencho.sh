#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/submit-elbencho.sh --cluster <b200|rtxpro6000> --workload <peak-cluster|small-block|small-file|metadata> [--profile <smoke|small>] [--partition <name>] [--nodes <n>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--nodelist <nodes>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--mem <size>] [--gres <gres>] [--repeat-count <n>] [--repeat-stagger-seconds <n>] [--dependency <slurm-dependency>] [--command <elbencho command>] [--apply]

Default behavior is a dry run. When --command or ELBENCHO_CMD is omitted, the
reviewed command template for --profile and --workload is used.
With --from-node-report, selects passed nodes for the requested cluster from the latest node report.
Repeats are submitted with afterok dependencies so storage jobs run serially.
Elbencho submissions default to --mem=0 so Slurm grants the job the node memory
cgroup. GPU batch partitions also require the cluster GPU GRES by default.
EOF
}

default_partition_for_cluster() {
  case "$1" in
    b200) printf 'b200-batch\n' ;;
    rtxpro6000) printf 'rtx-batch\n' ;;
    *) aicr_die "Unsupported cluster: $1" ;;
  esac
}

default_gres_for_cluster() {
  case "$1" in
    b200) printf 'gpu:b200:8\n' ;;
    rtxpro6000) printf 'gpu:rtx_pro_6000:8\n' ;;
    *) aicr_die "Unsupported cluster: $1" ;;
  esac
}

quote_args() {
  local out=""
  local item
  for item in "$@"; do
    if [[ -z "$out" ]]; then
      printf -v out '%q' "$item"
    else
      printf -v out '%s %q' "$out" "$item"
    fi
  done
  printf '%s\n' "$out"
}

validate_slurm_memory() {
  local value="$1"
  [[ -n "$value" ]] || aicr_die "--mem must not be empty"
  [[ "$value" =~ ^[0-9]+([KMGTP])?$ ]] || aicr_die "--mem must be a Slurm memory value such as 0, 512G, or 1T"
}

profile_command_path() {
  local profile_name="$1"
  local workload_name="$2"
  printf '%s/../../configs/elbencho/profiles/%s/%s.sh\n' "$BENCHMARK_DIR" "$profile_name" "$workload_name"
}

aicr_require_repo_root
[[ -n "${AICR_BMARK_DIR:-}" ]] || aicr_die "AICR_BMARK_DIR is empty; run from the repo root or set it explicitly"
aicr_mkdirs

repo_python=(aicr_python)

cluster=""
workload=""
profile="${ELBENCHO_PROFILE:-${PROFILE:-small}}"
partition=""
nodes="1"
nodelist=""
from_node_report=0
date_arg="today"
time_limit="01:00:00"
cpus_per_task="8"
memory_request="${ELBENCHO_MEM:-0}"
gres_request="${ELBENCHO_GRES:-}"
repeat_count="${ELBENCHO_REPEAT_COUNT:-1}"
repeat_stagger_seconds="${ELBENCHO_REPEAT_STAGGER_SECONDS:-30}"
external_dependency="${ELBENCHO_DEPENDENCY:-}"
elbencho_cmd="${ELBENCHO_CMD:-}"
apply=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --workload)
      workload="${2:-}"
      shift 2
      ;;
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --partition)
      partition="${2:-}"
      shift 2
      ;;
    --nodes)
      nodes="${2:-}"
      shift 2
      ;;
    --nodelist)
      nodelist="${2:-}"
      shift 2
      ;;
    --from-node-report)
      from_node_report=1
      shift
      ;;
    --date)
      date_arg="${2:-}"
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
    --gres)
      gres_request="${2:-}"
      shift 2
      ;;
    --repeat-count)
      repeat_count="${2:-}"
      shift 2
      ;;
    --repeat-stagger-seconds)
      repeat_stagger_seconds="${2:-}"
      shift 2
      ;;
    --dependency)
      external_dependency="${2:-}"
      shift 2
      ;;
    --command)
      elbencho_cmd="${2:-}"
      shift 2
      ;;
    --apply)
      apply=1
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

[[ -n "$cluster" ]] || {
  usage
  exit 2
}
[[ -n "$workload" ]] || {
  usage
  exit 2
}
aicr_assert_supported_cluster "$cluster"
case "$workload" in
  peak-cluster|small-block|small-file|metadata) ;;
  *) aicr_die "--workload must be peak-cluster, small-block, small-file, or metadata" ;;
esac
case "$profile" in
  smoke|small) ;;
  *) aicr_die "--profile must be smoke or small" ;;
esac
[[ "$nodes" =~ ^[0-9]+$ && "$nodes" -gt 0 ]] || aicr_die "--nodes must be a positive integer"
[[ "$cpus_per_task" =~ ^[0-9]+$ && "$cpus_per_task" -gt 0 ]] || aicr_die "--cpus-per-task must be a positive integer"
validate_slurm_memory "$memory_request"
[[ "$repeat_count" =~ ^[0-9]+$ && "$repeat_count" -gt 0 ]] || aicr_die "--repeat-count must be a positive integer"
[[ "$repeat_stagger_seconds" =~ ^[0-9]+$ ]] || aicr_die "--repeat-stagger-seconds must be a nonnegative integer"
[[ "$time_limit" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || aicr_die "--time must be HH:MM:SS"
[[ -z "$external_dependency" || "$external_dependency" =~ ^[A-Za-z0-9_,:\?\.\-]+$ ]] || aicr_die "--dependency contains unsupported characters"
if [[ "$apply" -eq 1 && "$workload" == "peak-cluster" && "$nodes" -lt 2 ]]; then
  aicr_die "peak-cluster apply requires --nodes 2 or greater"
fi
if [[ "$apply" -eq 1 && "$cluster" == "b200" && "${AICR_ELBENCHO_B200_APPLY_ALLOW:-0}" != "1" ]]; then
  aicr_die "B200 Elbencho apply is gated; set AICR_ELBENCHO_B200_APPLY_ALLOW=1 only after site facts and node policy are approved"
fi
if [[ "$from_node_report" -eq 1 ]]; then
  [[ -z "$nodelist" ]] || aicr_die "--from-node-report and --nodelist cannot be combined"
  nodelist="$("${repo_python[@]}" "${BENCHMARK_DIR}/select-benchmark-nodes.py" --date "$date_arg" --cluster "$cluster" --count "$nodes" --format csv)"
fi

partition="${partition:-$(default_partition_for_cluster "$cluster")}"
gres_request="${gres_request:-$(default_gres_for_cluster "$cluster")}"

if [[ -z "$elbencho_cmd" ]]; then
  template_path="$(profile_command_path "$profile" "$workload")"
  [[ -f "$template_path" ]] || aicr_die "missing Elbencho profile template: $template_path"
  elbencho_cmd="$(<"$template_path")"
fi

runner_cmd=("./scripts/benchmark/run-elbencho.sh" --cluster "$cluster" --workload "$workload" --profile "$profile")
if [[ -n "$elbencho_cmd" ]]; then
  runner_cmd+=(--command "$elbencho_cmd")
fi
wrap_cmd="cd $(quote_args "$AICR_BMARK_DIR") && $(quote_args "${runner_cmd[@]}")"

sbatch_base=(
  sbatch
  --parsable
  --partition="$partition"
  --nodes="$nodes"
  --ntasks-per-node=1
  --cpus-per-task="$cpus_per_task"
  --exclusive
  --mem="$memory_request"
  --gres="$gres_request"
  --time="$time_limit"
  --job-name="elbencho-${workload}-${profile}"
  --output="results/slurm/%x-%j.out"
  --error="results/slurm/%x-%j.err"
)
if [[ -n "$nodelist" ]]; then
  sbatch_base+=(--nodelist="$nodelist")
fi
wrap_arg=(--wrap="$wrap_cmd")

if [[ "$apply" -eq 0 ]]; then
  echo "Elbencho submission dry run"
  echo "  Cluster     : ${cluster}"
  echo "  Workload    : ${workload}"
  echo "  Profile     : ${profile}"
  echo "  Nodes       : ${nodes}"
  echo "  Partition   : ${partition}"
  echo "  Time limit  : ${time_limit}"
  echo "  CPUs/task   : ${cpus_per_task}"
  echo "  Memory      : ${memory_request}"
  echo "  GRES        : ${gres_request}"
  echo "  Repeats     : ${repeat_count}"
  echo "  Stagger sec : ${repeat_stagger_seconds}"
  if [[ -n "$nodelist" ]]; then
    echo "  Node list   : ${nodelist}"
  fi
  if [[ -n "$external_dependency" ]]; then
    echo "  Initial dep : ${external_dependency}"
  fi
  echo "  Dependency  : afterok chain between repeats"
  printf '  Command     : '
  printf '%q ' "${sbatch_base[@]}" "${wrap_arg[@]}"
  echo
  echo "Dry run only. Re-run with --apply to submit ${repeat_count} Elbencho row(s)."
  exit 0
fi

submitted=()
previous_job_id=""
for repeat_index in $(seq 1 "$repeat_count"); do
  repeat_cmd=("${sbatch_base[@]}")
  if [[ -n "$previous_job_id" ]]; then
    repeat_cmd+=(--dependency="afterok:${previous_job_id}")
  elif [[ -n "$external_dependency" ]]; then
    repeat_cmd+=(--dependency="$external_dependency")
  fi
  repeat_cmd+=("${wrap_arg[@]}")
  job_id="$("${repeat_cmd[@]}")"
  submitted+=("$job_id")
  echo "Submitted Elbencho ${workload} ${profile} repeat ${repeat_index}/${repeat_count} job ${job_id}"
  previous_job_id="$job_id"
  if [[ "$repeat_index" -lt "$repeat_count" && "$repeat_stagger_seconds" -gt 0 ]]; then
    sleep "$repeat_stagger_seconds"
  fi
done
printf 'Submitted Elbencho job ids: %s\n' "$(IFS=,; printf '%s' "${submitted[*]}")"
