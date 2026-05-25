#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR}/_common.sh"
aicr_require_repo_root
aicr_mkdirs
cluster="${AICR_CLUSTER_NAME:-$(aicr_cluster_name)}"
aicr_assert_supported_cluster "$cluster"
image="${1:-${ELBENCHO_IMAGE:-${AICR_ELBENCHO_IMAGE}}}"
run_id="${SETUP_RUN_ID:-$(aicr_next_setup_run_id "$cluster" "$AICR_CHECK_ELBENCHO_SMOKE")}"
raw_rel="$(aicr_setup_raw_run_dir "$cluster" "$AICR_CHECK_ELBENCHO_SMOKE" "$run_id")"
parsed_rel="$(aicr_setup_parsed_run_dir "$cluster" "$AICR_CHECK_ELBENCHO_SMOKE" "$run_id")"
mkdir -p "${AICR_BMARK_DIR}/${raw_rel}/canonical" "${AICR_BMARK_DIR}/${raw_rel}/wrapper" "${AICR_BMARK_DIR}/${raw_rel}/metadata" "${AICR_BMARK_DIR}/${parsed_rel}"
summary_rel="${raw_rel}/canonical/elbencho-smoke-summary.txt"
wrapper_out_rel="${raw_rel}/wrapper/slurm-${SLURM_JOB_ID:-manual}.out"
wrapper_err_rel="${raw_rel}/wrapper/slurm-${SLURM_JOB_ID:-manual}.err"
: >"${AICR_BMARK_DIR}/${wrapper_out_rel}"
: >"${AICR_BMARK_DIR}/${wrapper_err_rel}"
host="$(hostname -s 2>/dev/null || hostname)"
gpu_count="$(aicr_gpu_count)"
gpu_name="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n 1 || true)"
status="passed"
version=""
features=""
[[ -f "$image" ]] || status="failed"
if [[ "$status" == "passed" ]] && command -v apptainer >/dev/null 2>&1; then
  if ! apptainer exec ${AICR_APPTAINER_COMMON_OPTS} --nv "$image" elbencho --version >"${AICR_BMARK_DIR}/${wrapper_out_rel}" 2>"${AICR_BMARK_DIR}/${wrapper_err_rel}"; then
    status="failed"
  fi
else
  echo "apptainer not available or image missing" >"${AICR_BMARK_DIR}/${wrapper_err_rel}"
fi
if [[ -s "${AICR_BMARK_DIR}/${wrapper_out_rel}" ]]; then
  version="$(awk -F': ' '/Version:/ {print $2; exit}' "${AICR_BMARK_DIR}/${wrapper_out_rel}")"
  features="$(awk -F': ' '/Included optional build features:/ {print $2; exit}' "${AICR_BMARK_DIR}/${wrapper_out_rel}")"
fi
if [[ "$status" == "passed" ]]; then
  if [[ "$features" != *cuda* || "$features" != *cufile/gds* ]]; then
    status="failed"
    echo "elbencho image missing expected cuda or cufile/gds features" >>"${AICR_BMARK_DIR}/${wrapper_err_rel}"
  fi
fi
printf 'host=%s\ncluster=%s\nimage=%s\ngpu_name=%s\ngpu_count=%s\nversion=%s\nfeatures=%s\nstatus=%s\n' "$host" "$cluster" "$image" "$gpu_name" "$gpu_count" "$version" "$features" "$status" >"${AICR_BMARK_DIR}/${summary_rel}"
summary_json_rel="${parsed_rel}/summary.json"
status_json_rel="${parsed_rel}/status.json"
aicr_python - "$host" "$cluster" "$image" "$gpu_name" "$gpu_count" "$version" "$features" "$status" >"${AICR_BMARK_DIR}/${summary_json_rel}" <<'PY'
import json
import sys

host, cluster, image, gpu_name, gpu_count, version, features, status = sys.argv[1:]
print(json.dumps({
    "status": status,
    "host": host,
    "cluster": cluster,
    "image": image,
    "gpu_name": gpu_name,
    "gpu_count": int(gpu_count or 0),
    "version": version or None,
    "features": features.split() if features else [],
}, indent=2))
PY
aicr_python - "$status" >"${AICR_BMARK_DIR}/${status_json_rel}" <<'PY'
import json
import sys
print(json.dumps({"status": sys.argv[1], "pass_basis": f"parsed.summary.status={sys.argv[1]}"}, indent=2))
PY
record_rel="$(aicr_setup_record_path "$cluster" "$AICR_CHECK_ELBENCHO_SMOKE" "$run_id")"
aicr_python - "${AICR_BMARK_DIR}/${record_rel}" "$cluster" "$run_id" "$status" "$summary_rel" "$summary_json_rel" "$status_json_rel" "$wrapper_out_rel" "$wrapper_err_rel" "$gpu_count" <<'PY'
import json
import sys
from pathlib import Path
from datetime import datetime, timezone

record_path, cluster, run_id, status, summary_rel, summary_json_rel, status_json_rel, wrapper_out_rel, wrapper_err_rel, gpu_count = sys.argv[1:]
now = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
obj = {
    "schema_version": 1,
    "scope": "setup",
    "cluster": cluster,
    "node": None,
    "peer_nodes": [],
    "check": "elbencho-smoke",
    "subcheck": None,
    "mode": "setup",
    "run_id": run_id,
    "date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
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
Path(record_path).write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY
