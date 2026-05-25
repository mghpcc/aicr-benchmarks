set -euo pipefail
IMAGE="${AICR_ELBENCHO_IMAGE}"
TARGET_ROOT="${ELBENCHO_TARGET_ROOT:-${AICR_SCRATCH_DIR}/elbencho}"
SIZE="${ELBENCHO_SIZE:-1G}"
BLOCK="${ELBENCHO_BLOCK:-8k}"
THREADS="${ELBENCHO_THREADS:-8}"
IODEPTH="${ELBENCHO_IODEPTH:-4}"
FILE_PATTERN="${ELBENCHO_FILE_PATTERN:-file[1-4]}"
APPTAINER_OPTS="${AICR_APPTAINER_COMMON_OPTS}"
if [[ "${TARGET_ROOT}" == /scratch || "${TARGET_ROOT}" == /scratch/* ]]; then
  APPTAINER_OPTS="${APPTAINER_OPTS} --bind /scratch:/scratch"
fi
RUN_ROOT="${TARGET_ROOT}/small-block/run-${SLURM_JOB_ID:-manual-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
mkdir -p "${RUN_ROOT}"
cleanup() { rm -rf -- "${RUN_ROOT:?}/"; }
trap cleanup EXIT
apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" elbencho \
  --write --read --size "${SIZE}" --block "${BLOCK}" --direct --threads "${THREADS}" --iodepth "${IODEPTH}" \
  --dryrun "${RUN_ROOT}/${FILE_PATTERN}"
apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" elbencho \
  --write --read --size "${SIZE}" --block "${BLOCK}" --direct --threads "${THREADS}" --iodepth "${IODEPTH}" \
  "${RUN_ROOT}/${FILE_PATTERN}"
