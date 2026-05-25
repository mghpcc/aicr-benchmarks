#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/install-elbencho-runtime.sh [--method container|static] [--tag <tag>] [--image <path>] [--apply]

Installs or checks the Elbencho runtime under the shared AICR Apptainer/runtime
layout. Default method is the upstream Docker image converted to Apptainer SIF.
Static binary install is documented as a CPU/filesystem fallback and is not used
for GPU/GDS-capable campaign runs.
EOF
}

aicr_require_repo_root

method="container"
tag="${ELBENCHO_TAG:-${AICR_ELBENCHO_TAG}}"
image="${ELBENCHO_IMAGE:-${AICR_ELBENCHO_IMAGE}}"
apply=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --method) method="${2:-}"; shift 2 ;;
    --tag) tag="${2:-}"; shift 2 ;;
    --image) image="${2:-}"; shift 2 ;;
    --apply) apply=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) aicr_die "unknown argument: $1" ;;
  esac
done

case "$method" in container|static) ;; *) aicr_die "--method must be container or static" ;; esac

if [[ "$method" == "static" ]]; then
  cat <<EOF
Elbencho static fallback
  Release     : v3.1-1
  Asset       : https://github.com/breuner/elbencho/releases/download/v3.1-1/elbencho-static-x86_64.tar.gz
  Destination : ${AICR_RUNTIME_ROOT}/tools/elbencho/v3.1-1
  Note        : upstream static binaries do not include GPU support; prefer the container method for campaign work.
EOF
  if [[ "$apply" -eq 1 ]]; then
    aicr_die "static install is intentionally documented-only in this helper; use method=container for the supported runtime path"
  fi
  exit 0
fi

image="${image:-${AICR_APPTAINER_IMAGE_DIR}/elbencho-${tag}.sif}"
source_ref="docker://breuner/elbencho:${tag}"

echo "Elbencho Apptainer runtime"
echo "  Source      : ${source_ref}"
echo "  Image       : ${image}"
echo "  Scratch     : ${AICR_TMP_DIR}/apptainer-tmp"
echo "  Cache       : ${AICR_TMP_DIR}/apptainer-cache"
echo "  Apptainer   : $(command -v apptainer 2>/dev/null || printf 'not found')"

if [[ "$apply" -eq 0 ]]; then
  echo "Dry run. Command that would be run:"
  printf '  '
  printf '%q ' env "APPTAINER_TMPDIR=${AICR_TMP_DIR}/apptainer-tmp" "APPTAINER_CACHEDIR=${AICR_TMP_DIR}/apptainer-cache" apptainer pull "$image" "$source_ref"
  echo
  echo "After install, verify with:"
  printf '  '
  printf '%q ' apptainer exec ${AICR_APPTAINER_COMMON_OPTS} --nv "$image" elbencho --help
  echo
  exit 0
fi

command -v apptainer >/dev/null 2>&1 || aicr_die "apptainer not found"
mkdir -p "$(dirname "$image")"
mkdir -p "${AICR_TMP_DIR}/apptainer-tmp" "${AICR_TMP_DIR}/apptainer-cache"
APPTAINER_TMPDIR="${AICR_TMP_DIR}/apptainer-tmp" \
APPTAINER_CACHEDIR="${AICR_TMP_DIR}/apptainer-cache" \
  apptainer pull --force "$image" "$source_ref"
apptainer exec ${AICR_APPTAINER_COMMON_OPTS} --nv "$image" elbencho --help >/dev/null
echo "Installed and verified ${image}"
