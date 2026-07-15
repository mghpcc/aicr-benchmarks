#!/bin/bash
# Phase 0b -- Micro-batch-size tuning: make sure the baseline is TUNED for
# B200 before any FP8-vs-BF16 claim (reviewers will ask).
# 7b, 1 node x 8 GPU, DP=8, GBS fixed at 1024, MBS in {2,4,8,16}
# x {bf16, fp8ds}, 20 iters (~15 min/job).                    -> 8 jobs
# NOTE: must run on b200-batch -- the b200-devel QOS caps each user at 2 GPUs,
# so 8-GPU jobs pend forever there (b200-batch allows 32 GPUs/user).
#
# Notes:
#   * MBS sets the GEMM M-dim (M = MBS x 2048); larger MBS -> fatter GEMMs,
#     fewer launches. Accumulation adjusts automatically (GBS/(MBS x DP)).
#   * Expected OOMs are a RESULT, not a failure: 7b unsharded DP holds
#     ~126 GB of weights+optimizer, so BF16 likely OOMs at MBS >= 8.
#     FP8 halves activation bytes -> if FP8 sustains a larger MBS than BF16,
#     that is itself a Paper B finding (FP8 memory headroom).
#   * Afterwards: pick best MBS per precision, set it in the phase 1-4 submit
#     scripts (arg 6 of job_ddl.sh), and KEEP one MBS=4 job per precision in
#     phase 1 as the anchor to the paper's convention (see CLAUDE.md).
#
# Usage: bash submit_phase0b_mbs.sh [output_dir]

OUTDIR=${1:-output}
mkdir -p "$OUTDIR"
OUT_FLAG="--output=$OUTDIR/out.%N-%J"

for prec in bf16 fp8ds; do
    for mbs in 2 4 8 16; do
        sbatch -p b200-batch -t 1:00:00 -N 1 -n 1 --gpus-per-node=b200:8 $OUT_FLAG \
            job_ddl.sh 7b $prec 1 1 1024 $mbs 20
    done
done
