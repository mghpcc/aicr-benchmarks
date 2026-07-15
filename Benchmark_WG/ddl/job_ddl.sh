#!/bin/bash
#SBATCH -p b200-batch
#SBATCH --job-name=ddl-fp8
#SBATCH -N 1
#SBATCH -n 1
#SBATCH --mem=200GB
#SBATCH --gpus-per-node=b200:8
#SBATCH -t 03:00:00
#SBATCH -o output/out.%N-%J
#SBATCH --exclusive

# Slurm wrapper for the FP8 + model-parallelism study. Same architecture as the
# proven megatron-lm/Megatron-LM/job_all.sh:
#   * deterministic CUDA_VISIBLE_DEVICES list, identical on every node, so the
#     rank->cudaDev mapping is symmetric for any (nodes x GPUs/node) shape
#     (fixes the 2-node sub-allocation NCCL rendezvous hang; requires --exclusive)
#   * apptainer --nv --contain --cleanenv with InfiniBand binds
#
# Usage:
#   sbatch [-p PART] [-N n] [-n n] [--gpus-per-node=b200:G] [-t T] [--output=...] \
#       job_ddl.sh MODEL PREC TP PP GBS [MBS] [ITERS] [SEED] [SHARP]
#
#   MODEL : 1.3b | 7b | 13b
#   PREC  : bf16 | fp8ds | fp8cs | mxfp8
#   TP,PP : tensor / pipeline parallel sizes
#   GBS   : global batch size (house convention: 128 x total GPUs)
#   MBS ITERS SEED SHARP : optional, default 4 / 100 / 1234 / 0
#
# Examples:
#   sbatch -N 1 -n 1 --gpus-per-node=b200:8 job_ddl.sh 7b fp8ds 1 1 1024
#   sbatch -N 2 -n 2 --gpus-per-node=b200:8 job_ddl.sh 7b bf16 1 2 2048
#   sbatch -N 4 -n 4 --gpus-per-node=b200:8 job_ddl.sh 13b fp8ds 8 2 4096 4 100 1234 1
#
# Extra bind paths (e.g. a dataset dir for convergence runs):
#   sbatch --export=ALL,EXTRA_BIND=/path/to/data ... job_ddl.sh ...

MODEL=${1:?usage: job_ddl.sh MODEL PREC TP PP GBS [MBS] [ITERS] [SEED] [SHARP]}
PREC=${2:?PREC required}
TP=${3:?TP required}
PP=${4:?PP required}
GBS=${5:?GBS required}
MBS=${6:-4}
ITERS=${7:-100}
SEED=${8:-1234}
SHARP=${9:-0}

which apptainer

export work_path="/home/shaohao_mit/benchmarks"
export megatron_path="$work_path/megatron-lm/Megatron-LM"
export ddl_path="$work_path/ddl"
export imag_path="$work_path/megatron-lm/imag"

N_NODES=$SLURM_NNODES
N_GPUS=$(echo $SLURM_GPUS_PER_NODE | awk -F: '{print $2}')
echo "===== nodes=$N_NODES  GPUs/node=$N_GPUS  hosts=$SLURM_NODELIST ====="
echo "===== model=$MODEL prec=$PREC TP=$TP PP=$PP GBS=$GBS MBS=$MBS iters=$ITERS seed=$SEED sharp=$SHARP ====="
srun hostname

# Master node IP for c10d rendezvous (used only when N_NODES > 1).
nodes=( $( scontrol show hostnames $SLURM_JOB_NODELIST ) )
master_node=${nodes[0]}
master_node_ip=$(srun --nodes=1 --ntasks=1 -w "$master_node" hostname --ip-address)
echo "master ip: $master_node_ip"
echo "====================================="

# Deterministic CVD list, identical on every node (see header).
CVD_LIST=$(seq -s, 0 $((N_GPUS - 1)))

BIND_FLAGS="--bind ${megatron_path} --bind ${ddl_path}"
if [ -n "$EXTRA_BIND" ]; then BIND_FLAGS="$BIND_FLAGS --bind ${EXTRA_BIND}"; fi

srun bash -c "
    echo \"CUDA_VISIBLE_DEVICES (in container, \$(hostname)) = $CVD_LIST\"
    APPTAINERENV_CUDA_VISIBLE_DEVICES=$CVD_LIST \
    apptainer exec \
        --nv --contain --cleanenv \
        $BIND_FLAGS \
        --bind /dev/infiniband \
        --bind /sys/class/infiniband \
        --bind /sys/class/infiniband_verbs \
        '${imag_path}/pytorch_26.02-py3.sif' \
        ${ddl_path}/run_ddl.sh $N_NODES $N_GPUS $master_node_ip \
            $MODEL $PREC $TP $PP $GBS $MBS $ITERS $SEED $SHARP
"
