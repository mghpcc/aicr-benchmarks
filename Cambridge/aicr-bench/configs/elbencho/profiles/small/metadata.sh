set -euo pipefail
IMAGE="${AICR_ELBENCHO_IMAGE}"
TARGET_ROOT="${ELBENCHO_TARGET_ROOT:-${AICR_SCRATCH_DIR}/elbencho}"
SIZE="${ELBENCHO_SIZE:-0k}"
BLOCK="${ELBENCHO_BLOCK:-0k}"
THREADS="${ELBENCHO_THREADS:-32}"
FILES="${ELBENCHO_FILES:-100}"
DIRS="${ELBENCHO_DIRS:-1000}"
APPTAINER_OPTS="${AICR_APPTAINER_COMMON_OPTS}"
if [[ "${TARGET_ROOT}" == /scratch || "${TARGET_ROOT}" == /scratch/* ]]; then
  APPTAINER_OPTS="${APPTAINER_OPTS} --bind /scratch:/scratch"
fi
RUN_ROOT="${TARGET_ROOT}/metadata/run-${SLURM_JOB_ID:-manual-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
# Metadata evidence label: non-cache-neutral-rehearsal until --dropcache is approved.
mkdir -p "${RUN_ROOT}"
cleanup() { rm -rf -- "${RUN_ROOT:?}/"; }
trap cleanup EXIT
apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" elbencho \
  --sync \
  --mkdirs --write --stat --read --delfiles --deldirs \
  --size "${SIZE}" --block "${BLOCK}" --files "${FILES}" --dirs "${DIRS}" \
  --threads "${THREADS}" --direct --dryrun "${RUN_ROOT}"
apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" elbencho \
  --sync \
  --mkdirs --write --stat --read --delfiles --deldirs \
  --size "${SIZE}" --block "${BLOCK}" --files "${FILES}" --dirs "${DIRS}" \
  --threads "${THREADS}" --direct "${RUN_ROOT}"
