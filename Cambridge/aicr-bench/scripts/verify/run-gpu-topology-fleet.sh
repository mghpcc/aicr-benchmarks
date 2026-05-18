#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/verify/run-gpu-topology-fleet.sh --cluster <b200|rtxpro6000> [--partition <name>] [--nodes <nodelist>] [--submit-stagger-seconds <n>] [--apply] [--no-wait] [--no-render]

Default behavior is a dry run: discover exactly-idle nodes and print sbatch commands without submitting.
Use --nodes to limit collection to an explicit comma-separated node list or Slurm hostlist.
Default submit stagger is 2 seconds.
EOF
}

default_partition_for_cluster() {
  case "$1" in
    b200) printf 'GPU2\n' ;;
    rtxpro6000) printf 'GPU1\n' ;;
    *) aicr_die "Unsupported cluster: $1" ;;
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
        node, job_id = line.split("|", 1)
        jobs.append({"node": node, "job_id": job_id})
print(json.dumps(jobs))
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

write_manifest() {
  local path="$1"
  local mode="$2"
  local wait_result="$3"
  local markdown_report="$4"
  local idle_json submitted_json skipped_json

  idle_json="$(json_array_from_file "$idle_nodes_file")"
  submitted_json="$(json_jobs_from_file "$submitted_jobs_file")"
  skipped_json="$(json_skipped_from_file "$skipped_nodes_file")"

  aicr_python - \
    "$path" \
    "$cluster" \
    "$partition" \
    "$discovered_at_utc" \
    "$mode" \
    "$wait_result" \
    "$markdown_report" \
    "$submit_stagger_seconds" \
    "$idle_json" \
    "$submitted_json" \
    "$skipped_json" <<'PY'
import json
import sys
from pathlib import Path

(
    path,
    cluster,
    partition,
    discovered_at_utc,
    mode,
    wait_result,
    markdown_report,
    submit_stagger_seconds,
    idle_json,
    submitted_json,
    skipped_json,
) = sys.argv[1:]

obj = {
    "schema_version": 1,
    "check": "gpu-topology",
    "cluster": cluster,
    "partition": partition,
    "discovered_at_utc": discovered_at_utc,
    "mode": mode,
    "idle_nodes": json.loads(idle_json),
    "submitted_jobs": json.loads(submitted_json),
    "skipped_nodes_by_state": json.loads(skipped_json),
    "wait_result": wait_result or None,
    "submit_stagger_seconds": int(submit_stagger_seconds),
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
  echo "Waiting for submitted GPU topology jobs to leave the Slurm queue: ${jobs_csv}"
  while true; do
    active="$(squeue -h -j "$jobs_csv" -o "%i %T %N" 2>/dev/null || true)"
    if [[ -z "$active" ]]; then
      echo "Submitted GPU topology jobs are no longer queued or running."
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
apply=0
wait_for_completion=1
render=1
submit_stagger_seconds=2
nodes_filter=""

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
    --nodes|--nodelist)
      nodes_filter="${2:-}"
      shift 2
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
aicr_require_repo_root
aicr_require_settings_file
aicr_mkdirs

if ! [[ "$submit_stagger_seconds" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --submit-stagger-seconds must be a non-negative integer" >&2
  exit 2
fi

partition="${partition:-$(default_partition_for_cluster "$cluster")}"
sbatch_path="slurm/verify/${cluster}-gpu-topology-1n-8g.sbatch"
[[ -f "${AICR_BMARK_DIR}/${sbatch_path}" ]] || aicr_die "Missing Slurm script: ${sbatch_path}"

date_utc="$(aicr_today_date)"
discovered_at_utc="$(aicr_timestamp_utc)"
manifest_id="$(date -u +%H%M%SZ)-gpu-topology-${cluster}"
manifest_rel="results/reports/${date_utc}/gpu-topology/${manifest_id}.json"
manifest_abs="${AICR_BMARK_DIR}/${manifest_rel}"
markdown_rel="results/reports/${date_utc}/gpu-topology-${cluster}.md"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
idle_nodes_file="${tmpdir}/idle-nodes.txt"
skipped_nodes_file="${tmpdir}/skipped-nodes.txt"
submitted_jobs_file="${tmpdir}/submitted-jobs.txt"
requested_nodes_file="${tmpdir}/requested-nodes.txt"
seen_nodes_file="${tmpdir}/seen-nodes.txt"
touch "$idle_nodes_file" "$skipped_nodes_file" "$submitted_jobs_file" "$requested_nodes_file" "$seen_nodes_file"

if [[ -n "$nodes_filter" ]]; then
  expand_nodes "$nodes_filter" | sort -u >"$requested_nodes_file"
  if [[ ! -s "$requested_nodes_file" ]]; then
    echo "ERROR: --nodes did not expand to any hostnames: ${nodes_filter}" >&2
    exit 2
  fi
fi

echo "Discovering GPU topology target nodes"
echo "Cluster profile : ${cluster}"
echo "Partition       : ${partition}"
echo "State filter    : exactly idle"
if [[ -n "$nodes_filter" ]]; then
  echo "Node filter     : ${nodes_filter}"
fi
echo "Submit stagger  : ${submit_stagger_seconds}s"
echo

while IFS='|' read -r state nodespec; do
  [[ -n "${state}" && -n "${nodespec}" ]] || continue
  while IFS= read -r node; do
    [[ -n "$node" ]] || continue
    if [[ -n "$nodes_filter" ]] && ! grep -Fxq "$node" "$requested_nodes_file"; then
      continue
    fi
    printf '%s\n' "$node" >>"$seen_nodes_file"
    if [[ "$state" == "idle" ]]; then
      printf '%s\n' "$node" >>"$idle_nodes_file"
    else
      printf '%s|%s\n' "$state" "$node" >>"$skipped_nodes_file"
    fi
  done < <(expand_nodes "$nodespec")
done < <(sinfo -h -p "$partition" -o '%T|%N')

if [[ -n "$nodes_filter" ]]; then
  sort -u "$seen_nodes_file" -o "$seen_nodes_file"
  while read -r node; do
    [[ -n "$node" ]] || continue
    if ! grep -Fxq "$node" "$seen_nodes_file"; then
      printf 'not-found|%s\n' "$node" >>"$skipped_nodes_file"
    fi
  done <"$requested_nodes_file"
fi

sort -u "$idle_nodes_file" -o "$idle_nodes_file"
sort -u "$skipped_nodes_file" -o "$skipped_nodes_file"

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
  while read -r node; do
    [[ -n "$node" ]] || continue
    echo "  sbatch --parsable --nodelist=${node} ${sbatch_path}"
  done <"$idle_nodes_file"
  if [[ "$idle_count" != "0" ]]; then
    echo "  # sleep ${submit_stagger_seconds} between submissions when --apply is used"
  fi
  write_manifest "$manifest_abs" "dry-run" "not-run" ""
  echo
  echo "Wrote ${manifest_rel}"
  exit 0
fi

if [[ "$idle_count" == "0" ]]; then
  write_manifest "$manifest_abs" "apply" "not-run" ""
  echo "ERROR: no exactly-idle nodes found in partition ${partition}" >&2
  echo "Wrote ${manifest_rel}" >&2
  exit 1
fi

echo "Submitting GPU topology jobs"
cd "$AICR_BMARK_DIR"
submitted_count=0
while read -r node; do
  [[ -n "$node" ]] || continue
  if [[ "$submitted_count" != "0" && "$submit_stagger_seconds" != "0" ]]; then
    sleep "$submit_stagger_seconds"
  fi
  job_id="$(sbatch --parsable --nodelist="$node" "$sbatch_path")"
  job_id="${job_id%%;*}"
  [[ -n "$job_id" ]] || aicr_die "sbatch did not return a job ID for ${node}"
  printf '%s|%s\n' "$node" "$job_id" >>"$submitted_jobs_file"
  echo "Submitted ${node} as job ${job_id}"
  submitted_count=$((submitted_count + 1))
done <"$idle_nodes_file"

wait_result="not-run"
if [[ "$wait_for_completion" == "1" ]]; then
  jobs_csv="$(cut -d'|' -f2 "$submitted_jobs_file" | paste -sd, -)"
  wait_for_jobs "$jobs_csv"
  wait_result="completed"
else
  wait_result="skipped"
fi

report_path=""
if [[ "$render" == "1" ]]; then
  write_manifest "$manifest_abs" "apply" "$wait_result" "$markdown_rel"
  echo
  aicr_python "${AICR_BMARK_DIR}/scripts/report/render-verify-dashboard.py" \
    --results-root "${AICR_BMARK_DIR}/results" \
    --date "$date_utc" \
    --cluster "$cluster" \
    --check gpu-topology \
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
