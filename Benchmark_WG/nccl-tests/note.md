# NCCL ncclMemAlloc crash on RTX6000 (a-nodes) — 2026-05-22

## Q1: The same job ran successfully before, just slowly. Is there something changed in the system?

Yes — the GPU driver was rebuilt to **580.105.08** with build date **2026-05-10**
(per `/proc/driver/nvidia/version` on a0018). The previous successful run was
2026-05-05; the failing run was 2026-05-22, so the upgrade falls in the gap.

What broke:
- Driver 580 advertises multicast / fabric-memory capability the prior driver did not.
- NCCL 2.29.3's `ncclMemAlloc` now takes the fabric path and calls
  `cuMemCreate(..., CU_MEM_HANDLE_TYPE_FABRIC)`.
- That call requires the IMEX daemon to broker fabric handles, but
  `nvidia-imex.service` is **not installed** on the a-nodes and there are
  **no `/dev/nvidia-caps/imex-channel*` devices**.
- The create fails and surfaces in nccl-tests as
  `unhandled cuda error` at `common.cu:915` (the `ncclMemAlloc` line).

Why the May 5 run worked: the older driver didn't expose the fabric capability,
so NCCL took the plain `cudaMalloc` fallback. The job ran (very slowly, as
expected for cross-NUMA RTX6000) until the wall-clock timeout.

Two ways to deal with it:
1. **Workaround (user-side):** `export NCCL_NVLS_ENABLE=0` in the job script.
   NCCL skips multicast init and `ncclMemAlloc` falls back to plain allocation.
   Applied to `2socket.sh`.
2. **Real fix (sysadmin-side):** install and start `nvidia-imex.service` on the
   compute nodes (shipped with the 580 driver).

## Q2: Does this affect only the PCIe RTX nodes, or B200 NVLink nodes too?

The same underlying condition exists on both: B200 nodes (checked b0029) also run
driver **580.105.08, same May 10 build, and `nvidia-imex.service` is not
installed**. But the right action differs.

|                                   | RTX6000 (a-nodes)                | B200 (b-nodes)                                                 |
| --------------------------------- | -------------------------------- | -------------------------------------------------------------- |
| NVLS hardware?                    | No NVLink — NVLS is useless      | NVSwitch present — NVLS is a real perf feature (in-network AR) |
| Cost of `NCCL_NVLS_ENABLE=0`      | Free                             | Hurts perf (loses NVLS AllReduce gain, similar to losing SHARP)|
| Confirmed crash at `ncclMemAlloc`?| Yes (out-2socket/...-a0001-27157)| Unknown — no B200 run since May 10 to test                     |

Why B200 might *not* crash even without IMEX: single-node NVSwitch multicast can
be set up with a local handle (no cross-node fabric needed). IMEX is mandatory
for multi-node NVLink (MNNVL/NVL72), not necessarily for single-node NVSwitch
multicast. Note `/dev/nvidia-caps` on b0029 already has `nvidia-cap1`/`cap2`
(multicast capability nodes), which a-nodes don't have a use for.

Recommendation:
- Do **not** preemptively add `NCCL_NVLS_ENABLE=0` to B200 scripts. Submit the
  existing 1-node and 2-node B200 jobs first; if they pass, keep NVLS on.
- If a B200 job crashes the same way at `common.cu:915`, add
  `NCCL_NVLS_ENABLE=0` as a workaround, and flag IMEX install to sysadmin as
  the real fix — especially before any 2-node AllReduce work, where you'd
  otherwise lose the NVLS speedup.
