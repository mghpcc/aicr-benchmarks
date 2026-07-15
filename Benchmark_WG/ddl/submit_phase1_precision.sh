#!/bin/bash
# Phase 1 -- Precision sweep (the core Paper B experiment).
# 1 node x 8 B200, pure data parallel (TP=PP=1), GBS = 128 x 8 = 1024.
# Models {1.3b, 7b} x precisions {bf16, fp8ds, fp8cs, mxfp8}  -> 8 jobs.
#
# Questions answered:
#   * Does the 2.7x FP8/BF16 GEMM gap (4103 vs 1493 TFLOP/s gpu-fryer) translate
#     to end-to-end training, and how does the realized speedup grow with model
#     size (1.3b vs 7b -> Amdahl on non-GEMM work)?
#   * Which recipe wins on Blackwell: delayed vs current scaling vs native MXFP8?
#
# Usage: bash submit_phase1_precision.sh [output_dir] [with2node]
#   output_dir : sbatch stdout dir (default: output)
#   with2node  : 1 to also submit the 2-node x 8 comm-share check (default: 0)

OUTDIR=${1:-output}
WITH2NODE=${2:-0}
mkdir -p "$OUTDIR"
OUT_FLAG="--output=$OUTDIR/out.%N-%J"

for prec in bf16 fp8ds fp8cs mxfp8; do
    for model in 1.3b 7b; do
        sbatch -p b200-batch -N 1 -n 1 --gpus-per-node=b200:8 $OUT_FLAG \
            job_ddl.sh $model $prec 1 1 1024
    done
done

# Optional: 2 nodes x 8 (DP=16, GBS=2048) for BF16 vs best FP8. FP8 shrinks
# compute time but not gradient bytes, so the grads-sync SHARE of the step
# should grow -- measure it.
if [ "$WITH2NODE" = "1" ]; then
    for prec in bf16 fp8ds mxfp8; do
        sbatch -p b200-batch -N 2 -n 2 --gpus-per-node=b200:8 $OUT_FLAG \
            job_ddl.sh 7b $prec 1 1 2048
    done
fi
