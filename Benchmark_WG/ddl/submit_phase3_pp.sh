#!/bin/bash
# Phase 3 -- Pipeline parallelism across nodes: activation SendRecv rides the
# 26.6 GB/s GDRDMA wall the paper derives (~37 ms per GB of activations).
# 7b model, PP=2 across 2 nodes (stage boundary = node boundary), DP=8, TP=1.
# Sweep the microbatch count m = GBS/(MBS x DP) via GBS:
#   GBS  256  512  1024  2048   ->   m = 8, 16, 32, 64
#   ideal bubble (PP-1)/(m+PP-1) = 11.1%, 5.9%, 3.0%, 1.5%
# Measure the bubble fraction vs m and check the stage-boundary SendRecv time
# against the wall.                                            -> 8 jobs
#
# Usage: bash submit_phase3_pp.sh [output_dir]

OUTDIR=${1:-output}
mkdir -p "$OUTDIR"
OUT_FLAG="--output=$OUTDIR/out.%N-%J"

for prec in bf16 fp8ds; do
    for gbs in 256 512 1024 2048; do
        sbatch -p b200-batch -N 2 -n 2 --gpus-per-node=b200:8 $OUT_FLAG \
            job_ddl.sh 7b $prec 1 2 $gbs
    done
done
