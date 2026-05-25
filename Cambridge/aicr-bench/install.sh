#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  ./install.sh --prefix=/path/to/install

Installs this AICR-Bench checkout under:
  /path/to/install/aicr-bench

The installer copies source, docs, configs, and scripts only. Runtime assets,
Python environments, containers, scratch data, and generated results are built
or produced separately after installation.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

prefix=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix=*)
      prefix="${1#--prefix=}"
      shift
      ;;
    --prefix)
      prefix="${2:-}"
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

[[ -n "$prefix" ]] || die "--prefix is required"
case "$prefix" in
  /*) ;;
  *) die "--prefix must be an absolute path" ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${prefix%/}/aicr-bench"
tmp_target="${target}.tmp.$$"

[[ -d "$script_dir/scripts" ]] || die "installer must run from an AICR-Bench checkout"
if [[ -e "$target" ]]; then
  die "target already exists: ${target}"
fi
if [[ -e "$tmp_target" ]]; then
  die "temporary target already exists: ${tmp_target}"
fi

mkdir -p "$tmp_target"

if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude '.git/' \
    --exclude '.tools/' \
    --exclude '.venv/' \
    --exclude '__pycache__/' \
    --exclude '*.pyc' \
    --exclude 'scratch/' \
    --exclude 'data/tmp/' \
    --exclude 'results/by-date/' \
    --exclude 'results/by-node/' \
    --exclude 'results/setup/' \
    --exclude 'results/slurm/' \
    --exclude 'apptainer/images/' \
    "$script_dir"/ "$tmp_target"/
else
  (cd "$script_dir" && tar \
    --exclude './.git' \
    --exclude './.tools' \
    --exclude './.venv' \
    --exclude './scratch' \
    --exclude './data/tmp' \
    --exclude './results/by-date' \
    --exclude './results/by-node' \
    --exclude './results/setup' \
    --exclude './results/slurm' \
    --exclude './apptainer/images' \
    -cf - .) | (cd "$tmp_target" && tar -xf -)
fi

mv "$tmp_target" "$target"

cat <<EOF
Installed AICR-Bench to:
  ${target}

Next steps:
  cd ${target}
  cp benchmark-settings.env.example benchmark-settings.env
  make setup-python-local

On AICR HPC, set a private AICR_RUNTIME_ROOT in benchmark-settings.env and use:
  make setup-python-slurm CLUSTER=rtxpro6000 NODELIST=<rtx-devel-node> APPLY=1 WAIT=1
  make install-containers CONTAINER_NODELIST=<rtx-devel-node> APPLY=1
EOF
