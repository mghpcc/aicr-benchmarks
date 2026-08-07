# Enabling SHARP on the AICR B200 nodes — what's needed on the user side

**System side is already done.** `sharp_hello` confirms all 9 NDR NICs are
SHARP-enabled, the switch aggregation manager / `sharpd` is running, and a forced
run does light up the `COLLNET/SHARP/.../GDRDMA` path. Nothing more is needed from
the fabric/sysadmin.

SHARP is purely **runtime configuration** — no rebuild (the working recipe reuses
the original `build-nvhpc-26.3`). The catch is that the *job script* must be set up
correctly, and **NCCL will not pick SHARP on its own**.

The working recipe lives in `2nodes-8gpus-sharp.sh`. The user-side requirements:

## 1. Load the SHARP + plugin libraries onto `LD_LIBRARY_PATH`
- Set `SHARP_HOME` (`.../hpcx/sharp`) and `NCCL_PLUGIN_HOME`
  (`.../nccl_rdma_sharp_plugin`).
- The plugin provides `libnccl-net.so` (the IBext net plugin). Without it, NCCL
  prints `NET/Plugin: Could not find: libnccl-net.so` and silently falls back to
  its built-in NET/IB transport, which has **no** CollNet/SHARP support.
- **Do not** set `NCCL_NET=IB` — that disables the plugin.

## 2. Enable CollNet/SHARP
- `NCCL_COLLNET_ENABLE=1`
- `SHARP_COLL_LOCK_ON_COMM_INIT=1`

## 3. Force the algorithm — the non-obvious part
- NCCL's static bandwidth model rates CollNetChain (~69 GB/s) far below Ring
  (~204 GB/s), so the tuner **always picks Ring** even when SHARP would win. For
  AllReduce you must force `NCCL_ALGO=CollNetChain,CollNetDirect` with Ring excluded.
- `NCCL_PROTO=Simple` (SHARP requires Simple; LL/LL128 are not CollNet-compatible).
- Use camelCase tokens (`CollNetChain`, not `COLLNET_CHAIN`, which is rejected).

## 4. Pin to the SHARP-enabled NDR NICs only
- `NCCL_IB_HCA="^mlx5_7,mlx5_8,mlx5_9,mlx5_10"` — exact-match **exclusion** of the
  four management NICs.
- Don't use an inclusion list: prefix matching makes `mlx5_1` also match
  `mlx5_10/11/12`, which silently admits a non-SHARP mgmt NIC and makes `sharpd`
  fail with "Unknown port" → CollNet init aborts.

## 5. Preload libnuma
- `LD_PRELOAD=/lib64/libnuma.so.1` — the plugin dlopens the unversioned
  `libnuma.so`, which the system doesn't ship.

## 6. Forward every var to all ranks (Open MPI)
- Use the explicit `-x VAR=$VAR` form, not `-x VAR`. This HPC-X `mpirun` build
  silently drops some otherwise (`NCCL_IB_HCA` was lost this way, and NCCL then saw
  all 13 NICs).

## Verify it actually engaged
- Grep the run log for `COLLNET/SHARP/.../GDRDMA`, or check the AllReduce algorithm
  decision under `NCCL_DEBUG=INFO` / `NCCL_DEBUG_SUBSYS=NET,COLL,TUNING`.

## What SHARP is — hardware background

SHARP lives entirely in the **IB switch**; nothing on the GPU or PCIe side is
involved.

**Where it lives:** NVIDIA Quantum-2 NDR switches have dedicated **aggregation
engines** built into the switch ASIC itself. When SHARP is active, the switch
intercepts data flowing through it, performs the arithmetic (sum, min, max, etc.),
and forwards the result. The GPUs just send and receive — they never see intermediate
partial sums from other nodes.

**Is there a chip in the switch?** Not a separate chip — the aggregation engines are
integrated into the **Quantum-2 switch ASIC die** alongside the routing logic. Same
package, same die. NVIDIA calls this "in-network computing" because the compute
capability is fused into the fabric itself.

**Is it similar to a DPU?** Conceptually related but architecturally different:

| | SHARP (Quantum switch) | DPU (e.g. BlueField) |
|---|---|---|
| Where | Inside the IB switch | On the NIC/HCA card |
| Purpose | Collective reduction offload (AllReduce, barrier) | General-purpose offload (networking, storage, security) |
| Processor | Fixed-function aggregation engines (not general CPU) | Full ARM CPU cores + programmable pipeline |
| Programmability | Not user-programmable; operations fixed (sum/min/max over standard dtypes) | Fully programmable |
| Sits on | The network fabric path | The host PCIe bus |

A DPU is a programmable compute offload card on the PCIe bus next to the host.
SHARP is a fixed-function arithmetic accelerator baked into the switch ASIC that
operates transparently on traffic passing through the fabric — no host CPU or GPU
involvement once the collective is initiated. The GPU's only role is to DMA data out
over GDRDMA to the NIC, which passes it into the IB fabric where the switch does the
work. PCIe is just the on-ramp; once traffic is in the IB network, SHARP takes over.

---

## Caveat on the ~340 GB/s figure
In the captured runs SHARP only engaged when AllReduce was **forced** to CollNet.
The ~340 GB/s (≈ 2× the 170 GB/s Ring result) is the expected target, but a cleanly
parsed busbw number confirming it was hit has not been extracted from the verbose
logs (`out-2node/nvhpc-26.3-sharp-b0014-16209`).
