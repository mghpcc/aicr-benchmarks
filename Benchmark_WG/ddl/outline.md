# FP8 Training + Model Parallelism on AICR Blackwell — Project Outline (Paper B)

Follow-on to `paper/aicr_benchmarks_v7.tex`, implementing the "FP8 training
(Transformer Engine) + model parallelism" plan in `paper/future-work.md`.
Target: **Paper B — "FP8 training on Blackwell"**.
Status as of 2026-07-21: phases 0–4 done (phase 4's SHARP arm abandoned as
unworkable for TP/PP configs — see CLAUDE.md); phase 4b anomaly diagnostic
queued; phase 5 pending dataset prep. `outline.pdf` regenerates automatically
on every edit to this file (PostToolUse hook, see `.claude/settings.local.json`).

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

## Progress (updated 2026-07-17)

| Phase | Status | Headline result | Results file |
|---|---|---|---|
| 0 smoke | ✅ done | all 4 recipes run, FP8 engaged, 0 NaN; fp8ds led 1.13x @1.3b | `results-phase0-smoke.md` |
| 0b MBS tune | ✅ done | **MBS=4 wins** both precisions; MBS≥8 OOMs both (static state dominates, no FP8 headroom) | `results-phase0b-mbs.md` |
| 1 precision | ✅ done | **FP8 1.10x @1.3b → 1.42x @7b**; MFU 44%→63%; **fp8ds** best recipe; 2-node grads-sync share 1.24%(bf16)→1.70%(fp8) | `results-phase1-precision.md` |
| 2 TP + strategy | ✅ done | TP not free even on NVLink (7b TP1→8: fp8 1418→396); FP8 gain vanishes at TP=8; inter-node TP cliff 1.8–2.4x; DP beats TP8xDP2 by 2.4–3.3x at 16 GPU (guidance table validated); 13b: use minimum TP that fits | `results-phase2-tp.md` |
| 3 PP | ✅ done | bubble tracks 1/(m+1) (fp8 at/below ideal, bf16 ~1.5x); strategy table complete: DP 986/1337 > PPxDP 942/1270 (−4–5%) >> TPxDP 408/405; PP preserves FP8's 1.35x win, TP destroys it | `results-phase3-pp.md` |
| 4 flagship | 🔄 partly done | SHARP-off rows done (13b 32-GPU: TP8 layout 532/582, TP2 layout 486/391 bf16/fp8); 13b FP8 speedup at TP=2 = **1.42x**; timer overhead ~0% (so the 1.3b gap vs the paper is NOT instrumentation). 4 SHARP jobs crashed (NCCL_ALGO no-fallback) → fixed + resubmitted 171240–171243 | `results-phase4-flagship.md` |
| 4b anomaly | 🔄 running | jobs 171246–171254 diagnosing FP8-slower-than-BF16 at TP2xPP2xDP8 (repeat / microbatch-count / drop-PP / mxfp8) | `results-phase4b-anomaly.md` (auto) |
| 5 convergence | ⬜ (needs dataset) | | |

**Decisions locked in:** MBS=4 everywhere (default, no change needed); **fp8ds**
is the FP8 recipe for phases 2–4 (mxfp8 kept as secondary — it narrowly led at
2 nodes). Core Paper B claim confirmed: FP8 speedup grows with model size.

**Note (2026-07-17):** the first phase-2 submission (163247–163262) failed
instantly — unrelated to this project, your home directory quota filled up
(driven by `~/.apptainer` container cache, not by anything in `ddl/`, which
stayed under 10 MB throughout). Fixed by clearing the apptainer cache (42 GB,
safely re-downloadable, your `.sif` images untouched) and resubmitting as
163633–163648. No experiment data was lost. Worth periodically checking
`quota -s` on the head node if jobs ever fail instantly at launch.

## Experiment phases (scripts are in this directory)

### Phase 0 — Smoke test (do first) — ✅ DONE
One 20-iteration job per FP8 recipe (b200-batch) to confirm TE engages and
logs parse. ~1 h.
```
sbatch -p b200-batch -t 1:00:00 -N 1 -n 1 --gpus-per-node=b200:8 \
    --output=output/out.%N-%J job_ddl.sh 1.3b fp8ds 1 1 1024 4 20
```

### Phase 0b — Micro-batch-size tuning — `submit_phase0b_mbs.sh` — ✅ DONE
Tune the baseline before any FP8-vs-BF16 claim: 7B, 1 node x 8, GBS 1024,
MBS={2,4,8,16} x {BF16, FP8}, 20 iters (b200-batch). **8 jobs**, ~15 min each.
Expected OOMs are a result: BF16 likely OOMs at MBS≥8 (7B unsharded DP holds
~126 GB static); if FP8's smaller activations sustain a larger MBS, that is a
Paper B finding in itself. Outcome: best MBS per precision adopted in phases
1–4 (one MBS=4 job per precision kept in phase 1 as anchor to the paper's
convention). Model dims are already TE/FP8-clean (multiples of 32, vocab
divisible by 128, head dim 128); seq stays 2048 for paper comparability.
**Result:** MBS=4 won both precisions (bf16 1014, fp8ds 1447 TFLOP/s); MBS≥8
OOM'd for both — the FP8-headroom effect did NOT appear because static
weights+Adam (~126 GB) dominate under no_shard, not activations.

### Phase 1 — Precision sweep (core result) — `submit_phase1_precision.sh` — ✅ DONE
{1.3B, 7B} x {BF16, FP8-delayed, FP8-current-scaling, MXFP8}, 1 node x 8 GPU,
pure DP, GBS 1024. **8 jobs** (+3 optional 2-node jobs: FP8 shrinks compute but
not gradient bytes, so the grads-sync *share* grows — measure it).
Deliverable: TFLOP/s/GPU and MFU vs BOTH ceilings (2250 BF16 / 4500 FP8);
microbench-to-training ratio recomputed against gpu-fryer FP8; recipe ranking.
**Result:** FP8 speedup 1.10x @1.3b → 1.42x @7b (1 node) → 1.38x @7b (2 node);
FP8 MFU 63% vs BF16 44%. Recipe ranking: fp8ds ≥ fp8cs ≥ mxfp8 within ~3%
(fp8ds wins single-node; mxfp8 narrowly leads at 2 nodes). 2-node grads-sync
share: bf16 1.24% → fp8 1.67–1.70% (FP8 makes interconnect matter more).

### Phase 2 — Tensor parallelism + strategy comparison — `submit_phase2_tp.sh` — 🔄 RUNNING
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

### Phase 4 — Flagship combined run — `submit_phase4_flagship.sh` — ✅ DONE (SHARP arm abandoned)
13B, 4 nodes / 32 GPUs, GBS 4096, x {BF16, FP8}, in TWO layouts
(revised 2026-07-19 from the phase 2/3 findings):
- **Stress**: TP=8 x PP=2 x DP=2 — the original "touch every ceiling" config.
- **Throughput-optimal**: TP=2 x PP=2 x DP=8 — added because phase 2 showed
  TP=8 destroys throughput and the FP8 win ("minimum TP that fits"), and
  phase 3 showed PP is nearly free; DP=8 also gives SHARP a real workload.
**SHARP outcome (2026-07-21): abandoned for TP/PP configs.** The recipe is a
catch-22 with TP>1: forcing CollNet with no fallback crashes intra-node TP
AllReduces; adding a ring fallback makes NCCL's tuner pick ring everywhere
(job 171240: zero CollNet use, grads-sync unchanged), AND the global
NCCL_PROTO=Simple slowed the TP-8 config 4.3x. grads-sync is only ~0.3% of
step at 32 GPUs, so SHARP would be unmeasurable here anyway.
SHARP-in-training needs a pure-DP (TP=1) design → Paper A scope.
→ results-phase4-flagship.md (complete 2x2 grid, layout x precision).
Companion jobs: 13B BF16 TP=2 single-node anchor (completes the 13B FP8
speedup at optimal TP; an OOM would itself show FP8's memory headroom under
TP), and a 1.3B timing-level 0-vs-2 diagnostic (phase 1's 782 TFLOP/s vs the
paper's 986–1032 — quantifies per-rank-timer overhead).

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
- SHARP + model parallelism is a dead end (confirmed 2026-07-21): CollNet-only
  crashes TP comms, ring fallback silently disables SHARP, NCCL_PROTO=Simple
  cripples TP throughput 4.3x. Test SHARP only in pure-DP configs.
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
