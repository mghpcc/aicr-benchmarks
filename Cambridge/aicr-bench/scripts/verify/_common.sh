#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/../lib/aicr-paths.sh"

aicr_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

aicr_gpu_count() {
  if aicr_have_cmd nvidia-smi; then
    nvidia-smi -L 2>/dev/null | grep -c '^GPU ' || true
  else
    echo 0
  fi
}

aicr_expected_gpu_count_for_cluster() {
  case "$1" in
    b200|rtxpro6000) printf '8\n' ;;
    *) printf '0\n' ;;
  esac
}

aicr_cluster_requires_gpu_presence_preflight() {
  [[ "$1" == "rtxpro6000" ]]
}

aicr_gpu_presence_note() {
  local found="$1"
  local expected="$2"
  printf 'found %s of %s GPUs\n' "$found" "$expected"
}

aicr_run_gpu_presence_preflight() {
  local cluster="$1"
  local inventory_path="$2"
  local expected
  local found

  expected="$(aicr_expected_gpu_count_for_cluster "$cluster")"
  [[ "$expected" =~ ^[0-9]+$ ]] || expected=0

  AICR_GPU_PREFLIGHT_REQUIRED=0
  AICR_GPU_PREFLIGHT_STATUS="Not required"
  AICR_GPU_PREFLIGHT_EXPECTED="$expected"
  AICR_GPU_PREFLIGHT_FOUND=0
  AICR_GPU_PREFLIGHT_NOTE=""

  if ! aicr_cluster_requires_gpu_presence_preflight "$cluster"; then
    return 0
  fi

  AICR_GPU_PREFLIGHT_REQUIRED=1
  mkdir -p "$(dirname "$inventory_path")"

  if aicr_have_cmd nvidia-smi; then
    nvidia-smi -L >"$inventory_path" 2>&1 || true
  else
    printf 'nvidia-smi not found\n' >"$inventory_path"
  fi

  found="$(grep -c '^GPU ' "$inventory_path" 2>/dev/null || true)"
  [[ "$found" =~ ^[0-9]+$ ]] || found=0
  AICR_GPU_PREFLIGHT_FOUND="$found"

  if [[ "$expected" -gt 0 && "$found" -eq "$expected" ]]; then
    AICR_GPU_PREFLIGHT_STATUS="Pass"
    return 0
  fi

  AICR_GPU_PREFLIGHT_STATUS="Fail"
  AICR_GPU_PREFLIGHT_NOTE="$(aicr_gpu_presence_note "$found" "$expected")"
  return 1
}

aicr_filter_nodes_by_topology_gpu_preflight() {
  local cluster="$1"
  local date_utc="$2"
  local input_nodes_file="$3"
  local output_nodes_file="$4"
  local skipped_nodes_file="$5"
  local excluded_json_file="$6"
  local expected

  expected="$(aicr_expected_gpu_count_for_cluster "$cluster")"
  [[ "$expected" =~ ^[0-9]+$ ]] || expected=0

  aicr_python - \
    "$AICR_BMARK_DIR" \
    "$cluster" \
    "$date_utc" \
    "$expected" \
    "$input_nodes_file" \
    "$output_nodes_file" \
    "$skipped_nodes_file" \
    "$excluded_json_file" <<'PY'
import json
import sys
from pathlib import Path

(
    repo_root,
    cluster,
    date_utc,
    expected_text,
    input_nodes_path,
    output_nodes_path,
    skipped_nodes_path,
    excluded_json_path,
) = sys.argv[1:]

repo = Path(repo_root)
expected = int(expected_text)
input_nodes = Path(input_nodes_path)
output_nodes = Path(output_nodes_path)
skipped_nodes = Path(skipped_nodes_path)
excluded_json = Path(excluded_json_path)

nodes = [
    line.strip()
    for line in input_nodes.read_text(encoding="utf-8").splitlines()
    if line.strip()
]


def to_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def rel(path):
    if path is None:
        return None
    try:
        return str(path.relative_to(repo))
    except ValueError:
        return str(path)


def latest_summary(node):
    base = repo / "results" / "by-date" / date_utc / "parsed" / cluster / "nodes" / node / "gpu-topology"
    matches = sorted(base.glob("*/summary.json"))
    if not matches:
        return None
    return matches[-1]


kept = []
excluded = []
for node in nodes:
    summary_path = latest_summary(node)
    if summary_path is None:
        excluded.append({
            "node": node,
            "state": "gpu-preflight-missing",
            "reason": "missing same-day gpu-topology summary",
            "summary_json_path": None,
            "status": None,
            "gpu_count": None,
            "expected_gpu_count": expected,
            "gpu_count_status": None,
        })
        continue

    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        excluded.append({
            "node": node,
            "state": "gpu-preflight-missing",
            "reason": f"unreadable gpu-topology summary: {exc}",
            "summary_json_path": rel(summary_path),
            "status": None,
            "gpu_count": None,
            "expected_gpu_count": expected,
            "gpu_count_status": None,
        })
        continue

    status = summary.get("status")
    gpu_count = to_int(summary.get("gpu_count"))
    expected_gpu_count = to_int(summary.get("expected_gpu_count"))
    gpu_count_status = summary.get("gpu_count_status")
    reasons = []
    if status != "passed":
        reasons.append(f"topology status {status or 'missing'}")
    if gpu_count != expected:
        reasons.append(f"found {gpu_count if gpu_count is not None else 'missing'} of {expected} GPUs")
    if expected_gpu_count != expected:
        reasons.append(
            f"expected_gpu_count {expected_gpu_count if expected_gpu_count is not None else 'missing'}"
        )
    if gpu_count_status != "Pass":
        reasons.append(f"gpu_count_status {gpu_count_status or 'missing'}")

    if reasons:
        excluded.append({
            "node": node,
            "state": "gpu-preflight-failed",
            "reason": "; ".join(reasons),
            "summary_json_path": rel(summary_path),
            "status": status,
            "gpu_count": gpu_count,
            "expected_gpu_count": expected_gpu_count,
            "gpu_count_status": gpu_count_status,
        })
        continue

    kept.append(node)

output_nodes.write_text("".join(f"{node}\n" for node in kept), encoding="utf-8")
if excluded:
    with skipped_nodes.open("a", encoding="utf-8") as handle:
        for item in excluded:
            handle.write(f"{item['state']}|{item['node']}\n")
excluded_json.write_text(json.dumps(excluded, indent=2) + "\n", encoding="utf-8")
PY
}

aicr_print_gpu_preflight_filter_summary() {
  local expected="$1"
  local nodes_file="$2"
  local excluded_json_file="$3"
  local kept_count

  kept_count="$(wc -l <"$nodes_file" | tr -d ' ')"

  aicr_python - "$expected" "$kept_count" "$excluded_json_file" <<'PY'
import json
import sys
from pathlib import Path

expected, kept_count, excluded_path = sys.argv[1:4]
path = Path(excluded_path)
try:
    excluded = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
except json.JSONDecodeError:
    excluded = []

print("GPU preflight filter : enabled")
print("GPU preflight source : latest same-day gpu-topology parsed summaries")
print(f"GPU preflight expected: {expected} GPUs")
print(f"GPU preflight kept   : {kept_count}")
print(f"GPU preflight excluded: {len(excluded)}")
for item in excluded:
    node = item.get("node", "unknown")
    reason = item.get("reason") or item.get("state") or "excluded"
    summary = item.get("summary_json_path")
    suffix = f" ({summary})" if summary else ""
    print(f"  {node}: {reason}{suffix}")
PY
}

aicr_write_json_file() {
  local path="$1"
  local payload="$2"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$payload" > "$path"
}

aicr_write_summary_status_pair() {
  local summary_path="$1"
  local status_path="$2"
  local summary_payload="$3"
  local status="$4"
  local pass_basis="$5"

  local status_payload
  status_payload="$(
    aicr_python - "$status" "$pass_basis" <<'PY'
import json
import sys

status, pass_basis = sys.argv[1:3]
print(json.dumps({
    "status": status,
    "pass_basis": pass_basis,
}, indent=2))
PY
  )"

  aicr_write_json_file "$summary_path" "$summary_payload"
  aicr_write_json_file "$status_path" "$status_payload"
}

aicr_join_csv() {
  local out=""
  local item
  for item in "$@"; do
    [[ -n "$item" ]] || continue
    if [[ -z "$out" ]]; then
      out="$item"
    else
      out="$out,$item"
    fi
  done
  printf '%s\n' "$out"
}

aicr_emit_record_from_args() {
  local record_path="$1"
  local scope="$2"
  local cluster="$3"
  local node="$4"
  local peers_csv="$5"
  local check="$6"
  local mode="$7"
  local run_id="$8"
  local date_utc="$9"
  local submitted_at="${10}"
  local completed_at="${11}"
  local partition="${12}"
  local job_id="${13}"
  local status="${14}"
  local pass_basis="${15}"
  local node_count="${16}"
  local gpu_count="${17}"
  local canonical_csv="${18}"
  local parsed_csv="${19}"
  local wrapper_csv="${20}"
  local notes="${21}"

  mkdir -p "$(dirname "$record_path")"

  aicr_python - \
    "$record_path" \
    "$scope" \
    "$cluster" \
    "$node" \
    "$peers_csv" \
    "$check" \
    "$mode" \
    "$run_id" \
    "$date_utc" \
    "$submitted_at" \
    "$completed_at" \
    "$partition" \
    "$job_id" \
    "$status" \
    "$pass_basis" \
    "$node_count" \
    "$gpu_count" \
    "$canonical_csv" \
    "$parsed_csv" \
    "$wrapper_csv" \
    "$notes" <<'PY'
import json
import sys

(
    record_path,
    scope,
    cluster,
    node,
    peers_csv,
    check,
    mode,
    run_id,
    date_utc,
    submitted_at,
    completed_at,
    partition,
    job_id,
    status,
    pass_basis,
    node_count,
    gpu_count,
    canonical_csv,
    parsed_csv,
    wrapper_csv,
    notes,
) = sys.argv[1:]

def split_csv(value):
    return [x for x in value.split(",") if x]

obj = {
    "schema_version": 1,
    "scope": scope,
    "cluster": cluster,
    "node": None if node == "" else node,
    "peer_nodes": split_csv(peers_csv),
    "check": check,
    "subcheck": None,
    "mode": mode,
    "run_id": run_id,
    "date": date_utc,
    "submitted_at_utc": submitted_at,
    "launched_at_utc": submitted_at,
    "completed_at_utc": completed_at,
    "partition": None if partition == "" else partition,
    "job_id": None if job_id == "" else job_id,
    "status": status,
    "pass_basis": pass_basis,
    "notes": notes,
    "node_count": int(node_count),
    "gpu_count": int(gpu_count),
    "wrapper_log_paths": split_csv(wrapper_csv),
    "canonical_artifact_paths": split_csv(canonical_csv),
    "parsed_artifact_paths": split_csv(parsed_csv),
    "setup_baseline_ref": {
        "cluster": cluster,
        "baseline_path": f"results/setup/{cluster}/baseline.json",
        "baseline_id": None,
    },
}

with open(record_path, "w", encoding="utf-8") as f:
    json.dump(obj, f, indent=2)
    f.write("\n")
PY
}

aicr_append_index_row_from_record() {
  local jsonl_path="$1"
  local record_path="$2"

  mkdir -p "$(dirname "$jsonl_path")"

  aicr_python - "$jsonl_path" "$record_path" <<'PY'
import json
import sys

jsonl_path, record_path = sys.argv[1:3]

def rel_results(path):
    if not path:
        return path
    marker = "/results/"
    if marker in path:
        return "results/" + path.split(marker, 1)[1]
    return path

with open(record_path, "r", encoding="utf-8") as f:
    obj = json.load(f)

setup_ref = obj.get("setup_baseline_ref", {}) or {}

row = {
    "schema_version": 1,
    "view_date": obj.get("date"),
    "scope": obj.get("scope"),
    "cluster": obj.get("cluster"),
    "node": obj.get("node"),
    "peer_nodes": obj.get("peer_nodes", []),
    "check": obj.get("check"),
    "subcheck": obj.get("subcheck"),
    "mode": obj.get("mode"),
    "run_id": obj.get("run_id"),
    "status": obj.get("status"),
    "display_state": obj.get("status"),
    "pass_basis": obj.get("pass_basis"),
    "submitted_at_utc": obj.get("submitted_at_utc"),
    "completed_at_utc": obj.get("completed_at_utc"),
    "job_id": obj.get("job_id"),
    "partition": obj.get("partition"),
    "node_count": obj.get("node_count"),
    "gpu_count": obj.get("gpu_count"),
    "setup_baseline_id": setup_ref.get("baseline_id"),
    "setup_baseline_path": setup_ref.get("baseline_path"),
    "record_path": rel_results(record_path),
    "wrapper_log_paths": [rel_results(p) for p in obj.get("wrapper_log_paths", [])],
    "canonical_artifact_paths": [rel_results(p) for p in obj.get("canonical_artifact_paths", [])],
    "parsed_artifact_paths": [rel_results(p) for p in obj.get("parsed_artifact_paths", [])],
    "notes": obj.get("notes", ""),
}

with open(jsonl_path, "a", encoding="utf-8") as f:
    f.write(json.dumps(row))
    f.write("\n")
PY
}
