#!/usr/bin/env bash
#SBATCH --job-name=aicr-install-containers
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=0
#SBATCH --time=04:00:00

set -euo pipefail

cd "${SLURM_SUBMIT_DIR:?SLURM_SUBMIT_DIR is required}"

args=()
if [[ "${AICR_CONTAINER_REFRESH:-0}" == "1" ]]; then
  args+=(--refresh)
fi
if [[ -n "${AICR_CONTAINER_IMAGE_DIR_OVERRIDE:-}" ]]; then
  args+=(--image-dir "${AICR_CONTAINER_IMAGE_DIR_OVERRIDE}")
fi
if [[ "${AICR_INSTALL_ELBENCHO_CONTAINER:-0}" == "1" ]]; then
  args+=(--include-elbencho)
fi
if [[ "${AICR_INSTALL_ONLY_ELBENCHO_CONTAINER:-0}" == "1" ]]; then
  args+=(--only-elbencho)
fi

echo "AICR container install job"
echo "host=$(hostname -s 2>/dev/null || hostname)"
echo "submit_dir=${SLURM_SUBMIT_DIR}"
echo "job_id=${SLURM_JOB_ID:-}"
echo "partition=${SLURM_JOB_PARTITION:-}"
echo "args=${args[*]:-}"
echo

bash apptainer/pull/pull-verified-containers.sh "${args[@]}"
