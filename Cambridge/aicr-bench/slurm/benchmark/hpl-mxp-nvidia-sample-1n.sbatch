#!/bin/bash
#SBATCH --job-name "test-hpl-mxp.1N"
#SBATCH --time=40:00
#SBATCH --mem=0
#SBATCH --output=results/slurm/enroot-%x.%J.%N.out
#SBATCH --error=results/slurm/enroot-%x.%J.%N.err

DATESTRING=`date "+%Y-%m-%dT%H:%M:%S"`

CONT="${CONT:-/work/aicr/commissioning/benchmarks/runtime/apptainer/images/hpc-benchmarks-26.02.sif}"

DATESTRING=`date "+%Y-%m-%dT%H:%M:%S"`

echo "Running on hosts: $(echo $(scontrol show hostname))"
echo "$DATESTRING"

#FP16
sloppy_type=2
srun -N1 --ntasks-per-node=8 --cpu-bind=none --mem-bind=none --mpi=pmix \
      apptainer exec --no-mount /etc/localtime --bind /work:/work --nv "${CONT}" \
      /workspace/hpl-mxp.sh \
      --gpu-affinity 0:1:2:3:4:5:6:7 --mem-affinity 0:0:0:0:1:1:1:1 \
      --cpu-affinity 0-13:14-27:28-41:42-55:56-69:70-83:84-97:98-111 --ucx-affinity mlx5_0:mlx5_3:mlx5_4:mlx5_5:mlx5_6:mlx5_9:mlx5_10:mlx5_11 \
      --n 380000 --nb 2048 --nprow 4 --npcol 2 --nporder row \
      --preset-gemm-kernel 0 --u-panel-chunk-nbs 16  --use-mpi-panel-broadcast 50 --sloppy-type ${sloppy_type} \
      --call-dgemv-with-multiple-threads 0 --Anq-device 0 --mpi-use-mpi 1 --prioritize-trsm 0 --prioritize-factorization 1

#FP8
sloppy_type=1
srun -N1 --ntasks-per-node=8 --cpu-bind=none --mem-bind=none --mpi=pmix \
      apptainer exec --no-mount /etc/localtime --bind /work:/work --nv "${CONT}" \
      /workspace/hpl-mxp.sh \
      --gpu-affinity 0:1:2:3:4:5:6:7 --mem-affinity 0:0:0:0:1:1:1:1 \
      --cpu-affinity 0-13:14-27:28-41:42-55:56-69:70-83:84-97:98-111 --ucx-affinity mlx5_0:mlx5_3:mlx5_4:mlx5_5:mlx5_6:mlx5_9:mlx5_10:mlx5_11 \
      --n 380000 --nb 4096 --nprow 4 --npcol 2 --nporder row \
      --preset-gemm-kernel 0 --u-panel-chunk-nbs 8 --use-mpi-panel-broadcast 50 --sloppy-type ${sloppy_type} \
      --call-dgemv-with-multiple-threads 0 --Anq-device 0 --mpi-use-mpi 1 --prioritize-trsm 0 --prioritize-factorization 1


echo "Done"
echo "$DATESTRING"
