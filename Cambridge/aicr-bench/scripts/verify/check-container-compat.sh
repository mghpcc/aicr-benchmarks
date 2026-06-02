#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/_common.sh"

aicr_require_repo_root
aicr_mkdirs

print_next_steps() {
  local cluster_name="$1"
  cat <<EOM
Next steps:
  3. Validate canonical runtime assets:
     bash scripts/setup/check-runtime-assets.sh
  4. Submit smoke tests from repo root so benchmark-settings.env resolves via SLURM_SUBMIT_DIR:
     sbatch --mem=0 slurm/verify/${cluster_name}-pytorch-smoke.sbatch
     sbatch --mem=0 slurm/verify/${cluster_name}-hpc-benchmarks-smoke.sbatch
     sbatch --mem=0 slurm/verify/${cluster_name}-elbencho-smoke.sbatch
EOM
}

cluster="${AICR_CLUSTER_NAME:-$(aicr_cluster_name)}"
aicr_assert_supported_cluster "$cluster"

required_commands=(apptainer sbatch)
missing=()
for cmd in "${required_commands[@]}"; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

run_id="${SETUP_RUN_ID:-$(aicr_next_setup_run_id "$cluster" "$AICR_CHECK_CONTAINER_COMPAT")}"
raw_rel="$(aicr_setup_raw_run_dir "$cluster" "$AICR_CHECK_CONTAINER_COMPAT" "$run_id")"
parsed_rel="$(aicr_setup_parsed_run_dir "$cluster" "$AICR_CHECK_CONTAINER_COMPAT" "$run_id")"
mkdir -p \
  "${AICR_BMARK_DIR}/${raw_rel}/canonical" \
  "${AICR_BMARK_DIR}/${raw_rel}/wrapper" \
  "${AICR_BMARK_DIR}/${raw_rel}/metadata" \
  "${AICR_BMARK_DIR}/${parsed_rel}"

summary_rel="${raw_rel}/canonical/container-compat-summary.txt"
wrapper_out_rel="${raw_rel}/wrapper/slurm-${SLURM_JOB_ID:-manual}.out"
wrapper_err_rel="${raw_rel}/wrapper/slurm-${SLURM_JOB_ID:-manual}.err"
: > "${AICR_BMARK_DIR}/${wrapper_out_rel}"
: > "${AICR_BMARK_DIR}/${wrapper_err_rel}"

host="$(hostname -s 2>/dev/null || hostname)"
gpu_name="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)"
gpu_count="$(aicr_gpu_count)"
driver_version="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n 1 || true)"
status="passed"
(( ${#missing[@]} == 0 )) || status="failed"

{
  echo "host=${host}"
  echo "cluster=${cluster}"
  echo "gpu_name=${gpu_name}"
  echo "gpu_count=${gpu_count}"
  echo "driver_version=${driver_version}"
  echo "required_commands=${required_commands[*]}"
  echo "missing_commands=${missing[*]:-}"
  echo "status=${status}"
} > "${AICR_BMARK_DIR}/${summary_rel}"

summary_json_rel="${parsed_rel}/summary.json"
status_json_rel="${parsed_rel}/status.json"

aicr_python - "$host" "$cluster" "$gpu_name" "$gpu_count" "$driver_version" "$status" "${missing[*]:-}" > "${AICR_BMARK_DIR}/${summary_json_rel}" <<'PY'
import json, sys
host, cluster, gpu_name, gpu_count, driver_version, status, missing = sys.argv[1:]
print(json.dumps({
    "status": status,
    "host": host,
    "cluster": cluster,
    "gpu_name": gpu_name,
    "gpu_count": int(gpu_count or 0),
    "driver_version": driver_version,
    "missing_commands": [x for x in missing.split() if x],
}, indent=2))
PY

aicr_python - "$status" > "${AICR_BMARK_DIR}/${status_json_rel}" <<'PY'
import json, sys
print(json.dumps({
    "status": sys.argv[1],
    "pass_basis": f"parsed.summary.status={sys.argv[1]}"
}, indent=2))
PY

record_rel="$(aicr_setup_record_path "$cluster" "$AICR_CHECK_CONTAINER_COMPAT" "$run_id")"
aicr_python - "${AICR_BMARK_DIR}/${record_rel}" "$cluster" "$run_id" "$status" "$summary_rel" "$summary_json_rel" "$status_json_rel" "$wrapper_out_rel" "$wrapper_err_rel" "$gpu_count" <<'PY'
import json, sys
from datetime import datetime
from pathlib import Path

record_path, cluster, run_id, status, summary_rel, summary_json_rel, status_json_rel, wrapper_out_rel, wrapper_err_rel, gpu_count = sys.argv[1:]
now = datetime.utcnow().replace(microsecond=0).isoformat() + 'Z'
obj = {
    "schema_version": 1,
    "scope": "setup",
    "cluster": cluster,
    "node": None,
    "peer_nodes": [],
    "check": "container-compat",
    "subcheck": None,
    "mode": "setup",
    "run_id": run_id,
    "date": datetime.utcnow().strftime('%Y-%m-%d'),
    "submitted_at_utc": now,
    "launched_at_utc": now,
    "completed_at_utc": now,
    "partition": None,
    "job_id": None,
    "status": status,
    "pass_basis": f"parsed.summary.status={status}",
    "notes": "",
    "node_count": 1,
    "gpu_count": int(gpu_count or 0),
    "wrapper_log_paths": [wrapper_out_rel, wrapper_err_rel],
    "canonical_artifact_paths": [summary_rel],
    "parsed_artifact_paths": [summary_json_rel, status_json_rel],
    "setup_baseline_ref": {
        "cluster": cluster,
        "baseline_path": f"results/setup/{cluster}/baseline.json",
        "baseline_id": None,
    },
}
Path(record_path).parent.mkdir(parents=True, exist_ok=True)
Path(record_path).write_text(json.dumps(obj, indent=2) + '\n')
PY

if [[ "$status" != "passed" ]]; then
  {
    echo "Setup compatibility failed for cluster ${cluster}."
    if (( ${#missing[@]} > 0 )); then
      echo "Missing required commands: ${missing[*]}"
    fi
    echo "Canonical summary: ${summary_rel}"
    echo "Parsed status: ${status_json_rel}"
    echo "Record: ${record_rel}"
  } >&2
  exit 1
fi

echo "Setup compatibility passed for cluster ${cluster}."
echo "Run ID: ${run_id}"
echo "Canonical summary: ${summary_rel}"
echo "Parsed status: ${status_json_rel}"
echo "Record: ${record_rel}"
echo
print_next_steps "$cluster"
