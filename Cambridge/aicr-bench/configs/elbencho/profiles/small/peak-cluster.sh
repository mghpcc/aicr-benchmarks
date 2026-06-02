set -euo pipefail
IMAGE="${AICR_ELBENCHO_IMAGE}"
TARGET_ROOT="${ELBENCHO_TARGET_ROOT:-${AICR_SCRATCH_DIR}/elbencho}"
PHASE="${ELBENCHO_PHASE:-write-read}"
SIZE="${ELBENCHO_SIZE:-20G}"
BLOCK="${ELBENCHO_BLOCK:-1M}"
THREADS="${ELBENCHO_THREADS:-64}"
IODEPTH="${ELBENCHO_IODEPTH:-16}"
FILE_PATTERN="${ELBENCHO_FILE_PATTERN:-file[1-16]}"
APPTAINER_OPTS="${AICR_APPTAINER_COMMON_OPTS}"
if [[ "${TARGET_ROOT}" == /scratch || "${TARGET_ROOT}" == /scratch/* ]]; then
  APPTAINER_OPTS="${APPTAINER_OPTS} --bind /scratch:/scratch"
fi
export APPTAINER_OPTS
case "${PHASE}" in
  write-read|write-clean)
    RUN_ROOT="${ELBENCHO_RUN_ROOT:-${TARGET_ROOT}/peak-cluster/run-${SLURM_JOB_ID:-manual-$(date -u +%Y%m%dT%H%M%SZ)-$$}}"
    ;;
  write-keep|read-existing)
    if [[ -z "${ELBENCHO_RUN_ROOT:-}" ]]; then
      echo "ELBENCHO_RUN_ROOT is required for ELBENCHO_PHASE=${PHASE}" >&2
      exit 2
    fi
    RUN_ROOT="${ELBENCHO_RUN_ROOT}"
    ;;
  *)
    echo "unsupported ELBENCHO_PHASE=${PHASE}" >&2
    exit 2
    ;;
esac
HOSTSFILE="${AICR_ELBENCHO_WORK_DIR}/hosts.txt"
case "${PHASE}" in
  write-read|write-clean|write-keep)
    mkdir -p "${RUN_ROOT}"
    ;;
  read-existing)
    if [[ ! -d "${RUN_ROOT}" ]]; then
      echo "ELBENCHO_RUN_ROOT does not exist for read-existing: ${RUN_ROOT}" >&2
      exit 2
    fi
    ;;
esac
scontrol show hostnames "${SLURM_NODELIST:-${SLURM_JOB_NODELIST:-$(hostname -s)}}" > "${HOSTSFILE}"
cleanup() {
  apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" \
    elbencho --hostsfile "${HOSTSFILE}" --quit >/dev/null 2>&1 || true
  case "${PHASE}" in
    write-read|write-clean)
      rm -rf -- "${RUN_ROOT:?}/"
      ;;
  esac
}
trap cleanup EXIT
case "${PHASE}" in
  write-read) ELBENCHO_OPS=(--write --read) ;;
  write-keep|write-clean) ELBENCHO_OPS=(--write) ;;
  read-existing) ELBENCHO_OPS=(--read) ;;
esac
srun --overlap --nodes="${SLURM_NNODES:-1}" --ntasks="${SLURM_NNODES:-1}" --ntasks-per-node=1 \
  bash -lc 'apptainer exec ${APPTAINER_OPTS} --nv "${AICR_ELBENCHO_IMAGE}" elbencho --service --foreground' &
SERVICE_PID=$!
service_ready=0
for attempt in $(seq 1 12); do
  if apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" elbencho \
    --hostsfile "${HOSTSFILE}" "${ELBENCHO_OPS[@]}" --size "${SIZE}" --block "${BLOCK}" \
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
  --hostsfile "${HOSTSFILE}" "${ELBENCHO_OPS[@]}" --size "${SIZE}" --block "${BLOCK}" \
  --direct --threads "${THREADS}" --iodepth "${IODEPTH}" "${RUN_ROOT}/${FILE_PATTERN}"
apptainer exec ${APPTAINER_OPTS} --nv "${IMAGE}" elbencho \
  --hostsfile "${HOSTSFILE}" --quit
wait "${SERVICE_PID}" || true
