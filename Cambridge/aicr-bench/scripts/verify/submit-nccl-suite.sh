#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/verify/submit-nccl-suite.sh --scope local --cluster <b200|rtxpro6000> [options]
  scripts/verify/submit-nccl-suite.sh --scope rdma --cluster <b200|rtxpro6000> --nodes-per-job <n> [options]
  scripts/verify/submit-nccl-suite.sh --scope scale --cluster <b200|rtxpro6000> [options]

Dry-run-first submitter for the fully instrumented NCCL suite.
Scale scope submits one scale at a time in apply mode: all 1-node jobs finish
before 2-node jobs, 2-node before 4-node, and so on. The dashboard renders
after the full selected scale ladder completes.

Options:
  --apply                    Submit jobs with sbatch
  --scope <local|rdma|scale> Suite scope
  --cluster <name>           b200 or rtxpro6000
  --profile <name>           smoke, small, medium, or large (default: small)
  --suite-class <name>       Optional local suite class filter
  --nodes <list>             Optional space/comma-separated candidate node list
  --nodes-per-job <n>        RDMA group size, or a single scale for --scope scale
  --scales <list>            Scale scope node counts, comma/space-separated
  --partition <name>         Override partition
  --time <value>             Override Slurm time limit
  --repeat-count <n>         Repeat jobs as separate Slurm jobs (default: 1)
  --repeat-aggregation <name> standard or olympic repeat aggregation (default: standard)
  --gpu-preflight-filter     Keep only nodes with passing same-day gpu-topology evidence
  --submit-stagger-seconds <n>  Delay between submissions (default: 5)
  --scale-stagger-seconds <n>   Additional delay after one scale finishes before the next starts (default: 0)
  --round-stagger-seconds <n>   Delay between repeat rounds (default: 0)
  --no-wait                  Do not wait for submitted jobs
  --no-render                Do not render suite report after jobs finish
  -h, --help                 Show this help
EOF
}

expand_nodes() {
  local expr="$1"
  if command -v scontrol >/dev/null 2>&1; then
    scontrol show hostnames "$expr"
  else
    tr ',' '\n' <<<"$expr"
  fi
}

default_partition() {
  case "$1" in
    b200) printf 'GPU2\n' ;;
    rtxpro6000) printf 'GPU1\n' ;;
  esac
}

time_for_profile() {
  case "$1" in
    smoke) printf '00:45:00\n' ;;
    small) printf '02:30:00\n' ;;
    medium) printf '04:00:00\n' ;;
    large) printf '08:00:00\n' ;;
  esac
}

default_scales_for_cluster() {
  case "$1" in
    b200) printf '1 2 4 8 16\n' ;;
    rtxpro6000) printf '1 2 4\n' ;;
  esac
}

validate_scale_for_cluster() {
  local cluster_name="$1"
  local scale="$2"
  case "${cluster_name}:${scale}" in
    b200:1|b200:2|b200:4|b200:8|b200:16|rtxpro6000:1|rtxpro6000:2|rtxpro6000:4) ;;
    *) echo "ERROR: invalid scale ${scale} for ${cluster_name}" >&2; exit 2 ;;
  esac
}

build_groups() {
  local nodes_file="$1"
  local groups_file="$2"
  local group_size="$3"
  aicr_python - "$nodes_file" "$groups_file" "$group_size" <<'PY'
import sys
from pathlib import Path

nodes = [line.strip() for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines() if line.strip()]
group_size = int(sys.argv[3])
groups = []
if len(nodes) >= group_size:
    full = len(nodes) // group_size
    rem = len(nodes) % group_size
    for idx in range(full):
        groups.append(nodes[idx * group_size:(idx + 1) * group_size])
    if rem:
        tail = nodes[-group_size:]
        if not groups or groups[-1] != tail:
            groups.append(tail)
Path(sys.argv[2]).write_text("".join(",".join(group) + "\n" for group in groups), encoding="utf-8")
PY
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

write_scale_manifest() {
  local path="$1"
  local mode="$2"
  local wait_result="$3"
  local markdown_report="$4"
  local idle_json skipped_json gpu_preflight_excluded_json

  idle_json="$(json_array_from_file "${idle_nodes_file}")"
  skipped_json="$(json_skipped_from_file "${skipped_nodes_file}")"
  gpu_preflight_excluded_json="$(cat "${gpu_preflight_excluded_file}" 2>/dev/null || printf '[]')"

  aicr_python - \
    "$path" "$cluster" "$partition" "$discovered_at_utc" "$mode" "$wait_result" \
    "$markdown_report" "$submit_stagger_seconds" "$scale_stagger_seconds" "$round_stagger_seconds" "$repeat_count" \
    "$repeat_aggregation" "$gpu_preflight_filter" "$gpu_preflight_expected_count" \
    "latest same-day gpu-topology parsed summaries" "$gpu_preflight_excluded_json" \
    "$profile" "$scales_text" "$idle_json" "$selected_groups_file" "$submitted_jobs_file" \
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
    scale_stagger_seconds,
    round_stagger_seconds,
    repeat_count,
    repeat_aggregation,
    gpu_preflight_filter,
    gpu_preflight_expected_count,
    gpu_preflight_source,
    gpu_preflight_excluded_json,
    profile,
    scales_text,
    idle_json,
    selected_groups_path,
    submitted_jobs_path,
    skipped_json,
) = sys.argv[1:]

selected_scales = [int(item) for item in scales_text.split() if item]

selected_groups = []
for line in Path(selected_groups_path).read_text(encoding="utf-8").splitlines():
    if not line.strip():
        continue
    scale_text, group = line.split("|", 1)
    nodes = [item for item in group.split(",") if item]
    selected_groups.append({
        "scale": int(scale_text),
        "group": group,
        "nodes": nodes,
        "node_count": len(nodes),
        "gpu_count": len(nodes) * 8,
    })

submitted_jobs = []
rounds = {idx: [] for idx in range(1, int(repeat_count) + 1)}
if Path(submitted_jobs_path).exists():
    for line in Path(submitted_jobs_path).read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        round_text, scale_text, group, job_id = line.split("|", 3)
        nodes = [item for item in group.split(",") if item]
        item = {
            "round": int(round_text),
            "scale": int(scale_text),
            "group": group,
            "nodes": nodes,
            "node_count": len(nodes),
            "gpu_count": len(nodes) * 8,
            "job_id": job_id,
        }
        submitted_jobs.append(item)
        rounds[item["round"]].append(dict(item))

obj = {
    "schema_version": 1,
    "check": "nccl-suite",
    "scope": "scale",
    "cluster": cluster,
    "partition": partition,
    "profile": profile,
    "discovered_at_utc": discovered_at_utc,
    "mode": mode,
    "repeat_count": int(repeat_count),
    "repeat_aggregation": repeat_aggregation,
    "gpu_preflight_filter_enabled": gpu_preflight_filter == "1",
    "gpu_preflight_expected_count": int(gpu_preflight_expected_count),
    "gpu_preflight_source": gpu_preflight_source,
    "gpu_preflight_excluded_nodes": json.loads(gpu_preflight_excluded_json),
    "selected_scales": selected_scales,
    "idle_nodes": json.loads(idle_json),
    "selected_groups": selected_groups,
    "submitted_jobs": submitted_jobs,
    "rounds": [
        {"round": idx, "submitted_jobs": rounds[idx]}
        for idx in range(1, int(repeat_count) + 1)
    ],
    "scale_submission_policy": "sequential-wait",
    "skipped_nodes_by_state": json.loads(skipped_json),
    "wait_result": wait_result or None,
    "submit_stagger_seconds": int(submit_stagger_seconds),
    "scale_stagger_seconds": int(scale_stagger_seconds),
    "round_stagger_seconds": int(round_stagger_seconds),
    "report_paths": {"markdown": markdown_report or None},
}

out = Path(path)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY
}

wait_for_jobs() {
  local jobs_csv="$1"
  local active
  [[ -n "$jobs_csv" ]] || return 0
  echo
  echo "Waiting for submitted NCCL suite jobs to leave the Slurm queue: ${jobs_csv}"
  while true; do
    active="$(squeue -h -j "$jobs_csv" -o "%i %T %N" 2>/dev/null || true)"
    if [[ -z "$active" ]]; then
      echo "Submitted NCCL suite jobs are no longer queued or running."
      break
    fi
    echo "Still active:"
    echo "$active" | sed 's/^/  /'
    sleep 15
  done
  sleep 2
}

scope=""
cluster=""
profile="small"
suite_class=""
nodes=""
nodes_per_job=""
scales=""
partition=""
time_limit=""
repeat_count=1
repeat_aggregation="standard"
gpu_preflight_filter=0
gpu_preflight_expected_count=0
submit_stagger_seconds=5
scale_stagger_seconds=0
round_stagger_seconds=0
apply=0
wait_for_completion=1
render=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      apply=1
      shift
      ;;
    --scope)
      scope="${2:?missing value for --scope}"
      shift 2
      ;;
    --cluster)
      cluster="${2:?missing value for --cluster}"
      shift 2
      ;;
    --profile)
      profile="${2:?missing value for --profile}"
      shift 2
      ;;
    --suite-class)
      suite_class="${2:?missing value for --suite-class}"
      shift 2
      ;;
    --nodes)
      nodes="${2:?missing value for --nodes}"
      shift 2
      ;;
    --nodes-per-job)
      nodes_per_job="${2:?missing value for --nodes-per-job}"
      shift 2
      ;;
    --scales)
      scales="${2:?missing value for --scales}"
      shift 2
      ;;
    --partition)
      partition="${2:?missing value for --partition}"
      shift 2
      ;;
    --time)
      time_limit="${2:?missing value for --time}"
      shift 2
      ;;
    --repeat-count)
      repeat_count="${2:?missing value for --repeat-count}"
      shift 2
      ;;
    --repeat-aggregation)
      repeat_aggregation="${2:?missing value for --repeat-aggregation}"
      shift 2
      ;;
    --gpu-preflight-filter)
      gpu_preflight_filter=1
      shift
      ;;
    --submit-stagger-seconds)
      submit_stagger_seconds="${2:?missing value for --submit-stagger-seconds}"
      shift 2
      ;;
    --scale-stagger-seconds)
      scale_stagger_seconds="${2:?missing value for --scale-stagger-seconds}"
      shift 2
      ;;
    --round-stagger-seconds)
      round_stagger_seconds="${2:?missing value for --round-stagger-seconds}"
      shift 2
      ;;
    --no-wait)
      wait_for_completion=0
      shift
      ;;
    --no-render)
      render=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ -n "${scope}" ]] || { echo "ERROR: --scope is required" >&2; usage; exit 2; }
[[ -n "${cluster}" ]] || { echo "ERROR: --cluster is required" >&2; usage; exit 2; }
aicr_assert_supported_cluster "${cluster}"
aicr_require_repo_root
aicr_require_settings_file
case "${scope}" in local|rdma|scale) ;; *) echo "ERROR: --scope must be local, rdma, or scale" >&2; exit 2 ;; esac
case "${profile}" in smoke|small|medium|large) ;; *) echo "ERROR: --profile must be smoke, small, medium, or large" >&2; exit 2 ;; esac
if [[ -n "${suite_class}" ]]; then
  if [[ "${scope}" != "local" ]]; then
    echo "ERROR: --suite-class is supported only with --scope local" >&2
    exit 2
  fi
  case "${cluster}:${suite_class}" in
    b200:b200_1proc_8g|b200:b200_8rank_1g|b200:b200_2rank_socket_4g|rtxpro6000:rtx_8rank_1g|rtxpro6000:rtx_pair_policy) ;;
    *) echo "ERROR: unsupported --suite-class ${suite_class} for ${cluster}" >&2; exit 2 ;;
  esac
fi
[[ "${repeat_count}" =~ ^[0-9]+$ && "${repeat_count}" -ge 1 ]] || { echo "ERROR: --repeat-count must be positive" >&2; exit 2; }
case "${repeat_aggregation}" in
  standard|olympic) ;;
  *) echo "ERROR: --repeat-aggregation must be standard or olympic" >&2; exit 2 ;;
esac
[[ "${submit_stagger_seconds}" =~ ^[0-9]+$ ]] || { echo "ERROR: --submit-stagger-seconds must be non-negative" >&2; exit 2; }
[[ "${scale_stagger_seconds}" =~ ^[0-9]+$ ]] || { echo "ERROR: --scale-stagger-seconds must be non-negative" >&2; exit 2; }
[[ "${round_stagger_seconds}" =~ ^[0-9]+$ ]] || { echo "ERROR: --round-stagger-seconds must be non-negative" >&2; exit 2; }
if [[ "${repeat_count}" != "1" && "${wait_for_completion}" != "1" ]]; then
  echo "ERROR: --repeat-count greater than 1 requires waiting; omit --no-wait" >&2
  exit 2
fi

partition="${partition:-$(default_partition "${cluster}")}"
time_limit="${time_limit:-$(time_for_profile "${profile}")}"
date_utc="$(aicr_today_date)"
discovered_at_utc="$(aicr_timestamp_utc)"
manifest_rel=""
manifest_abs=""
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
idle_nodes_file="${tmpdir}/idle-nodes.txt"
skipped_nodes_file="${tmpdir}/skipped-nodes.txt"
gpu_preflight_nodes_file="${tmpdir}/gpu-preflight-idle-nodes.txt"
gpu_preflight_excluded_file="${tmpdir}/gpu-preflight-excluded.json"
groups_file="${tmpdir}/node-groups.txt"
selected_groups_file="${tmpdir}/selected-groups.txt"
submitted_jobs_file="${tmpdir}/submitted-jobs.txt"
: >"${idle_nodes_file}"
: >"${skipped_nodes_file}"
: >"${groups_file}"
: >"${selected_groups_file}"
: >"${submitted_jobs_file}"
printf '[]\n' >"${gpu_preflight_excluded_file}"
gpu_preflight_expected_count="$(aicr_expected_gpu_count_for_cluster "$cluster")"

if [[ -n "${nodes}" ]]; then
  for token in ${nodes//,/ }; do
    expand_nodes "${token}" >>"${idle_nodes_file}"
  done
else
  if ! command -v sinfo >/dev/null 2>&1; then
    echo "ERROR: sinfo is required for discovery unless --nodes is provided" >&2
    exit 2
  fi
  while IFS='|' read -r state nodespec; do
    [[ -n "${state}" && -n "${nodespec}" ]] || continue
    while IFS= read -r node; do
      [[ -n "${node}" ]] || continue
      if [[ "${state}" == "idle" ]]; then
        printf '%s\n' "${node}" >>"${idle_nodes_file}"
      else
        printf '%s|%s\n' "${state}" "${node}" >>"${skipped_nodes_file}"
      fi
    done < <(expand_nodes "${nodespec}")
  done < <(sinfo -h -p "${partition}" -o '%T|%N')
fi
sort -u "${idle_nodes_file}" -o "${idle_nodes_file}"
sort -u "${skipped_nodes_file}" -o "${skipped_nodes_file}"

if [[ "${gpu_preflight_filter}" == "1" ]]; then
  aicr_filter_nodes_by_topology_gpu_preflight \
    "${cluster}" \
    "${date_utc}" \
    "${idle_nodes_file}" \
    "${gpu_preflight_nodes_file}" \
    "${skipped_nodes_file}" \
    "${gpu_preflight_excluded_file}"
  mv "${gpu_preflight_nodes_file}" "${idle_nodes_file}"
  sort -u "${skipped_nodes_file}" -o "${skipped_nodes_file}"
fi

case "${scope}:${cluster}" in
  local:b200) sbatch_path="slurm/verify/b200-nccl-suite-local-1n-8g.sbatch" ;;
  local:rtxpro6000) sbatch_path="slurm/verify/rtxpro6000-nccl-suite-local-1n-8g.sbatch" ;;
  rdma:b200) sbatch_path="slurm/verify/b200-nccl-suite-rdma.sbatch" ;;
  rdma:rtxpro6000) sbatch_path="slurm/verify/rtxpro6000-nccl-suite-rdma.sbatch" ;;
  scale:b200) sbatch_path="slurm/verify/b200-nccl-suite-scale.sbatch" ;;
  scale:rtxpro6000) sbatch_path="slurm/verify/rtxpro6000-nccl-suite-scale.sbatch" ;;
  *) echo "ERROR: unsupported scope/cluster" >&2; exit 2 ;;
esac
[[ -f "${AICR_BMARK_DIR}/${sbatch_path}" ]] || [[ -f "${sbatch_path}" ]] || { echo "ERROR: missing ${sbatch_path}" >&2; exit 1; }

scales_text=""
if [[ "${scope}" == "scale" ]]; then
  if [[ -n "${nodes_per_job}" && -n "${scales}" ]]; then
    echo "ERROR: use either --nodes-per-job or --scales with --scope scale, not both" >&2
    exit 2
  fi
  scales="${scales:-${nodes_per_job:-$(default_scales_for_cluster "${cluster}")}}"
  for scale in ${scales//,/ }; do
    [[ -n "${scale}" ]] || continue
    [[ "${scale}" =~ ^[0-9]+$ ]] || { echo "ERROR: scale must be numeric: ${scale}" >&2; exit 2; }
    validate_scale_for_cluster "${cluster}" "${scale}"
    scales_text="${scales_text} ${scale}"
    scale_groups_file="${tmpdir}/scale-${scale}-groups.txt"
    build_groups "${idle_nodes_file}" "${scale_groups_file}" "${scale}"
    if [[ ! -s "${scale_groups_file}" ]]; then
      if [[ "${gpu_preflight_filter}" == "1" ]]; then
        echo "ERROR: fewer than ${scale} GPU-preflight-passed exactly-idle ${cluster} nodes are available for scale ${scale}" >&2
      else
        echo "ERROR: fewer than ${scale} exactly-idle ${cluster} nodes are available for scale ${scale}" >&2
      fi
      exit 1
    fi
    while IFS= read -r group; do
      [[ -n "${group}" ]] || continue
      printf '%s|%s\n' "${scale}" "${group}" >>"${selected_groups_file}"
    done <"${scale_groups_file}"
  done
  scales_text="${scales_text# }"
elif [[ "${scope}" == "rdma" ]]; then
  nodes_per_job="${nodes_per_job:-2}"
  case "${cluster}:${nodes_per_job}" in
    b200:2|b200:4|b200:8|b200:16|rtxpro6000:2|rtxpro6000:4|rtxpro6000:8) ;;
    *) echo "ERROR: invalid --nodes-per-job ${nodes_per_job} for ${cluster}" >&2; exit 2 ;;
  esac
  build_groups "${idle_nodes_file}" "${groups_file}" "${nodes_per_job}"
  while IFS= read -r group; do
    [[ -n "${group}" ]] || continue
    printf '%s|%s\n' "${nodes_per_job}" "${group}" >>"${selected_groups_file}"
  done <"${groups_file}"
else
  while IFS= read -r node; do
    [[ -n "${node}" ]] || continue
    printf '1|%s\n' "${node}" >>"${selected_groups_file}"
  done <"${idle_nodes_file}"
fi

idle_count="$(wc -l <"${idle_nodes_file}" | tr -d ' ')"
group_count="$(wc -l <"${selected_groups_file}" | tr -d ' ')"
planned_jobs=$((group_count * repeat_count))

echo "NCCL suite submitter"
echo "mode=$([[ "${apply}" == "1" ]] && echo apply || echo dry-run)"
echo "scope=${scope}"
echo "cluster=${cluster}"
echo "profile=${profile}"
if [[ -n "${suite_class}" ]]; then
  echo "suite_class=${suite_class}"
fi
echo "partition=${partition}"
echo "time=${time_limit}"
echo "repeat_count=${repeat_count}"
echo "repeat_aggregation=${repeat_aggregation}"
echo "gpu_preflight_filter=$([[ "${gpu_preflight_filter}" == "1" ]] && echo enabled || echo disabled)"
echo "submit_stagger_seconds=${submit_stagger_seconds}"
if [[ "${scope}" == "scale" ]]; then
  echo "scale_stagger_seconds=${scale_stagger_seconds}"
fi
echo "round_stagger_seconds=${round_stagger_seconds}"
if [[ "${scope}" == "rdma" ]]; then
  echo "nodes_per_job=${nodes_per_job}"
elif [[ "${scope}" == "scale" ]]; then
  echo "scales=${scales_text}"
fi
echo
if [[ "${gpu_preflight_filter}" == "1" ]]; then
  aicr_print_gpu_preflight_filter_summary \
    "${gpu_preflight_expected_count}" \
    "${idle_nodes_file}" \
    "${gpu_preflight_excluded_file}"
  echo
fi
echo "Idle nodes selected: ${idle_count}"
sed 's/^/  /' "${idle_nodes_file}" || true
echo
echo "Selected jobs/groups: ${group_count}"
sed 's/^/  /' "${selected_groups_file}" || true
echo
echo "NCCL suite submission summary"
echo "  Mode        : $([[ "${apply}" == "1" ]] && echo apply || echo dry-run)"
echo "  Jobs        : ${planned_jobs}"
echo "  Groups      : ${group_count}"
echo "  Nodes       : ${idle_count}"
echo "  Cluster     : ${cluster}"
echo "  Partition   : ${partition}"
echo

if [[ "${group_count}" == "0" ]]; then
  echo "ERROR: no runnable NCCL suite jobs/groups selected" >&2
  exit 1
fi

if [[ "${apply}" == "1" && "${scope}" == "scale" && "${wait_for_completion}" != "1" ]]; then
  scale_count="$(wc -w <<<"${scales_text}" | tr -d ' ')"
  if [[ "${scale_count}" -gt 1 ]]; then
    echo "ERROR: --scope scale with multiple scales requires waiting between scales; omit --no-wait" >&2
    exit 2
  fi
fi

base_args=(--profile "${profile}")
if [[ -n "${suite_class}" ]]; then
  base_args+=(--suite-class "${suite_class}")
fi

if [[ "${apply}" == "0" ]]; then
  echo "Dry run. Commands that would be submitted:"
  for round in $(seq 1 "${repeat_count}"); do
    if [[ "${repeat_count}" != "1" ]]; then
      echo "  # round ${round}/${repeat_count}"
    fi
    previous_scale=""
    while IFS='|' read -r scale group; do
      [[ -n "${scale}" && -n "${group}" ]] || continue
      if [[ "${scope}" == "scale" && -n "${previous_scale}" && "${scale}" != "${previous_scale}" ]]; then
        echo "  # wait for all ${previous_scale}n jobs before submitting ${scale}n jobs when --apply is used"
        if [[ "${scale_stagger_seconds}" != "0" ]]; then
          echo "  # sleep ${scale_stagger_seconds} after ${previous_scale}n jobs finish before ${scale}n submissions"
        fi
      fi
      if [[ "${scope}" == "local" ]]; then
        if [[ "${suite_class}" == "b200_2rank_socket_4g" ]]; then
          echo "  sbatch --parsable --ntasks=2 --ntasks-per-node=2 --cpus-per-task=64 --nodelist=${group} --time=${time_limit} ${sbatch_path} ${base_args[*]}"
        else
          echo "  sbatch --parsable --nodelist=${group} --time=${time_limit} ${sbatch_path} ${base_args[*]}"
        fi
      else
        ntasks=$(( scale * 8 ))
        echo "  sbatch --parsable --nodes=${scale} --ntasks=${ntasks} --ntasks-per-node=8 --cpus-per-task=16 --nodelist=${group} --time=${time_limit} ${sbatch_path} ${base_args[*]} --nodes-per-job ${scale}"
      fi
      previous_scale="${scale}"
    done <"${selected_groups_file}"
  done
  exit 0
fi

cd "${AICR_BMARK_DIR}"
wait_result="not-run"
if [[ "${scope}" == "scale" ]]; then
  manifest_id="$(date -u +%H%M%SZ)-nccl-suite-${cluster}"
  manifest_rel="results/reports/${date_utc}/nccl-suite/${manifest_id}.json"
  manifest_abs="${AICR_BMARK_DIR}/${manifest_rel}"
fi
for round in $(seq 1 "${repeat_count}"); do
  echo "Round ${round}/${repeat_count}"
  round_jobs_file="${tmpdir}/round-${round}-jobs.txt"
  scale_jobs_file="${tmpdir}/round-${round}-scale-jobs.txt"
  : >"${round_jobs_file}"
  : >"${scale_jobs_file}"
  submitted_this_round=0
  previous_scale=""
  current_scale=""
  while IFS='|' read -r scale group; do
    [[ -n "${scale}" && -n "${group}" ]] || continue
    if [[ "${scope}" == "scale" && "${wait_for_completion}" == "1" && -n "${current_scale}" && "${scale}" != "${current_scale}" ]]; then
      write_scale_manifest "${manifest_abs}" "apply" "submitted" ""
      echo "Wrote recoverable pre-wait manifest ${manifest_rel}"
      wait_for_jobs "$(paste -sd, - <"${scale_jobs_file}")"
      wait_result="completed"
      : >"${scale_jobs_file}"
      if [[ "${scale_stagger_seconds}" != "0" ]]; then
        echo "Sleeping ${scale_stagger_seconds}s before scale ${scale} submissions"
        sleep "${scale_stagger_seconds}"
      fi
    fi
    if [[ "${submitted_this_round}" != "0" && "${submit_stagger_seconds}" != "0" ]]; then
      sleep "${submit_stagger_seconds}"
    fi
    if [[ "${scope}" == "local" ]]; then
      if [[ "${suite_class}" == "b200_2rank_socket_4g" ]]; then
        job_id="$(
          sbatch --parsable \
            --ntasks=2 \
            --ntasks-per-node=2 \
            --cpus-per-task=64 \
            --nodelist="${group}" \
            --time="${time_limit}" \
            "${sbatch_path}" \
            "${base_args[@]}"
        )"
      else
        job_id="$(sbatch --parsable --nodelist="${group}" --time="${time_limit}" "${sbatch_path}" "${base_args[@]}")"
      fi
    else
      ntasks=$(( scale * 8 ))
      job_id="$(
        sbatch --parsable \
          --nodes="${scale}" \
          --ntasks="${ntasks}" \
          --ntasks-per-node=8 \
          --cpus-per-task=16 \
          --nodelist="${group}" \
          --time="${time_limit}" \
          "${sbatch_path}" \
          "${base_args[@]}" \
          --nodes-per-job "${scale}"
      )"
    fi
    job_id="${job_id%%;*}"
    [[ -n "${job_id}" ]] || aicr_die "sbatch did not return a job ID for ${group}"
    printf '%s|%s|%s|%s\n' "${round}" "${scale}" "${group}" "${job_id}" >>"${submitted_jobs_file}"
    printf '%s\n' "${job_id}" >>"${round_jobs_file}"
    printf '%s\n' "${job_id}" >>"${scale_jobs_file}"
    echo "Submitted round ${round} scale ${scale} ${group} as job ${job_id}"
    submitted_this_round=$((submitted_this_round + 1))
    previous_scale="${scale}"
    current_scale="${scale}"
  done <"${selected_groups_file}"
  if [[ "${scope}" == "scale" && "${wait_for_completion}" == "1" ]]; then
    write_scale_manifest "${manifest_abs}" "apply" "submitted" ""
    echo "Wrote recoverable pre-wait manifest ${manifest_rel}"
    wait_for_jobs "$(paste -sd, - <"${scale_jobs_file}")"
    wait_result="completed"
  else
    if [[ "${scope}" == "scale" ]]; then
      write_scale_manifest "${manifest_abs}" "apply" "submitted" ""
      echo "Wrote recoverable pre-wait manifest ${manifest_rel}"
    fi
    if [[ "${wait_for_completion}" == "1" ]]; then
      wait_for_jobs "$(paste -sd, - <"${round_jobs_file}")"
      wait_result="completed"
    else
      wait_result="skipped"
    fi
  fi
  if [[ "${round}" != "${repeat_count}" && "${round_stagger_seconds}" != "0" ]]; then
    sleep "${round_stagger_seconds}"
  fi
done

if [[ "${render}" == "1" && "${wait_for_completion}" == "1" ]]; then
  if [[ "${scope}" == "local" ]]; then
    report_rel="results/reports/${date_utc}/nccl-suite-local-${cluster}.md"
    scripts/report/render-nccl-suite-report.py --date "${date_utc}" --cluster "${cluster}" --scope local --output "${report_rel}"
  elif [[ "${scope}" == "rdma" ]]; then
    report_rel="results/reports/${date_utc}/nccl-suite-rdma-${cluster}-${nodes_per_job}n.md"
    scripts/report/render-nccl-suite-report.py --date "${date_utc}" --cluster "${cluster}" --scope rdma --nodes-per-job "${nodes_per_job}" --output "${report_rel}"
  else
    report_rel="results/reports/${date_utc}/nccl-suite-${cluster}.md"
    write_scale_manifest "${manifest_abs}" "apply" "${wait_result}" "${report_rel}"
    scripts/report/render-nccl-suite-report.py --date "${date_utc}" --cluster "${cluster}" --scope scale --fleet-manifest "${manifest_abs}" --output "${report_rel}"
    echo "Wrote ${manifest_rel}"
  fi
  echo "Wrote ${report_rel}"
elif [[ "${scope}" == "scale" ]]; then
  write_scale_manifest "${manifest_abs}" "apply" "${wait_result}" ""
  echo "Wrote ${manifest_rel}"
fi
