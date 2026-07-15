# FP8 + Model Parallelism Benchmarks (Paper B)

FP8 training (Transformer Engine) and TP/PP model parallelism on AICR B200
nodes, via Megatron-LM + Slurm + Apptainer. Follow-on to
`../paper/aicr_benchmarks_v7.tex`; plan in `outline.md`, background in
`notes.md`, working notes in `CLAUDE.md`.

## Prerequisites

- Megatron-LM checkout: `../megatron-lm/Megatron-LM`
- Container: `../megatron-lm/imag/pytorch_26.02-py3.sif` (TE 2.12.0 included)
- No code changes needed — everything is CLI flags and env vars.

## Scripts

| Script | Role |
|---|---|
| `job_ddl.sh` | sbatch wrapper (Apptainer, IB binds, CUDA_VISIBLE_DEVICES fix) |
| `run_ddl.sh` | runs inside the container; builds the torchrun command |
| `submit_phase*.sh` | submit one experiment phase each (below) |
| `parse_results.py` | output logs → markdown results table |

## Submitting a single job

```bash
sbatch [slurm opts] job_ddl.sh MODEL PREC TP PP GBS [MBS] [ITERS] [SEED] [SHARP]
```

| Arg | Values | Default |
|---|---|---|
| MODEL | `1.3b` (paper model) \| `7b` \| `13b` (needs TP≥2) | required |
| PREC | `bf16` \| `fp8ds` (hybrid delayed) \| `fp8cs` (tensorwise) \| `mxfp8` | required |
| TP, PP | tensor / pipeline parallel size | required |
| GBS | global batch size — convention: 128 × total GPUs | required |
| MBS, ITERS, SEED | micro batch, iterations, seed | 4, 100, 1234 |
| SHARP | `1` = SHARP CollNet on DP AllReduce (≥2 nodes, 8 GPU/node only) | 0 |

Examples:

```bash
# 1 node x 8 GPU, 7B, FP8 delayed scaling, pure DP
sbatch -N 1 -n 1 --gpus-per-node=b200:8 --output=output/out.%N-%J job_ddl.sh 7b fp8ds 1 1 1024

# 2 nodes x 8, TP=8 intra-node x DP=2, BF16
sbatch -N 2 -n 2 --gpus-per-node=b200:8 --output=output/out.%N-%J job_ddl.sh 7b bf16 8 1 2048

# 4 nodes x 8, 13B flagship: TP=8 x PP=2 x DP=2, FP8 + SHARP
sbatch -N 4 -n 4 --gpus-per-node=b200:8 --output=output/out.%N-%J job_ddl.sh 13b fp8ds 8 2 4096 4 100 1234 1
```

Constraints checked by `run_ddl.sh`: total GPUs divisible by TP×PP; GBS
divisible by MBS×DP; `13b` requires TP≥2 (optimizer state exceeds 193 GB HBM).
`--sequence-parallel` is added automatically when TP>1.

## Running the study

```bash
cd ~/benchmarks/ddl

# Phase 0 -- smoke test first (verify FP8 engages, logs parse)
sbatch -p b200-batch -t 1:00:00 -N 1 -n 1 --gpus-per-node=b200:8 \
    --output=output/out.%N-%J job_ddl.sh 1.3b fp8ds 1 1 1024 4 20

bash submit_phase0b_mbs.sh                 # MBS tuning: 7B,
                                           # MBS={2,4,8,16} x {bf16,fp8ds};
                                           # adopt best MBS per precision in
                                           # phases 1-4 (OOMs expected, see
                                           # script header)          -> 8 jobs
bash submit_phase1_precision.sh output 1   # precision sweep; arg2=1 adds the
                                           # 2-node DP=16 jobs (needed for the
                                           # strategy comparison)   -> 11 jobs
bash submit_phase2_tp.sh                   # TP sweep + TP=8xDP=2 hybrid + 13B -> 16 jobs
bash submit_phase3_pp.sh                   # PP=2 bubble sweep                 -> 8 jobs
bash submit_phase4_flagship.sh             # 32-GPU combined, ±FP8 ±SHARP      -> 4 jobs
bash submit_phase5_convergence.sh /path/to/dataset_dir   # loss parity         -> 3 jobs
```

All submit scripts take an optional output dir as first arg (default `output`).

**Phase 5 needs real data** (mock data can't show convergence): tokenize a
corpus with `Megatron-LM/tools/preprocess_data.py`, write `data_args.sh` here
defining `data_par` (template in the script header), then pass the dataset dir
— it is bind-mounted into the container via `EXTRA_BIND`.

## Results

```bash
python3 parse_results.py output    # markdown table to stdout
```

Reports last-iteration TFLOP/s/GPU (analytic FLOPs / step time — precision-
independent, so BF16 vs FP8 is directly comparable), step ms, MFU vs both
ceilings (BF16 2250 / FP8 4500 TFLOP/s), grads-sync ms and % of step, lm loss.

Key cross-phase table to assemble: DP=16 vs TP=8×DP=2 vs PP=2×DP=8 vs
TP=8-spanning at fixed 16 GPUs / 7B / GBS 2048 (phases 1–3).

## Troubleshooting

- **FP8 job crashes at startup**: TE/Megatron recipe assert — check
  `--fp8-format`/`--fp8-recipe` combo in `run_ddl.sh` (mxfp8 uses `e4m3`).
- **SHARP job crashes in NCCL init**: CollNet is forced with no ring fallback;
  check `NCCL_DEBUG=INFO` output for the `libnccl-net.so` plugin load line.
  Full recipe: `../megatron-lm/Megatron-LM/notes-sharp.md`.
- **Multi-node hang in rendezvous**: keep `--exclusive` (the deterministic
  CUDA_VISIBLE_DEVICES fix in `job_ddl.sh` depends on it).
- **No SHARP speedup**: needs ≥2 nodes, all 8 NICs/node, DP>1, and gradient
  buckets above the ~4 MB crossover.
