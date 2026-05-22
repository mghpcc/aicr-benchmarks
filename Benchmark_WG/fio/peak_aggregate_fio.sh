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
#   seq_read      sequential read,  bs=1M  (peak read BW)
#   seq_write     sequential write, bs=1M  (peak write BW)
#   rand_read     random read,      bs=4k  (peak read IOPS)
#   rand_write    random write,     bs=4k  (peak write IOPS)
#   all           run all four back to back (BW, then write IOPS, then read IOPS)
#
# For read workloads, the test file is auto-prepopulated via a one-shot
# sequential-write pass with --create-only=1 if any of the per-job files are
# missing or smaller than SIZE_PER_JOB.
#
# Tunables (override via env or sbatch --export):
#   ARRAY_SIZE      number of concurrent array tasks (default 16)
#   NODES_PER       nodes per array task (default 2)
#   JOBS_PER_NODE   fio numjobs per node (default 32)
#   IODEPTH         fio per-job iodepth (default 64)
#   SIZE_PER_JOB    file size per fio job (default 16G)
#   RUNTIME         seconds per workload (default 60)
#   RAMP_TIME       seconds to ramp before measurement (default 10)
#   WORKLOAD        one of: seq_read, seq_write, rand_read, rand_write, all
#                   (default: seq_read)
#   IOENGINE        fio ioengine. Default 'auto' probes io_uring on each
#                   compute node and falls back to posixaio if the kernel
#                   refuses (login nodes and many container runtimes block
#                   io_uring with EPERM). The local fio build is missing
#                   libaio because libaio-devel wasn't present at configure
#                   time, so io_uring vs posixaio is the real choice.
#                   Set explicitly to 'io_uring' or 'posixaio' to skip the
#                   probe.
#   DATA_ROOT       base writable directory (default /work/mit/datasets/test/fio)
#   FIO_BIN         path to fio binary (default $SCRIPT_DIR/install/bin/fio)
#   TAG             subdir name under results-peak/ (default array job id)
#   CLEANUP         1 (default) → rm -rf this task's data subtree on exit so
#                   the run doesn't leave hundreds of GB lying around. Set
#                   CLEANUP=0 to keep files (useful if you want to re-run
#                   read workloads against an already-laid-out file set).
#
# Usage (from /home/shaohao_mit/benchmarks/fio/):
#   # default: seq_read, 16 tasks × 2 nodes, b200-batch
#   sbatch --array=0-15%16 peak_aggregate_fio.sh
#
#   # rtx-batch run, override partition and job name:
#   sbatch -p rtx-batch -J fio_peak_rtx --array=0-7%8 peak_aggregate_fio.sh
#
#   # write-bandwidth sweep:
#   WORKLOAD=seq_write sbatch --array=0-15%16 peak_aggregate_fio.sh
#
#   # random-IOPS sweep on rtx, 8 tasks × 2 nodes:
#   WORKLOAD=rand_read sbatch -p rtx-batch -J fio_iops_rtx \
#       --array=0-7%8 peak_aggregate_fio.sh
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

set -euo pipefail

# Under Slurm, sbatch copies this script into /var/spool/slurmd/job<N>/
# and executes the copy, so BASH_SOURCE resolves to that staging path —
# install/bin/fio and jobs/*.fio live next to where the user submitted from,
# not next to the running copy. Prefer SLURM_SUBMIT_DIR when present.
if [[ -n "${SLURM_SUBMIT_DIR:-}" ]]; then
    SCRIPT_DIR="${SLURM_SUBMIT_DIR}"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

ARRAY_SIZE="${ARRAY_SIZE:-${SLURM_ARRAY_TASK_COUNT:-16}}"
NODES_PER="${NODES_PER:-${SLURM_NNODES:-2}}"
JOBS_PER_NODE="${JOBS_PER_NODE:-32}"
IODEPTH="${IODEPTH:-64}"
SIZE_PER_JOB="${SIZE_PER_JOB:-16G}"
RUNTIME="${RUNTIME:-60}"
RAMP_TIME="${RAMP_TIME:-10}"
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

# Each task gets its own data subdirectory under DATA_ROOT so no two tasks
# ever touch the same file. Task subdir is the cache-isolation boundary
# (analogous to the per-task shard.index in the raw-io v2 script).
TASK_DATA_DIR="${DATA_ROOT}/${TAG}/task_${TASK_ID}"
RUN_DIR="results-peak/${TAG}"
TASK_DIR="${RUN_DIR}/task_${TASK_ID}"
mkdir -p "${TASK_DATA_DIR}" "${TASK_DIR}"

# Cleanup runs on any script exit (success, error, signal) so the run never
# leaves hundreds of GB of fio scratch behind. Only this task's data
# subtree is removed; the JSON results in TASK_DIR are kept. Set CLEANUP=0
# to skip — useful if you want to inspect the laid-out files or re-run
# read workloads against an existing file set.
cleanup_task_data() {
    local rc=$?
    if [[ "${CLEANUP}" == "1" && -n "${TASK_DATA_DIR}" && -d "${TASK_DATA_DIR}" ]]; then
        echo "--- cleanup: rm -rf ${TASK_DATA_DIR} (exit rc=${rc}) ---"
        rm -rf -- "${TASK_DATA_DIR}" || true
        # try to remove the run-level dir too; harmless if siblings still hold it
        rmdir --ignore-fail-on-non-empty "${DATA_ROOT}/${TAG}" 2>/dev/null || true
    elif [[ "${CLEANUP}" != "1" ]]; then
        echo "--- cleanup: CLEANUP=${CLEANUP}, leaving ${TASK_DATA_DIR} in place ---"
    fi
    return ${rc}
}
trap cleanup_task_data EXIT

# --- report which CBOX VIP each node mounted (sanity-check distribution) ------
echo "=== NFS mount addrs on $(hostname) ==="
nfsstat -m 2>/dev/null | grep -E "^/work|addr=" | head -4 || true

echo "=== task=${TASK_ID}/${ARRAY_SIZE} nodes=${NODES_PER} jobs/node=${JOBS_PER_NODE} \
iodepth=${IODEPTH} size=${SIZE_PER_JOB} runtime=${RUNTIME}s workload=${WORKLOAD} ==="
echo "DATA_ROOT=${DATA_ROOT}"
echo "TASK_DATA_DIR=${TASK_DATA_DIR}"
echo "RESULTS=${TASK_DIR}"

# Map workload name → fio jobfile.
declare -A JOBFILE=(
    [seq_read]="${SCRIPT_DIR}/jobs/seq_read_bw.fio"
    [seq_write]="${SCRIPT_DIR}/jobs/seq_write_bw.fio"
    [rand_read]="${SCRIPT_DIR}/jobs/rand_read_iops.fio"
    [rand_write]="${SCRIPT_DIR}/jobs/rand_write_iops.fio"
)

# Workload order when WORKLOAD=all.
if [[ "${WORKLOAD}" == "all" ]]; then
    WORKLOADS=(seq_write seq_read rand_write rand_read)
else
    WORKLOADS=("${WORKLOAD}")
fi

pick_engine() {
    # Decide which ioengine to use on this node. With IOENGINE=auto, probe
    # io_uring with a 4 KiB throwaway op; if the kernel refuses (EPERM on
    # locked-down nodes, or if io_uring isn't built into fio) fall back to
    # posixaio. Explicit IOENGINE settings skip the probe.
    local probe_dir="$1"
    if [[ "${IOENGINE}" != "auto" ]]; then
        echo "${IOENGINE}"
        return
    fi
    mkdir -p "${probe_dir}"
    local probe_file="${probe_dir}/.io_uring_probe"
    local probe_out
    probe_out=$("${FIO_BIN}" \
        --name=probe --ioengine=io_uring --rw=write --bs=4k --size=4k \
        --filename="${probe_file}" --direct=1 \
        --runtime=1 --time_based=0 \
        --output-format=normal 2>&1 || true)
    rm -f "${probe_file}"
    if echo "${probe_out}" | grep -qE "Operation not permitted|failed to load engine|engine io_uring not loadable|error="; then
        echo "posixaio"
    else
        echo "io_uring"
    fi
}

run_one_workload() {
    local wl="$1"
    local jobfile="${JOBFILE[$wl]:-}"
    if [[ -z "${jobfile}" ]]; then
        echo "unknown workload '${wl}'" >&2
        return 1
    fi

    local node_data_dir="${TASK_DATA_DIR}/$(hostname -s)/${wl}"
    mkdir -p "${node_data_dir}"

    # No explicit prefill step: with time_based=1 + size=, fio lays out the
    # backing files BEFORE the runtime clock starts, so read workloads
    # against a fresh directory still measure real reads, not writes-then-reads.

    local engine
    engine=$(pick_engine "${node_data_dir}")

    # cpus_allowed_policy=split divides cpus_allowed across numjobs so each
    # job lands on a disjoint CPU subset. Use the full set of CPUs the
    # process can see (controlled by Slurm via --cpus-per-task).
    local ncpu
    ncpu=$(nproc 2>/dev/null || echo 96)
    local cpus_allowed="0-$((ncpu - 1))"

    local out_json="${TASK_DIR}/$(hostname -s).${wl}.json"
    echo "--- running fio ${wl} on $(hostname) engine=${engine} cpus=${cpus_allowed} -> ${out_json} ---"
    DATA_DIR="${node_data_dir}" \
    SIZE_PER_JOB="${SIZE_PER_JOB}" \
    NUMJOBS="${JOBS_PER_NODE}" \
    RUNTIME="${RUNTIME}" \
    RAMP_TIME="${RAMP_TIME}" \
    IODEPTH="${IODEPTH}" \
    IOENGINE="${engine}" \
    CPUS_ALLOWED="${cpus_allowed}" \
        "${FIO_BIN}" \
            --output-format=json \
            --output="${out_json}" \
            "${jobfile}"
}

# Run all workloads on every node in the task via srun. One fio process per
# node (numjobs=JOBS_PER_NODE inside fio gives intra-node parallelism), so
# --ntasks-per-node=1 and --cpus-per-task=JOBS_PER_NODE.
export -f run_one_workload pick_engine
export SCRIPT_DIR FIO_BIN TASK_DATA_DIR TASK_DIR JOBS_PER_NODE IODEPTH \
       SIZE_PER_JOB RUNTIME RAMP_TIME IOENGINE
export JOBFILE_seq_read="${JOBFILE[seq_read]}"
export JOBFILE_seq_write="${JOBFILE[seq_write]}"
export JOBFILE_rand_read="${JOBFILE[rand_read]}"
export JOBFILE_rand_write="${JOBFILE[rand_write]}"

for wl in "${WORKLOADS[@]}"; do
    if [[ -n "${SLURM_JOB_ID:-}" ]]; then
        srun --ntasks="${NODES_PER}" --ntasks-per-node=1 \
            bash -c "
                set -euo pipefail
                declare -A JOBFILE=(
                    [seq_read]=\"\$JOBFILE_seq_read\"
                    [seq_write]=\"\$JOBFILE_seq_write\"
                    [rand_read]=\"\$JOBFILE_rand_read\"
                    [rand_write]=\"\$JOBFILE_rand_write\"
                )
                $(declare -f run_one_workload)
                run_one_workload '${wl}'
            "
    else
        # Bare-shell fallback (no Slurm) — useful for smoke tests on the
        # submit host. Runs one node's worth of work locally.
        run_one_workload "${wl}"
    fi
done

echo "Done. Task results: ${TASK_DIR}"
