#!/bin/bash
# Slurm job array driving fio on many concurrent client nodes to measure
# peak aggregate bandwidth (sequential) and IOPS (random) of the Vast NFS.
#
# Recipe (same as ../raw-io/peak_aggregate_read_v2.sh, but the workload is
# fio against a private per-task directory instead of os.read of ImageNet):
#   - Submit many independent jobs concurrently (Slurm array), each on a few
#     nodes.
#   - Each task writes/reads files inside its OWN per-task subdirectory under
#     DATA_ROOT so no two tasks ever touch the same file (no cache overlap
#     and no false sharing).
#   - Stock NFS mounts use nconnect=16 and proto=rdma (see `nfsstat -m`), so
#     each task already drives its CBOX with multiple parallel RDMA streams.
#   - Slurm spreads tasks across hosts and the /work VIP pool DNS-round-robins
#     mounts across CBOXes, so aggregate fans out across the cluster.
#
# Workloads (set with WORKLOAD env var):
#   seq_read      sequential read,  bs=1M  (peak read BW), sweeps SIZES
#   seq_write     sequential write, bs=1M  (peak write BW), sweeps SIZES
#   rand_read     random read,      bs=4k  (peak read IOPS)
#   rand_write    random write,     bs=4k  (peak write IOPS)
#   all           run all four back to back
#
# Cache strategy:
#   - All jobs set direct=1, invalidate=1, fadvise_hint=1 (kill client cache).
#   - seq_read uses loops=1 single-pass with nrfiles to give a per-job
#     working set of TOTAL_PER_JOB (~4G default). Single-pass keeps the read
#     window honest against the same files seq_write just produced.
#   - seq_write uses time_based=RUNTIME so steady-state throughput is
#     measured rather than a single-pass burst; files are rewritten in
#     place, so on-disk footprint stays at TOTAL_PER_JOB per worker.
#   - Total cluster footprint at any size is numjobs × nodes ×
#     TOTAL_PER_JOB (≈5 TB on 42 nodes), well above aggregate CBOX cache,
#     so server-side cache hits are negligible.
#   - rand_* keeps time_based with a 16G/job working set (already cache-
#     hostile by volume).
#
# Tunables (override via env or sbatch --export):
#   ARRAY_SIZE      number of concurrent array tasks (default 16)
#   NODES_PER       nodes per array task (default 2)
#   JOBS_PER_NODE   fio numjobs per node for seq_read (default 32)
#   SEQ_WRITE_JOBS_PER_NODE  numjobs per node for seq_write (default 128).
#                   Higher than JOBS_PER_NODE because seq_write runs on
#                   pvsync2 (sync, iodepth clamped to 1), so the only way
#                   to get more in-flight writes is more worker threads.
#                   128 deliberately oversubscribes the 96 allowed CPUs;
#                   workers are usually blocked on NFS RPC, so extra
#                   threads keep more writes in flight per RDMA stream
#                   without hurting CPU efficiency.
#   IODEPTH         fio per-job iodepth for seq_* (default 64; clamped
#                   to 1 for sync engines such as pvsync2)
#   RAND_JOBS_PER_NODE  numjobs per node for rand_* (default 64 — higher
#                   concurrency than seq_read fits the 96-core nodes and
#                   helps pvsync2/posixaio scale)
#   RAND_IODEPTH    per-job iodepth for rand_* (default 128). Ignored when
#                   the engine is pvsync2 (sync engine, always depth=1) but
#                   honored by io_uring and posixaio.
#   HONEST_FSYNC    1 (default) = rand_write uses end_fsync=1 (wait for
#                   server commit). 0 = drops end_fsync to compare against
#                   the Vast spec; result is dishonest because NFS may ack
#                   before the data is durable. Affects rand_write only.
#   SIZES           space-separated per-file sizes for seq_* sweep
#                   (default "1M 10M 100M"; ignored by rand_*)
#   TOTAL_PER_JOB   per-job working set for seq_* (default 4G); nrfiles is
#                   computed as TOTAL_PER_JOB / size for each sweep step
#   RAND_SIZE_PER_JOB  per-job file size for rand_* (default 16G)
#   RUNTIME         seconds per workload for seq_write and rand_* (default 60)
#   RAMP_TIME       seconds to ramp before measurement for seq_write and
#                   rand_* (default 10)
#   WORKLOAD        one of: seq_read, seq_write, rand_read, rand_write,
#                   seq_read_layout, all (default: seq_read).
#                   seq_read_layout pre-creates the seq_read source files
#                   on disk via fio --create_only=1 (no measurement); use
#                   it when running seq_read by itself if you want to
#                   separate the layout write from the read measurement
#                   so the latter isn't served from CBOX cache. WORKLOAD=all
#                   wires this layout/scrub flow automatically.
#   IOENGINE        fio ioengine. Default 'auto' probes a preference chain
#                   on each compute node: io_uring → libaio → pvsync2 →
#                   posixaio. io_uring is best when available; libaio is
#                   the next-best async option (kernel AIO, real iodepth)
#                   and is often available when io_uring is seccomp-blocked;
#                   pvsync2 avoids the userspace thread-pool tax that caps
#                   posixaio at ~10–20k IOPS/node. Set explicitly (io_uring,
#                   libaio, pvsync2, posixaio) to skip the probe.
#   DATA_ROOT       base writable directory (default /work/mit/datasets/test/fio)
#   FIO_BIN         path to fio binary (default $SCRIPT_DIR/install/bin/fio)
#   TAG             subdir name under results-peak/ (default array job id)
#   CLEANUP         1 (default) → rm -rf this task's data subtree on exit.
#
# Usage (from /home/shaohao_mit/benchmarks/fio/):
#   sbatch --array=0-15%16 peak_aggregate_fio.sh
#   WORKLOAD=all sbatch --array=0-15%16 peak_aggregate_fio.sh
#   SIZES="1M 10M 100M 1G" sbatch --array=0-15%16 peak_aggregate_fio.sh
#
# After the array finishes:
#   python peak_aggregate_summary.py results-peak/<TAG>
#
#SBATCH -p b200-batch
#SBATCH -N 2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=96
#SBATCH --mem-per-cpu=2G
#SBATCH --time=00:45:00
#SBATCH -J fio_peak
#SBATCH -o output-peak/%x_a%A_t%a.out
#SBATCH --exclusive
# b200-batch and rtx-batch partitions require explicit GPU declaration
# (cluster policy: jobs without --gres=gpu:N are rejected with
# "gpu request mismatch"). This is a pure-I/O fio job — no GPUs needed.
#SBATCH --gres=gpu:0

set -euo pipefail

if [[ -n "${SLURM_SUBMIT_DIR:-}" ]]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

ARRAY_SIZE="${ARRAY_SIZE:-${SLURM_ARRAY_TASK_COUNT:-16}}"
NODES_PER="${NODES_PER:-${SLURM_NNODES:-2}}"
JOBS_PER_NODE="${JOBS_PER_NODE:-32}"
SEQ_WRITE_JOBS_PER_NODE="${SEQ_WRITE_JOBS_PER_NODE:-128}"
IODEPTH="${IODEPTH:-64}"
RAND_JOBS_PER_NODE="${RAND_JOBS_PER_NODE:-64}"
RAND_IODEPTH="${RAND_IODEPTH:-128}"
HONEST_FSYNC="${HONEST_FSYNC:-1}"
SIZES="${SIZES:-1M 10M}"
# TOTAL_PER_JOB / RAND_SIZE_PER_JOB / RUNTIME tuned for HONEST cold-cache
# reads (the 512M / 12-min-wall variant was faster but produced seq_read
# numbers >2× the Vast spec, which is the cache-hit signature). Trade-off:
# longer wall, validated cluster_sum vs spec.
#
#   - TOTAL_PER_JOB=2G × numjobs=128 × 42 nodes ≈ 10 TiB seq cluster
#     footprint per (size, sweep cell). Bigger than likely CBOX cache,
#     so the intervening seq_write phase pushes seq_read source out of
#     cache before measurement.
#   - RAND_SIZE_PER_JOB stays at 512M; random access pattern dilutes
#     cache hits at 2.7 TiB footprint regardless of absolute size.
#   - RUNTIME=20 + RAMP_TIME=5: 20 s steady-state window for time_based
#     workloads. 20 s × ~50 k IOPS/node = 1 M ops/worker (sub-1% IOPS
#     noise); 20 s × ~2 GB/s/node = ~40 GiB of measured writes per node.
#   - Per-node single-pass writes are ~0.5 GB/s on small (1M) files
#     (metadata-bound) and 4–5 GB/s on larger ones. Walltime is sized
#     so even the slow 1M cell finishes at numjobs=128.
#   - seq_read single-pass window grows to ~30 s at 2G — stable on both
#     cluster_sum and conservative.
TOTAL_PER_JOB="${TOTAL_PER_JOB:-2G}"
RAND_SIZE_PER_JOB="${RAND_SIZE_PER_JOB:-1G}"
RUNTIME="${RUNTIME:-20}"
RAMP_TIME="${RAMP_TIME:-5}"
WORKLOAD="${WORKLOAD:-seq_read}"
IOENGINE="${IOENGINE:-auto}"
DATA_ROOT="${DATA_ROOT:-/work/mit/datasets/test/fio}"
FIO_BIN="${FIO_BIN:-${SCRIPT_DIR}/install/bin/fio}"
TAG="${TAG:-${SLURM_ARRAY_JOB_ID:-manual}}"
TASK_ID="${SLURM_ARRAY_TASK_ID:-0}"
CLEANUP="${CLEANUP:-1}"

cd "${SLURM_SUBMIT_DIR:-${SCRIPT_DIR}}"

if [[ ! -x "${FIO_BIN}" ]]; then
    echo "fio binary not found at ${FIO_BIN}" >&2
    exit 1
fi

# seq_* uses nrfiles up to several thousand per worker (size sweep). Raise
# the soft FD limit as high as the hard limit allows so fio doesn't trip
# the default ulimit -n during file layout. openfiles=1 in the seq fio
# jobs is the primary defence; this is belt-and-braces.
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

# Parse a size string like "4G", "100M", "4096K", "1024" into bytes.
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

echo "=== NFS mount addrs on $(hostname) ==="
nfsstat -m 2>/dev/null | grep -E "^/work|addr=" | head -4 || true

echo "=== task=${TASK_ID}/${ARRAY_SIZE} nodes=${NODES_PER} jobs/node=${JOBS_PER_NODE} \
iodepth=${IODEPTH} workload=${WORKLOAD} ==="
echo "DATA_ROOT=${DATA_ROOT}"
echo "TASK_DATA_DIR=${TASK_DATA_DIR}"
echo "RESULTS=${TASK_DIR}"
echo "SIZES (for seq_*): ${SIZES}"
echo "TOTAL_PER_JOB (for seq_*): ${TOTAL_PER_JOB}"
echo "RAND_SIZE_PER_JOB: ${RAND_SIZE_PER_JOB}"
echo "SEQ_WRITE_JOBS_PER_NODE: ${SEQ_WRITE_JOBS_PER_NODE}  (seq_read uses JOBS_PER_NODE=${JOBS_PER_NODE})"
echo "RAND_JOBS_PER_NODE/RAND_IODEPTH: ${RAND_JOBS_PER_NODE}/${RAND_IODEPTH}"
echo "HONEST_FSYNC: ${HONEST_FSYNC}  (1=wait for server commit on rand_write; 0=dishonest spec-comparison mode)"

declare -A JOBFILE=(
    [seq_read]="${SCRIPT_DIR}/jobs/seq_read_bw.fio"
    [seq_write]="${SCRIPT_DIR}/jobs/seq_write_bw.fio"
    [rand_read]="${SCRIPT_DIR}/jobs/rand_read_iops.fio"
    [rand_write]="${SCRIPT_DIR}/jobs/rand_write_iops.fio"
)

# Run order for WORKLOAD=all is shaped to keep seq_read cold:
#
#   1. seq_read_layout — pre-create the seq_read source files using
#      --create_only=1 (no measurement). If this layout pass weren't
#      explicit, fio's implicit layout would still write the files and
#      seed CBOX cache with exactly what seq_read is about to read.
#   2. seq_write — measures writes AND pushes ~10 TB of fresh data into
#      CBOX cache (60 s × 3 sizes × ~60 GB/s), evicting the seq_read
#      source files laid out in step 1.
#   3. rand_write — measures + adds further cache pressure.
#   4. seq_read — reads the files from step 1, now mostly cold.
#   5. rand_read — random access pattern is cache-resistant on its own.
#
# To override the order or run a single workload, set WORKLOAD explicitly.
if [[ "${WORKLOAD}" == "all" ]]; then
    WORKLOADS=(seq_read_layout seq_write rand_write seq_read rand_read)
else
    WORKLOADS=("${WORKLOAD}")
fi

pick_engine() {
    # Pick the best available ioengine on this node by trial. Preference chain:
    #   io_uring  — best throughput; usually blocked by container/kernel policy.
    #   libaio    — Linux kernel AIO via io_submit/io_getevents. Gives real
    #               iodepth like io_uring; less commonly blocked by seccomp
    #               than io_uring on hardened hosts.
    #   pvsync2   — preadv2/pwritev2: kernel-side sync I/O, no userspace
    #               thread-pool tax. With high numjobs often beats posixaio on
    #               4 KiB IOPS workloads.
    #   posixaio  — glibc thread-pool fallback; capped at ~10–20k IOPS/node.
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
    # Last resort — posixaio is the universal fallback even if probe glitched.
    echo "posixaio"
}

# Run one fio invocation.
# Args: wl, file_size, size_per_job, nrfiles, jobname, jobs_per_node, iodepth,
#       end_fsync, layout_only(=0)
#
# layout_only=1 sets fio --create_only=1 (lay out files on disk without
# running the measured workload) and writes the JSON to /dev/null so the
# real measurement pass's JSON file isn't pre-empted.
run_one_fio() {
    local wl="$1"
    local file_size="$2"
    local size_per_job="$3"
    local nrfiles="$4"
    local jobname="$5"
    local jobs_per_node="$6"
    local iodepth="$7"
    local end_fsync="$8"
    local layout_only="${9:-0}"

    local jobfile="${JOBFILE[$wl]:-}"
    if [[ -z "${jobfile}" ]]; then
        echo "unknown workload '${wl}'" >&2
        return 1
    fi

    local node_data_dir="${TASK_DATA_DIR}/$(hostname -s)/${jobname}"
    mkdir -p "${node_data_dir}"

    local engine
    engine=$(pick_engine "${node_data_dir}")

    # pvsync2 and other sync engines ignore iodepth and print a "note:"
    # warning to the output file that breaks JSON parsing. Cap iodepth to 1
    # for sync engines so the warning isn't emitted.
    local effective_iodepth="${iodepth}"
    case "${engine}" in
        pvsync2|sync|psync|vsync)
            effective_iodepth=1
            ;;
    esac

    local ncpu
    ncpu=$(nproc 2>/dev/null || echo 96)
    local cpus_allowed="0-$((ncpu - 1))"

    local out_json
    local -a extra_fio_args=()
    local mode_tag="measure"
    if [[ "${layout_only}" == "1" ]]; then
        out_json="/dev/null"
        extra_fio_args+=(--create_only=1)
        mode_tag="layout-only"
    else
        out_json="${TASK_DIR}/$(hostname -s).${jobname}.json"
    fi
    # fio doesn't expand env vars in [section] headers, so render the jobfile
    # via envsubst (whitelisted to wrapper-controlled vars) into a sibling
    # .fio file. fio's own $jobname/$jobnum/$filenum tokens are left intact
    # because envsubst is restricted to the listed names.
    local rendered_fio="${TASK_DIR}/$(hostname -s).${jobname}.fio"
    echo "--- fio ${jobname} [${mode_tag}] (file=${file_size}, nrfiles=${nrfiles}, size_per_job=${size_per_job}, numjobs=${jobs_per_node}, iodepth=${effective_iodepth}, end_fsync=${end_fsync}) on $(hostname) engine=${engine} -> ${out_json} ---"

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

    # --alloc-size bumps fio's smalloc pool size. Default (16 MiB × 8 pools
    # = 128 MiB total) is not enough for seq_* at small file sizes with
    # high numjobs: e.g. numjobs=128 × nrfiles=4096 at 1 MiB = 524k file
    # structs × ~384 B = 200 MiB just for file metadata, which triggers
    # "smalloc: OOM" / alloc_new_file assertion failure during layout.
    # 256 MiB per pool (2 GiB total) covers numjobs up to several hundred.
    # smalloc grows pools lazily so unused capacity has no RAM cost.
    "${FIO_BIN}" \
        --alloc-size=262144 \
        --output-format=json \
        --output="${out_json}" \
        "${extra_fio_args[@]}" \
        "${rendered_fio}"
}

# Dispatch one workload across the size sweep (seq_*) or as a single run (rand_*).
# Picks per-workload numjobs / iodepth / end_fsync.
run_one_workload() {
    local wl="$1"
    local jobs iodepth end_fsync
    # fio_wl: the real workload that drives JOBFILE lookup and on-disk
    # filenames. layout_only: 1 ⇒ pass --create_only=1 to fio so files are
    # laid out without running the measured workload.
    local fio_wl="${wl}"
    local layout_only=0
    if [[ "${wl}" == "seq_read_layout" ]]; then
        # Pre-create the seq_read source files. The intervening seq_write
        # and rand_write phases then push them out of CBOX server-side
        # cache before the real seq_read measurement runs. jobname must
        # match what the seq_read pass will use ('seq_read_<sz>') so fio
        # finds the files already on disk and skips its implicit layout.
        fio_wl="seq_read"
        layout_only=1
        jobs="${JOBS_PER_NODE}"
        iodepth="${IODEPTH}"
        end_fsync="1"
    elif [[ "${wl}" == rand_* ]]; then
        jobs="${RAND_JOBS_PER_NODE}"
        iodepth="${RAND_IODEPTH}"
        # HONEST_FSYNC controls rand_write only; rand_read doesn't use fsync.
        if [[ "${wl}" == "rand_write" ]]; then
            end_fsync="${HONEST_FSYNC}"
        else
            end_fsync="0"
        fi
    elif [[ "${wl}" == "seq_write" ]]; then
        # seq_write uses more workers than seq_read: pvsync2 is sync, so
        # the only knob for more in-flight writes is numjobs.
        jobs="${SEQ_WRITE_JOBS_PER_NODE}"
        iodepth="${IODEPTH}"
        end_fsync="1"
    else
        jobs="${JOBS_PER_NODE}"
        iodepth="${IODEPTH}"
        # seq_read / seq_write fio files have their own hardcoded end_fsync;
        # END_FSYNC isn't referenced there. Pass a placeholder for consistency.
        end_fsync="1"
    fi

    if [[ "${fio_wl}" == seq_* ]]; then
        local total_b
        total_b=$(size_to_bytes "${TOTAL_PER_JOB}")
        for sz in ${SIZES}; do
            local sz_b
            sz_b=$(size_to_bytes "${sz}")
            local nrfiles=$(( total_b / sz_b ))
            if [[ "${nrfiles}" -lt 1 ]]; then
                nrfiles=1
            fi
            # No nrfiles cap: keeping every cell's working set at
            # TOTAL_PER_JOB so the cluster footprint stays above CBOX
            # cache (cache-defeat invariant). The cost is a long layout
            # phase at small file sizes (NFS file-CREATE RPC bottleneck);
            # the Slurm walltime is sized to absorb this — DO NOT add a
            # cap to make the 1M cell faster without retracting the
            # cache-defeat invariant first.
            run_one_fio "${fio_wl}" "${sz}" "${TOTAL_PER_JOB}" "${nrfiles}" "${fio_wl}_${sz}" "${jobs}" "${iodepth}" "${end_fsync}" "${layout_only}"
        done
    else
        run_one_fio "${fio_wl}" "${RAND_SIZE_PER_JOB}" "${RAND_SIZE_PER_JOB}" 1 "${fio_wl}" "${jobs}" "${iodepth}" "${end_fsync}" "${layout_only}"
    fi
}

export -f run_one_workload run_one_fio pick_engine size_to_bytes
export SCRIPT_DIR FIO_BIN TASK_DATA_DIR TASK_DIR JOBS_PER_NODE IODEPTH \
       SEQ_WRITE_JOBS_PER_NODE \
       RAND_JOBS_PER_NODE RAND_IODEPTH HONEST_FSYNC \
       SIZES TOTAL_PER_JOB RAND_SIZE_PER_JOB \
       RUNTIME RAMP_TIME IOENGINE
export JOBFILE_seq_read="${JOBFILE[seq_read]}"
export JOBFILE_seq_write="${JOBFILE[seq_write]}"
export JOBFILE_rand_read="${JOBFILE[rand_read]}"
export JOBFILE_rand_write="${JOBFILE[rand_write]}"

for wl in "${WORKLOADS[@]}"; do
    if [[ -n "${SLURM_JOB_ID:-}" ]]; then
        srun --ntasks="${NODES_PER}" --ntasks-per-node=1 \
            bash -c "
                set -euo pipefail
                # Per-srun process: raise soft FD limit as high as the hard
                # limit allows (seq_* lays out thousands of files at small
                # sizes).
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
