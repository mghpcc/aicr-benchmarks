# Comment on the Engaging-vs-AICR inter-node NCCL discrepancy

**Date:** 2026-08-06
**Subject:** `engaging-results/notes-aicr.md` and `engaging-results/summary-engaging-b200.md`
vs. Section IV B of `paper/aicr_benchmarks_submitted.pdf`
**Reference AICR data:** `out-2node/nvhpc-26.3-b0029-9289` (b0029+b0030), the raw file behind
Table 2 of `results_b200.md` and the right half of Table III in the paper.

---

## Verdict

**The critique is substantially correct, and it should be acted on before the paper is
finalized.** The physical model in Section IV B is not sound, the derived `%max` column in the
inter-node half of Table III is computed against a ceiling roughly half its true value, and the
most likely explanation for AICR's inter-node numbers is a real, fixable GPU↔NIC path defect
rather than a silicon limit.

Two things the critique gets *wrong in AICR's favour* actually make the case **stronger**, not
weaker — see §2. Two places where it overreaches are in §4.

What survives untouched: all intra-node (NVLink) results, the algorithm-limited diagnoses for
Gather and AllToAll, and the existence of the SHARP speedup. What needs rewriting: the ceiling
model, the `%max` column, the "silicon wall" language, and the framing of what SHARP bypasses.

---

## 1. The Section IV B model is not physically sound

The paper states:

> a B200 GPU reaches its NIC through a single 16-lane PCIe Gen5 port whose DMA engine has a
> fixed ≈53.5 GB/s HBM budget **shared** between transmit and receive; under simultaneous
> bidirectional traffic each direction collapses to half of that, about 26.7 GB/s

Three independent problems:

**(a) PCIe is full-duplex.** A Gen5 x16 link has separate transmit and receive differential
pairs and carries ~63 GB/s in *each* direction simultaneously. There is no shared budget to
halve. This is not a subtle point — it is the basic electrical structure of the link.

**(b) The 53.5 GB/s "HBM budget" is not a real hardware parameter.** B200 HBM3e delivers on the
order of 8 TB/s. Attributing a 53.5 GB/s ceiling to the GPU's DMA path against HBM has no
grounding, and the cited `\cite{gpudirect}` reference does not establish such a number. More
tellingly, 53.5 is *exactly* 2 × 26.7 — the constant was reverse-engineered from the measurement
and then used to explain it. That is circular: the model has no predictive content, it only
restates the observation.

**(c) The paper contradicts itself two subsections later.** Section IV D writes that PCIe Gen5
x16 is "≈63 GB/s **per direction**" and reports RTX PRO 6000 SendRecv at **37.4 GB/s per
direction under bidirectional traffic**, calling it "bounded by the GPU's PCIe DMA bidirectional
budget, 59% of the ... link rate."

So the same paper uses two different fractions of the same link for the same claimed mechanism:

| Section | Claimed bidir budget, per direction | As fraction of 63 GB/s |
|---|---:|---:|
| IV B (B200) | 26.7 GB/s | 42% |
| IV D (RTX PRO 6000) | 37.4 GB/s | 59% |

IV D's number is 40% *above* IV B's "silicon-level wall that no NCCL tuning can overcome" — on a
weaker, CPU-relayed path. Both cannot be right, and a reviewer who reads the two sections
together will find this.

---

## 2. Two corrections that strengthen the critique

I checked these against the raw AICR output rather than the published tables, and the critique
is more right than it claims.

### 2a. The NCCL version argument is backwards — AICR is running the *newer* library

`notes-aicr.md` §4 concedes that part of the AllToAll/AllReduce gap may come from NCCL version,
"ours is **NCCL 2.29.2** ... versus the paper's **nccl-tests 2.18.3** era."

That conflates two different version numbers. From the raw AICR header:

```
# nccl-tests version 2.18.3 nccl-headers=22903 nccl-library=22903
```

`2.18.3` is the **nccl-tests harness** version. `22903` is the **NCCL library** version =
**NCCL 2.29.3**. AICR is running NCCL 2.29.3; Engaging ran 2.29.2. AICR has the *newer* library
by one patch release.

**NCCL version therefore explains none of the gap** — not the 1.9× on point-to-point and ring
collectives, and not the 1.25× on AllToAll either. The one hedge the critique offered to AICR
should be withdrawn.

### 2b. The SendRecv comparison is valid — `summary-engaging-b200.md`'s disclaimer is wrong

`summary-engaging-b200.md` line 50 leaves the `ours / ref` cell blank for SendRecv with the note:

> the reference 26.6 GB/s is a per-pair (2-GPU) bidir figure, so the two are not directly
> comparable

This is incorrect. The AICR raw file shows 160 `# Rank` lines across 10 collectives — **16 ranks
per collective**, i.e. `nGpus 8` × 2 nodes, the same 16-GPU ring as the Engaging run. AICR's
26.6 GB/s SendRecv is a 16-GPU 2-node ring measurement, exactly like Engaging's 49.7.

The two numbers are directly comparable and the **1.87× ratio in `notes-aicr.md` is the correct
one**. The summary file should be fixed to match.

---

## 3. The decisive argument: per-rail decomposition

This is the cleanest way to state the case, and it is stronger than the argument the notes make.

In a 2-node ring collective NCCL builds one channel per rail, so `busbw` for the symmetric ring
collectives is the *aggregate* over all 8 NDR rails. Dividing back out gives the per-rail rate,
which is the physically meaningful quantity:

| | AllGather busbw | ÷ 8 rails | SendRecv (single pair) | Consistent? |
|---|---:|---:|---:|---|
| **AICR** (b0029+b0030) | 218 GB/s | **27.2 GB/s** | **26.6 GB/s** | ✅ |
| **Engaging** (node5500–5502) | 383 GB/s | **47.9 GB/s** | **47.8–50.0 GB/s** | ✅ |

On both clusters the aggregate is exactly 8× the single-pair rate — both are saturating all
eight rails, and both are rail-limited. **The clusters differ only in what one rail delivers:
26.6 vs ~48 GB/s.** A single per-rail defect explains every degraded AICR number simultaneously,
with no appeal to a novel silicon mechanism.

Engaging's ~48 GB/s per rail is ~96% of the 50 GB/s NDR nominal rate — a healthy GDR path.
AICR's 26.6 is 53% of it.

### The control: the collectives that *didn't* move

This is what makes the diagnosis convincing rather than merely a "our cluster is faster" claim.

| Collective | AICR | Engaging | Ratio | Paper's verdict | Verdict holds? |
|---|---:|---:|---:|---|---|
| Gather | 90.5 | 92.0–95.4 | **1.05×** | "42%, algorithm-limited" | ✅ confirmed |
| AllToAll | 39.8 | 47.5–49.9 | **1.25×** | "19%, algorithm-limited" | ✅ confirmed |
| SendRecv | 26.6 | 47.8–50.0 | 1.87× | "100%, silicon wall" | ❌ refuted |
| AllGather | 218 | 383 | 1.76× | "100% of max" | ❌ refuted |
| ReduceScatter | 218 | 382 | 1.75× | "100% of max" | ❌ refuted |
| Reduce | 201 | 384 | 1.91× | "94% of max" | ❌ refuted |
| Broadcast | 202 | 368 | 1.82× | "94% of max" | ❌ refuted |

Every collective the paper called *hardware-saturated* roughly doubled. Every collective it
called *algorithm-limited* barely moved. A faster fabric cannot fix an algorithmic bottleneck,
and it did not — Gather sits at ~92 GB/s on both clusters, and Engaging's AllToAll plateaus at
~49 GB/s, about one rail's worth, exactly as "N² P2P transfers not pipelined across NICs"
predicts.

**The paper's algorithmic analysis is good. Its hardware ceiling is not.** The inverted pattern
is hard to explain any other way.

### A bonus: the two-phase AllReduce claim survives

Section IV B argues Ring AllReduce underperforms AllGather because it runs two phases in
sequence. Engaging corroborates this and then some — the penalty is *larger* on a healthy
fabric, because phase-transition latency does not shrink when the wire gets faster:

| | AllReduce / AllGather |
|---|---:|
| AICR | 170 / 218 = 0.78 |
| Engaging | ~236 / ~377 = **0.63** |

This part of the paper can stay, and can even be stated more confidently.

---

## 4. Where the critique overreaches

Being fair to the paper on two points:

**(a) "99% of the NDR line rate ... a hard physical bound we approach but never exceed."**
`notes-aicr.md` §3 cites its own July perftest measurement of **47.4 GB/s** host-to-host as "full
line rate," then reports NCCL SendRecv at **49.7 GB/s** — above it. These are not strictly
inconsistent (different transfer sizes, different path, and the July run was on a
then-degraded node), but the "99% of line rate, never exceeded" framing is asserted rather than
shown. A current `ib_write_bw --use_cuda` on node5500–5502 would nail it down. This does not
affect the conclusion: 26.6 vs 48–50 is a ~1.8× gap on any reading.

**(b) The x8-link hypothesis is ranked first but is not the best fit.** 26.6 GB/s is indeed close
to PCIe Gen5 x8 (~26–27 GB/s effective), which is a striking coincidence. But a narrowed link is
full-duplex too, so it would cap *unidirectional* traffic at the same ~27 GB/s — and AICR's
Scatter reaches 293 GB/s aggregate, well above 8 × 27. (Scatter's per-rail decomposition is
messier than AllGather's because the root is a single GPU, so this is suggestive rather than
conclusive.) The asymmetry the Engaging team logged locally on 2026-07-13 — NIC *reads from* GPU
at 18.5 GB/s while NIC *writes into* GPU ran at 35.8 GB/s — is the classic signature of an
ACS-redirect or IOMMU-translation problem on the P2P read path, and fits AICR's profile better.
I would reorder the hypotheses accordingly.

**(c) A hypothesis the notes dismiss too fast.** Newer NCCL can fan a single peer connection
across multiple rails, which would raise SendRecv with no hardware change at all. Two things
argue against it here: NCCL 2.29.3 (AICR) is *newer* than 2.29.2 (Engaging), per §2a; and
Engaging's SendRecv plateaus flat at 49.7–50.0 GB/s across every message size and all three node
pairs, which is the signature of hitting one 50 GB/s wire, not of aggregating two. Worth
confirming with `NCCL_DEBUG=INFO` channel/NIC mapping, but it is not a live explanation.

---

## 5. Ranked hypotheses for AICR, with the check for each

| # | Hypothesis | Check |
|---|---|---|
| 1 | **ACS redirect enabled** on PCIe switch ports, forcing P2P TLPs through the root complex | `lspci -vvv \| grep -i acsctl` — look for `SrcValid+`/`RequestRedirect+` |
| 2 | **IOMMU translating the P2P path.** `results_b200.md` claims `iommu=off` was applied; confirm it was actually in effect on b0029/b0030 | `cat /proc/cmdline`; `dmesg \| grep -i -e DMAR -e IOMMU` |
| 3 | **GPU↔NIC PCIe link negotiated below x16** | `lspci -vv -s <nic> \| grep -E 'LnkCap\|LnkSta'` — compare width and speed |
| 4 | **GPU–NIC rail affinity** — NCCL pairing a GPU with an off-socket NIC | `nvidia-smi topo -m` should show `PIX`/`PXB` for each GPU's chosen NIC, never `SYS`; cross-check with `NCCL_DEBUG=INFO` |
| 5 | **`nvidia_peermem` / DMA-BUF path degraded** rather than absent (absence would give ~10–15 GB/s, not 26.6) | `lsmod \| grep peermem`; NCCL log should show `[GDRDMA]` / `via GPU Direct RDMA` |

**Decisive test, independent of NCCL entirely:**

```bash
# on AICR b-nodes, per rail
ib_write_bw -d mlx5_X -s 67108864 -F            # host  -> host
ib_write_bw -d mlx5_X -s 67108864 -F --use_cuda=<gpu>   # GPU   -> GPU, both directions
```

If host↔host reaches ~47 GB/s while GPU↔GPU sits at ~26 GB/s, the defect is in the P2P path —
not the fabric, and definitively not silicon. That single result settles the whole question.

**Also relevant:** there is already a known NIC anomaly on AICR — the SHARP recipe in
`2nodes-8gpus-sharp.sh` has to exclude `mlx5_12`, and there is an open rank-7 NIC issue logged
in the project notes. That is independent evidence that AICR's NIC/rail configuration is not
clean, and it should be run down at the same time.

---

## 6. Consequences for the paper

**Not affected:** everything intra-node (Section IV A, left half of Table III — NVLink numbers
stand); the Gather and AllToAll algorithmic analyses; the two-phase Ring AllReduce explanation;
the SHARP measurement itself (357 vs 163 GB/s at 16 GB is a real, cleanly-validated A/B).

**Needs revision:**

1. **The ceiling model (IV B).** Remove the "53.5 GB/s HBM budget shared between transmit and
   receive" derivation. PCIe Gen5 x16 is full-duplex at ~63 GB/s per direction; the binding
   constraint on a healthy node is the NDR rail at 50 GB/s per direction, giving 8 × 50 = **400
   GB/s per node per direction**, not 214.

2. **The `%max` column, inter-node half of Table III.** Recomputed against 50 GB/s per rail /
   400 GB/s aggregate: SendRecv ~53%, AllGather and ReduceScatter ~55%, Reduce ~50%, Broadcast
   ~51%. The honest reading is that the cluster measured for the paper had an inter-node problem,
   not that it was at silicon saturation.

3. **"A silicon-level wall that no NCCL tuning can overcome."** This sentence has to go. It is
   the single most quotable wrong claim in the section.

4. **The pipeline-parallel guidance in the discussion.** ~37 ms for a 1 GB activation transfer
   (1 GB ÷ 26.6 GB/s) becomes ~20 ms (÷ 49.7) on a healthy fabric — a materially different
   engineering recommendation.

5. **The SHARP framing (IV C).** SHARP does not "bypass a 214 GB/s bidirectional wall," because
   that wall is not where the paper places it. SHARP's single-pass advantage over Ring AllReduce
   is real and independent of this error, so the result stands — but note the reported 2.2× is
   probably *inflated* by the defect: single-pass in-switch reduction halves wire traffic, which
   is exactly the pressure a degraded bidirectional path is most sensitive to. On a healthy
   fabric the speedup would likely be smaller. **This is a prediction, not a measurement** — we
   have no SHARP data from Engaging. Running it there would be the cleanest way to check.

6. **The RTX PRO 6000 inter-node claim (IV D).** "Inter-node, a single GPU per node reaches 24.7
   GB/s on SendRecv, GDRDMA-bidir limited by the same PCIe DMA mechanism as B200 (26.6 GB/s) and
   thus nearly identical." If AICR has a cluster-wide GPU↔NIC path defect, the RTX number was
   measured on the same cluster and is suspect for the same reason. The "nearly identical"
   agreement may be evidence of a shared misconfiguration rather than of a shared mechanism —
   which, read that way, is corroborating evidence for the defect hypothesis.

---

## 7. Caveats, and what would settle it

- **AICR was not inspected directly.** This diagnosis rests on the published AICR numbers, the
  raw file behind them, and contrasting measurements from a different cluster. The internal
  contradiction between IV B and IV D and the inverted improvement pattern hold regardless, but
  the specific mechanism needs the §5 checks.

- **The comparison is across clusters, not a controlled experiment.** Same GPU (B200), same NIC
  class (8× NDR400 per node), same benchmark, and — per §2a — effectively the same NCCL library.
  That is a tight match, but switch topology, firmware, and OFED version were not controlled.
  Running the *identical* nccl-tests binary and NCCL build on both would close the last gap.

- **Useful in-flight data.** Ten 2-node runs are queued on AICR right now (jobs 299459–299468,
  20 distinct nodes b0001–b0020). They will show whether 26.6 GB/s is uniform across the
  cluster — pointing to a systemic configuration setting — or varies by node, pointing at
  per-node hardware or firmware. Either answer is informative, and the result lands in
  `results_b200-new.md`. If those runs come back at ~26.6 GB/s across all 20 nodes while
  Engaging sits at ~48, that is about as close to conclusive as a cross-cluster comparison gets.

---

*Sources: `engaging-results/notes-aicr.md`, `engaging-results/summary-engaging-b200.md`,
`paper/aicr_benchmarks_submitted.tex` §IV B / §IV C / §IV D,
`out-2node/nvhpc-26.3-b0029-9289` (raw AICR data, re-extracted and independently verified
against Table 2 of `results_b200.md`).*
