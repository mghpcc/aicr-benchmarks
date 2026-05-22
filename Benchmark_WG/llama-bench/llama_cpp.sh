#!/bin/bash
#SBATCH --job-name "llama-bench"
#SBATCH --nodes=1
#SBATCH --partition=rtx-devel
#SBATCH --time=40:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --output=/dev/null

module --quiet purge
module --quiet load llama.cpp/b8083-foss-2024a-CUDA-12.8.0

host=$(echo $(scontrol show hostname))
echo "Running on host: ${host}"
mkdir ${host}
cd ${host}



# Copy the .sif file and the model to /tmp space
BENCHDIR=/tmp/an492_yale/inference
mkdir -p ${BENCHDIR}
rsync -a ../llama.cpp ${BENCHDIR}

export modp=${BENCHDIR}/llama.cpp/bartowski_Meta-Llama-3.1-70B-Instruct-GGUF_Meta-Llama-3.1-70B-Instruct-Q4_K_M.gguf


for ((i=0; i<$SLURM_GPUS_ON_NODE; i++))
do
     CUDA_VISIBLE_DEVICES=$i srun -n 1 -c $(($SLURM_CPUS_ON_NODE/$SLURM_GPUS_ON_NODE)) --gpus=1 llama-bench -m $modp -pg 512,128 -t $(($SLURM_CPUS_ON_NODE/$SLURM_GPUS_ON_NODE)) &> llama_${i}_$SLURM_JOBID.log &
done

wait


