BUILD_DIR=build-nvhpc-26.3
rm -rf $BUILD_DIR

module load gcc/12.5.0 nvhpc/26.3
which mpirun

NVHPC_HOME=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3
make MPI=1 MPI_HOME=${NVHPC_HOME}/comm_libs/13.1/hpcx/hpcx-2.25.1/ompi CUDA_HOME=$NVHPC_HOME/cuda  NCCL_HOME=$NVHPC_HOME/comm_libs/nccl

mv build $BUILD_DIR
