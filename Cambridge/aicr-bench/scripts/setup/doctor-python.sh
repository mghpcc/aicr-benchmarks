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
  scripts/setup/doctor-python.sh

Checks the repo Python runtime selected by scripts/lib/run-repo-python.sh.
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

platform="$(aicr_python_platform)"
lockfile="$(aicr_python_lockfile_for_platform "$platform")"
python_bin="$(aicr_repo_python_env_path || true)"
if [[ -z "$python_bin" ]]; then
  echo "ERROR: repo Python is not available." >&2
  echo "Configured env : ${AICR_UV_ENV_PREFIX}" >&2
  echo "Local fallback : $(aicr_repo_local_env_prefix)" >&2
  echo "Run make setup-python-local." >&2
  exit 1
fi

env_prefix="$(cd "$(dirname "$python_bin")/.." && pwd)"
lock_sha=""
if [[ -f "$lockfile" ]]; then
  lock_sha="$(aicr_sha256_file "$lockfile")"
else
  echo "ERROR: missing committed platform lockfile: ${lockfile}" >&2
  exit 1
fi

mkdir -p "${AICR_TMP_DIR}/matplotlib"
MPLCONFIGDIR="${MPLCONFIGDIR:-${AICR_TMP_DIR}/matplotlib}" PYTHONNOUSERSITE=1 PYTHONHOME= "$python_bin" - \
  "$platform" \
  "$AICR_UV_ENV_PREFIX" \
  "$(aicr_repo_local_env_prefix)" \
  "$env_prefix" \
  "$python_bin" \
  "$lockfile" \
  "$lock_sha" <<'PY'
import importlib
import importlib.metadata
import sys
from pathlib import Path

(
    platform_name,
    configured_prefix,
    local_fallback,
    env_prefix,
    python_bin,
    lockfile,
    lock_sha,
) = sys.argv[1:]

required_imports = ["jsonschema", "matplotlib", "pandas", "plotly", "snakemake"]

def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)

if sys.version_info[:2] != (3, 11):
    fail(f"expected Python 3.11, found {sys.version.split()[0]}")

for module in required_imports:
    importlib.import_module(module)

if not (Path(env_prefix) / "pyvenv.cfg").exists():
    fail(f"selected environment is not a uv virtualenv: {env_prefix}")

print("Repo Python runtime is ready.")
print(f"Platform          : {platform_name}")
print(f"Configured env    : {configured_prefix}")
print(f"Repo-local fallback: {local_fallback}")
print(f"Selected env      : {env_prefix}")
print(f"Python executable : {python_bin}")
print(f"Python version    : {sys.version.split()[0]}")
print(f"Lockfile          : {lockfile}")
print(f"Lockfile sha256   : {lock_sha}")
print("Required imports  :")
for name in required_imports:
    importlib.import_module(name)
    try:
        version = importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        version = "unknown"
    print(f"  - {name} {version}")
PY
