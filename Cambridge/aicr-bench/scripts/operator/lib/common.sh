#!/usr/bin/env bash
set -euo pipefail

if [[ "${AICR_OPERATOR_COMMON_LOADED:-0}" == "1" ]]; then
  return 0 2>/dev/null || exit 0
fi
AICR_OPERATOR_COMMON_LOADED=1

AICR_OPERATOR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AICR_OPERATOR_DIR="$(cd "${AICR_OPERATOR_LIB_DIR}/.." && pwd)"
AICR_OPERATOR_REPO_ROOT="$(cd "${AICR_OPERATOR_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${AICR_OPERATOR_REPO_ROOT}/scripts/lib/aicr-paths.sh"

aicr_operator_usage_error() {
  echo "ERROR: $*" >&2
  exit 2
}

aicr_operator_die() {
  echo "ERROR: $*" >&2
  exit 1
}

aicr_operator_require_repo_root() {
  [[ -d "${AICR_BMARK_DIR}" ]] || aicr_operator_die "AICR_BMARK_DIR does not exist: ${AICR_BMARK_DIR}"
  [[ -d "${AICR_BMARK_DIR}/scripts" ]] || aicr_operator_die "AICR_BMARK_DIR does not look like repo root: ${AICR_BMARK_DIR}"
  [[ -f "${AICR_BMARK_DIR}/benchmark-settings.env.example" ]] || aicr_operator_die "missing benchmark-settings.env.example under ${AICR_BMARK_DIR}"
}

aicr_operator_relpath() {
  local path="$1"
  case "$path" in
    "${AICR_BMARK_DIR}")
      printf '.\n'
      ;;
    "${AICR_BMARK_DIR}"/*)
      printf '%s\n' "${path#"${AICR_BMARK_DIR}/"}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

aicr_operator_resolve_date() {
  local date_value="$1"

  case "$date_value" in
    today)
      date -u +%Y-%m-%d
      ;;
    yesterday)
      aicr_python - <<'PY'
from datetime import datetime, timedelta, timezone

print((datetime.now(timezone.utc).date() - timedelta(days=1)).isoformat())
PY
      ;;
    *)
      if ! [[ "$date_value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        aicr_operator_usage_error "--date must be YYYY-MM-DD, today, or yesterday: ${date_value}"
      fi
      printf '%s\n' "$date_value"
      ;;
  esac
}

aicr_operator_require_cluster() {
  case "$1" in
    b200|rtxpro6000) ;;
    *) aicr_operator_usage_error "--cluster must be one of: b200, rtxpro6000" ;;
  esac
}

aicr_operator_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

aicr_operator_sha256_file() {
  local path="$1"
  if aicr_operator_have_cmd sha256sum; then
    sha256sum "$path" | awk '{print $1}'
  elif aicr_operator_have_cmd shasum; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    aicr_operator_die "sha256sum or shasum is required"
  fi
}

aicr_operator_archive_list_members() {
  local archive_path="$1"

  case "$archive_path" in
    *.tar.zst)
      aicr_operator_have_cmd zstd || aicr_operator_die "zstd is required to inspect .tar.zst archives: ${archive_path}"
      zstd -dc "$archive_path" | tar -tf -
      ;;
    *.tar.gz|*.tgz)
      tar -tzf "$archive_path"
      ;;
    *)
      aicr_operator_die "unsupported archive format: ${archive_path}"
      ;;
  esac
}

aicr_operator_archive_extract_members() {
  local archive_path="$1"
  local dest_path="$2"
  shift 2

  mkdir -p "$dest_path"

  case "$archive_path" in
    *.tar.zst)
      aicr_operator_have_cmd zstd || aicr_operator_die "zstd is required to extract .tar.zst archives: ${archive_path}"
      if [[ "$#" -gt 0 ]]; then
        zstd -dc "$archive_path" | tar -xf - -C "$dest_path" "$@"
      else
        zstd -dc "$archive_path" | tar -xf - -C "$dest_path"
      fi
      ;;
    *.tar.gz|*.tgz)
      if [[ "$#" -gt 0 ]]; then
        tar -xzf "$archive_path" -C "$dest_path" "$@"
      else
        tar -xzf "$archive_path" -C "$dest_path"
      fi
      ;;
    *)
      aicr_operator_die "unsupported archive format: ${archive_path}"
      ;;
  esac
}

aicr_operator_join_csv() {
  local out=""
  local item
  for item in "$@"; do
    if [[ -z "$out" ]]; then
      out="$item"
    else
      out="${out}, ${item}"
    fi
  done
  printf '%s\n' "$out"
}
