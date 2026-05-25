#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"

json_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "$value"
}

json_array() {
  local first=1
  local value
  printf '['
  for value in "$@"; do
    if [[ "$first" -eq 0 ]]; then
      printf ', '
    fi
    first=0
    json_string "$value"
  done
  printf ']'
}

write_status_json() {
  local path="$1"
  local status="$2"
  local pass_basis="$3"

  {
    printf '{\n'
    printf '  "status": %s,\n' "$(json_string "$status")"
    printf '  "pass_basis": %s\n' "$(json_string "$pass_basis")"
    printf '}\n'
  } >"$path"
}

write_summary_json() {
  local path="$1"
  local status="$2"
  local cluster="$3"
  local host="$4"
  local run_id="$5"
  local partition="$6"
  local job_id="$7"
  local gpu_count="$8"
  local doctor_rc="$9"
  local import_rc="${10}"
  local python_exec_rel="${11}"

  {
    printf '{\n'
    printf '  "status": %s,\n' "$(json_string "$status")"
    printf '  "cluster": %s,\n' "$(json_string "$cluster")"
    printf '  "host": %s,\n' "$(json_string "$host")"
    printf '  "run_id": %s,\n' "$(json_string "$run_id")"
    printf '  "partition": %s,\n' "$(json_string "$partition")"
    printf '  "job_id": %s,\n' "$(json_string "$job_id")"
    printf '  "gpu_count": %s,\n' "$gpu_count"
    printf '  "doctor_exit_code": %s,\n' "$doctor_rc"
    printf '  "run_repo_python_import_exit_code": %s,\n' "$import_rc"
    printf '  "python_import_summary_path": %s\n' "$(json_string "$python_exec_rel")"
    printf '}\n'
  } >"$path"
}

write_record_json() {
  local path="$1"
  local cluster="$2"
  local run_id="$3"
  local date_utc="$4"
  local submitted_at="$5"
  local completed_at="$6"
  local partition="$7"
  local job_id="$8"
  local status="$9"
  local pass_basis="${10}"
  local gpu_count="${11}"
  local notes="${12}"
  shift 12
  local canonical_paths=("$1" "$2" "$3" "$4")
  local parsed_paths=("$5" "$6")
  local wrapper_paths=("$7" "$8")

  {
    printf '{\n'
    printf '  "schema_version": 1,\n'
    printf '  "scope": "setup",\n'
    printf '  "cluster": %s,\n' "$(json_string "$cluster")"
    printf '  "node": null,\n'
    printf '  "peer_nodes": [],\n'
    printf '  "check": %s,\n' "$(json_string "$AICR_CHECK_PYTHON_RUNTIME_SLURM")"
    printf '  "subcheck": null,\n'
    printf '  "mode": "setup",\n'
    printf '  "run_id": %s,\n' "$(json_string "$run_id")"
    printf '  "date": %s,\n' "$(json_string "$date_utc")"
    printf '  "submitted_at_utc": %s,\n' "$(json_string "$submitted_at")"
    printf '  "launched_at_utc": %s,\n' "$(json_string "$submitted_at")"
    printf '  "completed_at_utc": %s,\n' "$(json_string "$completed_at")"
    printf '  "partition": %s,\n' "$(json_string "$partition")"
    printf '  "job_id": %s,\n' "$(json_string "$job_id")"
    printf '  "status": %s,\n' "$(json_string "$status")"
    printf '  "pass_basis": %s,\n' "$(json_string "$pass_basis")"
    printf '  "notes": %s,\n' "$(json_string "$notes")"
    printf '  "node_count": 1,\n'
    printf '  "gpu_count": %s,\n' "$gpu_count"
    printf '  "wrapper_log_paths": %s,\n' "$(json_array "${wrapper_paths[@]}")"
    printf '  "canonical_artifact_paths": %s,\n' "$(json_array "${canonical_paths[@]}")"
    printf '  "parsed_artifact_paths": %s,\n' "$(json_array "${parsed_paths[@]}")"
    printf '  "setup_baseline_ref": {\n'
    printf '    "cluster": %s,\n' "$(json_string "$cluster")"
    printf '    "baseline_path": %s,\n' "$(json_string "results/setup/${cluster}/baseline.json")"
    printf '    "baseline_id": null\n'
    printf '  }\n'
    printf '}\n'
  } >"$path"
}

aicr_require_repo_root
aicr_mkdirs

cluster="${AICR_CLUSTER_NAME:-$(aicr_cluster_name)}"
aicr_assert_supported_cluster "$cluster"

check="$AICR_CHECK_PYTHON_RUNTIME_SLURM"
run_id="${SETUP_RUN_ID:-$(aicr_next_setup_run_id "$cluster" "$check")}"
raw_rel="$(aicr_setup_raw_run_dir "$cluster" "$check" "$run_id")"
parsed_rel="$(aicr_setup_parsed_run_dir "$cluster" "$check" "$run_id")"
raw_abs="${AICR_BMARK_DIR}/${raw_rel}"
parsed_abs="${AICR_BMARK_DIR}/${parsed_rel}"
mkdir -p "${raw_abs}/canonical" "${raw_abs}/wrapper" "${raw_abs}/metadata" "$parsed_abs"

host="$(hostname -s 2>/dev/null || hostname)"
gpu_count="$(aicr_gpu_count)"
partition="${SLURM_JOB_PARTITION:-${SLURM_JOB_PARTITION_NAME:-}}"
job_id="${SLURM_JOB_ID:-}"
submitted_at="$(aicr_timestamp_utc)"
date_utc="$(aicr_today_date)"

doctor_stdout_rel="${raw_rel}/canonical/doctor-python.stdout"
doctor_stderr_rel="${raw_rel}/canonical/doctor-python.stderr"
setup_stdout_rel="${raw_rel}/canonical/setup-python-local.stdout"
setup_stderr_rel="${raw_rel}/canonical/setup-python-local.stderr"
import_json_rel="${raw_rel}/canonical/run-repo-python-imports.json"
import_stderr_rel="${raw_rel}/canonical/run-repo-python-imports.stderr"
summary_txt_rel="${raw_rel}/canonical/python-runtime-slurm-summary.txt"
wrapper_out_rel="${raw_rel}/wrapper/slurm-${SLURM_JOB_ID:-manual}.out"
wrapper_err_rel="${raw_rel}/wrapper/slurm-${SLURM_JOB_ID:-manual}.err"
summary_json_rel="${parsed_rel}/summary.json"
status_json_rel="${parsed_rel}/status.json"
record_rel="$(aicr_setup_record_path "$cluster" "$check" "$run_id")"

: >"${AICR_BMARK_DIR}/${wrapper_out_rel}"
: >"${AICR_BMARK_DIR}/${wrapper_err_rel}"

run_setup="${AICR_PYTHON_RUNTIME_SETUP:-0}"
case "$run_setup" in
  0|1) ;;
  *) echo "AICR_PYTHON_RUNTIME_SETUP must be 0 or 1" >&2; exit 2 ;;
esac

setup_rc=0
if [[ "$run_setup" == "1" ]]; then
  set +e
  bash "${AICR_BMARK_DIR}/scripts/setup/setup-python-local.sh" --force \
    >"${AICR_BMARK_DIR}/${setup_stdout_rel}" \
    2>"${AICR_BMARK_DIR}/${setup_stderr_rel}"
  setup_rc=$?
  set -e
else
  printf 'setup-python-local skipped; AICR_PYTHON_RUNTIME_SETUP=0\n' >"${AICR_BMARK_DIR}/${setup_stdout_rel}"
  : >"${AICR_BMARK_DIR}/${setup_stderr_rel}"
fi

set +e
bash "${AICR_BMARK_DIR}/scripts/setup/doctor-python.sh" \
  >"${AICR_BMARK_DIR}/${doctor_stdout_rel}" \
  2>"${AICR_BMARK_DIR}/${doctor_stderr_rel}"
doctor_rc=$?
set -e

set +e
bash "${AICR_BMARK_DIR}/scripts/lib/run-repo-python.sh" - \
  >"${AICR_BMARK_DIR}/${import_json_rel}" \
  2>"${AICR_BMARK_DIR}/${import_stderr_rel}" <<'PY'
import importlib
import importlib.metadata as metadata
import json
import os
import sys

modules = ["jsonschema", "matplotlib", "pandas", "snakemake"]
distributions = ["jsonschema", "matplotlib", "pandas", "snakemake", "python"]
imports = {}
for module in modules:
    importlib.import_module(module)
    imports[module] = "ok"

packages = {}
for name in distributions:
    if name == "python":
        packages[name] = sys.version.split()[0]
        continue
    try:
        packages[name] = metadata.version(name)
    except metadata.PackageNotFoundError:
        packages[name] = None

print(json.dumps({
    "python_executable": sys.executable,
    "python_version": sys.version.split()[0],
    "sys_prefix": sys.prefix,
    "python_no_user_site": os.environ.get("PYTHONNOUSERSITE"),
    "python_home": os.environ.get("PYTHONHOME"),
    "imports": imports,
    "packages": packages,
}, indent=2))
PY
import_rc=$?
set -e

if [[ "$run_setup" == "1" && "$setup_rc" -ne 0 ]]; then
  status="$AICR_STATUS_FAILED"
  pass_basis="setup-python-local.sh=${setup_rc}; doctor-python.sh=${doctor_rc}; run-repo-python required imports=${import_rc}"
  notes="inspect canonical setup-python-local, doctor-python, and run-repo-python stderr artifacts"
elif [[ "$doctor_rc" -eq 0 && "$import_rc" -eq 0 ]]; then
  status="$AICR_STATUS_PASSED"
  if [[ "$run_setup" == "1" ]]; then
    pass_basis="setup-python-local.sh=0, doctor-python.sh=0, and run-repo-python required imports=0"
  else
    pass_basis="doctor-python.sh=0 and run-repo-python required imports=0"
  fi
  notes="compute-node Slurm allocation uses the configured direct repo Python"
else
  status="$AICR_STATUS_FAILED"
  pass_basis="setup-python-local.sh=${setup_rc}; doctor-python.sh=${doctor_rc}; run-repo-python required imports=${import_rc}"
  notes="inspect canonical doctor-python and run-repo-python stderr artifacts"
fi
completed_at="$(aicr_timestamp_utc)"

{
  printf 'host=%s\n' "$host"
  printf 'cluster=%s\n' "$cluster"
  printf 'run_id=%s\n' "$run_id"
  printf 'partition=%s\n' "$partition"
  printf 'job_id=%s\n' "$job_id"
  printf 'gpu_count=%s\n' "$gpu_count"
  printf 'setup_requested=%s\n' "$run_setup"
  printf 'setup_python_local_exit_code=%s\n' "$setup_rc"
  printf 'doctor_exit_code=%s\n' "$doctor_rc"
  printf 'run_repo_python_import_exit_code=%s\n' "$import_rc"
  printf 'status=%s\n' "$status"
  printf 'pass_basis=%s\n' "$pass_basis"
} >"${AICR_BMARK_DIR}/${summary_txt_rel}"

write_summary_json \
  "${AICR_BMARK_DIR}/${summary_json_rel}" \
  "$status" \
  "$cluster" \
  "$host" \
  "$run_id" \
  "$partition" \
  "$job_id" \
  "$gpu_count" \
  "$doctor_rc" \
  "$import_rc" \
  "$import_json_rel"
write_status_json "${AICR_BMARK_DIR}/${status_json_rel}" "$status" "$pass_basis"
write_record_json \
  "${AICR_BMARK_DIR}/${record_rel}" \
  "$cluster" \
  "$run_id" \
  "$date_utc" \
  "$submitted_at" \
  "$completed_at" \
  "$partition" \
  "$job_id" \
  "$status" \
  "$pass_basis" \
  "$gpu_count" \
  "$notes" \
  "$doctor_stdout_rel" \
  "$doctor_stderr_rel" \
  "$import_json_rel" \
  "$summary_txt_rel" \
  "$summary_json_rel" \
  "$status_json_rel" \
  "$wrapper_out_rel" \
  "$wrapper_err_rel"

if [[ "$status" != "$AICR_STATUS_PASSED" ]]; then
  echo "Python runtime Slurm doctor failed: ${pass_basis}" >&2
  exit 1
fi

echo "Python runtime Slurm doctor passed: ${run_id}"
