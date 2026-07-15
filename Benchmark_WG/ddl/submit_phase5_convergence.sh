#!/bin/bash
# Phase 5 -- Numerical parity: identical-seed loss curves, BF16 vs FP8 recipes.
# 1.3b model (cheap enough for 5000 iters), 1 node x 8, GBS=1024, seed fixed.
# ~2 s/iter -> ~3 h per job; submitted with -t 12:00:00 headroom.  -> 3 jobs
#
# PREREQUISITE: real data (mock data cannot show meaningful convergence).
#   1. Download + tokenize a corpus (e.g. a FineWeb/OpenWebText sample) with
#      Megatron-LM/tools/preprocess_data.py -> /path/to/data_text_document
#   2. Write ddl/data_args.sh defining data_par, e.g.:
#        data_par="--data-path /path/to/data_text_document \
#                  --tokenizer-type GPT2BPETokenizer \
#                  --vocab-file /path/to/gpt2-vocab.json \
#                  --merge-file /path/to/gpt2-merges.txt --split 949,50,1"
#   3. Submit with EXTRA_BIND pointing at the dataset directory (see below).
# run_ddl.sh sources data_args.sh automatically when it exists.
#
# Usage: bash submit_phase5_convergence.sh /path/to/dataset_dir [output_dir]

DATA_DIR=${1:?usage: submit_phase5_convergence.sh /path/to/dataset_dir [output_dir]}
OUTDIR=${2:-output}
mkdir -p "$OUTDIR"
OUT_FLAG="--output=$OUTDIR/out.%N-%J"

if [ ! -f data_args.sh ]; then
    echo "ERROR: ddl/data_args.sh not found -- create it first (see header)"; exit 1
fi

for prec in bf16 fp8ds mxfp8; do
    sbatch -p b200-batch -N 1 -n 1 --gpus-per-node=b200:8 -t 12:00:00 \
        --export=ALL,EXTRA_BIND=$DATA_DIR $OUT_FLAG \
        job_ddl.sh 1.3b $prec 1 1 1024 4 5000 1234
done
