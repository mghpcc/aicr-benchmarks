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
# Usage: bash submit_phase4_flagship.sh [output_dir]

OUTDIR=${1:-output}
mkdir -p "$OUTDIR"
OUT_FLAG="--output=$OUTDIR/out.%N-%J"

#                                                       MODEL PREC  TP PP GBS  MBS ITERS SEED SHARP
sbatch -p b200-batch -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b bf16  8 2 4096
sbatch -p b200-batch -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b fp8ds 8 2 4096
sbatch -p b200-batch -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b bf16  8 2 4096 4 100 1234 1
sbatch -p b200-batch -N 4 -n 4 --gpus-per-node=b200:8 $OUT_FLAG job_ddl.sh 13b fp8ds 8 2 4096 4 100 1234 1
