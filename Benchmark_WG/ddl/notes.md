# Notes: FP8 + model parallelism (Paper B) — source material

Everything about THIS project extracted from `../paper/future-work.md`
(2026-07-13). The SHARP-in-training plan and Paper A live there; this file keeps
only what drives the ddl project, verbatim where it matters.

## FP8 training (Transformer Engine) + model parallelism (detailed plan)

Status in the paper (`aicr_benchmarks_v7.tex`): training is BF16 only, TP=PP=1
(data-parallel). The GEMM microbenchmark already shows the FP8 headroom:
4103 TFLOP/s (91% of the 4500 dense peak) vs 1493 BF16 — a 2.7x raw-GEMM gap
that training never touches.

### FP8 via Transformer Engine (TE)

- Use Megatron-LM's TE integration (`--fp8-format hybrid`: E4M3 fwd / E5M2 bwd
  with delayed scaling; on Blackwell also evaluate MXFP8 block scaling, which
  the 5th-gen tensor cores support natively).
- What to measure:
  - TFLOP/s/GPU and MFU against BOTH ceilings (BF16 2250 and FP8 4500);
  - the microbenchmark-to-training ratio (paper: 69% of gpu-fryer BF16)
    recomputed against gpu-fryer FP8;
  - loss curves vs BF16 baseline for numerical parity.
- Expectations/risks: FP8 speedup on a 1.3B model will be modest (small GEMM
  shapes, memory-bound kernels unchanged; Amdahl) — pair FP8 with a larger
  model (7B+) where GEMMs dominate. Watch loss-scale instabilities; keep an
  identical-seed BF16 control.

### Model parallelism (TP/PP)

- **Tensor parallel**: TP=2,4,8 within a node — exercises the 841 GB/s NVLink
  AllReduce the paper measures but never uses in training. Success: near-flat
  TFLOP/s/GPU up to TP=8 intra-node; quantify the drop if TP spans nodes
  (falls onto the 218 GB/s AllGather+ReduceScatter path, ~4x slower —
  validates the guidance table).
- **Pipeline parallel**: PP=2 across nodes — activation SendRecv rides the
  26.6 GB/s GDRDMA wall the paper derives; measure bubble fraction vs
  microbatch count and check it against the wall (e.g. ~37 ms per GB of
  activations).
- **Combined**: a 7B+ model with TP=8 (intra-node) x PP across nodes x DP with
  SHARP — one flagship run tying every measured ceiling to an end-to-end
  configuration. This single experiment would connect all three layers of the
  paper's characterization.
- **DP vs TP vs PP strategy comparison** (ddl addition beyond future-work.md):
  at fixed 16 GPUs / 7B / GBS 2048, run the same training under four layouts —
  pure DP=16, TP=8 intra-node x DP=2 (the guidance-table hybrid), PP=2 x DP=8,
  and TP=8 spanning nodes (stress case) — in BF16 and FP8. Validates the
  paper's parallelism guidance table (Table tab:guidance) end-to-end. Since 7B
  fits in one GPU, DP is expected to win; the deliverable is the measured cost
  of TP/PP for models that force them. Spread across phases 1–3 (see
  outline.md).
- **Micro-batch-size tuning, phase 0b** (ddl addition beyond future-work.md):
  the paper's MBS=4 convention is not necessarily optimal on B200, and an
  untuned BF16 baseline would undermine any FP8 speedup claim. Sweep
  MBS={2,4,8,16} x {BF16, FP8} on 7B first; adopt the best MBS per precision,
  keep an MBS=4 anchor. FP8's smaller activations may sustain a larger MBS
  than BF16 — a Paper B result on its own (memory headroom). This study is
  B200-only; model dims are already TE/FP8-clean (multiples of 32, vocab
  divisible by 128, head dim 128).

Together with SHARP-in-training, these are the highest-leverage additions for
an SC-level version: they add the production-scale, multi-parallelism evidence
the current 16-GPU data-parallel sweep lacks.

## Packaging: Paper B definition (from "one paper or two?")

Recommendation was **two papers, split by AXIS (compute vs communication)**:

- **Paper A — Communication & scale in production training**: SHARP-in-training
  + combined model parallelism (TP/PP/MoE AllToAll), scaled past 2 nodes.
  (Lives in future-work.md; not this project.)
- **Paper B — FP8 training on Blackwell** (THIS project): FP8 via Transformer
  Engine, end-to-end. Speedup vs BF16, MFU lift toward the 4500 TFLOP/s FP8
  ceiling, convergence/quality, and the model-size sweet spot. One thread:
  *"does the 91% FP8 GEMM microbenchmark translate to end-to-end training
  gains, and at what cost."*

Why the split:
- FP8 is a compute/precision study that also carries a convergence/quality
  dimension (does accuracy hold under E4M3/E5M2); SHARP + model parallelism
  are communication/collective studies with no numerics-quality question.
- Combining all three overflows a conference page budget and reads as "three
  loosely-related extensions."

Caveat that shapes THIS project: experimentally, FP8 and model parallelism
SHARE apparatus (both are Megatron config knobs — precision x TP/PP), whereas
SHARP is an orthogonal NCCL toggle. That is why the ddl experiment plan runs
FP8 x TP/PP together here (phases 1–4), even though for publication the model-
parallelism communication results may feed Paper A and the precision results
Paper B. The phase-4 flagship (TP=8 x PP=2 x DP ± SHARP, FP8) is the bridge
experiment between the two papers.

## Relevant context from the SC assessment (same file)

Reasons the current paper falls short of SC main track that THIS project
addresses:
- Training eval thin: one 1.3B model, data-parallel only, BF16, no
  FP8/Transformer Engine, no tensor/pipeline parallelism. → phases 1–4.
- "FP8 training + model parallelism to broaden the training story" is listed
  as one of the moves that would lift it toward SC Technical Papers.
- Scale remains the other big gap (needs >=100–1000 GPUs); this project stays
  at 1–4 nodes, so scale is Paper A's burden, not ours.

## Future-work items already flagged in the paper's Limitations that this
project covers

- Larger models with bigger GEMM shapes (raise MFU, shift
  microbench-to-training ratio) → 7b/13b presets.
- Tensor-/pipeline-parallel configurations (stress collectives the
  data-parallel sweep does not) → phases 2–3.
- FP8 training via Transformer Engine (lifts the GEMM ceiling the training gap
  is measured against) → phases 1, 5.

NOT covered here (Paper A / other): scaling past 2 nodes at large node counts,
SHARP-in-production study proper (only the phase-4 toggle), MoE AllToAll,
storage-tier characterization.

## SC-paper framing: main work and new findings (as of 2026-07-17)

### Main work (contributions)

1. **Microbenchmark-to-training translation study.** The predecessor paper
   measured 91%-of-peak FP8 GEMMs (4103 TFLOP/s) but trained only in BF16.
   This project measures how much of that 2.7x raw-GEMM gap survives
   end-to-end GPT pre-training on B200 — the first systematic answer for
   Blackwell-generation hardware in our setting.
2. **FP8 recipe comparison on Blackwell.** Delayed scaling vs tensorwise
   current scaling vs MXFP8 block scaling (the Blackwell-native format),
   run under identical model/data/seed conditions at 1.3B and 7B — with a
   convergence/numerical-parity check (phase 5) rather than throughput only.
3. **Model-size sweep** (1.3B → 7B → 13B) testing the Amdahl hypothesis that
   FP8 gains grow as GEMMs dominate the step.
4. **Measured cost of model parallelism** at fixed 16 GPUs / 7B / GBS 2048:
   pure DP vs TP=8xDP=2 vs PP=2xDP=8 vs TP=8-spanning-nodes, in both
   precisions — an end-to-end validation of the predecessor paper's
   parallelism guidance table (phases 2–3, in progress).
5. **Flagship 32-GPU run** (13B, TP=8 x PP=2 x DP=2, ±FP8 ±SHARP) touching
   every fabric ceiling the predecessor paper measured (NVLink AllReduce,
   GDRDMA SendRecv wall, IB AllReduce ± SHARP) in one configuration.
6. **Methodological hygiene**: MBS tuned per precision before any speedup
   claim (phase 0b); identical-seed BF16 control; precision-independent
   analytic TFLOP/s so BF16/FP8 are directly comparable; MFU reported
   against both ceilings (2250/4500).

### Main new findings so far (phases 0–1 complete)

1. **FP8 end-to-end speedup grows with model size: 1.10x @1.3B → 1.42x @7B**
   (delayed scaling, single node) — the model-size hypothesis confirmed.
   ~Half the 2.7x raw-GEMM gap survives end-to-end at 7B.
2. **FP8 MFU 63–64% vs BF16 44%** at 7B (1447 vs 1014 TFLOP/s/GPU): FP8 not
   only speeds up training, it uses the machine's compute ceiling *more
   efficiently*, because non-GEMM time shrinks relative to bigger effective
   math throughput.
3. **Recipe ranking is close (~3%)**: delayed scaling wins single-node at
   both sizes; MXFP8 narrowly leads at 2 nodes. Practical takeaway: recipe
   choice is second-order vs model size; delayed scaling is a safe default
   on Blackwell.
4. **FP8 gives NO extra micro-batch headroom under unsharded DP**: both
   precisions OOM at MBS>=8 on 7B because static weights+optimizer
   (~126 GB) dominate HBM, not activations. MBS=4 is optimal for both — a
   negative result that corrects the "FP8 frees memory" intuition for
   no_shard configurations.
5. **FP8 makes the interconnect matter MORE, not less**: gradient bytes are
   unchanged while compute shrinks, so the grads-sync share of the step
   grows (2-node: 1.24% BF16 → 1.70% FP8). Extrapolated to larger DP
   widths, FP8 raises the value of SHARP/fast collectives — the
   cross-paper bridge to the communication study.
6. **Numerical health**: zero NaN iterations across all recipes so far
   (throughput runs; full 5000-iter convergence parity is phase 5).

Pending: TP/PP scaling data (phase 2 running, jobs 163633–163648), PP
bubble-fraction validation (phase 3), flagship (phase 4), convergence
(phase 5).

## Is this sufficient for an SC paper? (assessment, 2026-07-17)

**Short answer: not for the SC main track on its own — but close to
sufficient for adjacent venues.**

### Why not SC main track

- **Scale is the core gap.** SC Technical Papers on training performance
  expect evidence at 100–1000+ GPUs; this project deliberately stays at
  1–4 nodes / 32 GPUs (scale is Paper A's burden, per the split). A 4-node
  study reads to SC reviewers as a careful lab experiment, not a
  supercomputing result — the interesting failure modes live at scale.
- **The novelty bar.** The strongest findings are rigorous but largely
  *confirmatory*: FP8 speedup growing with model size is expected Amdahl
  behavior; recipe rankings within ~3% are useful engineering guidance but
  not a research insight; NVIDIA and MLPerf have already published
  FP8-on-Blackwell training numbers. The best genuinely-new items — the
  no-MBS-headroom negative result and the grads-sync-share growth — are
  paragraphs, not a paper's spine.

### What it IS sufficient for

- **PMBS workshop at SC** (Performance Modeling, Benchmarking and
  Simulation) — near-perfect fit: rigorous benchmarking methodology,
  both-ceilings MFU accounting, microbench-to-training translation. Same
  audience, SC venue, realistic bar.
- **HPEC** (predecessor's venue), **IEEE Cluster, ISC** — a full paper with
  phases 2–5 complete is competitive there.
- **An SC poster** as a visibility play while building toward more.

### What would close the gap to SC main track

1. **Merge the scale story back in**: if Paper A's SHARP/multi-node work
   reaches even 16–32 nodes (128–256 GPUs), a combined "FP8 training at
   scale: when precision meets the interconnect" paper is much stronger
   than either alone. The grads-sync-share finding is the natural thesis:
   *FP8 shifts the bottleneck to communication — here's what that costs at
   scale.*
2. **A predictive model, not just measurements**: an analytic model taking
   model size, parallelism layout, and the measured ceilings that
   *predicts* FP8 end-to-end speedup within a few percent (validated
   across the phase 1–4 grid) would generalize beyond this cluster.
3. **Real convergence evidence**: 5000 iters on 1.3B is a smoke test;
   numerics reviewers will want longer horizons or a larger model to trust
   the parity claim.

**Recommendation**: finish phases 2–5; target **PMBS@SC or HPEC/Cluster
for Paper B as scoped**; treat SC main track as the goal for the merged
A+B paper if the scale becomes available.

**Venue reality check (2026-07-17):** we cannot get >32 GPUs (QOS cap;
the 28-node/224-GPU machine exists physically but larger allocations are
not available to us), so the merged-A+B-at-scale route to SC main track
is closed. PMBS@SC = peer-reviewed workshop co-located with SC (talk +
paper in the ACM/IEEE SC-Workshops proceedings); formally a notch below
a standalone conference like HPEC. For continuity with the HPEC 2026
predecessor paper, HPEC is the default target; PMBS@SC is the
audience-fit/visibility alternative.

## Extension plan: lifting Paper B to SC main track without scale (2026-07-17)

Since scale is unavailable, compete on contributions scale can't buy.
Ranked by leverage:

1. **Validated predictive model as the spine (essential, ~2–3 weeks).**
   Analytic model: measured ceilings (per-precision GEMM rates,
   NVLink/IB bandwidths, GDRDMA wall) + model dims + parallelism layout +
   precision → predicted step time and MFU. Validate to within a few
   percent across the full phase 1–4 grid, then *project* the FP8
   communication shift at 128–4096 GPUs. Converts "we measured our
   4-node cluster" into "how to reason about any Blackwell system" —
   the generalizable contribution SC requires, with scale claims carried
   by the model.
2. **FP4/NVFP4 training axis (novelty hook, ~2–4 weeks if TE supports).**
   NVFP4 training recipes only appeared late 2025; independent
   evaluation on production B200s barely exists. If TE 2.12 in the
   container exposes an NVFP4 recipe, extend the sweep to
   BF16 → FP8x3 → FP4: the first systematic precision *ladder* study
   on Blackwell. "First rigorous look at the new thing" is accepted at
   modest scale.
3. **Numerics depth, not just throughput (~3–4 weeks, needs real
   dataset).** Extend phase 5 into a real study: longer horizons at 1.3B
   AND 7B, per-layer amax/overflow statistics over training, where/when
   each recipe degrades, first/last-layer-BF16 ablations, a practical
   "when is each recipe safe" decision rule. Actionable numerics
   guidance is scarce in the FP8 literature; conditional/negative
   results here are publishable insight.
4. **Energy per token (cheap, ~1 week).** DCGM power sampling across the
   precision x parallelism grid; joules/token per precision. FP8's
   energy story is asserted more than measured; ties into SC's
   sustainability thread.
5. **Retry the scale ask once (0 effort, high variance).** One-time
   8–16-node reservation request framed as "validating the model's
   extrapolation" — a single 128-GPU point turns extrapolation into
   demonstrated prediction. If no, the paper stands on 1–4 nodes.

**Recommended package: 1 + 2 + 3 (+4 if time).** Resulting paper —
*"A validated model of low-precision LLM training on Blackwell: from FP8
to FP4, throughput to convergence"* — has a modeling contribution, a
first-look novelty axis, and numerics depth. Legitimate SC main-track
submission at 32 GPUs, but still a reach (~30–40% odds vs near-lock at
PMBS/HPEC). Realistic play: build it, submit to SC, let PMBS/HPEC be
the fallback — near-zero wasted work.

## B200 vs AMD: the strongest SC main-track angle (2026-07-17)

AMD GPUs are arriving soon on our side. **A rigorous B200-vs-AMD
low-precision training comparison is the strongest SC main-track angle
available** — better odds than the single-vendor extension package —
because **independent cross-vendor data is scarce and in high demand**:
nearly all published FP8-training numbers come from the vendors
themselves; every center weighing procurement wants this study from a
neutral party, and SC reviewers know it.

### Why it works

- **The comparison itself is the novelty.** "Does Blackwell's
  91%-of-peak FP8 GEMM advantage survive end-to-end training, and does
  AMD's equivalent?" — no neutral party has answered at matched rigor.
  Modest scale (8–32 GPUs per system) is far more acceptable for
  cross-vendor studies: the question is per-node capability and
  software-stack maturity, not fleet behavior.
- **Existing apparatus transfers.** The methodology (both-ceilings MFU,
  tuned-MBS-first, identical-seed controls, recipe sweeps, analytic
  TFLOP/s) is vendor-neutral by construction; rerunning on ROCm (AMD
  Megatron-LM fork / TE-for-ROCm) reuses everything.
- **The predictive model becomes cross-architecture** — validated on two
  vendors' measured ceilings, its generalizability claim gets much
  stronger.
- **The software-maturity gap is itself a headline finding** — "what
  actually works today for FP8/FP4 training on ROCm vs CUDA" is a
  question the whole community asks and nobody publishes cleanly.

### Four make-or-break conditions

1. **Which AMD GPU matters a lot.** MI355X (CDNA4) is the true
   Blackwell-generation peer (native FP4/FP6/MXFP) — clean comparison.
   MI300X/MI325X is a generation behind (no FP4): still publishable but
   must be framed as cross-generation explicitly, else reviewers call it
   unfair to AMD.
2. **Fairness methodology is make-or-break.** Equal tuning effort on
   both stacks, documented; matched software versions where possible.
   "NVIDIA-tuned vs AMD-defaults" is the instant-reject failure mode.
   Doing this well is itself a contribution.
3. **Recipe parity may not exist on ROCm TE** (delayed vs current vs MX
   formats) — map what is actually available before promising the full
   sweep.
4. **Budget real bring-up time** — the ROCm Megatron/TE stack is a
   genuine porting effort, not a container swap.

### Verdict

**B200 vs AMD (ideally MI355X) + the existing FP8 grid + the predictive
model across both architectures + a numerics parity check = a
legitimately strong SC main-track submission** — roughly even odds or
better with clean execution, vs ~30–40% for the single-vendor package.
PMBS/HPEC fallback stays intact. If the AMD hardware timeline fits the
SC deadline cycle, this is the plan to commit to.

## Extending into distributed-deep-learning research: strategy & roadmap (2026-07-17)

Q: would broader DDL research help reach SC main track or other
high-quality venues? A: **yes, but selectively** — extend along axes
where our assets are rare, don't pivot into the mainstream.

### Where NOT to go

Core DDL systems research (new parallelism strategies, schedulers,
overlap/compression techniques, framework engineering) is dominated by
industrial labs (NVIDIA/Megatron, Microsoft/DeepSpeed, Meta/PyTorch,
ByteDance, Alibaba) publishing at MLSys/SC/OSDI with thousands of GPUs.
A 32-GPU academic entry competing on "our technique is faster" loses in
review regardless of quality. Similarly, algorithmic DDL (async SGD,
gradient compression, local SGD) at ICML/NeurIPS demands real theory or
large-scale validation — neither plays to our position.

### Where extension works — two rare assets

Dual-vendor Blackwell-class hardware under one roof + the
measured-ceilings characterization methodology. These support:

1. **Cross-vendor characterization + modeling** — the AMD plan above
   (SC main-track attempt; PMBS/HPEC fallback).
2. **Heterogeneous cross-vendor training — the most interesting "more
   DDL" direction available to us.** Once B200s and AMD GPUs coexist in
   one facility, *training a single job across both vendors* is a real,
   under-explored systems problem: collective interop (NCCL vs RCCL, no
   common fabric library; UCC/MPI paths), load balancing across unequal
   per-step throughput, precision-format mismatches (MXFP8 vs AMD
   formats). Very few groups worldwide can attempt this experimentally.
   A legitimate SC/MLSys/EuroSys-class contribution at modest scale —
   the novelty is the capability and the systems insight, not GPU count.
3. **Communication-centric studies** (SHARP/in-network aggregation for
   DDL — Paper A's core): solid at IPDPS/Cluster/TPDS; SC-competitive
   only with more scale than we have.
4. **IISWC** (IEEE Int'l Symposium on Workload Characterization) — an
   unconsidered venue: the precision x parallelism x vendor grid is
   exactly their scope; respected and attainable.

### Journals

**IEEE TPDS** (flagship parallel/distributed journal), **JPDC**, or
**IJHPCA** take extended versions of conference papers (+30% new
material). Paper B + AMD comparison + predictive model = a strong TPDS
submission that doesn't compete with the conference plans.

### Roadmap (three shots at top venues from one apparatus line)

- **Now → fall 2026:** finish Paper B → HPEC or PMBS (locked plan).
- **AMD arrival → SC'27 deadline (~spring 2027):** cross-vendor
  comparison + predictive model → **SC main-track attempt #1**.
- **In parallel/after:** heterogeneous NVIDIA+AMD co-training study →
  **SC/MLSys attempt #2** — the "more DDL research" extension actually
  worth investing in.
- **Any time:** consolidated journal version → **TPDS**.

Each step builds on the last; none fights industry on its home turf.

## No auto-transfer from SC main track to PMBS (2026-07-17)

Q: if Paper B is rejected from SC main track, does it get transferred to
PMBS@SC automatically? **A: no.**

- SC has **no standing auto-transfer/cascade** from Technical Papers to
  PMBS (unlike some journals that bounce rejects to sister venues).
  Separate submissions, separate deadlines, separate committees,
  separate reviews. A main-track reject just ends there.
- **Deadline mechanics matter.** Main-track paper deadlines are
  typically spring, notifications ~summer. PMBS (and other SC workshops)
  usually have their own summer deadlines — sometimes *after*
  main-track notification, sometimes overlapping or before. Some years
  you CAN resubmit the rejected paper to PMBS in the same cycle, but
  only if PMBS's deadline hasn't passed, and it is a fresh, manual
  submission — never routed automatically.
- Occasionally a workshop PC will informally *invite* strong-but-rejected
  main-track papers — this happens at some conferences but is
  discretionary courtesy, not something to plan around.
- Resubmit manually, and revise first — use the main-track reviews to
  strengthen the paper rather than resending the identical PDF.
- **Double-submission caution:** don't have the paper under review at
  both simultaneously; wait for the main-track decision, then submit to
  PMBS if its deadline is still open.

**Action item:** check the actual SC'27 dates before committing to the
submit-to-SC-then-fallback-to-PMBS plan — specifically whether the PMBS
deadline falls after main-track notification. If PMBS closes BEFORE
main-track decisions land (happens some years), the real fallback for
that cycle is **HPEC** or next year's PMBS, not "PMBS after the reject."

## Does FP8 match the baseline's quality while accelerating? (status, 2026-07-19)

**The speed half is proven; the quality half is not yet — by design of
the plan.**

- **Baseline is BF16, not FP16.** BF16 is the standard training dtype on
  this hardware (the paper's convention). All FP8 modes keep BF16 as the
  base dtype and master weights; only the GEMMs run in FP8 (E4M3 fwd /
  E5M2 bwd, or MXFP8 block scaling).
- **Acceleration: yes, measured thoroughly.** FP8 gives 1.42x at 7B
  (1412 vs 996 TFLOP/s/GPU), 1.35x under PP, MFU 44% → 63%, across 40+
  successful runs (phases 0–3).
- **"Not losing anything important": not yet demonstrated by us.**
  Current evidence is weak-form only: zero NaN iterations in every FP8
  run (~30 runs), sane loss values, stable training for 100 iters on
  MOCK data. That rules out gross instability but cannot support a
  parity claim — 100 iters on mock data says nothing about convergence
  quality over a real horizon.
- **The real answer is phase 5** (not yet run; needs the real tokenized
  dataset): 5000 iters, real data, identical seed, BF16 vs fp8ds vs
  MXFP8, checking that FP8 loss curves overlay BF16 within noise.
  Literature (NVIDIA TE) says parity generally holds with these recipes,
  but independently verifying it is one of Paper B's contributions.
  Caveat already noted in the SC assessment: 5000 iters at 1.3B is
  itself a smoke test — a credible parity claim wants longer horizons
  or 7B.

**Bottom line: compute acceleration confirmed; numerical equivalence is
currently an assumption borrowed from the literature, pending phase 5.**

## Phase 4b anomaly diagnostic: partial result, H3 rejected (2026-07-22)

Context: the phase-4 flagship grid found ONE inversion in 60+ runs — at 13b
TP2xPP2xDP8/32GPU/GBS4096, FP8 measured SLOWER than BF16 (391 vs 486
TFLOP/s/GPU), the only such case in the whole project. A 9-job diagnostic
(watch_phase4b.sh) tests 4 hypotheses: H1 one-off artifact, H2 amax overhead
scaling with microbatch count, H3 TP+PP interaction, H4 recipe-specific
(mxfp8 vs delayed). 7 of 9 jobs are 4-node and serialize behind the 32-GPU/
user QOS cap; 2 are 2-node and ran first.

**H3 (TP+PP interaction) REJECTED.** The 2-node H3 pair — 13b, TP=2 x DP=8,
**PP=1** (no pipeline parallelism at all), 16 GPU, GBS 2048, m=64 — still
shows the inversion:

| prec | TFLOP/s/GPU | fwd (ms) | bwd (ms) |
|---|---|---|---|
| bf16 (171252) | 499 | 20094 | 20039 |
| fp8ds (171253) | 376 (**0.75x**) | 28496 | 26456 |

Both clean: nan=0, no OOM, no crash. Removing PP does not remove the
slowdown, so it is not a TP+PP interaction. The timers localize it to
**compute itself**: FP8 forward+backward is ~1.3-1.4x SLOWER than BF16 here —
with PP=1 there is no cross-node activation SendRecv to blame, so this is a
genuine FP8-arithmetic-slower-than-BF16 result at this shape, not a
communication artifact.

**Open thread, not yet explained**: the single-node 13b/TP=2 FP8 run from
phase 2 (job 163645, DP=4, GBS 1024, same MBS=4/m=64 per-GPU shape) measured
1330 TFLOP/s — 3.5x faster than this 2-node run at an identical per-GPU
compute shape. Per-GPU compute should not depend on node count, so something
about going multi-node specifically triggers the FP8 compute penalty at
13b/TP=2. Remaining hypotheses (H1 repeat: 171246/247; H2 amax-vs-m sweep:
171248-251; H4 mxfp8: 171254) may narrow this once the 7 pending 4-node jobs
clear the QOS queue.

**Standing caveat unchanged**: do not use the phase-4 32-GPU FP8 numbers in
the paper until all 9 jobs finish and results-phase4b-anomaly.md issues a
verdict.

---
See `outline.md` for the experiment plan and `CLAUDE.md` for working notes;
source: `../paper/future-work.md`.
