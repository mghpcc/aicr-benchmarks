#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/run-elbencho.sh --cluster <b200|rtxpro6000> --workload <peak-cluster|small-block|small-file|metadata> [--profile <smoke|small>] [--command <elbencho command>]

Runs an operator-supplied elbencho command and records raw/parsed benchmark
artifacts. Workload command defaults are intentionally research-pending.

The command is executed from the run's artifact wrapper directory. Use exported
AICR_* absolute paths for repo, runtime image, scratch, and results locations.
EOF
}

aicr_require_repo_root
aicr_mkdirs

cluster="${AICR_CLUSTER_NAME:-}"
workload="${ELBENCHO_WORKLOAD:-}"
profile="${ELBENCHO_PROFILE:-small}"
elbencho_cmd="${ELBENCHO_CMD:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --workload)
      workload="${2:-}"
      shift 2
      ;;
    --profile)
      profile="${2:-}"
      shift 2
      ;;
    --command)
      elbencho_cmd="${2:-}"
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
[[ -n "$workload" ]] || {
  usage
  exit 2
}
aicr_assert_supported_cluster "$cluster"
case "$workload" in
  peak-cluster|small-block|small-file|metadata) ;;
  *) aicr_die "--workload must be peak-cluster, small-block, small-file, or metadata" ;;
esac
case "$profile" in
  smoke|small) ;;
  *) aicr_die "--profile must be smoke or small" ;;
esac

date_utc="$(aicr_today_date)"
node_short="$(hostname -s 2>/dev/null || hostname)"
peer_nodes_csv="$(scontrol show hostnames "${SLURM_JOB_NODELIST:-}" 2>/dev/null | paste -sd, - || true)"
if [[ -z "$peer_nodes_csv" ]]; then
  peer_nodes_csv="$node_short"
fi
node_count="${SLURM_NNODES:-1}"
run_id="${ELBENCHO_RUN_ID:-$(aicr_next_by_date_run_id "$date_utc" "$cluster" "$AICR_SCOPE_MULTI_NODE" "$AICR_CHECK_ELBENCHO")}"

raw_rel="$(aicr_multi_node_raw_run_dir "$date_utc" "$cluster" "$AICR_CHECK_ELBENCHO" "$run_id")"
parsed_rel="$(aicr_multi_node_parsed_run_dir "$date_utc" "$cluster" "$AICR_CHECK_ELBENCHO" "$run_id")"
raw_abs="${AICR_BMARK_DIR}/${raw_rel}"
parsed_abs="${AICR_BMARK_DIR}/${parsed_rel}"
canonical_abs="${raw_abs}/canonical"
wrapper_abs="${raw_abs}/wrapper"
metadata_abs="${raw_abs}/metadata"
mkdir -p "$canonical_abs" "$wrapper_abs" "$metadata_abs" "$parsed_abs"

command_rel="${raw_rel}/canonical/elbencho-command.txt"
stdout_rel="${raw_rel}/canonical/elbencho-stdout.txt"
stderr_rel="${raw_rel}/canonical/elbencho-stderr.txt"
summary_txt_rel="${raw_rel}/canonical/elbencho-summary.txt"
record_rel="${raw_rel}/metadata/record.json"
summary_json_rel="${parsed_rel}/summary.json"
status_rel="${parsed_rel}/status.json"

command_abs="${AICR_BMARK_DIR}/${command_rel}"
stdout_abs="${AICR_BMARK_DIR}/${stdout_rel}"
stderr_abs="${AICR_BMARK_DIR}/${stderr_rel}"
summary_txt_abs="${AICR_BMARK_DIR}/${summary_txt_rel}"
record_abs="${AICR_BMARK_DIR}/${record_rel}"
summary_json_abs="${AICR_BMARK_DIR}/${summary_json_rel}"
status_abs="${AICR_BMARK_DIR}/${status_rel}"

submitted_at_utc="$(aicr_timestamp_utc)"
launched_at_utc="$submitted_at_utc"
completed_at_utc=""
job_id="${SLURM_JOB_ID:-}"
partition="${SLURM_JOB_PARTITION:-${SLURM_JOB_PARTITION_NAME:-unknown}}"
status="not-run"
return_code=""
notes=""

printf '%s\n' "$elbencho_cmd" >"$command_abs"
if [[ -z "$elbencho_cmd" ]]; then
  printf 'elbencho command defaults are research-pending; set ELBENCHO_CMD or --command\n' >"$stdout_abs"
  : >"$stderr_abs"
  notes="elbencho command defaults are research-pending"
  status="not-run"
  return_code=""
else
  export AICR_ELBENCHO_WORK_DIR="$wrapper_abs"
  export AICR_ELBENCHO_RAW_DIR="$raw_abs"
  export AICR_ELBENCHO_PARSED_DIR="$parsed_abs"
  set +e
  (cd "$wrapper_abs" && bash -lc "$elbencho_cmd") >"$stdout_abs" 2>"$stderr_abs"
  rc=$?
  set -e
  return_code="$rc"
  if [[ "$rc" -eq 0 ]]; then
    status="passed"
  else
    status="failed"
    notes="elbencho command failed"
  fi
fi
completed_at_utc="$(aicr_timestamp_utc)"

export cluster workload profile run_id date_utc node_short peer_nodes_csv node_count
export status return_code notes submitted_at_utc launched_at_utc completed_at_utc
export partition job_id raw_rel parsed_rel command_rel stdout_rel stderr_rel summary_txt_rel summary_json_rel status_rel record_rel elbencho_cmd
export stdout_file_abs="$stdout_abs"

aicr_python - "$summary_txt_abs" "$summary_json_abs" "$status_abs" "$record_abs" <<'PY'
import json
import os
import re
import sys
from pathlib import Path

summary_txt_abs, summary_json_abs, status_abs, record_abs = sys.argv[1:]

def maybe_int(value):
    if value in (None, ""):
        return None
    try:
        return int(value)
    except ValueError:
        return None

def first_float(patterns, text):
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            try:
                return float(match.group(1).replace(",", ""))
            except ValueError:
                return None
    return None

def parse_elbencho_metrics(stdout_text):
    metrics = {
        "read_iops": first_float([
            r"\bread\b[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:IOPS|iops|ops/s)",
            r"read[^:\n]*:\s*([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:IOPS|iops|ops/s)",
        ], stdout_text),
        "write_iops": first_float([
            r"\bwrite\b[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:IOPS|iops|ops/s)",
            r"write[^:\n]*:\s*([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:IOPS|iops|ops/s)",
        ], stdout_text),
        "read_mib_per_second": first_float([
            r"\bread\b[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*MiB/s",
            r"read[^:\n]*:\s*([0-9][0-9,]*(?:\.[0-9]+)?)\s*MiB/s",
        ], stdout_text),
        "write_mib_per_second": first_float([
            r"\bwrite\b[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*MiB/s",
            r"write[^:\n]*:\s*([0-9][0-9,]*(?:\.[0-9]+)?)\s*MiB/s",
        ], stdout_text),
        "mkdirs_per_second": first_float([r"mkdir[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:/s|ops/s|per second)"], stdout_text),
        "file_creates_per_second": first_float([r"(?:create|mkfile|file write)[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:/s|ops/s|per second)"], stdout_text),
        "file_reads_per_second": first_float([r"(?:file read|read files?)[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:/s|ops/s|per second)"], stdout_text),
        "file_writes_per_second": first_float([r"(?:file write|write files?)[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:/s|ops/s|per second)"], stdout_text),
        "rmfiles_per_second": first_float([r"(?:rmfile|unlink|remove files?)[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:/s|ops/s|per second)"], stdout_text),
        "rmdirs_per_second": first_float([r"(?:rmdir|remove dirs?)[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:/s|ops/s|per second)"], stdout_text),
        "stats_per_second": first_float([r"\bstat[^\n]*?([0-9][0-9,]*(?:\.[0-9]+)?)\s*(?:/s|ops/s|per second)"], stdout_text),
    }
    current_op = None
    for line in stdout_text.splitlines():
        op_match = re.match(r"^(MKDIRS|WRITE|STAT|READ|RMFILES|RMDIRS)\s+", line)
        if op_match:
            current_op = op_match.group(1)
        elif line.startswith("---"):
            current_op = None
        if current_op is None:
            continue
        values = [float(item.replace(",", "")) for item in re.findall(r"(?<![A-Za-z])([0-9][0-9,]*(?:\.[0-9]+)?)(?![A-Za-z])", line)]
        if not values:
            continue
        value = values[-1]
        if "IOPS" in line:
            if current_op == "WRITE":
                metrics["write_iops"] = value
            elif current_op == "READ":
                metrics["read_iops"] = value
        elif "Throughput MiB/s" in line:
            if current_op == "WRITE":
                metrics["write_mib_per_second"] = value
            elif current_op == "READ":
                metrics["read_mib_per_second"] = value
        elif "Files/s" in line:
            if current_op == "WRITE":
                metrics["file_writes_per_second"] = value
                metrics["file_creates_per_second"] = value
            elif current_op == "READ":
                metrics["file_reads_per_second"] = value
            elif current_op == "STAT":
                metrics["stats_per_second"] = value
            elif current_op == "RMFILES":
                metrics["rmfiles_per_second"] = value
        elif "Dirs/s" in line:
            if current_op == "MKDIRS":
                metrics["mkdirs_per_second"] = value
            elif current_op == "RMDIRS":
                metrics["rmdirs_per_second"] = value
    return metrics

def has_any(text, tokens):
    return any(token in text for token in tokens)

def strip_shell_comments(text):
    lines = []
    for line in text.splitlines():
        lines.append(line.split("#", 1)[0])
    return "\n".join(lines)

def has_dropcache_option(command):
    return "--dropcache" in strip_shell_comments(command or "")

def command_review(command, workload):
    text = command or ""
    command_body = strip_shell_comments(text)
    checks = {
        "target_path": has_any(text, ("RUN_ROOT", "AICR_SCRATCH_DIR", "ELBENCHO_TARGET_ROOT"))
        or re.search(r"(?<![-\w])/(?:work|scratch|mnt|vast|tmp)/", text) is not None,
        "block_size": has_any(text, ("--block", "--blocksize", "-b ", "--bs")),
        "file_size_or_count": has_any(text, ("--size", "--files", "--file", "--dirs", "-s ")),
        "threads": "--threads" in text or "-t " in text,
        "iodepth": "--iodepth" in text or "--iodepths" in text,
        "direct_io": "--direct" in text,
        "cleanup": has_any(text, (
            "--cleanup", "--rm", "--remove", "--delete",
            "--delfiles", "--deldirs", "-F", "-D", "rm -rf", "rm -f", "rmdir ",
        )),
        "dryrun_or_preflight": "--dryrun" in text or "--dry-run" in text or "preflight" in text.lower(),
    }
    if workload == "small-file":
        checks["namespace_cleanup"] = "--delfiles" in text and "--deldirs" in text
    elif workload == "metadata":
        checks["namespace_cleanup"] = "--delfiles" in text and "--deldirs" in text
        checks["metadata_cache_control"] = "--sync" in command_body and (
            has_dropcache_option(text) or "non-cache-neutral-rehearsal" in text
        )
    elif workload == "peak-cluster":
        checks["distributed_host_list"] = "--hostsfile" in text or "--hosts " in text or "--hosts=" in text
        checks["service_start"] = "--service" in text
        checks["service_stop"] = "--quit" in text
    missing = [name for name, ok in checks.items() if not ok]
    return {
        "checks": checks,
        "missing": missing,
        "status": "reviewed-shape" if not missing else "needs-review",
    }

peers = [item for item in os.environ["peer_nodes_csv"].split(",") if item]
return_code = maybe_int(os.environ.get("return_code", ""))
stdout_text = Path(os.environ["stdout_file_abs"]).read_text(encoding="utf-8", errors="replace") if os.environ.get("stdout_file_abs") else ""
metrics = parse_elbencho_metrics(stdout_text)
review = command_review(os.environ["elbencho_cmd"], os.environ["workload"])
summary = {
    "status": os.environ["status"],
    "cluster": os.environ["cluster"],
    "date": os.environ["date_utc"],
    "run_id": os.environ["run_id"],
    "profile": os.environ["profile"],
    "workload": os.environ["workload"],
    "node": os.environ["node_short"],
    "peer_nodes": peers,
    "node_count": maybe_int(os.environ["node_count"]),
    "job_id": os.environ["job_id"] or None,
    "partition": os.environ["partition"],
    "command": os.environ["elbencho_cmd"],
    "return_code": return_code,
    "stdout_file": os.environ["stdout_rel"],
    "stderr_file": os.environ["stderr_rel"],
    "metrics": metrics,
    "command_review": review,
    "evidence_label": "non-cache-neutral-rehearsal"
    if os.environ["workload"] == "metadata" and not has_dropcache_option(os.environ["elbencho_cmd"])
    else "cache-neutral" if os.environ["workload"] == "metadata" else "standard",
    "notes": os.environ["notes"],
}
status = {
    "status": os.environ["status"],
    "pass_basis": "command_return_code",
}
record = {
    "schema_version": 1,
    "scope": "multi-node",
    "cluster": os.environ["cluster"],
    "node": None,
    "peer_nodes": peers,
    "check": "elbencho",
    "subcheck": os.environ["workload"],
    "mode": f"benchmark-storage-{os.environ['profile']}",
    "run_id": os.environ["run_id"],
    "date": os.environ["date_utc"],
    "submitted_at_utc": os.environ["submitted_at_utc"],
    "launched_at_utc": os.environ["launched_at_utc"],
    "completed_at_utc": os.environ["completed_at_utc"],
    "partition": os.environ["partition"],
    "job_id": os.environ["job_id"] or None,
    "status": os.environ["status"],
    "pass_basis": "command_return_code",
    "notes": os.environ["notes"],
    "node_count": maybe_int(os.environ["node_count"]) or len(peers),
    "gpu_count": 0,
    "wrapper_log_paths": [
        f"{os.environ['raw_rel']}/wrapper/slurm-{os.environ['job_id']}.out" if os.environ["job_id"] else f"{os.environ['raw_rel']}/wrapper/slurm-<jobid>.out",
        f"{os.environ['raw_rel']}/wrapper/slurm-{os.environ['job_id']}.err" if os.environ["job_id"] else f"{os.environ['raw_rel']}/wrapper/slurm-<jobid>.err",
    ],
    "canonical_artifact_paths": [
        os.environ["command_rel"],
        os.environ["stdout_rel"],
        os.environ["stderr_rel"],
        os.environ["summary_txt_rel"],
    ],
    "parsed_artifact_paths": [
        os.environ["summary_json_rel"],
        os.environ["status_rel"],
    ],
    "setup_baseline_ref": {
        "cluster": os.environ["cluster"],
        "baseline_path": f"results/setup/{os.environ['cluster']}/baseline.json",
        "baseline_id": None,
    },
}

lines = [
    f"cluster={summary['cluster']}",
    f"date={summary['date']}",
    f"run_id={summary['run_id']}",
    f"profile={summary['profile']}",
    f"workload={summary['workload']}",
    f"node_count={summary['node_count']}",
    f"peer_nodes={','.join(peers)}",
    f"job_id={summary['job_id'] or ''}",
    f"status={summary['status']}",
    f"return_code={summary['return_code'] if summary['return_code'] is not None else ''}",
    f"command={summary['command']}",
    f"command_review_status={summary['command_review']['status']}",
    f"command_review_missing={','.join(summary['command_review']['missing'])}",
    f"evidence_label={summary['evidence_label']}",
    f"read_iops={summary['metrics'].get('read_iops') or ''}",
    f"write_iops={summary['metrics'].get('write_iops') or ''}",
    f"read_mib_per_second={summary['metrics'].get('read_mib_per_second') or ''}",
    f"write_mib_per_second={summary['metrics'].get('write_mib_per_second') or ''}",
    f"mkdirs_per_second={summary['metrics'].get('mkdirs_per_second') or ''}",
    f"file_creates_per_second={summary['metrics'].get('file_creates_per_second') or ''}",
    f"file_reads_per_second={summary['metrics'].get('file_reads_per_second') or ''}",
    f"file_writes_per_second={summary['metrics'].get('file_writes_per_second') or ''}",
    f"rmfiles_per_second={summary['metrics'].get('rmfiles_per_second') or ''}",
    f"rmdirs_per_second={summary['metrics'].get('rmdirs_per_second') or ''}",
    f"stats_per_second={summary['metrics'].get('stats_per_second') or ''}",
    f"notes={summary['notes']}",
]
Path(summary_txt_abs).write_text("\n".join(lines) + "\n", encoding="utf-8")
for path, obj in ((summary_json_abs, summary), (status_abs, status), (record_abs, record)):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, indent=2)
        fh.write("\n")
PY

by_date_index_rel="$(aicr_by_date_index_path "$date_utc")"
aicr_append_index_row_from_record "${AICR_BMARK_DIR}/${by_date_index_rel}" "$record_abs"

echo "Wrote ${record_rel}"
echo "Wrote ${summary_json_rel}"
echo "Wrote ${status_rel}"
echo "Indexed ${by_date_index_rel}"
