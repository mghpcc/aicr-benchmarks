# FP8 Training + Model Parallelism on AICR Blackwell — Project Outline (Paper B)

Follow-on to `paper/aicr_benchmarks_v7.tex`, implementing the "FP8 training
(Transformer Engine) + model parallelism" plan in `paper/future-work.md`.
Target: **Paper B — "FP8 training on Blackwell"**.

## Research questions

1. **Does the FP8 microbenchmark translate?** gpu-fryer shows 4103 TFLOP/s FP8
   (91% of the 4500 peak) vs 1493 BF16 — a 2.7x raw-GEMM gap that the paper's
   BF16-only training never touches. How much survives end-to-end?
2. **Which recipe wins on Blackwell?** Delayed scaling vs tensorwise current
   scaling vs native MXFP8 block scaling (5th-gen tensor cores).
3. **Where is the model-size sweet spot?** 1.3B (paper model) → 7B → 13B:
   FP8 gains should grow as GEMMs dominate (Amdahl).
4. **Model parallelism**: does training finally exercise the measured fabric
   ceilings — TP on the 841 GB/s NVLink AllReduce, PP on the 26.6 GB/s GDRDMA
   wall — and do the paper's guidance-table predictions hold?
5. **Numerical parity**: do FP8 loss curves track BF16 at identical seed?

## Experiment phases (scripts are in this directory)

### Phase 0 — Smoke test (do first)
One 20-iteration job per FP8 recipe (b200-batch) to confirm TE engages and
logs parse. ~1 h.
```
sbatch -p b200-batch -t 1:00:00 -N 1 -n 1 --gpus-per-node=b200:8 \
    --output=output/out.%N-%J job_ddl.sh 1.3b fp8ds 1 1 1024 4 20
```

### Phase 0b — Micro-batch-size tuning — `submit_phase0b_mbs.sh`
Tune the baseline before any FP8-vs-BF16 claim: 7B, 1 node x 8, GBS 1024,
MBS={2,4,8,16} x {BF16, FP8}, 20 iters (b200-batch). **8 jobs**, ~15 min each.
Expected OOMs are a result: BF16 likely OOMs at MBS≥8 (7B unsharded DP holds
~126 GB static); if FP8's smaller activations sustain a larger MBS, that is a
Paper B finding in itself. Outcome: best MBS per precision adopted in phases
1–4 (one MBS=4 job per precision kept in phase 1 as anchor to the paper's
convention). Model dims are already TE/FP8-clean (multiples of 32, vocab
divisible by 128, head dim 128); seq stays 2048 for paper comparability.

### Phase 1 — Precision sweep (core result) — `submit_phase1_precision.sh`
{1.3B, 7B} x {BF16, FP8-delayed, FP8-current-scaling, MXFP8}, 1 node x 8 GPU,
pure DP, GBS 1024. **8 jobs** (+3 optional 2-node jobs: FP8 shrinks compute but
not gradient bytes, so the grads-sync *share* grows — measure it).
Deliverable: TFLOP/s/GPU and MFU vs BOTH ceilings (2250 BF16 / 4500 FP8);
microbench-to-training ratio recomputed against gpu-fryer FP8; recipe ranking.

### Phase 2 — Tensor parallelism + strategy comparison — `submit_phase2_tp.sh`
7B x {BF16, FP8} x TP={1,2,4,8} intra-node; TP=8 *spanning* 2 nodes (4 GPU/node)
to quantify the drop off NVLink onto the 218 GB/s inter-node path; TP=8
intra-node x DP=2 across 2 nodes (the guidance-table hybrid); 13B (needs
TP≥2 to fit) at TP={2,4,8}. **16 jobs**.
Success: near-flat TFLOP/s/GPU to TP=8 intra-node; explainable inter-node drop;
13B shows larger FP8 win (bigger GEMMs).

**DP vs TP vs PP strategy comparison** (spans phases 1–3): at fixed 16 GPUs /
7B / GBS 2048, only the parallelism layout changes — validates the paper's
guidance table end-to-end. Since 7B fits in one GPU, DP should win; the result
is the *measured cost* of TP/PP for when a model forces them.

| Strategy | Config (2 nodes x 8) | Submitted by |
|---|---|---|
| Pure DP | DP=16 | phase 1 (`with2node=1`) |
| TP hybrid (guidance table) | TP=8 intra-node x DP=2 | phase 2 |
| PP hybrid | PP=2 x DP=8 | phase 3 (GBS 2048 job) |
| TP stress | TP=8 spanning nodes (8 GPUs) | phase 2 |

### Phase 3 — Pipeline parallelism — `submit_phase3_pp.sh`
7B, PP=2 across 2 nodes (stage boundary = node boundary), DP=8, microbatch
count m = 8/16/32/64 via GBS = 256..2048, x {BF16, FP8}. **8 jobs**.
Success: bubble fraction follows (PP-1)/(m+PP-1); SendRecv time consistent with
the 26.6 GB/s wall (~37 ms/GB of activations).

### Phase 4 — Flagship combined run — `submit_phase4_flagship.sh`
13B, TP=8 (NVLink) x PP=2 (GDRDMA wall) x DP=2 (IB AllReduce ± SHARP),
4 nodes / 32 GPUs, x {BF16, FP8} x {SHARP off/on}. **4 jobs**.
One configuration touching every measured ceiling of the paper — the marquee
figure for Paper B (and a bridge to Paper A's SHARP story).

### Phase 5 — Convergence / numerical parity — `submit_phase5_convergence.sh`
1.3B, 5000 iters, **real data** (needs one-time dataset prep, see script
header), identical seed, {BF16, FP8-delayed, MXFP8}. **3 jobs**, ~3 h each.
Success: FP8 loss curves overlay BF16 within noise; no loss-scale/NaN events.

Total: ~50 jobs, mostly 1–2 nodes x ≤3 h; only phase 4 needs 4 nodes.

## Metrics reported (extracted by `parse_results.py`)

- Last-iteration TFLOP/s/GPU (analytic FLOPs / step time — precision-independent,
  so BF16 and FP8 are directly comparable), step time (ms), lm loss
- MFU against both ceilings: x/2250 (BF16) and x/4500 (FP8)
- grads-sync ms and % of step (from `--timing-log-level 2` per-rank timers)
- Weak-scaling efficiency vs matching single-node baseline (multi-node runs)

## Expected headline results

| Claim | Evidence |
|---|---|
| FP8 end-to-end speedup ~1.3–1.6x at 7B+, less at 1.3B | Phase 1/2 (Amdahl analysis) |
| FP8 memory headroom enables larger micro-batches than BF16 | Phase 0b |
| Recipe ranking on Blackwell (MXFP8 vs delayed vs current) | Phase 1 |
| TP flat intra-node, quantified cliff when spanning nodes | Phase 2 |
| DP vs TP vs PP ranked at fixed 16 GPUs; guidance table validated end-to-end | Phases 1–3 |
| PP bubble matches model; activation SendRecv hits GDRDMA wall | Phase 3 |
| All ceilings tied together in one 32-GPU FP8 run | Phase 4 |
| FP8 numerically safe (loss parity) | Phase 5 |

## Risks

- MXFP8 flag combos may hit TE/Megatron asserts → smoke test first.
- FP8 gain at small GEMM shapes may be underwhelming → that *is* a result
  (sweet-spot analysis); 13B strengthens it.
- SHARP CollNet forced with no fallback → crash instead of degrade; verify
  plugin load (notes in `../megatron-lm/Megatron-LM/notes-sharp.md`).
- 4-node allocation queue time; phase 5 needs dataset prep work.

## How to run

```bash
cd ~/benchmarks/ddl
# 0. smoke test (see Phase 0 above)
bash submit_phase0b_mbs.sh                 # then adopt best MBS per precision in phases 1-4
bash submit_phase1_precision.sh            # then: python3 parse_results.py output
bash submit_phase2_tp.sh
bash submit_phase3_pp.sh
bash submit_phase4_flagship.sh
bash submit_phase5_convergence.sh /path/to/dataset_dir   # after dataset prep
```

Working notes / agent memory for this project: `CLAUDE.md` (kept in sync).
