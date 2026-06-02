#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/submit-ddp-launcher-comparison.sh --cluster <b200|rtxpro6000> [--scales <csv>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--nodelist <csv>] [--time <HH:MM:SS>] [--mem <size>] [--srun-cpu-bind <value>] [--srun-mem-bind <value>] [--srun-mpi <value>] [--include-default-srun] [--submit-stagger-seconds <n>] [--apply] [--] [run-ddp-resnet50 args...]

Submits or dry-runs a paired DDP launcher comparison:
  - torchrun
  - srun with explicit binding controls, defaulting to CPU/MEM no-bind

When --nodelist is provided, each scale uses the first N nodes from that list.
When --from-node-report is provided, each scale selects N strict-passed nodes.
Rows default to --mem=0 through submit-ddp-resnet50.sh.
EOF
}

csv_count() {
  local value="$1"
  tr ',' '\n' <<<"$value" | sed '/^$/d' | wc -l | tr -d ' '
}

csv_prefix() {
  local value="$1"
  local count="$2"
  tr ',' '\n' <<<"$value" | sed '/^$/d' | head -n "$count" | paste -sd, -
}

run_submit() {
  local label="$1"
  local launcher="$2"
  local nodes="$3"
  local cpu_bind="$4"
  local mem_bind="$5"
  local selected_nodes=()
  local submit_cmd=()

  echo
  echo "## ${label}"
  selected_nodes=(--cluster "$cluster" --nodes "$nodes" --launcher "$launcher" --date "$date_arg" --time "$time_limit" --mem "$memory_request")
  if [[ "$from_node_report" -eq 1 ]]; then
    selected_nodes+=(--from-node-report)
  else
    selected_nodes+=(--nodelist "$(csv_prefix "$nodelist" "$nodes")")
  fi
  if [[ "$apply" -eq 1 ]]; then
    selected_nodes+=(--apply)
  fi
  submit_cmd=("${selected_nodes[@]}")
  if [[ "${#forward_args[@]}" -gt 0 ]]; then
    submit_cmd+=(-- "${forward_args[@]}")
  fi

  if [[ "$launcher" == "srun" ]]; then
    DDP_SRUN_MPI="$srun_mpi" \
    DDP_SRUN_CPU_BIND="$cpu_bind" \
    DDP_SRUN_MEM_BIND="$mem_bind" \
      bash "${BENCHMARK_DIR}/submit-ddp-resnet50.sh" "${submit_cmd[@]}"
  else
    bash "${BENCHMARK_DIR}/submit-ddp-resnet50.sh" "${submit_cmd[@]}"
  fi
}

aicr_require_repo_root
aicr_mkdirs

cluster=""
date_arg="today"
scales_csv="1,2,4"
nodelist=""
from_node_report=0
time_limit="02:00:00"
memory_request="${DDP_MEM:-0}"
srun_mpi="${DDP_SRUN_MPI:-pmix}"
srun_cpu_bind="${DDP_SRUN_CPU_BIND:-none}"
srun_mem_bind="${DDP_SRUN_MEM_BIND:-none}"
include_default_srun=0
submit_stagger_seconds=0
apply=0
forward_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) cluster="${2:-}"; shift 2 ;;
    --date) date_arg="${2:-}"; shift 2 ;;
    --scales) scales_csv="${2:-}"; shift 2 ;;
    --nodelist) nodelist="${2:-}"; shift 2 ;;
    --from-node-report) from_node_report=1; shift ;;
    --time) time_limit="${2:-}"; shift 2 ;;
    --mem) memory_request="${2:-}"; shift 2 ;;
    --srun-mpi) srun_mpi="${2:-}"; shift 2 ;;
    --srun-cpu-bind) srun_cpu_bind="${2:-}"; shift 2 ;;
    --srun-mem-bind) srun_mem_bind="${2:-}"; shift 2 ;;
    --include-default-srun) include_default_srun=1; shift ;;
    --submit-stagger-seconds) submit_stagger_seconds="${2:-}"; shift 2 ;;
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

[[ -n "$cluster" ]] || {
  usage
  exit 2
}
aicr_assert_supported_cluster "$cluster"
[[ "$time_limit" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || aicr_die "--time must be HH:MM:SS"
[[ -n "$memory_request" ]] || aicr_die "--mem must not be empty"
[[ "$memory_request" =~ ^[0-9]+([KMGTP])?$ ]] || aicr_die "--mem must be a Slurm memory value such as 0, 512G, or 1T"
[[ "$submit_stagger_seconds" =~ ^[0-9]+$ ]] || aicr_die "--submit-stagger-seconds must be a non-negative integer"
if [[ "$from_node_report" -eq 1 && -n "$nodelist" ]]; then
  aicr_die "--from-node-report and --nodelist cannot be combined"
fi
if [[ "$from_node_report" -eq 0 && -z "$nodelist" ]]; then
  aicr_die "provide --nodelist or --from-node-report"
fi

IFS=',' read -r -a scales <<<"$scales_csv"
max_scale=0
for nodes in "${scales[@]}"; do
  case "$nodes" in
    1|2|4|8|16) ;;
    *) aicr_die "unsupported DDP scale: ${nodes}" ;;
  esac
  if [[ "$cluster" == "$AICR_CLUSTER_RTXPRO6000" ]]; then
    case "$nodes" in
      1|2|4) ;;
      *) aicr_die "RTX Pro 6000 DDP comparison support is limited to scales 1,2,4" ;;
    esac
  fi
  (( nodes > max_scale )) && max_scale="$nodes"
done

if [[ "$from_node_report" -eq 0 ]]; then
  available_count="$(csv_count "$nodelist")"
  if (( available_count < max_scale )); then
    aicr_die "--nodelist has ${available_count} node(s), but max requested scale is ${max_scale}"
  fi
fi

echo "DDP launcher comparison"
echo "  Cluster       : ${cluster}"
echo "  Date          : ${date_arg}"
echo "  Scales        : ${scales_csv}"
echo "  Time limit    : ${time_limit}"
echo "  Memory        : ${memory_request}"
echo "  srun MPI      : ${srun_mpi}"
echo "  srun CPU bind : ${srun_cpu_bind}"
echo "  srun Mem bind : ${srun_mem_bind}"
echo "  Default srun  : $([[ "$include_default_srun" -eq 1 ]] && echo yes || echo no)"
echo "  Apply         : $([[ "$apply" -eq 1 ]] && echo yes || echo no)"
if [[ "$from_node_report" -eq 1 ]]; then
  echo "  Node source   : strict-passed node report ${date_arg}"
else
  echo "  Node source   : ${nodelist}"
fi

submission_count=0
for nodes in "${scales[@]}"; do
  run_submit "DDP ${nodes}n torchrun" torchrun "$nodes" "" ""
  submission_count=$((submission_count + 1))
  if [[ "$apply" -eq 1 && "$submit_stagger_seconds" -gt 0 ]]; then
    sleep "$submit_stagger_seconds"
  fi

  run_submit "DDP ${nodes}n srun controlled-bind" srun "$nodes" "$srun_cpu_bind" "$srun_mem_bind"
  submission_count=$((submission_count + 1))
  if [[ "$apply" -eq 1 && "$submit_stagger_seconds" -gt 0 ]]; then
    sleep "$submit_stagger_seconds"
  fi

  if [[ "$include_default_srun" -eq 1 ]]; then
    run_submit "DDP ${nodes}n srun default-bind" srun "$nodes" "" ""
    submission_count=$((submission_count + 1))
    if [[ "$apply" -eq 1 && "$submit_stagger_seconds" -gt 0 ]]; then
      sleep "$submit_stagger_seconds"
    fi
  fi
done

echo
if [[ "$apply" -eq 1 ]]; then
  echo "Submitted ${submission_count} DDP launcher comparison job(s)."
else
  echo "Dry run complete for ${submission_count} DDP launcher comparison job(s)."
fi
