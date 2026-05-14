#!/usr/bin/env bash
set -euo pipefail

aicr_python_platform() {
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) printf 'osx-arm64\n' ;;
    Darwin-x86_64) printf 'osx-64\n' ;;
    Linux-x86_64|Linux-amd64) printf 'linux-64\n' ;;
    *) aicr_die "unsupported Python runtime platform: $(uname -s)-$(uname -m)" ;;
  esac
}

aicr_python_lock_dir() {
  printf '%s\n' "$AICR_BMARK_DIR"
}

aicr_python_lockfile_for_platform() {
  local _platform="$1"
  printf '%s/uv.lock\n' "$AICR_BMARK_DIR"
}

aicr_sha256_file() {
  local path="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    aicr_die "sha256sum or shasum is required"
  fi
}

aicr_python_env_spec_path() {
  local _platform="$1"
  local lockfile
  lockfile="$(aicr_python_lockfile_for_platform "$_platform")"
  if [[ -f "$lockfile" ]]; then
    printf '%s\n' "$lockfile"
  else
    printf '%s/pyproject.toml\n' "$AICR_BMARK_DIR"
  fi
}

aicr_python_env_spec_kind() {
  local spec_path="$1"
  case "$(basename "$spec_path")" in
    uv.lock) printf 'uv-lock\n' ;;
    *) printf 'pyproject\n' ;;
  esac
}

aicr_try_load_uv_module() {
  if [[ "${AICR_USE_UV_MODULE:-1}" != "1" ]]; then
    return 1
  fi

  local env_file="${AICR_UV_MODULE_ENV_FILE:-/apps/umass/.utilities/environment}"
  local module_name="${AICR_UV_MODULE_NAME:-uv}"
  if [[ ! -r "$env_file" ]]; then
    return 1
  fi

  if ! command -v module >/dev/null 2>&1; then
    local restore_nounset=0
    case "$-" in
      *u*) restore_nounset=1; set +u ;;
    esac
    if [[ -r /etc/profile.d/modules.sh ]]; then
      # shellcheck disable=SC1091
      source /etc/profile.d/modules.sh
    elif [[ -r /usr/share/lmod/lmod/init/bash ]]; then
      # shellcheck disable=SC1091
      source /usr/share/lmod/lmod/init/bash
    fi
    if [[ "$restore_nounset" == "1" ]]; then
      set -u
    fi
  fi

  local restore_nounset=0
  case "$-" in
    *u*) restore_nounset=1; set +u ;;
  esac
  # shellcheck disable=SC1090
  source "$env_file"
  if [[ "$restore_nounset" == "1" ]]; then
    set -u
  fi
  if ! command -v module >/dev/null 2>&1; then
    return 1
  fi
  module load "$module_name" >/dev/null
  command -v uv >/dev/null 2>&1
}

aicr_bootstrap_uv() {
  local root_prefix="$1"
  local bin_path="${root_prefix}/bin/uv"
  local installer="${root_prefix}/uv-install.sh"

  mkdir -p "${root_prefix}/bin"
  if aicr_try_load_uv_module; then
    command -v uv
    return 0
  fi
  if command -v uv >/dev/null 2>&1; then
    command -v uv
    return 0
  fi
  if [[ -x "$bin_path" ]]; then
    printf '%s\n' "$bin_path"
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -LsSf https://astral.sh/uv/install.sh -o "$installer"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$installer" https://astral.sh/uv/install.sh
  else
    aicr_die "need curl or wget to bootstrap uv"
  fi

  UV_INSTALL_DIR="${root_prefix}/bin" sh "$installer" >/dev/null
  rm -f "$installer"
  [[ -x "$bin_path" ]] || aicr_die "uv bootstrap did not create ${bin_path}"
  printf '%s\n' "$bin_path"
}

aicr_acquire_env_lock() {
  local lock_path="$1"
  local owner

  mkdir -p "$(dirname "$lock_path")"
  if [[ -f "$lock_path" ]]; then
    owner="$(cat "$lock_path" 2>/dev/null || true)"
    if [[ "$owner" =~ ^[0-9]+$ ]] && ! kill -0 "$owner" 2>/dev/null; then
      rm -f "$lock_path"
    fi
  fi

  if (set -o noclobber; printf '%s\n' "$$" >"$lock_path") 2>/dev/null; then
    AICR_HELD_ENV_LOCK_PATH="$lock_path"
    trap 'rm -f "$AICR_HELD_ENV_LOCK_PATH"' EXIT
    return 0
  fi

  owner="$(cat "$lock_path" 2>/dev/null || true)"
  aicr_die "Python environment update lock is held: ${lock_path}${owner:+ by pid ${owner}}"
}

aicr_validate_env_python() {
  local python_bin="$1"
  "$python_bin" - <<'PY'
import jsonschema
import matplotlib
import pandas
import snakemake
PY
}
