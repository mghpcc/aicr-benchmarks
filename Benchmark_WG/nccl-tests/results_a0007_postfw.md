# a0007 NCCL Results — after the PCIe firmware update (2026-08-10)

**Status:** Tables 1–3 are complete. Two jobs are running and will be folded in automatically:
335776 (`a0007-crosssocket.sh`, explains the 4→8 GPU drop under Table 3) and 335844
(`a0007-defaults-control.sh`, the missing NCCL-defaults control needed before anything can be
attributed to the firmware). The pair-matrix and full sweep jobs were cancelled by request.

> **Attribution warning.** Comparisons against the `a0008` pre-firmware baseline change three
> variables at once — node, firmware, and NCCL setting. Where the confound has been resolved
> (`sendrecv`) the answer is that **the NCCL setting, not the firmware, accounts for the
> change**. Elsewhere no firmware attribution in this file is yet supported.

**Every benchmark result in this file is measured with `NCCL_P2P_LEVEL=SYS`.** That setting is
mandatory on this node — see the headline below. Default-settings numbers appear only in the
headline section, where they document the fault; the full default-settings diagnostic record is
in **`diag_a0007_socket1.md`**.

**Node:** a0007, reservation `shaohao_a0007` (2026-08-10T11:00 → 2026-08-11T11:00).
**Hardware:** 8× NVIDIA RTX PRO 6000 Blackwell Server Edition, no NVLink, PCIe Gen5 x16 per GPU
(~63 GB/s per direction). 2× AMD EPYC Turin, NPS=4 (8 NUMA dies). GPUs 0–3 on socket 0 (PCIe
domain `0000:`), GPUs 4–7 on socket 1 (domain `0001:`). Broadcom PEX890xx Gen5 switches.
**Software:** nvhpc/26.3, NCCL 2.29.3, nccl-tests 2.18.3, `NCCL_NVLS_ENABLE=0` (driver-580 /
no-IMEX workaround).

**Scripts:** `a0007-env.sh`, `a0007-topo.sh`, `a0007-1node-8gpu.sh`, `a0007-socket.sh`,
`a0007-pair-matrix.sh`, `a0007-sweep.sh`, `submit-a0007.sh`, `extract_a0007.py`.
**Outputs:** `out-1node-a0007/`. No pre-existing file was modified.

Converged values taken at 16 GB, best of out-of-place / in-place — the same convention as
`results_rtx6000.md`.

---

## Headline: the socket-1 multi-GPU collapse and its workaround

**`export NCCL_P2P_LEVEL=SYS` is required for any multi-GPU NCCL work on this node.**
Without it, throughput collapses by nearly three orders of magnitude.

| 8-GPU sendrecv | busbw @ 16 GB converged, 20 iters (GB/s) |
|---|---:|
| NCCL defaults | **0.04** |
| **`NCCL_P2P_LEVEL=SYS`** | **35.43** |

That is an **885× difference**, and the workaround's results validate clean (`#wrong = 0`).

The fault triggers whenever a group has **≥ 3 GPUs total and ≥ 2 GPUs on socket 1**. Socket 0
scales cleanly to 4 GPUs at defaults (13.0 GB/s); socket 1 collapses at 3 (0.06 GB/s). All 28
GPU pairs are individually healthy at ~39.5 GB/s, so no single GPU, link, or switch port is
degraded.

### What fixes it, and what does not

Seven NCCL settings tested at 8 GPUs. **`NCCL_P2P_LEVEL=SYS` is the only one that recovers
anything** — every other knob leaves the node within a factor of ~2 of the 0.04 GB/s floor:

| 8-GPU knob | busbw @ 16 MiB, 5 iters (GB/s) | verdict |
|---|---:|---|
| **`NCCL_P2P_LEVEL=SYS`** | **32.66** *(35.43 converged — see note)* | **fixes it — 800×** |
| `NCCL_SHM_DISABLE=1` | 0.09 | no fix |
| `NCCL_ALGO=Ring` | 0.04 | no fix |
| `NCCL_MAX_NCHANNELS=1` | 0.04 | no fix |
| `NCCL_PROTO=Simple` | 0.04 | no fix |
| `NCCL_P2P_DISABLE=1` | 0.04 | no fix |
| `NCCL_P2P_LEVEL=0` | 0.04 | no fix |
| *(defaults, for reference)* | 0.04 | — |

All eight rows are measured identically at 16 MiB / 5 iters, so they are directly comparable to
each other. They are **not** comparable to the converged 16 GB figures elsewhere in this file —
that is why this column carries its measurement conditions in the header. The broken cases
cannot be run at 16 GB at all: at 0.04 GB/s a single 16 GB iteration takes ~7 minutes.
Environment is NCCL default apart from the single knob named in each row.

**Why `SYS` reads 32.66 here but 35.43 in the converged table above.** Both are 8-GPU `sendrecv`
with the same workaround; they differ only in measurement conditions, and the gap is measurement
noise plus a small size effect — not different behaviour:

| | knob sweep (job 335364) | converged run (job 335385) |
|---|---|---|
| message size | 16 MiB | 16 GiB (1024× larger) |
| iterations | 5 | 20 |
| purpose | fast triage, many cases | the actual benchmark |
| result | 32.66 | 35.43 |

The converged job swept sizes, so it measured its own 16 MiB point — **34.41 GB/s**, against
35.43 at 16 GB. Message size therefore explains only ~3% of the difference; `sendrecv` has
already reached the knee of its bandwidth curve by 16 MiB:

| message | 1 MiB | 4 MiB | 16 MiB | 64 MiB | 1 GiB | 16 GiB |
|---|---:|---:|---:|---:|---:|---:|
| busbw | 15.63 | 18.16 | 34.41 | 35.13 | 35.58 | 35.43 |

The remaining ~5% (32.66 vs 34.41 at the same size) is run-to-run variance from the diagnostic's
5 iterations versus the benchmark's 20, and its shorter warm-up ramp. **Treat 35.43 as the
node's figure**; the 32.66 exists only to be compared against the other knobs in the table above,
all measured identically.

Note the two most informative negatives: `NCCL_P2P_DISABLE=1` and `NCCL_P2P_LEVEL=0` — both
*restrict* P2P, and both land exactly on the 0.04 floor, matching the default. That is the clue
that the default is already behaving as if P2P were unavailable, which the next section
confirms.

### Why `NCCL_P2P_LEVEL=SYS` fixes it

`NCCL_P2P_LEVEL` sets the **maximum topological distance at which NCCL is willing to use the
P2P (direct GPU-to-GPU pointer) transport**. `SYS` is the most permissive value: it allows P2P
between GPUs that are only connected through the whole system, i.e. across PCIe root complexes
and CPU sockets. If a GPU pair is further apart than the configured level, NCCL refuses P2P for
that pair and falls back to another transport.

On this node **every GPU pair is `SYS` distance** (`nvidia-smi topo -m` reports `SYS` for all 28
pairs — no pair shares a PCIe switch). So `SYS` is exactly the threshold that admits every pair,
and anything stricter admits none of them.

`NCCL_DEBUG=INFO` shows the mechanism directly:

| run | `Check P2P Type` | transport actually used | busbw |
|---|---|---|---:|
| 2 GPU, defaults | `isAllDirectP2p 1` | `P2P/direct pointer` | 39.4 |
| 8 GPU, defaults | `isAllDirectP2p 0` | **`SHM/direct/direct`** (all 16 connections) | 0.04 |
| 8 GPU, `P2P_LEVEL=SYS` | — | — | 35.4 |

Both runs report `isAllCudaP2p 1`, meaning **CUDA confirms P2P is possible between all pairs** —
the hardware and driver support it. It is NCCL's own distance gating that declines to use it. At
8 GPUs the default gating sets `isAllDirectP2p 0` and NCCL drops every connection to the **SHM
transport, staging all traffic through host shared memory**, which on this node runs at
0.04 GB/s. Setting `NCCL_P2P_LEVEL=SYS` raises the permitted distance to the maximum, so all
pairs qualify, direct P2P is used throughout, and the SHM fallback is never selected.

This closes the loop on the knob table above. `NCCL_P2P_DISABLE=1` and `NCCL_P2P_LEVEL=0` sit
exactly on the default's 0.04 because they force the very same SHM path the default was already
taking. `NCCL_SHM_DISABLE=1` (0.09) only pushes it onto another slow fallback. `ALGO`, `PROTO`
and `MAX_NCHANNELS` change *how* NCCL schedules traffic, not *which transport* carries it, so
they cannot help. Only raising the P2P level avoids the fallback altogether.

Two things remain **unexplained** and are not claimed here: why NCCL's default gating yields
`isAllDirectP2p 0` for groups with ≥ 2 socket-1 GPUs but `1` for 2-GPU groups at the same `SYS`
distance; and why the SHM path itself runs at 0.04 GB/s, which is far slower than normal host
staging should be. The workaround is verified; the reason the default misjudges this node is not.

Full evidence — the composition table, pair matrix, leave-one-out, knob sweep, what was ruled
out, and the PCIe-domain hypothesis — is in **`diag_a0007_socket1.md`**.

---

## Table 1: `sendrecv` scaling — 2 / 4 / 8 GPUs

Converged 16 GB, `NCCL_P2P_LEVEL=SYS`. `sendrecv` has a busbw multiplier of 1, so algbw = busbw.
`PCIe link spec` = 63 GB/s, one direction of a Gen5 x16 link.

| Config | GPUs | devices | sockets | algbw | busbw (GB/s) | % of link spec | Effective ceiling |
|---|---:|---|---|---:|---:|---:|---|
| 2 GPU, one socket | 2 | 0,1 | 1 | 36.95 | **36.95** | 59% | GPU PCIe DMA bidir budget |
| 4 GPU, one socket | 4 | 0,1,2,3 | 1 | 37.07 | **37.07** | 59% | GPU PCIe DMA bidir budget |
| 8 GPU, two sockets | 8 | 0–7 | 2 | 35.43 | **35.43** | 56% | same, −4% for socket crossing |

For reference, at NCCL **defaults**: a0007 itself gives 12.98 at 4 GPUs (job 335360) and a0008
gave 13.0 before the firmware update. Both are the SHM fallback path, and they agree — so the
step to 37.07 is the NCCL setting, not the firmware. See the attribution section.

### Why `sendrecv` is flat across GPU count

**It is limited by each GPU's own PCIe DMA engine, and that resource is private per GPU.**
In `sendrecv` every rank simultaneously sends one message to its ring successor and receives one
from its predecessor. Each GPU therefore drives ~37 GB/s outbound and ~37 GB/s inbound at the
same time — about 74 GB/s across its own x16 link, against a full-duplex capacity of 2 × 63 =
126 GB/s. The link is only 59% used, so the wire is not the constraint; the GPU's bidirectional
DMA budget is. Adding GPUs adds one private PCIe link per GPU and no shared stage, so the
per-GPU rate cannot fall — hence 36.95 → 37.07 → 35.43 rather than any decline.

This ~37 GB/s bidirectional budget reproduces the pre-firmware `a0001` 2-GPU measurement of
37.4 GB/s exactly, which is reassuring: that configuration was small enough that NCCL used P2P
even at defaults, so it was never distorted by the SHM fallback.

The 4% dip at 8 GPUs is the ring crossing the socket boundary; a single cross-socket P2P link
measures 36.6 GB/s in isolation, so one or two such hops cost little.

---

## Table 2: all collectives — 4 GPUs, one socket (`0,1,2,3`)

Converged 16 GB, `NCCL_P2P_LEVEL=SYS`, job 335386. Pre-firmware column is `a0008`, same GPU
count and socket, at NCCL defaults (`results_rtx6000.md` Table 2).

> **Read the `pre-fw` and `change` columns with care.** They compare a different node, a
> different firmware *and* a different NCCL setting simultaneously. For `sendrecv` the confound
> is resolved — a0007 at defaults gives 12.98, i.e. the whole gain is the NCCL setting, not the
> firmware (see the firmware section below). For the other rows it is **not** resolved; job
> 335844 supplies the missing a0007-at-defaults control.

| Benchmark | algbw | busbw (GB/s) | % of 63 | a0008 old-fw, defaults | difference (confounded) | Traffic pattern / ceiling |
|---|---:|---:|---:|---:|---|---|
| sendrecv | 37.07 | 37.07 | 59% | 13.0 | +185% | bidirectional — DMA bidir budget |
| reduce | 42.60 | 42.60 | 68% | 13.2 | +223% | tree, mostly one-way per link |
| broadcast | 43.20 | 43.20 | 69% | 17.6 | +145% | tree, mostly one-way per link |
| gather | 59.55 | 44.66 | 71% | 39.2 | +14% | root-anchored, unidirectional |
| scatter | 2.46 | **1.85** | 2.9% | 50.6 | **−96%** | **anomaly — undiagnosed** |
| reduce_scatter | 45.24 | 33.93 | 54% | 13.0 | +161% | ring, bidirectional |
| all_gather | 52.09 | 39.07 | 62% | 13.3 | +194% | ring, bidirectional |
| all_reduce | 26.55 | 39.82 | 63% | 13.1 | +204% | ring RS+AG, bidirectional |
| alltoall | 3.18 | **2.38** | 3.8% | 13.4 | **−82%** | **anomaly — undiagnosed** |
| hypercube | 4.33 | 4.33 | — | FAILED | — | FAILED — nccl-tests 2.18.3 bug |

### Why the collectives split into two bands

**The healthy collectives sort by how one-directional their per-link traffic is**, which is what
the ~37 GB/s bidirectional DMA budget predicts:

- **Bidirectional patterns land at 34–40.** `sendrecv` (37.07), `all_gather` (39.07),
  `all_reduce` (39.82) and `reduce_scatter` (33.93) all have every GPU sending and receiving
  concurrently, so they split the same DMA budget as `sendrecv` and cluster around it.
  `reduce_scatter` sits lowest because it interleaves reduction arithmetic with the transfers.
- **Predominantly one-way patterns exceed it, reaching 42–45.** `gather` (44.66), `broadcast`
  (43.20) and `reduce` (42.60) load each link mostly in a single direction, so the DMA engine is
  not splitting its budget two ways and more of the 63 GB/s link is usable. `gather`'s algbw of
  59.55 is 95% of the link spec — the root's inbound PCIe link is the binding constraint, exactly
  as expected for a root-anchored collective.

So on 4 GPUs within one socket the node behaves the way the hardware predicts, with the PCIe DMA
engine — not Infinity Fabric — setting the ceiling.

**`scatter` (1.85) and `alltoall` (2.38) do not fit any of this** and are treated as a separate
fault, not a bandwidth ceiling. `scatter` is the exact mirror of `gather`: same root, same
message sizes, opposite direction. `gather` achieves 44.66 and `scatter` 1.85 — a **24×
asymmetry** on the same links. No topology or budget argument produces that. See the regression
note below.

---

## Table 3: all collectives — 8 GPUs, two sockets (`0–7`)

Converged 16 GB, `NCCL_P2P_LEVEL=SYS`, job 335385. Final column compares against Table 2.

| Benchmark | algbw | busbw (GB/s) | % of 63 | 4-GPU busbw | 8 vs 4 GPU |
|---|---:|---:|---:|---:|---|
| sendrecv | 35.43 | **35.43** | 56% | 37.07 | −4% |
| reduce | 13.54 | 13.54 | 21% | 42.60 | **−68%** |
| broadcast | 13.62 | 13.62 | 22% | 43.20 | **−68%** |
| gather | 47.76 | **41.79** | 66% | 44.66 | −6% |
| scatter | 1.07 | 0.94 | 1.5% | 1.85 | −49% (already broken) |
| reduce_scatter | 15.47 | 13.53 | 21% | 33.93 | **−60%** |
| all_gather | 15.62 | 13.66 | 22% | 39.07 | **−65%** |
| all_reduce | 7.78 | 13.61 | 22% | 39.82 | **−66%** |
| alltoall | 1.15 | 1.01 | 1.6% | 2.38 | −58% (already broken) |
| hypercube | 2.81 | 2.81 | — | 4.33 | FAILED — validation bug |

### Why 8 GPUs bifurcate: two survive, five collapse to ~13.6

The striking feature is not a uniform slowdown — it is a **clean split**:

- **Survivors:** `sendrecv` 35.43 and `gather` 41.79, both within 6% of their 4-GPU values.
- **Collapsed:** `reduce`, `broadcast`, `reduce_scatter`, `all_gather`, `all_reduce` all land on
  **13.5–13.7 GB/s** — five different algorithms converging on one number, which is the
  signature of a single shared resource saturating rather than five separate problems.

**Working explanation — inter-socket fabric saturation.** A ring or tree spanning all 8 GPUs must
cross the socket boundary, and in a ring every link carries equal traffic, so the ring runs at the
speed of its slowest link. A single cross-socket P2P link measures 36.6 GB/s *in isolation*, but
an 8-GPU ring has **two** links crossing concurrently. If the aggregate inter-socket budget is
roughly 27 GB/s, two concurrent crossings get ~13.6 GB/s each — which is the observed number.
The arithmetic fits, and it explains why the collapse is common to all five ring/tree collectives.

**What this explanation does not cover — stated plainly.** `sendrecv` at 8 GPUs also forms a ring
that crosses sockets, yet it holds 35.43 GB/s. If two concurrent crossings were capped at ~13.6
each, `sendrecv` should be capped too. It is not, so either its NCCL schedule arranges crossings
differently, or the inter-socket limit is not the whole story. **This is a hypothesis, not a
conclusion.** `gather` surviving is easier: it is root-anchored, so its bottleneck is the single
root's inbound link, not any ring.

**The discriminating experiment is running now** (job 335776, `a0007-crosssocket.sh`): case
`4gpu-2plus2` uses GPUs `0,1,4,5` — only **four** GPUs, but the same **two** socket crossings as
the 8-GPU ring. If its ring collectives land near 13.6, socket crossing is confirmed as the cause
and GPU count is exonerated. If they stay at 34–43, the hypothesis is dead and the effect is a
count/scaling one. Results will be added to this file when the job completes.

---

## The 13 GB/s "Infinity Fabric ceiling" in `results_rtx6000.md` is an artifact

`results_rtx6000.md` Table 2 explains its ~13 GB/s rows as "IF 4-die bidir saturation" — a
hardware limit of Infinity Fabric between NUMA dies. It is not a hardware limit.

**The clean, single-variable evidence is `sendrecv`.** Same node, same day, same 4 GPUs on
socket 0, converged 16 GB — only `NCCL_P2P_LEVEL` differs:

| a0007, 4 GPU socket 0 | defaults | `NCCL_P2P_LEVEL=SYS` |
|---|---:|---:|
| sendrecv | **12.98** | **37.07** |

A hardware fabric ceiling does not lift 2.9× because an environment variable changed. That 13
GB/s was NCCL's SHM fallback being measured, not Infinity Fabric.

**The other collectives point the same way but are not yet controlled.** These compare a0008 at
defaults against a0007 with the workaround, so node and firmware vary too:

| | a0008 old-fw, defaults | a0007, `P2P_LEVEL=SYS` | controlled? |
|---|---:|---:|---|
| sendrecv | 13.0 | 37.07 | **yes** — a0007 defaults = 12.98 |
| reduce | 13.2 | 42.60 | no — job 335844 pending |
| reduce_scatter | 13.0 | 33.93 | no — job 335844 pending |
| all_gather | 13.3 | 39.07 | no — job 335844 pending |
| all_reduce | 13.1 | 39.82 | no — job 335844 pending |

Given that all five sat at the same ~13 GB/s and that `sendrecv` is proven to be the SHM
fallback, the same explanation very likely covers the rest — but job 335844 is what will
establish it. **The conclusion is safe for `sendrecv` today and provisional for the others.**

A caution on the number itself: 13 appears again in Table 3 at 8 GPUs *with* P2P enabled, where
it is a genuine measurement of something real. The coincidence with this artifact value is
exactly that — a coincidence. The two must not be conflated.

## `scatter` and `alltoall`: anomalous, cause NOT established

| 4 GPU, socket 0 | a0008 pre-fw, **defaults** | a0007 post-fw, **`P2P_LEVEL=SYS`** |
|---|---:|---:|
| scatter | 50.6 | **1.85** |
| alltoall | 13.4 | **2.38** |

Earlier revisions of this file called this a firmware regression "confirmed like-for-like".
**That was wrong and is withdrawn.** The two columns differ in node, firmware *and* NCCL
setting — the same confound described in the next section. Since `NCCL_P2P_LEVEL=SYS` is known
to change `sendrecv` by 2.9×, it could equally be depressing `scatter` and `alltoall` by forcing
P2P onto patterns better served by another transport.

What is solid, independent of the confound:

- The numbers are real and reproducible: `scatter` 1.85 at 4 GPUs and 0.94 at 8 GPUs.
- They are **not** a bandwidth ceiling. `gather` is `scatter`'s exact mirror — same root, same
  message sizes, opposite direction — and runs 44.66 on the same links. A **24× asymmetry**
  between two mirrored collectives has no topology explanation.
- Both are healthy at 2 GPUs (`scatter` 48.64, `alltoall` 37.71) and collapse from 4 upward.

What is **not** established: whether the cause is the firmware, the node, or
`NCCL_P2P_LEVEL=SYS` itself. Job 335844 measures a0007 `scatter`/`alltoall` at defaults and
discriminates:

| job 335844 result | conclusion |
|---|---|
| `scatter` ≈ 50 at defaults | `NCCL_P2P_LEVEL=SYS` causes the collapse — the workaround has a cost |
| `scatter` ≈ 1.85 at defaults | the setting is innocent; firmware or node is implicated |

That single number decides it. Until then, no cause should be quoted.

## Attribution: is the change from `NCCL_P2P_LEVEL=SYS`, the firmware, or something else?

> ### Verdict
> **`NCCL_P2P_LEVEL=SYS`.** Everywhere the question has been settled with a controlled
> measurement, the NCCL setting accounts for the change and the firmware accounts for none of it.
> The firmware update has **no demonstrated effect on NCCL performance on this node**.
> Rows where the control is still missing (everything except `sendrecv`) are marked as such and
> should not be attributed to anything yet.

**This section previously attributed large gains to the firmware update. That was wrong, and
the claim is withdrawn.**

The comparison being drawn was:

| | node | firmware | NCCL setting |
|---|---|---|---|
| "pre-firmware" (`a0008`, `results_rtx6000.md`) | a0008 | old | **defaults** |
| "post-firmware" (`a0007`, Tables 1–3) | a0007 | new | **`NCCL_P2P_LEVEL=SYS`** |

**Three variables change at once** — node, firmware, and the NCCL P2P setting. No difference
between those two columns can be attributed to the firmware, because the NCCL setting alone is
known to move `sendrecv` by 2.9× on a single node. Calling `a0008` "the pre-firmware result" is
accurate as a date label but misleading as a baseline, since it is also the *defaults* result
and a *different physical node*.

### The one place the confound is already resolved: `sendrecv`

Measuring a0007 itself at NCCL defaults removes the setting and the node from the comparison:

| 4 GPU, socket 0, sendrecv | NCCL defaults | `NCCL_P2P_LEVEL=SYS` |
|---|---:|---:|
| **a0008** (pre-firmware) | 13.0 | not measurable — node since updated |
| **a0007** (post-firmware) | **12.98** | **37.07** |

Reading across the bottom row and down the first column:

- **a0007 defaults (12.98) ≈ a0008 defaults (13.0).** At matched settings, the post-firmware
  node performs the same as the pre-firmware one. **The firmware changed nothing measurable here.**
- **a0007 defaults (12.98) → a0007 SYS (37.07) on the same node, same day.** The entire 2.9×
  improvement comes from `NCCL_P2P_LEVEL=SYS`.

**Answer: the change is from the NCCL setting, not the firmware.**

### What is still unresolved

The same confound applies to the `scatter` / `alltoall` regression claimed earlier, and there it
is **not** yet resolved. Those comparisons were a0008-at-defaults versus a0007-with-`SYS`, and
**no non-`sendrecv` collective has ever been measured on a0007 at defaults**. It is therefore
entirely possible that `NCCL_P2P_LEVEL=SYS` *itself* degrades `scatter` and `alltoall` — forcing
P2P where NCCL would otherwise have chosen a better transport for those patterns — and that the
firmware is innocent. Until the control lands, the "firmware regression" reading of
`scatter` 1.85 vs 50.6 and `alltoall` 2.38 vs 13.4 is **unsupported**.

**Job 335844 (`a0007-defaults-control.sh`) is queued** and supplies exactly this: a0007, NCCL
defaults, all 10 collectives, at 2 and 4 GPUs on socket 0 (configurations that do not trigger
the socket-1 collapse, so they run at usable speed even at defaults). It completes the 2×2:

| | NCCL defaults | `NCCL_P2P_LEVEL=SYS` |
|---|---|---|
| a0008, pre-firmware | have | impossible |
| a0007, post-firmware | **job 335844** | have (job 335386) |

Then `a0007 defaults vs a0007 SYS` isolates the setting, and `a0007 defaults vs a0008 defaults`
isolates firmware + node. Results will be added here when the job finishes.

### The residual confound that cannot be removed on this node

Even with job 335844, `a0008` and `a0007` are **different physical machines**. Separating
"firmware" from "node-to-node variation" needs either a same-node before/after (not available —
a0007 was already updated) or a currently non-updated a-node measured at defaults. Any firmware
attribution in this file should be read with that caveat.

## Open

- [x] 4-GPU sendrecv with the workaround — **37.07**, vs 13.0 at defaults.
- [x] `scatter` anomaly reproduces at 4 GPUs — **1.85**; cause not yet attributable (job 335844).
- [ ] **Job 335776 running**: `4gpu-2plus2` decides whether the Table 3 collapse to ~13.6 is
      caused by socket crossing or by GPU count. Also completes `4gpu-socket1` and
      `2gpu-crosssocket`.
- [ ] **Revise `results_rtx6000.md`**: its ~13 GB/s "IF 4-die bidir saturation" rows are a NCCL
      default-P2P-level artifact, not hardware.
- [ ] **Diagnose `scatter` and `alltoall`** — 1.85 vs 50.6 and 2.38 vs 13.4, healthy at 2 GPUs,
      not fixed by the workaround. Needs a same-node before/after to be conclusive.
- [ ] Re-run the cancelled `a0007-pair-matrix.sh` and `a0007-sweep.sh` if the 28-pair matrix and
      the full 2→8 scaling curve are still wanted.
- [ ] Run the socket-composition test on a **non-updated a-node** to settle attribution of the
      socket-1 collapse.

## Raw data

| file | contents |
|---|---|
| `out-1node-a0007/a0007-topo-a0007-335183` | topology, PCIe link state, NUMA, NIC firmware |
| `out-1node-a0007/a0007-8gpu-a0007-335385` | **Table 3** — 8 GPU, all collectives, `P2P_LEVEL=SYS` |
| `out-1node-a0007/a0007-socket-a0007-335386` | **Table 2** — 4 GPU (and 2 GPU) socket 0, `P2P_LEVEL=SYS` |
| `out-1node-a0007/a0007-xsock-a0007-335776` | cross-socket discriminator (running) |
| `diag_a0007_socket1.md` | default-settings diagnostic record for the collapse |

Extract any of these with `./extract_a0007.py <file>`.
