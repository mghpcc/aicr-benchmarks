#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/sweep-dataloader.sh [--cluster <b200|rtxpro6000>] [--profile <small|medium|large>] [--inspect-profile] [--nodes <csv>] [--nodes-list <csv>] [--gpu-count <1|8>] [--mode <single|replicated|distributed-sharded>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--repeat-count <n>] [--input-backend-list <csv>] [--num-workers-list <csv>] [--batch-size-list <csv>] [--prefetch-factor-list <csv>] [--dali-num-threads-list <csv>] [--dali-prefetch-queue-depth-list <csv>] [--dali-numpy-reader-prefetch-queue-depth-list <csv>] [--dali-decode-mode-list <csv>] [--dali-hw-decoder-load-list <csv>] [--pin-memory-list <csv>] [--persistent-workers-list <csv>] [--cpus-per-task <n>] [--cpus-per-task-list <csv>] [--mem <size>] [--mem-list <csv>] [--dependency <slurm-dependency>] [--partition <name>] [--time <HH:MM:SS>] [--nodelist <node[,node...]>] [--apply] [--] [runner args...]

Default behavior is a dry run: print one Slurm submission command per sweep point.
The default sweep varies --num-workers across 4,8,16,24,32 while holding the canonical dataloader config constant.
Arguments after -- are forwarded to scripts/benchmark/run-dataloader.sh for every submitted job and must not repeat sweep-owned runner flags.
Sweep points default to --mem=0 through the DataLoader submitter unless --mem or --mem-list is set.

Profiles set default batch, worker, prefetch, warmup, and measured-batch values; explicit sweep axes and runner args override them.
B200 accepts nodes 1, 2, 4, 8, or 16. RTX accepts nodes 1, 2, 4, 8, or 16.
EOF
}

dataloader_profile_values() {
  profile_batch_size=""
  profile_num_workers=""
  profile_prefetch_factor=""
  profile_warmup_batches=""
  profile_measured_batches=""
  case "$1" in
    "")
      return 0
      ;;
    small)
      profile_batch_size="512"
      profile_num_workers="16"
      profile_prefetch_factor="4"
      profile_warmup_batches="20"
      profile_measured_batches="100"
      ;;
    medium)
      profile_batch_size="512"
      profile_num_workers="16"
      profile_prefetch_factor="4"
      profile_warmup_batches="100"
      profile_measured_batches="500"
      ;;
    large)
      profile_batch_size="512"
      profile_num_workers="16"
      profile_prefetch_factor="4"
      profile_warmup_batches="200"
      profile_measured_batches="5000"
      ;;
    *)
      aicr_die "--profile must be small, medium, or large"
      ;;
  esac
}

dataloader_print_profile() {
  local profile_name="$1"
  dataloader_profile_values "$profile_name"
  echo "profile=${profile_name}"
  echo "batch_size=${profile_batch_size}"
  echo "num_workers=${profile_num_workers}"
  echo "prefetch_factor=${profile_prefetch_factor}"
  echo "warmup_batches=${profile_warmup_batches}"
  echo "measured_batches=${profile_measured_batches}"
}

default_partition() {
  case "$1" in
    b200) printf 'b200-batch\n' ;;
    rtxpro6000) printf 'rtx-batch\n' ;;
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

validate_memory_list() {
  local label="$1"
  shift
  local value
  for value in "$@"; do
    [[ -n "$value" ]] || continue
    [[ "$value" =~ ^[0-9]+([KMGTP])?$ ]] || aicr_die "${label} values must be Slurm memory values such as 0, 512G, or 1T: ${value}"
  done
}

assert_no_sweep_arg_conflicts() {
  local args=("$@")
  local index=0
  while [[ $index -lt ${#args[@]} ]]; do
    case "${args[$index]}" in
      --input-backend|--batch-size|--num-workers|--prefetch-factor|--dali-num-threads|--dali-prefetch-queue-depth|--dali-decode-mode|--dali-hw-decoder-load|--pin-memory|--persistent-workers|--cluster|--mode|--nodes|--node-count|--requested-gpu-count)
        aicr_die "Arguments after -- must not include sweep-owned runner flag: ${args[$index]}"
        ;;
    esac
    index=$((index + 1))
  done
}

aicr_require_repo_root
aicr_mkdirs

num_workers_csv="4,8,16,24,32"
batch_size_csv="256"
prefetch_factor_csv="4"
input_backend_csv="pytorch-cpu-dataloader"
dali_num_threads_csv="0"
dali_prefetch_queue_depth_csv="2"
dali_numpy_reader_prefetch_queue_depth_csv="1"
dali_decode_mode_csv="random-crop"
dali_hw_decoder_load_csv="0.65"
pin_memory_csv="1"
persistent_workers_csv="1"
nodes_csv="1"
cluster="b200"
partition=""
time_limit="01:00:00"
cpus_per_task="16"
cpus_per_task_csv=""
memory_request="${DATALOADER_MEM:-0}"
memory_request_csv=""
gpu_count="1"
mode=""
nodelist=""
from_node_report=0
date_arg="today"
repeat_count="1"
dependency=""
apply=0
profile=""
inspect_profile=0
batch_size_flag_set=0
num_workers_flag_set=0
prefetch_factor_flag_set=0
profile_batch_size=""
profile_num_workers=""
profile_prefetch_factor=""
profile_warmup_batches=""
profile_measured_batches=""
shared_args=()
cpus_per_task_flag_set=0
memory_request_flag_set=0
memory_request_csv_flag_set=0

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
    --from-node-report)
      from_node_report=1
      shift
      ;;
    --date)
      date_arg="${2:-}"
      shift 2
      ;;
    --repeat-count)
      repeat_count="${2:-}"
      shift 2
      ;;
    --dependency)
      dependency="${2:-}"
      shift 2
      ;;
    --input-backend-list)
      input_backend_csv="${2:-}"
      shift 2
      ;;
    --num-workers-list)
      num_workers_csv="${2:-}"
      num_workers_flag_set=1
      shift 2
      ;;
    --batch-size-list)
      batch_size_csv="${2:-}"
      batch_size_flag_set=1
      shift 2
      ;;
    --prefetch-factor-list)
      prefetch_factor_csv="${2:-}"
      prefetch_factor_flag_set=1
      shift 2
      ;;
    --dali-num-threads-list)
      dali_num_threads_csv="${2:-}"
      shift 2
      ;;
    --dali-prefetch-queue-depth-list)
      dali_prefetch_queue_depth_csv="${2:-}"
      shift 2
      ;;
    --dali-numpy-reader-prefetch-queue-depth-list)
      dali_numpy_reader_prefetch_queue_depth_csv="${2:-}"
      shift 2
      ;;
    --dali-decode-mode-list)
      dali_decode_mode_csv="${2:-}"
      shift 2
      ;;
    --dali-hw-decoder-load-list)
      dali_hw_decoder_load_csv="${2:-}"
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
    --mem)
      memory_request="${2:-}"
      memory_request_flag_set=1
      shift 2
      ;;
    --mem-list)
      memory_request_csv="${2:-}"
      memory_request_csv_flag_set=1
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

dataloader_profile_values "$profile"
if [[ "$inspect_profile" -eq 1 ]]; then
  [[ -n "$profile" ]] || profile="small"
  dataloader_print_profile "$profile"
  exit 0
fi
if [[ -n "$profile" ]]; then
  [[ "$batch_size_flag_set" -eq 1 ]] || batch_size_csv="$profile_batch_size"
  [[ "$num_workers_flag_set" -eq 1 ]] || num_workers_csv="$profile_num_workers"
  [[ "$prefetch_factor_flag_set" -eq 1 ]] || prefetch_factor_csv="$profile_prefetch_factor"
  if [[ "${#shared_args[@]}" -gt 0 ]]; then
    shared_args=(--warmup-batches "$profile_warmup_batches" --measured-batches "$profile_measured_batches" "${shared_args[@]}")
  else
    shared_args=(--warmup-batches "$profile_warmup_batches" --measured-batches "$profile_measured_batches")
  fi
fi

aicr_assert_supported_cluster "$cluster"
partition="${partition:-$(default_partition "$cluster")}"
[[ "$time_limit" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || aicr_die "--time must be HH:MM:SS"
[[ "$cpus_per_task" =~ ^[0-9]+$ && "$cpus_per_task" -gt 0 ]] || aicr_die "--cpus-per-task must be a positive integer"
[[ "$repeat_count" =~ ^[0-9]+$ && "$repeat_count" -gt 0 ]] || aicr_die "--repeat-count must be a positive integer"
[[ -z "$dependency" || "$dependency" =~ ^[A-Za-z0-9_,:\?\.\-]+$ ]] || aicr_die "--dependency contains unsupported characters"
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
if [[ "$memory_request_csv_flag_set" -eq 1 && "$memory_request_flag_set" -eq 1 ]]; then
  aicr_die "--mem and --mem-list cannot be used together"
fi
if [[ "$memory_request_csv_flag_set" -eq 1 && -z "$memory_request_csv" ]]; then
  aicr_die "--mem-list cannot be empty"
fi
if [[ "$from_node_report" -eq 1 && -n "$nodelist" ]]; then
  aicr_die "--from-node-report and --nodelist cannot be combined"
fi

nodes_list=()
input_backend_list=()
num_workers_list=()
batch_size_list=()
prefetch_factor_list=()
dali_num_threads_list=()
dali_prefetch_queue_depth_list=()
dali_numpy_reader_prefetch_queue_depth_list=()
dali_decode_mode_list=()
dali_hw_decoder_load_list=()
pin_memory_list=()
persistent_workers_list=()
cpus_per_task_list=()
memory_request_list=()
IFS=',' read -r -a nodes_list <<<"$nodes_csv"
IFS=',' read -r -a input_backend_list <<<"$input_backend_csv"
IFS=',' read -r -a num_workers_list <<<"$num_workers_csv"
IFS=',' read -r -a batch_size_list <<<"$batch_size_csv"
IFS=',' read -r -a prefetch_factor_list <<<"$prefetch_factor_csv"
IFS=',' read -r -a dali_num_threads_list <<<"$dali_num_threads_csv"
IFS=',' read -r -a dali_prefetch_queue_depth_list <<<"$dali_prefetch_queue_depth_csv"
IFS=',' read -r -a dali_numpy_reader_prefetch_queue_depth_list <<<"$dali_numpy_reader_prefetch_queue_depth_csv"
IFS=',' read -r -a dali_decode_mode_list <<<"$dali_decode_mode_csv"
IFS=',' read -r -a dali_hw_decoder_load_list <<<"$dali_hw_decoder_load_csv"
IFS=',' read -r -a pin_memory_list <<<"$pin_memory_csv"
IFS=',' read -r -a persistent_workers_list <<<"$persistent_workers_csv"
if [[ -n "$cpus_per_task_csv" ]]; then
  IFS=',' read -r -a cpus_per_task_list <<<"$cpus_per_task_csv"
else
  cpus_per_task_list=("$cpus_per_task")
fi
if [[ -n "$memory_request_csv" ]]; then
  IFS=',' read -r -a memory_request_list <<<"$memory_request_csv"
else
  memory_request_list=("$memory_request")
fi

[[ "${#nodes_list[@]}" -gt 0 ]] || aicr_die "--nodes-list cannot be empty"
[[ "${#input_backend_list[@]}" -gt 0 ]] || aicr_die "--input-backend-list cannot be empty"
[[ "${#num_workers_list[@]}" -gt 0 ]] || aicr_die "--num-workers-list cannot be empty"
[[ "${#batch_size_list[@]}" -gt 0 ]] || aicr_die "--batch-size-list cannot be empty"
[[ "${#prefetch_factor_list[@]}" -gt 0 ]] || aicr_die "--prefetch-factor-list cannot be empty"
[[ "${#dali_num_threads_list[@]}" -gt 0 ]] || aicr_die "--dali-num-threads-list cannot be empty"
[[ "${#dali_prefetch_queue_depth_list[@]}" -gt 0 ]] || aicr_die "--dali-prefetch-queue-depth-list cannot be empty"
[[ "${#dali_numpy_reader_prefetch_queue_depth_list[@]}" -gt 0 ]] || aicr_die "--dali-numpy-reader-prefetch-queue-depth-list cannot be empty"
[[ "${#dali_decode_mode_list[@]}" -gt 0 ]] || aicr_die "--dali-decode-mode-list cannot be empty"
[[ "${#dali_hw_decoder_load_list[@]}" -gt 0 ]] || aicr_die "--dali-hw-decoder-load-list cannot be empty"
[[ "${#pin_memory_list[@]}" -gt 0 ]] || aicr_die "--pin-memory-list cannot be empty"
[[ "${#persistent_workers_list[@]}" -gt 0 ]] || aicr_die "--persistent-workers-list cannot be empty"
[[ "${#cpus_per_task_list[@]}" -gt 0 ]] || aicr_die "--cpus-per-task-list cannot be empty"
[[ "${#memory_request_list[@]}" -gt 0 ]] || aicr_die "--mem-list cannot be empty"
validate_positive_int_list "--nodes-list" "${nodes_list[@]}"
validate_non_negative_int_list "--num-workers-list" "${num_workers_list[@]}"
validate_positive_int_list "--batch-size-list" "${batch_size_list[@]}"
validate_positive_int_list "--prefetch-factor-list" "${prefetch_factor_list[@]}"
validate_non_negative_int_list "--dali-num-threads-list" "${dali_num_threads_list[@]}"
validate_positive_int_list "--dali-prefetch-queue-depth-list" "${dali_prefetch_queue_depth_list[@]}"
validate_positive_int_list "--dali-numpy-reader-prefetch-queue-depth-list" "${dali_numpy_reader_prefetch_queue_depth_list[@]}"
for input_backend_value in "${input_backend_list[@]}"; do
  case "$input_backend_value" in
    pytorch-cpu-dataloader|dali-gpu-decode|numpy-uint8-shards|numpy-fp16-shards|numpy-fp16-blocks-pytorch|dali-numpy-fp16-cpu|dali-numpy-fp16-gds|dali-numpy-fp16-blocks-cpu|dali-numpy-fp16-blocks-gds) ;;
    *) aicr_die "--input-backend-list values must be pytorch-cpu-dataloader, dali-gpu-decode, numpy-uint8-shards, numpy-fp16-shards, numpy-fp16-blocks-pytorch, dali-numpy-fp16-cpu, dali-numpy-fp16-gds, dali-numpy-fp16-blocks-cpu, or dali-numpy-fp16-blocks-gds: ${input_backend_value}" ;;
  esac
done
for dali_decode_mode_value in "${dali_decode_mode_list[@]}"; do
  case "$dali_decode_mode_value" in
    random-crop|decode-resize) ;;
    *) aicr_die "--dali-decode-mode-list values must be random-crop or decode-resize: ${dali_decode_mode_value}" ;;
  esac
done
for dali_hw_decoder_load_value in "${dali_hw_decoder_load_list[@]}"; do
  [[ "$dali_hw_decoder_load_value" =~ ^[0-9]+([.][0-9]+)?$ ]] || aicr_die "--dali-hw-decoder-load-list values must be non-negative numbers: ${dali_hw_decoder_load_value}"
done
validate_binary_list "--pin-memory-list" "${pin_memory_list[@]}"
validate_binary_list "--persistent-workers-list" "${persistent_workers_list[@]}"
validate_positive_int_list "--cpus-per-task-list" "${cpus_per_task_list[@]}"
validate_memory_list "--mem-list" "${memory_request_list[@]}"
if [[ "${#shared_args[@]}" -gt 0 ]]; then
  assert_no_sweep_arg_conflicts "${shared_args[@]}"
fi

submit_script="scripts/benchmark/submit-dataloader.sh"
planned_count=0
submitted_count=0

echo "Dataloader sweep matrix"
echo "  Cluster        : ${cluster}"
echo "  Partition      : ${partition}"
echo "  Time limit     : ${time_limit}"
echo "  Nodes          : ${nodes_csv}"
echo "  GPU count      : ${gpu_count}"
echo "  Mode           : ${mode}"
echo "  CPUs per task  : ${cpus_per_task_list[*]}"
echo "  Memory request : ${memory_request_list[*]}"
echo "  Repeat count   : ${repeat_count}"
if [[ "$from_node_report" -eq 1 ]]; then
  echo "  Node report    : ${date_arg}"
fi
if [[ -n "$nodelist" ]]; then
  echo "  Node pin       : ${nodelist}"
fi
echo "  Batch sizes    : ${batch_size_csv}"
echo "  Input backends : ${input_backend_csv}"
echo "  Num workers    : ${num_workers_csv}"
echo "  Prefetch       : ${prefetch_factor_csv}"
echo "  DALI threads   : ${dali_num_threads_csv}"
echo "  DALI prefetch  : ${dali_prefetch_queue_depth_csv}"
echo "  DALI NumPy reader prefetch: ${dali_numpy_reader_prefetch_queue_depth_csv}"
echo "  DALI decode    : ${dali_decode_mode_csv}"
echo "  DALI hw load   : ${dali_hw_decoder_load_csv}"
echo "  Pin memory     : ${pin_memory_csv}"
echo "  Persistent     : ${persistent_workers_csv}"
if [[ -n "$dependency" ]]; then
  echo "  Dependency     : ${dependency}"
fi
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
      1|2|4|8|16) ;;
      *) aicr_die "RTX DataLoader supports nodes 1, 2, 4, 8, or 16: ${nodes_value}" ;;
    esac
  fi
  for repeat_index in $(seq 1 "$repeat_count"); do
    for cpus_per_task_value in "${cpus_per_task_list[@]}"; do
      for memory_request_value in "${memory_request_list[@]}"; do
        for input_backend in "${input_backend_list[@]}"; do
        if [[ "$input_backend" == "dali-gpu-decode" ]]; then
          active_dali_num_threads_list=("${dali_num_threads_list[@]}")
          active_dali_prefetch_queue_depth_list=("${dali_prefetch_queue_depth_list[@]}")
          active_dali_numpy_reader_prefetch_queue_depth_list=("1")
          active_dali_decode_mode_list=("${dali_decode_mode_list[@]}")
          active_dali_hw_decoder_load_list=("${dali_hw_decoder_load_list[@]}")
        elif [[ "$input_backend" == dali-numpy-* ]]; then
          active_dali_num_threads_list=("${dali_num_threads_list[@]}")
          active_dali_prefetch_queue_depth_list=("${dali_prefetch_queue_depth_list[@]}")
          active_dali_numpy_reader_prefetch_queue_depth_list=("${dali_numpy_reader_prefetch_queue_depth_list[@]}")
          active_dali_decode_mode_list=("random-crop")
          active_dali_hw_decoder_load_list=("0.65")
        else
          active_dali_num_threads_list=("0")
          active_dali_prefetch_queue_depth_list=("2")
          active_dali_numpy_reader_prefetch_queue_depth_list=("1")
          active_dali_decode_mode_list=("random-crop")
          active_dali_hw_decoder_load_list=("0.65")
        fi
        for batch_size in "${batch_size_list[@]}"; do
          for num_workers in "${num_workers_list[@]}"; do
            for prefetch_factor in "${prefetch_factor_list[@]}"; do
              for dali_num_threads in "${active_dali_num_threads_list[@]}"; do
                for dali_prefetch_queue_depth in "${active_dali_prefetch_queue_depth_list[@]}"; do
                  for dali_numpy_reader_prefetch_queue_depth in "${active_dali_numpy_reader_prefetch_queue_depth_list[@]}"; do
                    for dali_decode_mode in "${active_dali_decode_mode_list[@]}"; do
                      for dali_hw_decoder_load in "${active_dali_hw_decoder_load_list[@]}"; do
                        for pin_memory in "${pin_memory_list[@]}"; do
                          for persistent_workers in "${persistent_workers_list[@]}"; do
                          cmd=(bash "$submit_script" --cluster "$cluster" --nodes "$nodes_value" --gpu-count "$gpu_count" --mode "$mode" --partition "$partition" --time "$time_limit" --cpus-per-task "$cpus_per_task_value")
                          cmd+=(--mem "$memory_request_value")
                          if [[ "$from_node_report" -eq 1 ]]; then
                            cmd+=(--from-node-report --date "$date_arg")
                          fi
                          if [[ -n "$nodelist" ]]; then
                            cmd+=(--nodelist "$nodelist")
                          fi
                          if [[ -n "$dependency" ]]; then
                            cmd+=(--dependency "$dependency")
                          fi
                          if [[ "$apply" -eq 1 ]]; then
                            cmd+=(--apply)
                          fi
                          cmd+=(
                            --
                            --input-backend "$input_backend"
                            --batch-size "$batch_size"
                            --num-workers "$num_workers"
                            --prefetch-factor "$prefetch_factor"
                            --dali-num-threads "$dali_num_threads"
                            --dali-prefetch-queue-depth "$dali_prefetch_queue_depth"
                            --dali-numpy-reader-prefetch-queue-depth "$dali_numpy_reader_prefetch_queue_depth"
                            --dali-decode-mode "$dali_decode_mode"
                            --dali-hw-decoder-load "$dali_hw_decoder_load"
                            --pin-memory "$pin_memory"
                            --persistent-workers "$persistent_workers"
                          )
                          if [[ "${#shared_args[@]}" -gt 0 ]]; then
                            cmd+=("${shared_args[@]}")
                          fi

                          echo "Sweep point: nodes=${nodes_value} repeat=${repeat_index}/${repeat_count} backend=${input_backend} batch=${batch_size} workers=${num_workers} prefetch=${prefetch_factor} mem=${memory_request_value:-default} dali_threads=${dali_num_threads} dali_prefetch=${dali_prefetch_queue_depth} dali_numpy_reader_prefetch=${dali_numpy_reader_prefetch_queue_depth} dali_decode=${dali_decode_mode} pin=${pin_memory} persistent=${persistent_workers}"
                          planned_count=$((planned_count + 1))
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
        done
        done
        done
      done
    done
  done
done

if [[ "$apply" -eq 0 ]]; then
  echo
  echo "DataLoader sweep submission summary"
  echo "  Mode        : dry-run"
  echo "  Jobs        : ${planned_count}"
  echo "  Cluster     : ${cluster}"
  echo "  Nodes axis  : ${nodes_csv}"
  echo "  Node pool   : ${nodelist:-from submitter defaults}"
  echo "  Partition   : ${partition}"
  echo "  Memory      : ${memory_request_csv:-${memory_request}}"
  echo "Dry run only. Pass --apply to submit the sweep."
else
  echo
  echo "DataLoader sweep submission summary"
  echo "  Mode        : apply"
  echo "  Jobs        : ${submitted_count}/${planned_count}"
  echo "  Cluster     : ${cluster}"
  echo "  Nodes axis  : ${nodes_csv}"
  echo "  Node pool   : ${nodelist:-from submitter defaults}"
  echo "  Partition   : ${partition}"
  echo "  Memory      : ${memory_request_csv:-${memory_request}}"
  echo "Submitted ${submitted_count} dataloader sweep job(s)."
fi
