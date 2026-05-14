#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/sweep-dataloader.sh [--cluster <b200|rtxpro6000>] [--profile <small|medium|large>] [--inspect-profile] [--nodes <csv>] [--nodes-list <csv>] [--gpu-count <1|8>] [--mode <single|replicated|distributed-sharded>] [--repeat-count <n>] [--num-workers-list <csv>] [--batch-size-list <csv>] [--prefetch-factor-list <csv>] [--pin-memory-list <csv>] [--persistent-workers-list <csv>] [--cpus-per-task <n>] [--cpus-per-task-list <csv>] [--partition <name>] [--time <HH:MM:SS>] [--nodelist <node[,node...]>] [--apply] [--] [runner args...]

Default behavior is a dry run: print one Slurm submission command per sweep point.
The default sweep varies --num-workers across 4,8,16,24,32 while holding the canonical dataloader config constant.
When --nodelist has more nodes than a sweep point requests, the helper treats it as an ordered pool and passes the first N nodes to that point.
Arguments after -- are forwarded to scripts/benchmark/run-dataloader.sh for every submitted job and must not repeat sweep-owned runner flags.
Profiles control runner workload intensity defaults only. Sweep axes remain explicit.

B200 accepts nodes 1, 2, 4, 8, or 16. RTX accepts nodes 1, 2, 4, or 8.
EOF
}

default_partition() {
  case "$1" in
    b200) printf 'GPU2\n' ;;
    rtxpro6000) printf 'GPU1\n' ;;
    *) aicr_die "unsupported cluster: $1" ;;
  esac
}

validate_positive_int_list() {
  local label="$1"
  shift
  local value
  for value in "$@"; do
    [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 ]] || aicr_die "${label} values must be positive integers: ${value}"
  done
}

validate_non_negative_int_list() {
  local label="$1"
  shift
  local value
  for value in "$@"; do
    [[ "$value" =~ ^[0-9]+$ ]] || aicr_die "${label} values must be non-negative integers: ${value}"
  done
}

validate_binary_list() {
  local label="$1"
  shift
  local value
  for value in "$@"; do
    [[ "$value" == "0" || "$value" == "1" ]] || aicr_die "${label} values must be 0 or 1: ${value}"
  done
}

assert_no_sweep_arg_conflicts() {
  local args=("$@")
  local index=0
  while [[ $index -lt ${#args[@]} ]]; do
    case "${args[$index]}" in
      --batch-size|--num-workers|--prefetch-factor|--pin-memory|--persistent-workers|--cluster|--mode|--nodes|--node-count|--requested-gpu-count)
        aicr_die "Arguments after -- must not include sweep-owned runner flag: ${args[$index]}"
        ;;
    esac
    index=$((index + 1))
  done
}

ordered_nodelist_prefix() {
  local requested_count="$1"
  local node_csv="$2"
  local nodes=()
  local selected=()

  IFS=',' read -r -a nodes <<<"$node_csv"
  if [[ "${#nodes[@]}" -lt "$requested_count" ]]; then
    aicr_die "--nodelist has ${#nodes[@]} node(s), but this sweep point requires ${requested_count}: ${node_csv}"
  fi
  selected=("${nodes[@]:0:requested_count}")
  local IFS=,
  printf '%s\n' "${selected[*]}"
}

aicr_require_repo_root
aicr_mkdirs

num_workers_csv="4,8,16,24,32"
batch_size_csv="256"
prefetch_factor_csv="4"
pin_memory_csv="1"
persistent_workers_csv="1"
nodes_csv="1"
cluster="b200"
profile="${PROFILE:-small}"
partition=""
time_limit="01:00:00"
cpus_per_task="16"
cpus_per_task_csv=""
gpu_count="1"
mode=""
nodelist=""
repeat_count="1"
apply=0
inspect_profile=0
shared_args=()
cpus_per_task_flag_set=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --profile=*)
      profile="${1#--profile=}"
      shift
      ;;
    --inspect-profile)
      inspect_profile=1
      shift
      ;;
    --gpu-count)
      gpu_count="${2:-}"
      shift 2
      ;;
    --nodes)
      nodes_csv="${2:-}"
      shift 2
      ;;
    --nodes-list)
      nodes_csv="${2:-}"
      shift 2
      ;;
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --repeat-count)
      repeat_count="${2:-}"
      shift 2
      ;;
    --num-workers-list)
      num_workers_csv="${2:-}"
      shift 2
      ;;
    --batch-size-list)
      batch_size_csv="${2:-}"
      shift 2
      ;;
    --prefetch-factor-list)
      prefetch_factor_csv="${2:-}"
      shift 2
      ;;
    --pin-memory-list)
      pin_memory_csv="${2:-}"
      shift 2
      ;;
    --persistent-workers-list)
      persistent_workers_csv="${2:-}"
      shift 2
      ;;
    --partition)
      partition="${2:-}"
      shift 2
      ;;
    --time)
      time_limit="${2:-}"
      shift 2
      ;;
    --cpus-per-task)
      cpus_per_task="${2:-}"
      cpus_per_task_flag_set=1
      shift 2
      ;;
    --cpus-per-task-list)
      cpus_per_task_csv="${2:-}"
      shift 2
      ;;
    --nodelist)
      nodelist="${2:-}"
      shift 2
      ;;
    --apply)
      apply=1
      shift
      ;;
    --)
      shift
      shared_args=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      aicr_die "Unknown argument: $1"
      ;;
  esac
done

case "$profile" in
  small|medium|large) ;;
  *) aicr_die "--profile must be small, medium, or large" ;;
esac
if [[ "$inspect_profile" == "1" ]]; then
  scripts/benchmark/run-dataloader.sh --profile "$profile" --inspect-profile
  exit 0
fi

aicr_assert_supported_cluster "$cluster"
partition="${partition:-$(default_partition "$cluster")}"
[[ "$time_limit" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || aicr_die "--time must be HH:MM:SS"
[[ "$cpus_per_task" =~ ^[0-9]+$ && "$cpus_per_task" -gt 0 ]] || aicr_die "--cpus-per-task must be a positive integer"
[[ "$repeat_count" =~ ^[0-9]+$ && "$repeat_count" -gt 0 ]] || aicr_die "--repeat-count must be a positive integer"
case "$gpu_count" in
  1|8) ;;
  *) aicr_die "--gpu-count must be 1 or 8" ;;
esac
if [[ -z "$mode" ]]; then
  if [[ "$gpu_count" == "8" ]]; then
    mode="replicated"
  else
    mode="single"
  fi
fi
case "$mode" in
  single)
    [[ "$gpu_count" == "1" ]] || aicr_die "--mode single requires --gpu-count 1"
    ;;
  replicated|distributed-sharded)
    [[ "$gpu_count" == "8" ]] || aicr_die "--mode ${mode} requires --gpu-count 8"
    ;;
  *) aicr_die "--mode must be single, replicated, or distributed-sharded" ;;
esac
if [[ -n "$cpus_per_task_csv" && "$cpus_per_task_flag_set" -eq 1 ]]; then
  aicr_die "--cpus-per-task and --cpus-per-task-list cannot be used together"
fi
nodes_list=()
num_workers_list=()
batch_size_list=()
prefetch_factor_list=()
pin_memory_list=()
persistent_workers_list=()
cpus_per_task_list=()
IFS=',' read -r -a nodes_list <<<"$nodes_csv"
IFS=',' read -r -a num_workers_list <<<"$num_workers_csv"
IFS=',' read -r -a batch_size_list <<<"$batch_size_csv"
IFS=',' read -r -a prefetch_factor_list <<<"$prefetch_factor_csv"
IFS=',' read -r -a pin_memory_list <<<"$pin_memory_csv"
IFS=',' read -r -a persistent_workers_list <<<"$persistent_workers_csv"
if [[ -n "$cpus_per_task_csv" ]]; then
  IFS=',' read -r -a cpus_per_task_list <<<"$cpus_per_task_csv"
else
  cpus_per_task_list=("$cpus_per_task")
fi

[[ "${#nodes_list[@]}" -gt 0 ]] || aicr_die "--nodes-list cannot be empty"
[[ "${#num_workers_list[@]}" -gt 0 ]] || aicr_die "--num-workers-list cannot be empty"
[[ "${#batch_size_list[@]}" -gt 0 ]] || aicr_die "--batch-size-list cannot be empty"
[[ "${#prefetch_factor_list[@]}" -gt 0 ]] || aicr_die "--prefetch-factor-list cannot be empty"
[[ "${#pin_memory_list[@]}" -gt 0 ]] || aicr_die "--pin-memory-list cannot be empty"
[[ "${#persistent_workers_list[@]}" -gt 0 ]] || aicr_die "--persistent-workers-list cannot be empty"
[[ "${#cpus_per_task_list[@]}" -gt 0 ]] || aicr_die "--cpus-per-task-list cannot be empty"
validate_positive_int_list "--nodes-list" "${nodes_list[@]}"
validate_non_negative_int_list "--num-workers-list" "${num_workers_list[@]}"
validate_positive_int_list "--batch-size-list" "${batch_size_list[@]}"
validate_positive_int_list "--prefetch-factor-list" "${prefetch_factor_list[@]}"
validate_binary_list "--pin-memory-list" "${pin_memory_list[@]}"
validate_binary_list "--persistent-workers-list" "${persistent_workers_list[@]}"
validate_positive_int_list "--cpus-per-task-list" "${cpus_per_task_list[@]}"
if [[ "${#shared_args[@]}" -gt 0 ]]; then
  assert_no_sweep_arg_conflicts "${shared_args[@]}"
fi

submit_script="scripts/benchmark/submit-dataloader.sh"
submitted_count=0

echo "Dataloader sweep matrix"
echo "  Cluster        : ${cluster}"
echo "  Partition      : ${partition}"
echo "  Time limit     : ${time_limit}"
echo "  Nodes          : ${nodes_csv}"
echo "  GPU count      : ${gpu_count}"
echo "  Mode           : ${mode}"
echo "  Profile        : ${profile}"
echo "  CPUs per task  : ${cpus_per_task_list[*]}"
echo "  Repeat count   : ${repeat_count}"
if [[ -n "$nodelist" ]]; then
  echo "  Node pool      : ${nodelist}"
fi
echo "  Batch sizes    : ${batch_size_csv}"
echo "  Num workers    : ${num_workers_csv}"
echo "  Prefetch       : ${prefetch_factor_csv}"
echo "  Pin memory     : ${pin_memory_csv}"
echo "  Persistent     : ${persistent_workers_csv}"
if [[ "${#shared_args[@]}" -gt 0 ]]; then
  printf '  Shared args    : '
  printf '%q ' "${shared_args[@]}"
  echo
fi
echo

for nodes_value in "${nodes_list[@]}"; do
  case "$nodes_value" in
    1|2|4|8|16) ;;
    *) aicr_die "--nodes-list values must be 1, 2, 4, 8, or 16: ${nodes_value}" ;;
  esac
  if [[ "$cluster" == "rtxpro6000" ]]; then
    case "$nodes_value" in
      1|2|4|8) ;;
      *) aicr_die "RTX DataLoader supports nodes 1, 2, 4, or 8: ${nodes_value}" ;;
    esac
  fi
  for repeat_index in $(seq 1 "$repeat_count"); do
    point_nodelist=""
    if [[ -n "$nodelist" ]]; then
      point_nodelist="$(ordered_nodelist_prefix "$nodes_value" "$nodelist")"
    fi
    for cpus_per_task_value in "${cpus_per_task_list[@]}"; do
      for batch_size in "${batch_size_list[@]}"; do
        for num_workers in "${num_workers_list[@]}"; do
          for prefetch_factor in "${prefetch_factor_list[@]}"; do
            for pin_memory in "${pin_memory_list[@]}"; do
              for persistent_workers in "${persistent_workers_list[@]}"; do
                cmd=(bash "$submit_script" --cluster "$cluster" --profile "$profile" --nodes "$nodes_value" --gpu-count "$gpu_count" --mode "$mode" --partition "$partition" --time "$time_limit" --cpus-per-task "$cpus_per_task_value")
                if [[ -n "$point_nodelist" ]]; then
                  cmd+=(--nodelist "$point_nodelist")
                fi
                if [[ "$apply" -eq 1 ]]; then
                  cmd+=(--apply)
                fi
                cmd+=(
                  --
                  --batch-size "$batch_size"
                  --num-workers "$num_workers"
                  --prefetch-factor "$prefetch_factor"
                  --pin-memory "$pin_memory"
                  --persistent-workers "$persistent_workers"
                )
                if [[ "${#shared_args[@]}" -gt 0 ]]; then
                  cmd+=("${shared_args[@]}")
                fi

                echo "Sweep point: nodes=${nodes_value} repeat=${repeat_index}/${repeat_count} batch=${batch_size} workers=${num_workers} prefetch=${prefetch_factor} pin=${pin_memory} persistent=${persistent_workers}"
                if [[ -n "$point_nodelist" ]]; then
                  echo "  Selected nodes: ${point_nodelist}"
                fi
                "${cmd[@]}"
                if [[ "$apply" -eq 1 ]]; then
                  submitted_count=$((submitted_count + 1))
                fi
              done
            done
          done
        done
      done
    done
  done
done

if [[ "$apply" -eq 0 ]]; then
  echo
  echo "Dry run only. Pass --apply to submit the sweep."
else
  echo
  echo "Submitted ${submitted_count} dataloader sweep job(s)."
fi
