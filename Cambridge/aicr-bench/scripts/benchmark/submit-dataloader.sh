#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/submit-dataloader.sh [--cluster <b200|rtxpro6000>] [--profile <small|medium|large>] [--inspect-profile] [--nodes <n>] [--gpu-count <1|8>] [--mode <single|replicated|distributed-sharded>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--partition <name>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--mem <size>] [--dependency <slurm-dependency>] [--nodelist <nodes>] [--apply] [--] [runner args...]

Default behavior is a dry run: print the sbatch command that would submit the dataloader benchmark.
With --from-node-report, selects passed nodes for the selected cluster from the latest node report.
Arguments after -- are forwarded to scripts/benchmark/run-dataloader.sh inside the batch job.
Submissions default to --mem=0 so Slurm grants the job the node memory cgroup.

Profiles set workload-intensity defaults; explicit runner args after -- override them.
B200 accepts --nodes 1, 2, 4, 8, or 16. RTX accepts --nodes 1, 2, 4, 8, or 16.
EOF
}

dataloader_profile_args() {
  profile_args=()
  case "$1" in
    "")
      return 0
      ;;
    small)
      profile_args=(--batch-size 512 --num-workers 16 --prefetch-factor 4 --warmup-batches 20 --measured-batches 100)
      ;;
    medium)
      profile_args=(--batch-size 512 --num-workers 16 --prefetch-factor 4 --warmup-batches 100 --measured-batches 500)
      ;;
    large)
      profile_args=(--batch-size 512 --num-workers 16 --prefetch-factor 4 --warmup-batches 200 --measured-batches 5000)
      ;;
    *)
      aicr_die "--profile must be small, medium, or large"
      ;;
  esac
}

dataloader_print_profile() {
  local profile_name="$1"
  dataloader_profile_args "$profile_name"
  echo "profile=${profile_name}"
  echo "batch_size=${profile_args[1]}"
  echo "num_workers=${profile_args[3]}"
  echo "prefetch_factor=${profile_args[5]}"
  echo "warmup_batches=${profile_args[7]}"
  echo "measured_batches=${profile_args[9]}"
}

default_partition() {
  case "$1" in
    b200) printf 'b200-batch\n' ;;
    rtxpro6000) printf 'rtx-batch\n' ;;
    *) aicr_die "unsupported cluster: $1" ;;
  esac
}

assert_no_submit_arg_conflicts() {
  local args=("$@")
  local index=0
  while [[ $index -lt ${#args[@]} ]]; do
    case "${args[$index]}" in
      --cluster|--mode|--nodes|--node-count|--requested-gpu-count)
        aicr_die "Arguments after -- must not include submit-owned runner flag: ${args[$index]}"
        ;;
    esac
    index=$((index + 1))
  done
}

validate_slurm_memory() {
  local value="$1"
  [[ -z "$value" || "$value" =~ ^[0-9]+([KMGTP])?$ ]] || aicr_die "--mem must be a Slurm memory value such as 0, 512G, or 1T"
}

aicr_require_repo_root
aicr_mkdirs

repo_python=(aicr_python)

cluster="b200"
partition=""
time_limit="01:00:00"
cpus_per_task="16"
memory_request="${DATALOADER_MEM:-0}"
nodes="1"
gpu_count="1"
mode=""
nodelist=""
dependency=""
from_node_report=0
date_arg="today"
apply=0
profile=""
inspect_profile=0
profile_args=()
forward_args=()

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
    --inspect-profile)
      inspect_profile=1
      shift
      ;;
    --gpu-count)
      gpu_count="${2:-}"
      shift 2
      ;;
    --nodes)
      nodes="${2:-}"
      shift 2
      ;;
    --mode)
      mode="${2:-}"
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
      shift 2
      ;;
    --mem)
      memory_request="${2:-}"
      shift 2
      ;;
    --nodelist)
      nodelist="${2:-}"
      shift 2
      ;;
    --dependency)
      dependency="${2:-}"
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
    --apply)
      apply=1
      shift
      ;;
    --)
      shift
      forward_args=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      forward_args+=("$1")
      shift
      ;;
  esac
done

dataloader_profile_args "$profile"
if [[ "$inspect_profile" -eq 1 ]]; then
  [[ -n "$profile" ]] || profile="small"
  dataloader_print_profile "$profile"
  exit 0
fi

aicr_assert_supported_cluster "$cluster"
partition="${partition:-$(default_partition "$cluster")}"
[[ "$cpus_per_task" =~ ^[0-9]+$ && "$cpus_per_task" -gt 0 ]] || aicr_die "--cpus-per-task must be a positive integer"
validate_slurm_memory "$memory_request"
[[ -z "$dependency" || "$dependency" =~ ^[A-Za-z0-9_,:\?\.\-]+$ ]] || aicr_die "--dependency contains unsupported characters"
[[ "$time_limit" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || aicr_die "--time must be HH:MM:SS"
case "$nodes" in
  1|2|4|8|16) ;;
  *) aicr_die "--nodes must be 1, 2, 4, 8, or 16" ;;
esac
if [[ "$cluster" == "rtxpro6000" ]]; then
  case "$nodes" in
    1|2|4|8|16) ;;
    *) aicr_die "RTX DataLoader supports --nodes 1, 2, 4, 8, or 16" ;;
  esac
fi
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
if [[ "$nodes" != "1" ]]; then
  [[ "$gpu_count" == "8" ]] || aicr_die "--nodes ${nodes} requires --gpu-count 8"
  [[ "$mode" == "distributed-sharded" ]] || aicr_die "--nodes ${nodes} supports only --mode distributed-sharded"
fi
if [[ "${#forward_args[@]}" -gt 0 ]]; then
  assert_no_submit_arg_conflicts "${forward_args[@]}"
fi
if [[ "$from_node_report" -eq 1 ]]; then
  [[ -z "$nodelist" ]] || aicr_die "--from-node-report and --nodelist cannot be combined"
  nodelist="$("${repo_python[@]}" "${BENCHMARK_DIR}/select-benchmark-nodes.py" --date "$date_arg" --cluster "$cluster" --count "$nodes" --format csv)"
fi

requested_gpu_count="$gpu_count"
if [[ "$nodes" != "1" ]]; then
  requested_gpu_count="$((nodes * gpu_count))"
fi

rtx_wrapper_prefix="slurm/benchmark/rtxpro6000-dataloader"

case "${cluster}:${nodes}:${gpu_count}" in
  b200:1:1) sbatch_script="slurm/benchmark/b200-dataloader-1n-1g.sbatch" ;;
  b200:1:8) sbatch_script="slurm/benchmark/b200-dataloader-1n-8g.sbatch" ;;
  b200:*:8) sbatch_script="slurm/benchmark/b200-dataloader-mn-8g.sbatch" ;;
  rtxpro6000:1:1) sbatch_script="slurm/benchmark/rtxpro6000-dataloader-1n-1g.sbatch" ;;
  rtxpro6000:1:8) sbatch_script="${rtx_wrapper_prefix}-1n-8g.sbatch" ;;
  rtxpro6000:*:8) sbatch_script="${rtx_wrapper_prefix}-mn-8g.sbatch" ;;
  *) aicr_die "unsupported DataLoader submission shape: cluster=${cluster} nodes=${nodes} gpu_count=${gpu_count}" ;;
esac
sbatch_cmd=(sbatch --parsable --partition="$partition" --time="$time_limit" --nodes="$nodes" --cpus-per-task="$cpus_per_task" --mem="$memory_request")
if [[ -n "$nodelist" ]]; then
  sbatch_cmd+=(--nodelist="$nodelist")
fi
if [[ -n "$dependency" ]]; then
  sbatch_cmd+=(--dependency="$dependency")
fi
sbatch_cmd+=("$sbatch_script")
sbatch_cmd+=(--cluster "$cluster" --mode "$mode" --nodes "$nodes" --requested-gpu-count "$requested_gpu_count")
if [[ "${#profile_args[@]}" -gt 0 ]]; then
  sbatch_cmd+=("${profile_args[@]}")
fi
if [[ "${#forward_args[@]}" -gt 0 ]]; then
  sbatch_cmd+=("${forward_args[@]}")
fi

echo "DataLoader submission summary"
echo "  Mode        : $([[ "$apply" -eq 1 ]] && echo apply || echo dry-run)"
echo "  Jobs        : 1"
echo "  Cluster     : ${cluster}"
echo "  Nodes       : ${nodes}"
echo "  GPUs/node   : ${gpu_count}"
echo "  Partition   : ${partition}"
echo "  CPUs/task   : ${cpus_per_task}"
echo "  Memory      : ${memory_request}"
if [[ -n "$nodelist" ]]; then
  echo "  Node list   : ${nodelist}"
fi
echo

if [[ "$apply" -eq 0 ]]; then
  echo "Dry run. Command that would be submitted:"
  printf '  '
  printf '%q ' "${sbatch_cmd[@]}"
  echo
  exit 0
fi

job_id="$("${sbatch_cmd[@]}")"
echo "Submitted dataloader benchmark job ${job_id}"
