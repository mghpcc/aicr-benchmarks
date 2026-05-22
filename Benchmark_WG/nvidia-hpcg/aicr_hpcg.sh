#!/bin/bash

mkdir -p logs

DATESTRING=`date "+%Y-%m-%dT%H:%M:%S"`

echo "Running on hosts: $(echo $(scontrol show hostname))"
echo "$DATESTRING"

module load openmpi/4.1.8-gcc-12.5.0-cuda-13.1.1

NVHPC_HOME=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3

#export LD_LIBRARY_PATH=${NVHPC_HOME}/comm_libs/13.1/hpcx/hpcx-2.25.1/ompi/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=${NVHPC_HOME}/math_libs/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=${NVHPC_HOME}/comm_libs/nccl/lib:$LD_LIBRARY_PATH

run_script=./bin/hpcg.sh

#srun $run_script --p2p 2 --ucx-tls "rc,cuda_copy,cuda_ipc,sm"  --b 1 --dat ./config.dat 
# Run using CUDA-aware MPI
srun $run_script --p2p 2  --b 1 --dat ./config.dat 

 

echo "Done"
echo "$DATESTRING"
