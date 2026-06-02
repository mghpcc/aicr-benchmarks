#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOH'
Usage:
  ./install.sh --prefix=/path/to/install

Installs Cambridge/aicr-bench under:
  /path/to/install/aicr-bench
EOH
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
source_dir="${script_dir}/aicr-bench"
target="${prefix%/}/aicr-bench"
tmp_target="${target}.tmp.$$"

[[ -d "$source_dir/scripts" ]] || die "missing Cambridge/aicr-bench distribution"
[[ ! -e "$target" ]] || die "target already exists: ${target}"
[[ ! -e "$tmp_target" ]] || die "temporary target already exists: ${tmp_target}"

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
    "$source_dir"/ "$tmp_target"/
else
  (cd "$source_dir" && tar \
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
cat <<EOH
Installed AICR-Bench to:
  ${target}

Next steps:
  cd ${target}
  make setup-python-local
EOH
