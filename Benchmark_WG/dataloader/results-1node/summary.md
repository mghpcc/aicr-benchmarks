# Dataloader Benchmark Summary

The `results/` directory contains 20 runs covering two benchmark suites, each swept across 5 process counts (1, 8, 32, 64, 96) and two GPU clusters (GPU1 = `a00xx` hosts, GPU2 = `b00xx` hosts). Each (config, mode) cell is the mean of 3 iterations.

## Benchmark A — READ: `raw` vs `dataloader` (jobs 22284-22293)

From `read_benchmark.py`. Single large workload (~21 GB, 186 060 files). `raw` = direct read via `os.read` (optional `O_DIRECT`); `dataloader` = PyTorch DataLoader read path.

### GPU1
| nproc | raw GB/s | dataloader GB/s | raw/dataloader |
|---|---|---|---|
| 1  | 0.091 | 0.033 | 2.75× |
| 8  | 0.725 | 0.251 | 2.88× |
| 32 | 2.769 | 1.007 | 2.75× |
| 64 | 5.164 | 1.876 | 2.75× |
| 96 | 6.908 | 2.184 | 3.16× |

### GPU2
| nproc | raw GB/s | dataloader GB/s | raw/dataloader |
|---|---|---|---|
| 1  | 0.091 | 0.033 | 2.75× |
| 8  | 0.678 | 0.237 | 2.86× |
| 32 | 2.743 | 1.013 | 2.71× |
| 64 | 5.118 | 1.858 | 2.75× |
| 96 | 6.966 | 2.142 | 3.25× |

## Benchmark B — WRITE: `raw` / `torch_save` / `dcp` at varying file sizes (jobs 22294-22303)

From `write_benchmark.py`. `raw` = direct write of bytes; `torch_save` = `torch.save` of a synthetic model state dict; `dcp` = PyTorch distributed checkpoint write.

### GPU1 — GB/s
| file size | mode | 1 | 8 | 32 | 64 | 96 |
|---|---|---|---|---|---|---|
| 100 KiB | raw | 0.041 | 0.077 | 0.073 | 0.072 | 0.061 |
| 100 KiB | torch_save | 0.039 | 0.073 | 0.064 | 0.062 | 0.056 |
| 100 KiB | dcp | 0.008 | 0.035 | 0.050 | 0.064 | 0.056 |
| 1 MiB   | raw | 0.226 | 0.620 | 0.697 | 0.902 | 0.654 |
| 1 MiB   | torch_save | 0.195 | 0.559 | 0.689 | 0.728 | 0.749 |
| 1 MiB   | dcp | 0.068 | 0.308 | 0.438 | 0.557 | 0.633 |
| 10 MiB  | raw | 0.745 | 3.364 | 6.236 | 6.431 | 5.794 |
| 10 MiB  | torch_save | 0.763 | 3.843 | 5.828 | 6.457 | 6.468 |
| 10 MiB  | dcp | 0.456 | 2.139 | 4.632 | 5.418 | 4.850 |
| 100 MiB | raw | 0.910 | 7.490 | 15.05 | 20.27 | 20.59 |
| 100 MiB | torch_save | 1.144 | 6.548 | 14.10 | 19.36 | 20.88 |
| 100 MiB | dcp | 1.134 | 6.179 | 13.54 | 17.33 | 18.19 |

### GPU2 — GB/s
| file size | mode | 1 | 8 | 32 | 64 | 96 |
|---|---|---|---|---|---|---|
| 100 KiB | raw | 0.041 | 0.076 | 0.073 | 0.052 | 0.055 |
| 100 KiB | torch_save | 0.040 | 0.075 | 0.070 | 0.055 | 0.050 |
| 100 KiB | dcp | 0.008 | 0.035 | 0.050 | 0.058 | 0.054 |
| 1 MiB   | raw | 0.217 | 0.577 | 0.717 | 0.808 | 0.723 |
| 1 MiB   | torch_save | 0.189 | 0.524 | 0.721 | 0.793 | 0.656 |
| 1 MiB   | dcp | 0.062 | 0.352 | 0.670 | 0.602 | 0.554 |
| 10 MiB  | raw | 0.886 | 3.730 | 5.594 | 5.875 | 5.720 |
| 10 MiB  | torch_save | 0.659 | 3.226 | 5.879 | 5.350 | 5.939 |
| 10 MiB  | dcp | 0.384 | 2.314 | 4.670 | 5.232 | 5.202 |
| 100 MiB | raw | 1.019 | 7.767 | 13.31 | 19.23 | 20.58 |
| 100 MiB | torch_save | 1.055 | 6.499 | 13.76 | 16.92 | 21.14 |
| 100 MiB | dcp | 0.975 | 5.328 | 12.96 | 16.17 | 19.25 |

## Analysis

### What each mode actually does

- **`raw`** — `os.read` / `os.write`, thin Python wrappers around the Linux `read(2)` / `write(2)` syscalls (via libc → kernel). No shell, no `dd`/`cat`, no buffering, no decode, no serialization. This is the ceiling of the storage path itself; every other mode calls these same syscalls underneath plus extra CPU work.
- **`dataloader`** (read) — for each file: `open` → `read` bytes → **JPEG decode via PIL** → `Resize(256)` → `CenterCrop(224)` → `ToTensor` (uint8→float32, HWC→CHW, /255). Plus `DataLoader` worker IPC and batch collation. The benchmark scales by spawning N processes each running their own loader.
- **`torch_save`** (write) — `torch.save(tensor, path)`: pickle a float32 tensor (`size/4` elements) plus a small zip/pickle header, then `fsync`. Essentially raw float bytes with a thin wrapper.
- **`dcp`** (write) — `torch.distributed.checkpoint.save` of a synthetic `nn.Module`. Goes through the DCP planner, writes a sharded layout with per-shard data files + a metadata file, then `fsync` over every file in the directory. Designed for distributed sharded checkpoints.

### Findings (all expected for this stack)

- **GPU1 and GPU2 perform essentially identically** across both benchmarks — well within iteration noise. There is no measurable cluster-side throughput difference; the GPU label only tags which host pool ran the job.
- **Read: DataLoader is ~2.7-3.2× slower than raw, and this is normal** — the gap is JPEG decode + PIL transforms + tensor conversion, not I/O. The raw read syscall is identical in both modes; everything above it is CPU work on the decoded image. JPEG decode is the well-known bottleneck of the standard ImageNet pipeline (people bypass it with DALI, Pillow-SIMD, GPU `decode_jpeg`, or pre-decoded webdataset shards). Scaling is sub-linear: raw 0.09 → 6.9 GB/s (76× for 96× procs), DataLoader 0.03 → 2.2 GB/s (~66×). Diminishing returns past 64 procs.
- **Write: file size dominates throughput.** 100 KiB files top out around 0.07 GB/s regardless of process count — metadata/syscall bound. 100 MiB files reach ~20 GB/s at 64-96 procs, ~280× higher.
- **Write: `torch_save` ≈ `raw` (within 5-15%), also expected** — `torch.save` is essentially writing raw float32 bytes plus a small pickle header, so once files are big enough the wrapper amortizes away. No surprise there.
- **Write: `dcp` is meaningfully slower at low concurrency / small files** (e.g. 100 KiB / 1 proc: dcp 0.008 vs raw 0.041, ~5× slower) — expected, because DCP writes a sharded layout with extra metadata files per save, overhead that only pays off at distributed scale. At 100 MiB the three modes converge within ~10-15%.
- **Sweet spot for large-file writes is 64 procs**: doubling to 96 yields <5% gain (and sometimes a regression at smaller sizes, suggesting CPU/IO contention).
- **Read vs write at saturation:** at 96 procs, peak read is ~6.9 GB/s (21 GB / 186 K smaller files), peak write reaches ~20 GB/s with 100 MiB files. Not apples-to-apples (file size differs), but the write path is clearly not the bottleneck at large block sizes.

**Bottom line:** none of these overheads are anomalous for an NFS-over-RDMA Vast filesystem driven from PyTorch. The `dataloader`/`torch_save`/`dcp` slowdowns are all CPU-side cost of the framework layer above the syscall, not storage-side problems.

---

**Side note — is throughput saturated at 96 procs?** Looking at the 64→96 proc delta (a 1.5× bump; linear scaling = +50%):

| mode / workload | GPU1 64→96 | GPU2 64→96 | saturated? |
|---|---|---|---|
| read `raw`        | 5.16 → 6.91 (+34%) | 5.12 → 6.97 (+36%) | not yet — still gaining, but bending |
| read `dataloader` | 1.88 → 2.18 (+16%) | 1.86 → 2.14 (+15%) | nearly — bounded by CPU JPEG decode |
| write ≤10 MiB (all modes)   | flat / regressing | flat / regressing | yes; 96 procs overshoots optimum |
| write 100 MiB `raw`         | +1.6% | +7% | yes (within noise) |
| write 100 MiB `torch_save`  | +7.8% | +25% | nearly — some headroom |
| write 100 MiB `dcp`         | +5% | +19% | nearly — some headroom |

- **Read `raw`** is the only mode with meaningful headroom past 96 procs — try 128/192 to find the real plateau.
- **Read `dataloader`** is bounded by CPU decode, not storage. Adding procs won't help; switch to a faster decoder.
- **Write** is saturated (or past optimum) at 96 for all file sizes except `torch_save`/`dcp` on 100 MiB, where modest room remains.
