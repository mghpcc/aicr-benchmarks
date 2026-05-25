#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<EOF
Usage: $0 --cluster <rtxpro6000|b200> [--submit-smoke-tests] [--skip-runtime-validation]

Deprecated options:
  --skip-pull             Accepted as an alias for --skip-runtime-validation.
  --refresh-containers    Not supported; use make rebuild-runtime APPLY=1.
EOF
}

submit_sbatch() {
  local sbatch_path="$1"
  local job_id

  job_id="$(sbatch --parsable --mem=0 "${sbatch_path}")"
  job_id="${job_id%%;*}"
  [[ -n "${job_id}" ]] || {
    echo "ERROR: sbatch did not return a job ID for ${sbatch_path}" >&2
    exit 1
  }

  echo "Submitted ${sbatch_path} as job ${job_id}" >&2
  printf '%s\n' "${job_id}"
}

wait_for_slurm_jobs() {
  local poll_seconds=15
  local jobs_csv
  local active

  jobs_csv="$(IFS=,; echo "$*")"
  [[ -n "${jobs_csv}" ]] || return 0

  echo
  echo "Waiting for submitted smoke-test jobs to leave the Slurm queue: ${jobs_csv}"

  while true; do
    active="$(squeue -h -j "${jobs_csv}" -o "%i %T" 2>/dev/null || true)"
    if [[ -z "${active}" ]]; then
      echo "Submitted smoke-test jobs are no longer queued or running."
      break
    fi

    echo "Still active:"
    while IFS= read -r line; do
      echo "  ${line}"
    done <<<"${active}"
    sleep "${poll_seconds}"
  done

  # Give wrappers a brief moment to flush canonical artifacts before readiness.
  sleep 2
}

cluster=""
submit_smoke_tests=0
skip_runtime_validation=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --submit-smoke-tests)
      submit_smoke_tests=1
      shift
      ;;
    --skip-runtime-validation|--skip-pull)
      skip_runtime_validation=1
      shift
      ;;
    --refresh-containers)
      echo "ERROR: --refresh-containers is no longer part of the setup gate." >&2
      aicr_print_runtime_rebuild_hint
      exit 2
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

[[ -n "${cluster}" ]] || {
  usage
  exit 2
}

aicr_assert_supported_cluster "${cluster}"
aicr_require_repo_root
export AICR_CLUSTER_NAME="${cluster}"

pytorch_sbatch="slurm/verify/${cluster}-pytorch-smoke.sbatch"
hpc_sbatch="slurm/verify/${cluster}-hpc-benchmarks-smoke.sbatch"
elbencho_sbatch="slurm/verify/${cluster}-elbencho-smoke.sbatch"

if [[ ! -f "${AICR_BMARK_DIR}/${pytorch_sbatch}" ]]; then
  echo "ERROR: missing Slurm script: ${pytorch_sbatch}" >&2
  exit 1
fi
if [[ ! -f "${AICR_BMARK_DIR}/${hpc_sbatch}" ]]; then
  echo "ERROR: missing Slurm script: ${hpc_sbatch}" >&2
  exit 1
fi
if [[ ! -f "${AICR_BMARK_DIR}/${elbencho_sbatch}" ]]; then
  echo "ERROR: missing Slurm script: ${elbencho_sbatch}" >&2
  exit 1
fi

echo "Running setup gate for cluster ${cluster}"
echo

echo "[1/4] canonical runtime asset validation"
if [[ "${skip_runtime_validation}" == "1" ]]; then
  echo "Skipping runtime validation by request."
else
  aicr_validate_runtime_assets
fi
echo

echo "[2/4] container compatibility"
bash "${AICR_BMARK_DIR}/scripts/verify/check-container-compat.sh"
echo

if [[ "${submit_smoke_tests}" == "1" ]]; then
  echo "[3/4] submitting smoke tests"
  cd "${AICR_BMARK_DIR}"
  pytorch_job_id="$(submit_sbatch "${pytorch_sbatch}")"
  hpc_job_id="$(submit_sbatch "${hpc_sbatch}")"
  elbencho_job_id="$(submit_sbatch "${elbencho_sbatch}")"
  wait_for_slurm_jobs "${pytorch_job_id}" "${hpc_job_id}" "${elbencho_job_id}"
else
  echo "[3/4] smoke-test submission commands"
  echo "  sbatch --mem=0 ${pytorch_sbatch}"
  echo "  sbatch --mem=0 ${hpc_sbatch}"
  echo "  sbatch --mem=0 ${elbencho_sbatch}"
fi
echo

echo "[4/4] setup readiness"
if bash "${AICR_BMARK_DIR}/scripts/setup/check-setup-readiness.sh" --cluster "${cluster}"; then
  exit 0
fi

echo
if [[ "${submit_smoke_tests}" == "1" ]]; then
  echo "Smoke tests may still be queued or running. Re-run the readiness check after they finish:"
else
  echo "Submit the smoke tests, wait for them to finish, then re-run the readiness check:"
fi
echo "  bash scripts/setup/check-setup-readiness.sh --cluster ${cluster}"
