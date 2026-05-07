#!/bin/bash
#SBATCH --job-name=osu-bibw
#SBATCH --partition=CPU1              # update to your partition
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:30:00
#SBATCH --output=bibw_%j_%N.out
#SBATCH --error=bibw_%j_%N.err
#SBATCH --exclusive

set -euo pipefail

CONTAINER="${CONTAINER:-/opt/containers/osu-benchmarks.sif}"
OSU_BIBW="/opt/hpc/osu/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_bibw"
MSG_MIN=1
MSG_MAX=$((8 * 1024 * 1024))
ITERATIONS=100
WARMUP=10

[[ ! -f "$CONTAINER" ]] && { echo "ERROR: Container not found: $CONTAINER"; exit 1; }

echo "========================================================"
echo " OSU BIBW  |  ${SLURM_JOB_NODELIST}  |  job ${SLURM_JOB_ID}"
echo " Started   : $(date)"
echo "========================================================"
echo

export OMPI_MCA_pml=ucx
export UCX_WARN_UNUSED_ENV_VARS=n
# Uncomment to pin UCX to a specific HCA: export UCX_NET_DEVICES=mlx5_0:1

MPI_TYPE="${MPI_TYPE:-pmix}"
BENCH_FLAGS="-i ${ITERATIONS} -x ${WARMUP} -m ${MSG_MIN}:${MSG_MAX}"

APPTAINER_OPTS=(--no-mount /etc/localtime)
[[ -d /usr/lib64/libibverbs ]] && APPTAINER_OPTS+=(--bind /usr/lib64/libibverbs:/usr/lib64/libibverbs)
[[ -d /etc/libibverbs.d     ]] && APPTAINER_OPTS+=(--bind /etc/libibverbs.d:/etc/libibverbs.d)

srun \
    --mpi=${MPI_TYPE} \
    --export=ALL \
    --nodes=2 \
    --ntasks=2 \
    --ntasks-per-node=1 \
    apptainer exec "${APPTAINER_OPTS[@]}" "${CONTAINER}" \
        "${OSU_BIBW}" ${BENCH_FLAGS} H H

echo
echo "========================================================"
echo " Completed : $(date)"
echo "========================================================"
