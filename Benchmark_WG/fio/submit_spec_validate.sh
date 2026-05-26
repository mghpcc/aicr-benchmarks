#!/bin/bash
# Client-count SCALING SWEEP for fair Vast spec validation.
#
# Runs spec_validate_fio.sh (cold, sustained, streaming, honest) at several
# client-node counts so you can distinguish:
#   * STORAGE-limited  — throughput plateaus below spec as nodes increase
#                        => the product does not reach the quoted number.
#   * CLIENT-limited   — throughput still rising at the full pool
#                        => you'd need more client nodes than you own to hit
#                           it; the spec may assume a bigger client fleet.
#
# Each tier is a SEPARATE TAG (results-peak/<BASE>_cNN, NN = node count) so the
# summary aggregates each independently. Tiers are CHAINED via
# --dependency=afterany so they never run concurrently — overlapping tiers
# would contend for the same storage and corrupt every per-tier number.
#
# Every tier uses the SAME methodology and the SAME cluster working set
# (DEFEAT_TIB, default 32 TiB), so each tier independently defeats cache; only
# the client count changes. Working set is held constant by spec_validate_fio.sh
# sizing per-worker file = DEFEAT / (numjobs × TOTAL_NODES).
#
# TIERS / PARTITIONS
#   6, 12, 24 nodes run on b200-batch only (homogeneous node type — cleanest
#   scaling signal). The 42-node tier adds rtx-batch because the full pool is
#   26 b200 + 16 rtx; that point mixes node types (noted in the summary).
#   Override the tier list with CLIENT_TIERS="6 12 24 42".
#
# TUNABLES
#   CLIENT_TIERS  space-separated node counts (default "6 12 24 42").
#   NUMJOBS       fio workers per node = cores (default 96). --cpus-per-task
#                 is set to match (no oversubscription).
#   DEFEAT_TIB    cluster working set per direction in TiB (default 32). Drop
#                 once the real CBOX cache size is known (use ~4× actual).
#   RUNTIME       sustained-window seconds (default 900 = 15 min).
#   TIER_TIME     Slurm --time per tier (default 16:00:00, cap 24:00:00). Small tiers lay out
#                 the full DEFEAT footprint with few nodes, so they are the
#                 slow ones — size the wall for the SMALLEST tier.
#
# WARNING (space + time): at DEFEAT_TIB=32 each tier lays out ~32 TiB per read
# source on /work and rewrites ≥32 TiB during the write phases. The 6-node tier
# can take several hours. The whole chained sweep may run overnight. This is the
# honest cost of cold+sustained measurement; lower DEFEAT_TIB/RUNTIME once the
# cache size is known if you need it faster. CLEANUP=1 frees each task's data on
# exit, so peak /work usage is roughly one tier's footprint at a time.
#
# USAGE
#   ./submit_spec_validate.sh --probe        # measure the cache first (1 node)
#   ./submit_spec_validate.sh                 # run the sweep (default DEFEAT_TIB)
#   DEFEAT_TIB=<rec> ./submit_spec_validate.sh   # ... using the probe's number
#   CLIENT_TIERS="12 42" DEFEAT_TIB=24 ./submit_spec_validate.sh
# After it finishes:
#   python spec_validate_summary.py results-peak/<BASE_TAG>
#
# FLAGS
#   --probe   submit the single-node cache-size probe (CACHE_PROBE) on
#             PROBE_PART, print a recommended DEFEAT_TIB, and EXIT (no sweep).
#             Probe tunables: PROBE_PART (b200-batch), PROBE_TIME (02:00:00),
#             CACHE_PROBE_MAX_TIB (32), CACHE_MULT (4).

set -euo pipefail

PROBE=0
for arg in "$@"; do
    case "$arg" in
        --probe) PROBE=1 ;;
        -h|--help)
            grep -E '^# ' "$0" | sed 's/^# //'; exit 0 ;;
        *) echo "unknown arg '$arg' (try --probe or --help)" >&2; exit 2 ;;
    esac
done

CLIENT_TIERS="${CLIENT_TIERS:-6 12 24 42}"
NUMJOBS="${NUMJOBS:-96}"
# Cache probe (--probe): single-node measurement on PROBE_PART. Prints a
# recommended DEFEAT_TIB; it does NOT run the sweep.
PROBE_PART="${PROBE_PART:-b200-batch}"
PROBE_TIME="${PROBE_TIME:-02:00:00}"
CACHE_PROBE_MAX_TIB="${CACHE_PROBE_MAX_TIB:-32}"
CACHE_MULT="${CACHE_MULT:-4}"
# Raised 32->128: the 32 TiB working set leaked cache at 24/42 nodes (read >
# cold ceiling). Run `CACHE_PROBE=1 ./spec_validate_fio.sh` once to measure the
# real cache, then set DEFEAT_TIB to ~4x it here.
DEFEAT_TIB="${DEFEAT_TIB:-128}"
RUNTIME="${RUNTIME:-900}"
RAMP_TIME="${RAMP_TIME:-60}"
# 16 h default (partition cap is 24 h). At DEFEAT_TIB=128 the small tiers lay
# out 128 TiB with few nodes and need >8 h; bump to 24:00:00 for c06 if needed,
# or lower DEFEAT_TIB / skip small tiers to finish faster.
TIER_TIME="${TIER_TIME:-16:00:00}"
FIO_SCRIPT="${FIO_SCRIPT:-spec_validate_fio.sh}"

BASE_TAG=specval_$(date +%s)
prev_deps=""

# Submit one array job on one partition. Echoes the jobid.
submit_array() {
    local part="$1" jname="$2" array="$3" tasks="$4" total_nodes="$5" tag="$6"
    shift 6
    local -a deps=("$@")
    TOTAL_NODES="$total_nodes" ARRAY_SIZE="$tasks" TAG="$tag" \
    WORKLOAD=all JOBS_PER_NODE="$NUMJOBS" DEFEAT_TIB="$DEFEAT_TIB" \
    RUNTIME="$RUNTIME" RAMP_TIME="$RAMP_TIME" \
        sbatch "${deps[@]}" \
               -p "$part" -J "$jname" \
               -N 2 --ntasks-per-node=1 --cpus-per-task="$NUMJOBS" \
               --time="$TIER_TIME" --gres=gpu:0 \
               --array="$array" "$FIO_SCRIPT" \
        | awk '/Submitted batch job/ {print $NF}'
}

# Submit the single-node cache probe. Echoes the jobid.
submit_probe() {
    CACHE_PROBE=1 JOBS_PER_NODE="$NUMJOBS" TAG="${BASE_TAG}_probe" \
    CACHE_PROBE_MAX_TIB="$CACHE_PROBE_MAX_TIB" CACHE_MULT="$CACHE_MULT" \
        sbatch -p "$PROBE_PART" -J "specval_probe" \
               -N1 --ntasks-per-node=1 --cpus-per-task="$NUMJOBS" \
               --time="$PROBE_TIME" --gres=gpu:0 \
               "$FIO_SCRIPT" \
        | awk '/Submitted batch job/ {print $NF}'
}

if [[ "$PROBE" == "1" ]]; then
    echo "--- cache probe on ${PROBE_PART} (1 node, max ${CACHE_PROBE_MAX_TIB} TiB, ${CACHE_MULT}x mult) ---"
    pid=$(submit_probe)
    echo "  probe jobid: ${pid}"
    echo ""
    echo "When it finishes, read the recommended DEFEAT_TIB from:"
    echo "  output-peak/specval_probe_a${pid}_t*.out"
    echo "then run the sweep with it:  DEFEAT_TIB=<rec> ./submit_spec_validate.sh"
    exit 0
fi

for nc in $CLIENT_TIERS; do
    tasks=$(( nc / 2 ))            # 2 nodes per array task
    if [[ $(( tasks * 2 )) -ne "$nc" ]]; then
        echo "tier ${nc}: client count must be even (2 nodes/task); skipping" >&2
        continue
    fi
    TAG="${BASE_TAG}_c$(printf '%02d' "$nc")"

    dep_args=()
    if [[ -n "$prev_deps" ]]; then
        dep_args=(--dependency=afterany:${prev_deps})
        echo "--- tier ${nc} nodes (TAG=${TAG}) chained after: ${prev_deps} ---"
    else
        echo "--- tier ${nc} nodes (TAG=${TAG}) submitting immediately ---"
    fi

    if [[ "$nc" -le 24 ]]; then
        # Homogeneous b200 tier: one array job, all tasks on b200-batch.
        b200_id=$(submit_array b200-batch "specval_b200_c${nc}" \
                      "0-$(( tasks - 1 ))%${tasks}" "$tasks" "$nc" "$TAG" \
                      "${dep_args[@]}")
        echo "  b200 jobid: $b200_id"
        prev_deps="${b200_id}"
    else
        # Full pool: 13 b200 tasks (26 nodes) + remaining on rtx.
        local_b200_tasks=13
        local_rtx_tasks=$(( tasks - local_b200_tasks ))
        b200_id=$(submit_array b200-batch "specval_b200_c${nc}" \
                      "0-12%13" "$tasks" "$nc" "$TAG" "${dep_args[@]}")
        echo "  b200 jobid: $b200_id"
        rtx_id=$(submit_array rtx-batch "specval_rtx_c${nc}" \
                      "13-$(( tasks - 1 ))%${local_rtx_tasks}" "$tasks" "$nc" "$TAG" \
                      "${dep_args[@]}")
        echo "  rtx  jobid: $rtx_id"
        prev_deps="${b200_id}:${rtx_id}"
    fi
done

echo ""
echo "Submitted scaling sweep CLIENT_TIERS=\"${CLIENT_TIERS}\""
echo "BASE_TAG=${BASE_TAG}"
echo ""
echo "After the sweep finishes, read the scaling curve + spec verdict:"
echo "  python spec_validate_summary.py results-peak/${BASE_TAG}"
echo "(or aggregate one tier with the existing peak_aggregate_summary.py)"
