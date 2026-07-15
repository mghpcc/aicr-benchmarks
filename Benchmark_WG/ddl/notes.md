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

---
See `outline.md` for the experiment plan and `CLAUDE.md` for working notes;
source: `../paper/future-work.md`.
