#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/setup/promote-setup-baseline.sh --cluster <rtxpro6000|b200> \
    --container-compat-runid <setup_run_id> \
    --pytorch-smoke-runid <setup_run_id> \
    --hpc-benchmarks-smoke-runid <setup_run_id> \
    --elbencho-smoke-runid <setup_run_id> \
    [--promoted-by <name>] [--notes <text>] [--replace-existing] [--json]
EOF
}

cluster=""
container_compat_runid=""
pytorch_smoke_runid=""
hpc_smoke_runid=""
elbencho_smoke_runid=""
promoted_by="${USER:-unknown}"
notes=""
replace_existing=0
json_output=0
errors=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --container-compat-runid)
      container_compat_runid="${2:-}"
      shift 2
      ;;
    --pytorch-smoke-runid)
      pytorch_smoke_runid="${2:-}"
      shift 2
      ;;
    --hpc-benchmarks-smoke-runid)
      hpc_smoke_runid="${2:-}"
      shift 2
      ;;
    --elbencho-smoke-runid)
      elbencho_smoke_runid="${2:-}"
      shift 2
      ;;
    --promoted-by)
      promoted_by="${2:-}"
      shift 2
      ;;
    --notes)
      notes="${2:-}"
      shift 2
      ;;
    --replace-existing)
      replace_existing=1
      shift
      ;;
    --json)
      json_output=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      errors+=("unknown argument: $1")
      shift
      ;;
  esac
done

[[ -n "${cluster}" ]] || errors+=("--cluster is required")
[[ -n "${container_compat_runid}" ]] || errors+=("--container-compat-runid is required")
[[ -n "${pytorch_smoke_runid}" ]] || errors+=("--pytorch-smoke-runid is required")
[[ -n "${hpc_smoke_runid}" ]] || errors+=("--hpc-benchmarks-smoke-runid is required")
[[ -n "${elbencho_smoke_runid}" ]] || errors+=("--elbencho-smoke-runid is required")

errors_json() {
  aicr_python - "$@" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1:]))
PY
}

emit_json_envelope() {
  local ok="$1"
  local cluster_value="$2"
  local baseline_id="$3"
  local baseline_path="$4"
  local baseline_history_path="$5"
  local errors_json_value="$6"
  aicr_print_json_envelope \
    "${ok}" \
    "${cluster_value}" \
    "${baseline_id}" \
    "${baseline_path}" \
    "${baseline_history_path}" \
    "${errors_json_value}"
}

if (( ${#errors[@]} > 0 )); then
  baseline_path_guess="results/setup/${cluster:-unknown}/baseline.json"
  history_path_guess="results/setup/${cluster:-unknown}/baseline-history.jsonl"
  if [[ "${json_output}" == "1" ]]; then
    emit_json_envelope false "${cluster}" "" "${baseline_path_guess}" "${history_path_guess}" "$(errors_json "${errors[@]}")"
  else
    printf 'ERROR: %s\n' "${errors[@]}" >&2
    usage
  fi
  exit 2
fi

aicr_assert_supported_cluster "${cluster}"
aicr_require_repo_root

baseline_rel="$(aicr_setup_baseline_path "${cluster}")"
history_rel="$(aicr_setup_baseline_history_path "${cluster}")"
baseline_abs="${AICR_BMARK_DIR}/${baseline_rel}"
history_abs="${AICR_BMARK_DIR}/${history_rel}"
schema_abs="${AICR_BMARK_DIR}/schemas/baseline.schema.json"

python_cmd=(aicr_python)

previous_baseline_tmp="$(mktemp)"
if [[ -f "${baseline_abs}" ]]; then
  cp "${baseline_abs}" "${previous_baseline_tmp}"
  baseline_state="$(aicr_python - "${baseline_abs}" <<'PY'
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    print(json.load(fh).get('state', ''))
PY
)"
  if [[ "${baseline_state}" == "ready" && "${replace_existing}" != "1" ]]; then
    msg="baseline already exists in ready state; pass --replace-existing to replace it"
    if [[ "${json_output}" == "1" ]]; then
      emit_json_envelope false "${cluster}" "" "${baseline_rel}" "${history_rel}" "$(errors_json "${msg}")"
    else
      echo "ERROR: ${msg}" >&2
    fi
    rm -f "${previous_baseline_tmp}"
    exit 1
  fi
fi

validate_check() {
  local check="$1"
  local run_id="$2"
  local out_json="$3"
  local record_rel status_rel record_abs status_abs

  record_rel="$(aicr_setup_record_path "${cluster}" "${check}" "${run_id}")"
  status_rel="$(aicr_setup_parsed_status_path "${cluster}" "${check}" "${run_id}")"
  record_abs="${AICR_BMARK_DIR}/${record_rel}"
  status_abs="${AICR_BMARK_DIR}/${status_rel}"

  [[ -f "${record_abs}" ]] || { echo "missing canonical record: ${record_rel}" >&2; return 1; }
  [[ -f "${status_abs}" ]] || { echo "missing parsed status: ${status_rel}" >&2; return 1; }

  aicr_python - "${cluster}" "${check}" "${run_id}" "${record_rel}" "${status_rel}" "${record_abs}" "${status_abs}" > "${out_json}" <<'PY'
import json
import sys

cluster, check, run_id, record_rel, status_rel, record_abs, status_abs = sys.argv[1:]

with open(record_abs, 'r', encoding='utf-8') as fh:
    record = json.load(fh)
with open(status_abs, 'r', encoding='utf-8') as fh:
    status = json.load(fh)

errors = []
if record.get('cluster') != cluster:
    errors.append(f"record cluster mismatch: expected {cluster}, found {record.get('cluster')}")
if record.get('check') != check:
    errors.append(f"record check mismatch: expected {check}, found {record.get('check')}")
if record.get('run_id') != run_id:
    errors.append(f"record run_id mismatch: expected {run_id}, found {record.get('run_id')}")
if record.get('status') != 'passed':
    errors.append(f"record status is {record.get('status')}, expected passed")
if status.get('status') != 'passed':
    errors.append(f"parsed status is {status.get('status')}, expected passed")

if errors:
    raise SystemExit('; '.join(errors))

obj = {
    'run_id': run_id,
    'status': 'passed',
    'record_path': record_rel,
    'parsed_status_path': status_rel,
    'completed_at_utc': record.get('completed_at_utc'),
    'job_id': record.get('job_id'),
}
print(json.dumps(obj, indent=2))
PY
}

cc_json="$(mktemp)"
pt_json="$(mktemp)"
hb_json="$(mktemp)"
eb_json="$(mktemp)"

validation_errors=()
validate_check "${AICR_CHECK_CONTAINER_COMPAT}" "${container_compat_runid}" "${cc_json}" || validation_errors+=("container-compat validation failed for ${container_compat_runid}")
validate_check "${AICR_CHECK_PYTORCH_SMOKE}" "${pytorch_smoke_runid}" "${pt_json}" || validation_errors+=("pytorch-smoke validation failed for ${pytorch_smoke_runid}")
validate_check "${AICR_CHECK_HPC_BENCHMARKS_SMOKE}" "${hpc_smoke_runid}" "${hb_json}" || validation_errors+=("hpc-benchmarks-smoke validation failed for ${hpc_smoke_runid}")
validate_check "${AICR_CHECK_ELBENCHO_SMOKE}" "${elbencho_smoke_runid}" "${eb_json}" || validation_errors+=("elbencho-smoke validation failed for ${elbencho_smoke_runid}")

if (( ${#validation_errors[@]} > 0 )); then
  if [[ "${json_output}" == "1" ]]; then
    emit_json_envelope false "${cluster}" "" "${baseline_rel}" "${history_rel}" "$(errors_json "${validation_errors[@]}")"
  else
    printf 'ERROR: %s\n' "${validation_errors[@]}" >&2
  fi
    rm -f "${previous_baseline_tmp}" "${cc_json}" "${pt_json}" "${hb_json}" "${eb_json}"
  exit 1
fi

baseline_id="$(aicr_next_setup_baseline_id "${cluster}")"
promoted_at_utc="$(aicr_timestamp_utc)"
new_baseline_tmp="$(mktemp)"
compact_baseline_tmp="$(mktemp)"

aicr_python - "${baseline_id}" "${cluster}" "${promoted_at_utc}" "${promoted_by}" "${notes}" "${cc_json}" "${pt_json}" "${hb_json}" "${eb_json}" > "${new_baseline_tmp}" <<'PY'
import json
import sys

baseline_id, cluster, promoted_at_utc, promoted_by, notes, cc_json, pt_json, hb_json, eb_json = sys.argv[1:]

with open(cc_json, 'r', encoding='utf-8') as fh:
    cc = json.load(fh)
with open(pt_json, 'r', encoding='utf-8') as fh:
    pt = json.load(fh)
with open(hb_json, 'r', encoding='utf-8') as fh:
    hb = json.load(fh)
with open(eb_json, 'r', encoding='utf-8') as fh:
    eb = json.load(fh)

obj = {
    'schema_version': 1,
    'cluster': cluster,
    'baseline_id': baseline_id,
    'state': 'ready',
    'promoted_at_utc': promoted_at_utc,
    'promoted_by': promoted_by,
    'invalidated_at_utc': None,
    'invalidated_by': None,
    'notes': notes,
    'checks': {
        'container-compat': cc,
        'pytorch-smoke': pt,
        'hpc-benchmarks-smoke': hb,
        'elbencho-smoke': eb,
    },
}

print(json.dumps(obj, indent=2))
PY

if [[ -f "${schema_abs}" ]]; then
  "${python_cmd[@]}" - "${new_baseline_tmp}" "${schema_abs}" <<'PY'
import json
import sys
from jsonschema import Draft202012Validator

with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    obj = json.load(fh)
with open(sys.argv[2], 'r', encoding='utf-8') as fh:
    schema = json.load(fh)

Draft202012Validator(schema).validate(obj)
PY
fi

mkdir -p "$(dirname "${baseline_abs}")"
cp "${new_baseline_tmp}" "${baseline_abs}"

aicr_python - "${new_baseline_tmp}" > "${compact_baseline_tmp}" <<'PY'
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    print(json.dumps(json.load(fh), separators=(',', ':')))
PY

mkdir -p "$(dirname "${history_abs}")"
cat "${compact_baseline_tmp}" >> "${history_abs}"
printf '\n' >> "${history_abs}"

if [[ -s "${previous_baseline_tmp}" && "${json_output}" != "1" ]]; then
  aicr_python - "${previous_baseline_tmp}" "${new_baseline_tmp}" <<'PY'
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    old = json.load(fh)
with open(sys.argv[2], 'r', encoding='utf-8') as fh:
    new = json.load(fh)

if old.get('state') == 'ready':
    print('Replacement summary:')
    print(f"  previous baseline_id: {old.get('baseline_id')}")
    print(f"  new baseline_id: {new.get('baseline_id')}")
    for check in ('container-compat', 'pytorch-smoke', 'hpc-benchmarks-smoke', 'elbencho-smoke'):
        old_run = (old.get('checks') or {}).get(check, {}).get('run_id')
        new_run = (new.get('checks') or {}).get(check, {}).get('run_id')
        if old_run != new_run:
            print(f"  {check}: {old_run} -> {new_run}")
PY
fi

if [[ "${json_output}" == "1" ]]; then
  emit_json_envelope true "${cluster}" "${baseline_id}" "${baseline_rel}" "${history_rel}" '[]'
else
  echo "Promoted baseline ${baseline_id} for cluster ${cluster}"
  echo "Baseline path: ${baseline_rel}"
  echo "Baseline history path: ${history_rel}"
fi

rm -f "${previous_baseline_tmp}" "${cc_json}" "${pt_json}" "${hb_json}" "${eb_json}" "${new_baseline_tmp}" "${compact_baseline_tmp}"
