#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${DIR}/../lib/aicr-paths.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/setup/submit-container-install.sh [--apply] [--refresh] [--image-dir <path>] [--include-elbencho] [--only-elbencho] [--partition <name>] [--nodelist <node[,node...]>] [--time <HH:MM:SS>] [--mem <size>] [--no-wait]

Default behavior is a dry run. Pass --apply to submit the Apptainer image
install as a Slurm job. The default partition is cpu so large OCI-to-SIF
conversions do not run on the login node.
Submissions default to --mem=0 so Slurm grants the job the node memory cgroup.
Use --only-elbencho to add or refresh only the optional Elbencho image without
rechecking the default PyTorch and HPC Benchmarks images.
EOF
}

apply=0
refresh=0
image_dir_override=""
include_elbencho="${AICR_INSTALL_ELBENCHO_CONTAINER:-0}"
only_elbencho="${AICR_INSTALL_ONLY_ELBENCHO_CONTAINER:-0}"
partition="${AICR_CONTAINER_INSTALL_PARTITION:-cpu}"
nodelist="${AICR_CONTAINER_INSTALL_NODELIST:-}"
time_limit="${AICR_CONTAINER_INSTALL_TIME:-04:00:00}"
memory_request="${AICR_CONTAINER_INSTALL_MEM:-0}"
wait=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      apply=1
      shift
      ;;
    --refresh)
      refresh=1
      shift
      ;;
    --image-dir)
      image_dir_override="${2:-}"
      shift 2
      ;;
    --include-elbencho)
      include_elbencho=1
      shift
      ;;
    --only-elbencho)
      include_elbencho=1
      only_elbencho=1
      shift
      ;;
    --partition)
      partition="${2:-}"
      shift 2
      ;;
    --nodelist|--nodes)
      nodelist="${2:-}"
      shift 2
      ;;
    --time)
      time_limit="${2:-}"
      shift 2
      ;;
    --mem)
      memory_request="${2:-}"
      shift 2
      ;;
    --no-wait)
      wait=0
      shift
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

aicr_require_repo_root
aicr_require_settings_file
aicr_mkdirs
[[ -n "$memory_request" ]] || aicr_die "--mem must not be empty"
[[ "$memory_request" =~ ^[0-9]+([KMGTP])?$ ]] || aicr_die "--mem must be a Slurm memory value such as 0, 512G, or 1T"

sbatch_path="${AICR_BMARK_DIR}/slurm/setup/install-containers.sbatch"
[[ -f "$sbatch_path" ]] || {
  echo "ERROR: missing Slurm script: ${sbatch_path}" >&2
  exit 2
}

mkdir -p "${AICR_BMARK_DIR}/results/setup"

export_arg="ALL,AICR_CONTAINER_REFRESH=${refresh},AICR_INSTALL_ELBENCHO_CONTAINER=${include_elbencho},AICR_INSTALL_ONLY_ELBENCHO_CONTAINER=${only_elbencho}"
if [[ -n "$image_dir_override" ]]; then
  export_arg="${export_arg},AICR_CONTAINER_IMAGE_DIR_OVERRIDE=${image_dir_override}"
fi

cmd=(
  sbatch
  --parsable
  --partition "$partition"
  --time "$time_limit"
  --cpus-per-task 8
  --mem "$memory_request"
  --output "results/setup/container-install-%j.out"
  --error "results/setup/container-install-%j.err"
  --export "$export_arg"
)
if [[ -n "$nodelist" ]]; then
  cmd+=(--nodelist "$nodelist")
fi
cmd+=("$sbatch_path")

echo "Submitting container install job"
echo "Partition : ${partition}"
echo "Time      : ${time_limit}"
echo "Memory    : ${memory_request}"
if [[ -n "$nodelist" ]]; then
  echo "Node list : ${nodelist}"
fi
echo "Refresh   : ${refresh}"
echo "Elbencho  : ${include_elbencho}"
echo "Only Elb. : ${only_elbencho}"
if [[ -n "$image_dir_override" ]]; then
  echo "Image dir : ${image_dir_override}"
else
  echo "Image dir : ${AICR_APPTAINER_IMAGE_DIR}"
fi
printf 'Command   : '
printf '%q ' "${cmd[@]}"
echo

if [[ "$apply" == "0" ]]; then
  echo "Dry run only. Pass --apply to submit."
  exit 0
fi

job_id="$("${cmd[@]}")"
job_id="${job_id%%;*}"
echo "Submitted container install job ${job_id}"
echo "stdout: results/setup/container-install-${job_id}.out"
echo "stderr: results/setup/container-install-${job_id}.err"

if [[ "$wait" != "1" ]]; then
  exit 0
fi

echo "Waiting for container install job ${job_id} to leave the Slurm queue"
while squeue -h -j "$job_id" >/tmp/aicr-container-install-squeue.$$ 2>/dev/null && [[ -s /tmp/aicr-container-install-squeue.$$ ]]; do
  squeue -h -j "$job_id" -o '  %i %T %N'
  sleep 30
done
rm -f /tmp/aicr-container-install-squeue.$$

state="$(sacct -j "$job_id" --noheader --parsable2 --format=State 2>/dev/null | head -n 1 | cut -d'|' -f1 || true)"
exit_code="$(sacct -j "$job_id" --noheader --parsable2 --format=ExitCode 2>/dev/null | head -n 1 | cut -d'|' -f1 || true)"
echo "Slurm state: ${state:-unknown}"
echo "Exit code  : ${exit_code:-unknown}"

if [[ "${state:-}" != COMPLETED* || "${exit_code:-}" != "0:0" ]]; then
  echo
  echo "Last stdout lines:"
  tail -n 80 "${AICR_BMARK_DIR}/results/setup/container-install-${job_id}.out" 2>/dev/null || true
  echo
  echo "Last stderr lines:"
  tail -n 80 "${AICR_BMARK_DIR}/results/setup/container-install-${job_id}.err" 2>/dev/null || true
  exit 1
fi

echo
echo "Last stdout lines:"
tail -n 40 "${AICR_BMARK_DIR}/results/setup/container-install-${job_id}.out" 2>/dev/null || true
