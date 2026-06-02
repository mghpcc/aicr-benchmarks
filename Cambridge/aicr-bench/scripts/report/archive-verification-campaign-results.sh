#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/report/archive-verification-campaign-results.sh --date <YYYY-MM-DD|today> [--cluster <b200|rtxpro6000>] [--public-root <path>] [--private-root <path>] [--osn-remote <remote>] [--skip-osn] [--rotate]

Creates curated public verification-campaign bundles and private VAST bundles.
Public bundles follow the module study hierarchy:

  public-study-artifacts/aicr-public/<short-git-sha>/verification/<date>/

The default OSN remote is:

  bmark:csim-bmark

Private bundles include Slurm logs. Public bundles omit Slurm logs and keep only
rendered reports, report JSON/manifest files, and archive manifests.
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

json_array_from_lines() {
  aicr_python - "$@" <<'PY'
import json
import sys

print(json.dumps(list(sys.argv[1:])))
PY
}

make_archive() {
  local archive_path="$1"
  shift
  local rels=("$@")

  (
    cd "$AICR_BMARK_DIR"
    if [[ "$compression" == "zstd" ]]; then
      tar -cf - "${rels[@]}" | zstd -q -o "$archive_path"
    else
      tar -czf "$archive_path" "${rels[@]}"
    fi
  )
}

write_sha256_sidecar() {
  local path="$1"
  local sha="$2"
  printf '%s  %s\n' "$sha" "$(basename "$path")" >"${path}.sha256"
}

date_arg=""
cluster_arg=""
public_root=""
private_root=""
osn_remote="bmark:csim-bmark"
skip_osn=0
rotate=0

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
      cluster_arg="$2"
      shift 2
      ;;
    --cluster=*)
      cluster_arg="${1#--cluster=}"
      shift
      ;;
    --public-root)
      [[ -n "${2:-}" ]] || die "--public-root requires a value"
      public_root="$2"
      shift 2
      ;;
    --public-root=*)
      public_root="${1#--public-root=}"
      shift
      ;;
    --private-root)
      [[ -n "${2:-}" ]] || die "--private-root requires a value"
      private_root="$2"
      shift 2
      ;;
    --private-root=*)
      private_root="${1#--private-root=}"
      shift
      ;;
    --osn-remote)
      [[ -n "${2:-}" ]] || die "--osn-remote requires a value"
      osn_remote="$2"
      shift 2
      ;;
    --osn-remote=*)
      osn_remote="${1#--osn-remote=}"
      shift
      ;;
    --skip-osn)
      skip_osn=1
      shift
      ;;
    --rotate)
      rotate=1
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

aicr_init_paths
aicr_require_repo_root

date_utc="$(resolve_date "$date_arg")"
created_at_utc="$(aicr_timestamp_utc)"
repo_commit="$(git -C "$AICR_BMARK_DIR" rev-parse HEAD 2>/dev/null || true)"
repo_short="$(git -C "$AICR_BMARK_DIR" rev-parse --short=7 HEAD 2>/dev/null || true)"
repo_short="${repo_short:-unknown}"
public_root="${public_root:-/work/aicr/commissioning/benchmarks/public-study-artifacts}"
private_root="${private_root:-${AICR_RESULTS_ARCHIVE_ROOT}}"
object_prefix="public-study-artifacts/aicr-public/${repo_short}/verification/${date_utc}"
publish_dir="${public_root%/}/aicr-public/${repo_short}/verification/${date_utc}"
private_dir="${private_root%/}/${date_utc}"
osn_target="${osn_remote%/}/${object_prefix}"
https_base="https://uma1.osn.mghpcc.org/csim-bmark/${object_prefix}"

clusters=()
if [[ -n "$cluster_arg" ]]; then
  aicr_assert_supported_cluster "$cluster_arg"
  clusters=("$cluster_arg")
else
  clusters=(rtxpro6000 b200)
fi

if have_cmd zstd; then
  compression="zstd"
  archive_ext="tar.zst"
else
  compression="gzip"
  archive_ext="tar.gz"
fi

mkdir -p "$publish_dir" "$private_dir"

if [[ "$rotate" == "1" && -d "$publish_dir" ]]; then
  :
fi

bundle_manifest_paths=()
for cluster in "${clusters[@]}"; do
  stem="aicr-verification-campaign-${date_utc}-${cluster}"
  public_archive="${publish_dir}/${stem}.${archive_ext}"
  private_archive="${private_dir}/${stem}-private.${archive_ext}"
  manifest_path="${publish_dir}/${stem}-manifest.json"
  private_manifest_path="${private_dir}/${stem}-private-manifest.json"

  if [[ "$rotate" != "1" ]]; then
    [[ ! -e "$public_archive" ]] || die "public archive exists: ${public_archive}; use --rotate"
    [[ ! -e "$private_archive" ]] || die "private archive exists: ${private_archive}; use --rotate"
    [[ ! -e "$manifest_path" ]] || die "manifest exists: ${manifest_path}; use --rotate"
    [[ ! -e "$private_manifest_path" ]] || die "private manifest exists: ${private_manifest_path}; use --rotate"
  else
    suffix=".prev-${created_at_utc}"
    [[ -e "$public_archive" ]] && mv "$public_archive" "${public_archive}${suffix}"
    [[ -e "$private_archive" ]] && mv "$private_archive" "${private_archive}${suffix}"
    [[ -e "$manifest_path" ]] && mv "$manifest_path" "${manifest_path}${suffix}"
    [[ -e "$private_manifest_path" ]] && mv "$private_manifest_path" "${private_manifest_path}${suffix}"
    [[ -e "${public_archive}.sha256" ]] && mv "${public_archive}.sha256" "${public_archive}.sha256${suffix}"
    [[ -e "${private_archive}.sha256" ]] && mv "${private_archive}.sha256" "${private_archive}.sha256${suffix}"
  fi

  public_source_rels=(
    "results/reports/README.md"
    "results/reports/${date_utc}/campaign-${cluster}-${date_utc}.md"
    "results/reports/${date_utc}/campaign-${cluster}-${date_utc}.json"
    "results/reports/${date_utc}/nodes-${cluster}-${date_utc}.md"
    "results/reports/${date_utc}/nodes-${cluster}-${date_utc}.json"
    "results/reports/${date_utc}/gpu-topology-${cluster}.md"
    "results/reports/${date_utc}/gds-${cluster}.md"
    "results/reports/${date_utc}/nccl-suite-${cluster}.md"
    "results/reports/${date_utc}/gpu-topology"
    "results/reports/${date_utc}/gds"
    "results/reports/${date_utc}/nccl-suite"
    "results/archives/${date_utc}/aicr-results-${date_utc}-${cluster}-verify.json"
  )
  private_source_rels=(
    "results/setup/${cluster}"
    "results/by-date/${date_utc}/raw/${cluster}"
    "results/by-date/${date_utc}/parsed/${cluster}"
    "results/by-node/${cluster}"
    "results/reports/${date_utc}"
    "results/archives/${date_utc}"
    "results/slurm"
  )

  public_existing=()
  public_missing=()
  for rel in "${public_source_rels[@]}"; do
    if [[ -e "${AICR_BMARK_DIR}/${rel}" ]]; then
      public_existing+=("$rel")
    else
      public_missing+=("$rel")
    fi
  done
  private_existing=()
  private_missing=()
  for rel in "${private_source_rels[@]}"; do
    if [[ -e "${AICR_BMARK_DIR}/${rel}" ]]; then
      private_existing+=("$rel")
    else
      private_missing+=("$rel")
    fi
  done

  [[ "${#public_existing[@]}" -gt 0 ]] || die "no public verification sources exist for ${cluster} ${date_utc}"
  [[ "${#private_existing[@]}" -gt 0 ]] || die "no private verification sources exist for ${cluster} ${date_utc}"

  echo "Creating verification campaign bundles for ${cluster}"
  echo "  public : ${public_archive}"
  echo "  private: ${private_archive}"
  make_archive "$public_archive" "${public_existing[@]}"
  make_archive "$private_archive" "${private_existing[@]}"

  public_sha="$(sha256_file "$public_archive")"
  private_sha="$(sha256_file "$private_archive")"
  public_bytes="$(wc -c <"$public_archive" | tr -d ' ')"
  private_bytes="$(wc -c <"$private_archive" | tr -d ' ')"
  write_sha256_sidecar "$public_archive" "$public_sha"
  write_sha256_sidecar "$private_archive" "$private_sha"

  public_existing_json="$(json_array_from_lines "${public_existing[@]}")"
  if [[ "${#public_missing[@]}" -gt 0 ]]; then
    public_missing_json="$(json_array_from_lines "${public_missing[@]}")"
  else
    public_missing_json="[]"
  fi
  private_existing_json="$(json_array_from_lines "${private_existing[@]}")"
  if [[ "${#private_missing[@]}" -gt 0 ]]; then
    private_missing_json="$(json_array_from_lines "${private_missing[@]}")"
  else
    private_missing_json="[]"
  fi

  aicr_python - \
    "$manifest_path" \
    "$date_utc" \
    "$cluster" \
    "$created_at_utc" \
    "$repo_commit" \
    "$repo_short" \
    "$compression" \
    "$public_archive" \
    "$public_sha" \
    "$public_bytes" \
    "${https_base}/$(basename "$public_archive")" \
    "${https_base}/$(basename "$public_archive").sha256" \
    "${https_base}/$(basename "$manifest_path")" \
    "$public_existing_json" \
    "$public_missing_json" <<'PY'
import json
import sys
from pathlib import Path

(
    manifest_path,
    date_utc,
    cluster,
    created_at_utc,
    repo_commit,
    repo_short,
    compression,
    public_archive,
    public_sha,
    public_bytes,
    osn_public_url,
    osn_checksum_url,
    osn_manifest_url,
    public_existing_json,
    public_missing_json,
) = sys.argv[1:]

obj = {
    "schema_version": 1,
    "kind": "aicr-verification-campaign-public-bundle",
    "date": date_utc,
    "cluster": cluster,
    "created_at_utc": created_at_utc,
    "repo_commit": repo_commit or None,
    "repo_short": repo_short,
    "compression": compression,
    "public": {
        "archive_path": public_archive,
        "sha256": public_sha,
        "byte_size": int(public_bytes),
        "osn_url": osn_public_url,
        "osn_checksum_url": osn_checksum_url,
        "osn_manifest_url": osn_manifest_url,
        "source_paths": json.loads(public_existing_json),
        "missing_source_paths": json.loads(public_missing_json),
        "slurm_logs_included": False,
    },
}

Path(manifest_path).write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY

  aicr_python - \
    "$private_manifest_path" \
    "$date_utc" \
    "$cluster" \
    "$created_at_utc" \
    "$repo_commit" \
    "$repo_short" \
    "$compression" \
    "$private_archive" \
    "$private_sha" \
    "$private_bytes" \
    "${https_base}/$(basename "$public_archive")" \
    "${https_base}/$(basename "$manifest_path")" \
    "$private_existing_json" \
    "$private_missing_json" <<'PY'
import json
import sys
from pathlib import Path

(
    private_manifest_path,
    date_utc,
    cluster,
    created_at_utc,
    repo_commit,
    repo_short,
    compression,
    private_archive,
    private_sha,
    private_bytes,
    osn_public_url,
    osn_manifest_url,
    private_existing_json,
    private_missing_json,
) = sys.argv[1:]

obj = {
    "schema_version": 1,
    "kind": "aicr-verification-campaign-private-bundle",
    "date": date_utc,
    "cluster": cluster,
    "created_at_utc": created_at_utc,
    "repo_commit": repo_commit or None,
    "repo_short": repo_short,
    "compression": compression,
    "private": {
        "archive_path": private_archive,
        "sha256": private_sha,
        "byte_size": int(private_bytes),
        "source_paths": json.loads(private_existing_json),
        "missing_source_paths": json.loads(private_missing_json),
        "slurm_logs_included": True,
    },
    "public_reference": {
        "osn_url": osn_public_url,
        "osn_manifest_url": osn_manifest_url,
    },
}

Path(private_manifest_path).write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY
  bundle_manifest_paths+=("$manifest_path")
done

campaign_manifest="${publish_dir}/aicr-verification-campaign-${date_utc}-manifest.json"
if [[ "$rotate" == "1" && -e "$campaign_manifest" ]]; then
  mv "$campaign_manifest" "${campaign_manifest}.prev-${created_at_utc}"
elif [[ -e "$campaign_manifest" ]]; then
  die "campaign manifest exists: ${campaign_manifest}; use --rotate"
fi

aicr_python - "$campaign_manifest" "$date_utc" "$created_at_utc" "$repo_commit" "$repo_short" "$https_base" "${bundle_manifest_paths[@]}" <<'PY'
import json
import sys
from pathlib import Path

campaign_manifest, date_utc, created_at_utc, repo_commit, repo_short, https_base, *bundle_paths = sys.argv[1:]
bundles = []
for path in bundle_paths:
    bundles.append(json.loads(Path(path).read_text(encoding="utf-8")))
obj = {
    "schema_version": 1,
    "kind": "aicr-verification-campaign",
    "date": date_utc,
    "created_at_utc": created_at_utc,
    "repo_commit": repo_commit or None,
    "repo_short": repo_short,
    "osn_base_url": https_base,
    "clusters": bundles,
}
Path(campaign_manifest).write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY

if [[ "$skip_osn" == "0" ]]; then
  have_cmd rclone || die "rclone is required unless --skip-osn is set"
  echo "Copying curated verification campaign artifacts to ${osn_target}"
  rclone copy "$publish_dir" "$osn_target"
else
  echo "Skipping OSN copy by request."
fi

echo "Wrote campaign manifest: ${campaign_manifest}"
echo "OSN base URL: ${https_base}"
