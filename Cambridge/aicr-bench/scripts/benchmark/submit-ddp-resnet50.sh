#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/submit-ddp-resnet50.sh [--cluster <b200|rtxpro6000>] --nodes <1|2|4|8|16> [--launcher <torchrun|srun>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--nodelist <csv>] [--partition <name>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--mem <size>] [--repeat-count <n>] [--repeat-stagger-seconds <n>] [--apply] [--] [run-ddp-resnet50 args...]

Default behavior is a dry run. With --from-node-report, selects passed nodes for the requested cluster from the latest node report.
Full-node DDP submissions default to --mem=0 so Slurm grants the node memory cgroup; override with --mem for diagnostics.
EOF
}

validate_slurm_memory() {
  local value="$1"
  [[ -z "$value" || "$value" =~ ^[0-9]+([KMGTP])?$ ]] || aicr_die "--mem must be a Slurm memory value such as 0, 512G, or 1T"
}

aicr_require_repo_root
aicr_mkdirs

repo_python=(aicr_python)

cluster="b200"
nodes=""
launcher="torchrun"
date_arg="today"
partition=""
time_limit="02:00:00"
cpus_per_task=""
memory_request=""
nodelist=""
from_node_report=0
repeat_count="${DDP_REPEAT_COUNT:-1}"
repeat_stagger_seconds="${DDP_REPEAT_STAGGER_SECONDS:-30}"
apply=0
forward_args=()
srun_mpi="${DDP_SRUN_MPI:-pmix}"
srun_cpu_bind="${DDP_SRUN_CPU_BIND:-}"
srun_mem_bind="${DDP_SRUN_MEM_BIND:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) cluster="${2:-}"; shift 2 ;;
    --nodes) nodes="${2:-}"; shift 2 ;;
    --launcher) launcher="${2:-}"; shift 2 ;;
    --date) date_arg="${2:-}"; shift 2 ;;
    --partition) partition="${2:-}"; shift 2 ;;
    --time) time_limit="${2:-}"; shift 2 ;;
    --cpus-per-task) cpus_per_task="${2:-}"; shift 2 ;;
    --mem) memory_request="${2:-}"; shift 2 ;;
    --nodelist) nodelist="${2:-}"; shift 2 ;;
    --repeat-count) repeat_count="${2:-}"; shift 2 ;;
    --repeat-stagger-seconds) repeat_stagger_seconds="${2:-}"; shift 2 ;;
    --from-node-report) from_node_report=1; shift ;;
    --apply) apply=1; shift ;;
    --)
      shift
      forward_args=("$@")
      break
      ;;
    -h|--help) usage; exit 0 ;;
    *) forward_args+=("$1"); shift ;;
  esac
done

aicr_assert_supported_cluster "$cluster"
case "$nodes" in
  1|2|4|8|16) ;;
  *) usage; exit 2 ;;
esac
if [[ "$cluster" == "rtxpro6000" ]]; then
  case "$nodes" in
    1|2|4) ;;
    *) aicr_die "RTX Pro 6000 DDP campaign support is limited to --nodes 1, 2, or 4 in this slice" ;;
  esac
fi
case "$launcher" in
  torchrun|srun) ;;
  *) aicr_die "--launcher must be torchrun or srun" ;;
esac
[[ "$time_limit" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || aicr_die "--time must be HH:MM:SS"
validate_slurm_memory "$memory_request"
[[ "$repeat_count" =~ ^[0-9]+$ && "$repeat_count" -gt 0 ]] || aicr_die "--repeat-count must be a positive integer"
[[ "$repeat_stagger_seconds" =~ ^[0-9]+$ ]] || aicr_die "--repeat-stagger-seconds must be a nonnegative integer"
if [[ -z "$partition" ]]; then
  case "$cluster" in
    b200) partition="b200-batch" ;;
    rtxpro6000) partition="rtx-batch" ;;
  esac
fi

if [[ "$from_node_report" -eq 1 ]]; then
  [[ -z "$nodelist" ]] || aicr_die "--from-node-report and --nodelist cannot be combined"
  nodelist="$("${repo_python[@]}" "${BENCHMARK_DIR}/select-benchmark-nodes.py" --date "$date_arg" --cluster "$cluster" --count "$nodes")"
fi

if [[ -z "$cpus_per_task" ]]; then
  if [[ "$launcher" == "torchrun" ]]; then
    cpus_per_task="128"
  else
    cpus_per_task="16"
  fi
fi
[[ "$cpus_per_task" =~ ^[0-9]+$ && "$cpus_per_task" -gt 0 ]] || aicr_die "--cpus-per-task must be a positive integer"
if [[ -z "$memory_request" ]]; then
  memory_request="0"
fi

case "${cluster}:${launcher}" in
  b200:torchrun) sbatch_script="slurm/benchmark/b200-ddp-resnet50-torchrun.sbatch" ;;
  b200:srun) sbatch_script="slurm/benchmark/b200-ddp-resnet50-srun.sbatch" ;;
  rtxpro6000:torchrun) sbatch_script="slurm/benchmark/rtxpro6000-ddp-resnet50-torchrun.sbatch" ;;
  rtxpro6000:srun) sbatch_script="slurm/benchmark/rtxpro6000-ddp-resnet50-srun.sbatch" ;;
  *) aicr_die "unsupported DDP submission shape: cluster=${cluster} launcher=${launcher}" ;;
esac

sbatch_cmd=(sbatch --parsable --partition="$partition" --time="$time_limit" --nodes="$nodes" --cpus-per-task="$cpus_per_task")
if [[ -n "$memory_request" ]]; then
  sbatch_cmd+=(--mem="$memory_request")
fi
if [[ -n "$nodelist" ]]; then
  sbatch_cmd+=(--nodelist="$nodelist")
fi
if [[ "$launcher" == "srun" ]]; then
  export_arg="ALL,DDP_SRUN_MPI=${srun_mpi}"
  if [[ -n "$srun_cpu_bind" ]]; then
    export_arg+=",DDP_SRUN_CPU_BIND=${srun_cpu_bind}"
  fi
  if [[ -n "$srun_mem_bind" ]]; then
    export_arg+=",DDP_SRUN_MEM_BIND=${srun_mem_bind}"
  fi
  sbatch_cmd+=(--export="$export_arg")
fi
sbatch_cmd+=("$sbatch_script")
if [[ "${#forward_args[@]}" -gt 0 ]]; then
  sbatch_cmd+=("${forward_args[@]}")
fi

echo "DDP ResNet-50 submission"
echo "  Mode        : $([[ "$apply" -eq 1 ]] && echo apply || echo dry-run)"
echo "  Jobs        : ${repeat_count}"
echo "  Cluster     : ${cluster}"
echo "  Nodes       : ${nodes}"
echo "  Launcher    : ${launcher}"
echo "  Partition   : ${partition}"
echo "  Time limit  : ${time_limit}"
echo "  CPUs/task   : ${cpus_per_task}"
echo "  Memory      : ${memory_request}"
echo "  Repeats     : ${repeat_count}"
echo "  Stagger sec : ${repeat_stagger_seconds}"
if [[ "$launcher" == "srun" ]]; then
  echo "  srun MPI    : ${srun_mpi}"
  echo "  CPU bind    : ${srun_cpu_bind:-default}"
  echo "  Mem bind    : ${srun_mem_bind:-default}"
fi
if [[ -n "$nodelist" ]]; then
  echo "  Node list   : ${nodelist}"
fi
printf '  Command     : '
printf '%q ' "${sbatch_cmd[@]}"
echo

if [[ "$apply" -eq 0 ]]; then
  echo "Dry run only. Pass --apply to submit ${repeat_count} DDP ResNet-50 row(s)."
  exit 0
fi

submitted=()
for repeat_index in $(seq 1 "$repeat_count"); do
  job_id="$("${sbatch_cmd[@]}")"
  submitted+=("$job_id")
  echo "Submitted DDP ResNet-50 repeat ${repeat_index}/${repeat_count} job ${job_id}"
  if [[ "$repeat_index" -lt "$repeat_count" && "$repeat_stagger_seconds" -gt 0 ]]; then
    sleep "$repeat_stagger_seconds"
  fi
done
printf 'Submitted DDP ResNet-50 job ids: %s\n' "$(IFS=,; printf '%s' "${submitted[*]}")"
