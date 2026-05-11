#!/bin/bash
# Discovers all nodes in a Slurm partition and submits one job running osu_alltoall
# across all of them simultaneously (1 MPI rank per node).
#
# Usage:
#   ./run_alltoall.sh --partition CPU1 --container /opt/containers/osu-benchmarks.sif
#   ./run_alltoall.sh --partition CPU1 --container /opt/containers/osu-benchmarks.sif --dry-run

set -euo pipefail

PARTITION=""
CONTAINER=""
MPI_TYPE="${MPI_TYPE:-pmix}"
DRY_RUN=false
TIME_LIMIT="00:30:00"
CPUS_PER_TASK=4
ITERATIONS=100
WARMUP=10
MSG_MIN=1
MSG_MAX=$((1 * 1024 * 1024))   # 1 MiB — alltoall scales as N^2, keep reasonable
OSU_ALLTOALL="/opt/hpc/osu/libexec/osu-micro-benchmarks/mpi/collective/osu_alltoall"

usage() {
    cat <<EOF
Usage: $0 --partition PART --container PATH [OPTIONS]

Required:
  --partition PART    Slurm partition to test
  --container PATH    Path to Apptainer .sif image

Options:
  --mpi-type TYPE     pmix or pmi2 (default: ${MPI_TYPE})
  --time LIMIT        Job time limit (default: ${TIME_LIMIT})
  --msg-max BYTES     Maximum message size in bytes (default: ${MSG_MAX})
  --dry-run           Print without submitting
  --help
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --partition)  PARTITION="$2";   shift 2 ;;
        --container)  CONTAINER="$2";   shift 2 ;;
        --mpi-type)   MPI_TYPE="$2";    shift 2 ;;
        --time)       TIME_LIMIT="$2";  shift 2 ;;
        --msg-max)    MSG_MAX="$2";     shift 2 ;;
        --dry-run)    DRY_RUN=true;     shift   ;;
        --help|-h)    usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

[[ -z "$PARTITION" ]]   && { echo "ERROR: --partition is required"; exit 1; }
[[ -z "$CONTAINER" ]]   && { echo "ERROR: --container is required"; exit 1; }
[[ ! -f "$CONTAINER" ]] && { echo "ERROR: Container not found: $CONTAINER"; exit 1; }

RAW=$(sinfo -N -h -p "${PARTITION}" -t idle,alloc,mix -o "%N" | sort -u | paste -sd,)
[[ -z "$RAW" ]] && { echo "ERROR: No nodes found in partition ${PARTITION}"; exit 1; }

mapfile -t NODES < <(scontrol show hostnames "${RAW}" | sort -u)
N=${#NODES[@]}

[[ $N -lt 2 ]] && { echo "ERROR: Need at least 2 nodes"; exit 1; }

NODELIST=$(IFS=,; echo "${NODES[*]}")

echo "========================================================"
echo " OSU Alltoall All-Nodes Test"
echo " Partition : ${PARTITION}"
echo " Nodes     : ${N}  (${NODELIST})"
echo " Container : ${CONTAINER}"
echo " Dry run   : ${DRY_RUN}"
echo "========================================================"
echo

APPTAINER_OPTS="--no-mount /etc/localtime"
[[ -d /usr/lib64/libibverbs ]] && APPTAINER_OPTS+=" --bind /usr/lib64/libibverbs:/usr/lib64/libibverbs"
[[ -d /etc/libibverbs.d     ]] && APPTAINER_OPTS+=" --bind /etc/libibverbs.d:/etc/libibverbs.d"

BENCH_FLAGS="-i ${ITERATIONS} -x ${WARMUP} -m ${MSG_MIN}:${MSG_MAX}"

# Write a temp job script so the srun command is not embedded in --wrap quoting
TMPSCRIPT=$(mktemp /tmp/osu_alltoall_XXXXXX.sh)
trap "rm -f ${TMPSCRIPT}" EXIT

cat > "${TMPSCRIPT}" <<SCRIPT
#!/bin/bash
export OMPI_MCA_pml=ucx
export UCX_WARN_UNUSED_ENV_VARS=n

echo "========================================================"
echo " OSU Alltoall  |  \${SLURM_JOB_NODELIST}  |  job \${SLURM_JOB_ID}"
echo " Ranks         : \${SLURM_NTASKS} (1 per node)"
echo " Started       : \$(date)"
echo "========================================================"
echo

srun --mpi=${MPI_TYPE} --export=ALL \
    apptainer exec ${APPTAINER_OPTS} ${CONTAINER} \
    ${OSU_ALLTOALL} ${BENCH_FLAGS}

echo
echo "========================================================"
echo " Completed : \$(date)"
echo "========================================================"
SCRIPT
chmod +x "${TMPSCRIPT}"

SBATCH_ARGS=(
    --parsable
    --partition="${PARTITION}"
    --job-name="osu_alltoall_${PARTITION}"
    --nodes="${N}"
    --ntasks="${N}"
    --ntasks-per-node=1
    --cpus-per-task="${CPUS_PER_TASK}"
    --nodelist="${NODELIST}"
    --time="${TIME_LIMIT}"
    --output="alltoall_%j.out"
    --error="alltoall_%j.err"
    --export=ALL
)

if ${DRY_RUN}; then
    echo "[DRY RUN] sbatch ${SBATCH_ARGS[*]} <job-script>"
    echo
    echo "Job script contents:"
    cat "${TMPSCRIPT}"
else
    JOB_ID=$(sbatch "${SBATCH_ARGS[@]}" "${TMPSCRIPT}")
    echo "Submitted job ${JOB_ID}"
    echo "Output : alltoall_${JOB_ID}.out  (after job completes)"
fi
