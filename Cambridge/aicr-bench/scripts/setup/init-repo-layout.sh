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
  scripts/setup/init-repo-layout.sh [--repo-local-runtime]

Default behavior creates repo-local results/scratch layout and canonical shared
runtime settings. It does not build uv Python environments or pull containers.

Options:
  --repo-local-runtime  Development-only escape hatch that preserves the old
                        repo-local .tools and apptainer/images runtime layout.
EOF
}

repo_local_runtime=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-local-runtime)
      repo_local_runtime=1
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

settings_file="${AICR_BMARK_DIR}/benchmark-settings.env"

canonical_runtime_block() {
  cat <<'EOF'
AICR_RUNTIME_ROOT="/work/aicr/commissioning/benchmarks/runtime"
AICR_APPTAINER_IMAGE_DIR="${AICR_RUNTIME_ROOT}/apptainer/images"
AICR_ELBENCHO_TAG="master-ubuntu-cuda-multiarch"
AICR_ELBENCHO_IMAGE="${AICR_APPTAINER_IMAGE_DIR}/elbencho-${AICR_ELBENCHO_TAG}.sif"
AICR_TOOLS_DIR="${AICR_BMARK_DIR}/.tools"
AICR_UV_ROOT="${AICR_RUNTIME_ROOT}/uv"
AICR_UV_ENVS_DIR="${AICR_RUNTIME_ROOT}/uv-envs"
AICR_UV_ENV_PREFIX="${AICR_UV_ENVS_DIR}/aicr-bench"
AICR_UV_BIN="${AICR_UV_ROOT}/bin/uv"
EOF
}

repo_local_runtime_block() {
  cat <<'EOF'
AICR_RUNTIME_ROOT="${AICR_BMARK_DIR}/.tools/runtime"
AICR_APPTAINER_IMAGE_DIR="${AICR_BMARK_DIR}/apptainer/images"
AICR_ELBENCHO_TAG="master-ubuntu-cuda-multiarch"
AICR_ELBENCHO_IMAGE="${AICR_APPTAINER_IMAGE_DIR}/elbencho-${AICR_ELBENCHO_TAG}.sif"
AICR_TOOLS_DIR="${AICR_BMARK_DIR}/.tools"
AICR_UV_ROOT="${AICR_TOOLS_DIR}/uv"
AICR_UV_ENVS_DIR="${AICR_TOOLS_DIR}/uv-envs"
AICR_UV_ENV_PREFIX="${AICR_UV_ENVS_DIR}/aicr-bench"
AICR_UV_BIN="${AICR_UV_ROOT}/bin/uv"
EOF
}

settings_runtime_is_repo_local() {
  [[ "${AICR_APPTAINER_IMAGE_DIR}" == "$(aicr_repo_local_apptainer_image_dir)" ]] ||
    [[ "${AICR_UV_ROOT}" == "$(aicr_repo_local_runtime_root_prefix)" ]] ||
    [[ "${AICR_UV_ENVS_DIR}" == "$(aicr_repo_local_uv_envs_dir)" ]] ||
    [[ "${AICR_UV_ENV_PREFIX}" == "$(aicr_repo_local_uv_envs_dir)/aicr-bench" ]]
}

rewrite_runtime_settings() {
  local mode="$1"
  local backup tmp

  backup="${settings_file}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  tmp="$(mktemp)"
  cp "$settings_file" "$backup"

  awk '
    !/^(AICR_RUNTIME_ROOT|AICR_APPTAINER_IMAGE_DIR|AICR_ELBENCHO_TAG|AICR_ELBENCHO_IMAGE|AICR_TOOLS_DIR|AICR_UV_ROOT|AICR_UV_ENVS_DIR|AICR_UV_ENV_PREFIX|AICR_UV_BIN)=/
  ' "$backup" >"$tmp"
  {
    printf '\n# Runtime asset paths managed by scripts/setup/init-repo-layout.sh (%s).\n' "$mode"
    if [[ "$mode" == "repo-local" ]]; then
      repo_local_runtime_block
    else
      canonical_runtime_block
    fi
  } >>"$tmp"
  mv "$tmp" "$settings_file"

  echo "WARNING: updated runtime path settings in benchmark-settings.env"
  echo "WARNING: backup saved at ${backup}"
}

bootstrap_repo_local_uv() {
  mkdir -p "${AICR_UV_ROOT}/bin" "${AICR_UV_ENVS_DIR}" "${AICR_APPTAINER_IMAGE_DIR}"

  if [[ ! -x "${AICR_UV_BIN}" ]]; then
    aicr_bootstrap_uv "${AICR_UV_ROOT}" >/dev/null
  fi

  if [[ ! -f "${AICR_UV_ENV_PREFIX}/pyvenv.cfg" ]]; then
    "${AICR_UV_BIN}" venv --python 3.11 "${AICR_UV_ENV_PREFIX}"
    if [[ -f "${AICR_BMARK_DIR}/uv.lock" ]]; then
      (cd "$AICR_BMARK_DIR" && VIRTUAL_ENV="${AICR_UV_ENV_PREFIX}" "${AICR_UV_BIN}" sync --frozen --active)
    else
      (cd "$AICR_BMARK_DIR" && VIRTUAL_ENV="${AICR_UV_ENV_PREFIX}" "${AICR_UV_BIN}" sync --active)
    fi
  fi
  aicr_validate_env_python "${AICR_UV_ENV_PREFIX}/bin/python"
}

aicr_require_repo_root
aicr_mkdirs
mkdir -p \
  "${AICR_RESULTS_DIR}/slurm" \
  "${AICR_RESULTS_SETUP_DIR}/${AICR_CLUSTER_B200}" \
  "${AICR_RESULTS_SETUP_DIR}/${AICR_CLUSTER_RTXPRO6000}"

if [[ ! -f "$settings_file" ]]; then
  cp "${AICR_BMARK_DIR}/benchmark-settings.env.example" "$settings_file"
  echo "WARNING: created benchmark-settings.env from benchmark-settings.env.example"
  echo "WARNING: review and edit benchmark-settings.env before proceeding"
fi

# Reload settings after creating the file.
aicr_init_paths

if [[ "$repo_local_runtime" == "1" ]]; then
  if ! settings_runtime_is_repo_local; then
    rewrite_runtime_settings "repo-local"
    aicr_init_paths
  fi

  echo "WARNING: using repo-local runtime assets for development only"
  bootstrap_repo_local_uv
else
  if settings_runtime_is_repo_local; then
    rewrite_runtime_settings "canonical"
    aicr_init_paths
  fi

  if ! aicr_validate_runtime_assets; then
    echo
    echo "Repository layout is ready, but canonical runtime assets are missing or incomplete."
    echo "The init helper did not build runtime assets on this node."
    exit 0
  fi
fi

cat <<EOF
Repository layout is ready.

Runtime:
  AICR_RUNTIME_ROOT=${AICR_RUNTIME_ROOT}
  AICR_UV_ENV_PREFIX=${AICR_UV_ENV_PREFIX}
  AICR_APPTAINER_IMAGE_DIR=${AICR_APPTAINER_IMAGE_DIR}

Next steps:
  1. Review benchmark-settings.env.
  2. If canonical runtime assets are missing, run:
     make rebuild-runtime APPLY=1
  3. Run the setup gate workflow from repo root:
     bash scripts/setup/run-setup-gate.sh --cluster b200 --submit-smoke-tests
EOF
