#!/bin/bash
#SBATCH -p GPU2  # GPU1
#SBATCH -t 100
#SBATCH -N 2
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=8
#SBATCH --mem=200GB
#SBATCH --gpu-bind=closest
#SBATCH -J nvhpc-26.3-sharp
#SBATCH -o out-2node/%x-%N-%J
#SBATCH --exclusive

# Same as 2nodes-8gpus.sh but with SHARP CollNet offload enabled.
# Expected effect: AllReduce busbw should jump from ~170 GB/s to ~340 GB/s
# (in-network reduction bypasses the RS+AG two-pass GDRDMA bidir bottleneck).
# Other collectives are not SHARP-accelerated and should be unchanged.

# Use the original build; SHARP is a runtime configuration, not a build-time one.
BUILD_DIR=../build-nvhpc-26.3

module load nvhpc/26.3
export NVHPC_HOME=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3
export CUDA_HOME="$NVHPC_HOME/cuda"
export NCCL_HOME="$NVHPC_HOME/comm_libs/nccl"
export SHARP_HOME="$NVHPC_HOME/comm_libs/13.1/hpcx/hpcx-2.25.1/sharp"
# nccl_rdma_sharp_plugin provides libnccl-net.so (the IBext NCCL net plugin).
# Without it on LD_LIBRARY_PATH, NCCL prints "NET/Plugin: Could not find: libnccl-net.so"
# and silently falls back to its built-in NET/IB transport, which has no CollNet/SHARP
# support. Symptom: CollNetChain shows non-zero bandwidth in the NCCL tuning table
# (because the algorithm code exists), but forcing NCCL_ALGO=CollNetChain crashes with
# "no algorithm/protocol available" -- there is no actually-wired CollNet net.
# (see out-2node/nvhpc-26.3-sharp-b0001-16185)
export NCCL_PLUGIN_HOME="$NVHPC_HOME/comm_libs/13.1/hpcx/hpcx-2.25.1/nccl_rdma_sharp_plugin"
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$NCCL_HOME/lib:$NCCL_PLUGIN_HOME/lib:$SHARP_HOME/lib:$LD_LIBRARY_PATH

# IBext (nccl_rdma_sharp_plugin) must remain as the net plugin for SHARP CollNet
# to activate. Do NOT set NCCL_NET=IB -- that disables the SHARP plugin.

mpirun hostname
which mpirun
which nvcc
echo "Bin dir = $BUILD_DIR"

# Diagnostic: probe each NDR NIC with sharp_hello to find which are SHARP-enabled.
# An OK NIC prints "Initialized SHARP context" and exits 0; a non-SHARP NIC prints
# "Unknown port" or other error and exits non-zero. Use the OK list as the value
# of NCCL_IB_HCA. Runs only on the first node (b0029) since the SHARP fabric is
# uniform across nodes.
SHARP_HELLO=$SHARP_HOME/bin/sharp_hello
echo "%%%%%%%%% sharp_hello probe (which NICs are SHARP-enabled?) %%%%%%%%%%"
for hca in mlx5_0 mlx5_1 mlx5_2 mlx5_3 mlx5_4 mlx5_5 mlx5_6 mlx5_11 mlx5_12; do
   out=$($SHARP_HELLO -d ${hca}:1 2>&1)
   if echo "$out" | grep -q "Unknown port\|ERROR\|fatal"; then
      echo "  $hca:1  ->  NOT SHARP-enabled  ($(echo "$out" | grep -m1 -E 'Unknown port|ERROR|fatal'))"
   else
      echo "  $hca:1  ->  OK"
   fi
done
echo "%%%%%%%%% end sharp_hello probe %%%%%%%%%%"

MIN_SIZE=1M
MAX_SIZE=16G
FACTOR=4
GPUS_PER_TASK=8

echo "num_cpu = num_mpi_tasks = $SLURM_NTASKS"
echo "num_gpu_per_task = $GPUS_PER_TASK"

# SHARP activation: offload AllReduce reduction to IB switch hardware.
export NCCL_COLLNET_ENABLE=1
export SHARP_COLL_LOCK_ON_COMM_INIT=1

# Force NCCL to pick CollNet algorithm for AllReduce. This NCCL 2.29.3 build uses
# camelCase token names: CollNetChain, CollNetDirect, Tree, Ring, NVLS, NVLSTree.
# UPPERCASE_UNDERSCORE forms (e.g. COLLNET_CHAIN) are rejected with
# "Unrecognized element token" and -- when combined with NCCL_PROTO=Simple --
# cause every benchmark to crash with "invalid usage" rather than falling back
# (see out-2node/nvhpc-26.3-sharp-b0002-16169). List CollNet variants first so
# NCCL prefers them; keep Tree/Ring as fallback in case CollNet init fails.
# SHARP requires the Simple data protocol (LL/LL128 are not CollNet-compatible).
export NCCL_ALGO=CollNetChain,CollNetDirect,Tree,Ring
export NCCL_PROTO=Simple

# Exclude the 4 100 Gb/s management NICs (mlx5_7..mlx5_10) from NCCL. The 9 NDR NICs
# (mlx5_0..6, mlx5_11, mlx5_12) are confirmed SHARP-enabled by the sharp_hello probe.
#
# Why exclusion syntax instead of an inclusion list: NCCL_IB_HCA uses PREFIX matching
# in inclusion mode, so "mlx5_1" matches mlx5_1, mlx5_10, mlx5_11, mlx5_12 -- which
# silently lets mlx5_10 (a non-SHARP mgmt NIC) into the active set, causing sharpd
# to fail with "Unknown port" and CollNet init to abort with -11.
# (see out-2node/nvhpc-26.3-sharp-b0001-16187: NET/IB used [...] [7]mlx5_10:1/IB/SHARP)
# The "^" prefix switches to exact-match exclusion, which leaves no ambiguity.
export NCCL_IB_HCA="^mlx5_7,mlx5_8,mlx5_9,mlx5_10"

# SHARP plugin dlopens unversioned libnuma.so; the system only ships libnuma.so.1.
# Preload it so socket-grouping uses the real libnuma instead of the manual fallback.
# Plain bash export does not propagate through Open MPI's mpirun to remote ranks --
# we forward it explicitly via -x below.
export LD_PRELOAD=/lib64/libnuma.so.1${LD_PRELOAD:+:$LD_PRELOAD}

# Verbose NCCL logging: include COLL subsys to see the algorithm decision NCCL makes
# for AllReduce. After the run, grep for "AllReduce" + "CollNet" or look for
# "Channel ... AllReduce algorithm = CollNet" to confirm CollNet was selected.
# Comment the next two lines out once SHARP performance is verified.
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=NET,COLL,TUNING

# SHARP debug logging. Levels: 0=fatal, 1=error, 2=warn (default), 3=info, 4=debug, 5=trace.
# Need level 4 here -- level 3 confirmed 7 of 8 ranks per node successfully create SHARP
# jobs (sharp_job_id:1 tree_type:LLT...) but rank 7 on each node always fails with
# "Unknown port" without naming which port. Level 4 prints the LID/HCA the plugin
# presented to sharpd, which identifies the offending NIC so we can drop it from
# NCCL_IB_HCA. (see out-2node/nvhpc-26.3-sharp-b0001-16192: 140 SHARP successes / 20
# failures -- failures all on rank [7], i.e. the 8th GPU's mapped NIC.)
export SHARP_COLL_LOG_LEVEL=4

# All NCCL/SHARP env vars that must reach every rank on every node. Open MPI strips
# env by default; -x explicitly forwards each one.
#
# IMPORTANT: use the "-x VAR=$VAR" form rather than "-x VAR". The latter is supposed
# to forward the launching shell's value, but in this HPC-X-based mpirun build it
# silently fails for some vars (NCCL_IB_HCA was set in the launching shell but
# NCCL still saw all 13 NICs in out-2node/nvhpc-26.3-sharp-b0002-16162). The
# explicit "VAR=value" form bakes the value into the launch command and works
# reliably.
MPI_ENV_FORWARD="-x LD_PRELOAD=$LD_PRELOAD \
                 -x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
                 -x NCCL_IB_HCA=$NCCL_IB_HCA \
                 -x NCCL_COLLNET_ENABLE=$NCCL_COLLNET_ENABLE \
                 -x SHARP_COLL_LOCK_ON_COMM_INIT=$SHARP_COLL_LOCK_ON_COMM_INIT \
                 -x NCCL_ALGO=$NCCL_ALGO \
                 -x NCCL_PROTO=$NCCL_PROTO \
                 -x NCCL_DEBUG=$NCCL_DEBUG \
                 -x NCCL_DEBUG_SUBSYS=$NCCL_DEBUG_SUBSYS \
                 -x SHARP_COLL_LOG_LEVEL=$SHARP_COLL_LOG_LEVEL"

# Run all benchmarks except AllReduce with Tree+Ring available (CollNet not forced).
# NCCL's static bandwidth model rates CollNetChain at ~69 GB/s vs Ring at ~204 GB/s,
# so without forcing it NCCL always picks Ring even when SHARP would win.
# AllReduce is run separately with Ring removed from NCCL_ALGO so NCCL must use CollNet.
# (see out-2node/nvhpc-26.3-sharp-b0001-16179: AllReduce ran Ring/Simple at 218 GB/s;
#  CollNet was initialized (69.2 GB/s model estimate) but tuner always chose Ring.)
for program in sendrecv_perf reduce_perf broadcast_perf gather_perf scatter_perf reduce_scatter_perf all_gather_perf alltoall_perf hypercube_perf
do
   echo "%%%%%%%%% $program %%%%%%%%%%"
   mpirun -np $SLURM_NTASKS $MPI_ENV_FORWARD --mca btl_openib_warn_no_device_params_found 0 $BUILD_DIR/$program -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK
done

# AllReduce: force CollNetChain,CollNetDirect only -- Ring excluded so NCCL must use SHARP.
# This overrides the NCCL_ALGO already in MPI_ENV_FORWARD with the explicit -x below.
echo "%%%%%%%%% all_reduce_perf (CollNetChain forced -- SHARP path) %%%%%%%%%%"
mpirun -np $SLURM_NTASKS $MPI_ENV_FORWARD -x NCCL_ALGO=CollNetChain,CollNetDirect --mca btl_openib_warn_no_device_params_found 0 $BUILD_DIR/all_reduce_perf -b $MIN_SIZE -e $MAX_SIZE -f $FACTOR -g $GPUS_PER_TASK
