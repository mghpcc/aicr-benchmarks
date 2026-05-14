#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTERNAL_CLUSTER_NAME="${AICR_CLUSTER_NAME:-}"
EXTERNAL_IMAGENET_DIR="${AICR_IMAGENET_DIR:-}"
EXTERNAL_DATALOADER_IMAGE="${DATALOADER_IMAGE:-}"
EXTERNAL_PYTORCH_IMAGE="${PYTORCH_IMAGE:-}"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/run-dataloader.sh [--cluster <b200|rtxpro6000>] [--profile <small|medium|large>] [--inspect-profile] [--nodes <n>] [--mode <single|replicated|distributed-sharded>] [--requested-gpu-count <n>] [--dataset-root <path>] [--split <train|val>] [--image <path>] [--gpu <index>] [--batch-size <n>] [--num-workers <n>] [--prefetch-factor <n>] [--pin-memory <0|1>] [--persistent-workers <0|1>] [--warmup-batches <n>] [--measured-batches <n>] [--h2d <0|1>] [--transfer-labels <0|1>] [--drop-last <0|1>] [--byte-estimate-sample-count <n>]

This runnable v1 harness records canonical raw/parsed benchmark artifacts under results/by-date/ and results/by-node/.
Profiles control workload intensity defaults only. Explicit environment variables
and command-line flags override profile defaults.

B200 accepts --nodes 1, 2, 4, 8, or 16. RTX accepts --nodes 1, 2, 4, or 8.
EOF
}

aicr_require_repo_root
aicr_mkdirs

count_cuda_visible_devices() {
  local value="${CUDA_VISIBLE_DEVICES:-}"
  local normalized
  local devices=()
  local count=0
  local device

  [[ -n "$value" ]] || return 0
  case "$value" in
    NoDevFiles|none|void)
      printf '0\n'
      return 0
      ;;
  esac

  normalized="${value//[[:space:]]/}"
  [[ -n "$normalized" ]] || return 0
  IFS=',' read -r -a devices <<<"$normalized"
  for device in "${devices[@]}"; do
    [[ -n "$device" ]] || continue
    count=$((count + 1))
  done
  printf '%s\n' "$count"
}

profile_value() {
  local selected="$1"
  local field="$2"
  case "${selected}:${field}" in
    small:batch_size) printf '512\n' ;;
    small:num_workers) printf '16\n' ;;
    small:prefetch_factor) printf '4\n' ;;
    small:pin_memory) printf '1\n' ;;
    small:persistent_workers) printf '1\n' ;;
    small:warmup_batches) printf '20\n' ;;
    small:measured_batches) printf '100\n' ;;
    small:h2d) printf '1\n' ;;
    small:transfer_labels) printf '1\n' ;;
    small:drop_last) printf '0\n' ;;
    small:byte_estimate_sample_count) printf '1024\n' ;;
    medium:batch_size) printf '512\n' ;;
    medium:num_workers) printf '16\n' ;;
    medium:prefetch_factor) printf '4\n' ;;
    medium:pin_memory) printf '1\n' ;;
    medium:persistent_workers) printf '1\n' ;;
    medium:warmup_batches) printf '100\n' ;;
    medium:measured_batches) printf '500\n' ;;
    medium:h2d) printf '1\n' ;;
    medium:transfer_labels) printf '1\n' ;;
    medium:drop_last) printf '0\n' ;;
    medium:byte_estimate_sample_count) printf '1024\n' ;;
    large:batch_size) printf '512\n' ;;
    large:num_workers) printf '16\n' ;;
    large:prefetch_factor) printf '4\n' ;;
    large:pin_memory) printf '1\n' ;;
    large:persistent_workers) printf '1\n' ;;
    large:warmup_batches) printf '200\n' ;;
    large:measured_batches) printf '5000\n' ;;
    large:h2d) printf '1\n' ;;
    large:transfer_labels) printf '1\n' ;;
    large:drop_last) printf '0\n' ;;
    large:byte_estimate_sample_count) printf '1024\n' ;;
    *) aicr_die "unsupported DataLoader profile field: ${selected}:${field}" ;;
  esac
}

print_profile() {
  local selected="$1"
  printf 'profile=%s\n' "${selected}"
  printf 'batch_size=%s\n' "$(profile_value "${selected}" batch_size)"
  printf 'num_workers=%s\n' "$(profile_value "${selected}" num_workers)"
  printf 'prefetch_factor=%s\n' "$(profile_value "${selected}" prefetch_factor)"
  printf 'pin_memory=%s\n' "$(profile_value "${selected}" pin_memory)"
  printf 'persistent_workers=%s\n' "$(profile_value "${selected}" persistent_workers)"
  printf 'warmup_batches=%s\n' "$(profile_value "${selected}" warmup_batches)"
  printf 'measured_batches=%s\n' "$(profile_value "${selected}" measured_batches)"
  printf 'h2d=%s\n' "$(profile_value "${selected}" h2d)"
  printf 'transfer_labels=%s\n' "$(profile_value "${selected}" transfer_labels)"
  printf 'drop_last=%s\n' "$(profile_value "${selected}" drop_last)"
  printf 'byte_estimate_sample_count=%s\n' "$(profile_value "${selected}" byte_estimate_sample_count)"
}

profile="${PROFILE:-small}"
inspect_profile=0
scan_args=("$@")
scan_index=0
while [[ $scan_index -lt ${#scan_args[@]} ]]; do
  case "${scan_args[$scan_index]}" in
    --profile)
      profile="${scan_args[$((scan_index + 1))]:-}"
      scan_index=$((scan_index + 2))
      ;;
    --profile=*)
      profile="${scan_args[$scan_index]#--profile=}"
      scan_index=$((scan_index + 1))
      ;;
    --inspect-profile)
      inspect_profile=1
      scan_index=$((scan_index + 1))
      ;;
    --)
      break
      ;;
    *)
      scan_index=$((scan_index + 1))
      ;;
  esac
done
case "$profile" in
  small|medium|large) ;;
  *) aicr_die "--profile must be small, medium, or large" ;;
esac
if [[ "$inspect_profile" == "1" ]]; then
  print_profile "$profile"
  exit 0
fi

cluster="${EXTERNAL_CLUSTER_NAME:-${AICR_CLUSTER_NAME:-$(aicr_cluster_name)}}"
dataset_root="${EXTERNAL_IMAGENET_DIR:-${AICR_IMAGENET_DIR}}"
dataset_split="${DATALOADER_SPLIT:-train}"
image="${EXTERNAL_DATALOADER_IMAGE:-${DATALOADER_IMAGE:-${EXTERNAL_PYTORCH_IMAGE:-${PYTORCH_IMAGE:-${AICR_APPTAINER_IMAGE_DIR}/pytorch-25.10-py3.sif}}}}"
selected_gpu="${DATALOADER_GPU:-0}"
mode="${DATALOADER_MODE:-single}"
node_count="${DATALOADER_NODE_COUNT:-${SLURM_NNODES:-1}}"
requested_gpu_count="${DATALOADER_REQUESTED_GPU_COUNT:-}"
batch_size="${DATALOADER_BATCH_SIZE:-$(profile_value "$profile" batch_size)}"
num_workers="${DATALOADER_NUM_WORKERS:-$(profile_value "$profile" num_workers)}"
prefetch_factor="${DATALOADER_PREFETCH_FACTOR:-$(profile_value "$profile" prefetch_factor)}"
pin_memory="${DATALOADER_PIN_MEMORY:-$(profile_value "$profile" pin_memory)}"
persistent_workers="${DATALOADER_PERSISTENT_WORKERS:-$(profile_value "$profile" persistent_workers)}"
warmup_batches="${DATALOADER_WARMUP_BATCHES:-$(profile_value "$profile" warmup_batches)}"
measured_batches="${DATALOADER_MEASURED_BATCHES:-$(profile_value "$profile" measured_batches)}"
h2d="${DATALOADER_H2D:-$(profile_value "$profile" h2d)}"
transfer_labels="${DATALOADER_TRANSFER_LABELS:-$(profile_value "$profile" transfer_labels)}"
drop_last="${DATALOADER_DROP_LAST:-$(profile_value "$profile" drop_last)}"
byte_estimate_sample_count="${DATALOADER_BYTE_ESTIMATE_SAMPLE_COUNT:-$(profile_value "$profile" byte_estimate_sample_count)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --profile=*)
      profile="${1#--profile=}"
      shift
      ;;
    --inspect-profile)
      shift
      ;;
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --nodes|--node-count)
      node_count="${2:-}"
      shift 2
      ;;
    --requested-gpu-count)
      requested_gpu_count="${2:-}"
      shift 2
      ;;
    --dataset-root)
      dataset_root="${2:-}"
      shift 2
      ;;
    --split)
      dataset_split="${2:-}"
      shift 2
      ;;
    --image)
      image="${2:-}"
      shift 2
      ;;
    --gpu)
      selected_gpu="${2:-}"
      shift 2
      ;;
    --batch-size)
      batch_size="${2:-}"
      shift 2
      ;;
    --num-workers)
      num_workers="${2:-}"
      shift 2
      ;;
    --prefetch-factor)
      prefetch_factor="${2:-}"
      shift 2
      ;;
    --pin-memory)
      pin_memory="${2:-}"
      shift 2
      ;;
    --persistent-workers)
      persistent_workers="${2:-}"
      shift 2
      ;;
    --warmup-batches)
      warmup_batches="${2:-}"
      shift 2
      ;;
    --measured-batches)
      measured_batches="${2:-}"
      shift 2
      ;;
    --h2d)
      h2d="${2:-}"
      shift 2
      ;;
    --transfer-labels)
      transfer_labels="${2:-}"
      shift 2
      ;;
    --drop-last)
      drop_last="${2:-}"
      shift 2
      ;;
    --byte-estimate-sample-count)
      byte_estimate_sample_count="${2:-}"
      shift 2
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

aicr_assert_supported_cluster "$cluster"
case "$node_count" in
  1|2|4|8|16) ;;
  *) aicr_die "--nodes must be 1, 2, 4, 8, or 16" ;;
esac
if [[ "$cluster" == "rtxpro6000" ]]; then
  case "$node_count" in
    1|2|4|8) ;;
    *) aicr_die "RTX DataLoader supports --nodes 1, 2, 4, or 8" ;;
  esac
fi
case "$mode" in
  single)
    requested_gpu_count="${requested_gpu_count:-1}"
    ;;
  replicated|distributed-sharded)
    if [[ "$node_count" == "1" ]]; then
      requested_gpu_count="${requested_gpu_count:-8}"
    else
      requested_gpu_count="${requested_gpu_count:-$((node_count * 8))}"
    fi
    ;;
  *)
    aicr_die "--mode must be single, replicated, or distributed-sharded"
    ;;
esac

[[ "$dataset_split" == "train" || "$dataset_split" == "val" ]] || aicr_die "--split must be train or val"
[[ "$requested_gpu_count" =~ ^[0-9]+$ && "$requested_gpu_count" -gt 0 ]] || aicr_die "--requested-gpu-count must be a positive integer"
if [[ "$mode" == "single" && "$requested_gpu_count" != "1" ]]; then
  aicr_die "--mode single requires --requested-gpu-count 1"
fi
if [[ "$node_count" == "1" && "$mode" != "single" && "$requested_gpu_count" != "8" ]]; then
  aicr_die "--mode ${mode} currently supports only --requested-gpu-count 8"
fi
if [[ "$node_count" != "1" ]]; then
  [[ "$mode" == "distributed-sharded" ]] || aicr_die "--nodes ${node_count} supports only --mode distributed-sharded"
  [[ "$requested_gpu_count" == "$((node_count * 8))" ]] || aicr_die "--nodes ${node_count} requires --requested-gpu-count $((node_count * 8))"
fi
[[ "$batch_size" =~ ^[0-9]+$ && "$batch_size" -gt 0 ]] || aicr_die "--batch-size must be a positive integer"
[[ "$num_workers" =~ ^[0-9]+$ && "$num_workers" -ge 0 ]] || aicr_die "--num-workers must be a non-negative integer"
[[ "$prefetch_factor" =~ ^[0-9]+$ && "$prefetch_factor" -gt 0 ]] || aicr_die "--prefetch-factor must be a positive integer"
[[ "$pin_memory" == "0" || "$pin_memory" == "1" ]] || aicr_die "--pin-memory must be 0 or 1"
[[ "$persistent_workers" == "0" || "$persistent_workers" == "1" ]] || aicr_die "--persistent-workers must be 0 or 1"
[[ "$warmup_batches" =~ ^[0-9]+$ && "$warmup_batches" -ge 0 ]] || aicr_die "--warmup-batches must be a non-negative integer"
[[ "$measured_batches" =~ ^[0-9]+$ && "$measured_batches" -gt 0 ]] || aicr_die "--measured-batches must be a positive integer"
[[ "$h2d" == "0" || "$h2d" == "1" ]] || aicr_die "--h2d must be 0 or 1"
[[ "$transfer_labels" == "0" || "$transfer_labels" == "1" ]] || aicr_die "--transfer-labels must be 0 or 1"
[[ "$drop_last" == "0" || "$drop_last" == "1" ]] || aicr_die "--drop-last must be 0 or 1"
[[ "$byte_estimate_sample_count" =~ ^[0-9]+$ ]] || aicr_die "--byte-estimate-sample-count must be a non-negative integer"
[[ "$selected_gpu" =~ ^[0-9]+$ ]] || aicr_die "--gpu must be a non-negative integer"

date_utc="$(aicr_today_date)"
node_short="$(hostname -s 2>/dev/null || hostname)"
peer_nodes_csv="$(scontrol show hostnames "${SLURM_JOB_NODELIST:-}" 2>/dev/null | paste -sd, - || true)"
if [[ -z "$peer_nodes_csv" ]]; then
  peer_nodes_csv="$node_short"
fi
launcher="local"
scope="$AICR_SCOPE_NODE"
validation_mode="$AICR_MODE_BENCHMARK_SINGLE_NODE"
if [[ "$mode" != "single" ]]; then
  launcher="srun"
fi
if [[ "$node_count" != "1" ]]; then
  scope="$AICR_SCOPE_MULTI_NODE"
  validation_mode="benchmark-dataloader-multi-node"
fi
if [[ "$scope" == "$AICR_SCOPE_MULTI_NODE" ]]; then
  run_id="${DATALOADER_RUN_ID:-$(aicr_next_by_date_run_id "$date_utc" "$cluster" "$AICR_SCOPE_MULTI_NODE" "$AICR_CHECK_DATALOADER")}"
  raw_rel="$(aicr_multi_node_raw_run_dir "$date_utc" "$cluster" "$AICR_CHECK_DATALOADER" "$run_id")"
  parsed_rel="$(aicr_multi_node_parsed_run_dir "$date_utc" "$cluster" "$AICR_CHECK_DATALOADER" "$run_id")"
  record_rel="$(aicr_multi_node_record_path "$date_utc" "$cluster" "$AICR_CHECK_DATALOADER" "$run_id")"
else
  run_id="${DATALOADER_RUN_ID:-$(aicr_next_by_date_run_id "$date_utc" "$cluster" "$AICR_SCOPE_NODE" "$AICR_CHECK_DATALOADER" "$node_short")}"
  raw_rel="$(aicr_node_raw_run_dir "$date_utc" "$cluster" "$node_short" "$AICR_CHECK_DATALOADER" "$run_id")"
  parsed_rel="$(aicr_node_parsed_run_dir "$date_utc" "$cluster" "$node_short" "$AICR_CHECK_DATALOADER" "$run_id")"
  record_rel="$(aicr_node_record_path "$date_utc" "$cluster" "$node_short" "$AICR_CHECK_DATALOADER" "$run_id")"
fi
mkdir -p \
  "${AICR_BMARK_DIR}/${raw_rel}/canonical" \
  "${AICR_BMARK_DIR}/${raw_rel}/wrapper" \
  "${AICR_BMARK_DIR}/${raw_rel}/metadata" \
  "${AICR_BMARK_DIR}/${parsed_rel}"

job_id="${SLURM_JOB_ID:-}"
partition="${SLURM_JOB_PARTITION:-${SLURM_PARTITION:-}}"
cpus_per_task="${SLURM_CPUS_PER_TASK:-}"
if [[ -z "$cpus_per_task" && "$mode" != "single" ]]; then
  cpus_per_task="16"
fi
submitted_at="$(aicr_timestamp_utc)"
wrapper_out_rel="${raw_rel}/wrapper/slurm-${job_id:-manual}.out"
wrapper_err_rel="${raw_rel}/wrapper/slurm-${job_id:-manual}.err"
: > "${AICR_BMARK_DIR}/${wrapper_out_rel}"
: > "${AICR_BMARK_DIR}/${wrapper_err_rel}"

summary_rel="${raw_rel}/canonical/dataloader-summary.txt"
env_rel="${raw_rel}/canonical/dataloader-env.txt"
cmd_rel="${raw_rel}/canonical/dataloader-command.sh"
stdout_rel="${raw_rel}/canonical/dataloader-stdout.txt"
stderr_rel="${raw_rel}/canonical/dataloader-stderr.txt"
metrics_rel="${raw_rel}/canonical/dataloader-metrics.json"
inventory_rel="${raw_rel}/canonical/nvidia-smi-L.txt"
rank_table_rel="${raw_rel}/canonical/rank-metrics.tsv"
summary_json_rel="${parsed_rel}/summary.json"
status_json_rel="${parsed_rel}/status.json"

summary_abs="${AICR_BMARK_DIR}/${summary_rel}"
env_abs="${AICR_BMARK_DIR}/${env_rel}"
cmd_abs="${AICR_BMARK_DIR}/${cmd_rel}"
stdout_abs="${AICR_BMARK_DIR}/${stdout_rel}"
stderr_abs="${AICR_BMARK_DIR}/${stderr_rel}"
metrics_abs="${AICR_BMARK_DIR}/${metrics_rel}"
inventory_abs="${AICR_BMARK_DIR}/${inventory_rel}"
rank_table_abs="${AICR_BMARK_DIR}/${rank_table_rel}"
summary_json_abs="${AICR_BMARK_DIR}/${summary_json_rel}"
status_json_abs="${AICR_BMARK_DIR}/${status_json_rel}"
record_abs="${AICR_BMARK_DIR}/${record_rel}"
workload_script_abs="${BENCHMARK_DIR}/run-dataloader-workload.py"
: >"${rank_table_abs}"
if aicr_have_cmd nvidia-smi; then
  nvidia-smi -L >"${inventory_abs}" 2>&1 || true
else
  printf 'nvidia-smi not found\n' >"${inventory_abs}"
fi
gpu_count="$(grep -c '^GPU ' "${inventory_abs}" 2>/dev/null || true)"
[[ "$gpu_count" =~ ^[0-9]+$ ]] || gpu_count=0
gpu_preflight_count="$gpu_count"
gpu_preflight_count_source="nvidia-smi -L"
cuda_visible_count="$(count_cuda_visible_devices)"
if [[ -n "${CUDA_VISIBLE_DEVICES:-}" ]]; then
  gpu_preflight_count="${cuda_visible_count:-0}"
  [[ "$gpu_preflight_count" =~ ^[0-9]+$ ]] || gpu_preflight_count=0
  gpu_preflight_count_source="CUDA_VISIBLE_DEVICES"
fi
gpu_name="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)"
expected_visible_gpu_count="$requested_gpu_count"
if [[ "$node_count" != "1" ]]; then
  expected_visible_gpu_count="8"
fi
gpu_preflight_status="Pass"
gpu_preflight_note=""
if [[ "$cluster" == "$AICR_CLUSTER_RTXPRO6000" ]]; then
  if [[ "$gpu_preflight_count" != "$expected_visible_gpu_count" ]]; then
    gpu_preflight_status="Fail"
    gpu_preflight_note="$(aicr_gpu_presence_note "$gpu_preflight_count" "$expected_visible_gpu_count") via ${gpu_preflight_count_source}"
  fi
elif [[ "$gpu_count" -lt "$expected_visible_gpu_count" ]]; then
  gpu_preflight_status="Fail"
  gpu_preflight_note="requested ${expected_visible_gpu_count} GPU(s), but only ${gpu_count} visible"
fi
single_cuda_visible_devices="${CUDA_VISIBLE_DEVICES:-$selected_gpu}"

cat >"${env_abs}" <<EOF_ENV
cluster=${cluster}
profile=${profile}
host=${node_short}
run_id=${run_id}
scope=${scope}
launcher=${launcher}
node_count=${node_count}
node_list=${peer_nodes_csv}
world_size=${requested_gpu_count}
image=${image}
dataset_root=${dataset_root}
dataset_split=${dataset_split}
selected_gpu=${selected_gpu}
mode=${mode}
requested_gpu_count=${requested_gpu_count}
batch_size=${batch_size}
num_workers=${num_workers}
prefetch_factor=${prefetch_factor}
pin_memory=${pin_memory}
persistent_workers=${persistent_workers}
warmup_batches=${warmup_batches}
measured_batches=${measured_batches}
h2d=${h2d}
transfer_labels=${transfer_labels}
drop_last=${drop_last}
cpus_per_task=${cpus_per_task}
byte_estimate_sample_count=${byte_estimate_sample_count}
gpu_count=${gpu_count}
expected_visible_gpu_count=${expected_visible_gpu_count}
gpu_preflight_count=${gpu_preflight_count}
gpu_preflight_count_source=${gpu_preflight_count_source}
gpu_preflight_status=${gpu_preflight_status}
gpu_name=${gpu_name}
cuda_visible_devices=${CUDA_VISIBLE_DEVICES:-}
slurm_job_gpus=${SLURM_JOB_GPUS:-}
EOF_ENV

if [[ "${mode}" == "single" ]]; then
  {
    # shellcheck disable=SC2086
    printf '%q ' apptainer exec ${AICR_APPTAINER_COMMON_OPTS} --nv "${image}" env CUDA_VISIBLE_DEVICES="${single_cuda_visible_devices}" python3 "${workload_script_abs}" --dataset-root "${dataset_root}" --split "${dataset_split}" --batch-size "${batch_size}" --num-workers "${num_workers}" --prefetch-factor "${prefetch_factor}" --pin-memory "${pin_memory}" --persistent-workers "${persistent_workers}" --warmup-batches "${warmup_batches}" --measured-batches "${measured_batches}" --selected-gpu "${selected_gpu}" --sampler-mode "${mode}" --rank 0 --world-size 1 --local-rank "${selected_gpu}" --node-rank 0 --local-gpu-index "${selected_gpu}" --node-list "${peer_nodes_csv}" --node-count "${node_count}" --launcher "${launcher}" --h2d "${h2d}" --transfer-labels "${transfer_labels}" --drop-last "${drop_last}" --byte-estimate-sample-count "${byte_estimate_sample_count}" --output "${metrics_abs}"
    echo
  } >"${cmd_abs}"
else
  read -r -a apptainer_common_opts <<<"${AICR_APPTAINER_COMMON_OPTS}"
  launch_cmd=(
    srun --mpi=pmix --nodes "$node_count" --ntasks "$requested_gpu_count" --ntasks-per-node 8 --cpus-per-task "$cpus_per_task"
    apptainer exec "${apptainer_common_opts[@]}" --nv "$image"
    env AICR_DATE_UTC="$date_utc" AICR_CLUSTER_NAME="$cluster"
    python3 "$workload_script_abs"
      --dataset-root "$dataset_root"
      --split "$dataset_split"
      --batch-size "$batch_size"
      --num-workers "$num_workers"
      --prefetch-factor "$prefetch_factor"
      --pin-memory "$pin_memory"
      --persistent-workers "$persistent_workers"
      --warmup-batches "$warmup_batches"
      --measured-batches "$measured_batches"
      --sampler-mode "$mode"
      --world-size "$requested_gpu_count"
      --node-list "$peer_nodes_csv"
      --node-count "$node_count"
      --launcher "$launcher"
      --h2d "$h2d"
      --transfer-labels "$transfer_labels"
      --drop-last "$drop_last"
      --byte-estimate-sample-count "$byte_estimate_sample_count"
      --output-dir "${AICR_BMARK_DIR}/${raw_rel}/canonical/ranks"
  )
  {
    printf '%q ' "${launch_cmd[@]}"
    echo
  } >"${cmd_abs}"
fi

status="passed"
notes=()
dataset_split_root="${dataset_root}/${dataset_split}"
runner_rc=0

if [[ ! -d "${dataset_root}" ]]; then
  status="failed"
  notes+=("dataset root not found: ${dataset_root}")
elif [[ ! -d "${dataset_root}/train" ]]; then
  status="failed"
  notes+=("missing train split under dataset root")
elif [[ ! -d "${dataset_root}/val" ]]; then
  status="failed"
  notes+=("missing val split under dataset root")
elif [[ ! -d "${dataset_split_root}" ]]; then
  status="failed"
  notes+=("missing requested split directory: ${dataset_split_root}")
elif [[ ! -f "${image}" ]]; then
  status="failed"
  notes+=("image not found: ${image}")
elif [[ ! -f "${workload_script_abs}" ]]; then
  status="failed"
  notes+=("workload script not found: ${workload_script_abs}")
elif ! command -v apptainer >/dev/null 2>&1; then
  status="failed"
  notes+=("apptainer not available")
elif [[ "${gpu_count}" -lt 1 ]]; then
  status="failed"
  notes+=("no visible GPUs detected")
elif [[ "${gpu_preflight_status}" == "Fail" ]]; then
  status="failed"
  notes+=("${gpu_preflight_note}")
fi

if [[ "${status}" == "passed" ]]; then
  if [[ "${mode}" == "single" ]]; then
    set +e
    # shellcheck disable=SC2086
    apptainer exec ${AICR_APPTAINER_COMMON_OPTS} --nv "${image}" \
      env CUDA_VISIBLE_DEVICES="${single_cuda_visible_devices}" \
      python3 "${workload_script_abs}" \
        --dataset-root "${dataset_root}" \
        --split "${dataset_split}" \
        --batch-size "${batch_size}" \
        --num-workers "${num_workers}" \
        --prefetch-factor "${prefetch_factor}" \
        --pin-memory "${pin_memory}" \
        --persistent-workers "${persistent_workers}" \
        --warmup-batches "${warmup_batches}" \
        --measured-batches "${measured_batches}" \
        --selected-gpu "${selected_gpu}" \
        --sampler-mode "${mode}" \
        --rank 0 \
        --world-size 1 \
        --local-rank "${selected_gpu}" \
        --node-rank 0 \
        --local-gpu-index "${selected_gpu}" \
        --node-list "${peer_nodes_csv}" \
        --node-count "${node_count}" \
        --launcher "${launcher}" \
        --h2d "${h2d}" \
        --transfer-labels "${transfer_labels}" \
        --drop-last "${drop_last}" \
        --byte-estimate-sample-count "${byte_estimate_sample_count}" \
        --output "${metrics_abs}" \
        >"${stdout_abs}" 2>"${stderr_abs}"
    runner_rc=$?
    set -e
    if [[ "${runner_rc}" -ne 0 ]]; then
      status="failed"
      notes+=("benchmark command failed")
    fi
  else
    mkdir -p "${AICR_BMARK_DIR}/${raw_rel}/canonical/ranks"
    set +e
    "${launch_cmd[@]}" >"${stdout_abs}" 2>"${stderr_abs}"
    runner_rc=$?
    set -e
    if [[ "${runner_rc}" -ne 0 ]]; then
      complete_rank_metrics=1
      for rank in $(seq 0 "$((requested_gpu_count - 1))"); do
        rank_metrics_rel="${raw_rel}/canonical/ranks/rank-${rank}/dataloader-metrics.json"
        if [[ ! -f "${AICR_BMARK_DIR}/${rank_metrics_rel}" ]]; then
          complete_rank_metrics=0
          break
        fi
      done
      if [[ "${complete_rank_metrics}" == "1" ]]; then
        notes+=("multi-rank launcher returned ${runner_rc} after all rank metrics were written; treating launcher status as warning")
        runner_rc=0
      else
        status="failed"
        notes+=("multi-rank dataloader launcher failed")
      fi
    fi
    for rank in $(seq 0 "$((requested_gpu_count - 1))"); do
      rank_dir_rel="${raw_rel}/canonical/ranks/rank-${rank}"
      rank_dir_abs="${AICR_BMARK_DIR}/${rank_dir_rel}"
      mkdir -p "${rank_dir_abs}"
      rank_metrics_rel="${rank_dir_rel}/dataloader-metrics.json"
      rank_stdout_rel="${rank_dir_rel}/dataloader-stdout.txt"
      rank_stderr_rel="${rank_dir_rel}/dataloader-stderr.txt"
      : >"${AICR_BMARK_DIR}/${rank_stdout_rel}"
      : >"${AICR_BMARK_DIR}/${rank_stderr_rel}"
      rank_rc=0
      if [[ ! -f "${AICR_BMARK_DIR}/${rank_metrics_rel}" ]]; then
        rank_rc=1
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' \
        "$rank" \
        "${rank_metrics_rel}" \
        "${rank_stdout_rel}" \
        "${rank_stderr_rel}" \
        "$rank_rc" >>"${rank_table_abs}"
    done
  fi
else
  : >"${stdout_abs}"
  printf '%s\n' "${notes[@]}" >"${stderr_abs}"
fi

summary_payload="$(
  aicr_python - "${metrics_abs}" "${rank_table_abs}" "${AICR_BMARK_DIR}" "${mode}" "${requested_gpu_count}" "${node_count}" "${peer_nodes_csv}" "${launcher}" "${scope}" "${h2d}" "${transfer_labels}" "${drop_last}" "${status}" "$(aicr_join_csv "${notes[@]}")" "${runner_rc}" "${cluster}" "${date_utc}" "${run_id}" "${node_short}" "${job_id}" "${image}" "${dataset_root}" "${dataset_split}" "${selected_gpu}" "${gpu_count}" "${expected_visible_gpu_count}" "${gpu_preflight_count}" "${gpu_preflight_count_source}" "${gpu_preflight_status}" "${inventory_rel}" "${gpu_name}" "${batch_size}" "${num_workers}" "${prefetch_factor}" "${pin_memory}" "${persistent_workers}" "${warmup_batches}" "${measured_batches}" "${cpus_per_task}" "${byte_estimate_sample_count}" <<'PY'
import json
import sys
from pathlib import Path

(
    metrics_path,
    rank_table_path,
    repo_root,
    mode,
    requested_gpu_count,
    node_count,
    node_list,
    launcher,
    scope,
    h2d,
    transfer_labels,
    drop_last,
    initial_status,
    initial_notes_csv,
    runner_rc,
    cluster,
    date_utc,
    run_id,
    host,
    job_id,
    image,
    dataset_root,
    dataset_split,
    selected_gpu,
    gpu_count,
    expected_visible_gpu_count,
    gpu_preflight_count,
    gpu_preflight_count_source,
    gpu_preflight_status,
    gpu_inventory_rel,
    gpu_name,
    batch_size,
    num_workers,
    prefetch_factor,
    pin_memory,
    persistent_workers,
    warmup_batches,
    measured_batches,
    cpus_per_task,
    byte_estimate_sample_count,
) = sys.argv[1:]

status = initial_status
notes = [item for item in initial_notes_csv.split(",") if item]
metrics = {}
metrics_file = Path(metrics_path)
repo = Path(repo_root)
rank_table_file = Path(rank_table_path)
per_rank = []
estimated_read_bytes = None
estimated_vast_read_gb_per_second = None
dataset_byte_estimate_sample_count = None
dataset_byte_estimate_missing_sample_count = None
dataset_average_sample_bytes = None
dataset_estimated_total_bytes = None
worker_cpu_utilization_sample_count = None
worker_cpu_utilization_mean_percent = None
worker_cpu_utilization_max_percent = None
worker_cpu_utilization_total_percent = None


def mean(values):
    values = [value for value in values if value is not None]
    return sum(values) / len(values) if values else None


def sum_if_any(values):
    values = [value for value in values if value is not None]
    return sum(values) if values else None

if int(runner_rc) != 0:
    status = "failed"

if mode == "single":
    if metrics_file.exists():
        try:
            metrics = json.loads(metrics_file.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            status = "failed"
            notes.append(f"invalid metrics JSON: {exc}")
    else:
        if initial_status == "passed" and int(runner_rc) == 0:
            status = "failed"
            notes.append("benchmark metrics file was not created")

    metric_status = metrics.get("status")
    metric_notes = metrics.get("notes") or ""
    if metric_status and metric_status != "passed":
        status = "failed"
    if metric_notes:
        notes.append(metric_notes)

    samples_per_second = metrics.get("samples_per_second")
    if status == "passed" and samples_per_second is None:
        status = "failed"
        notes.append("samples_per_second missing from metrics")

    samples_total = metrics.get("samples_total")
    elapsed_seconds = metrics.get("elapsed_seconds")
    load_elapsed_seconds = metrics.get("load_elapsed_seconds")
    h2d_elapsed_seconds = metrics.get("h2d_elapsed_seconds")
    aggregate_samples_per_second = samples_per_second
    aggregate_load_samples_per_second = metrics.get("load_samples_per_second")
    aggregate_h2d_samples_per_second = metrics.get("h2d_samples_per_second")
    estimated_read_bytes = metrics.get("estimated_read_bytes")
    estimated_vast_read_gb_per_second = metrics.get("estimated_vast_read_gb_per_second")
    dataset_byte_estimate_sample_count = metrics.get("dataset_byte_estimate_sample_count")
    dataset_byte_estimate_missing_sample_count = metrics.get("dataset_byte_estimate_missing_sample_count")
    dataset_average_sample_bytes = metrics.get("dataset_average_sample_bytes")
    dataset_estimated_total_bytes = metrics.get("dataset_estimated_total_bytes")
    worker_cpu_utilization_sample_count = metrics.get("worker_cpu_utilization_sample_count")
    worker_cpu_utilization_mean_percent = metrics.get("worker_cpu_utilization_mean_percent")
    worker_cpu_utilization_max_percent = metrics.get("worker_cpu_utilization_max_percent")
    worker_cpu_utilization_total_percent = metrics.get("worker_cpu_utilization_total_percent")
    dataset_split_root = metrics.get("dataset_split_root") or f"{dataset_root}/{dataset_split}"
    dataset_size = metrics.get("dataset_size")
    class_count = metrics.get("class_count")
    effective_prefetch_factor = metrics.get("prefetch_factor")
    if effective_prefetch_factor is None:
        effective_prefetch_factor = int(prefetch_factor)
    effective_persistent_workers = metrics.get("persistent_workers")
    if effective_persistent_workers is None:
        effective_persistent_workers = persistent_workers == "1"
    shuffle = metrics.get("shuffle", dataset_split == "train")
    cuda_available = metrics.get("cuda_available")
    visible_gpu_count = metrics.get("visible_gpu_count")
    torch_version = metrics.get("torch_version")
    torchvision_version = metrics.get("torchvision_version")
    python_version = metrics.get("python_version")
    transform_pipeline = metrics.get("transform_pipeline") or []
    sampler_mode = metrics.get("sampler_mode", mode)
    h2d_enabled = metrics.get("h2d_enabled")
else:
    if not rank_table_file.exists():
        status = "failed"
        notes.append("rank metrics table was not created")
    else:
        for line in rank_table_file.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            rank, metrics_rel, stdout_rel, stderr_rel, rc_text = line.split("\t")
            rank_metrics = {}
            rank_status = "passed" if rc_text == "0" else "failed"
            rank_notes = []
            rank_metrics_path = repo / metrics_rel
            if rank_metrics_path.exists():
                try:
                    rank_metrics = json.loads(rank_metrics_path.read_text(encoding="utf-8"))
                except json.JSONDecodeError as exc:
                    rank_status = "failed"
                    rank_notes.append(f"invalid metrics JSON: {exc}")
            else:
                rank_status = "failed"
                rank_notes.append("metrics file was not created")
            if rank_metrics.get("status") and rank_metrics.get("status") != "passed":
                rank_status = "failed"
            if rank_metrics.get("notes"):
                rank_notes.append(str(rank_metrics.get("notes")))
            if rank_status == "passed" and rank_metrics.get("samples_per_second") is None:
                rank_status = "failed"
                rank_notes.append("samples_per_second missing from metrics")
            per_rank.append({
                "rank": int(rank),
                "selected_gpu": rank_metrics.get("selected_gpu", rank),
                "logical_gpu_index": rank_metrics.get("logical_gpu_index"),
                "local_rank": rank_metrics.get("local_rank"),
                "node_rank": rank_metrics.get("node_rank"),
                "local_gpu_index": rank_metrics.get("local_gpu_index"),
                "status": rank_status,
                "return_code": int(rc_text),
                "metrics_path": metrics_rel,
                "stdout_path": stdout_rel,
                "stderr_path": stderr_rel,
                "samples_total": rank_metrics.get("samples_total"),
                "elapsed_seconds": rank_metrics.get("elapsed_seconds"),
                "load_elapsed_seconds": rank_metrics.get("load_elapsed_seconds"),
                "h2d_elapsed_seconds": rank_metrics.get("h2d_elapsed_seconds"),
                "samples_per_second": rank_metrics.get("samples_per_second"),
                "load_samples_per_second": rank_metrics.get("load_samples_per_second"),
                "h2d_samples_per_second": rank_metrics.get("h2d_samples_per_second"),
                "estimated_read_bytes": rank_metrics.get("estimated_read_bytes"),
                "estimated_vast_read_gb_per_second": rank_metrics.get("estimated_vast_read_gb_per_second"),
                "dataset_byte_estimate_sample_count": rank_metrics.get("dataset_byte_estimate_sample_count"),
                "dataset_byte_estimate_missing_sample_count": rank_metrics.get("dataset_byte_estimate_missing_sample_count"),
                "dataset_average_sample_bytes": rank_metrics.get("dataset_average_sample_bytes"),
                "dataset_estimated_total_bytes": rank_metrics.get("dataset_estimated_total_bytes"),
                "worker_cpu_utilization_sample_count": rank_metrics.get("worker_cpu_utilization_sample_count"),
                "worker_cpu_utilization_mean_percent": rank_metrics.get("worker_cpu_utilization_mean_percent"),
                "worker_cpu_utilization_max_percent": rank_metrics.get("worker_cpu_utilization_max_percent"),
                "worker_cpu_utilization_total_percent": rank_metrics.get("worker_cpu_utilization_total_percent"),
                "sampler_mode": rank_metrics.get("sampler_mode", mode),
                "sampler_length": rank_metrics.get("sampler_length"),
                "dataset_size": rank_metrics.get("dataset_size"),
                "class_count": rank_metrics.get("class_count"),
                "visible_gpu_count": rank_metrics.get("visible_gpu_count"),
                "h2d_enabled": rank_metrics.get("h2d_enabled"),
                "notes": "; ".join(note for note in rank_notes if note),
            })
    if len(per_rank) != int(requested_gpu_count):
        status = "failed"
        notes.append(f"expected {requested_gpu_count} rank results, found {len(per_rank)}")
    if any(item["status"] != "passed" for item in per_rank):
        status = "failed"
    samples_total = sum(item["samples_total"] or 0 for item in per_rank)
    elapsed_values = [item["elapsed_seconds"] for item in per_rank if item["elapsed_seconds"] is not None]
    elapsed_seconds = max(elapsed_values) if elapsed_values else None
    load_elapsed_values = [item["load_elapsed_seconds"] for item in per_rank if item["load_elapsed_seconds"] is not None]
    load_elapsed_seconds = max(load_elapsed_values) if load_elapsed_values else None
    h2d_elapsed_values = [item["h2d_elapsed_seconds"] for item in per_rank if item["h2d_elapsed_seconds"] is not None]
    h2d_elapsed_seconds = max(h2d_elapsed_values) if h2d_elapsed_values else None
    sps_values = [item["samples_per_second"] for item in per_rank if item["samples_per_second"] is not None]
    aggregate_samples_per_second = sum(sps_values) if len(sps_values) == len(per_rank) and per_rank else None
    load_sps_values = [item["load_samples_per_second"] for item in per_rank if item["load_samples_per_second"] is not None]
    aggregate_load_samples_per_second = sum(load_sps_values) if len(load_sps_values) == len(per_rank) and per_rank else None
    h2d_sps_values = [item["h2d_samples_per_second"] for item in per_rank if item["h2d_samples_per_second"] is not None]
    aggregate_h2d_samples_per_second = sum(h2d_sps_values) if len(h2d_sps_values) == len(per_rank) and per_rank else None
    estimated_read_bytes = sum_if_any(item.get("estimated_read_bytes") for item in per_rank)
    if estimated_read_bytes is not None and elapsed_seconds and elapsed_seconds > 0:
        estimated_vast_read_gb_per_second = estimated_read_bytes / elapsed_seconds / 1_000_000_000
    else:
        estimated_vast_read_gb_per_second = None
    dataset_byte_estimate_sample_count = sum_if_any(item.get("dataset_byte_estimate_sample_count") for item in per_rank)
    dataset_byte_estimate_missing_sample_count = sum_if_any(item.get("dataset_byte_estimate_missing_sample_count") for item in per_rank)
    dataset_average_sample_bytes = mean(item.get("dataset_average_sample_bytes") for item in per_rank)
    dataset_estimated_total_bytes = mean(item.get("dataset_estimated_total_bytes") for item in per_rank)
    worker_cpu_utilization_sample_count = sum_if_any(item.get("worker_cpu_utilization_sample_count") for item in per_rank)
    worker_cpu_utilization_mean_percent = mean(item.get("worker_cpu_utilization_mean_percent") for item in per_rank)
    worker_cpu_utilization_max_values = [
        item.get("worker_cpu_utilization_max_percent")
        for item in per_rank
        if item.get("worker_cpu_utilization_max_percent") is not None
    ]
    worker_cpu_utilization_max_percent = max(worker_cpu_utilization_max_values) if worker_cpu_utilization_max_values else None
    worker_cpu_utilization_total_percent = sum_if_any(item.get("worker_cpu_utilization_total_percent") for item in per_rank)
    if status == "passed" and aggregate_samples_per_second is None:
        status = "failed"
        notes.append("aggregate_samples_per_second missing from rank metrics")
    first_metrics = {}
    if per_rank:
        first_metrics_path = repo / per_rank[0]["metrics_path"]
        if first_metrics_path.exists():
            try:
                first_metrics = json.loads(first_metrics_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                first_metrics = {}
    dataset_split_root = first_metrics.get("dataset_split_root") or f"{dataset_root}/{dataset_split}"
    dataset_size = first_metrics.get("dataset_size")
    class_count = first_metrics.get("class_count")
    effective_prefetch_factor = first_metrics.get("prefetch_factor")
    if effective_prefetch_factor is None:
        effective_prefetch_factor = int(prefetch_factor)
    effective_persistent_workers = first_metrics.get("persistent_workers")
    if effective_persistent_workers is None:
        effective_persistent_workers = persistent_workers == "1"
    shuffle = first_metrics.get("shuffle", dataset_split == "train")
    cuda_available = any(bool(item.get("visible_gpu_count")) for item in per_rank)
    visible_gpu_count = int(requested_gpu_count)
    torch_version = first_metrics.get("torch_version")
    torchvision_version = first_metrics.get("torchvision_version")
    python_version = first_metrics.get("python_version")
    transform_pipeline = first_metrics.get("transform_pipeline") or []
    sampler_mode = first_metrics.get("sampler_mode", mode)
    h2d_enabled = any(bool(item.get("h2d_enabled")) for item in per_rank)

    metrics_file.write_text(json.dumps({
        "status": status,
        "notes": "; ".join(note for note in notes if note),
        "mode": mode,
        "scope": scope,
        "launcher": launcher,
        "node_count": int(node_count),
        "node_list": node_list,
        "world_size": int(requested_gpu_count),
        "requested_gpu_count": int(requested_gpu_count),
        "rank_count": len(per_rank),
        "samples_total": samples_total,
        "elapsed_seconds": elapsed_seconds,
        "load_elapsed_seconds": load_elapsed_seconds,
        "h2d_elapsed_seconds": h2d_elapsed_seconds,
        "samples_per_second": aggregate_samples_per_second,
        "aggregate_samples_per_second": aggregate_samples_per_second,
        "aggregate_load_samples_per_second": aggregate_load_samples_per_second,
        "aggregate_h2d_samples_per_second": aggregate_h2d_samples_per_second,
        "estimated_read_bytes": estimated_read_bytes,
        "estimated_vast_read_gb_per_second": estimated_vast_read_gb_per_second,
        "worker_cpu_utilization_mean_percent": worker_cpu_utilization_mean_percent,
    }, indent=2) + "\n", encoding="utf-8")

rank_sps_values = [item.get("samples_per_second") for item in per_rank if item.get("samples_per_second") is not None]
rank_sps_values = sorted(rank_sps_values)
rank_min_samples_per_second = rank_sps_values[0] if rank_sps_values else None
rank_max_samples_per_second = rank_sps_values[-1] if rank_sps_values else None
rank_median_samples_per_second = None
if rank_sps_values:
    mid = len(rank_sps_values) // 2
    if len(rank_sps_values) % 2:
        rank_median_samples_per_second = rank_sps_values[mid]
    else:
        rank_median_samples_per_second = (rank_sps_values[mid - 1] + rank_sps_values[mid]) / 2
rank_imbalance_ratio = None
if rank_min_samples_per_second and rank_max_samples_per_second is not None:
    rank_imbalance_ratio = rank_max_samples_per_second / rank_min_samples_per_second
rank_imbalance_percent = (rank_imbalance_ratio - 1) * 100 if rank_imbalance_ratio is not None else None

payload = {
    "status": status,
    "host": host,
    "cluster": cluster,
    "date": date_utc,
    "run_id": run_id,
    "job_id": job_id or None,
    "scope": scope,
    "launcher": launcher,
    "node_count": int(node_count),
    "node_list": node_list,
    "world_size": int(requested_gpu_count),
    "image": image,
    "selected_gpu": selected_gpu,
    "gpu_count": int(gpu_count or 0),
    "expected_visible_gpu_count": int(expected_visible_gpu_count or 0),
    "gpu_preflight_count": int(gpu_preflight_count or 0),
    "gpu_preflight_count_source": gpu_preflight_count_source,
    "gpu_preflight_status": gpu_preflight_status,
    "gpu_inventory_path": gpu_inventory_rel,
    "gpu_name": gpu_name,
    "mode": mode,
    "sampler_mode": sampler_mode,
    "requested_gpu_count": int(requested_gpu_count),
    "rank_count": len(per_rank) if mode != "single" else 1,
    "dataset_root": dataset_root,
    "dataset_split": dataset_split,
    "dataset_split_root": dataset_split_root,
    "dataset_size": dataset_size,
    "class_count": class_count,
    "batch_size": int(batch_size),
    "num_workers": int(num_workers),
    "prefetch_factor": effective_prefetch_factor,
    "pin_memory": pin_memory == "1",
    "persistent_workers": effective_persistent_workers,
    "warmup_batches": int(warmup_batches),
    "measured_batches": int(measured_batches),
    "h2d_requested": h2d == "1",
    "h2d_enabled": h2d_enabled,
    "transfer_labels": transfer_labels == "1",
    "drop_last": drop_last == "1",
    "cpus_per_task": int(cpus_per_task) if cpus_per_task else None,
    "byte_estimate_sample_count": int(byte_estimate_sample_count),
    "samples_total": samples_total,
    "elapsed_seconds": elapsed_seconds,
    "load_elapsed_seconds": load_elapsed_seconds,
    "h2d_elapsed_seconds": h2d_elapsed_seconds,
    "samples_per_second": aggregate_samples_per_second,
    "aggregate_samples_per_second": aggregate_samples_per_second,
    "aggregate_load_samples_per_second": aggregate_load_samples_per_second,
    "aggregate_h2d_samples_per_second": aggregate_h2d_samples_per_second,
    "dataset_byte_estimate_sample_count": dataset_byte_estimate_sample_count,
    "dataset_byte_estimate_missing_sample_count": dataset_byte_estimate_missing_sample_count,
    "dataset_average_sample_bytes": dataset_average_sample_bytes,
    "dataset_estimated_total_bytes": dataset_estimated_total_bytes,
    "estimated_read_bytes": estimated_read_bytes,
    "estimated_vast_read_gb_per_second": estimated_vast_read_gb_per_second,
    "worker_cpu_utilization_sample_count": worker_cpu_utilization_sample_count,
    "worker_cpu_utilization_mean_percent": worker_cpu_utilization_mean_percent,
    "worker_cpu_utilization_max_percent": worker_cpu_utilization_max_percent,
    "worker_cpu_utilization_total_percent": worker_cpu_utilization_total_percent,
    "rank_min_samples_per_second": rank_min_samples_per_second,
    "rank_median_samples_per_second": rank_median_samples_per_second,
    "rank_max_samples_per_second": rank_max_samples_per_second,
    "rank_imbalance_ratio": rank_imbalance_ratio,
    "rank_imbalance_percent": rank_imbalance_percent,
    "per_rank": per_rank,
    "shuffle": shuffle,
    "cuda_available": cuda_available,
    "visible_gpu_count": visible_gpu_count,
    "torch_version": torch_version,
    "torchvision_version": torchvision_version,
    "python_version": python_version,
    "transform_pipeline": transform_pipeline,
    "notes": "; ".join(note for note in notes if note),
}
print(json.dumps(payload, indent=2))
PY
)"

status="$(printf '%s\n' "${summary_payload}" | aicr_python -c 'import json,sys; print(json.load(sys.stdin)["status"])')"
notes_str="$(printf '%s\n' "${summary_payload}" | aicr_python -c 'import json,sys; print(json.load(sys.stdin).get("notes", ""))')"
canonical_artifacts=("${summary_rel}" "${env_rel}" "${cmd_rel}" "${stdout_rel}" "${stderr_rel}" "${metrics_rel}" "${inventory_rel}" "${rank_table_rel}")
if [[ "${mode}" != "single" ]]; then
  while IFS=$'\t' read -r _rank rank_metrics_rel rank_stdout_rel rank_stderr_rel _rank_rc; do
    [[ -n "${rank_metrics_rel}" ]] || continue
    canonical_artifacts+=("${rank_metrics_rel}" "${rank_stdout_rel}" "${rank_stderr_rel}")
  done <"${rank_table_abs}"
fi

aicr_write_summary_status_pair "${summary_json_abs}" "${status_json_abs}" "${summary_payload}" "${status}" "parsed.summary.status"
aicr_python - "${summary_json_abs}" "${summary_abs}" <<'PY'
import json
import sys
from pathlib import Path

summary = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
lines = [
    f"status={summary['status']}",
    f"host={summary['host']}",
    f"cluster={summary['cluster']}",
    f"date={summary['date']}",
    f"run_id={summary['run_id']}",
    f"job_id={summary.get('job_id') or ''}",
    f"scope={summary.get('scope', '')}",
    f"launcher={summary.get('launcher', '')}",
    f"node_count={summary.get('node_count', '')}",
    f"node_list={summary.get('node_list', '')}",
    f"world_size={summary.get('world_size', '')}",
    f"image={summary['image']}",
    f"selected_gpu={summary['selected_gpu']}",
    f"gpu_count={summary['gpu_count']}",
    f"expected_visible_gpu_count={summary.get('expected_visible_gpu_count', '')}",
    f"gpu_preflight_count={summary.get('gpu_preflight_count', '')}",
    f"gpu_preflight_count_source={summary.get('gpu_preflight_count_source', '')}",
    f"gpu_preflight_status={summary.get('gpu_preflight_status', '')}",
    f"gpu_inventory_path={summary.get('gpu_inventory_path', '')}",
    f"gpu_name={summary.get('gpu_name', '')}",
    f"mode={summary.get('mode', '')}",
    f"sampler_mode={summary.get('sampler_mode', '')}",
    f"requested_gpu_count={summary.get('requested_gpu_count', '')}",
    f"rank_count={summary.get('rank_count', '')}",
    f"dataset_root={summary['dataset_root']}",
    f"dataset_split={summary['dataset_split']}",
    f"dataset_split_root={summary['dataset_split_root']}",
    f"batch_size={summary['batch_size']}",
    f"num_workers={summary['num_workers']}",
    f"prefetch_factor={summary['prefetch_factor']}",
    f"pin_memory={summary['pin_memory']}",
    f"persistent_workers={summary['persistent_workers']}",
    f"warmup_batches={summary['warmup_batches']}",
    f"measured_batches={summary['measured_batches']}",
    f"h2d_requested={summary.get('h2d_requested', '')}",
    f"h2d_enabled={summary.get('h2d_enabled', '')}",
    f"transfer_labels={summary.get('transfer_labels', '')}",
    f"drop_last={summary.get('drop_last', '')}",
    f"cpus_per_task={summary.get('cpus_per_task', '')}",
    f"byte_estimate_sample_count={summary.get('byte_estimate_sample_count', '')}",
    f"samples_total={summary.get('samples_total', '')}",
    f"elapsed_seconds={summary.get('elapsed_seconds', '')}",
    f"load_elapsed_seconds={summary.get('load_elapsed_seconds', '')}",
    f"h2d_elapsed_seconds={summary.get('h2d_elapsed_seconds', '')}",
    f"samples_per_second={summary.get('samples_per_second', '')}",
    f"aggregate_samples_per_second={summary.get('aggregate_samples_per_second', '')}",
    f"aggregate_load_samples_per_second={summary.get('aggregate_load_samples_per_second', '')}",
    f"aggregate_h2d_samples_per_second={summary.get('aggregate_h2d_samples_per_second', '')}",
    f"estimated_read_bytes={summary.get('estimated_read_bytes', '')}",
    f"estimated_vast_read_gb_per_second={summary.get('estimated_vast_read_gb_per_second', '')}",
    f"worker_cpu_utilization_mean_percent={summary.get('worker_cpu_utilization_mean_percent', '')}",
    f"worker_cpu_utilization_max_percent={summary.get('worker_cpu_utilization_max_percent', '')}",
    f"worker_cpu_utilization_total_percent={summary.get('worker_cpu_utilization_total_percent', '')}",
    f"rank_min_samples_per_second={summary.get('rank_min_samples_per_second', '')}",
    f"rank_median_samples_per_second={summary.get('rank_median_samples_per_second', '')}",
    f"rank_max_samples_per_second={summary.get('rank_max_samples_per_second', '')}",
    f"rank_imbalance_percent={summary.get('rank_imbalance_percent', '')}",
    f"notes={summary.get('notes', '')}",
]
Path(sys.argv[2]).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

aicr_emit_record_from_args \
  "${record_abs}" \
  "${scope}" \
  "${cluster}" \
  "$([[ "${scope}" == "${AICR_SCOPE_NODE}" ]] && printf '%s' "${node_short}")" \
  "$([[ "${scope}" == "${AICR_SCOPE_MULTI_NODE}" ]] && printf '%s' "${peer_nodes_csv}")" \
  "${AICR_CHECK_DATALOADER}" \
  "${validation_mode}" \
  "${run_id}" \
  "${date_utc}" \
  "${submitted_at}" \
  "$(aicr_timestamp_utc)" \
  "${partition}" \
  "${job_id}" \
  "${status}" \
  "parsed.summary.status" \
  "${node_count}" \
  "${requested_gpu_count}" \
  "$(aicr_join_csv "${canonical_artifacts[@]}")" \
  "$(aicr_join_csv "${summary_json_rel}" "${status_json_rel}")" \
  "$(aicr_join_csv "${wrapper_out_rel}" "${wrapper_err_rel}")" \
  "${notes_str}"

aicr_append_index_row_from_record "${AICR_BMARK_DIR}/$(aicr_by_date_index_path "${date_utc}")" "${record_abs}"
if [[ "${scope}" == "${AICR_SCOPE_NODE}" ]]; then
  aicr_append_index_row_from_record "${AICR_BMARK_DIR}/$(aicr_by_node_history_path "${cluster}" "${node_short}")" "${record_abs}"
fi

echo "DataLoader benchmark status: ${status}"
echo "Record: ${record_rel}"
echo "Summary: ${summary_rel}"

[[ "${status}" == "passed" ]]
