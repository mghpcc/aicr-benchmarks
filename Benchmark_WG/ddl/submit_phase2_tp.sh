#!/bin/bash
# Phase 2 -- Tensor parallelism: exercise the 841 GB/s NVLink AllReduce the
# paper measures but never uses in training.
# 7b model, {bf16, fp8ds} x TP={1,2,4,8} intra-node          -> 8 jobs
# plus TP=8 SPANNING 2 nodes (4 GPU/node) to quantify the drop onto the
# 218 GB/s inter-node AllGather+ReduceScatter path            -> 2 jobs
# plus TP=8 intra-node x DP=2 across nodes (2 x 8, the guidance-table
# hybrid) -- completes the fixed-16-GPU DP/TP/PP strategy
# comparison with phase 1 (DP=16) and phase 3 (PP=2 x DP=8)   -> 2 jobs
# plus 13b at TP={2,4,8} (needs TP>=2 to fit; larger GEMMs)   -> 4 jobs
#
# Success criteria (from future-work.md): near-flat TFLOP/s/GPU up to TP=8
# intra-node; measurable, explainable drop when TP spans nodes (~4x slower
# collective path) -- validates the paper's guidance table. The 16-GPU
# strategy comparison (same model/GPUs/GBS, only the parallelism changes)
# turns the guidance table into a measured end-to-end result.
#
# Usage: bash submit_phase2_tp.sh [output_dir]

OUTDIR=${1:-output}
mkdir -p "$OUTDIR"
OUT_FLAG="--output=$OUTDIR/out.%N-%J"

# Intra-node TP sweep: 8 GPUs total, DP = 8/TP, GBS fixed at 1024.
for prec in bf16 fp8ds; do
    for tp in 1 2 4 8; do
        sbatch -p b200-batch -N 1 -n 1 --gpus-per-node=b200:8 $OUT_FLAG \
            job_ddl.sh 7b $prec $tp 1 1024
    done
done

# TP=8 spanning 2 nodes (4 GPU/node, 8 GPUs total, DP=1): same TP degree and
# GBS as the intra-node TP=8 job above -- the only change is the fabric.
for prec in bf16 fp8ds; do
    sbatch -p b200-batch -N 2 -n 2 --gpus-per-node=b200:4 $OUT_FLAG \
        job_ddl.sh 7b $prec 8 1 1024
done

# TP=8 intra-node x DP=2 across nodes (2 x 8 = 16 GPUs, GBS=2048): the
# guidance-table recommended hybrid (TP inside the NVLink node, DP over IB).
# Compare at fixed 16 GPUs / GBS 2048 / 7b against pure DP=16 (phase 1,
# with2node=1) and PP=2 x DP=8 (phase 3) -> 4-way strategy comparison with
# the TP-spanning stress case above.
for prec in bf16 fp8ds; do
    sbatch -p b200-batch -N 2 -n 2 --gpus-per-node=b200:8 $OUT_FLAG \
        job_ddl.sh 7b $prec 8 1 2048
done

# 13b (12.8 B params): larger GEMM shapes should raise MFU and widen the FP8 win.
for tp in 2 4 8; do
    sbatch -p b200-batch -N 1 -n 1 --gpus-per-node=b200:8 $OUT_FLAG \
        job_ddl.sh 13b fp8ds $tp 1 1024
done
sbatch -p b200-batch -N 1 -n 1 --gpus-per-node=b200:8 $OUT_FLAG \
    job_ddl.sh 13b bf16 8 1 1024
