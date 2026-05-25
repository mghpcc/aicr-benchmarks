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
  scripts/setup/rebuild-runtime-assets.sh [--replace-current]

Builds canonical runtime assets in a timestamped release directory, validates
them, and promotes stable runtime symlinks only after validation succeeds.
Run this from the Slurm wrapper on a builder node, not from a login node.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    die "sha256sum or shasum is required"
  fi
}

file_size() {
  wc -c <"$1" | tr -d ' '
}

replace_symlink() {
  local link_path="$1"
  local target="$2"
  local tmp="${link_path}.tmp.$$"
  local backup

  rm -f "$tmp"
  if [[ -e "$link_path" || -L "$link_path" ]]; then
    if [[ ! -L "$link_path" ]]; then
      [[ "$replace_current" == "1" ]] || die "refusing to replace non-symlink path without --replace-current: ${link_path}"
      backup="${link_path}.pre-runtime-${release_id}"
      [[ ! -e "$backup" ]] || die "backup path already exists: ${backup}"
      mv "$link_path" "$backup"
      echo "Moved existing ${link_path} to ${backup}"
    fi
  fi

  ln -s "$target" "$tmp"
  mv -Tf "$tmp" "$link_path"
}

replace_current=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --replace-current)
      replace_current=1
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

aicr_require_repo_root
if [[ -z "${SLURM_JOB_ID:-}" && "${AICR_ALLOW_DIRECT_RUNTIME_REBUILD:-0}" != "1" ]]; then
  die "runtime rebuilds must run under Slurm; use make rebuild-runtime APPLY=1"
fi
require_cmd apptainer
require_cmd tar

umask 022

release_id="${AICR_RUNTIME_RELEASE_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
release_dir="${AICR_RUNTIME_ROOT}/releases/${release_id}"
manifest_dir="${AICR_RUNTIME_ROOT}/manifests"
manifest_path="${manifest_dir}/runtime-${release_id}.json"
current_manifest_path="${manifest_dir}/current.json"
build_uv_root="${release_dir}/uv"
build_uv_envs_dir="${release_dir}/uv-envs"
build_env_prefix="${build_uv_envs_dir}/aicr-bench"
build_image_dir="${release_dir}/apptainer/images"
marker="${release_dir}/.build-in-progress"
build_platform="$(aicr_python_platform)"
env_spec_path="$(aicr_python_env_spec_path "$build_platform")"
env_spec_kind="$(aicr_python_env_spec_kind "$env_spec_path")"

[[ ! -e "$release_dir" ]] || die "release directory already exists: ${release_dir}"
mkdir -p "$release_dir" "$build_uv_envs_dir" "$build_image_dir" "$manifest_dir"
chmod u+rwX,go+rX,go-w "$AICR_RUNTIME_ROOT" "${AICR_RUNTIME_ROOT}/releases" "$manifest_dir"
printf '%s\n' "$(aicr_timestamp_utc)" >"$marker"

echo "Building AICR runtime release ${release_id}"
echo "Runtime root : ${AICR_RUNTIME_ROOT}"
echo "Release dir  : ${release_dir}"

build_uv_bin="$(aicr_bootstrap_uv "$build_uv_root")"

echo "Creating uv Python environment"
echo "Environment spec: ${env_spec_path} (${env_spec_kind})"
UV_LINK_MODE="${UV_LINK_MODE:-copy}" "$build_uv_bin" venv --python 3.11 "$build_env_prefix"
if [[ "$env_spec_kind" == "uv-lock" ]]; then
  (cd "$AICR_BMARK_DIR" && VIRTUAL_ENV="$build_env_prefix" UV_LINK_MODE="${UV_LINK_MODE:-copy}" "$build_uv_bin" sync --frozen --active)
else
  (cd "$AICR_BMARK_DIR" && VIRTUAL_ENV="$build_env_prefix" UV_LINK_MODE="${UV_LINK_MODE:-copy}" "$build_uv_bin" sync --active)
fi

PYTORCH_PRIMARY_URI="${PYTORCH_PRIMARY_URI:-docker://nvcr.io/nvidia/pytorch:25.10-py3}"
PYTORCH_PROBE_URI="${PYTORCH_PROBE_URI:-docker://nvcr.io/nvidia/pytorch:26.03-py3}"
HPC_BENCH_URI="${HPC_BENCH_URI:-docker://nvcr.io/nvidia/hpc-benchmarks:26.02}"
ELBENCHO_URI="${ELBENCHO_URI:-docker://breuner/elbencho:${AICR_ELBENCHO_TAG}}"
export PYTORCH_PRIMARY_URI PYTORCH_PROBE_URI HPC_BENCH_URI ELBENCHO_URI

echo "Pulling verified Apptainer containers"
container_pull_args=(--refresh --image-dir "$build_image_dir")
if [[ "${AICR_REQUIRE_ELBENCHO_IMAGE:-0}" == "1" ]]; then
  container_pull_args+=(--include-elbencho)
fi
bash "${AICR_BMARK_DIR}/apptainer/pull/pull-verified-containers.sh" "${container_pull_args[@]}"

echo "Validating uv Python imports"
aicr_validate_env_python "${build_env_prefix}/bin/python"

echo "Validating Apptainer images"
read -r -a apptainer_common_opts <<<"${AICR_APPTAINER_COMMON_OPTS}"
required_images=(
  "${build_image_dir}/pytorch-25.10-py3.sif"
  "${build_image_dir}/hpc-benchmarks-26.02.sif"
)
if [[ "${AICR_REQUIRE_ELBENCHO_IMAGE:-0}" == "1" ]]; then
  required_images+=("${build_image_dir}/elbencho-${AICR_ELBENCHO_TAG}.sif")
fi
if [[ "${ENABLE_PYTORCH_PROBE:-0}" == "1" ]]; then
  required_images+=("${build_image_dir}/pytorch-26.03-py3.sif")
fi

for image in "${required_images[@]}"; do
  [[ -r "$image" && -s "$image" ]] || die "missing readable image after pull: ${image}"
  apptainer sif list "$image" >/dev/null
  apptainer exec "${apptainer_common_opts[@]}" "$image" true >/dev/null
done

echo "Applying shared read/execute permissions"
chmod -R u+rwX,go+rX,go-w "$release_dir"
rm -f "$marker"

mkdir -p "${AICR_RUNTIME_ROOT}/uv-envs" "${AICR_RUNTIME_ROOT}/apptainer"
chmod u+rwX,go+rX,go-w "${AICR_RUNTIME_ROOT}/uv-envs" "${AICR_RUNTIME_ROOT}/apptainer"
replace_symlink "${AICR_RUNTIME_ROOT}/current" "releases/${release_id}"
replace_symlink "${AICR_RUNTIME_ROOT}/uv" "current/uv"
replace_symlink "${AICR_RUNTIME_ROOT}/uv-envs/aicr-bench" "../current/uv-envs/aicr-bench"
replace_symlink "${AICR_RUNTIME_ROOT}/apptainer/images" "../current/apptainer/images"

env_sha256="$(sha256_file "${AICR_BMARK_DIR}/pyproject.toml")"
env_spec_sha256="$(sha256_file "$env_spec_path")"
git_commit="$(git -C "$AICR_BMARK_DIR" rev-parse HEAD 2>/dev/null || true)"
git_dirty="$(git -C "$AICR_BMARK_DIR" diff --quiet --ignore-submodules -- 2>/dev/null && printf 'false' || printf 'true')"
created_at_utc="$(aicr_timestamp_utc)"
manifest_tmp="$(mktemp)"
probe_sha256=""
probe_size="0"
elbencho_sha256=""
elbencho_size="0"
if [[ "${ENABLE_PYTORCH_PROBE:-0}" == "1" && -f "${build_image_dir}/pytorch-26.03-py3.sif" ]]; then
  probe_sha256="$(sha256_file "${build_image_dir}/pytorch-26.03-py3.sif")"
  probe_size="$(file_size "${build_image_dir}/pytorch-26.03-py3.sif")"
fi
if [[ "${AICR_REQUIRE_ELBENCHO_IMAGE:-0}" == "1" && -f "${build_image_dir}/elbencho-${AICR_ELBENCHO_TAG}.sif" ]]; then
  elbencho_sha256="$(sha256_file "${build_image_dir}/elbencho-${AICR_ELBENCHO_TAG}.sif")"
  elbencho_size="$(file_size "${build_image_dir}/elbencho-${AICR_ELBENCHO_TAG}.sif")"
fi

"${build_env_prefix}/bin/python" - \
  "$manifest_tmp" \
  "$release_id" \
  "$created_at_utc" \
  "$AICR_RUNTIME_ROOT" \
  "$release_dir" \
  "$git_commit" \
  "$git_dirty" \
  "$env_sha256" \
  "$env_spec_path" \
  "$env_spec_kind" \
  "$env_spec_sha256" \
  "$PYTORCH_PRIMARY_URI" \
  "${build_image_dir}/pytorch-25.10-py3.sif" \
  "$(sha256_file "${build_image_dir}/pytorch-25.10-py3.sif")" \
  "$(file_size "${build_image_dir}/pytorch-25.10-py3.sif")" \
  "$HPC_BENCH_URI" \
  "${build_image_dir}/hpc-benchmarks-26.02.sif" \
  "$(sha256_file "${build_image_dir}/hpc-benchmarks-26.02.sif")" \
  "$(file_size "${build_image_dir}/hpc-benchmarks-26.02.sif")" \
  "${AICR_REQUIRE_ELBENCHO_IMAGE:-0}" \
  "$ELBENCHO_URI" \
  "${build_image_dir}/elbencho-${AICR_ELBENCHO_TAG}.sif" \
  "$elbencho_sha256" \
  "$elbencho_size" \
  "${ENABLE_PYTORCH_PROBE:-0}" \
  "$PYTORCH_PROBE_URI" \
  "${build_image_dir}/pytorch-26.03-py3.sif" \
  "$probe_sha256" \
  "$probe_size" \
  <<'PY'
import json
import os
import stat
import sys
from pathlib import Path

(
    out_path,
    release_id,
    created_at_utc,
    runtime_root,
    release_dir,
    git_commit,
    git_dirty,
    env_sha256,
    env_spec_path,
    env_spec_kind,
    env_spec_sha256,
    pytorch_primary_uri,
    pytorch_primary_path,
    pytorch_primary_sha,
    pytorch_primary_size,
    hpc_bench_uri,
    hpc_bench_path,
    hpc_bench_sha,
    hpc_bench_size,
    include_elbencho,
    elbencho_uri,
    elbencho_path,
    elbencho_sha,
    elbencho_size,
    enable_probe,
    pytorch_probe_uri,
    pytorch_probe_path,
    pytorch_probe_sha,
    pytorch_probe_size,
) = sys.argv[1:]

images = [
    {
        "name": "pytorch-25.10-py3",
        "uri": pytorch_primary_uri,
        "path": pytorch_primary_path,
        "sha256": pytorch_primary_sha,
        "bytes": int(pytorch_primary_size),
    },
    {
        "name": "hpc-benchmarks-26.02",
        "uri": hpc_bench_uri,
        "path": hpc_bench_path,
        "sha256": hpc_bench_sha,
        "bytes": int(hpc_bench_size),
    },
]
if include_elbencho == "1" and Path(elbencho_path).exists():
    images.append({
        "name": "elbencho",
        "uri": elbencho_uri,
        "path": elbencho_path,
        "sha256": elbencho_sha,
        "bytes": int(elbencho_size),
    })
if enable_probe == "1" and Path(pytorch_probe_path).exists():
    images.append({
        "name": "pytorch-26.03-py3",
        "uri": pytorch_probe_uri,
        "path": pytorch_probe_path,
        "sha256": pytorch_probe_sha,
        "bytes": int(pytorch_probe_size),
    })

runtime = Path(runtime_root)
links = {
    "current": str((runtime / "current").resolve()),
    "uv": os.readlink(runtime / "uv"),
    "uv_env": os.readlink(runtime / "uv-envs" / "aicr-bench"),
    "apptainer_images": os.readlink(runtime / "apptainer" / "images"),
}

mode = stat.S_IMODE(Path(release_dir).stat().st_mode)
obj = {
    "schema_version": 1,
    "release_id": release_id,
    "created_at_utc": created_at_utc,
    "runtime_root": runtime_root,
    "release_dir": release_dir,
    "git_commit": git_commit or None,
    "git_dirty": git_dirty == "true",
    "pyproject_toml_sha256": env_sha256,
    "environment_spec_path": env_spec_path,
    "environment_spec_kind": env_spec_kind,
    "environment_spec_sha256": env_spec_sha256,
    "uv_root_prefix": str(Path(release_dir) / "uv"),
    "uv_env_prefix": str(Path(release_dir) / "uv-envs" / "aicr-bench"),
    "apptainer_image_dir": str(Path(release_dir) / "apptainer" / "images"),
    "images": images,
    "validation": {
        "python_imports": ["jsonschema", "matplotlib", "pandas", "snakemake"],
        "apptainer_sif_list": "passed",
        "apptainer_exec_true": "passed",
    },
    "promoted_links": links,
    "permissions": {
        "release_dir_mode": oct(mode),
        "policy": "owner-write, world-read/world-execute, no group/world write",
    },
}
Path(out_path).write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
PY

mv "$manifest_tmp" "$manifest_path"
cp "$manifest_path" "$current_manifest_path"
chmod u+rw,go+r,go-w "$manifest_path" "$current_manifest_path"

echo "Promoted runtime release ${release_id}"
echo "Manifest: ${manifest_path}"
echo "Current manifest: ${current_manifest_path}"
