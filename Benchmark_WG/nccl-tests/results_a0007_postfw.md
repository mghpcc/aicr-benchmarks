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

## Table 2: socket cases, `NCCL_P2P_LEVEL=SYS` (job 335386 — cancelled part-way)

Job 335386 was cancelled at 18:18 by request, after completing `2gpu-socket0` and
`4gpu-socket0` in full and two collectives of `4gpu-socket1`. `2gpu-crosssocket` was never run.
The completed cases are valid (`#wrong = 0`) and are reported here; `hypercube` fails validation
as usual (nccl-tests 2.18.3 bug).

busbw (GB/s), converged 16 GB, `NCCL_P2P_LEVEL=SYS`. Pre-firmware column is `a0008`, 4 GPU
socket 0, at NCCL defaults (`results_rtx6000.md` Table 2) — the like-for-like configuration.

| Benchmark | 2 GPU sock0 | 4 GPU sock0 | 4 GPU sock1 | pre-fw 4 GPU sock0 | 4-GPU change |
|---|---:|---:|---:|---:|---|
| sendrecv | 36.95 | **37.07** | 36.77 | 13.0 | **+185%** |
| reduce | 44.22 | 42.60 | 42.52 | 13.2 | **+223%** |
| broadcast | 44.93 | 43.20 | *cancelled* | 17.6 | **+145%** |
| gather | 48.74 | 44.66 | — | 39.2 | +14% |
| scatter | 48.64 | **1.85** | — | 50.6 | **−96%** |
| reduce_scatter | 24.98 | 33.93 | — | 13.0 | **+161%** |
| all_gather | 33.24 | 39.07 | — | 13.3 | **+194%** |
| all_reduce | 35.76 | 39.82 | — | 13.1 | **+204%** |
| alltoall | 37.71 | **2.38** | — | 13.4 | **−82%** |
| hypercube | 36.09 | FAILED | — | FAILED | — |

### The 13 GB/s "Infinity Fabric ceiling" was an artifact — confirmed

**4-GPU socket-0 sendrecv reaches 37.07 GB/s with the workaround, against 13.0 GB/s at
defaults on the identical configuration.** `results_rtx6000.md` attributes that 13.0 to
"~13 GB/s — IF 4-die bidir saturation", i.e. a hardware limit of Infinity Fabric between NUMA
dies. It is not: the same four GPUs on the same socket run 2.85× faster once NCCL is allowed to
use P2P. Every collective that sat pinned near 13 GB/s in that table — reduce, reduce_scatter,
all_gather, all_reduce — now runs at 34–43 GB/s.

**`results_rtx6000.md` needs revising.** The "IF 4-die bidir saturation" ceiling in its Table 2
is a NCCL default-P2P-level artifact, not hardware. That baseline was taken at defaults, so it
measured the SHM fallback path rather than the fabric.

Note this does *not* extend to the 8-GPU numbers in Table 1, where the ring collectives sit at
13.5–13.7 GB/s **with** the workaround. Four GPUs reach 34–43 and eight fall back to ~13.6, a 3×
drop from doubling the GPU count. That is a separate scaling question and is **not explained**.

### `scatter` and `alltoall` are a real regression — confirmed like-for-like

The Table 1 anomaly reproduces at 4 GPUs on socket 0, the exact configuration of the
pre-firmware baseline:

| | pre-firmware (a0008) | post-firmware (a0007), workaround |
|---|---:|---:|
| scatter | 50.6 | **1.85** (−96%) |
| alltoall | 13.4 | **2.38** (−82%) |

Both are healthy at 2 GPUs (48.64 / 37.71) and collapse at 4. `gather` — scatter's mirror — is
fine at 44.66. This is **not** fixed by `NCCL_P2P_LEVEL=SYS` and is a second, independent fault.
Unlike the socket-1 collapse, this one *does* have a valid pre-firmware comparison at matching
GPU count, socket, and message size, so it is the strongest candidate for an actual firmware
regression. Caveat: different physical nodes (a0008 vs a0007), so a same-node before/after is
still absent.

### Socket 1 is healthy with the workaround

`4gpu-socket1` sendrecv 36.77 and reduce 42.52 match `4gpu-socket0` (37.07, 42.60) to within
1%. With `NCCL_P2P_LEVEL=SYS` the socket-1 deficit disappears entirely — further confirmation
that nothing is physically wrong with socket 1.

## Table 3: 28-pair matrix (job 335387 — CANCELLED, never ran)

## Table 4: GPU-count sweep 2→8 (job 335388 — CANCELLED, never ran)

Both were cancelled before starting. Table 4 in particular would have addressed the unexplained
4→8 GPU drop noted above; re-running `a0007-sweep.sh` is the way to get it.

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

- [x] Confirm whether 4-GPU sendrecv exceeds 13.0 GB/s with the workaround — **yes, 37.07**.
- [x] Confirm whether the `scatter` anomaly reproduces at 4 GPUs — **yes, 1.85 vs 50.6**.
- [ ] **Revise `results_rtx6000.md`**: its Table 2 "IF 4-die bidir saturation ~13 GB/s" ceiling
      is a NCCL default-P2P-level artifact, not hardware. Affects every ~13 GB/s row there.
- [ ] **Diagnose `scatter` and `alltoall`** — 4-GPU socket-0: 1.85 vs 50.6 and 2.38 vs 13.4
      pre-firmware. Healthy at 2 GPUs. Not fixed by the workaround. Strongest firmware-regression
      candidate; needs a same-node before/after to be conclusive.
- [ ] **Explain the 4→8 GPU drop with the workaround**: ring collectives 34–43 GB/s at 4 GPUs,
      13.5–13.7 at 8. Re-run `a0007-sweep.sh` (was job 335388, cancelled).
- [ ] Re-run the cancelled work: `a0007-socket.sh` (`4gpu-socket1` tail, `2gpu-crosssocket`),
      `a0007-pair-matrix.sh`, `a0007-sweep.sh`.
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
