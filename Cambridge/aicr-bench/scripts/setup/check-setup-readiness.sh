#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<EOF
Usage: $0 --cluster <rtxpro6000|b200> [--json]
EOF
}

cluster=""
json_output=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
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
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ -n "${cluster}" ]] || {
  usage
  exit 2
}

aicr_assert_supported_cluster "${cluster}"
aicr_require_repo_root

required_checks=(
  "${AICR_CHECK_CONTAINER_COMPAT}"
  "${AICR_CHECK_PYTORCH_SMOKE}"
  "${AICR_CHECK_HPC_BENCHMARKS_SMOKE}"
  "${AICR_CHECK_ELBENCHO_SMOKE}"
)

json_tmp="$(mktemp)"
export AICR_BMARK_DIR cluster json_tmp

aicr_python - <<'PY'
import json
import os
from pathlib import Path

repo_root = Path(os.environ["AICR_BMARK_DIR"])
cluster = os.environ["cluster"]
out_path = Path(os.environ["json_tmp"])
checks = ["container-compat", "pytorch-smoke", "hpc-benchmarks-smoke", "elbencho-smoke"]

result = {
    "ok": False,
    "cluster": cluster,
    "ready_to_promote": False,
    "checks": {},
    "promote_command": None,
    "errors": [],
}

for check in checks:
    parsed_root = repo_root / "results" / "setup" / cluster / "parsed" / check
    raw_root = repo_root / "results" / "setup" / cluster / "raw" / check
    info = {
        "check": check,
        "run_id": None,
        "status": "missing",
        "record_path": None,
        "parsed_status_path": None,
        "completed_at_utc": None,
        "message": None,
    }

    if not parsed_root.exists():
        info["message"] = f"no parsed artifacts found under {parsed_root.relative_to(repo_root)}"
        result["checks"][check] = info
        result["errors"].append(f"{check}: {info['message']}")
        continue

    candidates = sorted([p for p in parsed_root.iterdir() if p.is_dir()])
    if not candidates:
        info["message"] = f"no setup run directories found under {parsed_root.relative_to(repo_root)}"
        result["checks"][check] = info
        result["errors"].append(f"{check}: {info['message']}")
        continue

    run_dir = candidates[-1]
    run_id = run_dir.name
    status_path = run_dir / "status.json"
    record_path = raw_root / run_id / "metadata" / "record.json"

    info["run_id"] = run_id
    info["record_path"] = str(record_path.relative_to(repo_root))
    info["parsed_status_path"] = str(status_path.relative_to(repo_root))

    if not status_path.exists():
        info["message"] = f"missing parsed status file {status_path.relative_to(repo_root)}"
        result["checks"][check] = info
        result["errors"].append(f"{check}: {info['message']}")
        continue

    if not record_path.exists():
        info["message"] = f"missing canonical record file {record_path.relative_to(repo_root)}"
        result["checks"][check] = info
        result["errors"].append(f"{check}: {info['message']}")
        continue

    try:
        status_obj = json.loads(status_path.read_text(encoding="utf-8"))
        record_obj = json.loads(record_path.read_text(encoding="utf-8"))
    except Exception as exc:
        info["message"] = f"failed to parse canonical artifacts: {exc}"
        result["checks"][check] = info
        result["errors"].append(f"{check}: {info['message']}")
        continue

    parsed_status = status_obj.get("status")
    record_status = record_obj.get("status")
    record_cluster = record_obj.get("cluster")
    record_check = record_obj.get("check")
    record_run_id = record_obj.get("run_id")
    completed_at_utc = record_obj.get("completed_at_utc")
    info["completed_at_utc"] = completed_at_utc

    consistency_errors = []
    if record_cluster != cluster:
        consistency_errors.append(f"record cluster mismatch: expected {cluster}, found {record_cluster}")
    if record_check != check:
        consistency_errors.append(f"record check mismatch: expected {check}, found {record_check}")
    if record_run_id != run_id:
        consistency_errors.append(f"record run_id mismatch: expected {run_id}, found {record_run_id}")
    if parsed_status != "passed":
        consistency_errors.append(f"parsed status is {parsed_status}, expected passed")
    if record_status != "passed":
        consistency_errors.append(f"record status is {record_status}, expected passed")

    if consistency_errors:
        info["status"] = parsed_status or record_status or "failed"
        info["message"] = "; ".join(consistency_errors)
        result["checks"][check] = info
        result["errors"].append(f"{check}: {info['message']}")
        continue

    info["status"] = "passed"
    info["message"] = "ready"
    result["checks"][check] = info

all_ready = all(result["checks"].get(check, {}).get("status") == "passed" for check in checks)
result["ready_to_promote"] = all_ready
result["ok"] = all_ready

if all_ready:
    cc = result["checks"]["container-compat"]["run_id"]
    pt = result["checks"]["pytorch-smoke"]["run_id"]
    hb = result["checks"]["hpc-benchmarks-smoke"]["run_id"]
    eb = result["checks"]["elbencho-smoke"]["run_id"]
    result["promote_command"] = (
        "bash scripts/setup/promote-setup-baseline.sh "
        f"--cluster {cluster} "
        f"--container-compat-runid {cc} "
        f"--pytorch-smoke-runid {pt} "
        f"--hpc-benchmarks-smoke-runid {hb} "
        f"--elbencho-smoke-runid {eb}"
    )

out_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
PY

if [[ "${json_output}" == "1" ]]; then
  cat "${json_tmp}"
else
  aicr_python - "${json_tmp}" <<'PY'
import json
import sys
from pathlib import Path

obj = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

if obj["ready_to_promote"]:
    print(f"SETUP READY TO PROMOTE for cluster {obj['cluster']}")
else:
    print(f"SETUP NOT READY for cluster {obj['cluster']}")

print()

for check in ("container-compat", "pytorch-smoke", "hpc-benchmarks-smoke", "elbencho-smoke"):
    info = obj["checks"].get(check, {})
    print(f"- {check}: {info.get('status', 'missing')}")
    if info.get("run_id"):
        print(f"  run_id: {info['run_id']}")
    if info.get("completed_at_utc"):
        print(f"  completed_at_utc: {info['completed_at_utc']}")
    if info.get("record_path"):
        print(f"  record: {info['record_path']}")
    if info.get("parsed_status_path"):
        print(f"  status: {info['parsed_status_path']}")
    if info.get("message"):
        print(f"  note: {info['message']}")

print()

if obj.get("promote_command"):
    print("Promote with:")
    print(obj["promote_command"])
else:
    print("Promotion is blocked until all four setup checks are present and passed.")
PY
fi

ready="$(
aicr_python - "${json_tmp}" <<'PY'
import json
import sys
from pathlib import Path
print("yes" if json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("ready_to_promote") else "no")
PY
)"
rm -f "${json_tmp}"

if [[ "${ready}" == "yes" ]]; then
  exit 0
fi
exit 1
