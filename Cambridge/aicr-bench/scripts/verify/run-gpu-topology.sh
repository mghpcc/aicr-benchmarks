#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/_common.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/verify/run-gpu-topology.sh [--help]

Collect GPU inventory, GPU topology, CPU, NIC, and storage-affinity evidence for
the current node. Run this command inside a Slurm allocation or on an AICR HPC
compute node.

Environment:
  AICR_CLUSTER_NAME        Override cluster detection with b200 or rtxpro6000.
  GPU_TOPOLOGY_RUN_ID     Override the generated run identifier.
  AICR_SETTINGS_FILE      Settings file sourced by the calling Slurm wrapper.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

expected_gpu_model_contains_for_cluster() {
  case "$1" in
    b200) printf 'B200\n' ;;
    rtxpro6000) printf 'RTX PRO 6000\n' ;;
    *) printf '\n' ;;
  esac
}

aicr_require_repo_root
aicr_mkdirs
cluster="${AICR_CLUSTER_NAME:-$(aicr_cluster_name)}"
aicr_assert_supported_cluster "$cluster"
date_utc="$(aicr_today_date)"
node_short="$(hostname -s 2>/dev/null || hostname)"
run_id="${GPU_TOPOLOGY_RUN_ID:-$(aicr_next_by_date_run_id "$date_utc" "$cluster" "$AICR_SCOPE_NODE" "$AICR_CHECK_GPU_TOPOLOGY" "$node_short")}"
raw_rel="$(aicr_node_raw_run_dir "$date_utc" "$cluster" "$node_short" "$AICR_CHECK_GPU_TOPOLOGY" "$run_id")"
parsed_rel="$(aicr_node_parsed_run_dir "$date_utc" "$cluster" "$node_short" "$AICR_CHECK_GPU_TOPOLOGY" "$run_id")"
raw_dir="${AICR_BMARK_DIR}/${raw_rel}"
parsed_dir="${AICR_BMARK_DIR}/${parsed_rel}"
mkdir -p "$raw_dir/canonical" "$raw_dir/wrapper" "$raw_dir/metadata" "$parsed_dir"

job_id="${SLURM_JOB_ID:-}"
partition="${SLURM_JOB_PARTITION:-${SLURM_PARTITION:-}}"
submitted_at="$(aicr_timestamp_utc)"
wrapper_out_rel="${raw_rel}/wrapper/slurm-${job_id:-manual}.out"
wrapper_err_rel="${raw_rel}/wrapper/slurm-${job_id:-manual}.err"
: > "${AICR_BMARK_DIR}/${wrapper_out_rel}"
: > "${AICR_BMARK_DIR}/${wrapper_err_rel}"

inventory_rel="${raw_rel}/canonical/nvidia-smi-L.txt"
topo_rel="${raw_rel}/canonical/nvidia-smi-topo-m.txt"
lscpu_rel="${raw_rel}/canonical/lscpu.txt"
mlx5_rel="${raw_rel}/canonical/mlx5-topology.txt"
storage_rel="${raw_rel}/canonical/gds-storage-topology.txt"
summary_rel="${raw_rel}/canonical/gpu-topology-summary.txt"
inventory_abs="${AICR_BMARK_DIR}/${inventory_rel}"
topo_abs="${AICR_BMARK_DIR}/${topo_rel}"
lscpu_abs="${AICR_BMARK_DIR}/${lscpu_rel}"
mlx5_abs="${AICR_BMARK_DIR}/${mlx5_rel}"
storage_abs="${AICR_BMARK_DIR}/${storage_rel}"
summary_abs="${AICR_BMARK_DIR}/${summary_rel}"
capture_storage_for_cluster="0"
if [[ "$cluster" == "b200" ]]; then
  capture_storage_for_cluster="1"
else
  storage_rel=""
  storage_abs=""
fi

nvidia_l_status="Fail"
nvidia_topo_status="Fail"
lscpu_status="Fail"
mlx5_status="Fail"
storage_status="Skipped"
if command -v nvidia-smi >/dev/null 2>&1; then
  if nvidia-smi -L > "$inventory_abs" 2>>"${AICR_BMARK_DIR}/${wrapper_err_rel}"; then nvidia_l_status="Pass"; fi
  if nvidia-smi topo -m > "$topo_abs" 2>>"${AICR_BMARK_DIR}/${wrapper_err_rel}"; then nvidia_topo_status="Pass"; fi
fi
if command -v lscpu >/dev/null 2>&1; then
  if lscpu > "$lscpu_abs" 2>>"${AICR_BMARK_DIR}/${wrapper_err_rel}"; then lscpu_status="Pass"; fi
fi

capture_mlx5_topology() {
  shopt -s nullglob
  for ib_path in /sys/class/infiniband/mlx5_*; do
    local ib_device
    local numa_node=""
    local local_cpulist=""
    local netdevs=""
    ib_device="$(basename "$ib_path")"
    [[ -f "${ib_path}/device/numa_node" ]] && numa_node="$(<"${ib_path}/device/numa_node")"
    [[ -f "${ib_path}/device/local_cpulist" ]] && local_cpulist="$(<"${ib_path}/device/local_cpulist")"
    if [[ -d "${ib_path}/device/net" ]]; then
      netdevs="$(find "${ib_path}/device/net" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | paste -sd, -)"
    fi
    printf 'ib_device %s numa_node=%s local_cpulist=%s netdevs=%s\n' "$ib_device" "$numa_node" "$local_cpulist" "$netdevs"
  done
  shopt -u nullglob

  if command -v ibdev2netdev >/dev/null 2>&1; then
    printf 'ibdev2netdev_begin\n'
    ibdev2netdev 2>/dev/null || true
    printf 'ibdev2netdev_end\n'
  fi
}

capture_storage_topology() {
  local gds_scratch_dir="${AICR_GDS_SCRATCH_DIR:-${AICR_BMARK_DIR}/scratch/gds}"
  local source=""
  local source_host=""
  local route_target=""
  local route_line=""
  local route_dev=""
  local route_src=""
  local route_mlx5=""

  mkdir -p "$gds_scratch_dir" 2>/dev/null || true
  printf 'gds_scratch_dir=%s\n' "$gds_scratch_dir"

  if command -v findmnt >/dev/null 2>&1; then
    findmnt -P -T "$gds_scratch_dir" -o TARGET,SOURCE,FSTYPE,OPTIONS 2>/dev/null | sed 's/^/findmnt /' || true
    source="$(findmnt -n -T "$gds_scratch_dir" -o SOURCE 2>/dev/null || true)"
  fi

  if [[ "$source" == *:* ]]; then
    source_host="${source%%:*}"
    if command -v getent >/dev/null 2>&1; then
      route_target="$(getent ahostsv4 "$source_host" 2>/dev/null | awk 'NR == 1 {print $1}' || true)"
    fi
    if [[ -z "$route_target" ]]; then
      route_target="$source_host"
    fi
  fi

  if [[ -n "$route_target" ]] && command -v ip >/dev/null 2>&1; then
    route_line="$(ip route get "$route_target" 2>/dev/null | head -1 || true)"
    if [[ -n "$route_line" ]]; then
      route_dev="$(awk '{for (i=1; i<NF; i++) if ($i == "dev") {print $(i+1); exit}}' <<<"$route_line")"
      route_src="$(awk '{for (i=1; i<NF; i++) if ($i == "src") {print $(i+1); exit}}' <<<"$route_line")"
    fi
    printf 'storage_route_target=%s\n' "$route_target"
    printf 'storage_route_line=%s\n' "$route_line"
    printf 'storage_route_dev=%s\n' "$route_dev"
    printf 'storage_route_src=%s\n' "$route_src"
  fi

  shopt -s nullglob
  for ib_path in /sys/class/infiniband/mlx5_*; do
    local ib_device
    local numa_node=""
    local local_cpulist=""
    local netdevs=""
    ib_device="$(basename "$ib_path")"
    [[ -f "${ib_path}/device/numa_node" ]] && numa_node="$(<"${ib_path}/device/numa_node")"
    [[ -f "${ib_path}/device/local_cpulist" ]] && local_cpulist="$(<"${ib_path}/device/local_cpulist")"
    if [[ -d "${ib_path}/device/net" ]]; then
      netdevs="$(find "${ib_path}/device/net" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort | paste -sd, -)"
    fi
    if [[ -n "$route_dev" && ",${netdevs}," == *",${route_dev},"* ]]; then
      route_mlx5="$ib_device"
    fi
    printf 'ib_device %s numa_node=%s local_cpulist=%s netdevs=%s\n' "$ib_device" "$numa_node" "$local_cpulist" "$netdevs"
  done
  shopt -u nullglob

  if [[ -n "$route_mlx5" ]]; then
    printf 'storage_route_mlx5=%s\n' "$route_mlx5"
  fi

}

if capture_mlx5_topology >"$mlx5_abs" 2>>"${AICR_BMARK_DIR}/${wrapper_err_rel}"; then
  mlx5_status="Pass"
fi

if [[ "$capture_storage_for_cluster" == "1" ]]; then
  storage_status="Fail"
  if capture_storage_topology >"$storage_abs" 2>>"${AICR_BMARK_DIR}/${wrapper_err_rel}"; then
    storage_status="Pass"
  fi
fi

expected_gpu_count="$(aicr_expected_gpu_count_for_cluster "$cluster")"
expected_gpu_model_contains="$(expected_gpu_model_contains_for_cluster "$cluster")"

summary_json_rel="${parsed_rel}/summary.json"
status_json_rel="${parsed_rel}/status.json"
summary_payload="$(
  aicr_python - \
    "$summary_abs" \
    "$inventory_abs" \
    "$node_short" \
    "$cluster" \
    "$date_utc" \
    "$run_id" \
    "$inventory_rel" \
    "$topo_rel" \
    "$topo_abs" \
    "$lscpu_rel" \
    "$lscpu_abs" \
    "$mlx5_rel" \
    "$mlx5_abs" \
    "$storage_rel" \
    "$storage_abs" \
    "$nvidia_l_status" \
    "$nvidia_topo_status" \
    "$lscpu_status" \
    "$mlx5_status" \
    "$storage_status" \
    "$expected_gpu_count" \
    "$expected_gpu_model_contains" \
    "${AICR_BMARK_DIR}/scripts/parse/topology_intelligence.py" <<'PY'
import importlib.util
import json
import re
import sys
from pathlib import Path

(
    summary_path,
    inventory_path,
    host,
    cluster,
    date_utc,
    run_id,
    inventory_rel,
    topo_rel,
    topo_path,
    lscpu_rel,
    lscpu_path,
    mlx5_rel,
    mlx5_path,
    storage_rel,
    storage_path,
    nvidia_l_status,
    nvidia_topo_status,
    lscpu_status,
    mlx5_status,
    storage_status,
    expected_gpu_count,
    expected_gpu_model_contains,
    topology_intelligence_module_path,
) = sys.argv[1:]

spec = importlib.util.spec_from_file_location("topology_intelligence", topology_intelligence_module_path)
topology_intelligence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(topology_intelligence)

expected_gpu_count = int(expected_gpu_count)
inventory = Path(inventory_path)
gpu_lines = []
gpu_models = []
model_re = re.compile(r"^GPU\s+\d+:\s+(.+?)\s+\(")

if inventory.exists():
    for line in inventory.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line.startswith("GPU "):
            continue
        gpu_lines.append(line)
        match = model_re.search(line)
        if match:
            gpu_models.append(match.group(1).strip())

unique_models = sorted(set(gpu_models))
gpu_count = len(gpu_lines)
gpu_model_summary = unique_models[0] if len(unique_models) == 1 else ", ".join(unique_models)
model_status = "Pass"
if expected_gpu_model_contains:
    if not gpu_models or any(expected_gpu_model_contains not in model for model in gpu_models):
        model_status = "Fail"

count_status = "Pass" if expected_gpu_count == gpu_count else "Fail"

notes = []
if nvidia_l_status != "Pass":
    notes.append("nvidia-smi -L failed")
if count_status != "Pass":
    notes.append(f"expected {expected_gpu_count} GPUs, found {gpu_count}")
if model_status != "Pass":
    notes.append(f"expected GPU model containing {expected_gpu_model_contains!r}")
if nvidia_topo_status != "Pass":
    notes.append("nvidia-smi topo -m failed")
if lscpu_status != "Pass":
    notes.append("lscpu failed")
if mlx5_status != "Pass":
    notes.append("mlx5 topology sampling failed")
if storage_status not in {"Pass", "Skipped"}:
    notes.append("GDS storage topology sampling failed")

topology_fields = topology_intelligence.topology_intelligence_from_files(
    topo_path,
    lscpu_path,
    cluster,
    storage_path=storage_path,
    mlx5_path=mlx5_path,
)

if nvidia_l_status != "Pass" or count_status != "Pass" or model_status != "Pass":
    status = "failed"
elif nvidia_topo_status != "Pass" or lscpu_status != "Pass" or mlx5_status != "Pass" or storage_status not in {"Pass", "Skipped"}:
    status = "degraded"
else:
    status = "passed"

payload = {
    "status": status,
    "host": host,
    "cluster": cluster,
    "date": date_utc,
    "run_id": run_id,
    "gpu_count": gpu_count,
    "expected_gpu_count": expected_gpu_count,
    "gpu_count_status": count_status,
    "gpu_models": unique_models,
    "gpu_model_summary": gpu_model_summary,
    "expected_gpu_model_contains": expected_gpu_model_contains,
    "gpu_model_status": model_status,
    "nvidia_smi_l_status": nvidia_l_status,
    "nvidia_smi_topo_status": nvidia_topo_status,
    "lscpu_status": lscpu_status,
    "mlx5_topology_status": mlx5_status,
    "storage_topology_status": storage_status,
    "nvidia_smi_l_file": inventory_rel,
    "nvidia_smi_topo_file": topo_rel,
    "lscpu_file": lscpu_rel,
    "mlx5_topology_file": mlx5_rel,
    "storage_topology_file": storage_rel,
    "notes": "; ".join(notes),
}
payload.update(topology_fields)

summary_lines = [
    ("host", host),
    ("cluster", cluster),
    ("date", date_utc),
    ("run_id", run_id),
    ("gpu_count", gpu_count),
    ("expected_gpu_count", expected_gpu_count),
    ("gpu_count_status", count_status),
    ("gpu_model_summary", gpu_model_summary),
    ("gpu_models_json", json.dumps(unique_models)),
    ("expected_gpu_model_contains", expected_gpu_model_contains),
    ("gpu_model_status", model_status),
    ("nvidia_smi_l_status", nvidia_l_status),
    ("nvidia_smi_topo_status", nvidia_topo_status),
    ("lscpu_status", lscpu_status),
    ("mlx5_topology_status", mlx5_status),
    ("storage_topology_status", storage_status),
    ("topology_profile_status", topology_fields.get("topology_profile_status", "")),
    ("topology_profile_notes", topology_fields.get("topology_profile_notes", "")),
    ("topology_signature", topology_fields.get("topology_signature", "")),
    ("gpu_cpu_affinity_json", json.dumps(topology_fields.get("gpu_cpu_affinity", {}), sort_keys=True)),
    ("gpu_numa_affinity_json", json.dumps(topology_fields.get("gpu_numa_affinity", {}), sort_keys=True)),
    ("nic_legend_json", json.dumps(topology_fields.get("nic_legend", {}), sort_keys=True)),
    ("nic_cpu_affinity_json", json.dumps(topology_fields.get("nic_cpu_affinity", {}), sort_keys=True)),
    ("nic_numa_affinity_json", json.dumps(topology_fields.get("nic_numa_affinity", {}), sort_keys=True)),
    ("ib_device_cpu_affinity_json", json.dumps(topology_fields.get("ib_device_cpu_affinity", {}), sort_keys=True)),
    ("ib_device_numa_affinity_json", json.dumps(topology_fields.get("ib_device_numa_affinity", {}), sort_keys=True)),
    ("gpu_pix_nics_json", json.dumps(topology_fields.get("gpu_pix_nics", {}), sort_keys=True)),
    ("gpu_nearest_nics_json", json.dumps(topology_fields.get("gpu_nearest_nics", {}), sort_keys=True)),
    ("gds_storage_source", topology_fields.get("gds_storage_source", "")),
    ("gds_storage_fstype", topology_fields.get("gds_storage_fstype", "")),
    ("gds_storage_route_dev", topology_fields.get("gds_storage_route_dev", "")),
    ("gds_storage_route_mlx5", topology_fields.get("gds_storage_route_mlx5", "")),
    ("lscpu_numa_node_count", topology_fields.get("lscpu_numa_node_count")),
    ("lscpu_numa_cpu_affinity_json", json.dumps(topology_fields.get("lscpu_numa_cpu_affinity", {}), sort_keys=True)),
    ("nvidia_smi_l_file", inventory_rel),
    ("nvidia_smi_topo_file", topo_rel),
    ("lscpu_file", lscpu_rel),
    ("mlx5_topology_file", mlx5_rel),
    ("storage_topology_file", storage_rel),
    ("overall_status", status),
    ("notes", payload["notes"]),
]
Path(summary_path).write_text(
    "".join(f"{key}={value}\n" for key, value in summary_lines),
    encoding="utf-8",
)

print(json.dumps(payload, indent=2))
PY
)"
status="$(printf '%s\n' "$summary_payload" | aicr_python -c 'import json,sys; print(json.load(sys.stdin)["status"])')"
gpu_count="$(printf '%s\n' "$summary_payload" | aicr_python -c 'import json,sys; print(json.load(sys.stdin)["gpu_count"])')"
notes="$(printf '%s\n' "$summary_payload" | aicr_python -c 'import json,sys; print(json.load(sys.stdin).get("notes", ""))')"

aicr_write_summary_status_pair "${AICR_BMARK_DIR}/${summary_json_rel}" "${AICR_BMARK_DIR}/${status_json_rel}" "$summary_payload" "$status" "parsed.summary.status"
record_rel="$(aicr_node_record_path "$date_utc" "$cluster" "$node_short" "$AICR_CHECK_GPU_TOPOLOGY" "$run_id")"
record_abs="${AICR_BMARK_DIR}/${record_rel}"
aicr_emit_record_from_args "$record_abs" "$AICR_SCOPE_NODE" "$cluster" "$node_short" "" "$AICR_CHECK_GPU_TOPOLOGY" "$AICR_MODE_PER_NODE" "$run_id" "$date_utc" "$submitted_at" "$(aicr_timestamp_utc)" "$partition" "$job_id" "$status" "parsed.summary.status" 1 "$gpu_count" "$(aicr_join_csv "$summary_rel" "$inventory_rel" "$topo_rel" "$lscpu_rel" "$mlx5_rel" "$storage_rel")" "$(aicr_join_csv "$summary_json_rel" "$status_json_rel")" "$(aicr_join_csv "$wrapper_out_rel" "$wrapper_err_rel")" "$notes"
aicr_append_index_row_from_record "${AICR_BMARK_DIR}/$(aicr_by_date_index_path "$date_utc")" "$record_abs"
aicr_append_index_row_from_record "${AICR_BMARK_DIR}/$(aicr_by_node_history_path "$cluster" "$node_short")" "$record_abs"
