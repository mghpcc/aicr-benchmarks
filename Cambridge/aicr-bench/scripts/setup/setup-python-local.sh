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
  scripts/setup/setup-python-local.sh [--force] [--runtime <repo-local|configured>]

Build or refresh the repo-local Python virtual environment from uv.lock when
available, otherwise from pyproject.toml. This helper is for laptop and local
development by default; it does not edit benchmark-settings.env.

Use --runtime configured for Slurm/runtime bootstrap jobs that should build the
configured AICR_UV_ROOT and AICR_UV_ENV_PREFIX instead of the repo-local .tools
fallback.
EOF
}

force=0
runtime_target="repo-local"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=1
      shift
      ;;
    --runtime)
      runtime_target="${2:-}"
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

aicr_require_repo_root
case "$runtime_target" in
  repo-local|configured) ;;
  *) aicr_die "--runtime must be repo-local or configured" ;;
esac

platform="$(aicr_python_platform)"
if [[ "$runtime_target" == "configured" ]]; then
  local_uv_root="$AICR_UV_ROOT"
  local_envs_dir="$AICR_UV_ENVS_DIR"
  local_env_prefix="$AICR_UV_ENV_PREFIX"
  lock_path="${AICR_UV_ENVS_DIR}/.aicr-python-env.lock"
  runtime_label="configured"
else
  local_uv_root="$(aicr_repo_local_runtime_root_prefix)"
  local_envs_dir="$(aicr_repo_local_uv_envs_dir)"
  local_env_prefix="$(aicr_repo_local_env_prefix)"
  lock_path="${AICR_BMARK_DIR}/.tools/.aicr-python-env.lock"
  runtime_label="repo-local"
fi
spec_path="$(aicr_python_env_spec_path "$platform")"
spec_kind="$(aicr_python_env_spec_kind "$spec_path")"
spec_sha="$(aicr_sha256_file "$spec_path")"
manifest_path="${local_env_prefix}/.aicr-python-env"

aicr_acquire_env_lock "$lock_path"
mkdir -p "$local_envs_dir"
uv_bin="$(aicr_bootstrap_uv "$local_uv_root")"

if [[ "$force" -eq 0 && -f "$manifest_path" && -x "${local_env_prefix}/bin/python" ]]; then
  current_platform="$(awk -F= '$1 == "platform" {print $2}' "$manifest_path" 2>/dev/null || true)"
  current_spec_sha="$(awk -F= '$1 == "spec_sha256" {print $2}' "$manifest_path" 2>/dev/null || true)"
  if [[ "$current_platform" == "$platform" && "$current_spec_sha" == "$spec_sha" ]]; then
    if aicr_validate_env_python "${local_env_prefix}/bin/python"; then
      echo "${runtime_label} Python environment is ready."
      echo "Platform : ${platform}"
      echo "Env      : ${local_env_prefix}"
      echo "Spec     : ${spec_path}"
      exit 0
    fi
  fi
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
tmp_prefix="${local_envs_dir}/.aicr-bench-build-${timestamp}-$$"
backup_prefix="${local_env_prefix}.previous-${timestamp}"

rm -rf "$tmp_prefix"
echo "Building ${runtime_label} Python environment"
echo "Platform : ${platform}"
echo "Env      : ${local_env_prefix}"
echo "Spec     : ${spec_path} (${spec_kind})"
UV_LINK_MODE="${UV_LINK_MODE:-copy}" "$uv_bin" venv --python 3.11 "$tmp_prefix"
if [[ "$spec_kind" == "uv-lock" ]]; then
  (cd "$AICR_BMARK_DIR" && UV_PROJECT_ENVIRONMENT="$tmp_prefix" UV_LINK_MODE="${UV_LINK_MODE:-copy}" "$uv_bin" sync --frozen --python "${tmp_prefix}/bin/python")
else
  (cd "$AICR_BMARK_DIR" && UV_PROJECT_ENVIRONMENT="$tmp_prefix" UV_LINK_MODE="${UV_LINK_MODE:-copy}" "$uv_bin" sync --python "${tmp_prefix}/bin/python")
fi

aicr_validate_env_python "${tmp_prefix}/bin/python"
cat >"${tmp_prefix}/.aicr-python-env" <<EOF
platform=${platform}
spec_path=${spec_path}
spec_kind=${spec_kind}
spec_sha256=${spec_sha}
created_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

if [[ -e "$backup_prefix" ]]; then
  rm -rf "$backup_prefix"
fi
if [[ -e "$local_env_prefix" ]]; then
  mv "$local_env_prefix" "$backup_prefix"
fi
if mv "$tmp_prefix" "$local_env_prefix"; then
  rm -rf "$backup_prefix"
else
  if [[ -e "$backup_prefix" ]]; then
    mv "$backup_prefix" "$local_env_prefix"
  fi
  exit 1
fi

echo "${runtime_label} Python environment is ready."
echo "Python   : ${local_env_prefix}/bin/python"
