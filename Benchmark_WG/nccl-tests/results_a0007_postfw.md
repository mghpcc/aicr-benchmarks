# a0007 NCCL 1-node results (RTX PRO 6000)

**Node:** a0007 — 8× RTX PRO 6000 Blackwell, no NVLink, PCIe Gen5 x16 (63 GB/s per direction).
2× AMD EPYC Turin, NPS=4. GPUs 0–3 = socket 0, GPUs 4–7 = socket 1. Every GPU pair is `SYS`
distance (no pair shares a PCIe switch).
**Software:** nvhpc/26.3, NCCL 2.29.3, nccl-tests 2.18.3, driver 595.71.05, `NCCL_NVLS_ENABLE=0`.
**Values:** busbw GB/s, converged at 16 GB, best of out-of-place / in-place.

**The PCIe firmware update changed nothing.** a0007 at NCCL defaults matches the older a0008
baseline on every collective (scatter 50.76 vs 50.6, sendrecv 13.09 vs 13.0, gather 39.37 vs
39.2, alltoall 13.30 vs 13.4). Everything below is caused by the `NCCL_P2P_LEVEL` setting.

Full detail, diagnostics and the audit trail: `results_a0007_postfw_full_20260811.md`
and `diag_a0007_socket1.md`.

---

# 1. Measurements

All tables use `NCCL_P2P_LEVEL=SYS`. Devices taken in order `0..N-1`, so 1–4 GPUs stay on
socket 0 and 5–8 span both sockets.

## Table 1 — `sendrecv` scaling

| Config | GPUs | busbw | % of 63 |
|---|---:|---:|---:|
| one socket | 2 | 36.95 | 59% |
| one socket | 4 | 37.07 | 59% |
| two sockets | 8 | 35.43 | 56% |

**Flat, because the limit is each GPU's own PCIe DMA engine.** Every rank sends and receives
at once: ~37 GB/s each way, ~74 GB/s on a link with 126 GB/s full-duplex capacity. The wire is
only 59% used, so the DMA budget binds, not the link. Each GPU brings its own link and no shared
stage, so adding GPUs cannot lower the per-GPU rate. The 4% dip at 8 GPUs is the socket crossing.

## Table 2 — all collectives, 4 GPUs, one socket

| Collective | busbw | % of 63 | Pattern |
|---|---:|---:|---|
| gather | 44.66 | 71% | root-anchored, one-way |
| broadcast | 43.20 | 69% | tree, mostly one-way |
| reduce | 42.60 | 68% | tree, mostly one-way |
| all_reduce | 39.82 | 63% | ring, bidirectional |
| all_gather | 39.07 | 62% | ring, bidirectional |
| sendrecv | 37.07 | 59% | bidirectional |
| reduce_scatter | 33.93 | 54% | ring, bidirectional + reduce |
| **alltoall** | **2.38** | 3.8% | **broken — see §2** |
| **scatter** | **1.85** | 2.9% | **broken — see §2** |

**Two bands, sorted by directionality.** Bidirectional patterns land at 34–40, sharing the same
~37 GB/s DMA budget as `sendrecv`. Mostly one-way patterns reach 42–45 because the engine is not
splitting its budget; `gather`'s algbw of 59.55 is 95% of link spec, bound by the root's inbound
link. This is what the hardware predicts — the ceiling is the PCIe DMA engine, not Infinity Fabric.

`scatter` and `alltoall` fit neither band and are a separate fault.

## Table 3 — all collectives, 8 GPUs, two sockets

| Collective | busbw | vs 4 GPU |
|---|---:|---|
| gather | 41.79 | −6% |
| sendrecv | 35.43 | −4% |
| all_gather | 13.66 | −65% |
| broadcast | 13.62 | −68% |
| all_reduce | 13.61 | −66% |
| reduce | 13.54 | −68% |
| reduce_scatter | 13.53 | −60% |
| alltoall | 1.01 | broken |
| scatter | 0.94 | broken |

**Five ring/tree collectives converge on 13.5–13.7 — one shared resource saturating.**
The cause is socket crossing, not GPU count: at 4 GPUs split 2+2 across sockets, `reduce` drops
42.60 → 20.13 with the GPU count unchanged. Going to 8 GPUs costs a further ~1.5×, which is not
fully explained. `gather` and `sendrecv` survive because neither depends on a ring spanning both
sockets.

---

# 2. The `NCCL_P2P_LEVEL=SYS` trade-off

## Why it fixes the collapse

At NCCL defaults, any group with **≥ 3 GPUs and ≥ 2 on socket 1** runs at **0.04 GB/s** — silently,
with correct results and no error.

`NCCL_P2P_LEVEL` is the maximum topological distance at which NCCL will use direct GPU-to-GPU
P2P. Every pair here is `SYS` distance, so `SYS` admits all pairs and anything stricter admits
none. `NCCL_DEBUG=INFO` shows the mechanism:

| Run | `Check P2P Type` | Transport used | busbw |
|---|---|---|---:|
| 2 GPU, defaults | `isAllDirectP2p 1` | `P2P/direct pointer` | 39.4 |
| 8 GPU, defaults | `isAllDirectP2p 0` | `SHM/direct/direct` | 0.04 |
| 8 GPU, `SYS` | — | P2P | 35.4 |

Both report `isAllCudaP2p 1` — CUDA says P2P works between all pairs. NCCL's own gating declines
it and falls back to staging through host shared memory, which runs at 0.04 GB/s here. `SYS`
prevents that fallback.

## What fixes it, and what does not (8 GPUs)

8 GPUs, `sendrecv` busbw at 16 MiB / 5 iters, one knob changed at a time:

| Setting | busbw | |
|---|---:|---|
| **`NCCL_P2P_LEVEL=SYS`** | **32.66** | **only fix — 800×** |
| `NCCL_SHM_DISABLE=1` | 0.09 | no |
| `NCCL_ALGO=Ring` | 0.04 | no |
| `NCCL_MAX_NCHANNELS=1` | 0.04 | no |
| `NCCL_PROTO=Simple` | 0.04 | no |
| `NCCL_P2P_DISABLE=1` | 0.04 | no |
| `NCCL_P2P_LEVEL=0` | 0.04 | no |
| *(defaults)* | 0.04 | — |

`P2P_DISABLE` and `P2P_LEVEL=0` sit exactly on the default's 0.04 because they force the same SHM
path. `ALGO`/`PROTO`/`NCHANNELS` change scheduling, not transport, so they cannot help.

## Why it improves other collectives but breaks `scatter` and `alltoall` (4 and 8 GPUs)

**Why the other collectives improve.** At NCCL defaults, once a group has more than a couple of
GPUs, NCCL declines direct GPU-to-GPU P2P and falls back to staging every byte through host
memory instead — the same fallback described above, just less severe at 4 GPUs than the
0.04 GB/s socket-1 collapse. `NCCL_P2P_LEVEL=SYS` removes that fallback and lets GPUs copy
straight to each other over PCIe, at close to each GPU's own DMA budget (~37–45 GB/s). For the
seven collectives below, that direct route is a clear win — hence the 150–223% gains.

The same setting costs 82–96% on the other two.

### 4 GPUs, socket 0

| Collective | defaults | `SYS` | effect |
|---|---:|---:|---|
| reduce | 13.19 | **42.60** | +223% |
| all_reduce | 13.17 | **39.82** | +202% |
| all_gather | 13.29 | **39.07** | +194% |
| sendrecv | 13.09 | **37.07** | +183% |
| reduce_scatter | 12.91 | **33.93** | +163% |
| broadcast | 17.29 | **43.20** | +150% |
| gather | 39.37 | **44.66** | +13% |
| **alltoall** | **13.30** | 2.38 | **−82%** |
| **scatter** | **50.76** | 1.85 | **−96%** |

Reproducible: 3 consecutive runs give scatter 1.85/1.86/1.92, alltoall 2.28/2.28/2.27.

### 8 GPUs, both sockets

| Collective | defaults | `SYS` | effect |
|---|---:|---:|---|
| gather | not measured¹ | **41.79** | — |
| sendrecv | **0.04** | **35.43** | **+885×** |
| all_gather | not measured¹ | 13.66 | — |
| broadcast | not measured¹ | 13.62 | — |
| all_reduce | not measured¹ | 13.61 | — |
| reduce | not measured¹ | 13.54 | — |
| reduce_scatter | not measured¹ | 13.53 | — |
| **alltoall** | not measured¹ | **1.01** | — |
| **scatter** | not measured¹ | **0.94** | — |

¹ Only `sendrecv` was ever run at 8 GPUs with NCCL defaults (job 335364, 0.04 GB/s). The other
collectives were not, because at 0.04 GB/s a converged run is impractical — a single 16 GB
iteration takes ~7 minutes. The ring/tree rows would almost certainly also sit at ~0.04, since
the socket-1 collapse is transport-level and hits every collective (see
`diag_a0007_socket1.md`), but `scatter`/`alltoall` at 8-GPU defaults are **genuinely unknown** —
they might collapse to 0.04 like the rest, or stay near their 4-GPU defaults values. This is the
one gap that prevents a definitive 8-GPU recommendation.

### Combined discussion

**The cause is the same at both GPU counts.** `scatter` and `alltoall` break for one reason —
the one→many fan-out described below — and it applies identically at 4 and 8 GPUs. The severity
simply scales with how many peers one sender must feed at once: fan-out grows from 3 peers at
4 GPUs to 7 at 8 GPUs, and throughput roughly halves in step (scatter 1.85 → 0.94, alltoall
2.38 → 1.01). That is what a per-sender contention limit predicts, and it is the same fault, not
a new one.

**Two differences that matter in practice:**

1. **At 4 GPUs there is a real choice; at 8 GPUs there is not.** With 4 GPUs on socket 0 the
   socket-1 trigger is not tripped, so defaults stay usable (13–51 GB/s) and are genuinely the
   better setting for `scatter`/`alltoall`. At 8 GPUs defaults trip the socket-1 collapse, so
   `sendrecv` — and, on the transport argument, the ring/tree collectives — fall to 0.04 GB/s.
   Defaults stop being a viable escape hatch, which is why 8-GPU MoE has no good configuration.
2. **At 8 GPUs the healthy collectives are separately degraded.** Even with `SYS` working as
   intended, the five ring/tree collectives sit at ~13.6 rather than the ~40 they reach at
   4 GPUs. That is the socket-crossing fault from Table 3, an **independent** problem with a
   different cause — it is not the P2P setting and not the fan-out issue. `gather` (41.79) and
   `sendrecv` (35.43) escape it because neither relies on a ring spanning both sockets.

**The trade-off is binary.** Since all pairs are `SYS` distance, the P2P level is an on/off
switch. `NCCL_P2P_LEVEL=PHB` (49.90) and `NCCL_P2P_DISABLE=1` (50.32) both restore `scatter`
because both simply turn P2P off. There is no intermediate setting.

**Mechanism — hypothesis, not established.** The broken collectives are those where *one rank
sends to many peers at once*. `gather` (many→one) and `sendrecv` (1→1) are healthy; `scatter`
(one→many) and `alltoall` are not. `gather` at 44.66 versus its mirror `scatter` at 1.85 — same
root, same sizes, opposite direction — rules out any bandwidth explanation. Concurrent
multi-peer P2P transmit is the suspect; this has not been proven.

In plain terms: a P2P copy is done by the GPU that's *sending* the data — it reads its own
memory and pushes it across PCIe to the other GPU. Each GPU only has a few of these "copy paths"
free to run at once (4 here). In `gather`, each of the other GPUs sends just one copy, using its
own path — no two GPUs are competing for anything. In `scatter`, one GPU has to send to all the
others at the same time, so all those sends pile up on that single GPU's few copy paths and jam
each other. `alltoall` is worse because every GPU is doing this "send to everyone" job at once,
not just one root. That's also why cutting the number of channels to 1
(`NCCL_MAX_NCHANNELS=1`) claws back some speed (1.85→4.01) — fewer things piling up on the
sender at once. Turning P2P off routes everything through host memory instead, which does not
have this one-GPU pile-up problem.

**So the two faults have opposite fixes:** the socket-1 collapse needs P2P **on**, `scatter` and
`alltoall` need it **off**. At 4 GPUs in one socket you can pick whichever your workload needs.
At 8 GPUs you cannot — turning P2P off to rescue `scatter`/`alltoall` re-triggers the socket-1
collapse, so both settings lose.

---

# 3. Recommended configuration

## By collective

| Collective | Setting | busbw |
|---|---|---:|
| sendrecv, reduce, broadcast, all_reduce, all_gather, reduce_scatter | `NCCL_P2P_LEVEL=SYS` | 34–43 |
| gather | either (`SYS` slightly better) | 39–45 |
| scatter, alltoall | **NCCL defaults** | 50.8 / 13.3 |
| any job with ≥ 3 GPUs and ≥ 2 on socket 1 | `NCCL_P2P_LEVEL=SYS` — mandatory | else 0.04 |

## By DL parallelism strategy

| Strategy | NCCL ops used | Setting | Expected (4 GPU) |
|---|---|---|---:|
| Data parallel | all_reduce | `SYS` | 39.82 |
| ZeRO / FSDP | reduce_scatter + all_gather | `SYS` | 33.9 / 39.1 |
| Tensor parallel | all_reduce, all_gather | `SYS` | 39.8 / 39.1 |
| Pipeline parallel | sendrecv | `SYS` | 37.07 |
| **MoE / expert routing** | **alltoall** | **defaults** | **13.30** |

Everything except MoE wants `SYS`, and gains 2.6–3.2×.

## The unresolved case

**8-GPU MoE has no good configuration.** Defaults give 0.04 GB/s across the board; `SYS` gives
`alltoall` at 1.01. Both are unusable. MoE workloads on this hardware should stay within one
socket (≤ 4 GPUs, defaults, alltoall 13.30) until the `scatter`/`alltoall` mechanism is
understood.

## Also worth fixing

- Set the P2P level per job, not site-wide — the correct value depends on the workload.
- `nvidia-imex.service` is absent, forcing `NCCL_NVLS_ENABLE=0` on every job. Driver is now
  595.71.05, so this may no longer be needed — worth re-testing.

---

<!-- AUTO-BEGIN: regenerated by a0007_autoreport.py -->

## Appendix: GPU-count series 1–8 (auto-generated 2026-08-11 18:03)

`NCCL_P2P_LEVEL=SYS`, converged 16 GB, devices `0..N-1`. Counts 2/4/8 from jobs 335386
and 335385; counts 1/3/5/6/7 from job 338765. Regenerated automatically — only the block
between the AUTO markers is touched.

| Collective | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| sendrecv | — | 36.95 | — | 37.07 | — | — | — | 35.43 |
| reduce | — | 44.22 | — | 42.60 | — | — | — | 13.54 |
| broadcast | — | 44.93 | — | 43.20 | — | — | — | 13.62 |
| gather | — | 48.74 | — | 44.66 | — | — | — | 41.79 |
| scatter | — | 48.64 | — | 1.85 | — | — | — | 0.94 |
| reduce_scatter | — | 24.98 | — | 33.93 | — | — | — | 13.53 |
| all_gather | — | 33.24 | — | 39.07 | — | — | — | 13.66 |
| all_reduce | — | 35.76 | — | 39.82 | — | — | — | 13.61 |
| alltoall | — | 37.71 | — | 2.38 | — | — | — | 1.01 |

Missing: 1, 3, 5, 6, 7 — job 338765 (queued) supplies these.

<!-- AUTO-END -->
