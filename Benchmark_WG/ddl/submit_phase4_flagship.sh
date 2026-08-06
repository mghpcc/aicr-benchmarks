#!/bin/bash
# Phase 4 -- Flagship combined run: one experiment tying every measured ceiling
# to an end-to-end configuration (future-work.md):
#   13b model, TP=8 (intra-node NVLink) x PP=2 (inter-node GDRDMA wall)
#   x DP=2 (inter-node AllReduce, optionally SHARP), 4 nodes x 8 = 32 GPUs,
#   GBS = 128 x 32 = 4096.
# Jobs: bf16 / fp8ds / fp8ds+SHARP / bf16+SHARP                -> 4 jobs
#
# SHARP notes (Megatron-LM/notes-sharp.md): only the DP gradient AllReduce is
# offloaded; needs all 8 NICs/node engaged and buckets > ~4 MB crossover. With
# no_shard DP the gradient sync is a plain AllReduce, which is exactly the
# CollNet-accelerated collective.
#
# Layout note (added 2026-07-19, from phase 2/3 findings): TP=8 destroys
# throughput (13b TP8 = 637 TFLOP/s fp8 vs TP2 = 1331) and kills the FP8
# advantage, while PP is nearly free at large m. So the original TP8 x PP2 x
# DP2 quartet is kept as the "touch every ceiling" stress config, and a
# TP2 x PP2 x DP8 quartet is added as the throughput-optimal flagship
# ("minimum TP that fits"). DP=8 also gives SHARP a real workout (bigger DP
# group, ~13 GB gradient shards vs DP=2).
#
# Usage: bash submit_phase4_flagship.sh [output_dir]

OUTDIR=${1:-output}
mkdir -p "$OUTDIR"
OUT_FLAG="--output=$OUTDIR/out.%N-%J"

#                                                       MODEL PREC  TP PP GBS  MBS ITERS SEED SHARP
# stress config: TP=8 x PP=2 x DP=2 (original plan; slow -> 4 h limit)
sbatch -p b200-batch -t 4:00:00 -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b bf16  8 2 4096
sbatch -p b200-batch -t 4:00:00 -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b fp8ds 8 2 4096
sbatch -p b200-batch -t 4:00:00 -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b bf16  8 2 4096 4 100 1234 1
sbatch -p b200-batch -t 4:00:00 -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b fp8ds 8 2 4096 4 100 1234 1
# throughput-optimal flagship: TP=2 x PP=2 x DP=8 (minimum TP that fits)
sbatch -p b200-batch -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b bf16  2 2 4096
sbatch -p b200-batch -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b fp8ds 2 2 4096
sbatch -p b200-batch -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b bf16  2 2 4096 4 100 1234 1
sbatch -p b200-batch -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b fp8ds 2 2 4096 4 100 1234 1
