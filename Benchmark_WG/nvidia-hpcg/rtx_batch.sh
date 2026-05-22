#!/bin/bash

# RTX Pro 6000 
GPU=rtx
for n in 1 2 4 8 ; do
    sbatch \
        --partition=${GPU}-batch \
        --gpus=${n} \
        --ntasks-per-node=${n} \
        --cpus-per-task=16 \
        --time=01:00:00 \
        --mem=200GB \
	--exclude=a0001 \
        --gpu-bind=closest \
        --output=logs/hpcg_1_node_${n}_gpu_${GPU}_%j.out \
        --error=logs/hpcg_1_node_${n}_gpu_${GPU}_%j.err \
        --job-name=hpcg_${n}_gpu_${GPU}  ./aicr_hpcg.sh
done
