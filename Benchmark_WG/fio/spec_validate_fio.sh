#!/bin/bash
# Vast spec-VALIDATION fio runner (separate from peak_aggregate_fio.sh).
#
# PURPOSE
#   Answer one question fairly: "Does the storage product we bought actually
#   deliver the throughput / IOPS the vendor quoted?" The peak_aggregate_*
#   suite chases the highest *aggregate* number and (as summary.md documents)
#   ends up reporting cache hits and write-buffer bursts that exceed the spec.
#   This runner instead measures numbers that are directly comparable to the
#   vendor spec:
#
#     1. COLD storage, not cache.   Working sets are sized to several× the CBOX
#        cache (DEFEAT_TIB, default 32 TiB cluster-wide), AND reads are measured
#        only after intervening multi-TB writes have evicted the read source
#        from server cache. Client cache is killed as always (direct=1 +
#        invalidate=1 + fadvise_hint=1).
#     2. SUSTAINED, not burst.      time_based writes run for RUNTIME (default
#        900 s = 15 min) so the CBOX NVMe write buffer saturates and we measure
#        the rate storage can hold, comparable to the vendor "sustained write".
#     3. STREAMING, not metadata.   seq_* uses large files (FILE_SIZE, default
#        1G) so bandwidth isn't throttled by file-create RPCs (the 1M-file
#        metadata trap that made seq_write read 11% of spec). This matches how
#        "max read/write GB/s" is measured.
#     4. HONEST writes.             end_fsync=1 — writes wait for server commit.
#
#   The result is meant to be read as: "with N client nodes, the product
#   sustains X GB/s / Y kIOPS cold — that is Z% of the vendor spec." Run via
#   submit_spec_validate.sh to get the same suite at several client counts so
#   you can tell a storage limit (curve plateaus below spec) from a client
#   limit (curve still rising at the full pool).
#
# WHY A SEPARATE SCRIPT
#   peak_aggregate_fio.sh optimizes for headline aggregate and sweeps small
#   file sizes; its defaults (12 TiB working set ≈ 1.5× cache, 60 s window)
#   are deliberately tuned for that. This script trades wall-time for honesty
#   and is sized per the cache-defeat + long-window invariants. Kept separate
#   on purpose — do not merge the defaults.
#
# WORKLOAD ORDER (WORKLOAD=all)
#   seq_read_layout  → lay out the seq_read source (≥DEFEAT_TIB), no measure
#   rand_read_layout → lay out the rand_read source (≥DEFEAT_TIB), no measure
#   seq_write        → MEASURE sustained write; also writes ≥DEFEAT_TIB of
#                      distinct blocks, evicting both read sources from cache
#   rand_write       → MEASURE random write IOPS; more eviction pressure
#   seq_read         → MEASURE cold sequential read (source now evicted)
#   rand_read        → MEASURE cold random read IOPS (source now evicted)
#   Because each write phase touches ≥DEFEAT_TIB of distinct blocks and the
#   cache is assumed smaller than that, one write phase fully displaces the
#   laid-out read sources. Both reads are therefore cold by construction.
#
# KEY TUNABLES (override via env / sbatch --export)
#   TOTAL_NODES     total client nodes in THIS tier (NODES_PER × ARRAY_SIZE).
#                   Required for sizing — submit_spec_validate.sh sets it.
#                   Working set per fio worker = DEFEAT / (JOBS_PER_NODE ×
#                   TOTAL_NODES) so the CLUSTER footprint = DEFEAT regardless
#                   of node count (every tier defeats cache independently).
#   DEFEAT_TIB      cluster-wide working set per direction, in TiB (default 32).
#                   Must exceed the CBOX server cache by a comfortable margin.
#                   Lower it ONCE you know the real cache size (e.g. 4× actual)
#                   to cut layout time — but never below a few× the cache.
#   FILE_SIZE       per-file size for seq_* streaming (default 1G). Large on
#                   purpose: peak BW, not a metadata-create benchmark.
#   JOBS_PER_NODE   fio numjobs per node = allocated cores (default 96). On a
#                   sync engine (pvsync2/iodepth=1) concurrency == numjobs;
#                   never set above cores (oversubscription regresses — see
#                   summary.md n128). submit sets --cpus-per-task to match.
#   RUNTIME         steady-state seconds for time_based phases (default 900).
#   RAMP_TIME       warm-up seconds before measurement (default 60).
#   HONEST_FSYNC    1 (default) = writes wait for server commit. 0 = buffered
#                   (dishonest vs a durability spec); leave at 1 for validation.
#   WORKLOAD        all (default) | seq_read | seq_write | rand_read |
#                   rand_write | seq_read_layout | rand_read_layout
#   IOENGINE        auto (default; io_uring→libaio→pvsync2→posixaio probe) or
#                   explicit. io_uring gives real iodepth if unblocked.
#   DATA_ROOT       writable base dir (default /work/mit/datasets/test/fio)
#   FIO_BIN         fio path (default $SCRIPT_DIR/install/bin/fio)
#   TAG             results-peak/ subdir (default array job id)
#   CLEANUP         1 (default) → rm this task's data subtree on exit.
#
# STANDALONE USAGE
#   TOTAL_NODES=8 ARRAY_SIZE=4 sbatch --array=0-3%4 \
#       -N2 --cpus-per-task=96 spec_validate_fio.sh
#   # then:  python spec_validate_summary.py results-peak/<TAG>
#
# NOTE ON SPACE/TIME: at DEFEAT_TIB=32 the cluster lays out ~32 TiB per read
#   source on /work and re-writes ≥32 TiB during the write phases. Small tiers
#   (few nodes) take hours because the same footprint is laid out by fewer
#   nodes. This is intended — correctness over wall-time. See submit script.
#
#SBATCH -p b200-batch
#SBATCH -N 2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=96
#SBATCH --mem-per-cpu=2G
#SBATCH --time=08:00:00
#SBATCH -J fio_specval
#SBATCH -o output-peak/%x_a%A_t%a.out
#SBATCH --exclusive
#SBATCH --gres=gpu:0

set -euo pipefail

if [[ -n "${SLURM_SUBMIT_DIR:-}" ]]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

ARRAY_SIZE="${ARRAY_SIZE:-${SLURM_ARRAY_TASK_COUNT:-1}}"
NODES_PER="${NODES_PER:-${SLURM_NNODES:-2}}"
JOBS_PER_NODE="${JOBS_PER_NODE:-${SLURM_CPUS_PER_TASK:-96}}"
# TOTAL_NODES drives cache-defeat sizing. Default to NODES_PER×ARRAY_SIZE if
# the submit wrapper didn't set it explicitly.
TOTAL_NODES="${TOTAL_NODES:-$(( NODES_PER * ARRAY_SIZE ))}"
DEFEAT_TIB="${DEFEAT_TIB:-32}"
FILE_SIZE="${FILE_SIZE:-1G}"
RUNTIME="${RUNTIME:-900}"
RAMP_TIME="${RAMP_TIME:-60}"
HONEST_FSYNC="${HONEST_FSYNC:-1}"
WORKLOAD="${WORKLOAD:-all}"
IOENGINE="${IOENGINE:-auto}"
DATA_ROOT="${DATA_ROOT:-/work/mit/datasets/test/fio}"
FIO_BIN="${FIO_BIN:-${SCRIPT_DIR}/install/bin/fio}"
TAG="${TAG:-${SLURM_ARRAY_JOB_ID:-manual}}"
TASK_ID="${SLURM_ARRAY_TASK_ID:-0}"
CLEANUP="${CLEANUP:-1}"

# Single-size streaming workloads — seq_* jobs carry no size suffix so the
# summary parses them as the bare (workload, None) cell.
IODEPTH=1   # sync engines clamp to 1; io_uring/libaio would honor more.

cd "${SLURM_SUBMIT_DIR:-${SCRIPT_DIR}}"

if [[ ! -x "${FIO_BIN}" ]]; then
    echo "fio binary not found at ${FIO_BIN}" >&2
    exit 1
fi

ulimit -n "$(ulimit -Hn)" 2>/dev/null || true

TASK_DATA_DIR="${DATA_ROOT}/${TAG}/task_${TASK_ID}"
RUN_DIR="results-peak/${TAG}"
TASK_DIR="${RUN_DIR}/task_${TASK_ID}"
mkdir -p "${TASK_DATA_DIR}" "${TASK_DIR}"

cleanup_task_data() {
    local rc=$?
    if [[ "${CLEANUP}" == "1" && -n "${TASK_DATA_DIR}" && -d "${TASK_DATA_DIR}" ]]; then
        echo "--- cleanup: rm -rf ${TASK_DATA_DIR} (exit rc=${rc}) ---"
        rm -rf -- "${TASK_DATA_DIR}" || true
        rmdir --ignore-fail-on-non-empty "${DATA_ROOT}/${TAG}" 2>/dev/null || true
    elif [[ "${CLEANUP}" != "1" ]]; then
        echo "--- cleanup: CLEANUP=${CLEANUP}, leaving ${TASK_DATA_DIR} in place ---"
    fi
    return ${rc}
}
trap cleanup_task_data EXIT

size_to_bytes() {
    local s="$1"
    local n="${s%[KkMmGgTt]}"
    local suf="${s:${#n}}"
    case "$suf" in
        T|t) echo $(( n * 1024 * 1024 * 1024 * 1024 )) ;;
        G|g) echo $(( n * 1024 * 1024 * 1024 )) ;;
        M|m) echo $(( n * 1024 * 1024 )) ;;
        K|k) echo $(( n * 1024 )) ;;
        "")  echo "$n" ;;
        *)   echo "size_to_bytes: bad suffix '$suf' in '$s'" >&2; return 1 ;;
    esac
}

# Per-worker working set so that JOBS_PER_NODE × TOTAL_NODES × per_job = DEFEAT.
DEFEAT_BYTES=$(( DEFEAT_TIB * 1024 * 1024 * 1024 * 1024 ))
TOTAL_WORKERS=$(( JOBS_PER_NODE * TOTAL_NODES ))
if [[ "${TOTAL_WORKERS}" -lt 1 ]]; then TOTAL_WORKERS=1; fi
PER_JOB_BYTES=$(( (DEFEAT_BYTES + TOTAL_WORKERS - 1) / TOTAL_WORKERS ))
FILE_BYTES=$(size_to_bytes "${FILE_SIZE}")
if [[ "${PER_JOB_BYTES}" -lt "${FILE_BYTES}" ]]; then
    PER_JOB_BYTES="${FILE_BYTES}"
fi
SEQ_NRFILES=$(( PER_JOB_BYTES / FILE_BYTES ))
if [[ "${SEQ_NRFILES}" -lt 1 ]]; then SEQ_NRFILES=1; fi

echo "=== NFS mount addrs on $(hostname) ==="
nfsstat -m 2>/dev/null | grep -E "^/work|addr=" | head -4 || true

echo "=== SPEC-VALIDATION  task=${TASK_ID}/${ARRAY_SIZE}  workload=${WORKLOAD} ==="
echo "TOTAL_NODES=${TOTAL_NODES}  JOBS_PER_NODE=${JOBS_PER_NODE}  (cluster workers=${TOTAL_WORKERS})"
echo "DEFEAT_TIB=${DEFEAT_TIB}  -> per-worker working set=$(( PER_JOB_BYTES / (1024*1024*1024) )) GiB, seq nrfiles=${SEQ_NRFILES} @ FILE_SIZE=${FILE_SIZE}"
echo "RUNTIME=${RUNTIME}s  RAMP_TIME=${RAMP_TIME}s  HONEST_FSYNC=${HONEST_FSYNC}"
echo "DATA_ROOT=${DATA_ROOT}  RESULTS=${TASK_DIR}"

declare -A JOBFILE=(
    [seq_read]="${SCRIPT_DIR}/jobs/seq_read_bw.fio"
    [seq_write]="${SCRIPT_DIR}/jobs/seq_write_bw.fio"
    [rand_read]="${SCRIPT_DIR}/jobs/rand_read_iops.fio"
    [rand_write]="${SCRIPT_DIR}/jobs/rand_write_iops.fio"
)

if [[ "${WORKLOAD}" == "all" ]]; then
    WORKLOADS=(seq_read_layout rand_read_layout seq_write rand_write seq_read rand_read)
else
    WORKLOADS=("${WORKLOAD}")
fi

pick_engine() {
    local probe_dir="$1"
    if [[ "${IOENGINE}" != "auto" ]]; then
        echo "${IOENGINE}"
        return
    fi
    mkdir -p "${probe_dir}"
    local eng
    for eng in io_uring libaio pvsync2 posixaio; do
        local probe_file="${probe_dir}/.engine_probe_${eng}"
        local probe_out
        probe_out=$("${FIO_BIN}" \
            --name=probe --ioengine="${eng}" --rw=write --bs=4k --size=4k \
            --filename="${probe_file}" --direct=1 \
            --runtime=1 --time_based=0 \
            --output-format=normal 2>&1 || true)
        rm -f "${probe_file}"
        if ! echo "${probe_out}" | grep -qE "Operation not permitted|failed to load engine|not loadable|error="; then
            echo "${eng}"
            return
        fi
    done
    echo "posixaio"
}

# Run one fio invocation. Args:
#   wl size_per_job nrfiles jobname jobs_per_node iodepth end_fsync layout_only
run_one_fio() {
    local wl="$1" size_per_job="$2" nrfiles="$3" jobname="$4"
    local jobs_per_node="$5" iodepth="$6" end_fsync="$7" layout_only="${8:-0}"

    local jobfile="${JOBFILE[$wl]:-}"
    if [[ -z "${jobfile}" ]]; then echo "unknown workload '${wl}'" >&2; return 1; fi

    local node_data_dir="${TASK_DATA_DIR}/$(hostname -s)/${jobname}"
    mkdir -p "${node_data_dir}"

    local engine
    engine=$(pick_engine "${node_data_dir}")
    local effective_iodepth="${iodepth}"
    case "${engine}" in
        pvsync2|sync|psync|vsync) effective_iodepth=1 ;;
    esac

    local ncpu; ncpu=$(nproc 2>/dev/null || echo 96)
    local cpus_allowed="0-$((ncpu - 1))"

    local out_json mode_tag="measure"
    local -a extra_fio_args=()
    if [[ "${layout_only}" == "1" ]]; then
        out_json="/dev/null"; extra_fio_args+=(--create_only=1); mode_tag="layout-only"
    else
        out_json="${TASK_DIR}/$(hostname -s).${jobname}.json"
    fi
    local rendered_fio="${TASK_DIR}/$(hostname -s).${jobname}.fio"
    echo "--- fio ${jobname} [${mode_tag}] (nrfiles=${nrfiles}, size_per_job=${size_per_job}B, numjobs=${jobs_per_node}, iodepth=${effective_iodepth}, end_fsync=${end_fsync}) on $(hostname) engine=${engine} -> ${out_json} ---"

    DATA_DIR="${node_data_dir}" \
    SIZE_PER_JOB="${size_per_job}" \
    NRFILES="${nrfiles}" \
    NUMJOBS="${jobs_per_node}" \
    RUNTIME="${RUNTIME}" \
    RAMP_TIME="${RAMP_TIME}" \
    IODEPTH="${effective_iodepth}" \
    IOENGINE="${engine}" \
    CPUS_ALLOWED="${cpus_allowed}" \
    JOBNAME="${jobname}" \
    END_FSYNC="${end_fsync}" \
        envsubst '${JOBNAME} ${IOENGINE} ${SIZE_PER_JOB} ${NRFILES} ${IODEPTH} ${NUMJOBS} ${RUNTIME} ${RAMP_TIME} ${DATA_DIR} ${CPUS_ALLOWED} ${END_FSYNC}' \
        < "${jobfile}" > "${rendered_fio}"

    "${FIO_BIN}" \
        --alloc-size=262144 \
        --output-format=json \
        --output="${out_json}" \
        "${extra_fio_args[@]}" \
        "${rendered_fio}"
}

# Dispatch one phase. Single streaming file size for seq_*; one big file for
# rand_*. layout phases pass --create_only via layout_only=1 with the SAME
# jobname/size the measured pass uses, so fio finds the files already on disk.
run_one_workload() {
    local wl="$1"
    local fio_wl="${wl}" layout_only=0 jobs end_fsync

    case "${wl}" in
        seq_read_layout)  fio_wl="seq_read";  layout_only=1; end_fsync="1" ;;
        rand_read_layout) fio_wl="rand_read"; layout_only=1; end_fsync="0" ;;
        rand_write)       end_fsync="${HONEST_FSYNC}" ;;
        rand_read)        end_fsync="0" ;;
        seq_write|seq_read) end_fsync="1" ;;
        *) end_fsync="1" ;;
    esac
    jobs="${JOBS_PER_NODE}"

    if [[ "${fio_wl}" == seq_* ]]; then
        run_one_fio "${fio_wl}" "${PER_JOB_BYTES}" "${SEQ_NRFILES}" "${fio_wl}" \
            "${jobs}" "${IODEPTH}" "${end_fsync}" "${layout_only}"
    else
        # rand_*: one large file per worker (nrfiles=1) spanning the working set.
        run_one_fio "${fio_wl}" "${PER_JOB_BYTES}" 1 "${fio_wl}" \
            "${jobs}" "${IODEPTH}" "${end_fsync}" "${layout_only}"
    fi
}

export -f run_one_workload run_one_fio pick_engine size_to_bytes
export SCRIPT_DIR FIO_BIN TASK_DATA_DIR TASK_DIR JOBS_PER_NODE IODEPTH \
       HONEST_FSYNC PER_JOB_BYTES SEQ_NRFILES RUNTIME RAMP_TIME IOENGINE
export JOBFILE_seq_read="${JOBFILE[seq_read]}"
export JOBFILE_seq_write="${JOBFILE[seq_write]}"
export JOBFILE_rand_read="${JOBFILE[rand_read]}"
export JOBFILE_rand_write="${JOBFILE[rand_write]}"

for wl in "${WORKLOADS[@]}"; do
    if [[ -n "${SLURM_JOB_ID:-}" ]]; then
        srun --ntasks="${NODES_PER}" --ntasks-per-node=1 \
            bash -c "
                set -euo pipefail
                ulimit -n \"\$(ulimit -Hn)\" 2>/dev/null || true
                declare -A JOBFILE=(
                    [seq_read]=\"\$JOBFILE_seq_read\"
                    [seq_write]=\"\$JOBFILE_seq_write\"
                    [rand_read]=\"\$JOBFILE_rand_read\"
                    [rand_write]=\"\$JOBFILE_rand_write\"
                )
                $(declare -f size_to_bytes)
                $(declare -f pick_engine)
                $(declare -f run_one_fio)
                $(declare -f run_one_workload)
                run_one_workload '${wl}'
            "
    else
        run_one_workload "${wl}"
    fi
done

echo "Done. Task results: ${TASK_DIR}"
