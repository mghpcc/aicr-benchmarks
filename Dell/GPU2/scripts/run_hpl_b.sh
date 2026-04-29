#!/bin/bash
#SBATCH --job-name=run_hpl_b
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --time=02:00:00
#SBATCH --partition=GPU2
#SBATCH --gres=gpu:b200:8
#SBATCH --exclusive
#SBATCH --output=slurm-%x.%J.%N.out

SIF=/home/knevins/aicr-benchmarks/hpc-benchmarks_25.09.sif
HPL_DAT=${SLURM_SUBMIT_DIR}/config/HPL.B200.dat

echo Running on host `uname -n`

export UCX_POSIX_USE_PROC_LINK=n 
export UCX_TLS=posix,cma,ib
export HPL_USE_NVSHMEM=0
export HPL_CUSOLVER_MP_TESTS=0
export PMIX_MCA_gds=hash

#export APPTAINERENV_PMIX_MCA_gds=hash
#export APPTAINERENV_OMPI_MCA_pml=ucx
#export APPTAINERENV_OMPI_MCA_btl=^openib
#export APPTAINERENV_UCX_TLS=rc,sm,cuda_copy,cuda_ipc,self
#export APPTAINERENV_UCX_MEMTYPE_CACHE=n

srun --mpi=pmix \
    apptainer exec --nv \
    --no-mount /etc/localtime \
    --bind /var/spool/slurm/slurmd \
    --bind ${HPL_DAT}:/workspace/HPL.dat \
    ${SIF} \
    /workspace/hpl.sh --no-multinode --dat /workspace/HPL.dat