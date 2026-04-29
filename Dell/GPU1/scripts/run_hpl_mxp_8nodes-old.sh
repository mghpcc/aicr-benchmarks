#!/bin/bash
#SBATCH --job-name "run_hpl_mxp_8node"
#SBATCH --ntasks-per-node=8
#SBATCH --nodes=8
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:rtx6000:8
#SBATCH --partition=GPU1
#SBATCH --time=120:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --output=slurm-%x.%J.%N.out

set -x

DATESTRING=$(date "+%Y-%m-%dT%H:%M:%S")
SIF=/home/knevins/aicr-benchmarks/hpc-benchmarks_26.02.sif

echo "Running on hosts: $(scontrol show hostname | tr '\n' ' ')"
echo "$DATESTRING"

GPU_AFFINITY="0:1:2:3:4:5:6:7"
#for i in {1..7}
#do
#    GPU_AFFINITY="$GPU_AFFINITY:0:1:2:3:4:5:6:7"
#done

N_SIZE=1140736

srun -N 8 --ntasks-per-node=8 --cpu-bind=none --mpi=pmix \
    apptainer exec --nv \
    --no-mount /etc/localtime \
    --bind /var/spool/slurm/slurmd \
    "${SIF}" \
    /workspace/hpl-mxp.sh \
    --gpu-affinity ${GPU_AFFINITY} \
    --n ${N_SIZE} \
    --nb 4096 \
    --nprow 8 --npcol 8 --nporder row 

echo "Done"
echo "$(date "+%Y-%m-%dT%H:%M:%S")"