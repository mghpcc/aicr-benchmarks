#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/setup/check-runtime-assets.sh

Validates the configured uv-built Python environment and required
Apptainer images. Python is checked by direct env/bin/python execution.
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
aicr_validate_runtime_assets

echo "Canonical runtime assets are ready."
echo "Runtime root: ${AICR_RUNTIME_ROOT}"
