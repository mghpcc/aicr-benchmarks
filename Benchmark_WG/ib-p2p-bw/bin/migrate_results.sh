#!/usr/bin/env bash
# One-shot migration of existing p2p_pair results from the old flat layout
# to the new nested layout.
#
# Old:  results/<nodeA>-gpu<a>__<nodeB>-gpu<b>/<ts>/...
# New:  results/<nodeA>-gpu<a>/<nodeB>/<nodeA>-gpu<a>__<nodeB>-gpu<b>/<ts>/...
#
# Run from the directory that contains your `results/` tree (typically the
# directory you submit jobs from), or pass --results-dir.
#
# Idempotent: re-running after a partial migration only moves the
# remaining old-layout directories. Dirs that already match the new layout
# (no `__` in the top-level name), and `.slurm/`, are left alone.

set -euo pipefail

DRY_RUN=0
RESULTS_DIR="results"

usage() {
  cat <<EOF
Usage: $(basename "$0") [-n|--dry-run] [--results-dir DIR]

Move each old-layout pair directory:
    <DIR>/<nodeA>-gpu<a>__<nodeB>-gpu<b>/
into:
    <DIR>/<nodeA>-gpu<a>/<nodeB>/<nodeA>-gpu<a>__<nodeB>-gpu<b>/

Options:
  -n, --dry-run        Show what would be moved without moving anything.
  --results-dir DIR    Path to the results tree (default: ./results).
  -h, --help           Show this help and exit.

Safety:
  - Re-runs are idempotent (already-nested dirs are skipped).
  - Destinations that already exist are skipped with a SKIP message;
    you can inspect and resolve manually.
  - The .slurm/ subdir is never touched.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)        usage; exit 0;;
    -n|--dry-run)     DRY_RUN=1; shift;;
    --results-dir)
      [[ $# -ge 2 ]] || { echo "ERROR: --results-dir requires an argument" >&2; exit 1; }
      RESULTS_DIR="$2"; shift 2;;
    --results-dir=*)  RESULTS_DIR="${1#--results-dir=}"; shift;;
    *)                echo "ERROR: unknown arg: $1" >&2; usage >&2; exit 1;;
  esac
done

if [[ ! -d "$RESULTS_DIR" ]]; then
  echo "ERROR: results directory '$RESULTS_DIR' not found" >&2
  exit 1
fi

shopt -s nullglob
moved=0
skipped_other=0
skipped_collision=0

for dir in "$RESULTS_DIR"/*; do
  [[ -d "$dir" ]] || continue
  base="$(basename "$dir")"

  # Leave .slurm/ alone.
  [[ "$base" == ".slurm" ]] && continue

  # Match only old-layout pair names: nodeA-gpuN__nodeB-gpuM
  if [[ "$base" =~ ^([^_]+)-gpu([0-9]+)__([^_]+)-gpu([0-9]+)$ ]]; then
    nodeA="${BASH_REMATCH[1]}"
    gpuA="${BASH_REMATCH[2]}"
    nodeB="${BASH_REMATCH[3]}"
    new_parent="${RESULTS_DIR}/${nodeA}-gpu${gpuA}/${nodeB}"
    new_path="${new_parent}/${base}"

    if [[ -e "$new_path" ]]; then
      echo "SKIP (destination exists): $dir -> $new_path"
      skipped_collision=$((skipped_collision + 1))
      continue
    fi

    echo "MOVE: $dir -> $new_path"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      mkdir -p "$new_parent"
      mv "$dir" "$new_path"
    fi
    moved=$((moved + 1))
  else
    # Anything else (already-nested server-gpu dirs, unrelated files, etc.)
    skipped_other=$((skipped_other + 1))
  fi
done

echo
echo "moved:               $moved"
echo "skipped (collision): $skipped_collision"
echo "skipped (other):     $skipped_other"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo
  echo "(dry run; no files were moved. Re-run without --dry-run to apply.)"
fi
