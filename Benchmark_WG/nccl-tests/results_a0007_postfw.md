# a0007 NCCL Results — after the PCIe firmware update (2026-08-10)

**Status:** Tables 1–3 are complete. Job 335776 (`a0007-crosssocket.sh`) is running to explain
the 4→8 GPU drop analysed under Table 3; its results will be appended here automatically when it
finishes. The pair-matrix and full sweep jobs were cancelled by request and never ran.

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

| 8-GPU sendrecv, converged 16 GB | busbw (GB/s) |
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

| 8-GPU knob | busbw (GB/s) | verdict |
|---|---:|---|
| **`NCCL_P2P_LEVEL=SYS`** | **32.66** | **fixes it — 800×** |
| `NCCL_SHM_DISABLE=1` | 0.09 | no fix |
| `NCCL_ALGO=Ring` | 0.04 | no fix |
| `NCCL_MAX_NCHANNELS=1` | 0.04 | no fix |
| `NCCL_PROTO=Simple` | 0.04 | no fix |
| `NCCL_P2P_DISABLE=1` | 0.04 | no fix |
| `NCCL_P2P_LEVEL=0` | 0.04 | no fix |
| *(defaults, for reference)* | 0.04 | — |

`sendrecv` busbw at 16 MiB, 5 iters; default environment apart from the single knob named. The
16 MiB size is why `SYS` reads 32.66 here and 35.43 in the converged 16 GB table above.

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

Pre-firmware reference (defaults, i.e. the SHM fallback path): 2 GPU 37.4, 4 GPU 13.0.

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

Converged 16 GB, `NCCL_P2P_LEVEL=SYS`, job 335386. Pre-firmware column is `a0008`, same
configuration, at NCCL defaults (`results_rtx6000.md` Table 2).

| Benchmark | algbw | busbw (GB/s) | % of 63 | pre-fw busbw | change | Traffic pattern / ceiling |
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

Table 2's pre-firmware column is the direct evidence. `results_rtx6000.md` Table 2 explains its
~13 GB/s rows as "IF 4-die bidir saturation" — a hardware limit of Infinity Fabric between NUMA
dies. On the identical configuration (4 GPUs, one socket, converged 16 GB) with P2P enabled:

| | pre-fw, defaults | post-fw, `P2P_LEVEL=SYS` |
|---|---:|---:|
| sendrecv | 13.0 | 37.07 |
| reduce | 13.2 | 42.60 |
| reduce_scatter | 13.0 | 33.93 |
| all_gather | 13.3 | 39.07 |
| all_reduce | 13.1 | 39.82 |

Every row that sat at ~13 now runs 2.6–3.2× faster. A hardware fabric ceiling does not lift
because an environment variable changed. **That baseline was measuring NCCL's SHM fallback, not
Infinity Fabric** — the same fallback documented in the headline section. `results_rtx6000.md`
needs revising for every ~13 GB/s row in its RTX6000 tables.

Note the number 13 appears again in Table 3 at 8 GPUs *with* P2P enabled. That is a genuine
measurement of something real, and the coincidence with the old artifact value is exactly that —
a coincidence. The two must not be conflated.

## `scatter` and `alltoall`: a real regression, confirmed like-for-like

| | pre-firmware (a0008) | post-firmware (a0007), workaround |
|---|---:|---:|
| scatter | 50.6 | **1.85** (−96%) |
| alltoall | 13.4 | **2.38** (−82%) |

Both are healthy at 2 GPUs (48.64 and 37.71) and collapse from 4 GPUs upward. `NCCL_P2P_LEVEL=SYS`
does not help, so this is independent of the socket-1 collapse. Unlike that collapse, this one has
a valid pre-firmware comparison at matching GPU count, socket, and message size, making it the
strongest candidate for an actual firmware regression.

**It is not diagnosed.** The `gather`/`scatter` asymmetry — 44.66 versus 1.85 on the same links
with the same root — rules out a bandwidth explanation, but nothing yet identifies the cause.
Caveat: a0008 and a0007 are different physical nodes, so a same-node before/after is still absent.

## What the firmware update did change

| Config | post-firmware | pre-firmware baseline |
|---|---:|---:|
| 2 GPU, socket 0 | 39.4 | 37.4 (a0001, converged 16 GB) |
| 2 GPU, cross-socket (0,4) | 36.6 | — |
| 4 GPU, socket 0 | 13.0 | 13.0 (a0008, converged 16 GB) |

The post-firmware values in this table are at 16 MiB / 5 iters and at NCCL defaults; the
baselines are converged 16 GB. They are indicative, not strictly comparable — Tables 2–4 will
replace them with converged, workaround-enabled numbers.

1. **Cross-socket 2-GPU (36.6) is essentially equal to same-socket (39.4–40.4), and all 12
   pairs measured are uniform at ~39.5.** The prior RTX6000 record has cross-NUMA traffic
   collapsing; that penalty is absent at the pair level here. This is the most promising
   candidate for a genuine firmware improvement, pending the converged pair matrix.
2. **4-GPU is unchanged at 13.0 GB/s at defaults.** The firmware did not lift that ceiling —
   though as discussed above, with the workaround the sendrecv ceiling is no longer 13.0 at all.

**No pre-firmware 8-GPU reference exists.** The old 8-GPU run
(`out-2socket/nvhpc-26.3-a0001-27180`) crashed at `common.cu:915` with the driver-580/IMEX error
and produced no numbers. So neither the socket-1 collapse nor the scatter/alltoall anomaly can
currently be attributed to the firmware update — both may predate it. Establishing that requires
running the same tests on an a-node that has *not* been updated.

---

## Open

- [x] 4-GPU sendrecv with the workaround — **37.07**, vs 13.0 at defaults.
- [x] `scatter` anomaly reproduces at 4 GPUs — **1.85** vs 50.6 pre-firmware.
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
