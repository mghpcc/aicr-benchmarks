#!/bin/bash
# All-pairs OSU BIBW sweep for cluster node validation.
# Discovers all nodes in a Slurm partition, submits one job per unique pair, then
# submits a summarizer job with afterany dependency to print a pass/fail table.
#
# Usage:
#   ./run_sweep.sh --partition CPU1 --container /opt/containers/osu-benchmarks.sif
#   ./run_sweep.sh --partition CPU1 --container /opt/containers/osu-benchmarks.sif --dry-run

set -euo pipefail

PARTITION=""
CONTAINER=""
THRESHOLD_HH=15000
DRY_RUN=false
RESULTS_DIR=""
TIME_LIMIT="00:15:00"
CPUS_PER_TASK=4
ITERATIONS=100
WARMUP=10
MSG_MIN=1
MSG_MAX=$((8 * 1024 * 1024))
MPI_TYPE="${MPI_TYPE:-pmix}"
OSU_BIBW="/opt/hpc/osu/libexec/osu-micro-benchmarks/mpi/pt2pt/osu_bibw"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 --partition PART --container PATH [OPTIONS]

Required:
  --partition PART       Slurm partition to test
  --container PATH       Path to Apptainer .sif image

Options:
  --threshold-hh BW      Minimum acceptable H H bandwidth in MB/s (default: ${THRESHOLD_HH})
  --results-dir DIR      Output directory (default: sweep_PARTITION_TIMESTAMP)
  --time LIMIT           Per-pair job time limit (default: ${TIME_LIMIT})
  --mpi-type TYPE        pmix or pmi2 (default: ${MPI_TYPE})
  --dry-run              Print pairs and commands without submitting
  --help
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --partition)     PARTITION="$2";     shift 2 ;;
        --container)     CONTAINER="$2";     shift 2 ;;
        --threshold-hh)  THRESHOLD_HH="$2"; shift 2 ;;
        --results-dir)   RESULTS_DIR="$2";  shift 2 ;;
        --time)          TIME_LIMIT="$2";   shift 2 ;;
        --mpi-type)      MPI_TYPE="$2";     shift 2 ;;
        --dry-run)       DRY_RUN=true;      shift   ;;
        --help|-h)       usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

[[ -z "${PARTITION}" ]]   && { echo "ERROR: --partition is required"; exit 1; }
[[ -z "${CONTAINER}" ]]   && { echo "ERROR: --container is required"; exit 1; }
[[ ! -f "${CONTAINER}" ]] && { echo "ERROR: Container not found: ${CONTAINER}"; exit 1; }

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="${RESULTS_DIR:-sweep_${PARTITION}_${TIMESTAMP}}"
mkdir -p "${RESULTS_DIR}"

APPTAINER_OPTS="--no-mount /etc/localtime"
[[ -d /usr/lib64/libibverbs ]] && APPTAINER_OPTS+=" --bind /usr/lib64/libibverbs:/usr/lib64/libibverbs"
[[ -d /etc/libibverbs.d    ]] && APPTAINER_OPTS+=" --bind /etc/libibverbs.d:/etc/libibverbs.d"

BENCH_FLAGS="-i ${ITERATIONS} -x ${WARMUP} -m ${MSG_MIN}:${MSG_MAX}"

echo "========================================================"
echo " OSU BIBW All-Pairs Sweep"
echo " Partition  : ${PARTITION}"
echo " Container  : ${CONTAINER}"
echo " Results    : ${RESULTS_DIR}/"
echo " H H thresh : >= ${THRESHOLD_HH} MB/s"
echo " Dry run    : ${DRY_RUN}"
echo "========================================================"
echo

echo "Querying nodes in partition ${PARTITION}..."
RAW=$(sinfo -N -h -p "${PARTITION}" -t idle,alloc,mix -o "%N" | sort -u | paste -sd,)
if [[ -z "${RAW}" ]]; then
    echo "ERROR: No nodes found in partition ${PARTITION} (checked idle/alloc/mix states)"
    exit 1
fi

mapfile -t NODES < <(scontrol show hostnames "${RAW}" | sort -u)
N=${#NODES[@]}
PAIR_COUNT=$(( N * (N - 1) / 2 ))

echo "Found ${N} nodes → ${PAIR_COUNT} pairs"
echo "Nodes: ${NODES[*]}"
echo

[[ $N -lt 2 ]] && { echo "ERROR: Need at least 2 nodes to run a pair test"; exit 1; }

declare -a JOB_IDS=()

for (( i=0; i<N; i++ )); do
    for (( j=i+1; j<N; j++ )); do
        nodeA="${NODES[i]}"
        nodeB="${NODES[j]}"
        PAIR="${nodeA}--${nodeB}"
        PAIR_SCRIPT="${RESULTS_DIR}/${PAIR}.sh"
        OUT="${RESULTS_DIR}/${PAIR}.out"
        ERR="${RESULTS_DIR}/${PAIR}.err"

        cat > "${PAIR_SCRIPT}" <<SCRIPT
#!/bin/bash
export OMPI_MCA_pml=ucx
export UCX_WARN_UNUSED_ENV_VARS=n

echo "=== PAIR: ${nodeA} <-> ${nodeB} ==="
echo "--- H H ---"
srun --mpi=${MPI_TYPE} --export=ALL --nodes=2 --ntasks=2 --ntasks-per-node=1 \\
    apptainer exec ${APPTAINER_OPTS} ${CONTAINER} \\
    ${OSU_BIBW} ${BENCH_FLAGS} H H
SCRIPT
        chmod +x "${PAIR_SCRIPT}"

        SBATCH_ARGS=(
            --parsable
            --partition="${PARTITION}"
            --job-name="bibw_${PAIR}"
            --nodes=2
            --ntasks=2
            --ntasks-per-node=1
            --cpus-per-task="${CPUS_PER_TASK}"
            --nodelist="${nodeA},${nodeB}"
            --time="${TIME_LIMIT}"
            --output="${OUT}"
            --error="${ERR}"
            --export=ALL
        )

        if ${DRY_RUN}; then
            echo "[DRY RUN] ${nodeA} <-> ${nodeB} → ${OUT}"
        else
            JOB_ID=$(sbatch "${SBATCH_ARGS[@]}" "${PAIR_SCRIPT}")
            JOB_IDS+=("${JOB_ID}")
            echo "Submitted ${nodeA} <-> ${nodeB} → job ${JOB_ID}"
        fi
    done
done

echo

if ${DRY_RUN}; then
    echo "Dry run complete. ${PAIR_COUNT} pairs would be submitted."
    echo "Per-pair scripts written to: ${RESULTS_DIR}/"
    exit 0
fi

echo "Submitted ${#JOB_IDS[@]} / ${PAIR_COUNT} pair jobs."

DEPS=$(IFS=:; echo "${JOB_IDS[*]}")

SUMMARY_JOB=$(sbatch --parsable \
    --partition="${PARTITION}" \
    --job-name="bibw_summary_${PARTITION}" \
    --nodes=1 --ntasks=1 \
    --time=00:05:00 \
    --dependency="afterany:${DEPS}" \
    --output="${RESULTS_DIR}/summary.out" \
    --wrap="bash ${SCRIPT_DIR}/summarize_sweep.sh ${RESULTS_DIR} ${THRESHOLD_HH}")

echo "Summary job: ${SUMMARY_JOB} (runs after all pair jobs complete)"
echo
echo "Monitor : squeue -u \$USER"
echo "Results : ${RESULTS_DIR}/"
echo "Summary : ${RESULTS_DIR}/summary.out  (available after job ${SUMMARY_JOB})"
