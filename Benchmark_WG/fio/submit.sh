#!/bin/bash
# Combined b200 + rtx submission for the fio peak-aggregate suite, with a
# numjobs sweep.
#
# For each value in NUMJOBS_SWEEP (default "96 128"), submits one b200 +
# one rtx array job, both running WORKLOAD=all under that numjobs value.
# Sweep cells are CHAINED via --dependency=afterany so sweep N+1 only
# starts after both b200 and rtx of sweep N have finished. Without the
# chain, Slurm could schedule e.g. b200@n96 alongside rtx@n128 (different
# partitions, no global slot contention) and split each TAG's data across
# different calendar windows — invalid for an aggregate measurement.
#
# Within a single sweep, b200 and rtx race independently; they share no
# explicit dependency, but they target different partitions and both
# need 42 nodes worth of /work I/O. Submitting them back-to-back gives
# Slurm room to start them together as in prior runs.
#
# Sizing (~28 idle b200 + ~17 idle rtx ≈ 42 nodes):
#   13 b200 tasks × 2 nodes = 26 nodes  (--array=0-12)
#    8 rtx  tasks × 2 nodes = 16 nodes  (--array=13-20)
#   ARRAY_SIZE=21 → 21 disjoint per-task data subdirs under DATA_ROOT.
#
# WORKLOAD=all expands inside the wrapper to:
#   seq_read_layout → seq_write → rand_write → seq_read → rand_read
# (cache-cold reads, see peak_aggregate_fio.sh docstring).
#
# Tunables:
#   NUMJOBS_SWEEP   space-separated numjobs values (default "96 128").
#                   Applied uniformly to seq_read, seq_write, rand_read,
#                   rand_write within each sweep cell.
#   WORKLOAD        passed through to the wrapper (default "all").
#   SIZES           seq_* file size sweep (default "1M 10M 100M").

set -euo pipefail

WORKLOAD="${WORKLOAD:-all}"
NUMJOBS_SWEEP="${NUMJOBS_SWEEP:-96 128}"
SIZES="${SIZES:-1M 10M 100M}"

BASE_TAG=fio_$(date +%s)
prev_deps=""

for nj in $NUMJOBS_SWEEP; do
    TAG="${BASE_TAG}_n${nj}"

    dep_args=()
    if [[ -n "$prev_deps" ]]; then
        dep_args=(--dependency=afterany:${prev_deps})
        echo "--- Sweep numjobs=${nj} (TAG=${TAG}) chained after: ${prev_deps} ---"
    else
        echo "--- Sweep numjobs=${nj} (TAG=${TAG}) submitting immediately ---"
    fi

    b200_id=$(ARRAY_SIZE=21 TAG=$TAG WORKLOAD=$WORKLOAD SIZES="$SIZES" \
        JOBS_PER_NODE=$nj SEQ_WRITE_JOBS_PER_NODE=$nj RAND_JOBS_PER_NODE=$nj \
        IODEPTH=64 RAND_IODEPTH=128 RUNTIME=20 RAMP_TIME=5 \
            sbatch "${dep_args[@]}" \
                   -p b200-batch -J fio_peak_b200_n${nj} \
                   -N 2 --ntasks-per-node=1 --cpus-per-task=96 \
                   --gres=gpu:0 \
                   --array=0-12%13 peak_aggregate_fio.sh \
            | awk '/Submitted batch job/ {print $NF}')
    echo "  b200 jobid: $b200_id"

    rtx_id=$(ARRAY_SIZE=21 TAG=$TAG WORKLOAD=$WORKLOAD SIZES="$SIZES" \
        JOBS_PER_NODE=$nj SEQ_WRITE_JOBS_PER_NODE=$nj RAND_JOBS_PER_NODE=$nj \
        IODEPTH=64 RAND_IODEPTH=128 RUNTIME=20 RAMP_TIME=5 \
            sbatch "${dep_args[@]}" \
                   -p rtx-batch -J fio_peak_rtx_n${nj} \
                   -N 2 --ntasks-per-node=1 --cpus-per-task=96 \
                   --gres=gpu:0 \
                   --array=13-20%8 peak_aggregate_fio.sh \
            | awk '/Submitted batch job/ {print $NF}')
    echo "  rtx  jobid: $rtx_id"

    prev_deps="${b200_id}:${rtx_id}"
done

echo ""
echo "Submitted NUMJOBS_SWEEP=\"${NUMJOBS_SWEEP}\""
echo "BASE_TAG=${BASE_TAG}"
echo ""
echo "After each sweep finishes, aggregate its TAG independently:"
for nj in $NUMJOBS_SWEEP; do
    echo "  python peak_aggregate_summary.py results-peak/${BASE_TAG}_n${nj}"
done
