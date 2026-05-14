#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/verify/run-gds.sh [--profile <small|medium|large>] [--inspect-profile]
  scripts/verify/run-gds.sh --custom-gdsio-args '<gdsio args>'

Profiles select GDS readiness intensity. Every profile records gdscheck -p plus
the profile's gdsio phases. Default: small.

Options:
  --profile-config <path>       Override the selected profile config JSON
  --custom-gdsio-args <args>    Run one custom gdsio phase only. Do not include the gdsio binary.
  --allow-custom-target-file    Expert mode: permit -f in --custom-gdsio-args
  --inspect-profile             Validate and print the profile config without running GDS
EOF
}

load_gds_profile_config() {
  local config_path="$1"
  local selected_profile="$2"
  local mode="$3"
  aicr_python - "$config_path" "$selected_profile" "$mode" <<'PY'
import json
import re
import sys
from pathlib import Path

config_path, selected_profile, mode = sys.argv[1:4]
required_gdsio_fields = [
    "target",
    "xfer_type",
    "io_type",
    "gpu_id",
    "threads",
    "memory_type",
    "size",
    "io_size",
]
known_targets = {"sequential", "random", "async"}
name_re = re.compile(r"^[a-z0-9][a-z0-9-]*$")
env_re = re.compile(r"^[A-Z0-9_]+$")
size_re = re.compile(r"^[0-9]+[KMGT]?$")


def die(message):
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(2)


def require_int(phase, field):
    value = phase.get(field)
    if not isinstance(value, int) or value < 0:
        die(f"phase {phase.get('name')!r} field {field!r} must be a non-negative integer")
    return value


def require_size(phase, field):
    value = phase.get(field)
    if not isinstance(value, str) or not size_re.match(value):
        die(f"phase {phase.get('name')!r} field {field!r} must be a size string like 16G")
    return value


path = Path(config_path)
if not path.exists():
    die(f"GDS profile config not found: {path}")
try:
    obj = json.loads(path.read_text(encoding="utf-8"))
except json.JSONDecodeError as exc:
    die(f"unable to parse GDS profile config {path}: {exc}")

if obj.get("schema_version") != 1:
    die(f"{path} has unsupported schema_version {obj.get('schema_version')!r}")
if obj.get("profile") != selected_profile:
    die(f"{path} profile mismatch: expected {selected_profile}, found {obj.get('profile')!r}")

phases = obj.get("phases")
if not isinstance(phases, list) or not phases:
    die(f"{path} must contain a non-empty phases list")

rows = []
seen = set()
for index, phase in enumerate(phases):
    if not isinstance(phase, dict):
        die(f"phase #{index + 1} must be an object")
    name = phase.get("name")
    phase_type = phase.get("type")
    if not isinstance(name, str) or not name_re.match(name):
        die(f"phase #{index + 1} has invalid name {name!r}")
    if name in seen:
        die(f"duplicate phase name: {name}")
    if phase_type not in {"gdscheck", "gdsio"}:
        die(f"phase {name!r} has unsupported type {phase_type!r}")
    dependency = phase.get("dependency") or ""
    if dependency and dependency not in seen:
        die(f"phase {name!r} dependency {dependency!r} must reference an earlier phase")

    row = {
        "name": name,
        "type": phase_type,
        "dependency": dependency,
        "target": "",
        "xfer_type": "",
        "io_type": "",
        "gpu_id": "",
        "threads": "",
        "memory_type": "",
        "size": "",
        "io_size": "",
        "duration": "",
        "random_seed": "",
        "env_overrides": "",
        "shape": "gdscheck -p",
    }
    if phase_type == "gdsio":
        missing = [field for field in required_gdsio_fields if field not in phase]
        if missing:
            die(f"phase {name!r} missing required fields: {', '.join(missing)}")
        target = phase.get("target")
        if target not in known_targets:
            die(f"phase {name!r} has unsupported target {target!r}")
        duration = phase.get("duration", "")
        random_seed = phase.get("random_seed", "")
        if duration != "" and (not isinstance(duration, int) or duration < 1):
            die(f"phase {name!r} field 'duration' must be a positive integer when set")
        if random_seed != "" and (not isinstance(random_seed, int) or random_seed < 0):
            die(f"phase {name!r} field 'random_seed' must be a non-negative integer when set")
        env_overrides = phase.get("env_overrides", [])
        if not isinstance(env_overrides, list) or any(not isinstance(item, str) or not env_re.match(item) for item in env_overrides):
            die(f"phase {name!r} env_overrides must be a list of environment variable names")

        row.update({
            "target": target,
            "xfer_type": str(require_int(phase, "xfer_type")),
            "io_type": str(require_int(phase, "io_type")),
            "gpu_id": str(require_int(phase, "gpu_id")),
            "threads": str(require_int(phase, "threads")),
            "memory_type": str(require_int(phase, "memory_type")),
            "size": require_size(phase, "size"),
            "io_size": require_size(phase, "io_size"),
            "duration": str(duration),
            "random_seed": str(random_seed),
            "env_overrides": ",".join(env_overrides),
        })
        shape = (
            f"-x {row['xfer_type']} -I {row['io_type']} -d {row['gpu_id']} "
            f"-w {row['threads']} -m {row['memory_type']} -s {row['size']} -i {row['io_size']}"
        )
        if row["duration"]:
            shape = f"{shape} -T {row['duration']}"
        if row["random_seed"]:
            shape = f"{shape} -k {row['random_seed']}"
        row["shape"] = shape
    rows.append(row)
    seen.add(name)

if mode == "inspect":
    print(f"profile={selected_profile}")
    print(f"config={path}")
    display_rows = [
        {
            "phase": row["name"],
            "type": row["type"],
            "dependency": row["dependency"] or "-",
            "target": row["target"] or "-",
            "shape": row["shape"],
            "env_overrides": row["env_overrides"] or "-",
        }
        for row in rows
    ]
    columns = [
        ("phase", "phase"),
        ("type", "type"),
        ("dependency", "dependency"),
        ("target", "target"),
        ("shape", "shape"),
        ("env_overrides", "env_overrides"),
    ]
    widths = {
        key: max(len(label), *(len(item[key]) for item in display_rows))
        for key, label in columns
    }
    print("  ".join(label.ljust(widths[key]) for key, label in columns))
    for row in display_rows:
        print("  ".join(row[key].ljust(widths[key]) for key, _ in columns))
elif mode == "tsv":
    fields = [
        "name",
        "type",
        "dependency",
        "target",
        "xfer_type",
        "io_type",
        "gpu_id",
        "threads",
        "memory_type",
        "size",
        "io_size",
        "duration",
        "random_seed",
        "env_overrides",
    ]
    for row in rows:
        print("|".join(row[field] for field in fields))
else:
    die(f"unsupported profile config mode: {mode}")
PY
}

profile="${PROFILE:-small}"
gds_profile_config="${AICR_GDS_PROFILE_CONFIG:-}"
custom_gdsio_args="${AICR_GDS_CUSTOM_GDSIO_ARGS:-}"
allow_custom_target_file="${AICR_GDS_ALLOW_CUSTOM_TARGET_FILE:-0}"
inspect_profile=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --profile=*)
      profile="${1#--profile=}"
      shift
      ;;
    --profile-config)
      gds_profile_config="${2:-}"
      shift 2
      ;;
    --profile-config=*)
      gds_profile_config="${1#--profile-config=}"
      shift
      ;;
    --custom-gdsio-args)
      custom_gdsio_args="${2:-}"
      profile="custom"
      shift 2
      ;;
    --custom-gdsio-args=*)
      custom_gdsio_args="${1#--custom-gdsio-args=}"
      profile="custom"
      shift
      ;;
    --allow-custom-target-file)
      allow_custom_target_file=1
      shift
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
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

case "$profile" in
  small|medium|large|custom) ;;
  *)
    echo "ERROR: unsupported GDS profile: ${profile}" >&2
    echo "Supported profiles: small, medium, large, custom" >&2
    exit 2
    ;;
esac
if [[ "$profile" == "custom" && -z "$custom_gdsio_args" && -z "$gds_profile_config" ]]; then
  echo "ERROR: custom profile requires --custom-gdsio-args, AICR_GDS_CUSTOM_GDSIO_ARGS, --profile-config, or AICR_GDS_PROFILE_CONFIG" >&2
  exit 2
fi

aicr_require_repo_root
gds_profile_config="${gds_profile_config:-${AICR_BMARK_DIR}/configs/gds/profiles/${profile}.json}"
if [[ "$inspect_profile" == "1" ]]; then
  if [[ "$profile" == "custom" && -n "$custom_gdsio_args" ]]; then
    echo "profile=custom"
    echo "config=custom-gdsio-args"
    printf '%-12s  %-8s  %-10s  %-10s  %-40s  %s\n' "phase" "type" "dependency" "target" "shape" "env_overrides"
    printf '%-12s  %-8s  %-10s  %-10s  %-40s  %s\n' "custom" "gdsio" "-" "sequential" "${custom_gdsio_args}" "-"
    exit 0
  fi
  load_gds_profile_config "$gds_profile_config" "$profile" inspect
  exit 0
fi
aicr_mkdirs

cluster="${AICR_CLUSTER_NAME:-$(aicr_cluster_name)}"
aicr_assert_supported_cluster "$cluster"

date_utc="$(aicr_today_date)"
node_short="$(hostname -s 2>/dev/null || hostname)"
run_id="${GDS_RUN_ID:-$(aicr_next_by_date_run_id "$date_utc" "$cluster" "$AICR_SCOPE_NODE" "$AICR_CHECK_GDS" "$node_short")}"

raw_rel="$(aicr_node_raw_run_dir "$date_utc" "$cluster" "$node_short" "$AICR_CHECK_GDS" "$run_id")"
parsed_rel="$(aicr_node_parsed_run_dir "$date_utc" "$cluster" "$node_short" "$AICR_CHECK_GDS" "$run_id")"

raw_abs="${AICR_BMARK_DIR}/${raw_rel}"
parsed_abs="${AICR_BMARK_DIR}/${parsed_rel}"
canonical_abs="${raw_abs}/canonical"
wrapper_abs="${raw_abs}/wrapper"
metadata_abs="${raw_abs}/metadata"

mkdir -p "$canonical_abs" "$wrapper_abs" "$metadata_abs" "$parsed_abs"

inventory_rel="${raw_rel}/canonical/nvidia-smi-L.txt"
topology_rel="${raw_rel}/canonical/nvidia-smi-topo-m.txt"
summary_txt_rel="${raw_rel}/canonical/gds-summary.txt"
record_rel="${raw_rel}/metadata/record.json"
summary_json_rel="${parsed_rel}/summary.json"
status_rel="${parsed_rel}/status.json"
cufile_log_rel="${raw_rel}/wrapper/cufile.log"

inventory_abs="${AICR_BMARK_DIR}/${inventory_rel}"
topology_abs="${AICR_BMARK_DIR}/${topology_rel}"
summary_txt_abs="${AICR_BMARK_DIR}/${summary_txt_rel}"
record_abs="${AICR_BMARK_DIR}/${record_rel}"
summary_json_abs="${AICR_BMARK_DIR}/${summary_json_rel}"
status_abs="${AICR_BMARK_DIR}/${status_rel}"
cufile_log_abs="${AICR_BMARK_DIR}/${cufile_log_rel}"
phase_status_abs="${wrapper_abs}/gds-phases.tsv"

gds_tool_dir="${AICR_GDS_TOOL_DIR:-/usr/local/cuda/gds/tools}"
gdscheck_bin="${AICR_GDSCHECK_BIN:-${gds_tool_dir}/gdscheck}"
gdsio_bin="${AICR_GDSIO_BIN:-${gds_tool_dir}/gdsio}"
gds_run_scratch_dir="${AICR_GDS_SCRATCH_DIR}/${cluster}/${node_short}/${run_id}"
cleanup_gds_targets="${AICR_GDS_CLEANUP_TARGETS:-1}"
cleanup_sequential_target=0
cleanup_random_target=1
cleanup_async_target=1
legacy_shared_read_target="${AICR_GDS_SCRATCH_DIR}/gds-throughput.dat"
legacy_shared_write_target="${AICR_GDS_SCRATCH_DIR}/gds-write-throughput.dat"

if [[ -n "${AICR_GDS_THROUGHPUT_FILE:-}" && "${AICR_GDS_THROUGHPUT_FILE}" != "${legacy_shared_read_target}" ]]; then
  gds_sequential_target_file="${AICR_GDS_THROUGHPUT_FILE}"
elif [[ -n "${AICR_GDS_WRITE_THROUGHPUT_FILE:-}" && "${AICR_GDS_WRITE_THROUGHPUT_FILE}" != "${legacy_shared_write_target}" ]]; then
  gds_sequential_target_file="${AICR_GDS_WRITE_THROUGHPUT_FILE}"
else
  gds_sequential_target_file="${gds_run_scratch_dir}/gds-sequential-target.dat"
  cleanup_sequential_target=1
fi

gds_random_target_file="${gds_run_scratch_dir}/gds-random-target.dat"
gds_async_target_file="${gds_run_scratch_dir}/gds-async-target.dat"

mkdir -p \
  "${AICR_GDS_SCRATCH_DIR}" \
  "${gds_run_scratch_dir}" \
  "$(dirname "$gds_sequential_target_file")" \
  "$(dirname "$gds_random_target_file")" \
  "$(dirname "$gds_async_target_file")"

cleanup_targets() {
  [[ "${cleanup_gds_targets}" == "1" ]] || return 0
  if [[ "${cleanup_sequential_target}" == "1" ]]; then
    rm -f -- "$gds_sequential_target_file"
  fi
  if [[ "${cleanup_random_target}" == "1" ]]; then
    rm -f -- "$gds_random_target_file"
  fi
  if [[ "${cleanup_async_target}" == "1" ]]; then
    rm -f -- "$gds_async_target_file"
  fi
  rmdir --ignore-fail-on-non-empty "$gds_run_scratch_dir" 2>/dev/null || true
}
trap cleanup_targets EXIT

submitted_at_utc="$(aicr_timestamp_utc)"
launched_at_utc="$submitted_at_utc"
job_id="${SLURM_JOB_ID:-}"
partition="${SLURM_JOB_PARTITION:-${SLURM_JOB_PARTITION_NAME:-unknown}}"
gpu_count="${SLURM_GPUS_ON_NODE:-$(aicr_gpu_count)}"
node_count="1"
gpu_preflight_status="Not required"
visible_gpu_count="$gpu_count"
expected_visible_gpu_count="$(aicr_expected_gpu_count_for_cluster "$cluster")"
gpu_inventory_rel="$inventory_rel"
gpu_topology_rel="$topology_rel"
notes=()

declare -a phase_order=()
declare -A phase_type=()
declare -A phase_cmd=()
declare -A phase_dependency=()
declare -A phase_rel=()
declare -A phase_abs=()
declare -A phase_status=()
declare -A phase_note=()

add_note() {
  local note="$1"
  local existing
  [[ -n "$note" ]] || return 0
  for existing in "${notes[@]}"; do
    [[ "$existing" == "$note" ]] && return 0
  done
  notes+=("$note")
}

phase_file_rel() {
  local phase="$1"
  if [[ "$phase" == "platform" ]]; then
    printf '%s/canonical/gdscheck-platform.txt\n' "$raw_rel"
  else
    printf '%s/canonical/gdsio-%s.txt\n' "$raw_rel" "$phase"
  fi
}

add_phase() {
  local name="$1"
  local type="$2"
  local cmd="$3"
  local dependency="${4:-}"
  local rel
  rel="$(phase_file_rel "$name")"
  phase_order+=("$name")
  phase_type["$name"]="$type"
  phase_cmd["$name"]="$cmd"
  phase_dependency["$name"]="$dependency"
  phase_rel["$name"]="$rel"
  phase_abs["$name"]="${AICR_BMARK_DIR}/${rel}"
  phase_status["$name"]="Not run"
  phase_note["$name"]=""
}

quote_arg() {
  printf '%q' "$1"
}

gdsio_cmd() {
  local xfer_type="$1"
  local io_type="$2"
  local gpu_id="$3"
  local threads="$4"
  local memory_type="$5"
  local size="$6"
  local io_size="$7"
  local target_file="$8"
  local duration="${9:-}"
  local random_seed="${10:-}"
  local cmd
  cmd="$(quote_arg "$gdsio_bin") -x ${xfer_type} -I ${io_type} -d ${gpu_id} -w ${threads} -m ${memory_type} -s ${size} -i ${io_size} -f $(quote_arg "$target_file")"
  if [[ -n "$duration" ]]; then
    cmd="${cmd} -T ${duration}"
  fi
  if [[ -n "$random_seed" ]]; then
    cmd="${cmd} -k ${random_seed}"
  fi
  printf '%s\n' "$cmd"
}

args_include_target_file() {
  local args=" $1 "
  [[ "$args" =~ [[:space:]]-f([=[:space:]]|$) || "$args" =~ [[:space:]]--file([=[:space:]]|$) ]]
}

custom_gdsio_cmd() {
  local args="$1"
  local target_file="$2"
  local cmd
  if args_include_target_file "$args"; then
    if [[ "$allow_custom_target_file" != "1" ]]; then
      echo "ERROR: --custom-gdsio-args must not include -f/--file unless --allow-custom-target-file is set" >&2
      exit 2
    fi
    cmd="$(quote_arg "$gdsio_bin") ${args}"
  else
    cmd="$(quote_arg "$gdsio_bin") ${args} -f $(quote_arg "$target_file")"
  fi
  printf '%s\n' "$cmd"
}

gds_target_file_for_key() {
  case "$1" in
    sequential) printf '%s\n' "$gds_sequential_target_file" ;;
    random) printf '%s\n' "$gds_random_target_file" ;;
    async) printf '%s\n' "$gds_async_target_file" ;;
    *) echo "ERROR: unsupported GDS target key: $1" >&2; exit 2 ;;
  esac
}

command_with_env_overrides() {
  local default_cmd="$1"
  local env_overrides="$2"
  local override_name
  local override_value
  local -a override_names=()
  local cmd="$default_cmd"
  if [[ -n "$env_overrides" ]]; then
    IFS=',' read -r -a override_names <<<"$env_overrides"
    for override_name in "${override_names[@]}"; do
      [[ -n "$override_name" ]] || continue
      override_value="${!override_name:-}"
      if [[ -n "$override_value" ]]; then
        cmd="$override_value"
        break
      fi
    done
  fi
  printf '%s\n' "$cmd"
}

if [[ "$profile" == "custom" && -n "$custom_gdsio_args" ]]; then
  add_phase "custom" "gdsio" "$(custom_gdsio_cmd "$custom_gdsio_args" "$gds_sequential_target_file")" ""
else
  while IFS='|' read -r phase_name phase_kind dependency target_key xfer_type io_type gpu_id threads memory_type size io_size duration random_seed env_overrides; do
    [[ -n "$phase_name" ]] || continue
    case "$phase_kind" in
      gdscheck)
        add_phase "$phase_name" "$phase_kind" "$(quote_arg "$gdscheck_bin") -p" "$dependency"
        ;;
      gdsio)
        target_file="$(gds_target_file_for_key "$target_key")"
        default_cmd="$(gdsio_cmd "$xfer_type" "$io_type" "$gpu_id" "$threads" "$memory_type" "$size" "$io_size" "$target_file" "$duration" "$random_seed")"
        add_phase "$phase_name" "$phase_kind" "$(command_with_env_overrides "$default_cmd" "$env_overrides")" "$dependency"
        ;;
      *)
        echo "ERROR: unsupported GDS phase type from config: ${phase_kind}" >&2
        exit 2
        ;;
    esac
  done < <(load_gds_profile_config "$gds_profile_config" "$profile" tsv)
fi

run_capture() {
  local cmd="$1"
  local outfile="$2"
  set +e
  (cd "$wrapper_abs" && bash -lc "$cmd") >"$outfile" 2>&1
  local rc=$?
  set -e
  return $rc
}

record_phase_placeholder() {
  local phase="$1"
  local status="$2"
  local note="$3"
  printf '%s\n' "$note" >"${phase_abs[$phase]}"
  phase_status["$phase"]="$status"
  phase_note["$phase"]="$note"
}

capture_gpu_preflight_artifacts() {
  if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi -L >"$inventory_abs" 2>&1 || true
    nvidia-smi topo -m >"$topology_abs" 2>&1 || true
  else
    printf '%s\n' "nvidia-smi not found on host" >"$inventory_abs"
    printf '%s\n' "nvidia-smi not found on host" >"$topology_abs"
  fi
}

capture_gpu_preflight_artifacts

if aicr_cluster_requires_gpu_presence_preflight "$cluster"; then
  if aicr_run_gpu_presence_preflight "$cluster" "$inventory_abs"; then
    gpu_preflight_status="$AICR_GPU_PREFLIGHT_STATUS"
  else
    gpu_preflight_status="$AICR_GPU_PREFLIGHT_STATUS"
    add_note "$AICR_GPU_PREFLIGHT_NOTE"
  fi
  visible_gpu_count="$AICR_GPU_PREFLIGHT_FOUND"
  expected_visible_gpu_count="$AICR_GPU_PREFLIGHT_EXPECTED"
  gpu_count="$visible_gpu_count"
fi

if [[ "$gpu_preflight_status" == "Fail" ]]; then
  for phase in "${phase_order[@]}"; do
    record_phase_placeholder "$phase" "Not run" "${phase} not run because GPU presence preflight failed"
  done
else
  for phase in "${phase_order[@]}"; do
    case "${phase_type[$phase]}" in
      gdscheck)
        if [[ ! -x "$gdscheck_bin" ]]; then
          record_phase_placeholder "$phase" "Degraded" "gdscheck not found: ${gdscheck_bin}"
          add_note "gdscheck not found"
        elif run_capture "${phase_cmd[$phase]}" "${phase_abs[$phase]}"; then
          phase_status["$phase"]="Pass"
        else
          phase_status["$phase"]="Fail"
          phase_note["$phase"]="gdscheck -p failed"
          add_note "gdscheck -p failed"
        fi
        ;;
      gdsio)
        if [[ ! -x "$gdsio_bin" ]]; then
          record_phase_placeholder "$phase" "Degraded" "gdsio not found: ${gdsio_bin}"
          add_note "gdsio not found"
          continue
        fi
        dependency="${phase_dependency[$phase]}"
        if [[ -n "$dependency" && "${phase_status[$dependency]}" != "Pass" ]]; then
          record_phase_placeholder "$phase" "Not run" "${phase} not run because ${dependency} did not pass"
          continue
        fi
        if run_capture "${phase_cmd[$phase]}" "${phase_abs[$phase]}"; then
          phase_status["$phase"]="Pass"
        else
          phase_status["$phase"]="Fail"
          phase_note["$phase"]="gdsio ${phase} command failed"
          add_note "gdsio ${phase} command failed"
        fi
        ;;
      *)
        record_phase_placeholder "$phase" "Fail" "internal error: unsupported phase type ${phase_type[$phase]}"
        add_note "internal error: unsupported phase type"
        ;;
    esac
  done
fi

overall_status="passed"
if [[ "$gpu_preflight_status" == "Fail" ]]; then
  overall_status="failed"
else
  for phase in "${phase_order[@]}"; do
    case "${phase_status[$phase]}" in
      Fail)
        overall_status="failed"
        break
        ;;
      Degraded|"Not run")
        if [[ "$overall_status" != "failed" ]]; then
          overall_status="degraded"
        fi
        ;;
    esac
  done
fi

notes_str=""
if (( ${#notes[@]} > 0 )); then
  printf -v notes_str '%s; ' "${notes[@]}"
  notes_str="${notes_str%; }"
fi

: >"$phase_status_abs"
for phase in "${phase_order[@]}"; do
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$phase" \
    "${phase_type[$phase]}" \
    "${phase_status[$phase]}" \
    "${phase_rel[$phase]}" \
    "${phase_dependency[$phase]}" \
    "${phase_note[$phase]}" \
    "${phase_cmd[$phase]}" >>"$phase_status_abs"
done

baseline_rel="$(aicr_setup_baseline_path "$cluster")"
baseline_abs="${AICR_BMARK_DIR}/${baseline_rel}"
baseline_id=""
if [[ -f "$baseline_abs" ]]; then
  baseline_id="$(aicr_python - "$baseline_abs" <<'PY'
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    obj = json.load(fh)
print(obj.get('baseline_id') or "")
PY
)"
fi

completed_at_utc="$(aicr_timestamp_utc)"
cufile_log_exists=0
if [[ -f "$cufile_log_abs" ]]; then
  cufile_log_exists=1
fi

export overall_status profile gds_profile_config node_short cluster date_utc run_id gds_tool_dir gdscheck_bin gdsio_bin
export gds_run_scratch_dir gds_sequential_target_file gds_random_target_file gds_async_target_file
export cleanup_gds_targets cleanup_sequential_target cleanup_random_target cleanup_async_target
export notes_str submitted_at_utc launched_at_utc completed_at_utc
export partition job_id node_count gpu_count raw_rel parsed_rel summary_txt_rel inventory_rel gpu_inventory_rel gpu_topology_rel
export summary_json_rel status_rel cufile_log_rel cufile_log_abs cufile_log_exists baseline_rel baseline_id AICR_GDS_SCRATCH_DIR
export gpu_preflight_status visible_gpu_count expected_visible_gpu_count

aicr_python - \
  "$phase_status_abs" \
  "$summary_txt_abs" \
  "$summary_json_abs" \
  "$status_abs" \
  "$record_abs" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

phase_status_abs, summary_txt_abs, summary_json_abs, status_abs, record_abs = sys.argv[1:]
bmark_dir = Path(os.environ["AICR_BMARK_DIR"])

METRIC_PATTERNS = {
    "io_type": r"IoType:\s+(\S+)",
    "xfer_type": r"XferType:\s+(\S+)",
    "threads": r"Threads:\s+([0-9]+)",
    "dataset_kib": r"DataSetSize:\s+([0-9]+)",
    "dataset_target_kib": r"DataSetSize:\s+[0-9]+/([0-9]+)\(KiB\)",
    "io_size_kib": r"IOSize:\s+([0-9]+)\(KiB\)",
    "throughput_gib_s": r"Throughput:\s+([0-9.]+)\s+GiB/sec",
    "avg_latency_usecs": r"Avg_Latency:\s+([0-9.]+)\s+usecs",
    "ops": r"ops:\s+([0-9]+)",
    "total_time_s": r"total_time\s+([0-9.]+)\s+secs",
}
INT_FIELDS = {"threads", "dataset_kib", "dataset_target_kib", "io_size_kib", "ops"}
FLOAT_FIELDS = {"throughput_gib_s", "avg_latency_usecs", "total_time_s"}


def optional_int(value):
    if value in (None, ""):
        return None
    try:
        return int(value)
    except ValueError:
        return None


def parse_metric_value(field, text):
    match = re.search(METRIC_PATTERNS[field], text)
    if not match:
        return None
    value = match.group(1)
    if field in INT_FIELDS:
        return optional_int(value)
    if field in FLOAT_FIELDS:
        try:
            return float(value)
        except ValueError:
            return None
    return value


def parse_gdsio_metrics(relpath):
    path = bmark_dir / relpath
    text = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    return {field: parse_metric_value(field, text) for field in METRIC_PATTERNS}


def combined_status(statuses):
    normalized = [status for status in statuses if status and status != "-"]
    if not normalized:
        return "Not run"
    if "Fail" in normalized:
        return "Fail"
    if any(status in {"Degraded", "Not run"} for status in normalized):
        return "Degraded"
    return "Pass"


def phase_to_prefix(summary, prefix, phase_name):
    phase = summary["phases"].get(phase_name) or {}
    summary[f"{prefix}_status"] = phase.get("status") or "Not run"
    summary[f"{prefix}_cmd"] = phase.get("command") or ""
    for field in METRIC_PATTERNS:
        summary[f"{prefix}_{field}"] = phase.get(field)


def phase_statuses(phases, names):
    return [(phases.get(name) or {}).get("status") or "Not run" for name in names]


phases = {}
phase_order = []
canonical_paths = [os.environ["summary_txt_rel"], os.environ["gpu_inventory_rel"], os.environ["gpu_topology_rel"]]
with open(phase_status_abs, "r", encoding="utf-8") as fh:
    for line in fh:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t", 6)
        while len(parts) < 7:
            parts.append("")
        name, phase_type, status, relpath, dependency, note, command = parts
        phase_order.append(name)
        item = {
            "status": status,
            "phase_type": phase_type,
            "artifact_path": relpath,
            "dependency": dependency or None,
            "note": note or "",
            "command": command or "",
        }
        if phase_type == "gdsio":
            item.update(parse_gdsio_metrics(relpath))
        phases[name] = item
        if relpath:
            canonical_paths.append(relpath)

primary_read_phase = "sequential-read" if "sequential-read" in phases else "custom"
primary_write_phase = "sequential-write" if "sequential-write" in phases else "custom"

legacy_profiles = {
    "platform": phases.get("platform", {"status": "Not run"}),
    "throughput-read": phases.get(primary_read_phase, {"status": "Not run"}),
    "throughput-write": phases.get(primary_write_phase, {"status": "Not run"}),
}

summary = {
    "status": os.environ["overall_status"],
    "host": os.environ["node_short"],
    "cluster": os.environ["cluster"],
    "date": os.environ["date_utc"],
    "run_id": os.environ["run_id"],
    "profile": os.environ["profile"],
    "gds_profile_config": os.environ["gds_profile_config"],
    "gds_tool_dir": os.environ["gds_tool_dir"],
    "gdscheck_bin": os.environ["gdscheck_bin"],
    "gdsio_bin": os.environ["gdsio_bin"],
    "gds_scratch_dir": os.environ["AICR_GDS_SCRATCH_DIR"],
    "gds_run_scratch_dir": os.environ["gds_run_scratch_dir"],
    "gds_target_file": os.environ["gds_sequential_target_file"],
    "gds_read_target_file": os.environ["gds_sequential_target_file"],
    "gds_write_target_file": os.environ["gds_sequential_target_file"],
    "gds_sequential_target_file": os.environ["gds_sequential_target_file"],
    "gds_random_target_file": os.environ["gds_random_target_file"],
    "gds_async_target_file": os.environ["gds_async_target_file"],
    "cufile_log_file": os.environ["cufile_log_abs"],
    "cufile_log_exists": os.environ["cufile_log_exists"] == "1",
    "cleanup_gds_targets": os.environ["cleanup_gds_targets"] == "1",
    "cleanup_read_target": os.environ["cleanup_sequential_target"] == "1",
    "cleanup_write_target": os.environ["cleanup_sequential_target"] == "1",
    "cleanup_sequential_target": os.environ["cleanup_sequential_target"] == "1",
    "cleanup_random_target": os.environ["cleanup_random_target"] == "1",
    "cleanup_async_target": os.environ["cleanup_async_target"] == "1",
    "gpu_preflight_status": os.environ["gpu_preflight_status"],
    "visible_gpu_count": optional_int(os.environ["visible_gpu_count"]),
    "expected_visible_gpu_count": optional_int(os.environ["expected_visible_gpu_count"]),
    "gpu_inventory_file": os.environ["gpu_inventory_rel"] or None,
    "gpu_topology_file": os.environ["gpu_topology_rel"] or None,
    "phase_order": phase_order,
    "primary_read_phase": primary_read_phase,
    "primary_write_phase": primary_write_phase,
    "platform_status": (phases.get("platform") or {}).get("status") or "Not run",
    "throughput_status": combined_status(phase_statuses(phases, [primary_write_phase, primary_read_phase])),
    "phases": phases,
    "profiles": legacy_profiles,
    "notes": os.environ["notes_str"],
}

phase_to_prefix(summary, "throughput_read", primary_read_phase)
phase_to_prefix(summary, "throughput_write", primary_write_phase)
phase_to_prefix(summary, "read", primary_read_phase)
phase_to_prefix(summary, "write", primary_write_phase)

status = {
    "status": os.environ["overall_status"],
    "pass_basis": "parsed.summary.status",
}

job_id = os.environ["job_id"]
raw_rel = os.environ["raw_rel"]
record = {
    "schema_version": 1,
    "scope": "node",
    "cluster": os.environ["cluster"],
    "node": os.environ["node_short"],
    "peer_nodes": [],
    "check": "gds",
    "subcheck": None,
    "mode": "per-node",
    "run_id": os.environ["run_id"],
    "date": os.environ["date_utc"],
    "submitted_at_utc": os.environ["submitted_at_utc"],
    "launched_at_utc": os.environ["launched_at_utc"],
    "completed_at_utc": os.environ["completed_at_utc"],
    "partition": os.environ["partition"],
    "job_id": job_id,
    "status": os.environ["overall_status"],
    "pass_basis": "parsed.summary.status",
    "notes": os.environ["notes_str"],
    "node_count": int(os.environ["node_count"]),
    "gpu_count": int(os.environ["gpu_count"] or 0),
    "profile": os.environ["profile"],
    "wrapper_log_paths": [
        f"{raw_rel}/wrapper/slurm-{job_id}.out" if job_id else f"{raw_rel}/wrapper/slurm-<jobid>.out",
        f"{raw_rel}/wrapper/slurm-{job_id}.err" if job_id else f"{raw_rel}/wrapper/slurm-<jobid>.err",
    ],
    "canonical_artifact_paths": [path for path in canonical_paths if path],
    "parsed_artifact_paths": [
        os.environ["summary_json_rel"],
        os.environ["status_rel"],
    ],
    "setup_baseline_ref": {
        "cluster": os.environ["cluster"],
        "baseline_path": os.environ["baseline_rel"],
        "baseline_id": os.environ["baseline_id"] or None,
    },
}

if os.environ["cufile_log_exists"] == "1":
    record["wrapper_log_paths"].append(os.environ["cufile_log_rel"])

summary_lines = [
    f"host={summary['host']}",
    f"cluster={summary['cluster']}",
    f"date={summary['date']}",
    f"run_id={summary['run_id']}",
    f"profile={summary['profile']}",
    f"gds_profile_config={summary['gds_profile_config']}",
    f"gds_tool_dir={summary['gds_tool_dir']}",
    f"gdscheck_bin={summary['gdscheck_bin']}",
    f"gdsio_bin={summary['gdsio_bin']}",
    f"gds_scratch_dir={summary['gds_scratch_dir']}",
    f"gds_run_scratch_dir={summary['gds_run_scratch_dir']}",
    f"gds_sequential_target_file={summary['gds_sequential_target_file']}",
    f"gds_random_target_file={summary['gds_random_target_file']}",
    f"gds_async_target_file={summary['gds_async_target_file']}",
    f"cufile_log_file={summary['cufile_log_file']}",
    f"cleanup_gds_targets={summary['cleanup_gds_targets']}",
    f"gpu_preflight_status={summary['gpu_preflight_status']}",
    f"visible_gpu_count={summary['visible_gpu_count']}",
    f"expected_visible_gpu_count={summary['expected_visible_gpu_count']}",
    f"gpu_inventory_file={summary['gpu_inventory_file'] or ''}",
    f"gpu_topology_file={summary['gpu_topology_file'] or ''}",
    f"primary_read_phase={primary_read_phase}",
    f"primary_write_phase={primary_write_phase}",
    f"platform_status={summary['platform_status']}",
    f"throughput_status={summary['throughput_status']}",
    f"overall_status={summary['status']}",
]
for phase in phase_order:
    safe = phase.replace("-", "_")
    item = phases[phase]
    summary_lines.append(f"{safe}_status={item.get('status')}")
    summary_lines.append(f"{safe}_cmd={item.get('command') or ''}")
    for field in ("throughput_gib_s", "avg_latency_usecs", "ops", "total_time_s"):
        if field in item:
            summary_lines.append(f"{safe}_{field}={item.get(field) if item.get(field) is not None else ''}")
for prefix in ("throughput_read", "throughput_write", "read", "write"):
    summary_lines.append(f"{prefix}_status={summary.get(prefix + '_status')}")
    summary_lines.append(f"{prefix}_throughput_gib_s={summary.get(prefix + '_throughput_gib_s') if summary.get(prefix + '_throughput_gib_s') is not None else ''}")
    summary_lines.append(f"{prefix}_avg_latency_usecs={summary.get(prefix + '_avg_latency_usecs') if summary.get(prefix + '_avg_latency_usecs') is not None else ''}")
    summary_lines.append(f"{prefix}_ops={summary.get(prefix + '_ops') if summary.get(prefix + '_ops') is not None else ''}")
summary_lines.append(f"notes={summary['notes']}")

Path(summary_txt_abs).write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
for path, obj in ((summary_json_abs, summary), (status_abs, status), (record_abs, record)):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, indent=2)
        fh.write("\n")
PY

by_date_index_rel="$(aicr_by_date_index_path "$date_utc")"
by_node_history_rel="$(aicr_by_node_history_path "$cluster" "$node_short")"
aicr_append_index_row_from_record "${AICR_BMARK_DIR}/${by_date_index_rel}" "$record_abs"
aicr_append_index_row_from_record "${AICR_BMARK_DIR}/${by_node_history_rel}" "$record_abs"

echo "Wrote ${record_rel}"
echo "Wrote ${summary_json_rel}"
echo "Wrote ${status_rel}"
echo "Indexed ${by_date_index_rel}"
echo "Indexed ${by_node_history_rel}"
