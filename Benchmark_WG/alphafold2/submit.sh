#!/bin/bash


sbatch --time="12:00:00" --partition=rtx-batch --exclude=a0001 --gpus=1 --cpus-per-task=16 --tasks-per-node=1 bench.sh
sbatch --time="12:00:00" --partition=b200-batch --exclude=b0001,b0002 --gpus=1 --cpus-per-task=16 --tasks-per-node=1 bench.sh


