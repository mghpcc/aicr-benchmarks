#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/run-hpl-mxp.sh --cluster <b200|rtxpro6000> --nodes <N> --matrix-size <N> --nb <N> [--nprow <auto|N>] [--npcol <auto|N>] [--preset <smoke|staged|campaign-candidate|weak-study>] [--image <path>] [--sloppy-type <precision>] [--test-loop <n>] [--ompi-coll <value|none>] [--ompi-pml <value|none>] [--ompi-btl <value|none>] [--ompi-btl-tcp-if-include <value|none>] [--ompi-oob-tcp-if-include <value|none>] [--ucx-tls <value|none>] [--ucx-net-devices <value|none>] [--pmix-mca-gds <value|none>] [--mpi-use-mpi <0|1>] [--use-mpi-panel-broadcast <0-100>] [--prioritize-trsm <0|1>] [--prioritize-factorization <0|1>] [--anq-device <columns>] [--fill-device <0|1>] [--fill-device-buffer-size <MB>] [--call-dgemv-with-multiple-threads <threads>] [--preset-gemm-kernel <n>] [--cpu-affinity <map>] [--mem-affinity <map>] [--ucx-affinity <map>] [--u-panel-chunk-nbs <N>] [--scaling-study <exploratory|strong|weak>] [--baseline-matrix-size <N>]

Runs a guarded HPL-MxP row inside the NVIDIA HPC Benchmarks container and
writes canonical raw/parsed artifacts. Rows are classified as smoke, staged,
campaign-candidate, or weak-study from the preset and matrix size. The
weak-study preset uses the reviewed weak-scaling matrix ladder with the
derived NPS4 affinity profile.
Precision values are FP16, FP8, or B200-only FP4.
EOF
}

aicr_require_repo_root
aicr_mkdirs

cluster="${AICR_CLUSTER_NAME:-}"
node_count="${SLURM_NNODES:-}"
matrix_size=""
nb=""
nprow_override="${HPL_MXP_NPROW:-auto}"
npcol_override="${HPL_MXP_NPCOL:-auto}"
preset="${HPL_MXP_PRESET:-smoke}"
image="${HPL_MXP_IMAGE:-${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif}"
sloppy_type="${HPL_MXP_SLOPPY_TYPE:-FP16}"
test_loop="${HPL_MXP_TEST_LOOP:-1}"
ompi_coll="${HPL_MXP_OMPI_COLL:-^ucc}"
ompi_pml="${HPL_MXP_OMPI_PML:-}"
ompi_btl="${HPL_MXP_OMPI_BTL:-}"
ompi_btl_tcp_if_include="${HPL_MXP_OMPI_BTL_TCP_IF_INCLUDE:-}"
ompi_oob_tcp_if_include="${HPL_MXP_OMPI_OOB_TCP_IF_INCLUDE:-}"
ucx_tls="${HPL_MXP_UCX_TLS:-}"
ucx_net_devices="${HPL_MXP_UCX_NET_DEVICES:-}"
pmix_mca_gds="${HPL_MXP_PMIX_MCA_GDS:-^ds12}"
mpi_use_mpi="${HPL_MXP_MPI_USE_MPI:-0}"
mpi_panel_broadcast="${HPL_MXP_MPI_PANEL_BROADCAST:-1}"
prioritize_trsm="${HPL_MXP_PRIORITIZE_TRSM:-0}"
prioritize_factorization="${HPL_MXP_PRIORITIZE_FACTORIZATION:-0}"
anq_device="${HPL_MXP_ANQ_DEVICE:-}"
fill_device="${HPL_MXP_FILL_DEVICE:-}"
fill_device_buffer_size="${HPL_MXP_FILL_DEVICE_BUFFER_SIZE:-}"
call_dgemv_threads="${HPL_MXP_CALL_DGEMV_THREADS:-}"
preset_gemm_kernel="${HPL_MXP_PRESET_GEMM_KERNEL:-}"
cpu_affinity="${HPL_MXP_CPU_AFFINITY:-}"
mem_affinity="${HPL_MXP_MEM_AFFINITY:-}"
ucx_affinity="${HPL_MXP_UCX_AFFINITY:-}"
u_panel_chunk_nbs="${HPL_MXP_U_PANEL_CHUNK_NBS:-8}"
scaling_study="${HPL_MXP_SCALING_STUDY:-exploratory}"
baseline_matrix_size="${HPL_MXP_BASELINE_MATRIX_SIZE:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) cluster="${2:-}"; shift 2 ;;
    --nodes) node_count="${2:-}"; shift 2 ;;
    --matrix-size) matrix_size="${2:-}"; shift 2 ;;
    --nb) nb="${2:-}"; shift 2 ;;
    --nprow) nprow_override="${2:-}"; shift 2 ;;
    --npcol) npcol_override="${2:-}"; shift 2 ;;
    --preset) preset="${2:-}"; shift 2 ;;
    --image) image="${2:-}"; shift 2 ;;
    --sloppy-type) sloppy_type="${2:-}"; shift 2 ;;
    --test-loop) test_loop="${2:-}"; shift 2 ;;
    --ompi-coll) ompi_coll="${2:-}"; shift 2 ;;
    --ompi-pml) ompi_pml="${2:-}"; shift 2 ;;
    --ompi-btl) ompi_btl="${2:-}"; shift 2 ;;
    --ompi-btl-tcp-if-include) ompi_btl_tcp_if_include="${2:-}"; shift 2 ;;
    --ompi-oob-tcp-if-include) ompi_oob_tcp_if_include="${2:-}"; shift 2 ;;
    --ucx-tls) ucx_tls="${2:-}"; shift 2 ;;
    --ucx-net-devices) ucx_net_devices="${2:-}"; shift 2 ;;
    --pmix-mca-gds) pmix_mca_gds="${2:-}"; shift 2 ;;
    --mpi-use-mpi) mpi_use_mpi="${2:-}"; shift 2 ;;
    --use-mpi-panel-broadcast) mpi_panel_broadcast="${2:-}"; shift 2 ;;
    --prioritize-trsm) prioritize_trsm="${2:-}"; shift 2 ;;
    --prioritize-factorization) prioritize_factorization="${2:-}"; shift 2 ;;
    --anq-device) anq_device="${2:-}"; shift 2 ;;
    --fill-device) fill_device="${2:-}"; shift 2 ;;
    --fill-device-buffer-size) fill_device_buffer_size="${2:-}"; shift 2 ;;
    --call-dgemv-with-multiple-threads) call_dgemv_threads="${2:-}"; shift 2 ;;
    --preset-gemm-kernel) preset_gemm_kernel="${2:-}"; shift 2 ;;
    --cpu-affinity) cpu_affinity="${2:-}"; shift 2 ;;
    --mem-affinity) mem_affinity="${2:-}"; shift 2 ;;
    --ucx-affinity) ucx_affinity="${2:-}"; shift 2 ;;
    --u-panel-chunk-nbs) u_panel_chunk_nbs="${2:-}"; shift 2 ;;
    --scaling-study) scaling_study="${2:-}"; shift 2 ;;
    --baseline-matrix-size) baseline_matrix_size="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) aicr_die "unknown argument: $1" ;;
  esac
done

aicr_assert_supported_cluster "$cluster"
[[ "$node_count" =~ ^[0-9]+$ && "$node_count" -gt 0 ]] || aicr_die "--nodes must be a positive integer"
[[ "$matrix_size" =~ ^[0-9]+$ && "$matrix_size" -gt 0 ]] || aicr_die "--matrix-size must be a positive integer"
[[ "$nb" =~ ^[0-9]+$ && "$nb" -gt 0 ]] || aicr_die "--nb must be a positive integer"
[[ "$nprow_override" == "auto" || "$nprow_override" =~ ^[0-9]+$ ]] || aicr_die "--nprow must be auto or a positive integer"
[[ "$npcol_override" == "auto" || "$npcol_override" =~ ^[0-9]+$ ]] || aicr_die "--npcol must be auto or a positive integer"
[[ "$nprow_override" == "auto" || "$nprow_override" -gt 0 ]] || aicr_die "--nprow must be auto or a positive integer"
[[ "$npcol_override" == "auto" || "$npcol_override" -gt 0 ]] || aicr_die "--npcol must be auto or a positive integer"
if [[ "$preset" == "campaign" ]]; then
  preset="campaign-candidate"
fi
case "$preset" in smoke|staged|campaign-candidate|weak-study) ;; *) aicr_die "--preset must be smoke, staged, campaign-candidate, or weak-study" ;; esac
sloppy_type="$(printf '%s' "$sloppy_type" | tr '[:lower:]' '[:upper:]')"
case "$sloppy_type" in FP4|FP8|FP16) ;; *) aicr_die "--sloppy-type must be FP4, FP8, or FP16" ;; esac
if [[ "$sloppy_type" == "FP4" && "$cluster" != "$AICR_CLUSTER_B200" ]]; then
  aicr_die "--sloppy-type FP4 is supported by this public wrapper only for cluster=b200"
fi
[[ "$test_loop" =~ ^[0-9]+$ && "$test_loop" -gt 0 ]] || aicr_die "--test-loop must be a positive integer"
[[ "$mpi_use_mpi" =~ ^[01]$ ]] || aicr_die "--mpi-use-mpi must be 0 or 1"
[[ "$mpi_panel_broadcast" =~ ^[0-9]+$ && "$mpi_panel_broadcast" -le 100 ]] || aicr_die "--use-mpi-panel-broadcast must be 0..100"
[[ "$prioritize_trsm" =~ ^[01]$ ]] || aicr_die "--prioritize-trsm must be 0 or 1"
[[ "$prioritize_factorization" =~ ^[01]$ ]] || aicr_die "--prioritize-factorization must be 0 or 1"
[[ -z "$anq_device" || "$anq_device" =~ ^[0-9]+$ ]] || aicr_die "--anq-device must be a nonnegative integer"
[[ -z "$fill_device" || "$fill_device" =~ ^[01]$ ]] || aicr_die "--fill-device must be 0 or 1"
[[ -z "$fill_device_buffer_size" || "$fill_device_buffer_size" =~ ^[0-9]+$ ]] || aicr_die "--fill-device-buffer-size must be a nonnegative integer"
[[ -z "$call_dgemv_threads" || "$call_dgemv_threads" =~ ^[0-9]+$ ]] || aicr_die "--call-dgemv-with-multiple-threads must be a nonnegative integer"
[[ -z "$preset_gemm_kernel" || "$preset_gemm_kernel" =~ ^[0-9]+$ ]] || aicr_die "--preset-gemm-kernel must be a nonnegative integer"
[[ "$u_panel_chunk_nbs" =~ ^[0-9]+$ && "$u_panel_chunk_nbs" -gt 0 ]] || aicr_die "--u-panel-chunk-nbs must be a positive integer"
case "$scaling_study" in exploratory|strong|weak) ;; *) aicr_die "--scaling-study must be exploratory, strong, or weak" ;; esac
[[ -z "$baseline_matrix_size" || "$baseline_matrix_size" =~ ^[0-9]+$ ]] || aicr_die "--baseline-matrix-size must be a positive integer"
[[ -z "$baseline_matrix_size" || "$baseline_matrix_size" -gt 0 ]] || aicr_die "--baseline-matrix-size must be a positive integer"
[[ -f "$image" ]] || aicr_die "HPL-MxP image not found: $image"
case "$ompi_coll" in
  none|default) ompi_coll="" ;;
esac
case "$ompi_pml" in
  none|default) ompi_pml="" ;;
esac
case "$ompi_btl" in
  none|default) ompi_btl="" ;;
esac
case "$ompi_btl_tcp_if_include" in
  none|default) ompi_btl_tcp_if_include="" ;;
esac
case "$ompi_oob_tcp_if_include" in
  none|default) ompi_oob_tcp_if_include="" ;;
esac
case "$ucx_tls" in
  none|default) ucx_tls="" ;;
esac
case "$ucx_net_devices" in
  none|default) ucx_net_devices="" ;;
esac
case "$pmix_mca_gds" in
  none|default) pmix_mca_gds="" ;;
esac

date_utc="$(aicr_today_date)"
node_short="$(hostname -s 2>/dev/null || hostname)"
peer_nodes_csv="$(scontrol show hostnames "${SLURM_JOB_NODELIST:-}" 2>/dev/null | paste -sd, - || true)"
if [[ -z "$peer_nodes_csv" ]]; then
  peer_nodes_csv="$node_short"
fi
job_id="${SLURM_JOB_ID:-}"
if [[ -n "${HPL_MXP_RUN_ID:-}" ]]; then
  run_id="$HPL_MXP_RUN_ID"
else
  run_id="$(aicr_next_by_date_run_id "$date_utc" "$cluster" "$AICR_SCOPE_MULTI_NODE" "$AICR_CHECK_HPL_MXP")"
  if [[ -n "$job_id" ]]; then
    run_id="${run_id}-j${job_id}"
  fi
fi

raw_rel="$(aicr_multi_node_raw_run_dir "$date_utc" "$cluster" "$AICR_CHECK_HPL_MXP" "$run_id")"
parsed_rel="$(aicr_multi_node_parsed_run_dir "$date_utc" "$cluster" "$AICR_CHECK_HPL_MXP" "$run_id")"
raw_abs="${AICR_BMARK_DIR}/${raw_rel}"
parsed_abs="${AICR_BMARK_DIR}/${parsed_rel}"
canonical_abs="${raw_abs}/canonical"
metadata_abs="${raw_abs}/metadata"
wrapper_abs="${raw_abs}/wrapper"
mkdir -p "$canonical_abs" "$metadata_abs" "$wrapper_abs" "$parsed_abs"

command_rel="${raw_rel}/canonical/hpl-mxp-command.txt"
stdout_rel="${raw_rel}/canonical/hpl-mxp-stdout.txt"
stderr_rel="${raw_rel}/canonical/hpl-mxp-stderr.txt"
preflight_rel="${raw_rel}/canonical/gpu-preflight.txt"
postflight_rel="${raw_rel}/canonical/gpu-postflight.txt"
summary_txt_rel="${raw_rel}/canonical/hpl-mxp-summary.txt"
record_rel="${raw_rel}/metadata/record.json"
summary_json_rel="${parsed_rel}/summary.json"
status_rel="${parsed_rel}/status.json"

command_abs="${AICR_BMARK_DIR}/${command_rel}"
stdout_abs="${AICR_BMARK_DIR}/${stdout_rel}"
stderr_abs="${AICR_BMARK_DIR}/${stderr_rel}"
preflight_abs="${AICR_BMARK_DIR}/${preflight_rel}"
postflight_abs="${AICR_BMARK_DIR}/${postflight_rel}"
summary_txt_abs="${AICR_BMARK_DIR}/${summary_txt_rel}"
record_abs="${AICR_BMARK_DIR}/${record_rel}"
summary_json_abs="${AICR_BMARK_DIR}/${summary_json_rel}"
status_abs="${AICR_BMARK_DIR}/${status_rel}"

total_ranks=$((node_count * 8))
case "$total_ranks" in
  8) nprow=2; npcol=4 ;;
  16) nprow=4; npcol=4 ;;
  32) nprow=4; npcol=8 ;;
  64) nprow=8; npcol=8 ;;
  128) nprow=8; npcol=16 ;;
  *) aicr_die "no HPL-MxP smoke processor-grid policy for ${total_ranks} ranks" ;;
esac
if [[ "$nprow_override" != "auto" ]]; then
  nprow="$nprow_override"
fi
if [[ "$npcol_override" != "auto" ]]; then
  npcol="$npcol_override"
fi
if (( nprow * npcol != total_ranks )); then
  aicr_die "processor grid ${nprow}x${npcol} does not match rank count ${total_ranks}"
fi

read -r -a apptainer_common_opts <<<"${AICR_APPTAINER_COMMON_OPTS}"
hpl_args=(
  /workspace/hpl-mxp.sh
  --gpu-affinity 0:1:2:3:4:5:6:7
  --n "$matrix_size"
  --nb "$nb"
  --nprow "$nprow"
  --npcol "$npcol"
  --nporder row
  --test-loop "$test_loop"
  --sloppy-type "$sloppy_type"
  --u-panel-chunk-nbs "$u_panel_chunk_nbs"
  --use-mpi-panel-broadcast "$mpi_panel_broadcast"
  --mpi-use-mpi "$mpi_use_mpi"
  --prioritize-trsm "$prioritize_trsm"
  --prioritize-factorization "$prioritize_factorization"
)
if [[ -n "$cpu_affinity" ]]; then
  hpl_args+=(--cpu-affinity "$cpu_affinity")
fi
if [[ -n "$mem_affinity" ]]; then
  hpl_args+=(--mem-affinity "$mem_affinity")
fi
if [[ -n "$ucx_affinity" ]]; then
  hpl_args+=(--ucx-affinity "$ucx_affinity")
fi
if [[ -n "$call_dgemv_threads" ]]; then
  hpl_args+=(--call-dgemv-with-multiple-threads "$call_dgemv_threads")
fi
if [[ -n "$preset_gemm_kernel" ]]; then
  hpl_args+=(--preset-gemm-kernel "$preset_gemm_kernel")
fi
if [[ -n "$anq_device" ]]; then
  hpl_args+=(--Anq-device "$anq_device")
fi
if [[ -n "$fill_device" ]]; then
  hpl_args+=(--fill-device "$fill_device")
fi
if [[ -n "$fill_device_buffer_size" ]]; then
  hpl_args+=(--fill-device-buffer-size "$fill_device_buffer_size")
fi
run_cmd=(
  srun
  --mpi=pmix
  --nodes "$node_count"
  --ntasks "$total_ranks"
  --ntasks-per-node 8
  --cpu-bind=none
  --mem-bind=none
  apptainer exec
  "${apptainer_common_opts[@]}"
  --nv
  "$image"
  "${hpl_args[@]}"
)
: >"$command_abs"
if [[ -n "$ompi_coll" ]]; then
  export OMPI_MCA_coll="$ompi_coll"
  printf 'OMPI_MCA_coll=%q ' "$ompi_coll" >>"$command_abs"
fi
if [[ -n "$ompi_pml" ]]; then
  export OMPI_MCA_pml="$ompi_pml"
  printf 'OMPI_MCA_pml=%q ' "$ompi_pml" >>"$command_abs"
fi
if [[ -n "$ompi_btl" ]]; then
  export OMPI_MCA_btl="$ompi_btl"
  printf 'OMPI_MCA_btl=%q ' "$ompi_btl" >>"$command_abs"
fi
if [[ -n "$ompi_btl_tcp_if_include" ]]; then
  export OMPI_MCA_btl_tcp_if_include="$ompi_btl_tcp_if_include"
  printf 'OMPI_MCA_btl_tcp_if_include=%q ' "$ompi_btl_tcp_if_include" >>"$command_abs"
fi
if [[ -n "$ompi_oob_tcp_if_include" ]]; then
  export OMPI_MCA_oob_tcp_if_include="$ompi_oob_tcp_if_include"
  printf 'OMPI_MCA_oob_tcp_if_include=%q ' "$ompi_oob_tcp_if_include" >>"$command_abs"
fi
if [[ -n "$ucx_tls" ]]; then
  export UCX_TLS="$ucx_tls"
  printf 'UCX_TLS=%q ' "$ucx_tls" >>"$command_abs"
fi
if [[ -n "$ucx_net_devices" ]]; then
  export UCX_NET_DEVICES="$ucx_net_devices"
  printf 'UCX_NET_DEVICES=%q ' "$ucx_net_devices" >>"$command_abs"
fi
if [[ -n "$pmix_mca_gds" ]]; then
  export PMIX_MCA_gds="$pmix_mca_gds"
  printf 'PMIX_MCA_gds=%q ' "$pmix_mca_gds" >>"$command_abs"
fi
printf 'HPL_MXP_SCALING_STUDY=%q ' "$scaling_study" >>"$command_abs"
if [[ -n "$baseline_matrix_size" ]]; then
  printf 'HPL_MXP_BASELINE_MATRIX_SIZE=%q ' "$baseline_matrix_size" >>"$command_abs"
fi
printf '%q ' "${run_cmd[@]}" >>"$command_abs"
printf '\n' >>"$command_abs"

submitted_at_utc="$(aicr_timestamp_utc)"
launched_at_utc="$submitted_at_utc"
completed_at_utc=""
partition="${SLURM_JOB_PARTITION:-${SLURM_JOB_PARTITION_NAME:-unknown}}"
cpus_per_task="${SLURM_CPUS_PER_TASK:-}"
status="not-run"
return_code=""
notes=""
: >"$stdout_abs"
: >"$stderr_abs"
: >"$postflight_abs"

capture_gpu_inventory() {
  local output_path="$1"
  srun --nodes "$node_count" --ntasks "$node_count" --ntasks-per-node 1 bash -lc 'host="$(hostname -s)"; echo "${host}|NODE"; nvidia-smi -L | sed "s/^/${host}|/"' >"$output_path" 2>>"$stderr_abs"
}

classify_gpu_inventory() {
  local input_path="$1"
  aicr_python - "$input_path" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
counts = {}
errors = {}
for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
    if "|" not in line:
        continue
    node, payload = line.split("|", 1)
    if payload == "NODE":
        counts.setdefault(node, 0)
        errors.setdefault(node, [])
    elif payload.startswith("GPU "):
        counts[node] = counts.get(node, 0) + 1
    elif "Unable to determine the device handle" in payload:
        errors.setdefault(node, []).append(payload)

bad = []
for node in sorted(counts):
    count = counts.get(node, 0)
    node_errors = errors.get(node, [])
    if count != 8 or node_errors:
        suffix = f"{node}:{count}"
        if node_errors:
            suffix += ":device-handle-error"
        bad.append(suffix)
if len(counts) == 0:
    bad.append("no-node-output:0")
print(",".join(bad))
PY
}

set +e
capture_gpu_inventory "$preflight_abs"
preflight_rc=$?
set -e
if [[ "$preflight_rc" -ne 0 ]]; then
  status="failed"
  return_code="$preflight_rc"
  notes="GPU preflight command failed"
else
  bad_preflight="$(classify_gpu_inventory "$preflight_abs")"
  if [[ -n "$bad_preflight" ]]; then
    status="skipped"
    return_code=""
    notes="GPU preflight failed: ${bad_preflight}"
  else
    set +e
    "${run_cmd[@]}" >"$stdout_abs" 2>>"$stderr_abs"
    rc=$?
    set -e
    return_code="$rc"
    if [[ "$rc" -eq 0 ]]; then
      status="passed"
    else
      status="failed"
      notes="HPL-MxP command failed"
    fi
    set +e
    capture_gpu_inventory "$postflight_abs"
    postflight_rc=$?
    set -e
    if [[ "$postflight_rc" -ne 0 ]]; then
      status="failed"
      return_code="$postflight_rc"
      if [[ -n "$notes" ]]; then
        notes="${notes}; GPU postflight command failed"
      else
        notes="GPU postflight command failed"
      fi
    else
      bad_postflight="$(classify_gpu_inventory "$postflight_abs")"
      if [[ -n "$bad_postflight" ]]; then
        status="failed"
        if [[ -z "$return_code" || "$return_code" -eq 0 ]]; then
          return_code=1
        fi
        if [[ -n "$notes" ]]; then
          notes="${notes}; GPU postflight failed: ${bad_postflight}"
        else
          notes="GPU postflight failed: ${bad_postflight}"
        fi
      fi
    fi
  fi
fi
completed_at_utc="$(aicr_timestamp_utc)"

export cluster date_utc run_id node_short peer_nodes_csv node_count total_ranks matrix_size nb nprow npcol sloppy_type test_loop ompi_coll ompi_pml ompi_btl ompi_btl_tcp_if_include ompi_oob_tcp_if_include ucx_tls ucx_net_devices preset
export pmix_mca_gds mpi_use_mpi mpi_panel_broadcast prioritize_trsm prioritize_factorization
export anq_device fill_device fill_device_buffer_size call_dgemv_threads preset_gemm_kernel cpu_affinity mem_affinity ucx_affinity u_panel_chunk_nbs
export scaling_study baseline_matrix_size
export status return_code notes submitted_at_utc launched_at_utc completed_at_utc partition job_id image cpus_per_task
export raw_rel parsed_rel command_rel stdout_rel stderr_rel preflight_rel postflight_rel summary_txt_rel record_rel summary_json_rel status_rel
export stdout_abs stderr_abs preflight_abs postflight_abs summary_txt_abs summary_json_abs status_abs record_abs

aicr_python - <<'PY'
import json
import os
import re
from pathlib import Path


def maybe_int(value):
    if value in (None, ""):
        return None
    try:
        return int(value)
    except ValueError:
        return None


def maybe_float(value):
    if value in (None, ""):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def first_float(patterns, text):
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            try:
                return float(match.group(1).replace(",", ""))
            except ValueError:
                return None
    return None


stdout_text = Path(os.environ["stdout_abs"]).read_text(encoding="utf-8", errors="replace") if Path(os.environ["stdout_abs"]).exists() else ""
stderr_text = Path(os.environ["stderr_abs"]).read_text(encoding="utf-8", errors="replace") if Path(os.environ["stderr_abs"]).exists() else ""
combined = stdout_text + "\n" + stderr_text
anq_device = maybe_int(os.environ.get("anq_device", ""))
fill_device = maybe_int(os.environ.get("fill_device", ""))
fill_device_buffer_size = maybe_int(os.environ.get("fill_device_buffer_size", ""))
call_dgemv_threads = maybe_int(os.environ.get("call_dgemv_threads", ""))
preset_gemm_kernel = maybe_int(os.environ.get("preset_gemm_kernel", ""))
cpu_affinity = os.environ.get("cpu_affinity") or None
mem_affinity = os.environ.get("mem_affinity") or None
ucx_affinity = os.environ.get("ucx_affinity") or None
u_panel_chunk_nbs = maybe_int(os.environ.get("u_panel_chunk_nbs", ""))
mpi_use_mpi = maybe_int(os.environ.get("mpi_use_mpi", ""))
mpi_panel_broadcast = maybe_int(os.environ.get("mpi_panel_broadcast", ""))
prioritize_trsm = maybe_int(os.environ.get("prioritize_trsm", ""))
prioritize_factorization = maybe_int(os.environ.get("prioritize_factorization", ""))
scaling_study = os.environ.get("scaling_study") or "exploratory"
baseline_matrix_size = maybe_int(os.environ.get("baseline_matrix_size", ""))
if fill_device == 1:
    fp64_placement_policy = "fill-device=1; HPL-MxP places FP64 matrix data on GPU until buffer reserve is reached"
elif anq_device is not None:
    fp64_placement_policy = f"Anq-device={anq_device}; HPL-MxP places this many FP64 matrix columns on GPU"
else:
    fp64_placement_policy = "hpl-mxp default; no --Anq-device or --fill-device override"


CAMPAIGN_TARGETS = {
    ("b200", 1): 417000,
    ("b200", 4): 834000,
    ("b200", 16): 1668000,
    ("rtxpro6000", 1): 409600,
    ("rtxpro6000", 4): 409600,
}
WEAK_STUDY_TARGETS = {
    ("b200", 1): 379904,
    ("b200", 2): 530432,
    ("b200", 4): 749568,
    ("b200", 8): 1049600,
    ("b200", 16): 1500160,
    ("rtxpro6000", 1): 379904,
    ("rtxpro6000", 2): 530432,
    ("rtxpro6000", 4): 749568,
}
GIB = 1024 ** 3

performance_pflops = first_float([
    r"([+-]?[0-9][0-9,]*(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\s*(?:peta)?flop/s",
    r"([+-]?[0-9][0-9,]*(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\s*pflops?",
], combined)
if performance_pflops is None:
    tflops = first_float([
        r"([+-]?[0-9][0-9,]*(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\s*(?:tera)?flop/s",
        r"([+-]?[0-9][0-9,]*(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\s*tflops?",
    ], combined)
    if tflops is not None:
        performance_pflops = tflops / 1000.0
if performance_pflops is None:
    gflops = first_float([
        r"\bGFLOPS\s*=\s*([+-]?[0-9][0-9,]*(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)",
        r"([+-]?[0-9][0-9,]*(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\s*gflops?",
    ], combined)
    if gflops is not None:
        performance_pflops = gflops / 1_000_000.0

residual_check = None
residual_block = re.search(r"HPL MxP Result(.+?)(?:test loop|test\s+\d+|\Z)", combined, re.IGNORECASE | re.DOTALL)
residual_target = residual_block.group(1) if residual_block else combined
if re.search(r"\b(fail|failed|incorrect|wrong)\b", residual_target, re.IGNORECASE):
    residual_check = "failed"
elif re.search(r"\b(pass|passed|successful)\b", residual_target, re.IGNORECASE):
    residual_check = "passed"

peers = [item for item in os.environ["peer_nodes_csv"].split(",") if item]
return_code = maybe_int(os.environ.get("return_code", ""))
cluster = os.environ["cluster"]
node_count = maybe_int(os.environ["node_count"])
matrix_size = maybe_int(os.environ["matrix_size"])
preset = os.environ["preset"]
if baseline_matrix_size is None and scaling_study == "strong":
    baseline_matrix_size = matrix_size
if scaling_study == "strong" and node_count == 1 and baseline_matrix_size == matrix_size:
    scaling_role = "baseline"
elif scaling_study == "strong":
    scaling_role = "strong-scale"
elif scaling_study in ("weak", "weak80", "weak90"):
    scaling_role = "capacity"
else:
    scaling_role = "exploratory"
target_map = WEAK_STUDY_TARGETS if preset == "weak-study" else CAMPAIGN_TARGETS
campaign_target_matrix_size = target_map.get((cluster, node_count))
campaign_sized = False
if preset == "staged":
    evidence_type = "staged"
elif preset == "campaign-candidate":
    evidence_type = "staged"
elif preset == "weak-study":
    evidence_type = "campaign"
elif preset == "smoke" and matrix_size == 8192:
    evidence_type = "smoke"
else:
    evidence_type = "staged"

rank_count = maybe_int(os.environ["total_ranks"])
dense_fp64_matrix_bytes = matrix_size * matrix_size * 8 if matrix_size else None
dense_fp64_matrix_gib = dense_fp64_matrix_bytes / GIB if dense_fp64_matrix_bytes is not None else None
dense_fp64_matrix_gib_per_rank = (
    dense_fp64_matrix_gib / rank_count
    if dense_fp64_matrix_gib is not None and rank_count
    else None
)
campaign_size_ratio = (
    (matrix_size / campaign_target_matrix_size) ** 2
    if matrix_size and campaign_target_matrix_size
    else None
)
campaign_size_percent = campaign_size_ratio * 100.0 if campaign_size_ratio is not None else None
campaign_sized = bool(campaign_size_ratio is not None and campaign_size_ratio >= 1.0)
summary = {
    "schema_version": 1,
    "status": os.environ["status"],
    "cluster": cluster,
    "date": os.environ["date_utc"],
    "run_id": os.environ["run_id"],
    "node": os.environ["node_short"],
    "peer_nodes": peers,
    "node_count": node_count,
    "gpu_count": maybe_int(os.environ["total_ranks"]),
    "rank_count": rank_count,
    "job_id": os.environ["job_id"] or None,
    "partition": os.environ["partition"],
    "cpus_per_task": maybe_int(os.environ.get("cpus_per_task", "")),
    "image": os.environ["image"],
    "preset": preset,
    "evidence_type": evidence_type,
    "scaling_study": scaling_study,
    "scaling_role": scaling_role,
    "baseline_matrix_size": baseline_matrix_size,
    "campaign_target_matrix_size": campaign_target_matrix_size,
    "campaign_sized": campaign_sized,
    "matrix_size": matrix_size,
    "nb": maybe_int(os.environ["nb"]),
    "nprow": maybe_int(os.environ["nprow"]),
    "npcol": maybe_int(os.environ["npcol"]),
    "processor_grid": f"{os.environ['nprow']}x{os.environ['npcol']}",
    "nporder": "row",
    "dense_fp64_matrix_bytes": dense_fp64_matrix_bytes,
    "dense_fp64_matrix_gib": dense_fp64_matrix_gib,
    "dense_fp64_matrix_gib_per_rank": dense_fp64_matrix_gib_per_rank,
    "campaign_size_ratio": campaign_size_ratio,
    "campaign_size_percent": campaign_size_percent,
    "fp64_placement_policy": fp64_placement_policy,
    "anq_device": anq_device,
    "fill_device": fill_device,
    "fill_device_buffer_size_mb": fill_device_buffer_size,
    "call_dgemv_with_multiple_threads": call_dgemv_threads,
    "preset_gemm_kernel": preset_gemm_kernel,
    "gpu_affinity": "0:1:2:3:4:5:6:7",
    "cpu_affinity": cpu_affinity,
    "mem_affinity": mem_affinity,
    "ucx_affinity": ucx_affinity,
    "sizing_note": "Dense FP64 matrix footprint is a planning estimate, not exact GPU memory allocation.",
    "sloppy_type": os.environ["sloppy_type"],
    "sloppy_precision": os.environ["sloppy_type"],
    "u_panel_chunk_nbs": u_panel_chunk_nbs,
    "test_loop": maybe_int(os.environ["test_loop"]),
    "ompi_mca_coll": os.environ["ompi_coll"] or None,
    "ompi_mca_pml": os.environ["ompi_pml"] or None,
    "ompi_mca_btl": os.environ["ompi_btl"] or None,
    "ompi_mca_btl_tcp_if_include": os.environ["ompi_btl_tcp_if_include"] or None,
    "ompi_mca_oob_tcp_if_include": os.environ["ompi_oob_tcp_if_include"] or None,
    "ucx_tls": os.environ["ucx_tls"] or None,
    "ucx_net_devices": os.environ["ucx_net_devices"] or None,
    "pmix_mca_gds": os.environ["pmix_mca_gds"] or None,
    "mpi_use_mpi": mpi_use_mpi,
    "mpi_panel_broadcast_percent": mpi_panel_broadcast,
    "prioritize_trsm": prioritize_trsm,
    "prioritize_factorization": prioritize_factorization,
    "return_code": return_code,
    "performance_pflops": performance_pflops,
    "efficiency_percent": None,
    "scaling_efficiency_percent": None,
    "residual_check": residual_check,
    "stdout_file": os.environ["stdout_rel"],
    "stderr_file": os.environ["stderr_rel"],
    "preflight_file": os.environ["preflight_rel"],
    "postflight_file": os.environ["postflight_rel"],
    "command_file": os.environ["command_rel"],
    "summary_path": os.environ["summary_json_rel"],
    "notes": os.environ["notes"],
}
status = {
    "status": os.environ["status"],
    "pass_basis": f"return_code=0 and guarded {cluster} GPU preflight/postflight passed",
    "return_code": return_code,
    "residual_check": residual_check,
}
record = {
    "schema_version": 1,
    "scope": "multi-node",
    "cluster": os.environ["cluster"],
    "node": None,
    "peer_nodes": peers,
    "check": "hpl-mxp",
    "subcheck": f"{cluster}-{evidence_type}",
    "mode": f"benchmark-hpl-mxp-{evidence_type}",
    "run_id": os.environ["run_id"],
    "date": os.environ["date_utc"],
    "submitted_at_utc": os.environ["submitted_at_utc"],
    "launched_at_utc": os.environ["launched_at_utc"],
    "completed_at_utc": os.environ["completed_at_utc"],
    "partition": os.environ["partition"],
    "job_id": os.environ["job_id"] or None,
    "status": os.environ["status"],
    "pass_basis": status["pass_basis"],
    "notes": os.environ["notes"],
    "node_count": maybe_int(os.environ["node_count"]),
    "gpu_count": maybe_int(os.environ["total_ranks"]),
    "wrapper_log_paths": [],
    "canonical_artifact_paths": [
        os.environ["command_rel"],
        os.environ["stdout_rel"],
        os.environ["stderr_rel"],
        os.environ["preflight_rel"],
        os.environ["postflight_rel"],
        os.environ["summary_txt_rel"],
    ],
    "parsed_artifact_paths": [
        os.environ["summary_json_rel"],
        os.environ["status_rel"],
    ],
    "setup_baseline_ref": {
        "cluster": os.environ["cluster"],
        "baseline_path": f"results/setup/{os.environ['cluster']}/baseline.json",
        "baseline_id": None,
    },
}
lines = [
    f"cluster={summary['cluster']}",
    f"date={summary['date']}",
    f"run_id={summary['run_id']}",
    f"node_count={summary['node_count']}",
    f"gpu_count={summary['gpu_count']}",
    f"rank_count={summary['rank_count']}",
    f"peer_nodes={','.join(peers)}",
    f"job_id={summary['job_id'] or ''}",
    f"partition={summary['partition']}",
    f"cpus_per_task={summary['cpus_per_task'] if summary['cpus_per_task'] is not None else ''}",
    f"status={summary['status']}",
    f"return_code={summary['return_code'] if summary['return_code'] is not None else ''}",
    f"matrix_size={summary['matrix_size']}",
    f"preset={summary['preset']}",
    f"evidence_type={summary['evidence_type']}",
    f"scaling_study={summary['scaling_study']}",
    f"scaling_role={summary['scaling_role']}",
    f"baseline_matrix_size={summary['baseline_matrix_size'] if summary['baseline_matrix_size'] is not None else ''}",
    f"campaign_target_matrix_size={summary['campaign_target_matrix_size'] if summary['campaign_target_matrix_size'] is not None else ''}",
    f"campaign_sized={str(summary['campaign_sized']).lower()}",
    f"nb={summary['nb']}",
    f"nprow={summary['nprow']}",
    f"npcol={summary['npcol']}",
    f"processor_grid={summary['processor_grid']}",
    f"dense_fp64_matrix_gib={summary['dense_fp64_matrix_gib'] if summary['dense_fp64_matrix_gib'] is not None else ''}",
    f"dense_fp64_matrix_gib_per_rank={summary['dense_fp64_matrix_gib_per_rank'] if summary['dense_fp64_matrix_gib_per_rank'] is not None else ''}",
    f"campaign_size_ratio={summary['campaign_size_ratio'] if summary['campaign_size_ratio'] is not None else ''}",
    f"campaign_size_percent={summary['campaign_size_percent'] if summary['campaign_size_percent'] is not None else ''}",
    f"fp64_placement_policy={summary['fp64_placement_policy']}",
    f"anq_device={summary['anq_device'] if summary['anq_device'] is not None else ''}",
    f"fill_device={summary['fill_device'] if summary['fill_device'] is not None else ''}",
    f"fill_device_buffer_size_mb={summary['fill_device_buffer_size_mb'] if summary['fill_device_buffer_size_mb'] is not None else ''}",
    f"call_dgemv_with_multiple_threads={summary['call_dgemv_with_multiple_threads'] if summary['call_dgemv_with_multiple_threads'] is not None else ''}",
    f"preset_gemm_kernel={summary['preset_gemm_kernel'] if summary['preset_gemm_kernel'] is not None else ''}",
    f"gpu_affinity={summary['gpu_affinity'] or ''}",
    f"cpu_affinity={summary['cpu_affinity'] or ''}",
    f"mem_affinity={summary['mem_affinity'] or ''}",
    f"ucx_affinity={summary['ucx_affinity'] or ''}",
    f"sloppy_type={summary['sloppy_type']}",
    f"u_panel_chunk_nbs={summary['u_panel_chunk_nbs'] if summary['u_panel_chunk_nbs'] is not None else ''}",
    f"ompi_mca_coll={summary['ompi_mca_coll'] or ''}",
    f"ompi_mca_pml={summary['ompi_mca_pml'] or ''}",
    f"ompi_mca_btl={summary['ompi_mca_btl'] or ''}",
    f"ompi_mca_btl_tcp_if_include={summary['ompi_mca_btl_tcp_if_include'] or ''}",
    f"ompi_mca_oob_tcp_if_include={summary['ompi_mca_oob_tcp_if_include'] or ''}",
    f"ucx_tls={summary['ucx_tls'] or ''}",
    f"ucx_net_devices={summary['ucx_net_devices'] or ''}",
    f"pmix_mca_gds={summary['pmix_mca_gds'] or ''}",
    f"mpi_use_mpi={summary['mpi_use_mpi'] if summary['mpi_use_mpi'] is not None else ''}",
    f"mpi_panel_broadcast_percent={summary['mpi_panel_broadcast_percent'] if summary['mpi_panel_broadcast_percent'] is not None else ''}",
    f"prioritize_trsm={summary['prioritize_trsm'] if summary['prioritize_trsm'] is not None else ''}",
    f"prioritize_factorization={summary['prioritize_factorization'] if summary['prioritize_factorization'] is not None else ''}",
    f"performance_pflops={summary['performance_pflops'] if summary['performance_pflops'] is not None else ''}",
    f"residual_check={summary['residual_check'] or ''}",
    f"notes={summary['notes']}",
]
Path(os.environ["summary_txt_abs"]).write_text("\n".join(lines) + "\n", encoding="utf-8")
for path_name, obj in (
    ("summary_json_abs", summary),
    ("status_abs", status),
    ("record_abs", record),
):
    with open(os.environ[path_name], "w", encoding="utf-8") as handle:
        json.dump(obj, handle, indent=2)
        handle.write("\n")
PY

aicr_append_index_row_from_record "${AICR_BMARK_DIR}/$(aicr_by_date_index_path "$date_utc")" "$record_abs"

echo "Wrote ${record_rel}"
echo "Wrote ${summary_json_rel}"
echo "Wrote ${status_rel}"

if [[ "$status" == "failed" && -n "$return_code" ]]; then
  exit "$return_code"
fi
