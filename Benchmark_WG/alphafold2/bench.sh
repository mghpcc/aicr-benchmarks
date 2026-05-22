#!/bin/bash -l

# what GPUs are here...
nvidia-smi



cd bin
# Fetch the Singularity container
if [ ! -f "colabfold_1.6.0-cuda12.sif" ]; then
    echo Fetching Docker container.
    singularity pull docker://ghcr.io/sokrypton/colabfold:1.6.0-cuda12
fi

# Is the cache directory here? If not, fetch it.
if [ ! -d "cache" ]; then
    mkdir cache
    singularity run -B $PWD/cache:/cache \
        colabfold_1.6.0-cuda12.sif \
        python -m colabfold.download
fi

export APPTAINERENV_PYTHONUNBUFFERED=1

mkdir ../out-${SLURM_JOB_PARTITION}
# and...run it. The unified memory is disabled otherwise it 
# won't run on the B200. It's not clear why, as no error messages
# are provided.
time srun ./colabfold_batch --disable-unified-memory  ../aicr_msa ../out-${SLURM_JOB_PARTITION}



