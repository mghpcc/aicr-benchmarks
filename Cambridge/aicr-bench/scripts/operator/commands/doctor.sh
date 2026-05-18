#!/usr/bin/env bash
set -euo pipefail

aicr_operator_doctor_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr doctor repo-root

Checks the repository root for stray top-level runtime artifacts.
Allowed generated top-level locations are results/, scratch/, and data/.
.tools/ is allowed only for the explicit --repo-local-runtime development escape hatch.
Canonical Apptainer images live under the shared AICR_APPTAINER_IMAGE_DIR outside the checkout.
Operator automation source may live at Makefile and workflows/.
EOF
}

aicr_operator_doctor_repo_root_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr doctor repo-root

Fails on unexpected top-level files or directories, including root cufile.log and ad hoc *.out, *.err, or *.log files.
EOF
}

aicr_operator_doctor_allow() {
  allowed+=("$1")
}

aicr_operator_doctor_is_allowed() {
  local item="$1"
  local allowed_item

  for allowed_item in "${allowed[@]}"; do
    [[ "$allowed_item" == "$item" ]] && return 0
  done

  return 1
}

aicr_operator_doctor_add_tracked_top_levels() {
  local root="$1"
  local path top
  while IFS= read -r -d '' path; do
    [[ -n "$path" ]] || continue
    top="${path%%/*}"
    aicr_operator_doctor_allow "$top"
  done < <(git -C "$root" ls-files -z)
}

aicr_operator_doctor_repo_root() {
  local root="${AICR_BMARK_DIR}"
  local pwd_physical
  local git_root=""
  local entry base
  local -a problems=()
  local -a entries=()
  local -a allowed=()

  aicr_operator_require_repo_root

  pwd_physical="$(pwd -P)"
  if command -v git >/dev/null 2>&1 && [[ -d "${root}/.git" ]]; then
    git_root="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -n "$git_root" ]]; then
      git_root="$(cd "$git_root" && pwd -P)"
      root="$(cd "$root" && pwd -P)"
      if [[ "$git_root" != "$root" ]]; then
        aicr_operator_die "resolved repo root ${root} does not match git root ${git_root}"
      fi
    fi
  fi

  aicr_operator_doctor_allow ".git"
  aicr_operator_doctor_allow "benchmark-settings.env"
  aicr_operator_doctor_allow "results"
  aicr_operator_doctor_allow "scratch"
  aicr_operator_doctor_allow "apptainerimages"
  aicr_operator_doctor_allow ".tools"
  aicr_operator_doctor_allow "data"
  aicr_operator_doctor_allow "Makefile"
  aicr_operator_doctor_allow "workflows"

  if command -v git >/dev/null 2>&1 && [[ -d "${root}/.git" ]]; then
    aicr_operator_doctor_add_tracked_top_levels "$root"
  else
    aicr_operator_doctor_allow ".gitignore"
    aicr_operator_doctor_allow "README.md"
    aicr_operator_doctor_allow "benchmark-settings.env.example"
    aicr_operator_doctor_allow "pyproject.toml"
    aicr_operator_doctor_allow "uv.lock"
    aicr_operator_doctor_allow "Makefile"
    aicr_operator_doctor_allow "apptainer"
    aicr_operator_doctor_allow "docs"
    aicr_operator_doctor_allow "examples"
    aicr_operator_doctor_allow "schemas"
    aicr_operator_doctor_allow "scripts"
    aicr_operator_doctor_allow "slurm"
    aicr_operator_doctor_allow "workflows"
  fi

  shopt -s dotglob nullglob
  entries=("${root}"/*)
  shopt -u dotglob nullglob

  for entry in "${entries[@]}"; do
    base="$(basename "$entry")"

    case "$base" in
      cufile.log)
        problems+=("${base} (root-level cuFile log; expected under results/... run artifacts)")
        continue
        ;;
      *.out|*.err|*.log)
        problems+=("${base} (root-level runtime log; expected under results/... or scratch/)")
        continue
        ;;
    esac

    if ! aicr_operator_doctor_is_allowed "$base"; then
      if [[ -d "$entry" ]]; then
        problems+=("${base}/ (unexpected top-level directory)")
      else
        problems+=("${base} (unexpected top-level file)")
      fi
    fi
  done

  echo "Repo root: ${root}"
  if [[ "$pwd_physical" != "$root" ]]; then
    echo "Current directory: ${pwd_physical}"
  fi

  if [[ "${#problems[@]}" -eq 0 ]]; then
    echo "Repo root cleanliness: ok"
    return 0
  fi

  echo "Repo root cleanliness: failed"
  echo "Unexpected top-level entries:"
  printf '  %s\n' "${problems[@]}"
  return 1
}

aicr_operator_doctor() {
  local target="${1:-}"

  case "$target" in
    -h|--help)
      aicr_operator_doctor_usage
      exit 0
      ;;
    "")
      aicr_operator_doctor_usage >&2
      exit 2
      ;;
    repo-root)
      shift
      case "${1:-}" in
        -h|--help)
          aicr_operator_doctor_repo_root_usage
          exit 0
          ;;
        "")
          aicr_operator_doctor_repo_root
          ;;
        *)
          aicr_operator_usage_error "unknown doctor repo-root argument: $1"
          ;;
      esac
      ;;
    *)
      echo "ERROR: unknown doctor target: ${target}" >&2
      aicr_operator_doctor_usage >&2
      exit 2
      ;;
  esac
}
