#!/bin/bash

#SBATCH --job-name "Gromacs"
#SBATCH --nodes=1
#SBATCH --partition=rtx-batch
#SBATCH -w a0001
#SBATCH --time=30:00
#SBATCH --gpus=8
#SBATCH --ntasks=8
#SBATCH --cpus-per-task=16
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --output=slurm-%x.%J.%N.out


module --quiet purge
module --quiet load GROMACS/2024.6-foss-2024a-CUDA-12.8.0-PLUMED-2.9.3

# Run Gromacs in the /tmp space
BENCHDIR=/tmp/an492_yale/gromacs
mkdir -p ${BENCHDIR}
cp lignocellulose.tpr ${BENCHDIR}
cd ${BENCHDIR}

echo "Running on host: $(echo $(scontrol show hostname))"

# Run Gromacs benchmark
gmx mdrun \
    -s lignocellulose.tpr \
    -deffnm ${BENCHDIR}/gromacs_$SLURM_JOBID \
    -cpt 10000 \
    -maxh 1.0 \
    -nsteps 400000 \
    -nb gpu \
    -bonded gpu \
    -ntmpi 8 \
    -ntomp 16 

