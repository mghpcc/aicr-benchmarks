#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/verify/submit-gds-fleet.sh --cluster <b200|rtxpro6000> [--profile <small|medium|large>] [--nodes <node[,node...]>] [--partition <name>] [--repeat-count <n>] [--repeat-aggregation <standard|olympic>] [--submit-stagger-seconds <n|benchmark>] [--round-stagger-seconds <n>] [--apply] [--no-wait] [--no-render]
  scripts/verify/submit-gds-fleet.sh --cluster <b200|rtxpro6000> --custom-gdsio-args '<gdsio args>' [--nodes <node[,node...]>] [--apply]

Default behavior is a dry run: discover exactly-idle nodes and print sbatch commands without submitting.
Default submit stagger is 60 seconds; use 0 only for intentional concurrent filesystem stress.
Use --submit-stagger-seconds benchmark for a Slurm afterany dependency chain that starts one job at a time.
Default profile is small. Default repeat count is 1. Default repeat aggregation is standard.
EOF
}

default_partition_for_cluster() {
  case "$1" in
    b200) printf 'GPU2\n' ;;
    rtxpro6000) printf 'GPU1\n' ;;
    *) aicr_die "Unsupported cluster: $1" ;;
  esac
}

time_limit_for_profile() {
  case "$1" in
    small) printf '00:25:00\n' ;;
    medium) printf '01:00:00\n' ;;
    large) printf '02:30:00\n' ;;
    custom) printf '00:25:00\n' ;;
    *) aicr_die "Unsupported GDS profile: $1" ;;
  esac
}

expand_nodes() {
  local expr="$1"
  scontrol show hostnames "$expr"
}

json_array_from_file() {
  local path="$1"
  aicr_python - "$path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
items = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()] if path.exists() else []
print(json.dumps(items))
PY
}

json_jobs_from_file() {
  local path="$1"
  aicr_python - "$path" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
jobs = []
if path.exists():
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("|")
        if len(parts) == 2:
            round_id, node, job_id = 1, parts[0], parts[1]
        else:
            round_id, node, job_id = int(parts[0]), parts[1], parts[2]
        jobs.append({"round": round_id, "node": node, "job_id": job_id})
print(json.dumps(jobs))
PY
}

json_rounds_from_file() {
  local path="$1"
  aicr_python - "$path" "$repeat_count" <<'PY'
import json
import sys
from collections import defaultdict
from pathlib import Path
path = Path(sys.argv[1])
repeat_count = int(sys.argv[2])
rounds = {idx: [] for idx in range(1, repeat_count + 1)}
if path.exists():
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("|")
        if len(parts) == 2:
            round_id, node, job_id = 1, parts[0], parts[1]
        else:
            round_id, node, job_id = int(parts[0]), parts[1], parts[2]
        rounds[round_id].append({"node": node, "job_id": job_id})
print(json.dumps([
    {"round": idx, "submitted_jobs": rounds[idx]}
    for idx in range(1, repeat_count + 1)
]))
PY
}

json_skipped_from_file() {
  local path="$1"
  aicr_python - "$path" <<'PY'
import json
import sys
from collections import defaultdict
from pathlib import Path
path = Path(sys.argv[1])
skipped = defaultdict(list)
if path.exists():
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        state, node = line.split("|", 1)
        skipped[state].append(node)
print(json.dumps({state: sorted(nodes) for state, nodes in sorted(skipped.items())}))
PY
}

write_requested_nodes_file() {
  local expr="$1"
  local output="$2"
  local token
  : >"$output"
  IFS=',' read -r -a tokens <<<"$expr"
  for token in "${tokens[@]}"; do
    [[ -n "$token" ]] || continue
    expand_nodes "$token" 2>/dev/null >>"$output" || printf '%s\n' "$token" >>"$output"
  done
  sort -u "$output" -o "$output"
}

filter_to_requested_nodes() {
  local requested_file="$1"
  local idle_file="$2"
  local skipped_file="$3"
  local filtered_idle="${tmpdir}/requested-idle-nodes.txt"
  local filtered_skipped="${tmpdir}/requested-skipped-nodes.txt"

  aicr_python - "$requested_file" "$idle_file" "$skipped_file" "$filtered_idle" "$filtered_skipped" <<'PY'
import sys
from pathlib import Path

requested_path, idle_path, skipped_path, filtered_idle_path, filtered_skipped_path = map(Path, sys.argv[1:])
requested = [line.strip() for line in requested_path.read_text(encoding="utf-8").splitlines() if line.strip()]
requested_set = set(requested)
idle = [line.strip() for line in idle_path.read_text(encoding="utf-8").splitlines() if line.strip()]
skipped_rows = []
if skipped_path.exists():
    for line in skipped_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        state, node = line.split("|", 1)
        skipped_rows.append((state, node))

known = set(idle)
known.update(node for _, node in skipped_rows)
filtered_idle = [node for node in idle if node in requested_set]
filtered_skipped = [(state, node) for state, node in skipped_rows if node in requested_set]
for node in requested:
    if node not in known:
        filtered_skipped.append(("not-found", node))

filtered_idle_path.write_text("".join(f"{node}\n" for node in filtered_idle), encoding="utf-8")
filtered_skipped_path.write_text("".join(f"{state}|{node}\n" for state, node in filtered_skipped), encoding="utf-8")
PY
  mv "$filtered_idle" "$idle_file"
  mv "$filtered_skipped" "$skipped_file"
}

write_manifest() {
  local path="$1"
  local mode="$2"
  local wait_result="$3"
  local markdown_report="$4"
  local idle_json submitted_json rounds_json skipped_json gpu_preflight_excluded_json

  idle_json="$(json_array_from_file "$idle_nodes_file")"
  submitted_json="$(json_jobs_from_file "$submitted_jobs_file")"
  rounds_json="$(json_rounds_from_file "$submitted_jobs_file")"
  skipped_json="$(json_skipped_from_file "$skipped_nodes_file")"
  gpu_preflight_excluded_json="$(cat "$gpu_preflight_excluded_file" 2>/dev/null || printf '[]')"

  aicr_python - \
    "$path" \
    "$cluster" \
    "$profile" \
    "$partition" \
    "$time_limit" \
    "$discovered_at_utc" \
    "$mode" \
    "$wait_result" \
    "$markdown_report" \
    "$submit_stagger_request" \
    "$submit_stagger_seconds" \
    "$submit_dependency_mode" \
    "$round_stagger_seconds" \
    "$repeat_count" \
    "$repeat_aggregation" \
    "$gpu_preflight_filter" \
    "$gpu_preflight_expected_count" \
    "latest same-day gpu-topology parsed summaries" \
    "$gpu_preflight_excluded_json" \
    "$idle_json" \
    "$submitted_json" \
    "$rounds_json" \
    "$skipped_json" <<'PY'
import json
import sys
from pathlib import Path

(
    path,
    cluster,
    profile,
    partition,
    time_limit,
    discovered_at_utc,
    mode,
    wait_result,
    markdown_report,
    submit_stagger_request,
    submit_stagger_seconds,
    submit_dependency_mode,
    round_stagger_seconds,
    repeat_count,
    repeat_aggregation,
    gpu_preflight_filter,
    gpu_preflight_expected_count,
    gpu_preflight_source,
    gpu_preflight_excluded_json,
    idle_json,
    submitted_json,
    rounds_json,
    skipped_json,
) = sys.argv[1:]

obj = {
    "schema_version": 1,
    "check": "gds",
    "cluster": cluster,
    "profile": profile,
    "partition": partition,
    "time_limit": time_limit,
    "discovered_at_utc": discovered_at_utc,
    "mode": mode,
    "repeat_count": int(repeat_count),
    "repeat_aggregation": repeat_aggregation,
    "gpu_preflight_filter_enabled": gpu_preflight_filter == "1",
    "gpu_preflight_expected_count": int(gpu_preflight_expected_count),
    "gpu_preflight_source": gpu_preflight_source,
    "gpu_preflight_excluded_nodes": json.loads(gpu_preflight_excluded_json),
    "idle_nodes": json.loads(idle_json),
    "submitted_jobs": json.loads(submitted_json),
    "rounds": json.loads(rounds_json),
    "skipped_nodes_by_state": json.loads(skipped_json),
    "wait_result": wait_result or None,
    "submit_stagger_request": submit_stagger_request,
    "submit_stagger_seconds": int(submit_stagger_seconds),
    "submit_dependency_mode": submit_dependency_mode,
    "round_stagger_seconds": int(round_stagger_seconds),
    "report_paths": {
        "markdown": markdown_report or None,
    },
}

out = Path(path)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY
}

wait_for_jobs() {
  local poll_seconds=15
  local jobs_csv="$1"
  local active

  [[ -n "$jobs_csv" ]] || return 0

  echo
  echo "Waiting for submitted GDS jobs to leave the Slurm queue: ${jobs_csv}"
  while true; do
    active="$(squeue -h -j "$jobs_csv" -o "%i %T %N" 2>/dev/null || true)"
    if [[ -z "$active" ]]; then
      echo "Submitted GDS jobs are no longer queued or running."
      break
    fi
    echo "Still active:"
    echo "$active" | sed 's/^/  /'
    sleep "$poll_seconds"
  done

  sleep 2
}

cluster=""
partition=""
profile="small"
requested_nodes=""
custom_gdsio_args="${AICR_GDS_CUSTOM_GDSIO_ARGS:-}"
allow_custom_target_file="${AICR_GDS_ALLOW_CUSTOM_TARGET_FILE:-0}"
apply=0
wait_for_completion=1
render=1
submit_stagger_seconds=60
submit_stagger_request=60
submit_dependency_mode="none"
round_stagger_seconds=30
repeat_count=1
repeat_aggregation="standard"
gpu_preflight_filter=0
gpu_preflight_expected_count=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --partition)
      partition="${2:-}"
      shift 2
      ;;
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --profile=*)
      profile="${1#--profile=}"
      shift
      ;;
    --nodes|--nodelist)
      requested_nodes="${2:-}"
      shift 2
      ;;
    --nodes=*|--nodelist=*)
      requested_nodes="${1#*=}"
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
    --apply)
      apply=1
      shift
      ;;
    --no-wait)
      wait_for_completion=0
      shift
      ;;
    --no-render)
      render=0
      shift
      ;;
    --submit-stagger-seconds)
      submit_stagger_seconds="${2:-}"
      shift 2
      ;;
    --round-stagger-seconds)
      round_stagger_seconds="${2:-}"
      shift 2
      ;;
    --repeat-count)
      repeat_count="${2:-}"
      shift 2
      ;;
    --repeat-aggregation)
      repeat_aggregation="${2:-}"
      shift 2
      ;;
    --gpu-preflight-filter)
      gpu_preflight_filter=1
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

[[ -n "$cluster" ]] || {
  usage
  exit 2
}

aicr_assert_supported_cluster "$cluster"
case "$profile" in
  small|medium|large|custom) ;;
  *)
    echo "ERROR: unsupported GDS profile: ${profile}" >&2
    echo "Supported profiles: small, medium, large, custom" >&2
    exit 2
    ;;
esac
if [[ "$profile" == "custom" && -z "$custom_gdsio_args" && -z "${AICR_GDS_PROFILE_CONFIG:-}" ]]; then
  echo "ERROR: custom profile requires --custom-gdsio-args, AICR_GDS_CUSTOM_GDSIO_ARGS, or AICR_GDS_PROFILE_CONFIG" >&2
  exit 2
fi
aicr_require_repo_root
aicr_require_settings_file
aicr_mkdirs

submit_stagger_request="$submit_stagger_seconds"
submit_stagger_mode="$(printf '%s' "$submit_stagger_request" | tr '[:upper:]' '[:lower:]')"
case "$submit_stagger_mode" in
  benchmark)
    submit_dependency_mode="afterany-chain"
    submit_stagger_seconds=5
    ;;
  *)
    if ! [[ "$submit_stagger_seconds" =~ ^[0-9]+$ ]]; then
      echo "ERROR: --submit-stagger-seconds must be a non-negative integer or benchmark" >&2
      exit 2
    fi
    ;;
esac
if ! [[ "$round_stagger_seconds" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --round-stagger-seconds must be a non-negative integer" >&2
  exit 2
fi
if ! [[ "$repeat_count" =~ ^[0-9]+$ ]] || [[ "$repeat_count" == "0" ]]; then
  echo "ERROR: --repeat-count must be a positive integer" >&2
  exit 2
fi
case "$repeat_aggregation" in
  standard|olympic) ;;
  *)
    echo "ERROR: --repeat-aggregation must be standard or olympic" >&2
    exit 2
    ;;
esac
if [[ "$repeat_count" != "1" && "$wait_for_completion" != "1" ]]; then
  echo "ERROR: --repeat-count greater than 1 requires waiting between rounds; omit --no-wait" >&2
  exit 2
fi

partition="${partition:-$(default_partition_for_cluster "$cluster")}"
time_limit="$(time_limit_for_profile "$profile")"
sbatch_path="slurm/verify/${cluster}-gds-1n-8g.sbatch"
[[ -f "${AICR_BMARK_DIR}/${sbatch_path}" ]] || aicr_die "Missing Slurm script: ${sbatch_path}"

date_utc="$(aicr_today_date)"
discovered_at_utc="$(aicr_timestamp_utc)"
manifest_id="$(date -u +%H%M%SZ)-gds-${cluster}"
manifest_rel="results/reports/${date_utc}/gds/${manifest_id}.json"
manifest_abs="${AICR_BMARK_DIR}/${manifest_rel}"
markdown_rel="results/reports/${date_utc}/gds-${cluster}.md"
markdown_abs="${AICR_BMARK_DIR}/${markdown_rel}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
idle_nodes_file="${tmpdir}/idle-nodes.txt"
skipped_nodes_file="${tmpdir}/skipped-nodes.txt"
submitted_jobs_file="${tmpdir}/submitted-jobs.txt"
requested_nodes_file="${tmpdir}/requested-nodes.txt"
gpu_preflight_nodes_file="${tmpdir}/gpu-preflight-idle-nodes.txt"
gpu_preflight_excluded_file="${tmpdir}/gpu-preflight-excluded.json"
touch "$idle_nodes_file" "$skipped_nodes_file" "$submitted_jobs_file"
printf '[]\n' >"$gpu_preflight_excluded_file"
gpu_preflight_expected_count="$(aicr_expected_gpu_count_for_cluster "$cluster")"

echo "Discovering GDS target nodes"
echo "Cluster profile : ${cluster}"
echo "GDS profile     : ${profile}"
echo "Partition       : ${partition}"
echo "Time limit      : ${time_limit}"
echo "State filter    : exactly idle"
if [[ -n "$requested_nodes" ]]; then
  echo "Requested nodes : ${requested_nodes}"
fi
echo "Repeat count    : ${repeat_count}"
echo "Aggregation     : ${repeat_aggregation}"
echo "GPU filter      : $([[ "$gpu_preflight_filter" == "1" ]] && echo enabled || echo disabled)"
if [[ "$submit_dependency_mode" == "afterany-chain" ]]; then
  echo "Submit stagger  : ${submit_stagger_request} dependency chain (${submit_stagger_seconds}s between sbatch calls)"
else
  echo "Submit stagger  : ${submit_stagger_seconds}s"
fi
echo "Round stagger   : ${round_stagger_seconds}s"
echo

if [[ -n "${AICR_GDS_FLEET_IDLE_NODES_CSV:-}" ]]; then
  tr ',' '\n' <<<"${AICR_GDS_FLEET_IDLE_NODES_CSV}" | sed '/^$/d' >"$idle_nodes_file"
else
  while IFS='|' read -r state nodespec; do
    [[ -n "${state}" && -n "${nodespec}" ]] || continue
    while IFS= read -r node; do
      [[ -n "$node" ]] || continue
      if [[ "$state" == "idle" ]]; then
        printf '%s\n' "$node" >>"$idle_nodes_file"
      else
        printf '%s|%s\n' "$state" "$node" >>"$skipped_nodes_file"
      fi
    done < <(expand_nodes "$nodespec")
  done < <(sinfo -h -p "$partition" -o '%T|%N')
fi

sort -u "$idle_nodes_file" -o "$idle_nodes_file"
sort -u "$skipped_nodes_file" -o "$skipped_nodes_file"

if [[ -n "$requested_nodes" ]]; then
  write_requested_nodes_file "$requested_nodes" "$requested_nodes_file"
  filter_to_requested_nodes "$requested_nodes_file" "$idle_nodes_file" "$skipped_nodes_file"
  sort -u "$idle_nodes_file" -o "$idle_nodes_file"
  sort -u "$skipped_nodes_file" -o "$skipped_nodes_file"
fi

if [[ "$gpu_preflight_filter" == "1" ]]; then
  aicr_filter_nodes_by_topology_gpu_preflight \
    "$cluster" \
    "$date_utc" \
    "$idle_nodes_file" \
    "$gpu_preflight_nodes_file" \
    "$skipped_nodes_file" \
    "$gpu_preflight_excluded_file"
  mv "$gpu_preflight_nodes_file" "$idle_nodes_file"
  sort -u "$skipped_nodes_file" -o "$skipped_nodes_file"
  aicr_print_gpu_preflight_filter_summary \
    "$gpu_preflight_expected_count" \
    "$idle_nodes_file" \
    "$gpu_preflight_excluded_file"
  echo
fi

idle_count="$(wc -l <"$idle_nodes_file" | tr -d ' ')"
skipped_count="$(wc -l <"$skipped_nodes_file" | tr -d ' ')"

echo "Idle nodes selected: ${idle_count}"
if [[ "$idle_count" != "0" ]]; then
  sed 's/^/  /' "$idle_nodes_file"
fi
echo
echo "Skipped non-idle nodes: ${skipped_count}"
if [[ "$skipped_count" != "0" ]]; then
  cut -d'|' -f1 "$skipped_nodes_file" | sort -u | while read -r state; do
    nodes="$(awk -F'|' -v s="$state" '$1 == s {print $2}' "$skipped_nodes_file" | paste -sd, -)"
    echo "  ${state}: ${nodes}"
  done
fi
echo

if [[ "$apply" == "0" ]]; then
  echo "Dry run. Commands that would be submitted:"
  previous_dry_run_job_id=""
  dry_run_index=0
  for round in $(seq 1 "$repeat_count"); do
    if [[ "$repeat_count" != "1" ]]; then
      echo "  # round ${round}/${repeat_count}"
    fi
    while read -r node; do
      [[ -n "$node" ]] || continue
      dry_run_index=$((dry_run_index + 1))
      dependency_preview=""
      if [[ "$submit_dependency_mode" == "afterany-chain" && -n "$previous_dry_run_job_id" ]]; then
        dependency_preview="--dependency=afterany:${previous_dry_run_job_id} "
      fi
      if [[ "$profile" == "custom" && -n "$custom_gdsio_args" ]]; then
        echo "  sbatch --parsable ${dependency_preview}--time=${time_limit} --export=ALL,PROFILE=custom,AICR_GDS_CUSTOM_GDSIO_ARGS='<args>' --nodelist=${node} ${sbatch_path}"
      else
        echo "  sbatch --parsable ${dependency_preview}--time=${time_limit} --export=ALL,PROFILE=${profile} --nodelist=${node} ${sbatch_path}"
      fi
      previous_dry_run_job_id="<job-${dry_run_index}>"
    done <"$idle_nodes_file"
  done
  if [[ "$idle_count" != "0" ]]; then
    if [[ "$submit_dependency_mode" == "afterany-chain" ]]; then
      echo "  # dependency chain mode: each job after the first uses --dependency=afterany:<previous-job-id>"
      echo "  # sleep ${submit_stagger_seconds} between sbatch calls when --apply is used"
    else
      echo "  # sleep ${submit_stagger_seconds} between submissions when --apply is used"
    fi
    if [[ "$repeat_count" != "1" && "$submit_dependency_mode" != "afterany-chain" ]]; then
      echo "  # sleep ${round_stagger_seconds} between completed rounds when --apply is used"
    fi
  fi
  write_manifest "$manifest_abs" "dry-run" "not-run" ""
  echo
  echo "Wrote ${manifest_rel}"
  exit 0
fi

if [[ "$idle_count" == "0" ]]; then
  write_manifest "$manifest_abs" "apply" "not-run" ""
  if [[ "$gpu_preflight_filter" == "1" ]]; then
    echo "ERROR: no exactly-idle nodes passed GPU preflight filtering in partition ${partition}" >&2
  else
    echo "ERROR: no exactly-idle nodes found in partition ${partition}" >&2
  fi
  echo "Wrote ${manifest_rel}" >&2
  exit 1
fi

echo "Submitting GDS jobs"
cd "$AICR_BMARK_DIR"
wait_result="not-run"
previous_chain_job_id=""
for round in $(seq 1 "$repeat_count"); do
  echo "Round ${round}/${repeat_count}"
  round_jobs_file="${tmpdir}/round-${round}-jobs.txt"
  : >"$round_jobs_file"
  submitted_count=0
  while read -r node; do
    [[ -n "$node" ]] || continue
    if [[ "$submitted_count" != "0" && "$submit_stagger_seconds" != "0" ]]; then
      sleep "$submit_stagger_seconds"
    fi
    dependency_arg=""
    if [[ "$submit_dependency_mode" == "afterany-chain" && -n "$previous_chain_job_id" ]]; then
      dependency_arg="--dependency=afterany:${previous_chain_job_id}"
    fi
    if [[ "$profile" == "custom" && -n "$custom_gdsio_args" ]]; then
      if [[ -n "$dependency_arg" ]]; then
        job_id="$(sbatch --parsable "$dependency_arg" --time="$time_limit" --export=ALL,PROFILE=custom,AICR_GDS_CUSTOM_GDSIO_ARGS="$custom_gdsio_args",AICR_GDS_ALLOW_CUSTOM_TARGET_FILE="$allow_custom_target_file" --nodelist="$node" "$sbatch_path")"
      else
        job_id="$(sbatch --parsable --time="$time_limit" --export=ALL,PROFILE=custom,AICR_GDS_CUSTOM_GDSIO_ARGS="$custom_gdsio_args",AICR_GDS_ALLOW_CUSTOM_TARGET_FILE="$allow_custom_target_file" --nodelist="$node" "$sbatch_path")"
      fi
    else
      if [[ -n "$dependency_arg" ]]; then
        job_id="$(sbatch --parsable "$dependency_arg" --time="$time_limit" --export=ALL,PROFILE="$profile" --nodelist="$node" "$sbatch_path")"
      else
        job_id="$(sbatch --parsable --time="$time_limit" --export=ALL,PROFILE="$profile" --nodelist="$node" "$sbatch_path")"
      fi
    fi
    job_id="${job_id%%;*}"
    [[ -n "$job_id" ]] || aicr_die "sbatch did not return a job ID for ${node}"
    previous_chain_job_id="$job_id"
    printf '%s|%s|%s\n' "$round" "$node" "$job_id" >>"$submitted_jobs_file"
    printf '%s\n' "$job_id" >>"$round_jobs_file"
    echo "Submitted round ${round} ${node} as job ${job_id}"
    submitted_count=$((submitted_count + 1))
  done <"$idle_nodes_file"

  if [[ "$wait_for_completion" == "1" && "$submit_dependency_mode" != "afterany-chain" ]]; then
    jobs_csv="$(paste -sd, - <"$round_jobs_file")"
    wait_for_jobs "$jobs_csv"
    wait_result="completed"
  elif [[ "$submit_dependency_mode" != "afterany-chain" ]]; then
    wait_result="skipped"
  fi

  if [[ "$round" != "$repeat_count" && "$wait_for_completion" == "1" && "$submit_dependency_mode" != "afterany-chain" && "$round_stagger_seconds" != "0" ]]; then
    echo "Sleeping ${round_stagger_seconds}s before next GDS repeat round"
    sleep "$round_stagger_seconds"
  fi
done

if [[ "$submit_dependency_mode" == "afterany-chain" ]]; then
  if [[ "$wait_for_completion" == "1" ]]; then
    wait_for_jobs "$(cut -d'|' -f3 "$submitted_jobs_file" | paste -sd, -)"
    wait_result="completed"
  else
    wait_result="skipped"
  fi
fi

report_path=""
if [[ "$render" == "1" ]]; then
  write_manifest "$manifest_abs" "apply" "$wait_result" "$markdown_rel"
  echo
  aicr_python "${AICR_BMARK_DIR}/scripts/report/render-verify-dashboard.py" \
    --results-root "${AICR_BMARK_DIR}/results" \
    --date "$date_utc" \
    --cluster "$cluster" \
    --both \
    --write \
    --fleet-manifest "$manifest_abs"
  report_path="$markdown_rel"
else
  write_manifest "$manifest_abs" "apply" "$wait_result" ""
fi

echo
echo "Wrote ${manifest_rel}"
if [[ -n "$report_path" ]]; then
  echo "Wrote ${report_path}"
fi
