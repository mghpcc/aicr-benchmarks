#!/bin/bash
export OMPI_MCA_pml=ucx
export UCX_WARN_UNUSED_ENV_VARS=n

echo "=== PAIR: w0005 <-> w0020 ==="
echo "--- H H ---"
srun --mpi=pmix --export=ALL --nodes=2 --ntasks=2 --ntasks-per-node=1 \
    apptainer exec --no-mount /etc/localtime --bind /usr/lib64/libibverbs:/usr/lib64/libibverbs --bind /etc/libibverbs.d:/etc/libibverbs.d /home/knevins/osu-benchmarks/osu-benchmarks.sif \
    /opt/hpc/osu/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_bibw -i 100 -x 10 -m 1:8388608 H H
