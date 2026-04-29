#!/bin/bash
#SBATCH --job-name "run_hpl_mxp_8node"
#SBATCH --ntasks-per-node=8
#SBATCH --nodes=8
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:rtx6000:8
#SBATCH --partition=GPU1
#SBATCH --time=40:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --output=slurm-%x.%J.%N.out

set -x

DATESTRING=`date "+%Y-%m-%dT%H:%M:%S"`

SIF=/home/knevins/aicr-benchmarks/hpc-benchmarks_26.02.sif


DATESTRING=`date "+%Y-%m-%dT%H:%M:%S"`

echo "Running on hosts: $(echo $(scontrol show hostname))"
echo "$DATESTRING"

export UCX_NET_DEVICES=mlx5_0:1,mlx5_3:1
export APPTAINERENV_UCX_NET_DEVICES=mlx5_0:1,mlx5_3:1
# Force RC (Reliable Connected) transport — avoids DCI QP failures seen with DC transport
export UCX_TLS=self,shm,rc,cuda_copy,cuda_ipc
export APPTAINERENV_UCX_TLS=self,shm,rc,cuda_copy,cuda_ipc
#export NCCL_BUFFSIZE=4194304
#export NCCL_P2P_DISABLE=1
#export CUDA_P2P_LEVEL=0

N_SIZE=1140736
srun -N 8 --ntasks-per-node=8 --exclusive --mpi=pmix \
    apptainer exec --nv \
    --no-mount /etc/localtime \
    --bind /var/spool/slurm/slurmd \
    "${SIF}" \
    /workspace/hpl-mxp.sh \
    --gpu-affinity 0:1:2:3:4:5:6:7 \
    --n ${N_SIZE} \
    --nb 2048 --nporder row \
    --nprow 8 --npcol 8

echo "Done"
echo "$DATESTRING"

