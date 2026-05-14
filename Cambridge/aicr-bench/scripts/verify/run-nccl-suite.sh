#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage: scripts/verify/run-nccl-suite.sh --scope <local|rdma|survey> [options]
       scripts/verify/run-nccl-suite.sh --profile <small|medium|large> --inspect-profile

Run the fully instrumented NCCL suite inside an existing Slurm allocation.

Options:
  --scope <local|rdma|survey>
                            Suite scope
  --cluster <name>          b200 or rtxpro6000 (default: detected/env)
  --profile <name>          small, medium, or large (default: small)
  --suite-class <name>      Optional local suite class filter
  --nodes-per-job <n>       Multi-node node count metadata (default: Slurm nodelist count)
  --inspect-profile         Print the selected profile without running NCCL
  -h, --help                Show this help

Environment overrides:
  HPCBENCH_IMAGE
  NCCL_SUITE_RUN_ID
  NCCL_SUITE_OPS
  NCCL_DEBUG_FILE
EOF
}

print_profile() {
  local selected="$1"
  local min_bytes max_bytes step_factor warmup_iters iters requested_check_iters
  case "${selected}" in
    small)
      min_bytes="8"
      max_bytes="1G"
      step_factor="2"
      warmup_iters="5"
      iters="20"
      requested_check_iters="0"
      ;;
    medium)
      min_bytes="1M"
      max_bytes="4G"
      step_factor="2"
      warmup_iters="20"
      iters="100"
      requested_check_iters="0"
      ;;
    large)
      min_bytes="1M"
      max_bytes="8G"
      step_factor="2"
      warmup_iters="40"
      iters="200"
      requested_check_iters="0"
      ;;
    *)
      echo "ERROR: unsupported --profile: ${selected}" >&2
      echo "Expected one of: small, medium, large" >&2
      exit 2
      ;;
  esac
  printf 'profile=%s\n' "${selected}"
  printf 'min_bytes=%s\n' "${min_bytes}"
  printf 'max_bytes=%s\n' "${max_bytes}"
  printf 'step_factor=%s\n' "${step_factor}"
  printf 'warmup_iters=%s\n' "${warmup_iters}"
  printf 'iters=%s\n' "${iters}"
  printf 'requested_check_iters=%s\n' "${requested_check_iters}"
}

scope=""
cluster="${AICR_CLUSTER_NAME:-}"
profile="${PROFILE:-small}"
suite_class_filter="${NCCL_SUITE_CLASS:-}"
nodes_per_job=""
suite_ops_filter="${NCCL_SUITE_OPS:-}"
inspect_profile=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)
      scope="${2:?missing value for --scope}"
      shift 2
      ;;
    --cluster)
      cluster="${2:?missing value for --cluster}"
      shift 2
      ;;
    --profile)
      profile="${2:?missing value for --profile}"
      shift 2
      ;;
    --suite-class)
      suite_class_filter="${2:?missing value for --suite-class}"
      shift 2
      ;;
    --nodes-per-job)
      nodes_per_job="${2:?missing value for --nodes-per-job}"
      shift 2
      ;;
    --inspect-profile)
      inspect_profile=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

case "${profile}" in
  small)
    min_bytes="8"
    max_bytes="1G"
    step_factor="2"
    warmup_iters="5"
    iters="20"
    requested_check_iters="0"
    ;;
  medium)
    min_bytes="1M"
    max_bytes="4G"
    step_factor="2"
    warmup_iters="20"
    iters="100"
    requested_check_iters="0"
    ;;
  large)
    min_bytes="1M"
    max_bytes="8G"
    step_factor="2"
    warmup_iters="40"
    iters="200"
    requested_check_iters="0"
    ;;
  *)
    echo "ERROR: unsupported --profile: ${profile}" >&2
    echo "Expected one of: small, medium, large" >&2
    exit 2
    ;;
esac
if [[ "${inspect_profile}" == "1" ]]; then
  print_profile "${profile}"
  exit 0
fi

[[ -n "${scope}" ]] || { echo "ERROR: --scope is required" >&2; usage; exit 2; }
case "${scope}" in
  local|rdma|survey) ;;
  *) echo "ERROR: --scope must be local, rdma, or survey" >&2; exit 2 ;;
esac

cluster="${cluster:-$(aicr_cluster_name)}"
aicr_assert_supported_cluster "${cluster}"

if [[ -n "${suite_class_filter}" ]]; then
  if [[ "${scope}" != "local" ]]; then
    echo "ERROR: --suite-class is supported only with --scope local" >&2
    exit 2
  fi
  case "${cluster}:${suite_class_filter}" in
    b200:b200_1proc_8g|b200:b200_8rank_1g|b200:b200_2rank_socket_4g|rtxpro6000:rtx_8rank_1g|rtxpro6000:rtx_pair_policy) ;;
    *)
      echo "ERROR: unsupported --suite-class ${suite_class_filter} for ${cluster}" >&2
      exit 2
      ;;
  esac
fi

aicr_require_repo_root
aicr_mkdirs

date_utc="$(aicr_today_date)"
node_short="$(hostname -s 2>/dev/null || hostname)"
check="nccl-suite-${scope}"
mode="nccl-suite-${scope}"
image="${HPCBENCH_IMAGE:-${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif}"
wrapper="/workspace/microbenchmarks/nccl_tests.sh"
apptainer_opts="${AICR_APPTAINER_COMMON_OPTS} --nv"
read -r -a apptainer_opt_args <<<"${apptainer_opts}"

if [[ "${scope}" == "local" ]]; then
  run_id="${NCCL_SUITE_RUN_ID:-$(aicr_next_by_date_run_id "$date_utc" "$cluster" "$AICR_SCOPE_NODE" "$check" "$node_short")}"
  raw_rel="$(aicr_node_raw_run_dir "$date_utc" "$cluster" "$node_short" "$check" "$run_id")"
  parsed_rel="$(aicr_node_parsed_run_dir "$date_utc" "$cluster" "$node_short" "$check" "$run_id")"
  record_rel="$(aicr_node_record_path "$date_utc" "$cluster" "$node_short" "$check" "$run_id")"
  peer_nodes_csv=""
  node_count=1
else
  peer_nodes_csv="${PEER_NODES_CSV:-$(scontrol show hostnames "${SLURM_JOB_NODELIST:-}" 2>/dev/null | paste -sd, -)}"
  [[ -n "${peer_nodes_csv}" ]] || peer_nodes_csv="${node_short}"
  if [[ -z "${nodes_per_job}" ]]; then
    nodes_per_job="$(awk -F',' '{print NF}' <<<"${peer_nodes_csv}")"
  fi
  node_count="${nodes_per_job}"
  run_id="${NCCL_SUITE_RUN_ID:-$(aicr_next_by_date_run_id "$date_utc" "$cluster" "$AICR_SCOPE_MULTI_NODE" "$check")}"
  raw_rel="$(aicr_multi_node_raw_run_dir "$date_utc" "$cluster" "$check" "$run_id")"
  parsed_rel="$(aicr_multi_node_parsed_run_dir "$date_utc" "$cluster" "$check" "$run_id")"
  record_rel="$(aicr_multi_node_record_path "$date_utc" "$cluster" "$check" "$run_id")"
fi

raw_abs="${AICR_BMARK_DIR}/${raw_rel}"
parsed_abs="${AICR_BMARK_DIR}/${parsed_rel}"
mkdir -p "${raw_abs}/canonical" "${raw_abs}/wrapper" "${raw_abs}/metadata" "${parsed_abs}"

summary_rel="${raw_rel}/canonical/nccl-suite-summary.md"
env_rel="${raw_rel}/canonical/nccl-suite-env.txt"
cmd_rel="${raw_rel}/canonical/nccl-suite-command.sh"
records_rel="${raw_rel}/canonical/nccl-suite-records.jsonl"
capabilities_rel="${raw_rel}/canonical/nccl-suite-capabilities.json"
cap_stdout_rel="${raw_rel}/canonical/nccl-suite-capability-probe-stdout.txt"
cap_stderr_rel="${raw_rel}/canonical/nccl-suite-capability-probe-stderr.txt"
gpu_preflight_rel="${raw_rel}/canonical/gpu-preflight.txt"
summary_json_rel="${parsed_rel}/summary.json"
status_json_rel="${parsed_rel}/status.json"

summary_abs="${AICR_BMARK_DIR}/${summary_rel}"
cmd_abs="${AICR_BMARK_DIR}/${cmd_rel}"
records_abs="${AICR_BMARK_DIR}/${records_rel}"
capabilities_abs="${AICR_BMARK_DIR}/${capabilities_rel}"
cap_stdout_abs="${AICR_BMARK_DIR}/${cap_stdout_rel}"
cap_stderr_abs="${AICR_BMARK_DIR}/${cap_stderr_rel}"
gpu_preflight_abs="${AICR_BMARK_DIR}/${gpu_preflight_rel}"
summary_json_abs="${AICR_BMARK_DIR}/${summary_json_rel}"
status_json_abs="${AICR_BMARK_DIR}/${status_json_rel}"
record_abs="${AICR_BMARK_DIR}/${record_rel}"

: >"${cmd_abs}"
: >"${records_abs}"

if [[ -z "${NCCL_DEBUG+x}" ]]; then
  export NCCL_DEBUG="INFO"
else
  export NCCL_DEBUG
fi
export NCCL_DEBUG_SUBSYS="${NCCL_DEBUG_SUBSYS:-INIT,GRAPH,NET}"
export CUDA_DEVICE_MAX_CONNECTIONS="${CUDA_DEVICE_MAX_CONNECTIONS:-1}"
export OMPI_MCA_pml="${OMPI_MCA_pml:-ob1}"
if [[ "${scope}" == "local" ]]; then
  export NCCL_IB_DISABLE="${NCCL_IB_DISABLE:-1}"
  export OMPI_MCA_btl="${OMPI_MCA_btl:-self,vader}"
  export OMPI_MCA_btl_tcp_if_include="${OMPI_MCA_btl_tcp_if_include:-}"
  export OMPI_MCA_oob_tcp_if_include="${OMPI_MCA_oob_tcp_if_include:-}"
else
  export NCCL_IB_DISABLE="${NCCL_IB_DISABLE:-0}"
  export OMPI_MCA_btl="${OMPI_MCA_btl:-tcp,self,vader}"
  export OMPI_MCA_btl_tcp_if_include="${OMPI_MCA_btl_tcp_if_include:-ib0}"
  export OMPI_MCA_oob_tcp_if_include="${OMPI_MCA_oob_tcp_if_include:-ib0}"
fi
export OMPI_MCA_coll="${OMPI_MCA_coll:-^ucc}"
export OMPI_MCA_coll_ucc_enable="${OMPI_MCA_coll_ucc_enable:-0}"
export PMIX_MCA_gds="${PMIX_MCA_gds:-^ds12}"

cat >"${AICR_BMARK_DIR}/${env_rel}" <<EOT
cluster=${cluster}
scope=${scope}
mode=${mode}
host=${node_short}
peer_nodes_csv=${peer_nodes_csv}
node_count=${node_count}
run_id=${run_id}
profile=${profile}
suite_class_filter=${suite_class_filter}
image=${image}
wrapper=${wrapper}
apptainer_opts=${apptainer_opts}
min_bytes=${min_bytes}
max_bytes=${max_bytes}
step_factor=${step_factor}
warmup_iters=${warmup_iters}
iters=${iters}
requested_check_iters=${requested_check_iters}
suite_ops_filter=${suite_ops_filter}
NCCL_DEBUG=${NCCL_DEBUG}
NCCL_DEBUG_SUBSYS=${NCCL_DEBUG_SUBSYS}
NCCL_DEBUG_FILE=${NCCL_DEBUG_FILE:-}
CUDA_DEVICE_MAX_CONNECTIONS=${CUDA_DEVICE_MAX_CONNECTIONS}
NCCL_IB_DISABLE=${NCCL_IB_DISABLE}
OMPI_MCA_pml=${OMPI_MCA_pml}
OMPI_MCA_btl=${OMPI_MCA_btl}
OMPI_MCA_btl_tcp_if_include=${OMPI_MCA_btl_tcp_if_include}
OMPI_MCA_oob_tcp_if_include=${OMPI_MCA_oob_tcp_if_include}
OMPI_MCA_coll=${OMPI_MCA_coll}
OMPI_MCA_coll_ucc_enable=${OMPI_MCA_coll_ucc_enable}
PMIX_MCA_gds=${PMIX_MCA_gds}
EOT

run_gpu_preflight() {
  if [[ "${scope}" != "local" ]]; then
    # shellcheck disable=SC2016
    srun --mpi=pmix --ntasks="${node_count}" --ntasks-per-node=1 bash --noprofile --norc -lc \
      'found="$(nvidia-smi -L 2>/dev/null | grep -c "^GPU " || true)"; printf "%s %s\n" "$(hostname -s)" "${found}"' \
      >"${gpu_preflight_abs}" 2>&1 || return 1
  else
    found="$(nvidia-smi -L 2>/dev/null | grep -c '^GPU ' || true)"
    printf '%s %s\n' "${node_short}" "${found}" >"${gpu_preflight_abs}"
  fi

  aicr_python - "$gpu_preflight_abs" "$node_count" <<'PY'
import sys
from pathlib import Path
expected_nodes = int(sys.argv[2])
seen = {}
for line in Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").splitlines():
    parts = line.split()
    if len(parts) == 2:
        try:
            seen[parts[0]] = int(parts[1])
            continue
        except ValueError:
            pass
ok = len(seen) == expected_nodes and all(count == 8 for count in seen.values())
sys.exit(0 if ok else 1)
PY
}

run_capability_probe() {
  local return_code=0
  if [[ ! -f "${image}" ]]; then
    echo "missing image: ${image}" >"${cap_stderr_abs}"
    : >"${cap_stdout_abs}"
    return_code=127
  else
    set +e
    # shellcheck disable=SC2016
    apptainer exec "${apptainer_opt_args[@]}" "${image}" bash --noprofile --norc -lc '
set +e
echo "AICR_WRAPPER_HELP_BEGIN"
/workspace/microbenchmarks/nccl_tests.sh 2>&1
echo "AICR_WRAPPER_HELP_END"
echo "AICR_BINARIES_BEGIN"
ls -1 /workspace/microbenchmarks/nccl_tests 2>/dev/null
echo "AICR_BINARIES_END"
echo "AICR_ALL_REDUCE_HELP_BEGIN"
/workspace/microbenchmarks/nccl_tests/all_reduce_perf -h 2>&1
echo "AICR_ALL_REDUCE_HELP_END"
echo "AICR_NCCL_VERSION_BEGIN"
if command -v dpkg >/dev/null 2>&1; then dpkg -l 2>/dev/null | grep -i nccl || true; fi
for lib in /usr/lib/x86_64-linux-gnu/libnccl.so* /usr/local/cuda/lib64/libnccl.so*; do
  if [[ -r "$lib" ]]; then
    echo "lib=$lib"
    strings "$lib" 2>/dev/null | grep -m1 -E "NCCL version|^[0-9]+\\.[0-9]+\\.[0-9]+" || true
  fi
done
echo "AICR_NCCL_VERSION_END"
' >"${cap_stdout_abs}" 2>"${cap_stderr_abs}"
    return_code=$?
    set -e
  fi

  aicr_python - \
    "$capabilities_abs" "$cap_stdout_abs" "$cap_stderr_abs" "$return_code" \
    "$image" "$wrapper" <<'PY'
import json
import re
import sys
from pathlib import Path

out_path, stdout_path, stderr_path, return_code, image, wrapper = sys.argv[1:]
stdout = Path(stdout_path).read_text(encoding="utf-8", errors="replace") if Path(stdout_path).exists() else ""
stderr = Path(stderr_path).read_text(encoding="utf-8", errors="replace") if Path(stderr_path).exists() else ""
ops = ["allreduce", "allgather", "reduce_scatter", "alltoall", "sendrecv"]
obj = {
    "schema_version": 1,
    "image": image,
    "wrapper": wrapper,
    "probe_return_code": int(return_code),
    "ops": {op: bool(re.search(rf"(^|\s){re.escape(op)}(\s|$)", stdout, re.M)) for op in ops},
    "check_flag_supported": "-c,--check" in stdout or "--check" in stdout,
    "binaries": sorted(set(re.findall(r"^(.*_perf(?:_mpi)?)$", stdout, re.M))),
    "nccl_version_evidence": [
        line.strip()
        for line in stdout.splitlines()
        if "nccl" in line.lower() or "NCCL version" in line
    ][-20:],
    "stderr_tail": stderr.splitlines()[-20:],
}
Path(out_path).write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY
}

capability_value() {
  local expr="$1"
  aicr_python - "$capabilities_abs" "$expr" <<'PY'
import json
import sys
from pathlib import Path
obj = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expr = sys.argv[2]
if expr == "check":
    print("1" if obj.get("check_flag_supported") else "0")
else:
    print("1" if obj.get("ops", {}).get(expr) else "0")
PY
}

json_quote() {
  aicr_python - "$1" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1]))
PY
}

append_record() {
  local suite_class="$1"
  local op="$2"
  local binary_name="$3"
  local gpu_set="$4"
  local gpus_arg="$5"
  local ranks="$6"
  local rank_shape="$7"
  local transport="$8"
  local return_code="$9"
  local stdout_rel="${10}"
  local stderr_rel="${11}"
  local stdout_abs="${12}"
  local stderr_abs="${13}"
  local test_params="${14}"
  local env_text="${15}"

  aicr_python - \
    "$records_abs" "$suite_class" "$op" "$binary_name" "$gpu_set" "$gpus_arg" "$ranks" \
    "$rank_shape" "$transport" "$return_code" "$stdout_rel" "$stderr_rel" "$stdout_abs" \
    "$stderr_abs" "$test_params" "$env_text" <<'PY'
import json
import sys

(
    path, suite_class, op, binary_name, gpu_set, gpus_arg, ranks, rank_shape,
    transport, return_code, stdout_rel, stderr_rel, stdout_abs, stderr_abs,
    test_params, env_text,
) = sys.argv[1:]

with open(path, "a", encoding="utf-8") as fh:
    fh.write(json.dumps({
        "suite_class": suite_class,
        "op": op,
        "test": binary_name,
        "gpu_set": gpu_set,
        "gpus_arg": int(gpus_arg),
        "ranks": int(ranks),
        "rank_shape": rank_shape,
        "transport": transport,
        "return_code": int(return_code),
        "stdout_rel": stdout_rel,
        "stderr_rel": stderr_rel,
        "stdout_abs": stdout_abs,
        "stderr_abs": stderr_abs,
        "test_params": test_params,
        "env": env_text,
    }))
    fh.write("\n")
PY
}

binary_name_for_op() {
  case "$1" in
    allreduce) printf 'all_reduce_perf\n' ;;
    allgather) printf 'all_gather_perf\n' ;;
    reduce_scatter) printf 'reduce_scatter_perf\n' ;;
    alltoall) printf 'alltoall_perf\n' ;;
    sendrecv) printf 'sendrecv_perf\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}

params_for_op() {
  local op="$1"
  local gpus_arg="$2"
  local params="-b ${min_bytes} -e ${max_bytes} -f ${step_factor} -g ${gpus_arg} -w ${warmup_iters} -n ${iters}"
  if [[ "${effective_check_iters}" != "0" ]]; then
    params="${params} -c ${effective_check_iters}"
  fi
  printf '%s\n' "${params}"
}

run_suite_item() {
  local suite_class="$1"
  local op="$2"
  local gpu_set="$3"
  local gpus_arg="$4"
  local ranks="$5"
  local rank_shape="$6"
  local transport="$7"
  local launch_mode="$8"
  local bind_local_rank="$9"

  local binary_name test_params safe_class stdout_rel stderr_rel stdout_abs stderr_abs return_code env_text
  binary_name="$(binary_name_for_op "${op}")"
  test_params="$(params_for_op "${op}" "${gpus_arg}")"
  safe_class="${suite_class}"
  if [[ -n "${gpu_set}" ]]; then
    safe_class="${safe_class}_${gpu_set//,/_}"
    safe_class="${safe_class//=/}"
    safe_class="${safe_class//;/_}"
  fi
  stdout_rel="${raw_rel}/canonical/${safe_class}--${op}-stdout.txt"
  stderr_rel="${raw_rel}/canonical/${safe_class}--${op}-stderr.txt"
  stdout_abs="${AICR_BMARK_DIR}/${stdout_rel}"
  stderr_abs="${AICR_BMARK_DIR}/${stderr_rel}"

  local env_args=(
    "NCCL_DEBUG=${NCCL_DEBUG}"
    "NCCL_DEBUG_SUBSYS=${NCCL_DEBUG_SUBSYS}"
    "CUDA_DEVICE_MAX_CONNECTIONS=${CUDA_DEVICE_MAX_CONNECTIONS}"
    "OMPI_MCA_pml=${OMPI_MCA_pml}"
    "OMPI_MCA_btl=${OMPI_MCA_btl}"
    "OMPI_MCA_coll=${OMPI_MCA_coll}"
    "OMPI_MCA_coll_ucc_enable=${OMPI_MCA_coll_ucc_enable}"
    "PMIX_MCA_gds=${PMIX_MCA_gds}"
    "AICR_NCCL_WRAPPER=${wrapper}"
    "AICR_NCCL_OP=${op}"
    "AICR_NCCL_TEST_PARAMS=${test_params}"
    "AICR_NCCL_LOCAL_RANK_BIND=${bind_local_rank}"
  )
  if [[ -n "${NCCL_DEBUG_FILE:-}" ]]; then
    env_args+=("NCCL_DEBUG_FILE=${NCCL_DEBUG_FILE}")
  fi
  if [[ -n "${OMPI_MCA_btl_tcp_if_include}" ]]; then
    env_args+=("OMPI_MCA_btl_tcp_if_include=${OMPI_MCA_btl_tcp_if_include}")
  fi
  if [[ -n "${OMPI_MCA_oob_tcp_if_include}" ]]; then
    env_args+=("OMPI_MCA_oob_tcp_if_include=${OMPI_MCA_oob_tcp_if_include}")
  fi
  if [[ "${scope}" == "local" ]]; then
    env_args+=(
      "NCCL_IB_DISABLE=1"
      "NCCL_NET=Socket"
      "APPTAINERENV_NCCL_IB_DISABLE=1"
      "APPTAINERENV_NCCL_NET=Socket"
      "AICR_NCCL_WRAPPER_EXTRA=--no-multinode"
    )
  else
    env_args+=("NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-0}" "APPTAINERENV_NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-0}" "AICR_NCCL_WRAPPER_EXTRA=")
  fi
  if [[ "${launch_mode}" == "socket-srun" ]]; then
    env_args+=(
      "AICR_B200_SOCKET_SPLIT_RANK0_CPUS=0-63"
      "AICR_B200_SOCKET_SPLIT_RANK0_GPUS=3,0,1,2"
      "AICR_B200_SOCKET_SPLIT_RANK1_CPUS=64-127"
      "AICR_B200_SOCKET_SPLIT_RANK1_GPUS=7,4,5,6"
    )
  elif [[ -n "${gpu_set}" ]]; then
    env_args+=("CUDA_VISIBLE_DEVICES=${gpu_set}")
  fi
  env_text="${env_args[*]}"

  local container_cmd
  # shellcheck disable=SC2016
  container_cmd='set -euo pipefail
if [[ "${AICR_NCCL_LOCAL_RANK_BIND:-0}" == "1" ]]; then
  : "${SLURM_LOCALID:?SLURM_LOCALID is required for rank binding}"
  echo "AICR_RANK_BINDING=nccl-tests-local-rank:${SLURM_LOCALID}"
fi
echo "AICR_NCCL_WRAPPER=${AICR_NCCL_WRAPPER}"
echo "AICR_NCCL_OP=${AICR_NCCL_OP}"
echo "AICR_NCCL_TEST_PARAMS=${AICR_NCCL_TEST_PARAMS}"
echo "AICR_NCCL_IB_DISABLE=${NCCL_IB_DISABLE:-unset}"
echo "AICR_NCCL_NET=${NCCL_NET:-unset}"
echo "AICR_CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
if [[ -n "${AICR_NCCL_WRAPPER_EXTRA:-}" ]]; then
  exec "${AICR_NCCL_WRAPPER}" --op "${AICR_NCCL_OP}" ${AICR_NCCL_WRAPPER_EXTRA} --test-params "${AICR_NCCL_TEST_PARAMS}"
fi
exec "${AICR_NCCL_WRAPPER}" --op "${AICR_NCCL_OP}" --test-params "${AICR_NCCL_TEST_PARAMS}"
'

  local socket_launcher
  # shellcheck disable=SC2016
  socket_launcher='set -euo pipefail
: "${SLURM_LOCALID:?SLURM_LOCALID is required for B200 socket split}"
case "${SLURM_LOCALID}" in
  0)
    cpu_set="0-63"
    ;;
  1)
    cpu_set="64-127"
    ;;
  *)
    echo "ERROR: unsupported B200 socket split local rank: ${SLURM_LOCALID}" >&2
    exit 2
    ;;
esac
cuda_visible="3,0,1,2,7,4,5,6"
container_cmd="${!#}"
set -- "${@:1:$(($# - 1))}"
export CUDA_VISIBLE_DEVICES="${cuda_visible}"
export APPTAINERENV_CUDA_VISIBLE_DEVICES="${cuda_visible}"
echo "AICR_SOCKET_SPLIT_LOCALID=${SLURM_LOCALID}"
echo "AICR_SOCKET_SPLIT_CPU_SET=${cpu_set}"
echo "AICR_SOCKET_SPLIT_CUDA_VISIBLE_DEVICES=${cuda_visible}"
if command -v numactl >/dev/null 2>&1; then
  exec numactl --physcpubind="${cpu_set}" apptainer exec "$@" bash --noprofile --norc -lc "${container_cmd}"
elif command -v taskset >/dev/null 2>&1; then
  exec taskset -c "${cpu_set}" apptainer exec "$@" bash --noprofile --norc -lc "${container_cmd}"
else
  echo "WARNING: numactl/taskset unavailable; running B200 socket split without CPU pinning" >&2
  exec apptainer exec "$@" bash --noprofile --norc -lc "${container_cmd}"
fi
'

  {
    echo "# ${suite_class} ${op}"
    if [[ "${launch_mode}" == "srun" ]]; then
      printf '%q ' env "${env_args[@]}" srun --mpi=pmix --cpu-bind=none --ntasks="${ranks}" --ntasks-per-node=8 apptainer exec "${apptainer_opt_args[@]}" "${image}" bash --noprofile --norc -lc "${container_cmd}"
    elif [[ "${launch_mode}" == "socket-srun" ]]; then
      printf '%q ' env "${env_args[@]}" srun --mpi=pmix --cpu-bind=none --ntasks="${ranks}" --ntasks-per-node=2 --cpus-per-task=64 bash --noprofile --norc -lc "${socket_launcher}" socket-launch "${apptainer_opt_args[@]}" "${image}" "${container_cmd}"
    else
      printf '%q ' env "${env_args[@]}" apptainer exec "${apptainer_opt_args[@]}" "${image}" bash --noprofile --norc -lc "${container_cmd}"
    fi
    echo
  } >>"${cmd_abs}"

  return_code=0
  if [[ ! -f "${image}" ]]; then
    echo "missing image: ${image}" >"${stderr_abs}"
    : >"${stdout_abs}"
    return_code=127
  else
    set +e
    if [[ "${launch_mode}" == "srun" ]]; then
      env "${env_args[@]}" \
        srun --mpi=pmix --cpu-bind=none --ntasks="${ranks}" --ntasks-per-node=8 \
        apptainer exec "${apptainer_opt_args[@]}" "${image}" bash --noprofile --norc -lc "${container_cmd}" \
        >"${stdout_abs}" 2>"${stderr_abs}"
      return_code=$?
    elif [[ "${launch_mode}" == "socket-srun" ]]; then
      env "${env_args[@]}" \
        srun --mpi=pmix --cpu-bind=none --ntasks="${ranks}" --ntasks-per-node=2 --cpus-per-task=64 \
        bash --noprofile --norc -lc "${socket_launcher}" socket-launch "${apptainer_opt_args[@]}" "${image}" "${container_cmd}" \
        >"${stdout_abs}" 2>"${stderr_abs}"
      return_code=$?
    else
      env "${env_args[@]}" \
        apptainer exec "${apptainer_opt_args[@]}" "${image}" bash --noprofile --norc -lc "${container_cmd}" \
        >"${stdout_abs}" 2>"${stderr_abs}"
      return_code=$?
    fi
    set -e
  fi

  append_record \
    "${suite_class}" "${op}" "${binary_name}" "${gpu_set}" "${gpus_arg}" "${ranks}" \
    "${rank_shape}" "${transport}" "${return_code}" "${stdout_rel}" "${stderr_rel}" \
    "${stdout_abs}" "${stderr_abs}" "${test_params}" "${env_text}"
}

run_ops_for_class() {
  local suite_class="$1"
  local gpu_set="$2"
  local gpus_arg="$3"
  local ranks="$4"
  local rank_shape="$5"
  local transport="$6"
  local launch_mode="$7"
  local bind_local_rank="$8"
  shift 8
  if [[ -n "${suite_class_filter}" && "${suite_class_filter}" != "${suite_class}" ]]; then
    return 0
  fi
  local op
  for op in "$@"; do
    if ! suite_op_enabled "${op}"; then
      continue
    fi
    if [[ "$(capability_value "${op}")" != "1" ]]; then
      echo "ERROR: HPC Benchmarks wrapper does not advertise op ${op}" >&2
      continue
    fi
    run_suite_item "${suite_class}" "${op}" "${gpu_set}" "${gpus_arg}" "${ranks}" "${rank_shape}" "${transport}" "${launch_mode}" "${bind_local_rank}"
  done
}

suite_op_enabled() {
  local op="$1"
  local item
  [[ -n "${suite_ops_filter}" ]] || return 0
  for item in ${suite_ops_filter//,/ }; do
    if [[ "${item}" == "${op}" ]]; then
      return 0
    fi
  done
  return 1
}

run_capability_probe
check_supported="$(capability_value check)"
effective_check_iters="0"
if [[ "${requested_check_iters}" != "0" && "${check_supported}" == "1" ]]; then
  effective_check_iters="${requested_check_iters}"
fi

preflight_status="passed"
preflight_note=""
if ! run_gpu_preflight; then
  preflight_status="failed"
  preflight_note="one or more nodes do not expose 8 GPUs"
fi
required_ops=(allreduce allgather reduce_scatter alltoall)
if [[ "${scope}" == "local" && "${cluster}" == "rtxpro6000" ]]; then
  required_ops=(allreduce allgather reduce_scatter alltoall sendrecv)
fi
missing_ops=()
for required_op in "${required_ops[@]}"; do
  if [[ "$(capability_value "${required_op}")" != "1" ]]; then
    missing_ops+=("${required_op}")
  fi
done
if [[ "${#missing_ops[@]}" -gt 0 ]]; then
  preflight_status="failed"
  preflight_note="HPC Benchmarks wrapper is missing required ops: ${missing_ops[*]}"
fi

if [[ "${preflight_status}" == "passed" ]]; then
  if [[ "${scope}" == "local" ]]; then
    case "${cluster}" in
      b200)
        run_ops_for_class "b200_1proc_8g" "" 8 1 "1proc_8g" "local" "direct" 0 \
          allreduce allgather reduce_scatter alltoall
        run_ops_for_class "b200_8rank_1g" "" 1 8 "8rank_1g" "local" "srun" 1 \
          allreduce allgather reduce_scatter alltoall
        run_ops_for_class "b200_2rank_socket_4g" "rank0=3,0,1,2;rank1=7,4,5,6" 4 2 "2rank_socket_4g" "local-socket" "socket-srun" 0 \
          allreduce allgather reduce_scatter alltoall
        ;;
      rtxpro6000)
        run_ops_for_class "rtx_8rank_1g" "" 1 8 "8rank_1g" "local" "srun" 1 \
          allreduce allgather reduce_scatter alltoall
        for pair in 0,1 2,3 4,5 6,7; do
          run_ops_for_class "rtx_pair_policy" "${pair}" 2 1 "1proc_2g" "local-pair" "direct" 0 \
            allreduce allgather reduce_scatter sendrecv
        done
        ;;
    esac
  elif [[ "${scope}" == "rdma" ]]; then
    total_ranks=$(( node_count * 8 ))
    run_ops_for_class "${cluster}_rdma_${node_count}n_8rank_1g" "" 1 "${total_ranks}" "8rank_1g_per_node" "rdma" "srun" 1 \
      allreduce allgather reduce_scatter alltoall
  else
    total_ranks=$(( node_count * 8 ))
    run_ops_for_class "${cluster}_survey_${node_count}n_8rank_1g" "" 1 "${total_ranks}" "8rank_1g_per_node" "survey" "srun" 1 \
      allreduce allgather reduce_scatter alltoall
  fi
fi

aicr_python - \
  "$records_abs" "$summary_json_abs" "$status_json_abs" "$summary_abs" \
  "$cluster" "$scope" "$mode" "$run_id" "$profile" "$image" "$wrapper" \
  "$capabilities_abs" "$preflight_status" "$preflight_note" "$effective_check_iters" \
  "$node_short" "$peer_nodes_csv" "$node_count" <<'PY'
import json
import math
import re
import statistics
import sys
from pathlib import Path

(
    records_path,
    summary_json_path,
    status_json_path,
    summary_md_path,
    cluster,
    scope,
    mode,
    run_id,
    profile,
    image,
    wrapper,
    capabilities_path,
    preflight_status,
    preflight_note,
    effective_check_iters,
    host,
    peer_nodes_csv,
    node_count,
) = sys.argv[1:]


def parse_num(value):
    try:
        if str(value).lower() in {"nan", "inf", "-inf"}:
            return None
        return float(value)
    except (TypeError, ValueError):
        return None


def parse_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def parse_nccl_output(path):
    text = Path(path).read_text(encoding="utf-8", errors="replace") if Path(path).exists() else ""
    rows = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or stripped.startswith("AICR_"):
            continue
        parts = stripped.split()
        if not parts or not re.fullmatch(r"[0-9]+", parts[0]):
            continue
        if len(parts) >= 12:
            bytes_value = parse_int(parts[0])
            algbw = parse_num(parts[10])
            busbw = parse_num(parts[11])
            wrong_values = [parse_int(parts[idx]) for idx in (8, 12) if idx < len(parts)]
            wrong = sum(value for value in wrong_values if value is not None)
            if bytes_value is not None and algbw is not None and busbw is not None:
                rows.append({"bytes": bytes_value, "algbw": algbw, "busbw": busbw, "wrong": wrong})
    return text, rows


def count(pattern, *texts):
    return sum(len(re.findall(pattern, text, flags=re.I)) for text in texts)


records = []
if Path(records_path).exists():
    for line in Path(records_path).read_text(encoding="utf-8").splitlines():
        if line.strip():
            records.append(json.loads(line))

items = []
for record in records:
    stdout_text, rows = parse_nccl_output(record["stdout_abs"])
    stderr_text = Path(record["stderr_abs"]).read_text(encoding="utf-8", errors="replace") if Path(record["stderr_abs"]).exists() else ""
    wrong_count = sum(row["wrong"] for row in rows)
    largest = max(rows, key=lambda row: row["bytes"]) if rows else {}
    hints = []
    if count(r"Channel .* via P2P|via P2P/direct pointer", stdout_text):
        hints.append("P2P")
    if count(r"Channel .* via SHM", stdout_text):
        hints.append("SHM")
    if count(r"Channel .* via NET/IB", stdout_text):
        hints.append("NET/IB")
    if count(r"type SYS|/SYS", stdout_text):
        hints.append("SYS")
    if count(r"Channel .*GDRDMA", stdout_text):
        hints.append("GDRDMA")
    status = "passed"
    notes = ""
    if record["return_code"] != 0:
        status = "failed"
        notes = f"return_code={record['return_code']}"
    elif wrong_count > 0:
        status = "failed"
        notes = f"wrong_count={wrong_count}"
    elif not rows:
        status = "degraded"
        notes = "no parsed nccl-tests rows"
    item = {
        **record,
        "status": status,
        "notes": notes,
        "row_count": len(rows),
        "wrong_count": wrong_count,
        "max_algbw": max((row["algbw"] for row in rows), default=None),
        "max_busbw": max((row["busbw"] for row in rows), default=None),
        "largest_message_bytes": largest.get("bytes"),
        "largest_message_algbw": largest.get("algbw"),
        "largest_message_busbw": largest.get("busbw"),
        "transport_hints": ",".join(hints) if hints else "unknown",
    }
    items.append(item)

overall = "passed"
notes = []
if preflight_status != "passed":
    overall = "failed"
    notes.append(preflight_note or "gpu preflight failed")
elif any(item["status"] == "failed" for item in items):
    overall = "failed"
    notes.append("one or more NCCL suite items failed")
elif any(item["status"] == "degraded" for item in items):
    overall = "degraded"
    notes.append("one or more NCCL suite items were degraded")
elif not items:
    overall = "failed"
    notes.append("no NCCL suite items ran")

capabilities = json.loads(Path(capabilities_path).read_text(encoding="utf-8")) if Path(capabilities_path).exists() else {}
summary = {
    "schema_version": 1,
    "cluster": cluster,
    "scope": scope,
    "mode": mode,
    "host": host,
    "peer_nodes_csv": peer_nodes_csv,
    "node_count": int(node_count),
    "gpu_count": int(node_count) * 8,
    "run_id": run_id,
    "profile": profile,
    "image": image,
    "wrapper": wrapper,
    "effective_check_iters": int(effective_check_iters),
    "capabilities": capabilities,
    "gpu_preflight_status": preflight_status,
    "gpu_preflight_note": preflight_note,
    "status": overall,
    "notes": "; ".join(notes),
    "items": items,
}

Path(summary_json_path).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
Path(status_json_path).write_text(json.dumps({
    "status": overall,
    "pass_basis": f"parsed.summary.status={overall}",
}, indent=2) + "\n", encoding="utf-8")

lines = [
    "# NCCL Suite Summary",
    "",
    f"- status: `{overall}`",
    f"- cluster: `{cluster}`",
    f"- scope: `{scope}`",
    f"- profile: `{profile}`",
    f"- run_id: `{run_id}`",
    f"- image: `{image}`",
    f"- effective check iters: `{effective_check_iters}`",
]
if notes:
    lines.append(f"- notes: `{'; '.join(notes)}`")
lines.extend([
    "",
    "Bandwidth values are `nccl-tests` `busbw` in GB/s.",
    "",
    "| Class | Op | GPU set | Ranks | -g | Status | Largest busbw (GB/s) | Max busbw (GB/s) | Wrong | Hints |",
    "| --- | --- | --- | ---: | ---: | --- | ---: | ---: | ---: | --- |",
])
for item in items:
    def fmt(value):
        if value is None:
            return "-"
        try:
            return f"{float(value):.3f}"
        except (TypeError, ValueError):
            return str(value)
    lines.append(
        f"| `{item['suite_class']}` | `{item['op']}` | `{item.get('gpu_set') or 'all'}` | "
        f"{item['ranks']} | {item['gpus_arg']} | `{item['status']}` | "
        f"{fmt(item.get('largest_message_busbw'))} | {fmt(item.get('max_busbw'))} | "
        f"{item.get('wrong_count', 0)} | {item.get('transport_hints', '')} |"
    )
Path(summary_md_path).write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

status="$(aicr_python - "$summary_json_abs" <<'PY'
import json
import sys
from pathlib import Path
print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["status"])
PY
)"
notes="$(aicr_python - "$summary_json_abs" <<'PY'
import json
import sys
from pathlib import Path
print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("notes", ""))
PY
)"

canonical_paths=(
  "${summary_rel}"
  "${env_rel}"
  "${cmd_rel}"
  "${records_rel}"
  "${capabilities_rel}"
  "${cap_stdout_rel}"
  "${cap_stderr_rel}"
  "${gpu_preflight_rel}"
)
while IFS= read -r record_line; do
  [[ -n "${record_line}" ]] || continue
  stdout_rel="$(aicr_python -c 'import json,sys; print(json.loads(sys.stdin.read())["stdout_rel"])' <<<"${record_line}")"
  stderr_rel="$(aicr_python -c 'import json,sys; print(json.loads(sys.stdin.read())["stderr_rel"])' <<<"${record_line}")"
  canonical_paths+=("${stdout_rel}" "${stderr_rel}")
done <"${records_abs}"

if [[ "${scope}" == "local" ]]; then
  aicr_emit_record_from_args \
    "${record_abs}" \
    "${AICR_SCOPE_NODE}" \
    "${cluster}" \
    "${node_short}" \
    "" \
    "${check}" \
    "${mode}" \
    "${run_id}" \
    "${date_utc}" \
    "$(aicr_timestamp_utc)" \
    "$(aicr_timestamp_utc)" \
    "${SLURM_JOB_PARTITION:-${SLURM_PARTITION:-}}" \
    "${SLURM_JOB_ID:-}" \
    "${status}" \
    "parsed.nccl-suite-summary" \
    "1" \
    "8" \
    "$(aicr_join_csv "${canonical_paths[@]}")" \
    "$(aicr_join_csv "${summary_json_rel}" "${status_json_rel}")" \
    "" \
    "${notes}"
  aicr_append_index_row_from_record "${AICR_BMARK_DIR}/$(aicr_by_date_index_path "$date_utc")" "${record_abs}"
  aicr_append_index_row_from_record "${AICR_BMARK_DIR}/$(aicr_by_node_history_path "$cluster" "$node_short")" "${record_abs}"
else
  total_gpus=$(( node_count * 8 ))
  aicr_emit_record_from_args \
    "${record_abs}" \
    "${AICR_SCOPE_MULTI_NODE}" \
    "${cluster}" \
    "" \
    "${peer_nodes_csv}" \
    "${check}" \
    "${mode}" \
    "${run_id}" \
    "${date_utc}" \
    "$(aicr_timestamp_utc)" \
    "$(aicr_timestamp_utc)" \
    "${SLURM_JOB_PARTITION:-${SLURM_PARTITION:-}}" \
    "${SLURM_JOB_ID:-}" \
    "${status}" \
    "parsed.nccl-suite-summary" \
    "${node_count}" \
    "${total_gpus}" \
    "$(aicr_join_csv "${canonical_paths[@]}")" \
    "$(aicr_join_csv "${summary_json_rel}" "${status_json_rel}")" \
    "" \
    "${notes}"
  aicr_append_index_row_from_record "${AICR_BMARK_DIR}/$(aicr_by_date_index_path "$date_utc")" "${record_abs}"
  first_node="$(printf '%s' "${peer_nodes_csv}" | cut -d, -f1)"
  if [[ -n "${first_node}" ]]; then
    aicr_append_index_row_from_record "${AICR_BMARK_DIR}/$(aicr_by_node_history_path "$cluster" "$first_node")" "${record_abs}"
  fi
fi

echo "NCCL suite status: ${status}"
echo "Record: ${record_rel}"
echo "Summary: ${summary_rel}"

[[ "${status}" == "passed" ]]
