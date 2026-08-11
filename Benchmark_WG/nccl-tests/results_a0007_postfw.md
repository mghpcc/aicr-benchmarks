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

**Flat, because the limit is each GPU's own PCIe DMA engine.** Two steps:

1. *The link is not the constraint.* Each rank sends and receives at once — ~37 GB/s each way,
   ~74 GB/s total on a link whose full-duplex capacity is 2 × 63 = 126 GB/s. At 59% utilisation
   the wire has headroom, so something upstream of it binds: the GPU's bidirectional DMA budget.
2. *That budget is private per GPU.* Adding GPUs adds one more independent PCIe link and no
   shared stage, so the per-GPU rate cannot fall with count — which is what the table shows.

The −4.4% at 8 GPUs is consistent with the ring crossing the socket boundary: a cross-socket
pair measured in isolation gives 36.6 vs 39.5 for a same-socket pair, a comparable penalty.

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

**Five ring/tree collectives converge on 13.5–13.7.** Five different algorithms landing on one
number is the signature of a single shared resource saturating, not five separate problems.

**The trigger is socket crossing, not GPU count.** Proof: at 4 GPUs split 2+2 across sockets,
`reduce` drops 42.60 → 20.13 with the GPU count unchanged. Going from there to 8 GPUs costs a
further 1.5×.

**Why `sendrecv` (35.43) and `gather` (41.79) escape is not established.** `sendrecv` also forms
a ring crossing the socket boundary, so a simple "cross-socket links are capped at ~13.6" model
would cap it too, and does not. `gather` is easier to rationalise — it is root-anchored, so its
bottleneck is one inbound link rather than any ring — but that is reasoning after the fact. The
residual 4→8 GPU factor is likewise unexplained. Treat the 13.5–13.7 figure as a solid
measurement with an incomplete mechanism.

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
| 8 GPU, defaults | `isAllDirectP2p 0` | `SHM/direct/direct` (all 16 connections) | 0.04 |
| 8 GPU, `SYS` | — | P2P | 35.4 |

(Diagnostic sizes, so 39.4 here vs 36.95 converged in Table 1 — same configuration, different
message size.)

The chain is: all pairs are `SYS` distance → default gating refuses P2P for the 8-GPU group →
NCCL falls back to staging through host shared memory → that path runs at 0.04 GB/s. Setting
`SYS` removes the first link in the chain, so the fallback is never reached.

Both runs report `isAllCudaP2p 1` — **CUDA reports P2P as available between all pairs**, so the
hardware and driver support it; it is NCCL's own distance heuristic that declines. Two things
stay unexplained: why the gating passes at 2 GPUs but fails at 8 for pairs at the same `SYS`
distance, and why the SHM path is 0.04 GB/s when ordinary host staging should reach several GB/s.

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

## Why it improves other collectives but breaks `scatter` and `alltoall`

**Why the other collectives improve.** At NCCL defaults, once a group has more than a couple of
GPUs, NCCL declines direct GPU-to-GPU P2P and falls back to staging every byte through host
memory instead — the same fallback described above, just less severe at 4 GPUs than the
0.04 GB/s socket-1 collapse. `NCCL_P2P_LEVEL=SYS` removes that fallback and lets GPUs copy
straight to each other over PCIe, at close to each GPU's own DMA budget (~37–45 GB/s). For the
seven collectives below, that direct route is a clear win — hence the 150–223% gains.

The same setting costs 82–96% on the other two.

Measured at 4 GPUs, socket 0:

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

**The trade-off is binary.** Since all pairs are `SYS` distance, the P2P level is an on/off
switch. `NCCL_P2P_LEVEL=PHB` (49.90) and `NCCL_P2P_DISABLE=1` (50.32) both restore `scatter`
because both simply turn P2P off. There is no intermediate setting.

**Mechanism — hypothesis, not established.** The broken collectives are those where *one rank
sends to many peers at once*. `gather` (many→one) and `sendrecv` (1→1) are healthy; `scatter`
(one→many) and `alltoall` are not. `gather` at 44.66 versus its mirror `scatter` at 1.85 — same
root, same sizes, opposite direction — rules out any bandwidth explanation. Concurrent
multi-peer P2P transmit is the suspect; this has not been proven.

In plain terms: a P2P copy is driven by the GPU that is *sending* the data — it reads its own
memory and pushes it across PCIe. Each GPU can only run a limited number of these concurrent
sends. In `gather`, every GPU sends one copy using its own resources, so nothing competes. In
`scatter`, a single GPU must feed all the others at once, and those sends contend on that one
sender. `alltoall` is worse because every GPU is doing this "send to everyone" job at once,
not just one root. That's also why cutting the number of channels to 1
(`NCCL_MAX_NCHANNELS=1`) claws back some speed (1.85→4.01) — fewer things piling up on the
sender at once. Turning P2P off routes everything through host memory instead, which does not
have this one-GPU pile-up problem.

**So the two faults have opposite fixes:** the socket-1 collapse needs P2P **on**, `scatter` and
`alltoall` need it **off**. Whether you can actually choose depends on GPU placement — see §3.

---

# 3. Recommended configuration

## Decide in this order

**Step 1 — GPU placement decides whether you have a choice at all.**

| GPUs used | Choice available? |
|---|---|
| ≤ 2 GPUs, or ≥ 3 all on one socket | **Both settings work** — go to step 2 |
| ≥ 3 GPUs with ≥ 2 on socket 1 (includes every 8-GPU job) | **`NCCL_P2P_LEVEL=SYS` forced** — defaults give 0.04 GB/s |

Placement comes first because at defaults such a group is unusable regardless of which
collective it runs. Only when both settings are viable does the workload decide.

**Step 2 — the workload picks the setting.**

| Dominant collective | Setting | busbw (4 GPU, one socket) |
|---|---|---:|
| all_reduce, all_gather, reduce_scatter, sendrecv, reduce, broadcast | `NCCL_P2P_LEVEL=SYS` | 34–43 |
| gather | either — `SYS` marginally better | 39.37 → 44.66 |
| **scatter, alltoall** | **NCCL defaults** | **50.76 / 13.30** |

## By DL parallelism strategy

| Strategy | NCCL ops | Setting | Expected (4 GPU) |
|---|---|---|---:|
| Data parallel | all_reduce | `SYS` | 39.82 |
| ZeRO / FSDP | reduce_scatter + all_gather | `SYS` | 33.9 / 39.1 |
| Tensor parallel | all_reduce, all_gather | `SYS` | 39.8 / 39.1 |
| Pipeline parallel | sendrecv | `SYS` | 37.07 |
| **MoE / expert routing** | **alltoall** | **defaults** | **13.30** |

Everything except MoE wants `SYS`, and gains 2.5–3.2×. MoE is the only strategy whose critical
collective is one that `SYS` degrades — which is why it collides with step 1 below.

## The unresolved case: 8-GPU MoE

Steps 1 and 2 give opposite answers, and neither is usable:

- Step 1 forces `SYS` (8 GPUs always include ≥ 2 on socket 1) → `alltoall` = **1.01** (measured)
- Step 2 wants defaults for `alltoall` → but at 8 GPUs defaults trip the socket-1 collapse,
  measured at **0.04** for `sendrecv`. The collapse is transport-level, so `alltoall` is expected
  to fall with it — not measured directly, because a converged run at 0.04 GB/s is impractical.

**There is no working configuration for 8-GPU alltoall on this node.** Until the
`scatter`/`alltoall` mechanism is understood, MoE workloads should stay within one socket
(≤ 4 GPUs, NCCL defaults, `alltoall` 13.30), where step 1 leaves the choice open.

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
