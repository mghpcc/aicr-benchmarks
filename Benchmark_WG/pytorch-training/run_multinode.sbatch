#!/bin/bash
#SBATCH --partition=GPU1
#SBATCH --job-name=bench_multinode
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:8
#SBATCH --cpus-per-task=64
#SBATCH --time=00:50:00
#SBATCH --output=logs/bench_multinode_%j.out
#SBATCH --error=logs/bench_multinode_%j.err
#SBATCH --exclude=a0016

set -euo pipefail
mkdir -p logs results

module purge
module load nvhpc
module load miniforge3
source activate myenv

# === Rendezvous setup ===
nodes=( $(scontrol show hostnames "$SLURM_JOB_NODELIST") )
head_node=${nodes[0]}
head_node_ip=$(srun --nodes=1 --ntasks=1 -w "$head_node" hostname --ip-address | awk '{print $1}')
RDZV_PORT=29500

echo "=== Multi-node setup ==="
echo "Job ID         : ${SLURM_JOB_ID}"
echo "Nodes          : ${SLURM_NNODES}"
echo "Node list      : ${SLURM_JOB_NODELIST}"
echo "Head node      : ${head_node} (${head_node_ip})"
echo "Rendezvous port: ${RDZV_PORT}"
echo "GPUs/node      : ${SLURM_GPUS_ON_NODE:-?}"
echo "========================"

# NCCL: start with INFO to confirm it picks the right interface, drop to WARN once you've verified.
export NCCL_DEBUG=INFO
# Tune if NCCL picks the wrong interface:
# export NCCL_SOCKET_IFNAME=ib0
# export NCCL_IB_HCA=mlx5

SCALING="${SCALING:-weak}"
PER_GPU_BS="${PER_GPU_BS:-256}"
GLOBAL_BS="${GLOBAL_BS:-2048}"
MODEL="${MODEL:-resnet50}"

NPROC=${SLURM_GPUS_ON_NODE:-8}
WORLD=$((SLURM_NNODES * NPROC))
TAG="${SLURM_NNODES}node_${NPROC}gpu_${WORLD}rank_${SCALING}_${MODEL}_${SLURM_JOB_ID}"
OUT="results/${TAG}.json"

srun --kill-on-bad-exit=1 bash -c "
    echo \"[\$(hostname)] launching torchrun, node_rank=\${SLURM_NODEID}\"
    torchrun \
        --nnodes=${SLURM_NNODES} \
        --nproc_per_node=${NPROC} \
        --node_rank=\${SLURM_NODEID} \
        --rdzv_id=${SLURM_JOB_ID} \
        --rdzv_backend=c10d \
        --rdzv_endpoint=${head_node_ip}:${RDZV_PORT} \
        benchmark_ddp.py \
            --scaling ${SCALING} \
            --batch-size-per-gpu ${PER_GPU_BS} \
            --global-batch-size ${GLOBAL_BS} \
            --model ${MODEL} \
            --precision bf16 \
            --warmup-sec 60 \
            --bench-sec 600 \
            --tag '${TAG}' \
            --output-json '${OUT}'
"
