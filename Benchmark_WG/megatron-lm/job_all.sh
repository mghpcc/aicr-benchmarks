#!/bin/bash
#SBATCH -p GPU2
#SBATCH --job-name=megatron
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --mem=100GB
#SBATCH --gpus-per-node=1
#SBATCH -t 03:00:00
#SBATCH -o output/out.%N-%J
#SBATCH --exclusive

# Universal job script: drop-in replacement for job.sh that works for every
# (#nodes, #GPUs/node) combination submit.sh exercises:
#
#   1 x 1, 1 x 2, 1 x 4, 1 x 8       -- previously OK
#   2 x 8                            -- previously OK
#   2 x 1, 2 x 2, 2 x 4              -- previously HUNG with a 600 s
#                                       store->get('1') NCCL timeout
#
# Why the partial-node 2-node configs hung on the original job.sh:
#   APPTAINERENV_CUDA_VISIBLE_DEVICES=$SLURM_JOB_GPUS is unreliable on this
#   cluster (no cgroup ConstrainDevices), so the container saw all 8 GPUs.
#   torch.cuda.device_count() was 8 inside the container, the launcher
#   picked cudaDev = global_rank % 8, and node-1 ranks ended up on a
#   different cudaDev than node-0 ranks (asymmetric whenever world_size < 8).
#   PyTorch keys per-cudaDev sub-NCCL-comms lazily; the second collective
#   then deadlocked waiting for a uniqueID that the broadcaster never wrote.
#   The 2x8 case escaped because rank % 8 collapses to 0..7 on both nodes.
#
# Why this script works for every case:
#   APPTAINERENV_CUDA_VISIBLE_DEVICES is set to a deterministic list
#   "0,1,...,N_GPUS-1" -- the SAME value on every node. Therefore:
#     * device_count() inside the container == N_GPUS (matches the
#       allocation, regardless of what SLURM_JOB_GPUS reports);
#     * Megatron's set_device(LOCAL_RANK) picks 0..N_GPUS-1 on every node;
#     * rank<->cudaDev is symmetric across nodes for any world_size.
#   The single-node configs are unaffected (device_count was already correct
#   there) and the 2x8 case behaves identically to before.
#
# Safety: depends on #SBATCH --exclusive (above). With sole node ownership
# the first N_GPUS device indices are guaranteed free of co-tenants. If
# --exclusive is ever removed, restore SLURM_JOB_GPUS-based pinning AND
# require admin-side cgroup GPU isolation first.
#
# Usage (identical to job.sh):
#   sbatch -p GPU1 -N 1 -n 1 --gpus-per-node=rtx6000:1 job_all.sh 128
#   sbatch -p GPU1 -N 2 -n 2 --gpus-per-node=rtx6000:4 job_all.sh 1024
#   sbatch -p GPU2 -N 2 -n 2 --gpus-per-node=b200:2    job_all.sh 512

GBS=${1:?ERROR: global batch size must be passed as first argument to job_all.sh}

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

# Master node IP for c10d rendezvous (used only when N_NODES > 1).
nodes=( $( scontrol show hostnames $SLURM_JOB_NODELIST ) )
master_node=${nodes[0]}
master_node_ip=$(srun --nodes=1 --ntasks=1 -w "$master_node" hostname --ip-address)
echo $master_node_ip

echo "====================================="

# Deterministic CVD list -> "0", "0,1", "0,1,2,3", or "0,1,2,3,4,5,6,7".
# Identical on every node so rank-to-cudaDev mapping is symmetric.
CVD_LIST=$(seq -s, 0 $((N_GPUS - 1)))

srun bash -c "
    echo \"CUDA_VISIBLE_DEVICES (in container, \$(hostname)) = $CVD_LIST\"
    APPTAINERENV_CUDA_VISIBLE_DEVICES=$CVD_LIST \
    apptainer exec \
        --nv --contain --cleanenv \
        --bind ${megatron_path} \
        --bind /dev/infiniband \
        --bind /sys/class/infiniband \
        --bind /sys/class/infiniband_verbs \
        '${imag_path}/pytorch_26.02-py3.sif' \
        ${megatron_path}/run.sh  $N_NODES  $N_GPUS  $master_node_ip  $GPU_TYPE  $GBS
"
