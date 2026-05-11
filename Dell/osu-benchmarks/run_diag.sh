#!/bin/bash
#SBATCH --job-name=osu-diag
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:10:00
#SBATCH --output=diag_%j_%N.out
#SBATCH --error=diag_%j_%N.err

# Standalone diagnostic job — verify UCX transports and libibverbs linkage inside the container.
# Usage: sbatch --partition=PART run_diag.sh

set -euo pipefail

CONTAINER="${CONTAINER:-/opt/containers/osu-benchmarks.sif}"
OSU_BIBW="/opt/hpc/osu/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_bibw"

[[ ! -f "$CONTAINER" ]] && { echo "ERROR: Container not found: $CONTAINER"; exit 1; }

echo "========================================================"
echo " OSU Diagnostics  |  $(hostname)  |  job ${SLURM_JOB_ID}"
echo " Started   : $(date)"
echo "========================================================"
echo

APPTAINER_OPTS=(--no-mount /etc/localtime)
[[ -d /usr/lib64/libibverbs ]] && APPTAINER_OPTS+=(--bind /usr/lib64/libibverbs:/usr/lib64/libibverbs)
[[ -d /etc/libibverbs.d     ]] && APPTAINER_OPTS+=(--bind /etc/libibverbs.d:/etc/libibverbs.d)

echo "── UCX transports ──"
srun --ntasks=1 --mpi=none \
    apptainer exec "${APPTAINER_OPTS[@]}" "${CONTAINER}" \
    ucx_info -d
echo

echo "── libibverbs linkage ──"
srun --ntasks=1 --mpi=none \
    apptainer exec "${APPTAINER_OPTS[@]}" "${CONTAINER}" \
    /bin/bash -c "ldd ${OSU_BIBW} | grep -i verbs || echo '(no verbs libs found)'"
echo

echo "========================================================"
echo " Completed : $(date)"
echo "========================================================"
