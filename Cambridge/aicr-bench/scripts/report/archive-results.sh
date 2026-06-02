#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/report/archive-results.sh --date <YYYY-MM-DD|today> --cluster <b200|rtxpro6000> [--archive-root <path>] [--rotate]

Archives the full verification evidence set for one date to VAST and writes a small
Git-trackable checksum manifest under results/archives/<date>/.

Default archive root from AICR_RESULTS_ARCHIVE_ROOT:
  /work/aicr/commissioning/benchmarks/results-archive

If the target archive or manifest already exists, the default behavior is to fail.
Use --rotate to rename existing outputs to .prev-<UTC> before creating a new archive:
  scripts/report/archive-results.sh --date <YYYY-MM-DD|today> --cluster b200 --rotate
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

sha256_file() {
  local path="$1"
  if have_cmd sha256sum; then
    sha256sum "$path" | awk '{print $1}'
  elif have_cmd shasum; then
    shasum -a 256 "$path" | awk '{print $1}'
  else
    die "sha256sum or shasum is required"
  fi
}

resolve_date() {
  case "$1" in
    today)
      date -u +%Y-%m-%d
      ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      printf '%s\n' "$1"
      ;;
    *)
      die "--date must be YYYY-MM-DD or today"
      ;;
  esac
}

relpath() {
  local path="$1"
  case "$path" in
    "${AICR_BMARK_DIR}/"*) printf '%s\n' "${path#"${AICR_BMARK_DIR}/"}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

json_array_from_lines() {
  aicr_python - "$@" <<'PY'
import json
import sys

print(json.dumps(list(sys.argv[1:])))
PY
}

rotate_existing_path() {
  local path="$1"
  local rotated_path="$2"

  [[ -e "$path" ]] || return 0
  [[ ! -e "$rotated_path" ]] || die "rotation target already exists: ${rotated_path}"
  mv "$path" "$rotated_path"
}

date_arg=""
cluster=""
archive_root=""
rotate_existing=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --date)
      [[ -n "${2:-}" ]] || die "--date requires a value"
      date_arg="$2"
      shift 2
      ;;
    --date=*)
      date_arg="${1#--date=}"
      shift
      ;;
    --cluster)
      [[ -n "${2:-}" ]] || die "--cluster requires a value"
      cluster="$2"
      shift 2
      ;;
    --cluster=*)
      cluster="${1#--cluster=}"
      shift
      ;;
    --archive-root)
      [[ -n "${2:-}" ]] || die "--archive-root requires a value"
      archive_root="$2"
      shift 2
      ;;
    --archive-root=*)
      archive_root="${1#--archive-root=}"
      shift
      ;;
    --rotate)
      rotate_existing=1
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

[[ -n "$date_arg" ]] || {
  usage
  exit 2
}
[[ -n "$cluster" ]] || {
  usage
  exit 2
}

aicr_init_paths
aicr_require_repo_root
aicr_assert_supported_cluster "$cluster"
archive_root="${archive_root:-${AICR_RESULTS_ARCHIVE_ROOT}}"

date_utc="$(resolve_date "$date_arg")"
created_at_utc="$(aicr_timestamp_utc)"
archive_dir="${archive_root%/}/${date_utc}"
manifest_rel="results/archives/${date_utc}/aicr-results-${date_utc}-${cluster}-verify.json"
manifest_abs="${AICR_BMARK_DIR}/${manifest_rel}"
archive_stem="aicr-results-${date_utc}-${cluster}-verify"
rotate_suffix=".prev-${created_at_utc}"

source_rels=(
  "results/setup/${cluster}"
  "results/by-date/${date_utc}"
  "results/by-node/${cluster}"
  "results/reports/${date_utc}"
)

existing_rels=()
missing_rels=()
for rel in "${source_rels[@]}"; do
  if [[ -e "${AICR_BMARK_DIR}/${rel}" ]]; then
    existing_rels+=("$rel")
  else
    missing_rels+=("$rel")
  fi
done

if [[ "${#existing_rels[@]}" -eq 0 ]]; then
  die "no archive source paths exist for date=${date_utc} cluster=${cluster}"
fi

if [[ ! -d "${AICR_BMARK_DIR}/results/by-date/${date_utc}" && ! -d "${AICR_BMARK_DIR}/results/reports/${date_utc}" ]]; then
  die "no date-specific results found for date=${date_utc}"
fi

mkdir -p "$archive_dir" "$(dirname "$manifest_abs")"

compression=""
archive_path=""
if have_cmd zstd; then
  compression="zstd"
  archive_path="${archive_dir}/${archive_stem}.tar.zst"
else
  compression="gzip"
  archive_path="${archive_dir}/${archive_stem}.tar.gz"
fi

if [[ -e "$archive_path" ]]; then
  if [[ "$rotate_existing" == "1" ]]; then
    rotate_existing_path "$archive_path" "${archive_path}${rotate_suffix}"
  else
    die "archive already exists: ${archive_path}
Re-run with:
  scripts/report/archive-results.sh --date ${date_arg} --cluster ${cluster} --rotate"
  fi
fi

if [[ -e "$manifest_abs" ]]; then
  if [[ "$rotate_existing" == "1" ]]; then
    rotate_existing_path "$manifest_abs" "${manifest_abs}${rotate_suffix}"
  else
    die "manifest already exists: ${manifest_abs}
Re-run with:
  scripts/report/archive-results.sh --date ${date_arg} --cluster ${cluster} --rotate"
  fi
fi

echo "Archiving ${cluster} results"
echo "Date         : ${date_utc}"
echo "Cluster      : ${cluster}"
echo "Archive path : ${archive_path}"
echo "Compression  : ${compression}"
if [[ "$rotate_existing" == "1" ]]; then
  echo "Rotate mode  : enabled (${rotate_suffix})"
fi
echo "Sources:"
printf '  %s\n' "${existing_rels[@]}"
if [[ "${#missing_rels[@]}" -gt 0 ]]; then
  echo "Missing optional sources:"
  printf '  %s\n' "${missing_rels[@]}"
fi
echo

(
  cd "$AICR_BMARK_DIR"
  if [[ "$compression" == "zstd" ]]; then
    tar -cf - "${existing_rels[@]}" | zstd -q -o "$archive_path"
  else
    tar -czf "$archive_path" "${existing_rels[@]}"
  fi
)

sha256="$(sha256_file "$archive_path")"
byte_size="$(wc -c <"$archive_path" | tr -d ' ')"
repo_commit="$(git -C "$AICR_BMARK_DIR" rev-parse HEAD 2>/dev/null || true)"
repo_status="$(git -C "$AICR_BMARK_DIR" status --short 2>/dev/null || true)"
repo_dirty="$(printf '%s\n' "$repo_status" | sed '/^?? results\/archives\//d' | sed '/^?? docs\/plan\/results-storage.md/d' | sed '/^ M \.gitignore/d' | sed '/^?? scripts\/report\/archive-results.sh/d' | sed -n '1p')"
if [[ -n "$repo_dirty" ]]; then
  repo_dirty="true"
else
  repo_dirty="false"
fi

existing_json="$(json_array_from_lines "${existing_rels[@]}")"
if [[ "${#missing_rels[@]}" -gt 0 ]]; then
  missing_json="$(json_array_from_lines "${missing_rels[@]}")"
else
  missing_json="[]"
fi

aicr_python - \
  "$manifest_abs" \
  "$date_utc" \
  "$cluster" \
  "$created_at_utc" \
  "$archive_path" \
  "$(relpath "$archive_path")" \
  "$compression" \
  "$sha256" \
  "$byte_size" \
  "$repo_commit" \
  "$repo_dirty" \
  "$existing_json" \
  "$missing_json" <<'PY'
import json
import sys
from pathlib import Path

(
    manifest_abs,
    date_utc,
    cluster,
    created_at_utc,
    archive_path,
    archive_relpath,
    compression,
    sha256,
    byte_size,
    repo_commit,
    repo_dirty,
    existing_json,
    missing_json,
) = sys.argv[1:]

obj = {
    "schema_version": 1,
    "kind": "aicr-results-archive",
    "date": date_utc,
    "cluster": cluster,
    "scope": "verify",
    "created_at_utc": created_at_utc,
    "archive_path": archive_path,
    "archive_relpath": archive_relpath,
    "compression": compression,
    "sha256": sha256,
    "byte_size": int(byte_size),
    "repo_commit": repo_commit or None,
    "repo_dirty": repo_dirty == "true",
    "source_paths": json.loads(existing_json),
    "missing_source_paths": json.loads(missing_json),
}

path = Path(manifest_abs)
path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY

echo "Wrote archive: ${archive_path}"
echo "Wrote manifest: ${manifest_rel}"
