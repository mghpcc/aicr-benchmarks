# AICR B200 inter-node GDRDMA defect — root cause

**Date:** 2026-08-06 / 2026-08-07
**Nodes:** b0029, b0030, b0031 (`b200-devel`) — b0029+b0030 are the pair that produced the
inter-node data in `results_b200.md` Table 2 and Table III of `aicr_benchmarks_submitted.pdf`
**Platform:** AMD Turin GPP root complex → Broadcom PEX890xx Gen5 switch → B200 / ConnectX-7

---

## Root cause

**PCIe relaxed ordering is disabled on the GPU path.** `/proc/driver/nvidia/params` reports:

```
EnablePCIERelaxedOrderingMode: 0
```

Without relaxed ordering, a PCIe read completion may not pass a posted write. In GPUDirect RDMA
the NIC is the requester against GPU BAR memory: it **reads** GPU memory for outbound traffic and
**writes** GPU memory for inbound traffic. Run one direction at a time and nothing conflicts —
both hit full line rate. Run both at once and the read completions must queue behind the posted
writes at the GPU endpoint, and each direction collapses to roughly half.

That is precisely the measured signature, and it is a known requirement on AMD platforms: the
HPC Advisory Council's EPYC/InfiniBand tuning guidance calls relaxed ordering the key mechanism
for reaching full bandwidth against AMD-attached memory with ConnectX adapters.

**Confidence: high, but not yet closed.** Every alternative has been measured and excluded, the
mechanism matches the signature exactly, and the offending setting is confirmed off. What is
missing is the toggle-and-remeasure, which needs root. See §4.

**Cost of the defect:** ~1.75× on every bidirectional inter-node collective — the entire gap
between AICR's published inter-node numbers and what the hardware delivers.

---

## 1. The evidence chain

Six measurements, each eliminating something. All on AICR hardware; none needs root.

| # | Test | Result | What it establishes |
|---|---|---|---|
| 1 | **PCIe full duplex**, `cudaMemcpyAsync`, no IB at all | H2D 57.6, D2H 57.3, **concurrent 49.1 each way = 98.3 GB/s total** | The GPU's PCIe link **is** full duplex. No "shared TX/RX budget" exists. |
| 2 | Host↔Host RDMA, unidirectional | 46.3 GB/s | Baseline line rate |
| 3 | Host↔Host RDMA, **bidirectional** | **47.3 GB/s each way** (94.5 total) | Fabric, switch uplink and NIC all fine in both directions |
| 4 | GPU↔GPU RDMA, unidirectional | **47.5 GB/s** | The GDRDMA path is fine one direction at a time |
| 5 | GPU↔GPU RDMA, **bidirectional** | **27.2 GB/s each way** (54.5 total) | The defect |
| 6 | **One GPU endpoint only**, bidirectional | GPU↔host **30.7**, host↔GPU **27.2** GB/s/dir | A *single* GPU endpoint is enough — it is per-endpoint concurrency, not an end-to-end effect |

Measurement 1 is the one that changes the story. It runs entirely inside a single node with
plain `cudaMemcpy` — no InfiniBand, no NIC, no RDMA, no peer-to-peer — and the GPU sustains
**49.1 GB/s in each direction simultaneously, 98.3 GB/s total**. The paper's postulated
"≈53.5 GB/s DMA budget shared between transmit and receive" does not exist on the very hardware
the paper measured.

Measurement 6 is the one that identifies the mechanism. If the collapse needed GPU memory at both
ends, an end-to-end or fabric explanation would still be live. It does not: put GPU memory on
**one** side and host memory on the other, and that single endpoint still collapses to ~27–31
GB/s per direction. Whatever is wrong happens where the NIC's reads and writes meet at one GPU.

### Why measurement 1 and measurement 5 are not contradictory

They differ in **who is the PCIe requester**, and that is exactly what ordering rules key on:

- `cudaMemcpy` (test 1): the **GPU's** copy engines are the requester, reading and writing host
  DRAM. Separate engines, separate directions, no ordering conflict — 98.3 GB/s total.
- GDRDMA (test 5): the **NIC** is the requester, reading and writing **GPU BAR** memory. Its read
  completions and posted writes share one ordering domain at the GPU endpoint. Without relaxed
  ordering they serialize — 54.5 GB/s total.

Same link, same GPU, same switch. Only the requester and the ordering rules differ.

---

## 2. Cross-check against NCCL

27.2 GB/s per rail is exactly what AICR's NCCL delivers, so this microbenchmark is measuring the
same thing the collectives run into:

| Source | Per-rail rate |
|---|---:|
| `ib_write_bw` GPU bidirectional | 27.2 GB/s |
| NCCL SendRecv, 2 nodes × 8 GPUs | 26.6 GB/s |
| NCCL AllGather, 218 GB/s ÷ 8 rails | 27.2 GB/s |

And a healthy comparison cluster (MIT Engaging B200, same GPU, same NIC class, same NCCL library)
reaches 383 GB/s AllGather = **47.9 GB/s per rail per direction** — matching AICR's *unidirectional*
rate, i.e. what AICR would deliver with the ordering constraint removed.

---

## 3. What was excluded, and how

| Candidate | Evidence | Status |
|---|---|---|
| B200 silicon / shared DMA budget | Test 1: 98.3 GB/s total, full duplex | **excluded** |
| Fabric / IB switch / NIC | Test 3: 47.3 GB/s each way on the same rail | **excluded** |
| PCIe link width or generation | All GPUs and 8 compute rails at **Gen5 x16 of x16** | **excluded** |
| GDRDMA path broken or absent | Test 4: full line rate one-way; `nvidia_peermem` loaded | **excluded** |
| IOMMU translating P2P | `amd_iommu=off iommu=off`; `/sys/class/iommu` empty | **excluded** |
| ACS redirect | `pci=noacs` on cmdline; and a root-complex redirect would cost one-way throughput too, which is clean | **excluded**¹ |
| GPU BAR1 / resizable BAR | BAR1 = 256 GB, Region 2 = 256 G | **excluded** |
| NCCL version or tuning | AICR runs NCCL **2.29.3**, *newer* than the healthy comparison cluster's 2.29.2; and this is a `perftest` result with no NCCL involved | **excluded** |
| **PCIe relaxed ordering** | `EnablePCIERelaxedOrderingMode: 0`; mechanism matches signature exactly | **ROOT CAUSE** |

¹ `ACSCtl` could not be read: unprivileged `lspci -vv` omits the capability, and
`/sys/bus/pci/devices/*/config` returns only 64 of 4096 bytes. Excluded on the cmdline flag plus
the one-way argument, not on a live register read.

---

## 4. The fix, and how to confirm it

All three steps need root. Suggested order:

**1. Enable relaxed ordering in the NVIDIA driver.** Confirm the exact parameter spelling first —
the `/proc` name and the modprobe name differ in capitalisation:

```bash
modinfo nvidia | grep -i relax          # expect NVreg_EnablePCIeRelaxedOrderingMode
echo 'options nvidia NVreg_EnablePCIeRelaxedOrderingMode=1' \
     > /etc/modprobe.d/nvidia-relaxed-ordering.conf
dracut -f && reboot                      # or unload/reload the nvidia modules
cat /proc/driver/nvidia/params | grep -i relax   # want: 1
```

**2. Check the NIC side too.** ConnectX write ordering is a firmware setting; on AMD platforms it
is commonly moved off the default:

```bash
mlxconfig -d <pci-bdf> q | grep -i order      # PCI_WR_ORDERING
mlxconfig -d <pci-bdf> set PCI_WR_ORDERING=1  # force_relax; needs a firmware reset
```

**3. Read the live ACS state while you have root**, to close the one gap in §3:

```bash
lspci -vvv | grep -A1 ACSCtl        # want SrcValid- RequestRedirect-
```

**Confirm with the same measurement that found it** — no interpretation required:

```bash
sbatch -w b0029,b0030 diag-gdrdma-ab.sh     # row 4 should go 27.2 -> ~47 GB/s/dir
sbatch diag-rootcause.sh                     # part A should stay ~98 GB/s total
```

**Expected effect if this is right:** per-rail bidirectional 27 → ~47 GB/s, and therefore
SendRecv 26.6 → ~48, AllGather and ReduceScatter 218 → ~380, Reduce 201 → ~380, Broadcast
202 → ~365 GB/s. That is the healthy comparison cluster's profile.

If row 4 does **not** move after step 1, the next suspect is the Broadcom PEX890xx switch's
peer-to-peer handling — test 3 does not exercise the GPU↔switch leg, so the switch is not fully
exonerated by it, and step 2 becomes the more likely lever.

---

## 5. Configuration reference (b0029/b0030/b0031, 2026-08-07)

Full dumps: `out-diag/diag-b0029.txt`, `out-diag/gdr-root-b0031-317105`,
`out-diag/gdr-root-b0030-317112`.

**PCIe path from GPU to root complex:**

```
B200 (0000:a3:00.0)
  -> 0000:a2:00.0  Broadcom / LSI PEX890xx PCIe Gen 5 Switch
  -> 0000:a1:00.0  Broadcom / LSI PEX890xx PCIe Gen 5 Switch
  -> 0000:a0:01.1  AMD Turin GPP Bridge
```

The GPU and its rail NIC sit under the same switch (`PIX` in `nvidia-smi topo -m`), so GDRDMA is
switch-local peer-to-peer.

**Kernel cmdline:** `... pci=pcie_bus_perf ... amd_iommu=off iommu=off pci=noacs ...`

**Link widths:** every B200 and the 8 compute rails at width 16, speed 32.0 GT/s (Gen5), max 16 /
32.0. The four functions at `0000:e3:00.[0-3]` run **x2 at 8.0 GT/s** — these are the 100 Gb/s
`mlx5_7/8/9/10` seen in `ibstat`, i.e. storage/management, already excluded from the SHARP NIC
list. Not part of the compute fabric.

**Other:** `nvidia_peermem` loaded; BAR1 256 GB; ConnectX-7 firmware 28.41.1000; GPU
`asyncEngineCount=4`.

---

## 6. Method notes

Recorded so the next run does not repeat these.

**`test-gdrdma.sh` (the April 2026 script) measures the wrong path.** It hardcodes `-d mlx5_0`,
which is `NODE` — across a PCIe host bridge — from the GPU at `72:00`, while `mlx5_3` is `PIX`.
NCCL uses the PIX rail. `diag-gdrdma-ab.sh` resolves affinity at runtime from `nvidia-smi topo -m`.

**Server and client must use the same rail.** Letting each side pick its own PIX rail gave
`mlx5_3` on one node and `mlx5_12` on the other; those are on different IB subnets and every test
died with `Failed status 12` (transport retry exceeded). `NIC_FORCE=mlx5_N` pins one rail.

**perftest reports bidirectional rows as the sum of both directions.** Divide by 2 before
comparing against a unidirectional row. Forgetting this makes a halved link look healthy.

**`--use_cuda` is per side.** That is what makes test 6 possible — mixing GPU and host buffers
across the two ends localises the defect to a single endpoint.

**Unprivileged `lspci` is silently incomplete.** It omits the PCIe Express capability entirely, so
grepping for `ACSCtl` or `RlxdOrd` returns nothing — which reads as "clean" but means "not
visible". `/sys/bus/pci/devices/*/config` gives only the first 64 bytes without privileges.
`/sys/bus/pci/devices/*/current_link_width|max_link_width|current_link_speed` *are* world-readable
and were used instead.

**Reproduce:**

```bash
sbatch diag-rootcause.sh                    # 1 GPU: full-duplex test + config dump
sbatch -w b0029,b0030 diag-gdrdma-ab.sh     # 2 nodes: host vs GPU, uni vs bidir
sbatch diag-gdrdma-sides.sh                 # 2 nodes: which endpoint is at fault
```

`b200-devel` (b0029–b0031, 4 h limit) is far less contended than `b200-batch`.

---

## 7. Consequences for the paper

The measurements in `aicr_benchmarks_submitted.pdf` are correct; the interpretation is not.

Section IV B derives a "≈53.5 GB/s HBM budget shared between transmit and receive" and concludes
SendRecv's 26.6 GB/s is "a silicon-level wall that no NCCL tuning can overcome." Test 1 refutes
this **on AICR's own hardware**: the GPU moves 98.3 GB/s total across its PCIe link, 49.1 GB/s in
each direction at once. No cross-cluster comparison is needed to make this point any more.

Required changes: drop the shared-budget derivation; recompute the inter-node `%max` column
against 50 GB/s per rail / 400 GB/s per node (94–100% becomes ~50–55%); remove the "silicon-level
wall" claim; revise the ~37 ms pipeline-parallel activation budget to ~20 ms; and reword SHARP as
working around a *configuration* limit rather than a physical one — its 2.2× is probably inflated
by the defect, since in-switch reduction halves exactly the bidirectional pressure that is
degraded here.

Unaffected: all intra-node NVLink results, the Gather and AllToAll algorithmic diagnoses, and the
two-phase Ring AllReduce explanation.

Full discussion: `inter-node-nccl.md`.
