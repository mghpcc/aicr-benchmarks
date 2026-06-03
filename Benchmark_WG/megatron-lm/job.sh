#!/bin/bash
#SBATCH -p b200-batch
#SBATCH --job-name=megatron
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --mem=100GB
#SBATCH --gpus-per-node=1
#SBATCH -t 03:00:00
#SBATCH -o output/out.%N-%J
#SBATCH --exclusive

# $1 = global batch size (passed from submit.sh)
GBS=${1:?ERROR: global batch size must be passed as first argument to job.sh}

which apptainer

export work_path="/home/shaohao_mit/benchmarks/megatron-lm"
export megatron_path="$work_path/Megatron-LM"
export imag_path="$work_path/imag"

N_NODES=$SLURM_NNODES
GPU_TYPE=$(echo $SLURM_GPUS_PER_NODE | awk -F: '{print $1}')
N_GPUS=$(echo $SLURM_GPUS_PER_NODE | awk -F: '{print $2}')
echo "===== Number of nodes = $N_NODES ====="
echo "===== Number of GPUs per node = $N_GPUS ====="
echo "===== Host names: $SLURM_NODELIST ======"
echo "===== GPU TYPE: $GPU_TYPE ======"
echo "===== Global batch size = $GBS ====="
srun hostname

# Get IP address of master node
nodes=( $( scontrol show hostnames $SLURM_JOB_NODELIST ) )
nodes_array=($nodes)
master_node=${nodes_array[0]}
master_node_ip=$(srun --nodes=1 --ntasks=1 -w "$master_node" hostname --ip-address)
echo $master_node_ip

echo "====================================="
# --contain blocks host $HOME mounts that may conflict with internal libraries
# --cleanenv avoids importing host user-site Python packages
if [ "$N_GPUS" -eq 1 ]; then
    # With 1 GPU per node, hardcode CUDA_VISIBLE_DEVICES=0 to avoid NCCL hangs.
    # PyTorch maps rank N -> GPU N by default, causing rank 0 and rank 1 to pick
    # different cudaDev indices and deadlock during communicator setup.
    # SLURM_JOB_GPUS is unreliable here because the cluster has no cgroup isolation.
    srun bash -c "
        echo \"CUDA_VISIBLE_DEVICES (in container, \$(hostname)) = 0\"
        APPTAINERENV_CUDA_VISIBLE_DEVICES=0 \
        apptainer exec \
            --nv --contain --cleanenv \
            --bind ${megatron_path} \
            --bind /dev/infiniband \
            --bind /sys/class/infiniband \
            --bind /sys/class/infiniband_verbs \
            '${imag_path}/pytorch_26.02-py3.sif' \
            ${megatron_path}/run.sh  $N_NODES  $N_GPUS  $master_node_ip  $GPU_TYPE  $GBS
    "
else
    # Pin each task to the GPU(s) SLURM allocated on *that node*.
    # SLURM_JOB_GPUS is evaluated inside the srun task (escaped \$) so each node
    # gets its own GPU list, not the master node's list (which broke multi-node jobs).
    # Cluster doesn't isolate GPUs via cgroup, so without this pinning co-located
    # jobs all default to GPU 0 and OOM each other.
    srun bash -c "
        echo \"CUDA_VISIBLE_DEVICES (in container, \$(hostname)) = \$SLURM_JOB_GPUS\"
        APPTAINERENV_CUDA_VISIBLE_DEVICES=\$SLURM_JOB_GPUS \
        apptainer exec \
            --nv --contain --cleanenv \
            --bind ${megatron_path} \
            --bind /dev/infiniband \
            --bind /sys/class/infiniband \
            --bind /sys/class/infiniband_verbs \
            '${imag_path}/pytorch_26.02-py3.sif' \
            ${megatron_path}/run.sh  $N_NODES  $N_GPUS  $master_node_ip  $GPU_TYPE  $GBS
    "
fi
