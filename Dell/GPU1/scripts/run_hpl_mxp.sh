#!/bin/bash
#SBATCH --job-name "run_hpl_mxp"
#SBATCH --ntasks-per-node=8
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --gres=gpu:rtx6000:8
#SBATCH --partition=GPU1
#SBATCH --time=40:00
#SBATCH --exclusive
#SBATCH --mem=0
#SBATCH --output=slurm-%x.%J.%N.out

set -x

DATESTRING=`date "+%Y-%m-%dT%H:%M:%S"`

SIF=/home/knevins/aicr-benchmarks/hpc-benchmarks_25.09.sif


DATESTRING=`date "+%Y-%m-%dT%H:%M:%S"`

echo "Running on hosts: $(echo $(scontrol show hostname))"
echo "$DATESTRING"

export UCX_NET_DEVICES=mlx5_0:1,mlx5_3:1
export NCCL_BUFFSIZE=4194304
export NCCL_P2P_DISABLE=1
export CUDA_P2P_LEVEL=0
export UCX_TLS=self,shm,cuda_copy

N_SIZE=430080
srun -N1 --ntasks-per-node=8 --exclusive --mpi=pmix \
    apptainer exec --nv \
    --no-mount /etc/localtime \
    --bind /var/spool/slurm/slurmd \
    "${SIF}" \
    /workspace/hpl-mxp.sh \
    --gpu-affinity 0:1:2:3:4:5:6:7 \
    --n ${N_SIZE} \
    --nb 2048 --nporder row \
    --nprow 4 --npcol 2 \
    --sloppy-type 2 \
    --preset-gemm-kernel 0 --u-panel-chunk-nbs 16  --use-mpi-panel-broadcast 50 \
    --call-dgemv-with-multiple-threads 0 --Anq-device 0 --mpi-use-mpi 1 --prioritize-trsm 0 --prioritize-factorization 1

#FP16
#sloppy_type=2
#srun -N1 --ntasks-per-node=8 --cpu-bind=none --mem-bind=none --mpi=pmix \
#      apptainer exec --nv --no-mount /etc/localtime \
#      --bind /var/spool/slurm/slurmd "${CONT}" \
#      /workspace/hpl-mxp.sh \
#      --gpu-affinity 0:1:2:3:4:5:6:7 --mem-affinity 0:0:0:0:1:1:1:1 \
#      --cpu-affinity 0-15:16-31:32-47:48-63:64-79:80-95:96-111:112-127 \
#      --n 380000 --nb 2048 --nprow 4 --npcol 2 --nporder row \
#      --preset-gemm-kernel 0 --u-panel-chunk-nbs 16  --use-mpi-panel-broadcast 50 --sloppy-type ${sloppy_type} \
#      --call-dgemv-with-multiple-threads 0 --Anq-device 0 --mpi-use-mpi 1 --prioritize-trsm 0 --prioritize-factorization 1

#FP8
#sloppy_type=1
#srun  -N1 --ntasks-per-node=8 --cpu-bind=none --mem-bind=none --mpi=pmix \
#      apptainer exec --nv --no-mount /etc/localtime \
#      --bind /var/spool/slurm/slurmd "${CONT}" \
#      /workspace/hpl-mxp.sh \
#      --gpu-affinity 0:1:2:3:4:5:6:7 --mem-affinity 0:0:0:0:1:1:1:1 \
#      --cpu-affinity 0-15:16-31:32-47:48-63:64-79:80-95:96-111:112-127 \
#      --n 380000 --nb 4096 --nprow 4 --npcol 2 --nporder row \
#      --preset-gemm-kernel 0 --u-panel-chunk-nbs 8 --use-mpi-panel-broadcast 50 --sloppy-type ${sloppy_type} \
#      --call-dgemv-with-multiple-threads 0 --Anq-device 0 --mpi-use-mpi 1 --prioritize-trsm 0 --prioritize-factorization 1


echo "Done"
echo "$DATESTRING"

