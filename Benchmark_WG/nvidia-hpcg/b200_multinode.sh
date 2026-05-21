#!/bin/bash

GPU=b200
for n in 1 2 3 4 ; do
    sbatch \
        --partition=${GPU}-batch \
        --gpus=4 \
        --ntasks-per-node=4 \
        --nodes=${n}
        --cpus-per-task=16 \
        --time=01:00:00 \
        --mem=200GB \
        --gpu-bind=closest \
        --output=logs/hpcg_{$n}_node_4_gpu_${GPU}_%j.out \
        --error=logs/hpcg_{$n}_node_4_gpu_${GPU}_%j.err \
        --job-name=hpcg_${n}gpu ./aicr_hpcg.sh
done
