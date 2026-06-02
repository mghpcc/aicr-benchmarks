#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/report/archive-benchmark-study-results.sh --date <YYYY-MM-DD|today> --cluster b200 [--archive-root <path>] [--rotate]

Archives benchmark-study evidence after an experiment campaign, not as part of system verification.
EOF
}

die() { echo "ERROR: $*" >&2; exit 1; }
have_cmd() { command -v "$1" >/dev/null 2>&1; }
sha256_file() {
  if have_cmd sha256sum; then sha256sum "$1" | awk '{print $1}'
  elif have_cmd shasum; then shasum -a 256 "$1" | awk '{print $1}'
  else die "sha256sum or shasum is required"
  fi
}
resolve_date() {
  case "$1" in
    today) date -u +%Y-%m-%d ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) printf '%s\n' "$1" ;;
    *) die "--date must be YYYY-MM-DD or today" ;;
  esac
}
json_array_from_lines() {
  aicr_python - "$@" <<'PY'
import json, sys
print(json.dumps(list(sys.argv[1:])))
PY
}

date_arg=""
cluster=""
archive_root=""
rotate=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --date) date_arg="${2:-}"; shift 2 ;;
    --cluster) cluster="${2:-}"; shift 2 ;;
    --archive-root) archive_root="${2:-}"; shift 2 ;;
    --rotate) rotate=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done

[[ -n "$date_arg" && -n "$cluster" ]] || { usage; exit 2; }
[[ "$cluster" == "b200" ]] || die "benchmark-study archive currently supports --cluster b200 only"

aicr_init_paths
aicr_require_repo_root
archive_root="${archive_root:-${AICR_RESULTS_ARCHIVE_ROOT}}"
date_utc="$(resolve_date "$date_arg")"
created_at_utc="$(aicr_timestamp_utc)"
archive_dir="${archive_root%/}/${date_utc}"
manifest_rel="results/archives/${date_utc}/aicr-results-${date_utc}-${cluster}-benchmark-study.json"
manifest_abs="${AICR_BMARK_DIR}/${manifest_rel}"
archive_stem="aicr-results-${date_utc}-${cluster}-benchmark-study"

source_rels=(
  "results/by-date/${date_utc}/raw/${cluster}/nodes"
  "results/by-date/${date_utc}/parsed/${cluster}/nodes"
  "results/by-date/${date_utc}/raw/${cluster}/multi-node/dataloader"
  "results/by-date/${date_utc}/parsed/${cluster}/multi-node/dataloader"
  "results/by-date/${date_utc}/raw/${cluster}/multi-node/ddp-resnet50"
  "results/by-date/${date_utc}/parsed/${cluster}/multi-node/ddp-resnet50"
  "results/reports/${date_utc}/dataloader"
  "results/reports/${date_utc}/ddp"
)

existing_rels=()
missing_rels=()
for rel in "${source_rels[@]}"; do
  if [[ -e "${AICR_BMARK_DIR}/${rel}" ]]; then existing_rels+=("$rel"); else missing_rels+=("$rel"); fi
done
[[ "${#existing_rels[@]}" -gt 0 ]] || die "no benchmark-study source paths exist for date=${date_utc}"

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

if [[ -e "$archive_path" || -e "$manifest_abs" ]]; then
  if [[ "$rotate" != "1" ]]; then
    die "archive or manifest already exists; re-run with --rotate"
  fi
  suffix=".prev-$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  [[ -e "$archive_path" ]] && mv "$archive_path" "${archive_path}${suffix}"
  [[ -e "$manifest_abs" ]] && mv "$manifest_abs" "${manifest_abs}${suffix}"
fi

echo "Archiving B200 benchmark-study results"
echo "Date         : ${date_utc}"
echo "Cluster      : ${cluster}"
echo "Archive path : ${archive_path}"
echo "Compression  : ${compression}"
echo "Sources:"
printf '  %s\n' "${existing_rels[@]}"

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
repo_dirty="$(git -C "$AICR_BMARK_DIR" status --short 2>/dev/null | sed '/^?? results\/archives\//d' | sed -n '1p')"
existing_json="$(json_array_from_lines "${existing_rels[@]}")"
missing_json="$(json_array_from_lines "${missing_rels[@]}")"

aicr_python - "$manifest_abs" "$date_utc" "$cluster" "$created_at_utc" "$archive_path" "$compression" "$sha256" "$byte_size" "$repo_commit" "$repo_dirty" "$existing_json" "$missing_json" <<'PY'
import json, sys
from pathlib import Path
manifest_abs, date_utc, cluster, created_at_utc, archive_path, compression, sha256, byte_size, repo_commit, repo_dirty, existing_json, missing_json = sys.argv[1:]
obj = {
    "schema_version": 1,
    "kind": "aicr-results-archive",
    "date": date_utc,
    "cluster": cluster,
    "scope": "benchmark-study",
    "created_at_utc": created_at_utc,
    "archive_path": archive_path,
    "compression": compression,
    "sha256": sha256,
    "byte_size": int(byte_size),
    "repo_commit": repo_commit or None,
    "repo_dirty": bool(repo_dirty.strip()),
    "source_paths": json.loads(existing_json),
    "missing_source_paths": json.loads(missing_json),
}
Path(manifest_abs).write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY

echo "Wrote archive: ${archive_path}"
echo "Wrote manifest: ${manifest_rel}"
