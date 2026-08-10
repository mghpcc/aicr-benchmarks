# a0007 NCCL Results — after the PCIe firmware update (2026-08-10)

**Status: INTERIM.** The full benchmark suite has *not* completed. The first attempt was
cancelled because the 8-GPU configuration ran ~800× too slow to finish, and the session so far
has been spent isolating that. This file records what is established and what is still open.
It will be revised once the suite is re-run with the workaround below.

**Node:** a0007, reservation `shaohao_a0007` (2026-08-10T11:00 → 2026-08-11T11:00).
**Hardware:** 8× NVIDIA RTX PRO 6000 Blackwell Server Edition, no NVLink, PCIe Gen5 x16 per GPU.
2× AMD EPYC Turin, NPS=4 (8 NUMA dies). GPUs 0–3 on socket 0 (PCIe domain `0000:`),
GPUs 4–7 on socket 1 (domain `0001:`). Broadcom PEX890xx Gen5 switches present.
**Software:** nvhpc/26.3, NCCL 2.29.3 (nccl-library=22903), nccl-tests 2.18.3,
`NCCL_NVLS_ENABLE=0` (driver-580 / no-IMEX workaround — see the driver-580 note).

**Scripts:** `a0007-env.sh`, `a0007-topo.sh`, `a0007-1node-8gpu.sh`, `a0007-socket.sh`,
`a0007-pair-matrix.sh`, `a0007-sweep.sh`, `submit-a0007.sh`, `a0007-diag{,2,3}.sh`,
`extract_a0007.py`. **Outputs:** `out-1node-a0007/`. No pre-existing file was modified.

All numbers below are `sendrecv` busbw at **16 MiB**, 5 iters — the diagnostic message size,
**not** the converged 16 GB point used in `results_rtx6000.md`. They are therefore *not*
directly comparable to the tables in that file except where explicitly noted.

---

## Headline: the socket-1 multi-GPU collapse and its workaround

Default settings, all 8 GPUs: **0.04 GB/s**. With `NCCL_P2P_LEVEL=SYS`: **32.7 GB/s**.

| 8-GPU knob | busbw (GB/s) |
|---|---:|
| *(default)* | 0.04 |
| `NCCL_P2P_LEVEL=SYS` | **32.66** |
| `NCCL_SHM_DISABLE=1` | 0.09 |
| `NCCL_P2P_DISABLE=1` | 0.04 |
| `NCCL_P2P_LEVEL=0` | 0.04 |
| `NCCL_ALGO=Ring` | 0.04 |
| `NCCL_MAX_NCHANNELS=1` | 0.04 |

**Recommended setting for all multi-GPU work on this node: `export NCCL_P2P_LEVEL=SYS`.**

Every GPU pair on this node reports `SYS` distance in `nvidia-smi topo -m` (no pair shares a
PCIe switch). Forcing the P2P level to `SYS` keeps the direct-pointer path in use and restores
throughput. Note that `NCCL_P2P_DISABLE=1` is *also* 0.04, so the non-P2P fallback path is
itself the broken thing — this is not simply "P2P is off".

## The trigger: socket 1, not GPU count

My first reading of this was a GPU-count threshold between 5 and 6. **That was wrong.**
`a0007-diag3.sh` tested socket composition at ≤ 5 GPUs and found collapses well below 6:

| case | devices | socket split | busbw (GB/s) | |
|---|---|---|---:|---|
| 2 GPU, socket 0 | 0,1 | 2+0 | 39.68 | healthy |
| 2 GPU, socket 1 | 4,5 | 0+2 | 39.95 | healthy |
| 2 GPU, cross | 0,4 | 1+1 | 36.61 | healthy |
| 3 GPU | 0,1,4 | 2+1 | 16.18 | healthy |
| 3 GPU | 0,4,5 | 1+2 | **0.18** | collapsed |
| 3 GPU, socket 1 | 4,5,6 | 0+3 | **0.06** | collapsed |
| 4 GPU, socket 0 | 0,1,2,3 | 4+0 | 13.00 | healthy |
| 4 GPU | 0,1,2,4 | 3+1 | 8.67 | healthy |
| 4 GPU | 0,1,4,5 | 2+2 | **0.20** | collapsed |
| 4 GPU, socket 1 | 4,5,6,7 | 0+4 | **0.03** | collapsed |
| 5 GPU | 0,1,2,3,4 | 4+1 | 10.39 | healthy |
| 5 GPU | 0,4,5,6,7 | 1+4 | **0.04** | collapsed |
| 6/7/8 GPU | various | ≥2 on socket 1 | 0.20 / 0.06 / 0.04 | collapsed |

**The rule that fits every observation: collapse iff the group has ≥ 3 GPUs total AND ≥ 2 GPUs
on socket 1.** Socket 0 scales cleanly to 4 GPUs (13.0 GB/s); socket 1 collapses at 3 (0.06).
The earlier 5→6 "threshold" was an artifact of enumerating GPUs in order 0..N-1, which happens
to admit the second socket-1 GPU exactly at N=6.

Two-GPU groups are exempt regardless of socket — including all-socket-1 pairs.

## All 28 pairs are uniformly healthy

Every 2-GPU pair tested runs at ~39.5 GB/s, socket 0 and socket 1 alike:

| socket 0 pairs | 0-1 | 0-2 | 0-3 | 1-2 | 1-3 | 2-3 |
|---|---:|---:|---:|---:|---:|---:|
| busbw (GB/s) | 39.68 | 39.43 | 39.72 | 39.27 | 39.91 | 39.94 |

| socket 1 pairs | 4-5 | 4-6 | 4-7 | 5-6 | 5-7 | 6-7 |
|---|---:|---:|---:|---:|---:|---:|
| busbw (GB/s) | 40.38 | 39.61 | 39.25 | 39.90 | 39.74 | 39.46 |

So no individual GPU, link, or switch port on socket 1 is degraded. The fault appears only when
three or more ranks are formed with two or more of them on socket 1.

## Leave-one-out: no single bad GPU

Seven GPUs, dropping each in turn — all collapsed, consistent with the rule above (every
7-GPU subset still contains ≥ 2 socket-1 GPUs):

| dropped GPU | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| busbw (GB/s) | 0.04 | 0.04 | 0.04 | 0.04 | 0.06 | 0.07 | 0.06 | 0.06 |

## Root-cause hypothesis (unconfirmed)

Socket 1 sits in **PCIe domain `0001:`**, socket 0 in `0000:`. A plausible explanation is that
NCCL's topology detection mishandles the non-zero PCIe domain ID when building the P2P graph,
disabling P2P among socket-1 GPUs and dropping to the pathological fallback. This would explain
why the fault is socket-1-specific, why it needs ≥ 2 socket-1 ranks, and why explicitly setting
`NCCL_P2P_LEVEL=SYS` overrides it. It is a hypothesis — confirming it needs the 8-GPU
`NCCL_DEBUG=INFO` graph output, and a comparison against an a-node that was not updated.

## Ruled out

- **Bad PCIe links.** Under load all 8 GPUs train to **Gen5 x16**. The Gen1 readings in the
  topo job are ASPM idle downtraining, sampled while the GPUs were idle.
- **P2P capability.** `nvidia-smi topo -p2p rw` reports `OK` for all 28 pairs.
- **Lost write-combining on peer BAR mappings.** This was my first hypothesis for a flat
  40 MB/s; it is wrong. 2-GPU P2P is the *fastest* configuration on the node (39.4 GB/s), and
  disabling P2P there halves throughput (21.6), so the peer path is live and beneficial.
- **A single faulty GPU, link, or switch port.** See leave-one-out and the 28-pair table:
  all pairs, including every socket-1 pair, run at ~39.5 GB/s.
- **A pure GPU-count effect.** Falsified by diag3 — 3- and 4-GPU groups collapse when ≥ 2 of
  them are on socket 1.

## What the firmware update did change (2 GPUs, healthy regime)

| Config | post-firmware (16 MiB) | pre-firmware baseline (16 GB, converged) |
|---|---:|---:|
| 2 GPU, socket 0 | 39.4 | 37.4 (a0001) |
| 2 GPU, cross-socket (0,4) | 36.6 | — |
| 4 GPU, socket 0 | 13.0 | 13.0 (a0008) |

Two observations, both provisional because the message sizes differ:

1. **Cross-socket 2-GPU (36.6) is essentially equal to same-socket (39.4–40.4), and all 12
   pairs measured are uniform at ~39.5.** The prior RTX6000 record has cross-NUMA traffic
   collapsing; that penalty is absent at the pair level here. This is the most promising
   candidate for a genuine firmware improvement, pending the converged 16 GB pair matrix.
2. **4-GPU is unchanged at 13.0 GB/s.** The firmware did not lift the Infinity Fabric ceiling
   identified in `results_rtx6000.md`.

**No pre-firmware 8-GPU reference exists.** The old 8-GPU run
(`out-2socket/nvhpc-26.3-a0001-27180`) crashed at `common.cu:915` with the driver-580/IMEX
error and produced no numbers. So the 8-GPU collapse **cannot currently be attributed to the
firmware update** — it may well predate it. Establishing that requires running the same test on
an a-node that has *not* been updated.

## Open / next

- [x] `a0007-diag3.sh` (job 335379): socket composition — **done**, established the socket-1 rule.
- [ ] `NCCL_DEBUG=INFO` at 8 GPUs (in job 335364) — which transport NCCL falls back to, and
      whether the P2P graph treats domain `0001:` differently.
- [ ] **Full suite re-running with `NCCL_P2P_LEVEL=SYS`** — jobs 335385 (8 GPU), 335386 (socket
      cases), 335387 (28-pair matrix), 335388 (2→8 sweep). Converged 16 GB numbers for all 10
      collectives. This is the actual deliverable and is still outstanding.
- [ ] Run the socket-composition test on a **non-updated a-node** to determine whether the
      socket-1 collapse is a firmware regression or pre-existing. Without this the fault
      cannot be attributed to the firmware update either way.
- [ ] Compare PCIe switch firmware revisions between socket 0 and socket 1 (needs root —
      non-root `lspci -vvv` suppresses the capability blocks).

## Raw data

| file | contents |
|---|---|
| `out-1node-a0007/a0007-topo-a0007-335183` | topology, PCIe link state, NUMA, NIC firmware |
| `out-1node-a0007/a0007-8gpu-a0007-335184` | cancelled 8-GPU run showing the 0.04 GB/s wall |
| `out-1node-a0007/a0007-diag-a0007-335360` | 2/4/8 GPU × P2P on/off, link-under-load, `DEBUG=INFO` at 2 GPUs |
| `out-1node-a0007/a0007-diag2-a0007-335364` | count threshold, leave-one-out, knob sweep |
| `out-1node-a0007/a0007-diag3-a0007-335379` | socket-composition tests (queued) |
