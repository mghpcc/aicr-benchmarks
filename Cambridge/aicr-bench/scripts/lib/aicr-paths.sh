#!/usr/bin/env bash
set -euo pipefail

if [[ "${AICR_PATHS_LOADED:-0}" == "1" ]]; then
  if return 0 2>/dev/null; then
    # shellcheck disable=SC2317
    return 0
  fi
  # shellcheck disable=SC2317
  exit 0
fi
AICR_PATHS_LOADED=1

AICR_STATUS_NOT_RUN="not-run"
AICR_STATUS_SUBMITTED="submitted"
AICR_STATUS_LAUNCHED="launched"
AICR_STATUS_ARTIFACT_CAPTURED="artifact-captured"
AICR_STATUS_PARSED="parsed"
AICR_STATUS_PASSED="passed"
AICR_STATUS_DEGRADED="degraded"
AICR_STATUS_FAILED="failed"
AICR_STATUS_ERROR="error"

AICR_CLUSTER_RTXPRO6000="rtxpro6000"
AICR_CLUSTER_B200="b200"

AICR_SCOPE_SETUP="setup"
AICR_SCOPE_NODE="node"
AICR_SCOPE_MULTI_NODE="multi-node"

AICR_MODE_PER_NODE="per-node"
AICR_MODE_SINGLE_NODE_LOCAL="single-node-local"
AICR_MODE_MULTI_NODE_RDMA="multi-node-rdma"
AICR_MODE_BENCHMARK_SINGLE_NODE="benchmark-single-node"

AICR_CHECK_CONTAINER_COMPAT="container-compat"
AICR_CHECK_PYTHON_RUNTIME_SLURM="python-runtime-slurm"
AICR_CHECK_PYTORCH_SMOKE="pytorch-smoke"
AICR_CHECK_HPC_BENCHMARKS_SMOKE="hpc-benchmarks-smoke"
AICR_CHECK_ELBENCHO_SMOKE="elbencho-smoke"
AICR_CHECK_GPU_TOPOLOGY="gpu-topology"
AICR_CHECK_NCCL_LOCAL="nccl-local"
AICR_CHECK_NCCL_RDMA="nccl-rdma"
AICR_CHECK_NCCL_SUITE_LOCAL="nccl-suite-local"
AICR_CHECK_NCCL_SUITE_RDMA="nccl-suite-rdma"
AICR_CHECK_NCCL_SUITE_SCALE="nccl-suite-scale"
AICR_CHECK_GDS="gds"
AICR_CHECK_DATALOADER="dataloader"
AICR_CHECK_ELBENCHO="elbencho"
AICR_CHECK_HPL_MXP="hpl-mxp"

export \
  AICR_STATUS_NOT_RUN \
  AICR_STATUS_SUBMITTED \
  AICR_STATUS_LAUNCHED \
  AICR_STATUS_ARTIFACT_CAPTURED \
  AICR_STATUS_PARSED \
  AICR_STATUS_PASSED \
  AICR_STATUS_DEGRADED \
  AICR_STATUS_FAILED \
  AICR_STATUS_ERROR \
  AICR_CLUSTER_RTXPRO6000 \
  AICR_CLUSTER_B200 \
  AICR_SCOPE_SETUP \
  AICR_SCOPE_NODE \
  AICR_SCOPE_MULTI_NODE \
  AICR_MODE_PER_NODE \
  AICR_MODE_SINGLE_NODE_LOCAL \
  AICR_MODE_MULTI_NODE_RDMA \
  AICR_MODE_BENCHMARK_SINGLE_NODE \
  AICR_CHECK_CONTAINER_COMPAT \
  AICR_CHECK_PYTHON_RUNTIME_SLURM \
  AICR_CHECK_PYTORCH_SMOKE \
  AICR_CHECK_HPC_BENCHMARKS_SMOKE \
  AICR_CHECK_ELBENCHO_SMOKE \
  AICR_CHECK_GPU_TOPOLOGY \
  AICR_CHECK_NCCL_LOCAL \
  AICR_CHECK_NCCL_RDMA \
  AICR_CHECK_NCCL_SUITE_LOCAL \
  AICR_CHECK_NCCL_SUITE_RDMA \
  AICR_CHECK_NCCL_SUITE_SCALE \
  AICR_CHECK_GDS \
  AICR_CHECK_DATALOADER \
  AICR_CHECK_ELBENCHO \
  AICR_CHECK_HPL_MXP

aicr_die() {
  echo "ERROR: $*" >&2
  exit 1
}

aicr_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

aicr_repo_root_from_this_file() {
  local src="${BASH_SOURCE[0]}"
  cd "$(dirname "$src")/../.." && pwd
}

aicr_source_settings_if_present() {
  if [[ "${AICR_SKIP_SETTINGS:-0}" == "1" ]]; then
    return 0
  fi

  local settings_file="${AICR_SETTINGS_FILE:-${AICR_BMARK_DIR}/benchmark-settings.env}"
  if [[ -f "$settings_file" ]]; then
    # shellcheck disable=SC1090
    source "$settings_file"
  fi
}

aicr_export_defaults() {
  : "${AICR_BMARK_DIR:=$(aicr_repo_root_from_this_file)}"
  : "${AICR_DATA_DIR:=${AICR_BMARK_DIR}/data}"
  : "${AICR_IMAGENET_DIR:=/work/aicr/commissioning/benchmarks/imagenet/ILSVRC/Data/CLS-LOC}"
  : "${AICR_TMP_DIR:=${AICR_DATA_DIR}/tmp}"
  : "${AICR_SCRATCH_DIR:=${AICR_BMARK_DIR}/scratch}"
  : "${AICR_GDS_SCRATCH_DIR:=${AICR_SCRATCH_DIR}/gds}"
  : "${AICR_DATALOADER_DERIVED_ROOT:=${AICR_SCRATCH_DIR}/derived-datasets/dataloader-lab}"
  : "${AICR_RUNTIME_ROOT:=/work/aicr/commissioning/benchmarks/runtime}"
  : "${AICR_APPTAINER_IMAGE_DIR:=${AICR_RUNTIME_ROOT}/apptainer/images}"
  : "${AICR_ELBENCHO_TAG:=master-ubuntu-cuda-multiarch}"
  : "${AICR_ELBENCHO_IMAGE:=${AICR_APPTAINER_IMAGE_DIR}/elbencho-${AICR_ELBENCHO_TAG}.sif}"
  : "${AICR_RESULTS_DIR:=${AICR_BMARK_DIR}/results}"
  : "${AICR_RESULTS_SETUP_DIR:=${AICR_RESULTS_DIR}/setup}"
  : "${AICR_RESULTS_BY_DATE_DIR:=${AICR_RESULTS_DIR}/by-date}"
  : "${AICR_RESULTS_BY_NODE_DIR:=${AICR_RESULTS_DIR}/by-node}"
  : "${AICR_RESULTS_SLURM_DIR:=${AICR_RESULTS_DIR}/slurm}"
  : "${AICR_RESULTS_REPORTS_DIR:=${AICR_RESULTS_DIR}/reports}"
  : "${AICR_RESULTS_ARCHIVE_ROOT:=/work/aicr/commissioning/benchmarks/results-archive}"
  : "${AICR_TOOLS_DIR:=${AICR_BMARK_DIR}/.tools}"
  : "${AICR_UV_ROOT:=${AICR_RUNTIME_ROOT}/uv}"
  : "${AICR_UV_ENVS_DIR:=${AICR_RUNTIME_ROOT}/uv-envs}"
  : "${AICR_UV_ENV_PREFIX:=${AICR_UV_ENVS_DIR}/aicr-bench}"
  : "${AICR_UV_BIN:=${AICR_UV_ROOT}/bin/uv}"
  : "${AICR_USE_UV_MODULE:=1}"
  : "${AICR_UV_MODULE_ENV_FILE:=/apps/umass/.utilities/environment}"
  : "${AICR_UV_MODULE_NAME:=uv}"
  : "${AICR_GDS_TOOL_DIR:=/usr/local/cuda/gds/tools}"
  : "${AICR_GDSCHECK_BIN:=${AICR_GDS_TOOL_DIR}/gdscheck}"
  : "${AICR_GDSIO_BIN:=${AICR_GDS_TOOL_DIR}/gdsio}"
  : "${AICR_GDS_THROUGHPUT_FILE:=}"
  : "${AICR_GDS_READ_THROUGHPUT_FILE:=}"
  : "${AICR_GDS_WRITE_THROUGHPUT_FILE:=}"
  : "${AICR_APPTAINER_COMMON_OPTS:=--no-mount /etc/localtime --bind /work:/work --bind /scratch:/scratch}"

  export \
    AICR_BMARK_DIR \
    AICR_DATA_DIR \
    AICR_IMAGENET_DIR \
    AICR_TMP_DIR \
    AICR_SCRATCH_DIR \
    AICR_GDS_SCRATCH_DIR \
    AICR_DATALOADER_DERIVED_ROOT \
    AICR_RUNTIME_ROOT \
    AICR_APPTAINER_IMAGE_DIR \
    AICR_ELBENCHO_TAG \
    AICR_ELBENCHO_IMAGE \
    AICR_RESULTS_DIR \
    AICR_RESULTS_SETUP_DIR \
    AICR_RESULTS_BY_DATE_DIR \
    AICR_RESULTS_BY_NODE_DIR \
    AICR_RESULTS_SLURM_DIR \
    AICR_RESULTS_REPORTS_DIR \
    AICR_RESULTS_ARCHIVE_ROOT \
    AICR_TOOLS_DIR \
    AICR_UV_ROOT \
    AICR_UV_ENVS_DIR \
    AICR_UV_ENV_PREFIX \
    AICR_UV_BIN \
    AICR_USE_UV_MODULE \
    AICR_UV_MODULE_ENV_FILE \
    AICR_UV_MODULE_NAME \
    AICR_GDS_TOOL_DIR \
    AICR_GDSCHECK_BIN \
    AICR_GDSIO_BIN \
    AICR_GDS_THROUGHPUT_FILE \
    AICR_GDS_READ_THROUGHPUT_FILE \
    AICR_GDS_WRITE_THROUGHPUT_FILE \
    AICR_APPTAINER_COMMON_OPTS
}

aicr_init_paths() {
  local default_elbencho_image_before_settings
  aicr_export_defaults
  default_elbencho_image_before_settings="${AICR_APPTAINER_IMAGE_DIR}/elbencho-${AICR_ELBENCHO_TAG}.sif"
  aicr_source_settings_if_present
  if [[ "${AICR_ELBENCHO_IMAGE:-}" == "${default_elbencho_image_before_settings}" ||
        "${AICR_ELBENCHO_IMAGE:-}" == */"elbencho-${AICR_ELBENCHO_TAG}.sif" ]]; then
    AICR_ELBENCHO_IMAGE="${AICR_APPTAINER_IMAGE_DIR}/elbencho-${AICR_ELBENCHO_TAG}.sif"
  fi
  aicr_export_defaults
}

aicr_require_repo_root() {
  [[ -d "${AICR_BMARK_DIR}" ]] || aicr_die "AICR_BMARK_DIR does not exist: ${AICR_BMARK_DIR}"
  [[ -d "${AICR_BMARK_DIR}/scripts" ]] || aicr_die "AICR_BMARK_DIR does not look like repo root: ${AICR_BMARK_DIR}"
}

aicr_require_settings_file() {
  local settings_file="${AICR_SETTINGS_FILE:-${AICR_BMARK_DIR}/benchmark-settings.env}"
  if [[ ! -f "${settings_file}" ]]; then
    echo "ERROR: ${settings_file} not found." >&2
    echo "Create it first: cp benchmark-settings.env.example benchmark-settings.env" >&2
    exit 2
  fi
}

aicr_mkdirs() {
  mkdir -p \
    "${AICR_DATA_DIR}" \
    "${AICR_TMP_DIR}" \
    "${AICR_SCRATCH_DIR}" \
    "${AICR_GDS_SCRATCH_DIR}" \
    "${AICR_RESULTS_SETUP_DIR}" \
    "${AICR_RESULTS_BY_DATE_DIR}" \
    "${AICR_RESULTS_BY_NODE_DIR}" \
    "${AICR_RESULTS_SLURM_DIR}" \
    "${AICR_RESULTS_REPORTS_DIR}"
}

aicr_repo_local_runtime_root_prefix() {
  printf '%s/.tools/uv\n' "$AICR_BMARK_DIR"
}

aicr_repo_local_uv_envs_dir() {
  printf '%s/.tools/uv-envs\n' "$AICR_BMARK_DIR"
}

aicr_repo_local_env_prefix() {
  printf '%s/aicr-bench\n' "$(aicr_repo_local_uv_envs_dir)"
}

aicr_repo_local_apptainer_image_dir() {
  printf '%s/apptainer/images\n' "$AICR_BMARK_DIR"
}

aicr_runtime_required_image_paths() {
  printf '%s/pytorch-25.10-py3.sif\n' "$AICR_APPTAINER_IMAGE_DIR"
  printf '%s/hpc-benchmarks-26.02.sif\n' "$AICR_APPTAINER_IMAGE_DIR"
  if [[ "${AICR_REQUIRE_ELBENCHO_IMAGE:-0}" == "1" ]]; then
    printf '%s\n' "$AICR_ELBENCHO_IMAGE"
  fi
  if [[ "${ENABLE_PYTORCH_PROBE:-0}" == "1" ]]; then
    printf '%s/pytorch-26.03-py3.sif\n' "$AICR_APPTAINER_IMAGE_DIR"
  fi
}

aicr_print_runtime_rebuild_hint() {
  cat >&2 <<EOF
Rebuild canonical runtime assets with:
  make setup-python-local
  make rebuild-runtime APPLY=1

Runtime root:
  ${AICR_RUNTIME_ROOT}
EOF
}

aicr_validate_runtime_assets() {
  local errors=()
  local image

  [[ -x "$AICR_UV_BIN" ]] || errors+=("missing executable uv: ${AICR_UV_BIN}")
  [[ -f "${AICR_UV_ENV_PREFIX}/pyvenv.cfg" ]] || errors+=("missing uv virtualenv prefix: ${AICR_UV_ENV_PREFIX}")
  [[ -x "${AICR_UV_ENV_PREFIX}/bin/python" ]] || errors+=("missing executable env Python: ${AICR_UV_ENV_PREFIX}/bin/python")

  while IFS= read -r image; do
    [[ -n "$image" ]] || continue
    [[ -r "$image" && -s "$image" ]] || errors+=("missing readable SIF image: ${image}")
  done < <(aicr_runtime_required_image_paths)

  if (( ${#errors[@]} == 0 )); then
    if ! "${AICR_UV_ENV_PREFIX}/bin/python" - <<'PY' >/dev/null; then
import jsonschema
import matplotlib
import pandas
import snakemake
PY
      errors+=("configured uv Python failed required imports: jsonschema, matplotlib, pandas, snakemake")
    fi
  fi

  if (( ${#errors[@]} > 0 )); then
    printf 'ERROR: configured runtime assets are not ready:\n' >&2
    printf '  - %s\n' "${errors[@]}" >&2
    aicr_print_runtime_rebuild_hint
    return 1
  fi
}

aicr_repo_python_env_path() {
  local prefix

  prefix="$AICR_UV_ENV_PREFIX"
  if [[ -x "${prefix}/bin/python" && -f "${prefix}/pyvenv.cfg" ]]; then
    printf '%s\n' "${prefix}/bin/python"
    return 0
  fi

  prefix="$(aicr_repo_local_env_prefix)"
  if [[ -x "${prefix}/bin/python" && -f "${prefix}/pyvenv.cfg" ]]; then
    printf '%s\n' "${prefix}/bin/python"
    return 0
  fi

  return 1
}

aicr_python() {
  local python_bin

  if [[ "${AICR_ALLOW_SYSTEM_PYTHON:-0}" == "1" ]]; then
    command python3 "$@"
    return $?
  fi

  if python_bin="$(aicr_repo_python_env_path)"; then
    mkdir -p "${AICR_TMP_DIR}/matplotlib"
    MPLCONFIGDIR="${MPLCONFIGDIR:-${AICR_TMP_DIR}/matplotlib}" PYTHONNOUSERSITE=1 PYTHONHOME= "$python_bin" "$@"
    return $?
  fi

  printf 'ERROR: repo uv Python is not available.\n' >&2
  printf '  AICR_UV_BIN=%s\n' "$AICR_UV_BIN" >&2
  printf '  AICR_UV_ENV_PREFIX=%s\n' "$AICR_UV_ENV_PREFIX" >&2
  printf '  macOS repo-local fallback=%s\n' "$(aicr_repo_local_env_prefix)" >&2
  aicr_print_runtime_rebuild_hint
  printf 'For laptop/local development, run:\n' >&2
  printf '  make setup-python-local\n' >&2
  printf 'For local-only static checks, set AICR_ALLOW_SYSTEM_PYTHON=1 explicitly.\n' >&2
  return 1
}

aicr_assert_supported_cluster() {
  case "$1" in
    b200|rtxpro6000) ;;
    *) aicr_die "Unsupported cluster: $1" ;;
  esac
}

aicr_cluster_name() {
  if [[ -n "${AICR_CLUSTER_NAME:-}" ]]; then
    printf '%s\n' "$AICR_CLUSTER_NAME"
    return 0
  fi

  if aicr_have_cmd nvidia-smi; then
    local gpu_name
    gpu_name="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)"
    case "$gpu_name" in
      *B200*)
        printf 'b200\n'
        return 0
        ;;
      *"RTX PRO 6000 Blackwell Server Edition"*)
        printf 'rtxpro6000\n'
        return 0
        ;;
    esac
  fi

  printf 'unknown\n'
}

aicr_timestamp_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

aicr_run_id_timestamp_utc() {
  date -u +%Y-%m-%dT%H%M%SZ
}

aicr_today_date() {
  date -u +%Y-%m-%d
}

aicr_time_hhmmssz() {
  date -u +%H%M%SZ
}

aicr_gpu_count() {
  if aicr_have_cmd nvidia-smi; then
    nvidia-smi -L 2>/dev/null | grep -c '^GPU ' || true
  else
    echo 0
  fi
}

aicr_run_seq_from_dir() {
  local dir="$1"
  local prefix="$2"
  local max=0
  local base num path

  mkdir -p "$dir"
  shopt -s nullglob
  for path in "$dir"/"$prefix"*; do
    base="$(basename "$path")"
    if [[ "$base" =~ ^${prefix}r([0-9]{2})$ ]]; then
      num=$((10#${BASH_REMATCH[1]}))
      (( num > max )) && max="$num"
    fi
  done
  shopt -u nullglob

  printf 'r%02d\n' "$((max + 1))"
}

aicr_next_setup_run_id() {
  local cluster="$1"
  local check="$2"
  local stamp="${3:-$(aicr_run_id_timestamp_utc)}"
  local dir="${AICR_RESULTS_SETUP_DIR}/${cluster}/raw/${check}"
  local seq

  seq="$(aicr_run_seq_from_dir "$dir" "${stamp}-")"
  printf '%s-%s\n' "$stamp" "$seq"
}

aicr_next_setup_baseline_id() {
  local cluster="$1"
  local day="${2:-$(aicr_today_date)}"
  local dir="${AICR_RESULTS_SETUP_DIR}/${cluster}"
  local seq

  seq="$(aicr_run_seq_from_dir "$dir" "${day}-${cluster}-")"
  printf '%s-%s-%s\n' "$day" "$cluster" "$seq"
}

aicr_next_by_date_run_id() {
  local day="$1"
  local cluster="$2"
  local scope="$3"
  local check="$4"
  local node="${5:-}"
  local stamp="${6:-$(aicr_time_hhmmssz)}"
  local dir
  local seq

  if [[ "$scope" == "$AICR_SCOPE_NODE" ]]; then
    [[ -n "$node" ]] || aicr_die "node is required for per-node run IDs"
    dir="${AICR_RESULTS_BY_DATE_DIR}/${day}/raw/${cluster}/nodes/${node}/${check}"
  elif [[ "$scope" == "$AICR_SCOPE_MULTI_NODE" ]]; then
    dir="${AICR_RESULTS_BY_DATE_DIR}/${day}/raw/${cluster}/multi-node/${check}"
  else
    aicr_die "Unsupported by-date scope: $scope"
  fi

  seq="$(aicr_run_seq_from_dir "$dir" "${stamp}-")"
  printf '%s-%s\n' "$stamp" "$seq"
}

aicr_setup_baseline_path() {
  printf 'results/setup/%s/baseline.json\n' "$1"
}

aicr_setup_baseline_history_path() {
  printf 'results/setup/%s/baseline-history.jsonl\n' "$1"
}

aicr_setup_raw_run_dir() {
  printf 'results/setup/%s/raw/%s/%s\n' "$1" "$2" "$3"
}

aicr_setup_parsed_run_dir() {
  printf 'results/setup/%s/parsed/%s/%s\n' "$1" "$2" "$3"
}

aicr_setup_record_path() {
  printf '%s/metadata/record.json\n' "$(aicr_setup_raw_run_dir "$1" "$2" "$3")"
}

aicr_setup_parsed_status_path() {
  printf '%s/status.json\n' "$(aicr_setup_parsed_run_dir "$1" "$2" "$3")"
}

aicr_by_date_index_path() {
  printf 'results/by-date/%s/index.jsonl\n' "$1"
}

aicr_node_raw_run_dir() {
  printf 'results/by-date/%s/raw/%s/nodes/%s/%s/%s\n' "$1" "$2" "$3" "$4" "$5"
}

aicr_node_parsed_run_dir() {
  printf 'results/by-date/%s/parsed/%s/nodes/%s/%s/%s\n' "$1" "$2" "$3" "$4" "$5"
}

aicr_multi_node_raw_run_dir() {
  printf 'results/by-date/%s/raw/%s/multi-node/%s/%s\n' "$1" "$2" "$3" "$4"
}

aicr_multi_node_parsed_run_dir() {
  printf 'results/by-date/%s/parsed/%s/multi-node/%s/%s\n' "$1" "$2" "$3" "$4"
}

aicr_node_record_path() {
  printf '%s/metadata/record.json\n' "$(aicr_node_raw_run_dir "$1" "$2" "$3" "$4" "$5")"
}

aicr_multi_node_record_path() {
  printf '%s/metadata/record.json\n' "$(aicr_multi_node_raw_run_dir "$1" "$2" "$3" "$4")"
}

aicr_by_node_history_path() {
  printf 'results/by-node/%s/%s/history.jsonl\n' "$1" "$2"
}

aicr__print_json_envelope_impl() {
  local ok="$1"
  local cluster="$2"
  local baseline_id="$3"
  local baseline_path="$4"
  local baseline_history_path="$5"
  local errors_json="$6"

  aicr_python - "$ok" "$cluster" "$baseline_id" "$baseline_path" "$baseline_history_path" "$errors_json" <<'PY'
import json
import sys

ok = sys.argv[1].lower() == 'true'
cluster, baseline_id, baseline_path, baseline_history_path, errors_json = sys.argv[2:]

print(json.dumps({
    "ok": ok,
    "cluster": cluster or None,
    "baseline_id": baseline_id or None,
    "baseline_path": baseline_path or None,
    "baseline_history_path": baseline_history_path or None,
    "errors": json.loads(errors_json),
}, indent=2))
PY
}

aicr_print_json_envelope() {
  aicr__print_json_envelope_impl "$@"
}

aicrprintjsonenvelope() {
  aicr__print_json_envelope_impl "$@"
}

aicr_init_paths
