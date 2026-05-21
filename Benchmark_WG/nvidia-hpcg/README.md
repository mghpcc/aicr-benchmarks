# Nvidia HPCG Benchmark

### Get the code

```sh
wget https://developer.download.nvidia.com/compute/nvidia-hpc-benchmarks/redist/nvidia_hpc_benchmarks_openmpi/linux-x86_64/nvidia_hpc_benchmarks_openmpi-linux-x86_64-26.02.02-archive.tar.xz
tar xf nvidia_hpc_benchmarks_openmpi-linux-x86_64-26.02.02-archive.tar.xz
```

## Problem Size

nx=ny=nz=256

The time limit is set to 300s. This uses 14,964 MB of RAM per GPU. Increasing the size is 
in principle possible, provided the size is divisible by 16, but the program tends to throw
out-of-memory errors.

## Single node

Testing was done on single nodes with GPU counts of 1-8.



## Multi-node
Selecting more than 4 GPUs per node caused errors in the UCX library, so this was performed
with 4 GPUs with 1-8 nodes. 




