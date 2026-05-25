#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"
usage(){ echo "Usage: $0 --cluster <rtxpro6000|b200> [--invalidated-by <name>] [--notes <text>] [--json]" >&2; }
cluster=""; invalidated_by="${USER:-unknown}"; notes=""; json_output=0
while [[ $# -gt 0 ]]; do case "$1" in --cluster) cluster="${2:-}"; shift 2 ;; --invalidated-by) invalidated_by="${2:-}"; shift 2 ;; --notes) notes="${2:-}"; shift 2 ;; --json) json_output=1; shift ;; -h|--help) usage; exit 0 ;; *) usage; exit 2 ;; esac; done
[[ -n "$cluster" ]] || { usage; exit 2; }
aicr_assert_supported_cluster "$cluster"
baseline_rel="$(aicr_setup_baseline_path "$cluster")"; baseline_abs="${AICR_BMARK_DIR}/${baseline_rel}"; history_rel="$(aicr_setup_baseline_history_path "$cluster")"; history_abs="${AICR_BMARK_DIR}/${history_rel}"
[[ -f "$baseline_abs" ]] || { [[ "$json_output" == "1" ]] && aicr_print_json_envelope false "$cluster" "" "$baseline_rel" "$history_rel" '["baseline not found"]' || echo "ERROR: baseline not found: ${baseline_rel}" >&2; exit 1; }
tmp="$(mktemp)"
aicr_python - "$baseline_abs" "$invalidated_by" "$notes" "$tmp" <<'PY'
import json, sys, datetime
baseline_path, invalidated_by, notes, out_path = sys.argv[1:]
obj = json.load(open(baseline_path, 'r', encoding='utf-8'))
obj['state'] = 'invalid'
obj['invalidated_at_utc'] = datetime.datetime.utcnow().replace(microsecond=0).isoformat() + 'Z'
obj['invalidated_by'] = invalidated_by
if notes:
    obj['notes'] = (obj.get('notes') or '') + ('; ' if obj.get('notes') else '') + notes
open(out_path, 'w', encoding='utf-8').write(json.dumps(obj, indent=2) + '\n')
PY
cp "$tmp" "$baseline_abs"; mkdir -p "$(dirname "$history_abs")"; cat "$tmp" >> "$history_abs"; echo >> "$history_abs"; baseline_id="$(aicr_python - "$baseline_abs" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], 'r', encoding='utf-8')).get('baseline_id', ''))
PY
)"; rm -f "$tmp"
[[ "$json_output" == "1" ]] && aicr_print_json_envelope true "$cluster" "$baseline_id" "$baseline_rel" "$history_rel" '[]' || echo "Invalidated baseline ${baseline_id} for cluster ${cluster}"
