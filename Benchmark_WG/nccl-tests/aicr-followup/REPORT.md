# AICR inter-node GDRDMA defect — follow-up after the Engaging counter-test

**Date:** 2026-08-07
**Nodes:** b0029 + b0030 (`b200-devel`), SLURM job 317647
**Inputs:** `aicr-handoff/` (Engaging results), `aicr-handoff/aicr-2node-ib-test.md` (test plan)
**Outputs in this directory:** `RESULTS.md` (auto-generated), `aicr-followup-317647.out` (raw),
`run-aicr-followup.sh`, `analyze-followup.py`

---

## Headline

**The Broadcom PEX890xx PCIe switch's peer-to-peer path is the dominant contributor.** Routing
the same GPU RDMA traffic *around* switch-local peer-to-peer recovers **+45%** of the lost
bandwidth on AICR's own hardware.

A second, smaller GPU-side term remains unexplained. This is a gradient, not a single switch.

---

## 1. What Engaging established (input to this work)

| | Engaging (node5501+5502) | AICR (prior) |
|---|---:|---:|
| GPU bidirectional | **48.7 GB/s/dir** | 27.2 |
| GPU unidirectional | 49.4 | 47.5 |
| host bidirectional | 47.6 | 47.3 |
| `EnablePCIERelaxedOrderingMode` | **0** (and healthy) | 0 |
| relaxed-ordering toggle effect | none (48.7 vs 48.7) | none (32.0 vs 31.5) |

Two conclusions carried over:

1. **AICR's collapse is a genuine cluster defect** — healthy B200 hardware reaches 48.7 GB/s/dir
   bidirectionally, so 27.2 is not a platform property.
2. **PCIe relaxed ordering is eliminated on both clusters.** Engaging is healthy with the *same*
   `EnablePCIERelaxedOrderingMode: 0` that AICR was briefly blamed for, and toggling MR-level RO
   changes nothing on either. That closes the hypothesis permanently.

Engaging also contributed a methodological warning that shaped this run: a rail at NODE distance
gave 18.6 GB/s vs 49.4 on the GPU's PXB partner — a 2.6× error that *mimics a hardware defect*.
Rail affinity must be verified before any measurement is trusted.

---

## 2. Test 0 — rail affinity was correct

AICR's earlier measurements were **not** invalidated by the Engaging rail trap.

`nvidia-smi topo -m` on b0029 shows the allocated GPU is `PIX` to exactly one NIC (`mlx5_0`) and
`NODE` to all others. The PCIe bridge chains confirm it structurally:

```
GPU  0000:03:00.0  ->  0000:02:00.0  Broadcom PEX890xx Gen5 Switch
                   ->  0000:01:00.0  Broadcom PEX890xx Gen5 Switch
                   ->  0000:00:01.1  AMD Turin GPP Bridge

NIC  0000:04:00.0  ->  0000:02:01.0  Broadcom PEX890xx Gen5 Switch   <- same switch, bus 02
```

GPU and NIC hang off the **same PEX890xx switch**, so GDRDMA between them is switch-local
peer-to-peer. Every one of the 8 B200s on the node sits behind a PEX890xx pair in the same
pattern.

---

## 3. Test 1 — direction isolation: symmetric

Putting GPU memory on only one side isolates each direction of the GPU's PCIe traffic.

| Test | What it measures | GB/s per direction |
|---|---|---:|
| host↔host, unidirectional | baseline | 48.4 |
| **NIC reads from GPU** | GPU as source | **47.6** |
| **NIC writes into GPU** | GPU as sink | **48.4** |
| GPU↔GPU, unidirectional | | 47.6 |
| **GPU↔GPU, bidirectional** | | **26.9** |

**Ratio 1.02× — essentially symmetric.** Neither direction is individually impaired; both run at
full line rate alone. The collapse appears *only* when the two are concurrent.

This **eliminates read-completion credits and `MaxReadRequest`**, which were the prime suspects
going in. A small MRRS throttles the read direction specifically, and the read direction is fine.
It also rules out the asymmetric signature Engaging showed while *it* was broken (reads 18.5 vs
writes 35.8) — AICR's fault is a different one.

The remaining shape is a **shared resource that only saturates when both directions contend**.

---

## 4. Test 2 — switch path contrast: the finding

The decisive comparison. Same node, same GPU, same message size — only the *path* differs:

| Path | GB/s per direction |
|---|---:|
| GPU↔NIC **through switch-local P2P** (`PIX` rail `mlx5_0`) | **26.9** |
| GPU↔NIC **via the root complex** (`NODE` rail `mlx5_1`) | **39.0** |
| GPU↔NIC via root complex, unidirectional | 47.6 |
| host↔NIC via root complex, bidirectional (no GPU) | 48.3 |

**Avoiding switch-local peer-to-peer recovers +45%** (26.9 → 39.0 GB/s/dir).

This is the strongest evidence yet, and it points at the one structural difference remaining
between the clusters:

| | AICR | Engaging |
|---|---|---|
| GPU → root complex path | **Broadcom PEX890xx Gen5 switch** (×2 levels) | Mellanox MT2910 bridge chain |
| GPU bidirectional GDRDMA | 26.9–27.2 | 48.7 |

**But it is not the whole story.** The NODE path at 39.0 is still short of the 48.3 host
baseline, so a second GPU-side term of roughly 9 GB/s/dir remains after the switch's P2P
contribution is removed. Both terms need accounting for before the gap to Engaging's 48.7 is
closed.

---

## 5. Test 3 — concurrency scaling: PENDING

Not yet run. `b200-devel` caps a user at **2 GPUs total**, which allows only one pair, and the
`b200-batch` job (317648, 2 nodes × 8 GPUs) is still queued on a saturated partition.

This is the test that separates the two remaining possibilities:

| Outcome | Conclusion |
|---|---|
| Per-pair rate flat as pairs are added | a per-port / per-link limit |
| Per-pair rate falls as pairs are added | a **shared switch resource** (credits, buffers) saturating — the classic PCIe-switch signature, and strong corroboration for §4 |

Given §3 already implicates a shared-resource mechanism, the falling case is the prediction.

---

## 6. Test 4 — PCIe and firmware reads

| Item | Result |
|---|---|
| `DevCtl` / `MaxReadReq` / `RlxdOrd` / `ACSCtl` | **not visible** — unprivileged `lspci` omits the PCIe Express capability |
| GPU config space | 64 of 4096 bytes readable |
| `mlxconfig` (`PCI_WR_ORDERING`) | denied — root only |
| **ConnectX firmware** | **28.41.1000 and 28.46.5020 on the same node** |

Two observations worth chasing:

1. **AICR runs mixed ConnectX firmware within a single node** (28.41.1000 and 28.46.5020), and
   both are older than Engaging's **28.49.1120**. Firmware governs PCIe ordering and
   outstanding-read behaviour, so this is a plausible contributor to the residual GPU-side term
   in §4 — and mixed firmware is worth fixing on its own merits.
2. Every register that would settle the switch question directly still needs root.

---

## 7. Where the diagnosis stands

**Eliminated, with evidence:**

| Candidate | How it was eliminated |
|---|---|
| B200 silicon / shared TX-RX budget | `cudaMemcpy` full duplex 98.3 GB/s total on AICR |
| IB fabric, NIC, switch uplink | host bidirectional 47.3–48.4 GB/s/dir |
| PCIe link width / generation | all Gen5 x16 of x16 |
| IOMMU, ACS (boot flags) | `amd_iommu=off iommu=off pci=noacs` |
| `nvidia_peermem` | loaded; unidirectional GDR at line rate |
| NCCL version / tuning | AICR runs the newer NCCL; perftest involves no NCCL |
| **PCIe relaxed ordering** | Engaging healthy with the identical setting; toggle is a no-op on both clusters |
| **Read-completion credits / `MaxReadRequest`** | direction isolation is symmetric (§3) |
| **Rail-affinity measurement error** | topology verified; the PIX partner was used (§2) |

**Live, in order of evidence:**

1. **Broadcom PEX890xx peer-to-peer path** — +45% recovered by avoiding it (§4). Leading
   candidate, and the only structural difference from Engaging.
2. **A residual GPU-side term** — ~9 GB/s/dir still missing on the root-complex path (§4).
   Possibly the mixed/older ConnectX firmware (§6).
3. **Shared-resource saturation** — mechanism implied by §3; Test 3 will confirm or refute.

---

## 8. Recommended next steps

**Without root, already queued:** the `b200-batch` concurrency run (job 317648) completes §5.

**With root on a b-node** — read before changing anything:

```bash
# the switch's P2P and ordering configuration -- the leading candidate
lspci -vvv -s 02:00.0 | grep -E "DevCtl|MaxPayload|MaxReadReq|RlxdOrd|NoSnoop|ACSCtl"
lspci -vvv -s 02:01.0 | grep -E "DevCtl|MaxPayload|MaxReadReq|RlxdOrd|NoSnoop|ACSCtl"
lspci -vvv | grep -A1 ACSCtl        # is ACS genuinely off on the PEX switch ports?

# NIC firmware ordering policy + the version mismatch
mlxconfig -d <nic_bdf> q | grep -Ei "PCI_WR_ORDERING|ADVANCED_PCI|MAX_ACC_OUT_READ"
mlxfwmanager --query                 # reconcile 28.41.1000 / 28.46.5020 -> 28.49.1120
```

**Vendor angle:** the PEX890xx P2P result is specific enough to raise with Broadcom or the
system integrator — "switch-local GPU↔NIC peer-to-peer collapses to 55% under bidirectional load
while the same traffic via the root complex reaches 80%" is an actionable bug report.

**Confirming any fix**, ~30 seconds on the PIX rail:

```bash
ib_write_bw -d <pix_rail> -s 8388608 -n 2000 -F --report_gbits --use_cuda=0 -b [server]
```

~780 Gb/s (48–49 GB/s/dir) = fixed; ~435 Gb/s (27 GB/s/dir) = unchanged. Then end to end:
NCCL 2-node SendRecv 26.6 → ~49, AllGather 218 → ~380 GB/s.

---

## 9. Consequences for the paper

Unchanged by this round, and now on firmer ground: the paper's Section IV B model — a
"≈53.5 GB/s DMA budget shared between transmit and receive", and SendRecv's 26.6 GB/s as "a
silicon-level wall that no NCCL tuning can overcome" — is refuted three ways over:

1. AICR's own GPU does 98.3 GB/s total full-duplex over PCIe (`cudaMemcpy`, no IB).
2. Healthy B200 hardware on Engaging reaches 48.7 GB/s/dir bidirectionally.
3. On AICR itself, simply changing the *path* (root complex instead of switch-local P2P) moves
   the same GPU traffic from 26.9 to 39.0 GB/s/dir. A silicon wall does not care which PCIe
   bridge you route through.

The required edits are unchanged from `nccl-2node-ib-pice.md` §8.

---

*Raw data: `aicr-followup-317647.out`. Auto-generated tables: `RESULTS.md`. Engaging inputs:
`../aicr-handoff/`. Version of record for the overall analysis: `../nccl-2node-ib-pice.md`.*
