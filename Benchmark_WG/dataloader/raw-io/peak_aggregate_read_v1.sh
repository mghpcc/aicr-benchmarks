#!/bin/bash
# v1 — original peak-aggregate-read script (no REPEATS). This is the version
# that produced the run logged in results-peak/out.summary-2 (28 tasks × 2
# nodes, ITERS=15, TOTAL_SIZE=32G, peak iter-14 sum = 254.91 GB/s).
#
# v2 (peak_aggregate_read_v2.sh) adds a REPEATS env var that multiplies the
# shard.index so each iter is longer; useful when the dataset is small and
# Slurm task-launch jitter is large.
#
# Job array to maximize aggregate read throughput across the Vast cluster.
#
# Recipe:
#   - Submit many independent jobs concurrently (job array), each on a few nodes.
#   - Each task reads a DIFFERENT shard of the ImageNet class tree (no cache overlap).
#   - Stock NFS mounts already use nconnect=16 (see `nfsstat -m`), so each task
#     already drives its assigned CBOX with multiple parallel TCP/RDMA streams.
#   - The Slurm scheduler spreads array tasks across hosts, and the NFS VIP pool
#     DNS-round-robins mounts across the 16 CBOXes, so the aggregate naturally
#     fans out across the cluster.
#
# Tunables (override via env or sbatch --export):
#   ARRAY_SIZE   number of concurrent array tasks (default 16)
#   NODES_PER    nodes per array task (default 2)
#   CPU_PER_NODE worker procs per node (default 96)
#   TOTAL_SIZE   bytes read per rank per iter (default 8G — keep modest so all
#                tasks finish near-simultaneously and the aggregate window
#                actually overlaps)
#   ITERS        iterations per task (default 3)
#   TAG          subdir name under results-peak/ (default ts of submit)
#
# Usage (from /home/shaohao_mit/benchmarks/raw-io/):
#   # default: b200-batch, 16 tasks × 2 nodes
#   sbatch --array=0-15%16 peak_aggregate_read_v1.sh
#
#   # rtx-batch (override partition via sbatch -p; -J keeps stdout files clean):
#   sbatch -p rtx-batch -J vast_peak_read_rtx --array=0-7%8 peak_aggregate_read_v1.sh
#
#   # with env overrides:
#   ARRAY_SIZE=20 NODES_PER=2 sbatch --array=0-19%20 peak_aggregate_read_v1.sh
#
# After the array finishes:
#   python peak_aggregate_summary.py results-peak/<TAG>
#
#SBATCH -p b200-batch
#SBATCH -N 2
#SBATCH --ntasks-per-node=96
#SBATCH --mem-per-cpu=2G
#SBATCH --time=00:30:00
#SBATCH -J vast_peak_read
#SBATCH -o output-peak/%x_a%A_t%a.out
#SBATCH --exclusive

set -euo pipefail

ARRAY_SIZE="${ARRAY_SIZE:-${SLURM_ARRAY_TASK_COUNT:-16}}"
NODES_PER="${NODES_PER:-${SLURM_NNODES:-2}}"
CPU_PER_NODE="${CPU_PER_NODE:-${SLURM_NTASKS_PER_NODE:-96}}"
TOTAL_SIZE="${TOTAL_SIZE:-8G}"
ITERS="${ITERS:-3}"
TAG="${TAG:-${SLURM_ARRAY_JOB_ID:-manual}}"
TASK_ID="${SLURM_ARRAY_TASK_ID:-0}"

module load miniforge3/25.3.0-3
source activate torch
cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

# read_benchmark.py lives in the sibling dataloader repo
BENCH_PY="${BENCH_PY:-/home/shaohao_mit/benchmarks/dataloader/read_benchmark.py}"
DATA_ROOT="/work/mit/datasets/imagenet/images_complete/ilsvrc/train"
RUN_DIR="results-peak/${TAG}"
TASK_DIR="${RUN_DIR}/task_${TASK_ID}"
mkdir -p "${TASK_DIR}"

# --- shard the dataset: each task gets every Nth class directory --------------
SHARD_INDEX="${TASK_DIR}/shard.index"
python - "$DATA_ROOT" "$TASK_ID" "$ARRAY_SIZE" "$SHARD_INDEX" <<'PY'
import os, sys
root, task_id, array_size, out = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
classes = sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)))
mine = [c for i, c in enumerate(classes) if i % array_size == task_id]
paths = []
for c in mine:
    cdir = os.path.join(root, c)
    for name in os.listdir(cdir):
        if name.lower().endswith((".jpeg", ".jpg")):
            paths.append(os.path.join(cdir, name))
with open(out, "w") as f:
    f.write("\n".join(paths))
print(f"task {task_id}/{array_size}: {len(mine)} classes, {len(paths)} files -> {out}")
PY

# --- report which CBOX VIP this node is using (sanity-check distribution) -----
echo "=== NFS mount addrs on $(hostname) ==="
nfsstat -m 2>/dev/null | grep -E "^/work|addr=" | head -4 || true

# --- run raw-read benchmark on this shard -------------------------------------
echo "=== $(date) task=${TASK_ID}/${ARRAY_SIZE} nodes=${NODES_PER} cpu=${CPU_PER_NODE} total=${TOTAL_SIZE} ==="
srun -n "${NODES_PER}" --ntasks-per-node=1 \
    python "${BENCH_PY}" \
        --input "${DATA_ROOT}" \
        --index-file "${SHARD_INDEX}" \
        --output-dir "${TASK_DIR}" \
        --mode raw \
        --nproc "${CPU_PER_NODE}" \
        --total-size "${TOTAL_SIZE}" \
        --warmup-files 50 \
        --iters "${ITERS}"

# concatenate per-rank CSVs for this task
HEADER=$(head -n 1 "${TASK_DIR}"/results.*.csv 2>/dev/null | head -n 1 || true)
if [[ -n "${HEADER}" ]]; then
    echo "${HEADER}" > "${TASK_DIR}/all.csv"
    tail -n +2 -q "${TASK_DIR}"/results.*.csv >> "${TASK_DIR}/all.csv"
fi
echo "Done. Task results: ${TASK_DIR}/all.csv"
