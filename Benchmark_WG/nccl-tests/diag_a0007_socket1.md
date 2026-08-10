# a0007 — diagnostic record for the socket-1 multi-GPU collapse (2026-08-10)

Supporting evidence for the headline finding in `results_a0007_postfw.md`. **Everything here is
at NCCL defaults (`NCCL_P2P_LEVEL` unset)** — that is the point: these runs characterise the
fault. The benchmark results in `results_a0007_postfw.md` are all taken *with*
`NCCL_P2P_LEVEL=SYS` and are kept separate from this file.

All values: `sendrecv` busbw at 16 MiB, 5 iters (diagnostic size, not converged).
Socket 0 = GPUs 0–3 (PCIe domain `0000:`), socket 1 = GPUs 4–7 (domain `0001:`).

## The rule

**Collapse iff the group has ≥ 3 GPUs total AND ≥ 2 GPUs on socket 1.**

| case | devices | split | busbw (GB/s) | |
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
| 6 GPU | 0..5 | 4+2 | **0.20** | collapsed |
| 7 GPU | 0..6 | 4+3 | **0.06** | collapsed |
| 8 GPU | 0..7 | 4+4 | **0.04** | collapsed |

An earlier reading of this as a GPU-count threshold between 5 and 6 was **wrong**; that was an
artifact of enumerating devices `0..N-1`, which admits the second socket-1 GPU exactly at N=6.
Two-GPU groups are exempt regardless of socket.

## All 12 pairs tested are uniformly healthy

| socket 0 | 0-1 | 0-2 | 0-3 | 1-2 | 1-3 | 2-3 |
|---|---:|---:|---:|---:|---:|---:|
| busbw | 39.68 | 39.43 | 39.72 | 39.27 | 39.91 | 39.94 |

| socket 1 | 4-5 | 4-6 | 4-7 | 5-6 | 5-7 | 6-7 |
|---|---:|---:|---:|---:|---:|---:|
| busbw | 40.38 | 39.61 | 39.25 | 39.90 | 39.74 | 39.46 |

No individual GPU, link, or switch port on socket 1 is degraded.

## Leave-one-out (7 GPUs, dropping each in turn)

| dropped | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| busbw | 0.04 | 0.04 | 0.04 | 0.04 | 0.06 | 0.07 | 0.06 | 0.06 |

All collapsed — consistent with the rule, since every 7-GPU subset retains ≥ 2 socket-1 GPUs.

## Knob sweep at 8 GPUs

| knob | busbw (GB/s) |
|---|---:|
| *(default)* | 0.04 |
| **`NCCL_P2P_LEVEL=SYS`** | **32.66** |
| `NCCL_SHM_DISABLE=1` | 0.09 |
| `NCCL_P2P_DISABLE=1` | 0.04 |
| `NCCL_P2P_LEVEL=0` | 0.04 |
| `NCCL_ALGO=Ring` | 0.04 |
| `NCCL_MAX_NCHANNELS=1` | 0.04 |

`NCCL_P2P_DISABLE=1` is also 0.04, so the non-P2P fallback path is itself the broken thing —
this is not simply "P2P is off".

## Ruled out

- **Bad PCIe links.** Under load all 8 GPUs train to Gen5 x16. The Gen1 readings in the topo
  job are ASPM idle downtraining, sampled while idle.
- **P2P capability.** `nvidia-smi topo -p2p rw` reports `OK` for all 28 pairs.
- **Lost write-combining on peer BAR mappings.** 2-GPU P2P is the fastest configuration on the
  node (39.4 GB/s) and disabling P2P there halves it (21.6) — the peer path is live.
- **A single faulty GPU / link / switch port.** See leave-one-out and the pair tables.
- **A pure GPU-count effect.** Falsified: 3- and 4-GPU groups collapse when ≥ 2 are on socket 1.

## Mechanism (confirmed) and root cause (open)

`NCCL_DEBUG=INFO` establishes *what* happens:

| run | `Check P2P Type` | transport used | busbw |
|---|---|---|---:|
| 2 GPU, defaults | `isAllDirectP2p 1` | `P2P/direct pointer` | 39.4 |
| 8 GPU, defaults | `isAllDirectP2p 0` | `SHM/direct/direct` (all 16 connections) | 0.04 |

Both report `isAllCudaP2p 1` — CUDA confirms P2P is possible between all pairs. NCCL's own
distance gating declines it at 8 GPUs and falls back to staging every transfer through host
shared memory. `NCCL_P2P_LEVEL=SYS` raises the permitted distance to the maximum so all pairs
(all of which are `SYS` distance) qualify, and the SHM fallback is never selected.

Still open — *why* the default gating misjudges this node:

1. Why `isAllDirectP2p` is `0` for groups with ≥ 2 socket-1 GPUs but `1` for 2-GPU groups at
   the same `SYS` distance.
2. Why the SHM path runs at 0.04 GB/s, far below normal host-staging throughput.

Socket 1 sits in PCIe domain `0001:`, socket 0 in `0000:`. NCCL's topology detection may
mishandle the non-zero domain ID when building the P2P graph — this would explain the socket
specificity and the ≥ 2-rank requirement, but it is **not confirmed**. Settling it needs a
comparison against a non-updated a-node.

**Attribution is open.** There is no pre-firmware 8-GPU reference — the old run
(`out-2socket/nvhpc-26.3-a0001-27180`) crashed at `common.cu:915` with the driver-580/IMEX error
and produced no numbers. The collapse may predate the firmware update.

## Source files

`out-1node-a0007/a0007-diag-a0007-335360`, `a0007-diag2-a0007-335364`,
`a0007-diag3-a0007-335379`, and the cancelled `a0007-8gpu-a0007-335184`.
Scripts: `a0007-diag.sh`, `a0007-diag2.sh`, `a0007-diag3.sh`.
