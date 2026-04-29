#!/bin/bash
#SBATCH --job-name=amd_hpl_cluster
#SBATCH --nodes=26
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=128
#SBATCH --time=04:00:00
#SBATCH --partition=compute
#SBATCH --exclusive
#SBATCH --output=slurm-%x.%J.%N.out

set -x

CONTAINER=/home/knevins/aicr-benchmarks/amd-zen-hpl.sif
APP_DIR=/opt/amd-hpl
HPL_DAT=${SLURM_SUBMIT_DIR}/config/HPL_cluster.dat

# Detect CPU topology from the head node (uniform across all compute nodes)
NT=$(lscpu | awk '/^Core\(s\) per socket:/{print $NF}')   # cores per socket → OMP threads per rank
NR=$(lscpu | awk '/^Socket\(s\):/{print $NF}')            # sockets → MPI ranks per node
TOTAL_RANKS=$((SLURM_NNODES * NR))                        # e.g. 28 nodes * 2 sockets = 56 ranks

APPTAINER_OPTS=(--no-mount /etc/localtime)
[[ -d /usr/lib64/libibverbs ]] && APPTAINER_OPTS+=(--bind /usr/lib64/libibverbs:/usr/lib64/libibverbs)
[[ -d /etc/libibverbs.d     ]] && APPTAINER_OPTS+=(--bind /etc/libibverbs.d:/etc/libibverbs.d)

unset OMPI_MCA_osc
export OMP_NUM_THREADS=${NT}

# srun distributes one rank per socket across all nodes via SLURM (no SSH needed).
# Each rank launches inside the container; MPI bootstraps via SLURM PMI/PMIx.
# --cpu-bind=cores pins each rank to its socket's physical cores.
srun \
    --ntasks=${TOTAL_RANKS} \
    --ntasks-per-node=${NR} \
    --cpus-per-task=${NT} \
    --cpu-bind=cores \
    apptainer exec \
        "${APPTAINER_OPTS[@]}" \
        --bind ${HPL_DAT}:${APP_DIR}/HPL.dat \
        --pwd ${APP_DIR} \
        ${CONTAINER} \
        ${APP_DIR}/xhpl
