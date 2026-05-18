#!/bin/bash
#SBATCH -p GPU2
#SBATCH -N 1
#SBATCH --ntasks-per-node=96
#SBATCH --mem-per-cpu=2G
#SBATCH --time=02:00:00
#SBATCH -J vast_benchmark
#SBATCH -o output/%x_%N_%j.out
#SBATCH --exclusive

# Usage: sbatch job.sh <read|write> [result_dir]
#   sbatch job.sh read
#   sbatch job.sh write
#   sbatch job.sh read my_experiment

set -euo pipefail

MODE="${1:-}"
if [[ "${MODE}" != "read" && "${MODE}" != "write" ]]; then
    echo "error: first argument must be 'read' or 'write', got '${MODE}'" >&2
    exit 1
fi

module load miniforge3/25.3.0-3
source activate torch

cd "${SLURM_SUBMIT_DIR:-$(pwd)}"

RESULT_TAG="${2:-${MODE}_${SLURM_NODELIST}}"
OUT_DIR="results/${RESULT_TAG}_${SLURM_JOB_ID}"
mkdir -p "${OUT_DIR}"

NPERNODE="${SLURM_NTASKS_PER_NODE:-96}"
echo "=== $(date) mode=${MODE} nodes=${SLURM_NNODES} npernode=${NPERNODE} ==="

if [[ "${MODE}" == "read" ]]; then
    srun -n "${SLURM_NNODES}" --ntasks-per-node=1 \
        python read_benchmark.py \
            --output-dir "${OUT_DIR}" \
            --mode both \
            --nproc "${NPERNODE}" \
            --total-size 20G \
            --warmup-files 200 \
            --iters 3
else
    srun -n "${SLURM_NNODES}" --ntasks-per-node=1 \
        python write_benchmark.py \
            --output-path /work/mit/datasets/test \
            --output-dir "${OUT_DIR}" \
            --mode all \
            --nproc "${NPERNODE}" \
            --file-size 100K,1M,10M,100M \
            --files-per-proc 8 \
            --warmup 1 \
            --iters 3
fi

HEADER=$(head -n 1 "${OUT_DIR}"/results.*.csv 2>/dev/null | head -n 1 || true)
if [[ -n "${HEADER}" ]]; then
    echo "${HEADER}" > "${OUT_DIR}/all.csv"
    tail -n +2 -q "${OUT_DIR}"/results.*.csv >> "${OUT_DIR}/all.csv"
fi
echo "Done. Results: ${OUT_DIR}/all.csv"
