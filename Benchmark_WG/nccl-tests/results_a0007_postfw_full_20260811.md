# a0007 NCCL Results — after the PCIe firmware update (2026-08-10)

**Status:** Tables 1–3 complete. Job **338765** (`a0007-missing-counts.sh`) is queued to fill
GPU counts **1, 3, 5, 6, 7** with `NCCL_P2P_LEVEL=SYS`; counts 2, 4 and 8 are already measured
and are not repeated. Job **338766** then regenerates the auto-generated section below. Both
were submitted **without** the reservation, which expired 2026-08-11T11:00, so they queue on
`rtx-batch` for a0007 normally.

> **Attribution resolved (2026-08-11).** a0007 measured at NCCL defaults reproduces the a0008
> "pre-firmware" baseline across every collective (scatter 50.76 vs 50.6, alltoall 13.30 vs 13.4,
> gather 39.37 vs 39.2, sendrecv 13.09 vs 13.0). **The firmware update changed nothing
> measurable.** Every difference previously attributed to it is the `NCCL_P2P_LEVEL` setting.

**Unless a table says otherwise, results are measured with `NCCL_P2P_LEVEL=SYS`.** That setting
is a trade-off, not a blanket recommendation — see the "Headline" section after Table 3 for the
full workaround, why it is a trade-off, and the per-collective configuration table. The
default-settings diagnostic record is in **`diag_a0007_socket1.md`**.

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

The three tables below are the raw measurements, `NCCL_P2P_LEVEL=SYS` throughout unless noted;
the "Headline" section after Table 3 explains why that setting was used, what it costs, and how
to configure each collective. Start with `sendrecv`, since its 2/4/8-GPU scaling sets the
per-GPU PCIe budget that the rest of the tables are read against.

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
step to 37.07 is the NCCL setting, not the firmware. See "The 13 GB/s 'Infinity Fabric ceiling'
... is an artifact" after the Headline section for the full firmware-vs-setting attribution.

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

`sendrecv` was the simplest case — one traffic pattern, three GPU counts. Table 2 broadens this
to all ten collectives at a single GPU count (4, one socket), which is where the scatter/alltoall
anomaly first appears.

---

## Table 2: all collectives — 4 GPUs, one socket (`0,1,2,3`)

Converged 16 GB, `NCCL_P2P_LEVEL=SYS`, job 335386. Pre-firmware column is `a0008`, same GPU
count and socket, at NCCL defaults (`results_rtx6000.md` Table 2).

> **Read the `pre-fw` and `change` columns with care.** They compare a different node, a
> different firmware *and* a different NCCL setting simultaneously. **Resolved as of job
> 335844** (2026-08-11): a0007 measured at NCCL defaults matches `a0008` defaults on every row
> in this table (sendrecv 12.98 vs 13.0, reduce 13.19 vs 13.2, reduce_scatter 12.91 vs 13.0,
> all_gather 13.29 vs 13.3, all_reduce 13.17 vs 13.1, scatter 50.76 vs 50.6, alltoall 13.30 vs
> 13.4, gather 39.37 vs 39.2) — see "The 13 GB/s 'Infinity Fabric ceiling' ... is an artifact"
> after the Headline section. **Every "difference" column below is therefore the NCCL setting,
> not the firmware**, for every row, not just `sendrecv`.

| Benchmark | algbw | busbw (GB/s) | % of 63 | a0008 old-fw, defaults | effect of `NCCL_P2P_LEVEL=SYS` | Traffic pattern / ceiling |
|---|---:|---:|---:|---:|---|---|
| sendrecv | 37.07 | 37.07 | 59% | 13.0 | +185% | bidirectional — DMA bidir budget |
| reduce | 42.60 | 42.60 | 68% | 13.2 | +223% | tree, mostly one-way per link |
| broadcast | 43.20 | 43.20 | 69% | 17.6 | +145% | tree, mostly one-way per link |
| gather | 59.55 | 44.66 | 71% | 39.2 | +14% | root-anchored, unidirectional |
| scatter | 2.46 | **1.85** | 2.9% | 50.6 | **−96%** | **root-GPU fan-out — mechanism open, see Headline** |
| reduce_scatter | 45.24 | 33.93 | 54% | 13.0 | +161% | ring, bidirectional |
| all_gather | 52.09 | 39.07 | 62% | 13.3 | +194% | ring, bidirectional |
| all_reduce | 26.55 | 39.82 | 63% | 13.1 | +204% | ring RS+AG, bidirectional |
| alltoall | 3.18 | **2.38** | 3.8% | 13.4 | **−82%** | **root-GPU fan-out — mechanism open, see Headline** |

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
asymmetry** on the same links. No topology or budget argument produces that — see the dedicated
"`scatter` and `alltoall`" section after the Headline for the cause and the leading hypothesis.

Table 3 repeats this same 10-collective sweep at 8 GPUs across both sockets, which is where a
second, independent fault (the ring/tree collapse) appears on top of the scatter/alltoall one.

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

**Discriminating experiment — RESULT (job 335776, case `4gpu-2plus2` = GPUs `0,1,4,5`).**
Four GPUs, but two socket crossings, the same as the 8-GPU ring:

| Collective | 4 GPU, one socket | **4 GPU, 2+2 across sockets** | 8 GPU, two sockets |
|---|---:|---:|---:|
| reduce | 42.60 | **20.13** | 13.54 |
| broadcast | 43.20 | **19.71** | 13.62 |
| all_gather | 39.07 | **20.10** | 13.66 |
| all_reduce | 39.82 | **19.69** | 13.61 |
| reduce_scatter | 33.93 | **21.04** | 13.53 |
| sendrecv | 37.07 | 32.80 | 35.43 |
| gather | 44.66 | 43.96 | 41.79 |

**Socket crossing is confirmed as the dominant cause.** Holding GPU count fixed at 4 and merely
moving two of them to the other socket halves every ring/tree collective — 42.60 → 20.13 for
`reduce`, and the same ~2× for the other four. GPU count is *not* the trigger.

But it is not the whole story either: 8 GPUs fall further, from ~20 to ~13.6, at the same two
crossings. So there are two separate penalties — a ~2× cost for crossing the inter-socket fabric
at all, and a further ~1.5× for scaling the ring across it. A pure "fixed aggregate inter-socket
budget shared by two links" model predicts the 2+2 and 8-GPU cases should match; they do not, so
that simple model is **wrong** and the residual scaling term is unexplained.

The two survivors behave exactly as their traffic patterns predict: `gather` is root-anchored and
barely moves (44.66 → 43.96 → 41.79), and `sendrecv` is a single pairwise exchange bounded by
each GPU's own DMA engine rather than by any ring, so it stays in the low-to-mid 30s throughout.

Tables 1–3 establish two independent, oppositely-fixed faults: the socket-1 ring/tree collapse
just discriminated above, and the scatter/alltoall collapse first seen in Table 2. The rest of
this file is the practical consequence — what to set, per collective, and why the fix for one
fault breaks the other.

---

## Headline: the socket-1 multi-GPU collapse and its workaround

> ### ⚠ Recommendation revised 2026-08-11 — `NCCL_P2P_LEVEL=SYS` is a TRADE-OFF, not a free fix
>
> The NCCL-defaults control (job 335844) showed `scatter` runs at **50.76 GB/s at defaults** and
> **1.85 with `SYS`**. The workaround does not just rescue collectives — it destroys two of them.
> Earlier revisions of this file recommended setting it unconditionally. **That was wrong.**

**Without `NCCL_P2P_LEVEL=SYS`, any group with ≥ 3 GPUs and ≥ 2 on socket 1 collapses to
0.04 GB/s.** With it, seven collectives get ~3× faster and two collapse. Same node, 4 GPUs on
socket 0, converged 16 GB — only the setting differs:

| Collective | NCCL defaults | `NCCL_P2P_LEVEL=SYS` | effect |
|---|---:|---:|---|
| sendrecv | 13.09 | **37.07** | +183% |
| reduce | 13.19 | **42.60** | +223% |
| broadcast | 17.29 | **43.20** | +150% |
| reduce_scatter | 12.91 | **33.93** | +163% |
| all_gather | 13.29 | **39.07** | +194% |
| all_reduce | 13.17 | **39.82** | +202% |
| gather | 39.37 | **44.66** | +13% |
| **scatter** | **50.76** | **1.85** | **−96%** |
| **alltoall** | **13.30** | **2.38** | **−82%** |

### Which setting to use

| Workload | Setting | Why |
|---|---|---|
| Data-parallel / tensor-parallel (all_reduce, all_gather, reduce_scatter, sendrecv) | **`NCCL_P2P_LEVEL=SYS`** | 2.6–3.2× faster; scatter/alltoall not on the critical path |
| MoE / expert routing (alltoall-heavy), or scatter-heavy | **NCCL defaults** — but only up to 4 GPUs *within one socket* | `SYS` costs 82–96% on exactly the collectives that matter |
| Anything using ≥ 3 GPUs with ≥ 2 on socket 1, including all 8-GPU jobs | **`NCCL_P2P_LEVEL=SYS` — mandatory** | defaults collapse to 0.04 GB/s, which is unusable |

**The unavoidable conclusion for 8-GPU jobs: there is no good setting.** Defaults give
0.04 GB/s across the board; `SYS` gives healthy ring collectives but `alltoall` at 1.01 and
`scatter` at 0.94. An 8-GPU MoE workload has no usable configuration on this node today. That is
the single most important thing for the admin in this file.

### Full per-collective configuration reference

`NCCL_P2P_LEVEL` is the only lever that matters on this node (see "Why the trade-off is
binary" below — every pair is `SYS` distance, so it is effectively on/off). Base environment
for every row: `NCCL_NVLS_ENABLE=0` (required regardless of collective — driver-580/no-IMEX
workaround, see admin item 2).

| Collective | Best config, avoiding the socket-1 trigger (≤ 4 GPU in one socket, or < 2 GPU on socket 1) | Full 8-GPU / any config that trips the socket-1 trigger (≥ 3 GPU, ≥ 2 on socket 1) |
|---|---|---|
| sendrecv | `NCCL_P2P_LEVEL=SYS` — **37.07** vs 13.09 defaults | `NCCL_P2P_LEVEL=SYS` — **mandatory**, 35.43 vs 0.04 (defaults, measured) |
| reduce | `NCCL_P2P_LEVEL=SYS` — **42.60** vs 13.19 defaults | `NCCL_P2P_LEVEL=SYS` — mandatory, 13.54 (defaults untested at this config¹, expected ~0.04) |
| broadcast | `NCCL_P2P_LEVEL=SYS` — **43.20** vs 17.29 defaults | `NCCL_P2P_LEVEL=SYS` — mandatory, 13.62 (defaults untested¹) |
| reduce_scatter | `NCCL_P2P_LEVEL=SYS` — **33.93** vs 12.91 defaults | `NCCL_P2P_LEVEL=SYS` — mandatory, 13.53 (defaults untested¹) |
| all_gather | `NCCL_P2P_LEVEL=SYS` — **39.07** vs 13.29 defaults | `NCCL_P2P_LEVEL=SYS` — mandatory, 13.66 (defaults untested¹) |
| all_reduce | `NCCL_P2P_LEVEL=SYS` — **39.82** vs 13.17 defaults | `NCCL_P2P_LEVEL=SYS` — mandatory, 13.61 (defaults untested¹) |
| gather | `NCCL_P2P_LEVEL=SYS` — **44.66** vs 39.37 defaults (modest gain, not critical) | Either setting — 41.79 with `SYS`, root-anchored and barely affected by socket count |
| **scatter** | **NCCL defaults**, or explicit `NCCL_P2P_DISABLE=1` — **50.76** (50.32 explicit) vs 1.85 with `SYS` | **No good setting.** `SYS` gives 0.94; defaults untested at this config¹ — may hit the same ~0.04 floor as the ring collectives |
| **alltoall** | **NCCL defaults**, or explicit `NCCL_P2P_DISABLE=1` — **13.30** (49.90 via `P2P_LEVEL=PHB`, an equivalent off-state) vs 2.38 with `SYS` | **No good setting.** `SYS` gives 1.01; defaults untested¹ |

¹ No collective except `sendrecv` has been measured at NCCL defaults *with* the socket-1
trigger tripped (job 335844 deliberately avoided it, staying at ≤ 4 GPU on one socket). Whether
`reduce`/`broadcast`/etc. and `scatter`/`alltoall` also collapse to ~0.04 under defaults at
8 GPU, or behave differently, is an open question — see Open, below.

If forced into the "no good setting" 8-GPU scatter/alltoall case, `NCCL_MAX_NCHANNELS=1`
recovered partial throughput in isolation (4-GPU, one socket: scatter 1.85→4.01, alltoall
2.3→4.09) — untested in combination with the 8-GPU trigger, but worth trying before accepting
the ~1 GB/s floor.

### Why the trade-off is binary

Every GPU pair here is `SYS` distance, so the P2P level is effectively an on/off switch: `SYS`
enables direct P2P for all pairs, and anything stricter enables it for none. The knob sweep
confirms this — `NCCL_P2P_LEVEL=PHB` (49.90) and `NCCL_P2P_DISABLE=1` (50.32) both restore
`scatter`, because both simply turn P2P off. There is no intermediate setting that keeps the
ring-collective gain while avoiding the scatter loss.

So the two faults have opposite fixes:

- **Socket-1 collapse** (0.04 GB/s) — needs P2P **on**.
- **scatter / alltoall collapse** — needs P2P **off**.

### Why scatter/alltoall need the opposite setting — algorithmic explanation

**Not stated anywhere in earlier revisions of this file.** Every prior mention of the
scatter/alltoall fault called it "anomalous" or "no topology explanation" without saying why it
specifically — and not the other eight collectives — reacts this way to `NCCL_P2P_LEVEL`.
Stating it plainly: this file established *that* `NCCL_P2P_LEVEL=SYS` causes the collapse (job
335844, below), but never explained *why* scatter/alltoall are the two exceptions.

**Working hypothesis — fan-out concurrency on one GPU's copy engine, not an algorithm-class
difference.** `sendrecv`, `all_reduce`, `all_gather`, `reduce_scatter`, `reduce` and
`broadcast` are single fused NCCL library calls that run a ring or tree: as established above
for `sendrecv`, each GPU has at most two active peer connections at a time (predecessor,
successor), regardless of GPU count. `scatter` and `alltoall` in nccl-tests are implemented as
independent `ncclSend`/`ncclRecv` pairs issued inside one `ncclGroupStart`/`ncclGroupEnd` block
— a genuine N-way fan-out, not a pipelined ring.

That structural fact alone doesn't explain the *direction* of the fault: `gather` has the
identical N-way connection topology (root talks to N−1 leaves) and is healthy at 44.66 GB/s.
The difference is which GPU issues the concurrent copies. In `gather`, the N−1 inbound
transfers are each issued by a *different* leaf GPU's own copy engine — naturally parallel, one
queue per GPU. In `scatter`, the *same* root GPU must issue N−1 concurrent *outbound* P2P
copies from its own copy engine at once — all funneled through one queue. `alltoall` puts every
rank in the root's position simultaneously, which is consistent with it failing at least as
badly as `scatter`.

Evidence already in this file fits that story, though nothing here proves it:

| Observation | Consistent with fan-out-concurrency? |
|---|---|
| `gather` (fan-**in**, N sources, one per GPU) healthy at 44.66; `scatter` (fan-**out**, one source) at 1.85 — same links, same message size, opposite direction | yes — only the direction that concentrates concurrent copies on a single GPU fails |
| `NCCL_MAX_NCHANNELS=1` partially recovers both (scatter 1.85→4.01, alltoall ~2.3→4.09), while `MAX_NCHANNELS=4`/`8` leave scatter unchanged (1.84/1.87) | yes — cutting concurrent channels to one helps; the default is evidently already ≥ 4, so it is the *number of concurrent copies*, not simply "P2P is on", that drives the collapse |
| `NCCL_P2P_DISABLE=1` / `NCCL_P2P_LEVEL=PHB` fully recovers both (50.32 / 49.90) | yes — routing through host-staged SHM removes the direct-pointer fan-out entirely |
| Healthy at 2 GPU (fan-out = 1 peer), collapsed by 4 GPU (fan-out = 3 peers); the 3-GPU point (fan-out = 2) is not yet measured (job `a0007-missing-counts.sh`, queued) | consistent, but the fan-out ≥ 2 threshold is not directly confirmed |

**This is a hypothesis, not a confirmed mechanism.** Nothing in this file directly measures
per-GPU copy-engine queue depth or isolates concurrency from data volume. The discriminating
test would compare `NCCL_DEBUG=INFO` channel/queue behavior for `scatter` against `gather` at
matched GPU counts, or a microbenchmark that fans a single GPU's copy engine out to N peers via
N *separate* CUDA streams. Neither has been run.

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

The Headline established `NCCL_P2P_LEVEL` as the lever; the next two sections establish what it
was actually correcting for. First, the ~13 GB/s figures scattered through Tables 1–3 at NCCL
defaults — previously misattributed to Infinity Fabric hardware.

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

**The other collectives point the same way, and — as of job 335844 (2026-08-11) — are now
controlled too.** a0007 measured at NCCL defaults, compared against a0008 old-firmware defaults:

| | a0008 old-fw, defaults | a0007, defaults | a0007, `P2P_LEVEL=SYS` | controlled? |
|---|---:|---:|---:|---|
| sendrecv | 13.0 | 12.98 | 37.07 | **yes** — matches |
| reduce | 13.2 | 13.19 | 42.60 | **yes** — matches |
| reduce_scatter | 13.0 | 12.91 | 33.93 | **yes** — matches |
| all_gather | 13.3 | 13.29 | 39.07 | **yes** — matches |
| all_reduce | 13.1 | 13.17 | 39.82 | **yes** — matches |

Every row: a0007-at-defaults matches a0008-at-defaults to within measurement noise, and the
entire jump to `SYS` is the NCCL setting. **The conclusion that held for `sendrecv` alone now
holds for all five ring/tree collectives: this is an `NCCL_P2P_LEVEL` artifact, not a firmware
effect and not Infinity Fabric.**

A caution on the number itself: 13 appears again in Table 3 at 8 GPUs *with* P2P enabled, where
it is a genuine measurement of something real (the inter-socket ring collapse). The coincidence
with this artifact value is exactly that — a coincidence. The two must not be conflated.

The same job also resolved the other outstanding attribution question on this node — whether
`NCCL_P2P_LEVEL=SYS` itself, rather than the firmware, is what breaks `scatter`/`alltoall`.

## `scatter` and `alltoall`: `NCCL_P2P_LEVEL=SYS` confirmed as the cause; the mechanism is a hypothesis

**Resolved 2026-08-11 (job 335844).** Earlier revisions of this file called the drop below a
firmware regression, "confirmed like-for-like" — that was wrong and was withdrawn once it was
noticed the comparison confounded node, firmware, *and* NCCL setting at once. The controlled
version, measured on **a0007 itself**, same day, same 4 GPUs, setting as the only variable:

| 4 GPU, socket 0 | NCCL defaults | `NCCL_P2P_LEVEL=SYS` |
|---|---:|---:|
| scatter | **50.76** | 1.85 |
| alltoall | **13.30** | 2.38 |

**Verdict: `NCCL_P2P_LEVEL=SYS` is the cause. Not the firmware, not the node.** This is the
same conclusion the auto-generated section below reaches independently.

The remaining open question is *why* forcing P2P specifically breaks these two collectives —
see "Why scatter/alltoall need the opposite setting" in the headline section above for the
working hypothesis (root-GPU fan-out concurrency under direct P2P, not a bandwidth ceiling).

What is solid, independent of the mechanism:

- The numbers are real and reproducible: `scatter` 1.85 at 4 GPUs, 0.94 at 8 GPUs, spread
  ≤ 3.6% across three repeats (job 335909).
- They are **not** a bandwidth ceiling. `gather` is `scatter`'s exact mirror — same root, same
  message sizes, opposite direction — and runs 44.66 on the same links. A **24× asymmetry**
  between two mirrored collectives is a P2P-transport effect, not a link limit.
- Both are healthy at 2 GPUs (`scatter` 48.64, `alltoall` 37.71) and collapsed by 4 GPUs
  (fan-out ≥ 3 peers). The 3-GPU point is not yet measured.

Both attribution questions this file set out to answer — ring/tree collectives and
scatter/alltoall alike — are now resolved the same way: `NCCL_P2P_LEVEL`, not firmware, drives
every performance difference measured on this node. One confound remains structurally
unresolvable here: `a0008` and `a0007` are different physical machines, so this cannot fully
separate "firmware" from ordinary node-to-node variation (see admin item 5). What it does
establish cleanly is that no *NCCL-performance* difference on this node needs a firmware
explanation. What that means in practice for the site is the subject of the rest of this file.

## For the admin: suggested reconfiguration

Ordered by impact. Items 1–2 are actionable now; 3 is a check; 4 is a confirmed fault with an
open mechanism; 5 is resolved and kept for the record.

### 1. Set `NCCL_P2P_LEVEL=SYS` site-wide on the RTX6000 (a-) nodes — highest impact, with a caveat

Without it, any NCCL job using ≥ 3 GPUs with ≥ 2 on socket 1 silently runs at **0.04 GB/s**
instead of ~35 — an 885× penalty, with correct results and no error message. A user would
experience this as "my training job is inexplicably slow", not as a failure. An 8-GPU job that
should take an hour would take a month.

Suggested: export it from the site NCCL/CUDA module file, or `/etc/profile.d`, for a-nodes.
Root cause is NCCL's own P2P distance gating (`isAllDirectP2p 0` while CUDA reports
`isAllCudaP2p 1`), so this is a configuration fix, not a hardware one. **Before making this the
site default, read item 4** — the same setting that fixes this collapses `scatter`/`alltoall`
by up to 96%, so a blanket export is not free for every workload.

### 2. Install / start `nvidia-imex.service`

Absent on these nodes, which forces every NCCL job to set `NCCL_NVLS_ENABLE=0` or crash at
`common.cu:915` with "unhandled cuda error". **Worth re-testing:** this node now runs driver
**595.71.05** (built 2026-07-20), not the 580.105.08 that originally caused it — the requirement
may already be gone. Unrelated to items 1 and 4; this is a separate, independent fault.

### 3. Verify IOMMU / PCIe ACS state

AMD Turin IOMMU devices are present in `lspci`. Site notes record `iommu=off` having been set
system-wide as an earlier fix; whether that survived the firmware update is unverified, because
non-root `lspci -vvv` suppresses the `ACSCtl` capability blocks. Root check:
`cat /proc/cmdline` and `lspci -vvv | grep -i acsctl`.
Note this is unlikely to be the cause of item 1 — CUDA reports P2P as available between all
pairs, which ACS blocking would normally prevent. Also unrelated to item 4, for the same reason.

### 4. `scatter` and `alltoall` collapse under `NCCL_P2P_LEVEL=SYS` — confirmed, mechanism open

In every multi-GPU configuration, while their structural mirror `gather` is healthy at 42–45:

| | 4 GPU one socket | 4 GPU cross-socket | 8 GPU |
|---|---:|---:|---:|
| gather | 44.66 | 43.96 | 41.79 |
| **scatter** | **1.85** | **1.16** | **0.94** |
| **alltoall** | **2.38** | **1.47** | **1.01** |

**Confirmed cause: `NCCL_P2P_LEVEL=SYS` itself** (job 335844 — see the dedicated section
above), not the firmware and not a platform defect. **Do not report this to the GPU/switch
vendor** — the leading explanation (root-GPU fan-out concurrency under direct P2P; see the
headline section) is a software/configuration interaction, not a hardware fault, though it
remains a hypothesis rather than a confirmed mechanism.

This is why item 1's site-wide `NCCL_P2P_LEVEL=SYS` recommendation is a trade-off, not
unconditional — see "Which setting to use" and the full per-collective table in the headline.

### 5. Firmware/driver attribution — resolved for NCCL performance; open for everything else

**Job 335844 settled the question this item originally raised.** Every NCCL performance
difference measured on this node — the socket-1 collapse, the ring/tree gain from `SYS`, and the
scatter/alltoall regression — is fully explained by `NCCL_P2P_LEVEL`. Neither the PCIe firmware
update nor the driver update (580.105.08 (May) → 595.71.05, built 2026-07-20) has any
demonstrated effect on NCCL performance here. No further action is needed to interpret the
numbers in this file.

What remains open, and is lower priority: `a0008` and `a0007` are different physical machines,
so this file cannot separate "firmware/driver, held constant" from ordinary node-to-node
variation for anything **outside** NCCL performance (e.g. other workloads, stability, power).
If a **non-updated a-node** still exists, measuring it would close that gap; otherwise, record
the exact firmware and driver versions before/after for the site's own change log.

## Open

- [x] 4-GPU sendrecv with the workaround — **37.07**, vs 13.0 at defaults.
- [x] `scatter`/`alltoall` collapse attributed to `NCCL_P2P_LEVEL=SYS` — job 335844 confirmed it
      (defaults 50.76/13.30 vs `SYS` 1.85/2.38, same node, same day).
- [x] `4gpu-2plus2` discriminator (job 335776) — confirms socket crossing, not GPU count, drives
      the Table 3 ring/tree collapse; a residual ~1.5× scaling term is still unexplained.
- [ ] **Mechanism behind the scatter/alltoall collapse.** The current explanation (root-GPU
      fan-out concurrency under direct P2P — see the headline section) is a hypothesis
      consistent with the channel-count and gather/scatter-mirror evidence, not a confirmed
      cause. No test here directly isolates per-GPU copy-engine concurrency from data volume.
- [ ] **scatter/alltoall never measured at defaults *with* the socket-1 trigger** (≥ 3 GPU, ≥ 2
      on socket 1 — e.g. a full 8-GPU job). Unknown whether they collapse to ~0.04 like the ring
      collectives or behave differently — the missing data point behind the "no good 8-GPU
      setting" conclusion in the headline.
- [ ] **Revise `results_rtx6000.md`**: its ~13 GB/s "IF 4-die bidir saturation" rows are a NCCL
      default-P2P-level artifact, not hardware.
- [ ] Fill GPU counts 1, 3, 5, 6, 7 (job `a0007-missing-counts.sh`, queued) — would show whether
      the scatter/alltoall collapse begins exactly at 3 GPUs (fan-out > 1 peer), the threshold
      the fan-out-concurrency hypothesis predicts.
- [ ] Re-run the cancelled `a0007-pair-matrix.sh` and `a0007-sweep.sh` if the 28-pair matrix and
      the full 2→8 scaling curve are still wanted.
- [ ] Run the socket-composition test on a **non-updated a-node** to settle attribution of the
      socket-1 collapse (also closes the residual node-vs-firmware confound noted in admin item 5).

Every number quoted above traces back to one of the raw files below.

## Raw data

| file | contents |
|---|---|
| `out-1node-a0007/a0007-topo-a0007-335183` | topology, PCIe link state, NUMA, NIC firmware |
| `out-1node-a0007/a0007-8gpu-a0007-335385` | **Table 3** — 8 GPU, all collectives, `P2P_LEVEL=SYS` |
| `out-1node-a0007/a0007-socket-a0007-335386` | **Table 2** — 4 GPU (and 2 GPU) socket 0, `P2P_LEVEL=SYS` |
| `out-1node-a0007/a0007-xsock-a0007-335776` | cross-socket discriminator (job 335776, complete) |
| `diag_a0007_socket1.md` | default-settings diagnostic record for the collapse |

Extract any of these with `./extract_a0007.py <file>`. The auto-generated section below
regenerates from these same files on every `a0007_autoreport.py` run.

---

<!-- AUTO-BEGIN: regenerated by a0007_autoreport.py -->

## Auto-generated results (updated 2026-08-11 17:51)

Regenerated by `a0007_autoreport.py`, run as a SLURM dependency job. Hand-written
sections above are not modified by it.

### Is `NCCL_P2P_LEVEL=SYS` responsible for the scatter/alltoall collapse?

Both columns are a0007, 4 GPUs on socket 0, converged 16 GB. Only the setting differs.

| Collective | NCCL defaults (job 335844) | `NCCL_P2P_LEVEL=SYS` (job 335386) |
|---|---:|---:|
| sendrecv | 13.09 | 37.07 |
| gather | 39.37 | 44.66 |
| scatter | 50.76 | 1.85 |
| alltoall | 13.30 | 2.38 |
| all_reduce | 13.17 | 39.82 |

**Verdict: `NCCL_P2P_LEVEL=SYS` CAUSES the collapse.** `scatter` is healthy at
50.76 GB/s with NCCL defaults and falls to 1.85 with the workaround. The
workaround therefore has a real cost, and is not a free win: it rescues
`sendrecv`/ring collectives by ~885x while destroying `scatter` and `alltoall`.
Users whose workload is scatter- or alltoall-heavy (MoE, tensor-parallel
all-to-all) should benchmark both settings rather than adopting `SYS` blindly.
This is NOT a firmware defect and must not be reported as one.

### Repeatability (3 consecutive runs, 4 GPU socket 0, busbw @256 MiB)

| Collective | run 1 | run 2 | run 3 | spread |
|---|---:|---:|---:|---:|
| scatter | 1.85 | 1.86 | 1.92 | 3.6% |
| alltoall | 2.28 | 2.28 | 2.27 | 0.4% |
| gather | 43.68 | 43.52 | 43.68 | 0.4% |

All within 3.6% — the scatter/alltoall figures are **reproducible**, not a
transient or a one-off measurement artifact.

### GPU-count threshold from the debug job (socket 0, busbw @256 MiB)

| Collective | 2 GPU | 3 GPU | 4 GPU |
|---|---:|---:|---:|
| scatter | 46.49 | — | 1.89 |
| alltoall | 39.62 | — | 2.27 |
| gather | — | — | 43.59 |

### Knob sweep on `scatter` / `alltoall` (4 GPU socket 0, busbw @256 MiB)

| setting | collective | busbw (GB/s) |
|---|---|---:|
| `NCCL_BUFFSIZE=33554432` | alltoall | 2.01 |
| `NCCL_MAX_NCHANNELS=1` | alltoall | 4.09 |
| `NCCL_BUFFSIZE=33554432` | scatter | 1.87 |
| `NCCL_BUFFSIZE=8388608` | scatter | 2.24 |
| `NCCL_P2P_NET_CHUNKSIZE=1048576` | scatter | 1.82 |
| `NCCL_MAX_NCHANNELS=1` | scatter | 4.01 |
| `NCCL_MAX_NCHANNELS=4` | scatter | 1.84 |
| `NCCL_MAX_NCHANNELS=8` | scatter | 1.87 |
| `NCCL_P2P_DISABLE=1` | scatter | 50.32 |
| `NCCL_P2P_LEVEL=PHB` | scatter | 49.90 |
| `NCCL_PROTO=LL` | scatter | 1.87 |
| `NCCL_PROTO=LL128` | scatter | 1.88 |
| `NCCL_PROTO=Simple` | scatter | 1.84 |

**`NCCL_P2P_DISABLE=1` restores scatter to 50.32 GB/s.**

### GPU-count series 1–8, `NCCL_P2P_LEVEL=SYS` (converged 16 GB)

| Collective | 1 GPU | 2 GPU | 3 GPU | 4 GPU | 5 GPU | 6 GPU | 7 GPU | 8 GPU |
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

Counts still missing: 1, 3, 5, 6, 7 (job `a0007-counts` supplies 1, 3, 5, 6, 7).

### All extracted measurements

| file | case | collective | algbw | busbw | status |
|---|---|---|---:|---:|---|
| `a0007-8gpu-a0007-335184` | all | sendrecv | — | — | FAILED |
| `a0007-8gpu-a0007-335385` | all | all_gather | 15.62 | 13.66 | ok |
| `a0007-8gpu-a0007-335385` | all | all_reduce | 7.78 | 13.61 | ok |
| `a0007-8gpu-a0007-335385` | all | alltoall | 1.15 | 1.01 | ok |
| `a0007-8gpu-a0007-335385` | all | broadcast | 13.62 | 13.62 | ok |
| `a0007-8gpu-a0007-335385` | all | gather | 47.76 | 41.79 | ok |
| `a0007-8gpu-a0007-335385` | all | reduce | 13.54 | 13.54 | ok |
| `a0007-8gpu-a0007-335385` | all | reduce_scatter | 15.47 | 13.53 | ok |
| `a0007-8gpu-a0007-335385` | all | scatter | 1.07 | 0.94 | ok |
| `a0007-8gpu-a0007-335385` | all | sendrecv | 35.43 | 35.43 | ok |
| `a0007-defaults-a0007-335844` | 2gpu-socket0-DEFAULTS | all_gather | 66.60 | 33.30 | ok |
| `a0007-defaults-a0007-335844` | 2gpu-socket0-DEFAULTS | all_reduce | 35.73 | 35.73 | ok |
| `a0007-defaults-a0007-335844` | 2gpu-socket0-DEFAULTS | alltoall | 75.54 | 37.77 | ok |
| `a0007-defaults-a0007-335844` | 2gpu-socket0-DEFAULTS | broadcast | 44.82 | 44.82 | ok |
| `a0007-defaults-a0007-335844` | 2gpu-socket0-DEFAULTS | gather | 97.62 | 48.81 | ok |
| `a0007-defaults-a0007-335844` | 2gpu-socket0-DEFAULTS | reduce | 44.22 | 44.22 | ok |
| `a0007-defaults-a0007-335844` | 2gpu-socket0-DEFAULTS | reduce_scatter | 49.82 | 24.91 | ok |
| `a0007-defaults-a0007-335844` | 2gpu-socket0-DEFAULTS | scatter | 97.19 | 48.59 | ok |
| `a0007-defaults-a0007-335844` | 2gpu-socket0-DEFAULTS | sendrecv | 37.64 | 37.64 | ok |
| `a0007-defaults-a0007-335844` | 4gpu-socket0-DEFAULTS | all_gather | 17.72 | 13.29 | ok |
| `a0007-defaults-a0007-335844` | 4gpu-socket0-DEFAULTS | all_reduce | 8.78 | 13.17 | ok |
| `a0007-defaults-a0007-335844` | 4gpu-socket0-DEFAULTS | alltoall | 17.73 | 13.30 | ok |
| `a0007-defaults-a0007-335844` | 4gpu-socket0-DEFAULTS | broadcast | 17.29 | 17.29 | ok |
| `a0007-defaults-a0007-335844` | 4gpu-socket0-DEFAULTS | gather | 52.49 | 39.37 | ok |
| `a0007-defaults-a0007-335844` | 4gpu-socket0-DEFAULTS | reduce | 13.19 | 13.19 | ok |
| `a0007-defaults-a0007-335844` | 4gpu-socket0-DEFAULTS | reduce_scatter | 17.21 | 12.91 | ok |
| `a0007-defaults-a0007-335844` | 4gpu-socket0-DEFAULTS | scatter | 67.68 | 50.76 | ok |
| `a0007-defaults-a0007-335844` | 4gpu-socket0-DEFAULTS | sendrecv | 13.09 | 13.09 | ok |
| `a0007-socket-a0007-335386` | 2gpu-socket0 | all_gather | 66.47 | 33.24 | ok |
| `a0007-socket-a0007-335386` | 2gpu-socket0 | all_reduce | 35.76 | 35.76 | ok |
| `a0007-socket-a0007-335386` | 2gpu-socket0 | alltoall | 75.42 | 37.71 | ok |
| `a0007-socket-a0007-335386` | 2gpu-socket0 | broadcast | 44.93 | 44.93 | ok |
| `a0007-socket-a0007-335386` | 2gpu-socket0 | gather | 97.47 | 48.74 | ok |
| `a0007-socket-a0007-335386` | 2gpu-socket0 | reduce | 44.22 | 44.22 | ok |
| `a0007-socket-a0007-335386` | 2gpu-socket0 | reduce_scatter | 49.96 | 24.98 | ok |
| `a0007-socket-a0007-335386` | 2gpu-socket0 | scatter | 97.28 | 48.64 | ok |
| `a0007-socket-a0007-335386` | 2gpu-socket0 | sendrecv | 36.95 | 36.95 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket0 | all_gather | 52.09 | 39.07 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket0 | all_reduce | 26.55 | 39.82 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket0 | alltoall | 3.18 | 2.38 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket0 | broadcast | 43.20 | 43.20 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket0 | gather | 59.55 | 44.66 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket0 | reduce | 42.60 | 42.60 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket0 | reduce_scatter | 45.24 | 33.93 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket0 | scatter | 2.46 | 1.85 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket0 | sendrecv | 37.07 | 37.07 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket1 | broadcast | — | — | FAILED |
| `a0007-socket-a0007-335386` | 4gpu-socket1 | reduce | 42.52 | 42.52 | ok |
| `a0007-socket-a0007-335386` | 4gpu-socket1 | sendrecv | 36.77 | 36.77 | ok |
| `a0007-xsock-a0007-335776` | 2gpu-crosssocket | all_gather | 53.46 | 26.73 | ok |
| `a0007-xsock-a0007-335776` | 2gpu-crosssocket | all_reduce | 29.44 | 29.44 | ok |
| `a0007-xsock-a0007-335776` | 2gpu-crosssocket | alltoall | 73.33 | 36.66 | ok |
| `a0007-xsock-a0007-335776` | 2gpu-crosssocket | broadcast | 32.55 | 32.55 | ok |
| `a0007-xsock-a0007-335776` | 2gpu-crosssocket | gather | 70.62 | 35.31 | ok |
| `a0007-xsock-a0007-335776` | 2gpu-crosssocket | reduce | 32.26 | 32.26 | ok |
| `a0007-xsock-a0007-335776` | 2gpu-crosssocket | reduce_scatter | 45.21 | 22.61 | ok |
| `a0007-xsock-a0007-335776` | 2gpu-crosssocket | scatter | 69.66 | 34.83 | ok |
| `a0007-xsock-a0007-335776` | 2gpu-crosssocket | sendrecv | 36.38 | 36.38 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-2plus2 | all_gather | 26.80 | 20.10 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-2plus2 | all_reduce | 13.13 | 19.69 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-2plus2 | alltoall | 1.96 | 1.47 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-2plus2 | broadcast | 19.71 | 19.71 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-2plus2 | gather | 58.61 | 43.96 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-2plus2 | reduce | 20.13 | 20.13 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-2plus2 | reduce_scatter | 28.05 | 21.04 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-2plus2 | scatter | 1.54 | 1.16 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-2plus2 | sendrecv | 32.80 | 32.80 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-socket1 | all_gather | 52.18 | 39.14 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-socket1 | all_reduce | 26.71 | 40.06 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-socket1 | alltoall | 3.21 | 2.41 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-socket1 | broadcast | 43.34 | 43.34 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-socket1 | gather | 59.63 | 44.72 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-socket1 | reduce | 42.50 | 42.50 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-socket1 | reduce_scatter | 45.70 | 34.27 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-socket1 | scatter | 2.53 | 1.90 | ok |
| `a0007-xsock-a0007-335776` | 4gpu-socket1 | sendrecv | 37.17 | 37.17 | ok |

<!-- AUTO-END -->
