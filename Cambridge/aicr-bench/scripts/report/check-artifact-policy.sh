#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/report/check-artifact-policy.sh

Checks the Git working tree for raw, generated, or unreviewed benchmark artifacts
that should not be committed by default.

Set AICR_ARTIFACT_POLICY_ALLOW=1 only when intentionally adding reviewed
results/reports or archive evidence.
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    echo "ERROR: unknown argument: $1" >&2
    usage
    exit 2
    ;;
esac

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR: run from inside the repository." >&2
  exit 2
}

tmp="$(mktemp)"
violations="$(mktemp)"
trap 'rm -f "$tmp" "$violations"' EXIT

{
  git diff --cached --name-only | sed 's/^/staged|/'
  git diff --name-only | sed 's/^/unstaged|/'
  git ls-files --others --exclude-standard | sed 's/^/untracked|/'
} | sort -u >"$tmp"

is_blocked_path() {
  local path="$1"
  case "$path" in
    results/by-date/*|results/by-node/*|results/setup/*|results/slurm/*|results/archives/*)
      return 0
      ;;
    results/reports/README.md|results/reports/.gitkeep)
      return 1
      ;;
    results/reports/*)
      return 0
      ;;
    results/*.log|results/*.out|results/*.err|results/slurm-*.out|results/slurm-*.err)
      return 0
      ;;
  esac
  return 1
}

while IFS='|' read -r state path; do
  [[ -n "${path:-}" ]] || continue
  if is_blocked_path "$path"; then
    printf '%s\t%s\n' "$state" "$path" >>"$violations"
  fi
done <"$tmp"

if [[ ! -s "$violations" ]]; then
  echo "Artifact policy check passed."
  exit 0
fi

if [[ "${AICR_ARTIFACT_POLICY_ALLOW:-0}" == "1" ]]; then
  echo "Artifact policy override enabled; review these paths before commit:" >&2
  cat "$violations" >&2
  exit 0
fi

cat >&2 <<'EOF'
ERROR: raw/generated benchmark artifacts are present in the Git working tree.

Generated runtime evidence is not committed by default. Add reviewed reports
only after explicit review, then rerun with:

  AICR_ARTIFACT_POLICY_ALLOW=1 make check-artifact-policy

Violations:
EOF
cat "$violations" >&2
exit 1
