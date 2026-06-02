#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTERNAL_CLUSTER_NAME="${AICR_CLUSTER_NAME:-}"
EXTERNAL_IMAGENET_DIR="${AICR_IMAGENET_DIR:-}"
EXTERNAL_DDP_IMAGE="${DDP_IMAGE:-}"
EXTERNAL_PYTORCH_IMAGE="${PYTORCH_IMAGE:-}"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/run-ddp-resnet50.sh [--launcher <torchrun|srun>] [--dataset-root <path>] [--split <train|val>] [--image <path>] [--input-backend <pytorch-cpu-dataloader|dali-gpu-decode|numpy-uint8-shards|numpy-fp16-shards|numpy-fp16-blocks-pytorch|dali-numpy-fp16-blocks-gds|synthetic-gpu>] [--derived-root <path>] [--derived-image-size <n>] [--derived-samples-per-class <n>] [--derived-seed <n>] [--batch-size <n>] [--num-workers <n>] [--prefetch-factor <n>] [--dali-num-threads <n>] [--dali-prefetch-queue-depth <n>] [--dali-numpy-reader-prefetch-queue-depth <n>] [--dali-decode-mode <random-crop|decode-resize>] [--dali-hw-decoder-load <float>] [--dali-gds-chunk-size <value>] [--numpy-block-cache-size <n>] [--cufile-log-path <path>] [--cufile-log-level <level>] [--synthetic-class-count <n>] [--synthetic-image-size <n>] [--synthetic-dtype <float32|float16|bfloat16>] [--pin-memory <0|1>] [--persistent-workers <0|1>] [--warmup-iters <n>] [--measured-iters <n>] [--precision <bf16|fp32>] [--channels-last <0|1>] [--drop-last <0|1>]

Runs fixed-iteration torchvision ResNet-50 DDP over ImageNet and writes canonical multi-node benchmark artifacts.

For launcher diagnostics, the srun path accepts:
  DDP_SRUN_MPI=<pmix|...>
  DDP_SRUN_CPU_BIND=<none|cores|...>
  DDP_SRUN_MEM_BIND=<none|local|...>
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

assert_derived_jpeg_dataset_root() {
  local dataset_root_norm="${dataset_root%/}"
  local derived_root_norm="${derived_root%/}"
  local subset
  local expected_direct
  local expected_global

  [[ "$derived_jpeg_identity_requested" == "1" ]] || return 0
  [[ -n "$derived_root_norm" ]] || return 0
  case "$input_backend" in
    pytorch-cpu-dataloader|dali-gpu-decode) ;;
    *) return 0 ;;
  esac

  subset="spc-${derived_samples_per_class}-seed-${derived_seed}"
  expected_direct="${derived_root_norm}/size-${derived_image_size}/jpeg"
  expected_global=""
  if [[ "${derived_root_norm##*/}" != "$subset" ]]; then
    expected_global="${derived_root_norm}/imagenet/${dataset_split}/${subset}/size-${derived_image_size}/jpeg"
  fi
  if [[ "$dataset_root_norm" == "$expected_direct" || "$dataset_root_norm" == "$expected_global" ]]; then
    return 0
  fi
  if [[ "$dataset_root_norm" == "$derived_root_norm" && "$derived_root_norm" == */"size-${derived_image_size}/jpeg" ]]; then
    return 0
  fi

  if [[ -n "$expected_global" ]]; then
    aicr_die "derived JPEG metadata requires --dataset-root to point at size-${derived_image_size}/jpeg for JPEG backends; got dataset_root=${dataset_root_norm}, expected ${expected_direct} or ${expected_global}"
  fi
  aicr_die "derived JPEG metadata requires --dataset-root to point at size-${derived_image_size}/jpeg for JPEG backends; got dataset_root=${dataset_root_norm}, expected ${expected_direct}"
}

cluster="${EXTERNAL_CLUSTER_NAME:-${AICR_CLUSTER_NAME:-$(aicr_cluster_name)}}"

launcher="${DDP_LAUNCHER:-torchrun}"
dataset_root="${EXTERNAL_IMAGENET_DIR:-${AICR_IMAGENET_DIR:-}}"
dataset_split="${DDP_SPLIT:-train}"
image="${EXTERNAL_DDP_IMAGE:-${DDP_IMAGE:-${EXTERNAL_PYTORCH_IMAGE:-${PYTORCH_IMAGE:-${AICR_APPTAINER_IMAGE_DIR}/pytorch-25.10-py3.sif}}}}"
input_backend="${DDP_INPUT_BACKEND:-pytorch-cpu-dataloader}"
derived_root="${DDP_DERIVED_ROOT:-${AICR_DATALOADER_DERIVED_ROOT:-}}"
derived_image_size="${DDP_DERIVED_IMAGE_SIZE:-224}"
derived_samples_per_class="${DDP_DERIVED_SAMPLES_PER_CLASS:-16}"
derived_seed="${DDP_DERIVED_SEED:-1234}"
batch_size="${DDP_BATCH_SIZE:-256}"
num_workers="${DDP_NUM_WORKERS:-16}"
prefetch_factor="${DDP_PREFETCH_FACTOR:-4}"
dali_num_threads="${DDP_DALI_NUM_THREADS:-0}"
dali_prefetch_queue_depth="${DDP_DALI_PREFETCH_QUEUE_DEPTH:-2}"
dali_numpy_reader_prefetch_queue_depth="${DDP_DALI_NUMPY_READER_PREFETCH_QUEUE_DEPTH:-1}"
dali_decode_mode="${DDP_DALI_DECODE_MODE:-random-crop}"
dali_hw_decoder_load="${DDP_DALI_HW_DECODER_LOAD:-0.65}"
dali_gds_chunk_size="${DDP_DALI_GDS_CHUNK_SIZE:-}"
numpy_block_cache_size="${DDP_NUMPY_BLOCK_CACHE_SIZE:-1}"
cufile_log_path="${DDP_CUFILE_LOG_PATH:-}"
cufile_log_level="${DDP_CUFILE_LOG_LEVEL:-INFO}"
synthetic_class_count="${DDP_SYNTHETIC_CLASS_COUNT:-1000}"
synthetic_image_size="${DDP_SYNTHETIC_IMAGE_SIZE:-224}"
synthetic_dtype="${DDP_SYNTHETIC_DTYPE:-float32}"
pin_memory="${DDP_PIN_MEMORY:-1}"
persistent_workers="${DDP_PERSISTENT_WORKERS:-1}"
warmup_iters="${DDP_WARMUP_ITERS:-20}"
measured_iters="${DDP_MEASURED_ITERS:-100}"
precision="${DDP_PRECISION:-bf16}"
channels_last="${DDP_CHANNELS_LAST:-1}"
drop_last="${DDP_DROP_LAST:-1}"
srun_mpi="${DDP_SRUN_MPI:-pmix}"
srun_cpu_bind="${DDP_SRUN_CPU_BIND:-}"
srun_mem_bind="${DDP_SRUN_MEM_BIND:-}"
derived_jpeg_identity_requested=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --launcher) launcher="${2:-}"; shift 2 ;;
    --dataset-root) dataset_root="${2:-}"; shift 2 ;;
    --split) dataset_split="${2:-}"; shift 2 ;;
    --image) image="${2:-}"; shift 2 ;;
    --input-backend) input_backend="${2:-}"; shift 2 ;;
    --derived-root) derived_root="${2:-}"; derived_jpeg_identity_requested=1; shift 2 ;;
    --derived-image-size) derived_image_size="${2:-}"; derived_jpeg_identity_requested=1; shift 2 ;;
    --derived-samples-per-class) derived_samples_per_class="${2:-}"; shift 2 ;;
    --derived-seed) derived_seed="${2:-}"; shift 2 ;;
    --batch-size) batch_size="${2:-}"; shift 2 ;;
    --num-workers) num_workers="${2:-}"; shift 2 ;;
    --prefetch-factor) prefetch_factor="${2:-}"; shift 2 ;;
    --dali-num-threads) dali_num_threads="${2:-}"; shift 2 ;;
    --dali-prefetch-queue-depth) dali_prefetch_queue_depth="${2:-}"; shift 2 ;;
    --dali-numpy-reader-prefetch-queue-depth) dali_numpy_reader_prefetch_queue_depth="${2:-}"; shift 2 ;;
    --dali-decode-mode) dali_decode_mode="${2:-}"; shift 2 ;;
    --dali-hw-decoder-load) dali_hw_decoder_load="${2:-}"; shift 2 ;;
    --dali-gds-chunk-size) dali_gds_chunk_size="${2:-}"; shift 2 ;;
    --numpy-block-cache-size) numpy_block_cache_size="${2:-}"; shift 2 ;;
    --cufile-log-path) cufile_log_path="${2:-}"; shift 2 ;;
    --cufile-log-level) cufile_log_level="${2:-}"; shift 2 ;;
    --synthetic-class-count) synthetic_class_count="${2:-}"; shift 2 ;;
    --synthetic-image-size) synthetic_image_size="${2:-}"; shift 2 ;;
    --synthetic-dtype) synthetic_dtype="${2:-}"; shift 2 ;;
    --pin-memory) pin_memory="${2:-}"; shift 2 ;;
    --persistent-workers) persistent_workers="${2:-}"; shift 2 ;;
    --warmup-iters) warmup_iters="${2:-}"; shift 2 ;;
    --measured-iters) measured_iters="${2:-}"; shift 2 ;;
    --precision) precision="${2:-}"; shift 2 ;;
    --channels-last) channels_last="${2:-}"; shift 2 ;;
    --drop-last) drop_last="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) aicr_die "Unknown argument: $1" ;;
  esac
done

aicr_assert_supported_cluster "$cluster"
case "$launcher" in torchrun|srun) ;; *) aicr_die "--launcher must be torchrun or srun" ;; esac
[[ "$dataset_split" == "train" || "$dataset_split" == "val" ]] || aicr_die "--split must be train or val"
case "$input_backend" in pytorch-cpu-dataloader|dali-gpu-decode|numpy-uint8-shards|numpy-fp16-shards|numpy-fp16-blocks-pytorch|dali-numpy-fp16-blocks-gds|synthetic-gpu) ;; *) aicr_die "--input-backend must be pytorch-cpu-dataloader, dali-gpu-decode, numpy-uint8-shards, numpy-fp16-shards, numpy-fp16-blocks-pytorch, dali-numpy-fp16-blocks-gds, or synthetic-gpu" ;; esac
case "$input_backend" in
  numpy-uint8-shards|numpy-fp16-shards|numpy-fp16-blocks-pytorch|dali-numpy-fp16-blocks-gds)
    [[ -n "$derived_root" ]] || aicr_die "derived input backends require --derived-root or AICR_DATALOADER_DERIVED_ROOT"
    ;;
esac
[[ "$derived_image_size" =~ ^[0-9]+$ && "$derived_image_size" -gt 0 ]] || aicr_die "--derived-image-size must be a positive integer"
[[ "$derived_samples_per_class" =~ ^[0-9]+$ && "$derived_samples_per_class" -gt 0 ]] || aicr_die "--derived-samples-per-class must be a positive integer"
[[ "$derived_seed" =~ ^[0-9]+$ ]] || aicr_die "--derived-seed must be a non-negative integer"
[[ "$batch_size" =~ ^[0-9]+$ && "$batch_size" -gt 0 ]] || aicr_die "--batch-size must be a positive integer"
[[ "$num_workers" =~ ^[0-9]+$ && "$num_workers" -ge 0 ]] || aicr_die "--num-workers must be a non-negative integer"
[[ "$prefetch_factor" =~ ^[0-9]+$ && "$prefetch_factor" -gt 0 ]] || aicr_die "--prefetch-factor must be a positive integer"
[[ "$dali_num_threads" =~ ^[0-9]+$ ]] || aicr_die "--dali-num-threads must be a non-negative integer"
[[ "$dali_prefetch_queue_depth" =~ ^[0-9]+$ && "$dali_prefetch_queue_depth" -gt 0 ]] || aicr_die "--dali-prefetch-queue-depth must be a positive integer"
[[ "$dali_numpy_reader_prefetch_queue_depth" =~ ^[0-9]+$ && "$dali_numpy_reader_prefetch_queue_depth" -gt 0 ]] || aicr_die "--dali-numpy-reader-prefetch-queue-depth must be a positive integer"
case "$dali_decode_mode" in random-crop|decode-resize) ;; *) aicr_die "--dali-decode-mode must be random-crop or decode-resize" ;; esac
[[ "$dali_hw_decoder_load" =~ ^([0-9]+([.][0-9]*)?|[.][0-9]+)$ ]] || aicr_die "--dali-hw-decoder-load must be a non-negative float"
[[ -z "$dali_gds_chunk_size" || "$dali_gds_chunk_size" =~ ^[0-9]+([kKmM])?$ ]] || aicr_die "--dali-gds-chunk-size must be a byte count accepted by DALI, such as 2097152 or 2M"
[[ "$numpy_block_cache_size" =~ ^[0-9]+$ && "$numpy_block_cache_size" -gt 0 ]] || aicr_die "--numpy-block-cache-size must be a positive integer"
[[ "$synthetic_class_count" =~ ^[0-9]+$ && "$synthetic_class_count" -gt 0 ]] || aicr_die "--synthetic-class-count must be a positive integer"
[[ "$synthetic_image_size" =~ ^[0-9]+$ && "$synthetic_image_size" -gt 0 ]] || aicr_die "--synthetic-image-size must be a positive integer"
case "$synthetic_dtype" in float32|float16|bfloat16) ;; *) aicr_die "--synthetic-dtype must be float32, float16, or bfloat16" ;; esac
[[ "$pin_memory" == "0" || "$pin_memory" == "1" ]] || aicr_die "--pin-memory must be 0 or 1"
[[ "$persistent_workers" == "0" || "$persistent_workers" == "1" ]] || aicr_die "--persistent-workers must be 0 or 1"
[[ "$warmup_iters" =~ ^[0-9]+$ && "$warmup_iters" -ge 0 ]] || aicr_die "--warmup-iters must be a non-negative integer"
[[ "$measured_iters" =~ ^[0-9]+$ && "$measured_iters" -gt 0 ]] || aicr_die "--measured-iters must be a positive integer"
case "$precision" in bf16|fp32) ;; *) aicr_die "--precision must be bf16 or fp32" ;; esac
[[ "$channels_last" == "0" || "$channels_last" == "1" ]] || aicr_die "--channels-last must be 0 or 1"
[[ "$drop_last" == "0" || "$drop_last" == "1" ]] || aicr_die "--drop-last must be 0 or 1"
assert_derived_jpeg_dataset_root

date_utc="$(aicr_today_date)"
run_id="${DDP_RUN_ID:-$(aicr_next_by_date_run_id "$date_utc" "$cluster" "$AICR_SCOPE_MULTI_NODE" "ddp-resnet50")}"
raw_rel="$(aicr_multi_node_raw_run_dir "$date_utc" "$cluster" "ddp-resnet50" "$run_id")"
parsed_rel="$(aicr_multi_node_parsed_run_dir "$date_utc" "$cluster" "ddp-resnet50" "$run_id")"
mkdir -p \
  "${AICR_BMARK_DIR}/${raw_rel}/canonical/ranks" \
  "${AICR_BMARK_DIR}/${raw_rel}/wrapper" \
  "${AICR_BMARK_DIR}/${raw_rel}/metadata" \
  "${AICR_BMARK_DIR}/${parsed_rel}"

job_id="${SLURM_JOB_ID:-}"
partition="${SLURM_JOB_PARTITION:-${SLURM_PARTITION:-}}"
submitted_at="$(aicr_timestamp_utc)"
peer_nodes_csv="$(scontrol show hostnames "${SLURM_JOB_NODELIST:-}" 2>/dev/null | paste -sd, - || true)"
if [[ -z "$peer_nodes_csv" ]]; then
  peer_nodes_csv="$(hostname -s 2>/dev/null || hostname)"
fi
node_count="$(aicr_python - <<PY
csv = """${peer_nodes_csv}"""
print(len([x for x in csv.split(",") if x]))
PY
)"
gpus_per_node=8
total_gpus=$((node_count * gpus_per_node))
master_addr="${DDP_MASTER_ADDR:-${peer_nodes_csv%%,*}}"
master_port="${DDP_MASTER_PORT:-$((29500 + (${SLURM_JOB_ID:-0} % 1000)))}"

summary_rel="${raw_rel}/canonical/ddp-resnet50-summary.txt"
env_rel="${raw_rel}/canonical/ddp-resnet50-env.txt"
cmd_rel="${raw_rel}/canonical/ddp-resnet50-command.sh"
stdout_rel="${raw_rel}/canonical/ddp-resnet50-stdout.txt"
stderr_rel="${raw_rel}/canonical/ddp-resnet50-stderr.txt"
inventory_rel="${raw_rel}/canonical/nvidia-smi-L.txt"
rank_dir_rel="${raw_rel}/canonical/ranks"
summary_json_rel="${parsed_rel}/summary.json"
status_json_rel="${parsed_rel}/status.json"
record_rel="$(aicr_multi_node_record_path "$date_utc" "$cluster" "ddp-resnet50" "$run_id")"

summary_abs="${AICR_BMARK_DIR}/${summary_rel}"
cmd_abs="${AICR_BMARK_DIR}/${cmd_rel}"
stdout_abs="${AICR_BMARK_DIR}/${stdout_rel}"
stderr_abs="${AICR_BMARK_DIR}/${stderr_rel}"
inventory_abs="${AICR_BMARK_DIR}/${inventory_rel}"
summary_json_abs="${AICR_BMARK_DIR}/${summary_json_rel}"
status_json_abs="${AICR_BMARK_DIR}/${status_json_rel}"
record_abs="${AICR_BMARK_DIR}/${record_rel}"
rank_dir_abs="${AICR_BMARK_DIR}/${rank_dir_rel}"
workload_script_abs="${BENCHMARK_DIR}/run-ddp-resnet50-workload.py"
if [[ -z "$cufile_log_path" && "$input_backend" == "dali-numpy-fp16-blocks-gds" ]]; then
  cufile_log_path="${rank_dir_abs}/rank-{rank}/cufile.log"
fi
read -r -a apptainer_common_opts <<<"${AICR_APPTAINER_COMMON_OPTS}"
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
gpu_preflight_status="Pass"
gpu_preflight_note=""
if [[ "$cluster" == "$AICR_CLUSTER_RTXPRO6000" && "$gpu_preflight_count" != "8" ]]; then
  gpu_preflight_status="Fail"
  gpu_preflight_note="expected 8 visible GPUs for RTX DDP, found ${gpu_preflight_count} via ${gpu_preflight_count_source}"
elif [[ "$cluster" == "$AICR_CLUSTER_B200" && "$gpu_count" -lt 8 ]]; then
  gpu_preflight_status="Fail"
  gpu_preflight_note="expected at least 8 visible GPUs for B200 DDP, found ${gpu_count}"
fi

cat >"${AICR_BMARK_DIR}/${env_rel}" <<EOF_ENV
cluster=${cluster}
run_id=${run_id}
launcher=${launcher}
peer_nodes_csv=${peer_nodes_csv}
node_count=${node_count}
gpus_per_node=${gpus_per_node}
total_gpus=${total_gpus}
master_addr=${master_addr}
master_port=${master_port}
image=${image}
gpu_count=${gpu_count}
gpu_preflight_count=${gpu_preflight_count}
gpu_preflight_count_source=${gpu_preflight_count_source}
gpu_preflight_status=${gpu_preflight_status}
cuda_visible_devices=${CUDA_VISIBLE_DEVICES:-}
slurm_job_gpus=${SLURM_JOB_GPUS:-}
dataset_root=${dataset_root}
dataset_split=${dataset_split}
input_backend=${input_backend}
derived_root=${derived_root}
derived_image_size=${derived_image_size}
derived_samples_per_class=${derived_samples_per_class}
derived_seed=${derived_seed}
batch_size=${batch_size}
num_workers=${num_workers}
prefetch_factor=${prefetch_factor}
dali_num_threads=${dali_num_threads}
dali_prefetch_queue_depth=${dali_prefetch_queue_depth}
dali_numpy_reader_prefetch_queue_depth=${dali_numpy_reader_prefetch_queue_depth}
dali_decode_mode=${dali_decode_mode}
dali_hw_decoder_load=${dali_hw_decoder_load}
dali_gds_chunk_size=${dali_gds_chunk_size}
numpy_block_cache_size=${numpy_block_cache_size}
cufile_log_path=${cufile_log_path}
cufile_log_level=${cufile_log_level}
synthetic_class_count=${synthetic_class_count}
synthetic_image_size=${synthetic_image_size}
synthetic_dtype=${synthetic_dtype}
pin_memory=${pin_memory}
persistent_workers=${persistent_workers}
warmup_iters=${warmup_iters}
measured_iters=${measured_iters}
precision=${precision}
channels_last=${channels_last}
drop_last=${drop_last}
srun_mpi=${srun_mpi}
srun_cpu_bind=${srun_cpu_bind}
srun_mem_bind=${srun_mem_bind}
EOF_ENV

status="passed"
notes=()
runner_rc=0
if [[ "$input_backend" != "synthetic-gpu" && "$input_backend" != numpy-* && ! -d "${dataset_root}/${dataset_split}" ]]; then
  status="failed"
  notes+=("missing requested split directory: ${dataset_root}/${dataset_split}")
elif [[ ! -f "$image" ]]; then
  status="failed"
  notes+=("image not found: ${image}")
elif [[ ! -f "$workload_script_abs" ]]; then
  status="failed"
  notes+=("workload script not found: ${workload_script_abs}")
elif ! command -v apptainer >/dev/null 2>&1; then
  status="failed"
  notes+=("apptainer not available")
elif [[ "$gpu_preflight_status" == "Fail" ]]; then
  status="failed"
  notes+=("${gpu_preflight_note}")
fi

common_args=(
  --dataset-root "$dataset_root"
  --split "$dataset_split"
  --input-backend "$input_backend"
  --derived-root "$derived_root"
  --derived-image-size "$derived_image_size"
  --derived-samples-per-class "$derived_samples_per_class"
  --derived-seed "$derived_seed"
  --batch-size "$batch_size"
  --num-workers "$num_workers"
  --prefetch-factor "$prefetch_factor"
  --dali-num-threads "$dali_num_threads"
  --dali-prefetch-queue-depth "$dali_prefetch_queue_depth"
  --dali-numpy-reader-prefetch-queue-depth "$dali_numpy_reader_prefetch_queue_depth"
  --dali-decode-mode "$dali_decode_mode"
  --dali-hw-decoder-load "$dali_hw_decoder_load"
  --dali-gds-chunk-size "$dali_gds_chunk_size"
  --numpy-block-cache-size "$numpy_block_cache_size"
  --cufile-log-path "$cufile_log_path"
  --cufile-log-level "$cufile_log_level"
  --synthetic-class-count "$synthetic_class_count"
  --synthetic-image-size "$synthetic_image_size"
  --synthetic-dtype "$synthetic_dtype"
  --pin-memory "$pin_memory"
  --persistent-workers "$persistent_workers"
  --warmup-iters "$warmup_iters"
  --measured-iters "$measured_iters"
  --precision "$precision"
  --channels-last "$channels_last"
  --drop-last "$drop_last"
  --launcher "$launcher"
  --run-id "$run_id"
  --node-list "$peer_nodes_csv"
  --output-dir "$rank_dir_abs"
  --summary-output "$summary_json_abs"
  --status-output "$status_json_abs"
)

if [[ "$launcher" == "torchrun" ]]; then
  container_cmd=(
    python3 -m torch.distributed.run
    --nnodes "$node_count"
    --nproc-per-node "$gpus_per_node"
    --rdzv-backend c10d
    --rdzv-endpoint "${master_addr}:${master_port}"
    --rdzv-id "${SLURM_JOB_ID:-${run_id}}"
    "$workload_script_abs"
    "${common_args[@]}"
  )
  launch_cmd=(
    srun --nodes "$node_count" --ntasks "$node_count" --ntasks-per-node 1
    apptainer exec "${apptainer_common_opts[@]}" --nv "$image"
    env AICR_DATE_UTC="$date_utc" AICR_CLUSTER_NAME="$cluster"
    "${container_cmd[@]}"
  )
else
  srun_args=(
    srun --mpi="$srun_mpi" --nodes "$node_count" --ntasks "$total_gpus" --ntasks-per-node "$gpus_per_node"
  )
  if [[ -n "$srun_cpu_bind" ]]; then
    srun_args+=(--cpu-bind="$srun_cpu_bind")
  fi
  if [[ -n "$srun_mem_bind" ]]; then
    srun_args+=(--mem-bind="$srun_mem_bind")
  fi
  launch_cmd=(
    "${srun_args[@]}"
    apptainer exec "${apptainer_common_opts[@]}" --nv "$image"
    env MASTER_ADDR="$master_addr" MASTER_PORT="$master_port" AICR_DATE_UTC="$date_utc" AICR_CLUSTER_NAME="$cluster"
    python3 "$workload_script_abs"
    "${common_args[@]}"
  )
fi

{
  printf '%q ' "${launch_cmd[@]}"
  echo
} >"${cmd_abs}"

if [[ "$status" == "passed" ]]; then
  set +e
  "${launch_cmd[@]}" >"${stdout_abs}" 2>"${stderr_abs}"
  runner_rc=$?
  set -e
  if [[ "$runner_rc" -ne 0 ]]; then
    status="failed"
    notes+=("DDP launcher failed")
  fi
else
  : >"${stdout_abs}"
  printf '%s\n' "${notes[@]}" >"${stderr_abs}"
fi

if [[ ! -f "$summary_json_abs" ]]; then
  status="failed"
  notes+=("summary JSON was not created")
  aicr_python - "$summary_json_abs" "$status_json_abs" "$cluster" "$date_utc" "$run_id" "$launcher" "$input_backend" "$peer_nodes_csv" "$node_count" "$total_gpus" "$dali_num_threads" "$dali_prefetch_queue_depth" "$dali_decode_mode" "$dali_hw_decoder_load" "$synthetic_class_count" "$synthetic_image_size" "$synthetic_dtype" "$(aicr_join_csv "${notes[@]}")" <<'PY'
import json
import sys
from pathlib import Path
(
    summary_path,
    status_path,
    cluster,
    date,
    run_id,
    launcher,
    input_backend,
    peers,
    node_count,
    gpu_count,
    dali_num_threads,
    dali_prefetch_queue_depth,
    dali_decode_mode,
    dali_hw_decoder_load,
    synthetic_class_count,
    synthetic_image_size,
    synthetic_dtype,
    notes,
) = sys.argv[1:]
summary = {
    "schema_version": 1,
    "status": "failed",
    "notes": notes,
    "benchmark": "ddp-resnet50",
    "cluster": cluster,
    "date": date,
    "run_id": run_id,
    "launcher": launcher,
    "input_backend": input_backend,
    "node_list": peers,
    "node_count": int(node_count),
    "world_size": int(gpu_count),
    "dali_num_threads": int(dali_num_threads) if input_backend == "dali-gpu-decode" else None,
    "dali_prefetch_queue_depth": int(dali_prefetch_queue_depth) if input_backend == "dali-gpu-decode" else None,
    "dali_decode_mode": dali_decode_mode if input_backend == "dali-gpu-decode" else None,
    "dali_hw_decoder_load": float(dali_hw_decoder_load) if input_backend == "dali-gpu-decode" else None,
    "synthetic_class_count": int(synthetic_class_count) if input_backend == "synthetic-gpu" else None,
    "synthetic_image_size": int(synthetic_image_size) if input_backend == "synthetic-gpu" else None,
    "synthetic_dtype": synthetic_dtype if input_backend == "synthetic-gpu" else None,
}
Path(summary_path).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
Path(status_path).write_text(json.dumps({"status": "failed", "pass_basis": "parsed.summary.status"}, indent=2) + "\n", encoding="utf-8")
PY
else
  aicr_python - "$summary_json_abs" "$status_json_abs" "$job_id" "$partition" "$gpu_count" "$gpu_preflight_count" "$gpu_preflight_count_source" "$gpu_preflight_status" "$srun_mpi" "$srun_cpu_bind" "$srun_mem_bind" <<'PY'
import json
import sys
from pathlib import Path

(
    summary_path,
    _status_path,
    job_id,
    partition,
    gpu_count,
    preflight_count,
    preflight_source,
    preflight_status,
    srun_mpi,
    srun_cpu_bind,
    srun_mem_bind,
) = sys.argv[1:]
summary = json.loads(Path(summary_path).read_text(encoding="utf-8"))
summary["job_id"] = job_id or None
summary["partition"] = partition or None
summary["gpu_count"] = int(gpu_count or 0)
summary["gpu_preflight_count"] = int(preflight_count or 0)
summary["gpu_preflight_count_source"] = preflight_source
summary["gpu_preflight_status"] = preflight_status
summary["srun_mpi"] = srun_mpi or None
summary["srun_cpu_bind"] = srun_cpu_bind or None
summary["srun_mem_bind"] = srun_mem_bind or None
Path(summary_path).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
PY
  status="$(aicr_python - "$summary_json_abs" <<'PY'
import json, sys
from pathlib import Path
print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("status", "failed"))
PY
)"
fi

notes_str="$(aicr_python - "$summary_json_abs" <<'PY'
import json, sys
from pathlib import Path
print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("notes", ""))
PY
)"

aicr_python - "$summary_json_abs" "$summary_abs" <<'PY'
import json
import sys
from pathlib import Path
s = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
lines = [
    f"status={s.get('status')}",
    f"cluster={s.get('cluster')}",
    f"date={s.get('date')}",
    f"run_id={s.get('run_id')}",
    f"launcher={s.get('launcher')}",
    f"input_backend={s.get('input_backend')}",
    f"derived_root={s.get('derived_root')}",
    f"derived_image_size={s.get('derived_image_size')}",
    f"derived_samples_per_class={s.get('derived_samples_per_class')}",
    f"derived_seed={s.get('derived_seed')}",
    f"derived_format={s.get('derived_format')}",
    f"derived_storage_dtype={s.get('derived_storage_dtype')}",
    f"derived_storage_layout={s.get('derived_storage_layout')}",
    f"gds_requested={s.get('gds_requested')}",
    f"dali_reader_device={s.get('dali_reader_device')}",
    f"dali_numpy_use_o_direct={s.get('dali_numpy_use_o_direct')}",
    f"dali_numpy_reader_prefetch_queue_depth={s.get('dali_numpy_reader_prefetch_queue_depth')}",
    f"dali_gds_chunk_size={s.get('dali_gds_chunk_size')}",
    f"cufile_log_path={s.get('cufile_log_path')}",
    f"cufile_log_level={s.get('cufile_log_level')}",
    f"storage_transport_path={s.get('storage_transport_path')}",
    f"numpy_block_size={s.get('numpy_block_size')}",
    f"prepared_block_label_source={s.get('prepared_block_label_source')}",
    f"dali_num_threads={s.get('dali_num_threads')}",
    f"dali_prefetch_queue_depth={s.get('dali_prefetch_queue_depth')}",
    f"dali_decode_mode={s.get('dali_decode_mode')}",
    f"dali_hw_decoder_load={s.get('dali_hw_decoder_load')}",
    f"synthetic_class_count={s.get('synthetic_class_count')}",
    f"synthetic_image_size={s.get('synthetic_image_size')}",
    f"synthetic_dtype={s.get('synthetic_dtype')}",
    f"node_count={s.get('node_count')}",
    f"world_size={s.get('world_size')}",
    f"precision={s.get('precision')}",
    f"global_batch_size={s.get('global_batch_size')}",
    f"samples_per_second={s.get('samples_per_second')}",
    f"rank_imbalance_ratio={s.get('rank_imbalance_ratio')}",
    f"rank_imbalance_percent={s.get('rank_imbalance_percent')}",
    f"data_wait_mean_seconds_max_rank={s.get('data_wait_mean_seconds_max_rank')}",
    f"h2d_mean_seconds_max_rank={s.get('h2d_mean_seconds_max_rank')}",
    f"input_prepare_mean_seconds_max_rank={s.get('input_prepare_mean_seconds_max_rank')}",
    f"notes={s.get('notes', '')}",
]
Path(sys.argv[2]).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

canonical_artifacts=("${summary_rel}" "${env_rel}" "${cmd_rel}" "${stdout_rel}" "${stderr_rel}" "${inventory_rel}")
while IFS= read -r -d '' path; do
  canonical_artifacts+=("${path#"${AICR_BMARK_DIR}/"}")
done < <(find "$rank_dir_abs" -maxdepth 1 -type f -name 'rank-*.json' -print0)
while IFS= read -r -d '' path; do
  canonical_artifacts+=("${path#"${AICR_BMARK_DIR}/"}")
done < <(find "$rank_dir_abs" -mindepth 2 -maxdepth 2 -type f -name 'cufile.log' -print0)

aicr_emit_record_from_args \
  "$record_abs" \
  "$AICR_SCOPE_MULTI_NODE" \
  "$cluster" \
  "" \
  "$peer_nodes_csv" \
  "ddp-resnet50" \
  "benchmark-ddp-resnet50" \
  "$run_id" \
  "$date_utc" \
  "$submitted_at" \
  "$(aicr_timestamp_utc)" \
  "$partition" \
  "$job_id" \
  "$status" \
  "parsed.summary.status" \
  "$node_count" \
  "$total_gpus" \
  "$(aicr_join_csv "${canonical_artifacts[@]}")" \
  "$(aicr_join_csv "$summary_json_rel" "$status_json_rel")" \
  "$(aicr_join_csv "$stdout_rel" "$stderr_rel")" \
  "$notes_str"

aicr_append_index_row_from_record "${AICR_BMARK_DIR}/$(aicr_by_date_index_path "${date_utc}")" "$record_abs"

echo "DDP ResNet-50 benchmark status: ${status}"
echo "Record: ${record_rel}"
echo "Summary: ${summary_rel}"

[[ "$status" == "passed" ]]
