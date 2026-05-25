#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"
usage(){ echo "Usage: $0 --cluster <rtxpro6000|b200> [--json]" >&2; }
cluster=""; json_output=0
while [[ $# -gt 0 ]]; do case "$1" in --cluster) cluster="${2:-}"; shift 2 ;; --json) json_output=1; shift ;; -h|--help) usage; exit 0 ;; *) usage; exit 2 ;; esac; done
[[ -n "$cluster" ]] || { usage; exit 2; }
aicr_assert_supported_cluster "$cluster"
baseline_rel="$(aicr_setup_baseline_path "$cluster")"; baseline_abs="${AICR_BMARK_DIR}/${baseline_rel}"; history_rel="$(aicr_setup_baseline_history_path "$cluster")"
if [[ ! -f "$baseline_abs" ]]; then [[ "$json_output" == "1" ]] && aicr_print_json_envelope false "$cluster" "" "$baseline_rel" "$history_rel" '["baseline not found"]' || echo "No baseline file found: $baseline_rel" >&2; exit 1; fi
if [[ "$json_output" == "1" ]]; then baseline_id="$(aicr_python - "$baseline_abs" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], 'r', encoding='utf-8')).get('baseline_id', ''))
PY
)"; aicr_print_json_envelope true "$cluster" "$baseline_id" "$baseline_rel" "$history_rel" '[]'; else cat "$baseline_abs"; fi
