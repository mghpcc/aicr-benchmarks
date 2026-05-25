#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/python-env-common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/setup/refresh-python-locks.sh

Refresh the committed uv.lock from pyproject.toml.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

aicr_require_repo_root
if command -v uv >/dev/null 2>&1; then
  uv_cmd="$(command -v uv)"
elif [[ -x "$AICR_UV_BIN" ]]; then
  uv_cmd="$AICR_UV_BIN"
elif [[ -x "$(aicr_repo_local_runtime_root_prefix)/bin/uv" ]]; then
  uv_cmd="$(aicr_repo_local_runtime_root_prefix)/bin/uv"
else
  uv_cmd="$(aicr_bootstrap_uv "$(aicr_repo_local_runtime_root_prefix)")"
fi

echo "Refreshing uv.lock"
(cd "$AICR_BMARK_DIR" && "$uv_cmd" lock)
lockfile="${AICR_BMARK_DIR}/uv.lock"
[[ -f "$lockfile" ]] || aicr_die "lockfile was not generated: ${lockfile}"
echo "$(aicr_sha256_file "$lockfile")  ${lockfile}"
