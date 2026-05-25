#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib/aicr-paths.sh"

usage() {
  cat >&2 <<EOF
Usage: $0 [--refresh] [--image-dir <path>] [--include-elbencho]

Options:
  --refresh          Re-pull and replace existing verified SIF images.
  --image-dir        Override AICR_APPTAINER_IMAGE_DIR for explicit runtime rebuilds.
  --include-elbencho Pull the optional elbencho image.

Note:
  Routine AICR HPC setup submits this helper through Slurm:
    make install-containers

  Direct shell use is reserved for local debugging and runtime rebuild workflows.
EOF
}

refresh=0
image_dir_override=""
include_elbencho="${AICR_INSTALL_ELBENCHO_CONTAINER:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --refresh)
      refresh=1
      shift
      ;;
    --image-dir)
      image_dir_override="${2:-}"
      shift 2
      ;;
    --include-elbencho)
      include_elbencho=1
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

if [[ -n "$image_dir_override" ]]; then
  AICR_APPTAINER_IMAGE_DIR="$image_dir_override"
  AICR_ELBENCHO_IMAGE="${AICR_APPTAINER_IMAGE_DIR}/elbencho-${AICR_ELBENCHO_TAG}.sif"
  export AICR_APPTAINER_IMAGE_DIR
  export AICR_ELBENCHO_IMAGE
fi

aicr_mkdirs
mkdir -p "${AICR_APPTAINER_IMAGE_DIR}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

pull_image() {
  local src="$1"
  local dest="$2"

  if [[ -s "$dest" && "$refresh" == "0" ]]; then
    echo "Using existing ${dest}"
    echo "  source: ${src}"
    echo "  pass --refresh to replace it"
    return 0
  fi

  echo "Pulling ${src}"
  echo "  -> ${dest}"
  mkdir -p "${AICR_TMP_DIR}/apptainer-tmp" "${AICR_TMP_DIR}/apptainer-cache"
  APPTAINER_TMPDIR="${AICR_TMP_DIR}/apptainer-tmp" \
  APPTAINER_CACHEDIR="${AICR_TMP_DIR}/apptainer-cache" \
    apptainer pull --force "${dest}" "${src}"
}

print_smoke_test_next_step() {
  local cluster_name="$1"
  echo
  echo "Canonical Apptainer image directory: ${AICR_APPTAINER_IMAGE_DIR}"
  echo "Next step:"
  echo "  4. Submit smoke tests from repo root so benchmark-settings.env resolves via SLURM_SUBMIT_DIR:"
  if [[ "$cluster_name" == "$AICR_CLUSTER_B200" || "$cluster_name" == "$AICR_CLUSTER_RTXPRO6000" ]]; then
    echo "     sbatch slurm/verify/${cluster_name}-pytorch-smoke.sbatch"
    echo "     sbatch slurm/verify/${cluster_name}-hpc-benchmarks-smoke.sbatch"
    if [[ "$include_elbencho" == "1" ]]; then
      echo "     sbatch slurm/verify/${cluster_name}-elbencho-smoke.sbatch"
    fi
  else
    echo "     sbatch slurm/verify/<cluster>-pytorch-smoke.sbatch"
    echo "     sbatch slurm/verify/<cluster>-hpc-benchmarks-smoke.sbatch"
    if [[ "$include_elbencho" == "1" ]]; then
      echo "     sbatch slurm/verify/<cluster>-elbencho-smoke.sbatch"
    fi
    echo "  Set AICR_CLUSTER_NAME in benchmark-settings.env to b200 or rtxpro6000 if cluster detection is not available yet."
  fi
}

require_cmd apptainer

PYTORCH_PRIMARY_URI="${PYTORCH_PRIMARY_URI:-docker://nvcr.io/nvidia/pytorch:25.10-py3}"
PYTORCH_PROBE_URI="${PYTORCH_PROBE_URI:-docker://nvcr.io/nvidia/pytorch:26.03-py3}"
HPC_BENCH_URI="${HPC_BENCH_URI:-docker://nvcr.io/nvidia/hpc-benchmarks:26.02}"
ELBENCHO_URI="${ELBENCHO_URI:-docker://breuner/elbencho:${AICR_ELBENCHO_TAG}}"

pull_image "${PYTORCH_PRIMARY_URI}" "${AICR_APPTAINER_IMAGE_DIR}/pytorch-25.10-py3.sif"
pull_image "${HPC_BENCH_URI}" "${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif"

if [[ "$include_elbencho" == "1" ]]; then
  pull_image "${ELBENCHO_URI}" "${AICR_ELBENCHO_IMAGE}"
else
  echo
  echo "AICR_INSTALL_ELBENCHO_CONTAINER=0 -> skipping optional elbencho image pull"
fi

if [[ "${ENABLE_PYTORCH_PROBE:-0}" == "1" ]]; then
  echo
  echo "ENABLE_PYTORCH_PROBE=1 -> pulling optional PyTorch probe image"
  pull_image "${PYTORCH_PROBE_URI}" "${AICR_APPTAINER_IMAGE_DIR}/pytorch-26.03-py3.sif"
else
  echo
  echo "ENABLE_PYTORCH_PROBE=0 -> skipping optional PyTorch probe image pull"
fi

echo
echo "Pulled images:"
ls -lh   "${AICR_APPTAINER_IMAGE_DIR}/pytorch-25.10-py3.sif"   "${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif"
if [[ "$include_elbencho" == "1" ]]; then
  ls -lh "${AICR_ELBENCHO_IMAGE}"
fi

if [[ -f "${AICR_APPTAINER_IMAGE_DIR}/pytorch-26.03-py3.sif" ]]; then
  ls -lh "${AICR_APPTAINER_IMAGE_DIR}/pytorch-26.03-py3.sif"
fi

cluster_name="${AICR_CLUSTER_NAME:-$(aicr_cluster_name || true)}"
print_smoke_test_next_step "$cluster_name"
