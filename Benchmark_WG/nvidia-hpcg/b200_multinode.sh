#!/bin/bash

# using 1 GPU per node across multiple nodes

GPU=b200
for n in 2 4 8 ; do
   sbatch \
        --partition=${GPU}-batch \
        --gpus=${n} \
        --ntasks-per-node=1 \
        --nodes=${n} \
        --cpus-per-task=16 \
        --time=01:00:00 \
        --mem=200GB \
        --gpu-bind=closest \
        --output=logs/hpcg_${n}_node_${n}_gpu_${GPU}_%j.out \
        --error=logs/hpcg_${n}_node_${n}_gpu_${GPU}_%j.err \
        --job-name=hpcg_${n}gpu_mn ./aicr_hpcg.sh
done
