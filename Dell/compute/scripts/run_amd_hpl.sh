#!/bin/bash
#SBATCH --job-name=amd_hpl
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --time=02:00:00
#SBATCH --partition=compute
#SBATCH --exclusive
#SBATCH --output=slurm-%x.%J.%N.out

set -x

#CONTAINER=/scratch/amd-zen-hpl.sif
CONTAINER=/home/knevins/aicr-benchmarks/amd-zen-hpl.sif
APP_DIR=/opt/amd-hpl
HPL_DAT=${SLURM_SUBMIT_DIR}/config/HPL.dat

# Detect CPU topology from the host (container sees the same /proc)
NT=$(lscpu | awk '/^Core\(s\) per socket:/{print $NF}')   # cores per socket → OMP threads per rank
NR=$(lscpu | awk '/^Socket\(s\):/{print $NF}')            # sockets → MPI rank count

MPIRUN=/opt/hpc/openmpi/bin/mpirun

APPTAINER_OPTS=(--no-mount /etc/localtime)
[[ -d /usr/lib64/libibverbs ]] && APPTAINER_OPTS+=(--bind /usr/lib64/libibverbs:/usr/lib64/libibverbs)
[[ -d /etc/libibverbs.d     ]] && APPTAINER_OPTS+=(--bind /etc/libibverbs.d:/etc/libibverbs.d)

# mpirun inside the container handles process placement.
# --map-by socket:PE=${NT}  one rank per socket, NT PEs (cores) per rank
# --bind-to core            pin each rank to its physical cores
# -wdir ${APP_DIR}          xhpl reads HPL.dat from its working directory
unset OMPI_MCA_osc

srun -N1 --ntasks=1 \ 
    apptainer exec \
    "${APPTAINER_OPTS[@]}" \
    --bind ${HPL_DAT}:${APP_DIR}/HPL.dat \
    ${CONTAINER} \
    ${MPIRUN} \
        --map-by socket:PE=${NT} \
        --bind-to core \
        -np ${NR} \
        -wdir ${APP_DIR} \
        -x OMP_NUM_THREADS=${NT} \
        ${APP_DIR}/xhpl
