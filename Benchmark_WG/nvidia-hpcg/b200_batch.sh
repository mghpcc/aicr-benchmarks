#!/bin/bash

GPU=b200
for n in 1 2 4 8; do
    sbatch \
        --partition=${GPU}-batch \
        --gpus=${n} \
        --ntasks-per-node=${n} \
        --cpus-per-task=16 \
        --time=01:00:00 \
        --mem=200GB \
        --gpu-bind=closest \
        --exclude b0001 \
        --output=logs/hpcg_1_node_${n}_gpu_${GPU}_%j.out \
        --error=logs/hpcg_1_node_${n}_gpu_${GPU}_%j.err \
        --job-name=hpcg_${n}gpu_${GPU} ./aicr_hpcg.sh
done
