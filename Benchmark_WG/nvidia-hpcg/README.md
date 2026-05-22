# Nvidia HPCG Benchmark

Nvidia's [main page](https://docs.nvidia.com/nvidia-hpc-benchmarks/HPCG_benchmark.html) and 
[git](https://github.com/NVIDIA/nvidia-hpcg) repo. This is an MPI+CUDA benchmark.

## Problem Size

nx=ny=nz=256

This uses 14,964 MB of RAM per GPU. Increasing the size is in principle possible, provided 
the size is divisible by 16, but the program tends to throw out-of-memory errors. HPCG can
be compiled with 64-bit integer array indexing if the problem size is to be increased to 
fill the RAM on one of the GPUs. 

The runtime was set to a limit of 60 seconds.

## Compiling

The HPCG benchmark had to be compiled as the binary provided by Nvidia was not compatible
with the RTX Pro 6000. 

```bash
git clone https://github.com/NVIDIA/nvidia-hpcg.git
cd nvidia-hpcg
git checkout 26.02
# setup/Make.CUDA_X86 was adjusted to compile in support for 
# compute capability 10.0 (B200) and 12.0 (RTX). 
# A build_aicr.sh script was used to compile using the nvhpc/26.3 module.
./build_aicr.sh
# The xhpcg executable and a modified run scrip, hpcg.sh, are placed
# into the benchmark bin/ directory.
```

## UCX settings

As discussed on the aicr-benchmarking Slack channel, in order to correctly run on 8 GPUs some
environment variables for the UCX library (which is used by OpenMPI) needed to be set. This 
value is set for both types of GPU:

```bash
export UCX_TLS=rc_mlx5,cuda_copy,cuda_ipc,sm,self
```

For the B200 the `UCX_NET_DEVICES` variable is set to:

```bash
export UCX_NET_DEVICES=mlx5_0:1,mlx5_1:1,mlx5_2:1,mlx5_3:1,mlx5_4:1,mlx5_5:1,mlx5_6:1,mlx5_11:1,mlx5_12:1
```

For the RTX this is set to:

```bash
export UCX_NET_DEVICES=mlx5_0:1,mlx5_3:1
```

This worked correctly on the b200-devel and rtx-devel partitions with 1, 2, 4, or 8 GPUs. 

## Single node testing

Testing was done on single nodes with GPU counts of 1-8. While there were no execution
errors on the RTX nodes the 2 and 8 GPU runs on the B200s failed with a UCX library error.
The log files are in the `logs` directory.


| GPU  | num | Success? | Host  | Notes                                          |
|------|-----|----------|-------|------------------------------------------------|
| B200 | 1   |     Y    | b0016 | -                                              |
| B200 | 2   |     N    | b0016 | Transport retry count exceeded on mlx5_12:1/IB |
| B200 | 4   |     Y    | b0016 | -                                              |
| B200 | 8   |     N    | b0015 | Transport retry count exceeded on mlx5_5:1/IB  |
| RTX  | 1   |     Y    | a0004 | -                                              |
| RTX  | 2   |     Y    | a0004 | -                                              |
| RTX  | 4   |     Y    | a0004 | -                                              |
| RTX  | 8   |     Y    | a0004 | -                                              |


### RTX Performance

| GPUs | GFLOP/s | Efficiency vs. Linear |
|---|---|---|
| 1 | 287.985 | 100.0% |
| 2 | 573.885 | 99.6% |
| 4 | 1101.36 | 95.6% |
| 8 | 2193.38 | 95.3% |


### B200 Performance

TBD

The error files are in `logs/hpcg_1_node_2_gpu_b200_27007.err` and 
`logs/hpcg_1_node_8_gpu_b200_27009.err`. The errors are essentially the same in each:

```
[b0016:481792:0:481792] ib_mlx5_log.c:179  Transport retry count exceeded on mlx5_12:1/IB (synd 0x15 vend 0x81 hw_synd 0/0)
[b0016:481792:0:481792] ib_mlx5_log.c:179  RC QP 0xc82d wqe[0]: RDMA_READ s-- [rva 0x555e73f rkey 0x204c00] [va 0x470c5bf len 65 lkey 0x206a00] [rqpn 0xc45e dlid=206 sl=0 port=1 src_path_bits=0]
```
