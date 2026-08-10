# a0007 NCCL Results — after the PCIe firmware update (2026-08-10)

**Status: INTERIM.** The 8-GPU suite is complete; the socket, pair-matrix and sweep jobs are
still queued. This file will be extended as they land.

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
degraded. `NCCL_P2P_LEVEL=SYS` is the *only* knob that recovers it — `P2P_DISABLE`,
`SHM_DISABLE`, `ALGO=Ring`, `MAX_NCHANNELS=1` and `P2P_LEVEL=0` all stay at 0.04–0.09.

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

This also explains the knob sweep: `NCCL_P2P_DISABLE=1` (0.04) forces that same SHM path, and
`NCCL_SHM_DISABLE=1` (0.09) merely pushes it onto another slow fallback. Only raising the P2P
level avoids the fallback altogether.

Two things remain **unexplained** and are not claimed here: why NCCL's default gating yields
`isAllDirectP2p 0` for groups with ≥ 2 socket-1 GPUs but `1` for 2-GPU groups at the same `SYS`
distance; and why the SHM path itself runs at 0.04 GB/s, which is far slower than normal host
staging should be. The workaround is verified; the reason the default misjudges this node is not.

Full evidence — the composition table, pair matrix, leave-one-out, knob sweep, what was ruled
out, and the PCIe-domain hypothesis — is in **`diag_a0007_socket1.md`**.

---

## Table 1: 1-Node a0007, 8 GPUs, `NCCL_P2P_LEVEL=SYS` (job 335385)

`PCIe link spec` = 63 GB/s (Gen5 x16 per GPU per direction). `Effective ceiling` = the actual
binding constraint for that row.

| Benchmark | algbw (GB/s) | busbw (GB/s) | PCIe link spec | % of link spec | Effective ceiling |
|---|---:|---:|---:|---:|---|
| sendrecv | 35.43 | **35.43** | 63 | 56% | ~35 GB/s — PCIe DMA bidir budget |
| reduce | 13.54 | 13.54 | 63 | 21% | ~13.6 GB/s — IF bidir (tree) |
| broadcast | 13.62 | 13.62 | 63 | 22% | ~13.6 GB/s — IF bidir (tree) |
| gather | 47.76 | 41.79 | 63 | 66% | root-anchored unidir |
| scatter | 1.07 | **0.94** | 63 | 1.5% | **anomaly — undiagnosed** |
| reduce_scatter | 15.47 | 13.53 | 63 | 21% | ~13.6 GB/s — IF bidir (ring) |
| all_gather | 15.62 | 13.66 | 63 | 22% | ~13.6 GB/s — IF bidir (ring) |
| all_reduce | 7.78 | 13.61 | 63 | 22% | ~13.6 GB/s — IF bidir (RS+AG) |
| alltoall | 1.15 | **1.01** | 63 | 1.6% | **anomaly — undiagnosed** |
| hypercube | 2.81 | 2.81 | — | — | **FAILED** — validation, `#wrong`≠0 |

### Discussion

**sendrecv reaches 35.4 GB/s** — the highest bidirectional figure recorded on RTX6000 hardware
in this project, and 2.7× the 13.0 GB/s that `results_rtx6000.md` reports for 4 GPUs. Since that
figure was obtained on *fewer* GPUs within a *single* socket, and is exceeded here by a group
spanning *both* sockets, the "Infinity Fabric 4-die bidir saturation" explanation given for the
RTX6000 sendrecv rows does not survive: it looks like an artifact of NCCL's default P2P level,
not fabric saturation. The queued 4-GPU-with-workaround run (job 335386) tests this directly.

**The ring/tree collectives sit at a consistent ~13.5–13.7 GB/s** (reduce, broadcast,
reduce_scatter, all_gather, all_reduce) *even with the workaround*. That flatness across five
different algorithms is the signature of a real shared-fabric ceiling, so for these collectives
the IF-saturation reading in `results_rtx6000.md` stands.

**gather (41.8) is healthy**, consistent with root-anchored unidirectional traffic having a
higher ceiling than bidirectional patterns — the same pattern seen pre-firmware.

**`scatter` (0.94) and `alltoall` (1.01) are anomalies and are not diagnosed.** Both sit near
1 GB/s while their structural counterparts are healthy — `gather`, scatter's mirror, is 41.8,
a **44× asymmetry** that ring topology does not explain. Pre-firmware, scatter was the *fastest*
collective on RTX6000 (50.6 busbw, `results_rtx6000.md` Table 2) and alltoall was 13.4. Neither
is fixed by `NCCL_P2P_LEVEL=SYS`. This is a second, independent fault on this node. The 4-GPU
run (job 335386) will give a like-for-like comparison against those baselines; until then no
cause should be assumed.

**hypercube fails validation** (`#wrong` ≠ 0) — the known nccl-tests 2.18.3 bug, unrelated to
this node.

---

## Table 2: socket cases, `NCCL_P2P_LEVEL=SYS` (job 335386 — PENDING)

2 GPU socket 0 / 4 GPU socket 0 / 4 GPU socket 1 / 2 GPU cross-socket, all 10 collectives.
This table settles two open questions: whether 4-GPU sendrecv exceeds 13.0 GB/s with the
workaround, and whether 4-GPU `scatter` reproduces the 0.94 GB/s anomaly against its 50.6
pre-firmware baseline.

## Table 3: 28-pair matrix, `NCCL_P2P_LEVEL=SYS` (job 335387 — PENDING)

## Table 4: GPU-count sweep 2→8, `NCCL_P2P_LEVEL=SYS` (job 335388 — PENDING)

---

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

- [ ] Tables 2–4 (jobs 335386, 335387, 335388).
- [ ] **Diagnose `scatter` 0.94 and `alltoall` 1.01 GB/s** — undiagnosed second fault, not
      fixed by the workaround, against 50.6 / 13.4 pre-firmware baselines.
- [ ] Confirm whether 4-GPU sendrecv exceeds 13.0 GB/s with the workaround; if so, revise the
      IF-saturation reading of the sendrecv rows in `results_rtx6000.md`.
- [ ] Run the socket-composition test on a **non-updated a-node** to settle attribution.
- [ ] `NCCL_DEBUG=INFO` P2P graph at 8 GPUs — test the PCIe-domain hypothesis in
      `diag_a0007_socket1.md`.
- [ ] Compare PCIe switch firmware revisions between socket 0 and socket 1 (needs root).

## Raw data

| file | contents |
|---|---|
| `out-1node-a0007/a0007-topo-a0007-335183` | topology, PCIe link state, NUMA, NIC firmware |
| `out-1node-a0007/a0007-8gpu-a0007-335385` | **Table 1** — 8 GPU with `NCCL_P2P_LEVEL=SYS` |
| `out-1node-a0007/a0007-socket-a0007-335386` | Table 2 (pending) |
| `out-1node-a0007/a0007-pairs-a0007-335387` | Table 3 (pending) |
| `out-1node-a0007/a0007-sweep-a0007-335388` | Table 4 (pending) |
| `diag_a0007_socket1.md` | default-settings diagnostic record for the collapse |
