#!/bin/bash
# Combined b200 + rtx submission for the fio peak-aggregate suite.
#
# Mirrors ../raw-io/submit.sh: re-check `sinfo` first, size the array so each
# partition has at least (NODES_PER × tasks) idle nodes (otherwise Slurm runs
# tasks in waves and the aggregate measurement does NOT reflect all tasks
# running simultaneously).
#
# Current sizing (assumes ~28 idle b200 + ~17 idle rtx ≈ 42 usable nodes):
#   13 b200 tasks × 2 nodes = 26 nodes  (--array=0-12)
#    8 rtx  tasks × 2 nodes = 16 nodes  (--array=13-20)
#   total: 21 concurrent tasks × 2 nodes = 42 concurrent nodes
#   ARRAY_SIZE=21 → 21 disjoint per-task data subdirs under DATA_ROOT.
#
# WORKLOAD picks what to measure (default seq_read; set "all" to run all four
# workloads in sequence within each task). RUNTIME=60 + RAMP_TIME=10 gives a
# 70 s window per workload — long enough to outlast Slurm task-launch jitter
# and a 5-second post-stonewall pause.

set -euo pipefail

TAG=fio_$(date +%s)
WORKLOAD="${WORKLOAD:-seq_read}"

# b200-batch: tasks 0-12 (13 × 2 nodes = 26 nodes)
ARRAY_SIZE=21 TAG=$TAG WORKLOAD=$WORKLOAD \
JOBS_PER_NODE=32 IODEPTH=64 SIZE_PER_JOB=16G RUNTIME=60 RAMP_TIME=10 \
    sbatch -p b200-batch -J fio_peak_b200 \
           -N 2 --ntasks-per-node=1 --cpus-per-task=96 \
           --array=0-12%13 peak_aggregate_fio.sh

# rtx-batch: tasks 13-20 (8 × 2 nodes = 16 nodes)
ARRAY_SIZE=21 TAG=$TAG WORKLOAD=$WORKLOAD \
JOBS_PER_NODE=32 IODEPTH=64 SIZE_PER_JOB=16G RUNTIME=60 RAMP_TIME=10 \
    sbatch -p rtx-batch  -J fio_peak_rtx  \
           -N 2 --ntasks-per-node=1 --cpus-per-task=96 \
           --array=13-20%8 peak_aggregate_fio.sh

echo "TAG=$TAG"
echo "WORKLOAD=$WORKLOAD"
echo "After BOTH arrays finish:"
echo "  python peak_aggregate_summary.py results-peak/$TAG"
echo ""
echo "To run all four workloads (seq write, seq read, rand write, rand read)"
echo "back to back inside each task:  WORKLOAD=all ./submit.sh"
