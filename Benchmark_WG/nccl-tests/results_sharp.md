# SHARP results — 2-node B200 AllReduce

**SHARP (in-network reduction on the IB switch) makes 2-node AllReduce 2.2× faster at
8 GPU/node.** Use it for data/tensor-parallel training at scale.

## What is SHARP?

**SHARP** = Scalable Hierarchical Aggregation and Reduction Protocol — an NVIDIA/Mellanox
InfiniBand feature that performs the **arithmetic of a collective (the `sum` in an AllReduce)
inside the NDR/Quantum-2 switch ASIC itself**, instead of on the GPUs. The switch is not just
forwarding packets; it adds the contributions from all GPUs as they pass through.

**Without SHARP (Ring/Tree AllReduce):** the GPUs do all the math, and partial results are
shuffled GPU→GPU across the fabric in **two passes** — reduce-scatter, then all-gather. Every
byte crosses each GPU's NIC roughly twice, and each GPU's PCIe DMA engine must send *and*
receive at the same time. That bidirectional contention is what caps a B200 NIC at ~26.7 GB/s/dir
(~214 GB/s aggregate per node) — well below its 50 GB/s unidirectional line rate.

**With SHARP (single pass):** each GPU sends its local data **up to the switch once**; the
switch reduces (sums) all 16 GPUs' contributions in-network and sends the **single reduced
result back down once**. The GPUs never exchange partials with each other.

**Why this raises GB/s:**
1. **Half the wire/PCIe traffic.** Single up-and-down instead of the two-pass ring, so each NIC
   moves far less data and isn't fighting itself bidirectionally — it runs closer to its
   unidirectional line rate, **bypassing the ~214 GB/s GDRDMA bidirectional ceiling**.
2. **busbw credits the offloaded work.** `busbw` measures the *logical* AllReduce throughput.
   The switch performs reduction the GPUs would otherwise have done across the fabric, so for
   the same physical wire speed the reported busbw roughly doubles (162.7 → 357.2 GB/s).
3. **Less work scales better.** The win grows with message size (negligible below ~4 MB, 2.2×
   at multi-GB) because the per-byte savings dominate once setup latency is amortized.

## 8 GPU/node × 2 nodes (16 GPUs) — 2.2× faster

Clean A/B, `all_reduce_perf` busbw (GB/s), out-of-place (job 36311, nodes b0020+b0024).

| Message size | Ring (no SHARP) | SHARP | Speedup |
|---|---|---|---|
| 256 MB  | 113.1 | 197.9 | 1.75× |
| 1 GB    | 116.5 | 258.4 | 2.22× |
| 4 GB    | 160.7 | 344.1 | 2.14× |
| **16 GB** | **162.7** | **357.2** | **2.20×** |
| **Avg (1MB–16GB)** | **81.1** | **160.6** | **1.98×** |

- Validation clean (0 wrong values).
- Peak **357 GB/s exceeds the ~214 GB/s GDRDMA bidirectional ceiling**: plain Ring is capped
  there by its two-pass (reduce-scatter + all-gather) PCIe load; SHARP reduces in the switch
  (single pass) and bypasses it. The win grows with message size (crossover ~4 MB).

## How to enable (8 GPU/node)

See `2nodes-8gpus-sharp-ab.sh`. Each flag and why it's needed:

- **`NCCL_COLLNET_ENABLE=1`** — master switch for NCCL's CollNet transport, the mechanism
  that offloads reduction to the network. Without it NCCL never tries the in-switch (SHARP)
  path at all.
- **`SHARP_COLL_LOCK_ON_COMM_INIT=1`** — makes the SHARP library reserve its switch resources
  (the reduction tree/job) at communicator-init time instead of lazily on first use. Avoids
  init races/failures when all ranks start together.
- **`NCCL_ALGO=CollNetChain,CollNetDirect`** — restricts the AllReduce algorithm to the two
  CollNet (SHARP) variants. This is the "force SHARP" part: NCCL's cost model rates CollNet
  (~69 GB/s) far below Ring (~204), so left alone the tuner always picks Ring and SHARP never
  runs. Chain and Direct are two CollNet topologies; listing both lets NCCL pick whichever fits.
- **`NCCL_PROTO=Simple`** — restricts the wire protocol to `Simple`. CollNet/SHARP only works
  with Simple; the low-latency `LL`/`LL128` protocols are incompatible with in-network
  reduction. Without this the forced CollNet algo has no valid protocol and the run aborts.
- **`NCCL_IB_HCA="^mlx5_7,mlx5_8,mlx5_9,mlx5_10,mlx5_12"`** — selects which IB NICs NCCL uses;
  the leading `^` means *exclude* the listed devices. Drops the 4 management NICs
  (mlx5_7–10) and the one NDR NIC whose port is not on the SHARP tree (mlx5_12), leaving the 8
  SHARP-connected NICs (mlx5_0–6 + mlx5_11), one per GPU. Without excluding mlx5_12, GPU 7
  lands on it and SHARP job creation fails → AllReduce crashes.
- **`LD_PRELOAD=/lib64/libnuma.so.1`** — force-loads the NUMA library. The SHARP library
  `dlopen`s an unversioned `libnuma.so` that isn't installed (only `libnuma.so.1` exists);
  preloading it lets SHARP do proper socket/NUMA grouping instead of a manual fallback.
- **`--bind-to none`** (an `mpirun` flag, not an env var) — disables Open MPI's CPU-core
  binding. On a shared (non-`--exclusive`) node Slurm hands the job a restricted CPU set and
  OMPI's default binding tries to bind outside it → launch failure. `none` lets Slurm/cgroups
  handle affinity. Omit on `--exclusive` jobs.

SHARP accelerates AllReduce / Reduce / ReduceScatter / AllGather / Broadcast only.

## Using SHARP in Megatron-LM and PyTorch

**No code changes are needed.** Megatron-LM, PyTorch DDP, and FSDP all use the NCCL backend
under the hood, so SHARP is enabled purely by setting NCCL/SHARP environment variables before
launching `torchrun`/`srun`. The same variables from "How to enable" apply.

**What actually benefits (8 GPU/node × 2 nodes, inter-node):**
- **Data-parallel gradient sync** — the cross-node `AllReduce` (DDP) or `ReduceScatter`+`AllGather`
  (Megatron distributed optimizer / FSDP). This is the main win.
- **Tensor parallel**: usually kept *inside* a node (NVLink), so SHARP (inter-node) does not apply.
- **Pipeline parallel**: point-to-point `send/recv` — SHARP cannot accelerate it.

So SHARP helps most when your **data-parallel dimension spans nodes** (large global batch, DDP/FSDP).

**Recommended NCCL_ALGO scoping (production-safe):** force SHARP for `allreduce` only and leave
other collectives on their defaults, so small-message latency and TP/PP collectives are
unaffected:
```
NCCL_ALGO="allreduce:collnetchain,collnetdirect"      # scope to allreduce; do NOT set NCCL_PROTO globally
```
NCCL automatically uses the `Simple` protocol for the CollNet allreduce while keeping `LL128`
for everything else. (The benchmark used the blunt global form `NCCL_ALGO=CollNetChain,CollNetDirect`
+ `NCCL_PROTO=Simple`, which forces *every* collective onto CollNet/Simple — fine for an
AllReduce-only microbenchmark, but it slows other collectives in a real model.)
If your optimizer is sharded (distributed optimizer / FSDP), also scope reduce-scatter and
all-gather: `NCCL_ALGO="allreduce:collnetchain,collnetdirect;reducescatter:collnetdirect;allgather:collnetdirect"`.

### Sample SLURM job script (Megatron-LM; PyTorch DDP/FSDP identical env)

```bash
#!/bin/bash
#SBATCH -p b200-batch
#SBATCH -N 2                       # 2 nodes
#SBATCH --ntasks-per-node=8        # 1 task per GPU
#SBATCH --gpus-per-node=8
#SBATCH --gpu-bind=closest
#SBATCH --mem=0                    # all node memory
#SBATCH -t 240
#SBATCH -o train-%x-%j.out

# ---- toolchain (SHARP plugin + libs) ----
module load nvhpc/26.3
export NVHPC_HOME=/apps/aicr/packages/nvhpc/26.3/7jhdyji/Linux_x86_64/26.3
export CUDA_HOME="$NVHPC_HOME/cuda"
export NCCL_HOME="$NVHPC_HOME/comm_libs/nccl"
export SHARP_HOME="$NVHPC_HOME/comm_libs/13.1/hpcx/hpcx-2.25.1/sharp"
export NCCL_PLUGIN_HOME="$NVHPC_HOME/comm_libs/13.1/hpcx/hpcx-2.25.1/nccl_rdma_sharp_plugin"
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$NCCL_HOME/lib:$NCCL_PLUGIN_HOME/lib:$SHARP_HOME/lib:$LD_LIBRARY_PATH
export LD_PRELOAD=/lib64/libnuma.so.1${LD_PRELOAD:+:$LD_PRELOAD}   # SHARP dlopens unversioned libnuma

# ---- SHARP / NCCL settings ----
export NCCL_COLLNET_ENABLE=1                                   # enable in-switch reduction (SHARP)
export SHARP_COLL_LOCK_ON_COMM_INIT=1                          # reserve SHARP tree at init
export NCCL_IB_HCA="^mlx5_7,mlx5_8,mlx5_9,mlx5_10,mlx5_12"     # 8 SHARP-good NICs (exclude mgmt + off-tree mlx5_12)
export NCCL_ALGO="allreduce:collnetchain,collnetdirect"       # force SHARP for AllReduce only
# Distributed optimizer / FSDP? use instead:
# export NCCL_ALGO="allreduce:collnetchain,collnetdirect;reducescatter:collnetdirect;allgather:collnetdirect"
export NCCL_IB_PCI_RELAXED_ORDERING=1                          # better GDR DMA throughput
# Verify once, then comment out (verbose):
export NCCL_DEBUG=INFO
export NCCL_DEBUG_SUBSYS=INIT,NET                              # look for "via COLLNET/SHARP"

# ---- rendezvous ----
export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n1)
export MASTER_PORT=29500
export WORLD_SIZE=$((SLURM_NNODES * SLURM_NTASKS_PER_NODE))    # 16

# ---- launch (Megatron pretrain; srun spawns one rank per GPU) ----
srun python pretrain_gpt.py \
  --tensor-model-parallel-size 8 \      # TP within a node (NVLink); SHARP not used here
  --pipeline-model-parallel-size 1 \
  --use-distributed-optimizer \         # cross-node RS+AG → benefits from SHARP (see NCCL_ALGO note)
  --distributed-backend nccl \
  ...                                   # model / data / tokenizer args
```

**PyTorch DDP / FSDP:** identical env block; replace the launch with `torchrun`:
```bash
srun torchrun --nnodes $SLURM_NNODES --nproc-per-node 8 \
  --rdzv-backend c10d --rdzv-endpoint "$MASTER_ADDR:$MASTER_PORT" train.py ...
```
DDP gradient AllReduce uses SHARP automatically; FSDP's ReduceScatter/AllGather need the
extended `NCCL_ALGO` scope above. No `dist.*` code changes required — `backend="nccl"` is enough.

**Verify it's working:** with `NCCL_DEBUG=INFO`, the log must show channels `via COLLNET/SHARP/...`
and *no* `Cannot create SHARP job` warnings. If you see the latter on one rank, a NIC is off the
SHARP tree — recheck `NCCL_IB_HCA`. SHARP only pays off for large messages (≥ ~4 MB), so the gain
appears on big gradient buckets; keep DDP `bucket_cap_mb` reasonably large (e.g. ≥ 100).

## 2 GPU/node × 2 nodes — not worth it

At low NIC count SHARP gives no benefit: AllReduce peaks at **75 GB/s vs 82 GB/s for Ring
(−9%)** at large sizes (job 36306). With only 2 NICs/node the aggregate isn't bottlenecked,
so Ring is already optimal. Use the default at 2–4 GPU/node; enable SHARP at 8 GPU/node.

_Data: jobs 36306 (2 GPU A/B), 36311 (8 GPU A/B), 2026-06-05, partition b200-batch.
Scripts: `2nodes-2gpus-sharp-ab.sh`, `2nodes-8gpus-sharp-ab.sh`._
