#!/bin/bash

#SBATCH --job-name "OpenMM"
#SBATCH --nodes=1
#SBATCH --partition=b200-batch
#SBATCH --time=40:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --output=slurm-%x.%J.%N.out


# Modules were installed in /work/yale/support
module --quiet purge
module --quiet load OpenMM/8.4.0-foss-2024a-CUDA-12.8.0

# Create a directory in /tmp to run benchmark in
BENCHDIR=/tmp/an492_yale/openmm
mkdir -p ${BENCHDIR}

# $EBROOTOPENMM is environment variable set by EasyBuild, which points to /work/yale/support/apps/software/OpenMM/8.4.0-foss-2024a-CUDA-12.8.0 in this case
# Copy the provided benchmarks directory to the /tmp space  
cp -r $EBROOTOPENMM/examples/benchmarks ${BENCHDIR}
cd ${BENCHDIR}/benchmarks

# Run Apolopoprotein A1 (ApoaA1) with Particle Mesh Ewald (PME) method to calculate the effect of solvent. Run 8 of these simulations on a single node (1 GPU each)
# Even though I give 16 cores for each job, it only uses 1.
for ((i=0; i<$SLURM_GPUS_ON_NODE; i++))
do
        srun -t 20:00 --mem=20G -n 1 -c $(($SLURM_CPUS_ON_NODE/$SLURM_GPUS_ON_NODE)) --gpus=1 python benchmark.py --test apoa1pme --seconds 200 --outfile out_$i.json --platform=CUDA &
done

wait

