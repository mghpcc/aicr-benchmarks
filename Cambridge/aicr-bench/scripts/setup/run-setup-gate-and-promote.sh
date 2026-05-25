#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/setup/run-setup-gate-and-promote.sh --cluster <rtxpro6000|b200> [--submit-smoke-tests] [--ready-timeout-seconds <n>] [--ready-poll-seconds <n>] [--replace-existing]

Runs the setup gate. When smoke tests are submitted, waits for setup readiness and promotes the ready baseline.
EOF
}

cluster=""
submit_smoke_tests=0
ready_timeout_seconds=180
ready_poll_seconds=5
replace_existing=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --submit-smoke-tests)
      submit_smoke_tests=1
      shift
      ;;
    --ready-timeout-seconds)
      ready_timeout_seconds="${2:-}"
      shift 2
      ;;
    --ready-poll-seconds)
      ready_poll_seconds="${2:-}"
      shift 2
      ;;
    --replace-existing)
      replace_existing=1
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
[[ "${ready_timeout_seconds}" =~ ^[0-9]+$ && "${ready_timeout_seconds}" -gt 0 ]] || {
  echo "ERROR: --ready-timeout-seconds must be a positive integer" >&2
  exit 2
}
[[ "${ready_poll_seconds}" =~ ^[0-9]+$ && "${ready_poll_seconds}" -gt 0 ]] || {
  echo "ERROR: --ready-poll-seconds must be a positive integer" >&2
  exit 2
}

aicr_assert_supported_cluster "${cluster}"
aicr_require_repo_root

gate_cmd=(bash "${SCRIPT_DIR}/run-setup-gate.sh" --cluster "${cluster}")
if [[ "${submit_smoke_tests}" == "1" ]]; then
  gate_cmd+=(--submit-smoke-tests)
fi

"${gate_cmd[@]}"

if [[ "${submit_smoke_tests}" != "1" ]]; then
  echo
  echo "Setup gate preview complete. Re-run with --submit-smoke-tests to promote a ready baseline."
  exit 0
fi

readiness_json="$(mktemp)"
trap 'rm -f "${readiness_json}"' EXIT
deadline=$((SECONDS + ready_timeout_seconds))

while true; do
  if bash "${SCRIPT_DIR}/check-setup-readiness.sh" --cluster "${cluster}" --json >"${readiness_json}"; then
    ready="yes"
  else
    ready="no"
  fi

  if [[ "${ready}" == "yes" ]]; then
    break
  fi

  if [[ "${SECONDS}" -ge "${deadline}" ]]; then
    echo "ERROR: setup readiness did not become promotable within ${ready_timeout_seconds}s" >&2
    echo "Last readiness state:" >&2
    cat "${readiness_json}" >&2
    exit 1
  fi

  echo "Setup readiness is not promotable yet; sleeping ${ready_poll_seconds}s before recheck."
  sleep "${ready_poll_seconds}"
done

mapfile -t run_ids < <(
  aicr_python - "${readiness_json}" <<'PY'
import json
import sys
from pathlib import Path

obj = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
checks = obj.get("checks") or {}
for check in ("container-compat", "pytorch-smoke", "hpc-benchmarks-smoke", "elbencho-smoke"):
    run_id = (checks.get(check) or {}).get("run_id")
    if not run_id:
        raise SystemExit(f"missing run_id for {check}")
    print(run_id)
PY
)

promote_cmd=(
  bash "${SCRIPT_DIR}/promote-setup-baseline.sh"
  --cluster "${cluster}"
  --container-compat-runid "${run_ids[0]}"
  --pytorch-smoke-runid "${run_ids[1]}"
  --hpc-benchmarks-smoke-runid "${run_ids[2]}"
  --elbencho-smoke-runid "${run_ids[3]}"
)
if [[ "${replace_existing}" == "1" ]]; then
  promote_cmd+=(--replace-existing)
fi

echo "Promoting setup baseline:"
printf '  '
printf '%q ' "${promote_cmd[@]}"
echo
"${promote_cmd[@]}"
