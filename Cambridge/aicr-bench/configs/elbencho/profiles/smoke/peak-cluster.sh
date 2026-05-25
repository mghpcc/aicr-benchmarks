set -euo pipefail
IMAGE="${AICR_ELBENCHO_IMAGE}"
TARGET_ROOT="${ELBENCHO_TARGET_ROOT:-${AICR_SCRATCH_DIR}/elbencho}"
SIZE="${ELBENCHO_SIZE:-1G}"
BLOCK="${ELBENCHO_BLOCK:-1M}"
THREADS="${ELBENCHO_THREADS:-16}"
IODEPTH="${ELBENCHO_IODEPTH:-4}"
FILE_PATTERN="${ELBENCHO_FILE_PATTERN:-file[1-4]}"
APPTAINER_OPTS="${AICR_APPTAINER_COMMON_OPTS}"
if [[ "${TARGET_ROOT}" == /scratch || "${TARGET_ROOT}" == /scratch/* ]]; then
  APPTAINER_OPTS="${APPTAINER_OPTS} --bind /scratch:/scratch"
fi
export APPTAINER_OPTS
RUN_ROOT="${TARGET_ROOT}/peak-cluster/run-${SLURM_JOB_ID:-manual-$(date -u +%Y%m%dT%H%M%SZ)-$$}"
HOSTSFILE="${AICR_ELBENCHO_WORK_DIR}/hosts.txt"
mkdir -p "${RUN_ROOT}"
scontrol show hostnames "${SLURM_NODELIST:-${SLURM_JOB_NODELIST:-$(hostname -s)}}" > "${HOSTSFILE}"
cleanup() {
  apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" \
    elbencho --hostsfile "${HOSTSFILE}" --quit >/dev/null 2>&1 || true
  rm -rf -- "${RUN_ROOT:?}/"
}
trap cleanup EXIT
srun --overlap --nodes="${SLURM_NNODES:-1}" --ntasks="${SLURM_NNODES:-1}" --ntasks-per-node=1 \
  bash -lc 'apptainer exec ${APPTAINER_OPTS} --nv "${AICR_ELBENCHO_IMAGE}" elbencho --service --foreground' &
SERVICE_PID=$!
service_ready=0
for attempt in $(seq 1 12); do
  if apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" elbencho \
    --hostsfile "${HOSTSFILE}" --write --read --size "${SIZE}" --block "${BLOCK}" \
    --direct --threads "${THREADS}" --iodepth "${IODEPTH}" --dryrun "${RUN_ROOT}/${FILE_PATTERN}"; then
    service_ready=1
    break
  fi
  echo "elbencho service dry-run preflight failed on attempt ${attempt}; retrying..." >&2
  sleep 5
done
if [[ "${service_ready}" -ne 1 ]]; then
  echo "elbencho services did not pass dry-run preflight after 60 seconds" >&2
  exit 1
fi
apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" elbencho \
  --hostsfile "${HOSTSFILE}" --write --read --size "${SIZE}" --block "${BLOCK}" \
  --direct --threads "${THREADS}" --iodepth "${IODEPTH}" "${RUN_ROOT}/${FILE_PATTERN}"
apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" elbencho \
  --hostsfile "${HOSTSFILE}" --quit
wait "${SERVICE_PID}" || true
