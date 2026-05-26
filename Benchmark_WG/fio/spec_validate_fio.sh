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
#     1. COLD storage, MEASURED + VERIFIED — not just assumed.
#        a) MEASURE the server cache first (CACHE_PROBE): a parallel write of a
#           growing region, re-read warm; the size where warm-read BW collapses
#           toward the cold ceiling IS the cache size. (Earlier runs only
#           assumed 32 TiB and it leaked at 24/42 nodes — read > cold ceiling.)
#        b) SIZE the working set to CACHE_MULT× (default 4×) the measured cache,
#           cluster-wide, so cold blocks dominate every access.
#        c) VERIFY: the cold seq_read must come in at/under COLD_CEILING_GBPS.
#           A read above the physical cold ceiling proves residual cache — the
#           run FAILS loudly (raise DEFEAT_TIB / re-probe), it does not silently
#           report a cache number as if it were storage.
#        Client cache is killed as always (direct=1 + invalidate=1 +
#        fadvise_hint=1); reads still run only after multi-TB intervening writes.
#     2. SUSTAINED, not burst.      time_based writes run for RUNTIME (default
#        900 s = 15 min) so the CBOX NVMe write buffer saturates and we measure
#        the rate storage can hold, comparable to the vendor "sustained write".
#     3. STREAMING, not metadata.   seq_* uses large files (FILE_SIZE, default
#        1G) so bandwidth isn't throttled by file-create RPCs (the 1M-file
#        metadata trap that made seq_write read 11% of spec). This matches how
#        "max read/write GB/s" is measured.
#     4. HONEST writes.             end_fsync=1 — writes wait for server commit.
#     5. FAIR ENGINE.   io_uring/libaio (real async, RAND_IODEPTH) if available,
#        else pvsync2 (direct preadv2/pwritev2 syscalls; concurrency from
#        numjobs, iodepth clamps to 1). NOT posixaio: its glibc userspace thread
#        pool adds a context switch per op and caps random IOPS at the engine,
#        not the storage (see notes.md). The probe ABORTS rather than fall back
#        to posixaio (override ALLOW_SLOW_ENGINE=1). On this cluster io_uring is
#        kernel-disabled and libaio is absent, so pvsync2 is the fair engine.
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
#   Each write phase touches ≥DEFEAT_TIB of distinct blocks; with DEFEAT_TIB
#   sized to CACHE_MULT× the MEASURED cache, the read sources are displaced and
#   both reads are cold. Coldness is then VERIFIED, not assumed: a cold read
#   above the physical ceiling fails the run (see VERIFY_COLD).
#
# KEY TUNABLES (override via env / sbatch --export)
#   TOTAL_NODES     total client nodes in THIS tier (NODES_PER × ARRAY_SIZE).
#                   Required for sizing — submit_spec_validate.sh sets it.
#                   Working set per fio worker = DEFEAT / (JOBS_PER_NODE ×
#                   TOTAL_NODES) so the CLUSTER footprint = DEFEAT regardless
#                   of node count (every tier defeats cache independently).
#   DEFEAT_TIB      cluster-wide working set per direction, in TiB (default 128,
#                   raised from 32 after c24/c42 leaked cache at 32). Must exceed
#                   the CBOX server cache by a comfortable margin. Run CACHE_PROBE
#                   once to measure the cache, then set this to CACHE_MULT× it.
#   CACHE_PROBE     1 = run the warm-re-read cache-size probe, print a
#                   recommended DEFEAT_TIB, and exit without running the suite
#                   (default 0). Same as WORKLOAD=cache_probe.
#   CACHE_MULT      working set must be >= CACHE_MULT × measured cache (default 4).
#   COLD_CEILING_GBPS  physical cold-media seq_read ceiling for the VERIFY gate
#                   (default 462 = spec Max). A measured cold read above this is
#                   cache, not storage.
#   VERIFY_COLD     1 (default) = FAIL the run (exit 4) if the cold seq_read
#                   exceeds the ceiling; 0 = warn only.
#   FILE_SIZE       per-file size for seq_* streaming (default 1G). Large on
#                   purpose: peak BW, not a metadata-create benchmark.
#   JOBS_PER_NODE   fio numjobs per node = allocated cores (default 96). Never
#                   set above cores (oversubscription regresses — see
#                   summary.md n128). submit sets --cpus-per-task to match.
#   SEQ_IODEPTH / RAND_IODEPTH   queue depth per worker (default 8 / 64). Random
#                   IOPS needs a real depth on the async engine to measure the
#                   device, not per-op latency.
#   RUNTIME         steady-state seconds for time_based phases (default 900).
#   RAMP_TIME       warm-up seconds before measurement (default 60).
#   HONEST_FSYNC    1 (default) = writes wait for server commit. 0 = buffered
#                   (dishonest vs a durability spec); leave at 1 for validation.
#   WORKLOAD        all (default) | seq_read | seq_write | rand_read |
#                   rand_write | seq_read_layout | rand_read_layout | cache_probe
#   IOENGINE        auto (default; io_uring→libaio, then ABORT — no posixaio
#                   fallback) or explicit. REQUIRE_FAST_ENGINE=1 (default) makes
#                   the abort hard; ALLOW_SLOW_ENGINE=1 permits posixaio (NOT
#                   spec-fair: its userspace thread pool caps IOPS).
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
# Cache-defeat working set, cluster-wide, per direction. Default raised 32->128:
# the c24/c42 leak proved the effective read cache is >32 TiB (measured floor
# ~16 TiB, but write traffic does NOT evict the read cache, so out-sizing is the
# only sure lever). Run with CACHE_PROBE=1 once to measure it, then this is
# auto-bumped to CACHE_MULT× the measured cache if that is larger.
DEFEAT_TIB="${DEFEAT_TIB:-128}"
CACHE_PROBE="${CACHE_PROBE:-0}"      # 1 = measure server cache before the suite
CACHE_MULT="${CACHE_MULT:-4}"        # working set >= CACHE_MULT × measured cache
CACHE_PROBE_MAX_TIB="${CACHE_PROBE_MAX_TIB:-32}"  # probe sweep ceiling (single
                                     # node writes up to this much — minutes/TiB)
# Physical cold-media ceilings (cluster aggregate) used for the cold-read
# VERIFY gate. A cold read at/over these is impossible from media => cache leak.
COLD_CEILING_GBPS="${COLD_CEILING_GBPS:-462}"     # seq_read spec Max
VERIFY_COLD="${VERIFY_COLD:-1}"      # 1 = FAIL (exit 4) if cold read > ceiling;
                                     # 0 = warn only.
# Per-task tolerance: the suite splits a tier into 2-node array tasks, so the
# gate compares each task's read to its node-share of the ceiling. Allow some
# headroom for node-speed variance before declaring a leak. The authoritative
# cluster-wide check is still spec_validate_summary.py (CACHE?/INCONCLUSIVE).
VERIFY_MARGIN="${VERIFY_MARGIN:-1.2}"
FILE_SIZE="${FILE_SIZE:-1G}"
RUNTIME="${RUNTIME:-900}"
RAMP_TIME="${RAMP_TIME:-60}"
HONEST_FSYNC="${HONEST_FSYNC:-1}"
WORKLOAD="${WORKLOAD:-all}"
# Engine fairness: require a real async engine. auto probes io_uring->libaio and
# ABORTS rather than dropping to posixaio (which caps IOPS in userspace).
IOENGINE="${IOENGINE:-auto}"
REQUIRE_FAST_ENGINE="${REQUIRE_FAST_ENGINE:-1}"   # 1 = abort if only posixaio
ALLOW_SLOW_ENGINE="${ALLOW_SLOW_ENGINE:-0}"       # 1 = permit posixaio anyway
DATA_ROOT="${DATA_ROOT:-/work/mit/datasets/test/fio}"
FIO_BIN="${FIO_BIN:-${SCRIPT_DIR}/install/bin/fio}"
TAG="${TAG:-${SLURM_ARRAY_JOB_ID:-manual}}"
TASK_ID="${SLURM_ARRAY_TASK_ID:-0}"
CLEANUP="${CLEANUP:-1}"

# Queue depth: random IOPS needs a real depth on the async engine to be a fair
# storage measurement (iodepth=1 measures latency, not the device). Sequential
# BW is driven by numjobs streaming, so a small depth is enough.
SEQ_IODEPTH="${SEQ_IODEPTH:-8}"
RAND_IODEPTH="${RAND_IODEPTH:-64}"
IODEPTH="${SEQ_IODEPTH}"   # default; run_one_workload picks per direction.

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

engine_loads() {   # 1 if the engine loads + runs a 4k probe write, else 0
    local eng="$1" probe_dir="$2"
    mkdir -p "${probe_dir}"
    local probe_file="${probe_dir}/.engine_probe_${eng}"
    local probe_out
    probe_out=$("${FIO_BIN}" \
        --name=probe --ioengine="${eng}" --rw=write --bs=4k --size=4k \
        --filename="${probe_file}" --direct=1 \
        --runtime=1 --time_based=0 \
        --output-format=normal 2>&1 || true)
    rm -f "${probe_file}"
    if echo "${probe_out}" | grep -qE "Operation not permitted|failed to load engine|not loadable|error="; then
        echo 0
    else
        echo 1
    fi
}

pick_engine() {
    local probe_dir="$1"
    if [[ "${IOENGINE}" != "auto" ]]; then
        echo "${IOENGINE}"
        return
    fi
    # FAIR engines, best first:
    #   io_uring/libaio - real async, high iodepth per thread.
    #   pvsync2         - direct preadv2/pwritev2 syscalls, no engine tax;
    #                     concurrency comes from numjobs (iodepth clamps to 1).
    # The ONLY engine refused is posixaio: its glibc userspace thread pool adds
    # a context switch per op and caps IOPS at the engine, not the storage.
    local eng
    for eng in io_uring libaio pvsync2; do
        if [[ "$(engine_loads "${eng}" "${probe_dir}")" == "1" ]]; then
            echo "${eng}"; return
        fi
    done
    if [[ "${ALLOW_SLOW_ENGINE}" == "1" || "${REQUIRE_FAST_ENGINE}" != "1" ]]; then
        echo "posixaio"; return
    fi
    echo "FATAL: no fair engine (io_uring/libaio/pvsync2) loaded on $(hostname);" >&2
    echo "       refusing to fall back to posixaio — its userspace thread pool" >&2
    echo "       caps random IOPS at the engine and would understate the storage" >&2
    echo "       (unfair vs the vendor spec). Fixes: unblock io_uring" >&2
    echo "       (kernel.io_uring_disabled=0) / install libaio, or set" >&2
    echo "       ALLOW_SLOW_ENGINE=1 to measure anyway (results NOT spec-fair)." >&2
    exit 3
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
        # seq BW: streaming over many files; modest depth, driven by numjobs.
        run_one_fio "${fio_wl}" "${PER_JOB_BYTES}" "${SEQ_NRFILES}" "${fio_wl}" \
            "${jobs}" "${SEQ_IODEPTH}" "${end_fsync}" "${layout_only}"
    else
        # rand_*: one large file per worker (nrfiles=1) spanning the working set.
        # Real queue depth so IOPS reflects the device, not per-op latency.
        run_one_fio "${fio_wl}" "${PER_JOB_BYTES}" 1 "${fio_wl}" \
            "${jobs}" "${RAND_IODEPTH}" "${end_fsync}" "${layout_only}"
    fi
}

# --- sum read|write bw across a set of fio JSON files, in GB/s -------------
fio_aggr_gbps() {   # $1=read|write ; $2..=json files
    local side="$1"; shift
    [[ $# -eq 0 ]] && { echo "0.0"; return; }
    python3 - "${side}" "$@" <<'PY'
import json,sys
side=sys.argv[1]; tot=0.0
for f in sys.argv[2:]:
    try: d=json.load(open(f))
    except Exception: continue
    for j in d.get("jobs",[]):
        tot+=float(j.get(side,{}).get("bw_bytes",0.0))
print(f"{tot/1e9:.1f}")
PY
}

# --- CACHE PROBE -----------------------------------------------------------
# Measure the server read cache: write a growing region, immediately re-read it
# warm. While the region fits in cache the warm re-read runs far above cold
# media; once it overflows, BW collapses toward the cold ceiling. The largest
# size that still reads "warm-fast" is the cache reach. Single-node by design —
# the server cache is shared, so one node re-reading region R already exercises
# the whole cache. Prints a recommended DEFEAT_TIB and exits (no suite run).
cache_probe() {
    local eng; eng=$(pick_engine "${TASK_DATA_DIR}/probe")
    local pdir="${TASK_DATA_DIR}/probe"; mkdir -p "${pdir}"
    local njobs=$(( JOBS_PER_NODE < 16 ? JOBS_PER_NODE : 16 ))
    echo "=== CACHE PROBE on $(hostname) engine=${eng} (warm re-read sweep, max ${CACHE_PROBE_MAX_TIB} TiB) ==="
    echo "    NOTE: single-node lower-bound estimate; writes up to ${CACHE_PROBE_MAX_TIB} TiB (slow)."
    echo "    The cluster-scale 'no cache' guarantee is the per-run COLD-READ VERIFY gate."
    local plateau=0 cache_tib=0 s_tib=1
    while [[ "${s_tib}" -le "${CACHE_PROBE_MAX_TIB}" ]]; do
        local per_job=$(( s_tib * 1024 * 1024 * 1024 * 1024 / njobs ))
        local wj="${pdir}/w.json" rj="${pdir}/r.json"
        # write fresh distinct data
        "${FIO_BIN}" --name=pw --ioengine="${eng}" --direct=1 --rw=write --bs=1M \
            --size="${per_job}" --numjobs="${njobs}" --group_reporting=1 \
            --directory="${pdir}" --filename_format='probe.$jobnum' \
            --end_fsync=1 --output-format=json --output="${wj}" >/dev/null 2>&1 || true
        # immediately re-read it (warm if it fit in cache)
        "${FIO_BIN}" --name=pr --ioengine="${eng}" --direct=1 --rw=read --bs=1M \
            --size="${per_job}" --numjobs="${njobs}" --group_reporting=1 \
            --directory="${pdir}" --filename_format='probe.$jobnum' \
            --invalidate=1 --loops=1 --output-format=json --output="${rj}" >/dev/null 2>&1 || true
        local warm; warm=$(fio_aggr_gbps read "${rj}")
        echo "  probe ${s_tib} TiB -> warm re-read ${warm} GB/s"
        rm -f "${pdir}"/probe.* "${wj}" "${rj}" 2>/dev/null || true
        # first point sets the in-cache plateau; cache reach = last size still
        # within 70% of that plateau.
        if awk -v p="${plateau}" 'BEGIN{exit !(p==0)}'; then plateau="${warm}"; fi
        if awk -v w="${warm}" -v p="${plateau}" 'BEGIN{exit !(w>=0.7*p)}'; then
            cache_tib="${s_tib}"
        else
            break
        fi
        s_tib=$(( s_tib * 2 ))
    done
    local rec; rec=$(( cache_tib * CACHE_MULT ))
    echo "=== CACHE PROBE result: cache reach >= ${cache_tib} TiB (single-node lower bound) ==="
    echo "    Recommended DEFEAT_TIB >= ${CACHE_MULT} x ${cache_tib} = ${rec} TiB"
    echo "    Re-run the suite with:  DEFEAT_TIB=${rec} ./spec_validate_fio.sh"
}

# --- COLD-READ VERIFY ------------------------------------------------------
# After the suite, sum this task's measured seq_read and compare to the cold
# ceiling scaled to this task's node share. A cold read at/over the physical
# ceiling is impossible from media => residual server cache leaked in. Fail
# loudly (VERIFY_COLD=1) instead of reporting a cache number as storage.
verify_cold_read() {
    shopt -s nullglob; local files=( "${TASK_DIR}"/*.seq_read.json ); shopt -u nullglob
    [[ ${#files[@]} -eq 0 ]] && return 0
    local gbps share
    gbps=$(fio_aggr_gbps read "${files[@]}")
    share=$(python3 -c "print(f'{${COLD_CEILING_GBPS}*${NODES_PER}/${TOTAL_NODES}*${VERIFY_MARGIN}:.1f}')")
    echo "=== COLD-READ VERIFY: seq_read=${gbps} GB/s vs cold ceiling ${share} GB/s (${NODES_PER}/${TOTAL_NODES} nodes, x${VERIFY_MARGIN} margin) ==="
    if awk -v g="${gbps}" -v c="${share}" 'BEGIN{exit !(g>c)}'; then
        echo "FAIL: cold seq_read ${gbps} GB/s exceeds the cold-media ceiling ${share} GB/s" >&2
        echo "      => residual server cache leaked into the read; NOT a cold number." >&2
        echo "      Raise DEFEAT_TIB (now ${DEFEAT_TIB}) and re-run, or CACHE_PROBE=1 first." >&2
        if [[ "${VERIFY_COLD}" == "1" ]]; then exit 4; fi
        echo "      (VERIFY_COLD=0: warning only, continuing.)" >&2
    else
        echo "    PASS: read is at/under the cold ceiling — cold by the ceiling test."
    fi
}

export -f run_one_workload run_one_fio pick_engine engine_loads size_to_bytes
export SCRIPT_DIR FIO_BIN TASK_DATA_DIR TASK_DIR JOBS_PER_NODE IODEPTH \
       SEQ_IODEPTH RAND_IODEPTH REQUIRE_FAST_ENGINE ALLOW_SLOW_ENGINE \
       HONEST_FSYNC PER_JOB_BYTES SEQ_NRFILES RUNTIME RAMP_TIME IOENGINE
export JOBFILE_seq_read="${JOBFILE[seq_read]}"
export JOBFILE_seq_write="${JOBFILE[seq_write]}"
export JOBFILE_rand_read="${JOBFILE[rand_read]}"
export JOBFILE_rand_write="${JOBFILE[rand_write]}"

# Preflight cache measurement (optional). Measures and prints a recommended
# DEFEAT_TIB, then exits — does not run the suite.
if [[ "${WORKLOAD}" == "cache_probe" || "${CACHE_PROBE}" == "1" ]]; then
    cache_probe
    exit 0
fi

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
                $(declare -f engine_loads)
                $(declare -f pick_engine)
                $(declare -f run_one_fio)
                $(declare -f run_one_workload)
                run_one_workload '${wl}'
            "
    else
        run_one_workload "${wl}"
    fi
done

# Enforced cold-read gate: a measured seq_read above the cold-media ceiling is
# cache, not storage. Runs whenever the measured seq_read phase was part of this
# run (suite 'all' or WORKLOAD=seq_read).
if [[ "${WORKLOAD}" == "all" || "${WORKLOAD}" == "seq_read" ]]; then
    verify_cold_read
fi

echo "Done. Task results: ${TASK_DIR}"
