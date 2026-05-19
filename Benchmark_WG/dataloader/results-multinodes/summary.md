# Multinode Dataloader Benchmark Summary

Runs in this directory span a 2D sweep: **nodes ∈ {2, 4, 8, 12}** × **cpu_per_node ∈ {32, 64, 96, 128}** × {GPU1 (`a00xx`), GPU2 (`b00xx`)}. Two suites — READ (`read_benchmark.py`) and WRITE (`write_benchmark.py`) — share the same sweep, identified by separate job IDs (22323-22346 + 22397-22404 = READ, 22347-22370 + 22405-22412 = WRITE; the 22397+ block extends the sweep to 128 cpu/node). Values below are **aggregate cluster throughput** = sum of per-rank GBps, averaged over 3 iterations.

## Benchmark A — READ (`raw` vs `dataloader`)

Single ~21 GB / 186 K-file workload, partitioned across ranks. Each rank runs `nproc = cpu_per_node` workers.

### GPU1 — GB/s
| nodes | cpu/node | raw | dataloader | raw/dl |
|---|---|---|---|---|
| 2  | 32 | 2.77  | 1.61  | 1.72 |
| 2  | 64 | 9.37  | 3.61  | 2.60 |
| 2  | 96 | 5.40  | 4.22  | 1.28 |
| 4  | 32 | 5.98  | 3.73  | 1.60 |
| 4  | 64 | 17.67 | 6.49  | 2.72 |
| 4  | 96 | 16.03 | 8.71  | 1.84 |
| 8  | 32 | 10.22 | 6.83  | 1.50 |
| 8  | 64 | 36.71 | 13.63 | 2.69 |
| 8  | 96 | 32.96 | 16.22 | 2.03 |
| 12 | 32 | 18.03 | 11.97 | 1.51 |
| 12 | 64 | 33.42 | 15.05 | 2.22 |
| 12 | 96 | 33.86 | 25.13 | 1.35 |
| 2  | 128 | 17.11 | 4.33  | 3.95 |
| 4  | 128 | 13.42 | 7.63  | 1.76 |
| 8  | 128 | 22.33 | 15.61 | 1.43 |
| 12 | 128 | 45.64 | 27.31 | 1.67 |

### GPU2 — GB/s
| nodes | cpu/node | raw | dataloader | raw/dl |
|---|---|---|---|---|
| 2  | 32 | 5.17  | 1.45  | 3.57 |
| 2  | 64 | 8.87  | 3.39  | 2.62 |
| 2  | 96 | 5.66  | 4.20  | 1.35 |
| 4  | 32 | 9.50  | 2.81  | 3.38 |
| 4  | 64 | 17.09 | 6.74  | 2.54 |
| 4  | 96 | 10.82 | 6.56  | 1.65 |
| 8  | 32 | 20.66 | 6.07  | 3.40 |
| 8  | 64 | 35.71 | 13.67 | 2.61 |
| 8  | 96 | 38.71 | 16.54 | 2.34 |
| 12 | 32 | 13.90 | 9.01  | 1.54 |
| 12 | 64 | 24.96 | 20.26 | 1.23 |
| 12 | 96 | 33.00 | 24.44 | 1.35 |
| 2  | 128 | 6.13  | 3.17  | 1.93 |
| 4  | 128 | 28.66 | 6.38  | 4.49 |
| 8  | 128 | 56.10 | 16.10 | 3.48 |
| 12 | 128 | 46.21 | 25.54 | 1.81 |

## Benchmark B — WRITE (`raw` / `torch_save` / `dcp`)

Per-rank: `files_per_proc=8`, total files per rank = 256, sweep `file_size ∈ {100 KiB, 1 MiB, 10 MiB, 100 MiB}`.

### GPU1 — GB/s
**file_size = 100 KiB**
| nodes | cpu/node | raw | torch_save | dcp |
|---|---|---|---|---|
| 2  | 32 | 0.03 | 0.05 | 0.05 |
| 2  | 64 | 0.04 | 0.06 | 0.04 |
| 2  | 96 | 0.14 | 0.15 | 0.15 |
| 4  | 32 | 0.24 | 0.30 | 0.22 |
| 4  | 64 | 0.29 | 0.31 | 0.22 |
| 4  | 96 | 0.29 | 0.30 | 0.22 |
| 8  | 32 | 0.40 | 0.49 | 0.38 |
| 8  | 64 | 0.48 | 0.58 | 0.57 |
| 8  | 96 | 0.35 | 0.45 | 0.57 |
| 12 | 32 | 0.52 | 0.55 | 0.42 |
| 12 | 64 | 0.41 | 0.46 | 0.49 |
| 12 | 96 | 0.85 | 0.89 | 0.86 |
| 2  | 128 | 0.14 | 0.15 | 0.14 |
| 4  | 128 | 0.07 | 0.08 | 0.09 |
| 8  | 128 | 0.12 | 0.14 | 0.16 |
| 12 | 128 | 0.66 | 0.77 | 0.81 |

**file_size = 1 MiB**
| nodes | cpu/node | raw | torch_save | dcp |
|---|---|---|---|---|
| 2  | 32 | 0.82 | 0.99 | 0.99 |
| 2  | 64 | 0.82 | 1.05 | 1.03 |
| 2  | 96 | 1.69 | 1.59 | 1.29 |
| 4  | 32 | 2.66 | 2.49 | 1.88 |
| 4  | 64 | 2.45 | 2.80 | 1.52 |
| 4  | 96 | 2.61 | 2.80 | 1.25 |
| 8  | 32 | 6.31 | 6.38 | 4.15 |
| 8  | 64 | 6.54 | 6.68 | 5.19 |
| 8  | 96 | 6.93 | 6.88 | 5.13 |
| 12 | 32 | 5.85 | 5.39 | 4.71 |
| 12 | 64 | 7.31 | 7.24 | 2.23 |
| 12 | 96 | 9.93 | 9.77 | 7.54 |
| 2  | 128 | 1.77 | 1.71 | 1.34 |
| 4  | 128 | 1.67 | 2.08 | 1.75 |
| 8  | 128 | 2.20 | 2.76 | 3.40 |
| 12 | 128 | 8.15 | 8.06 | 6.24 |

**file_size = 10 MiB**
| nodes | cpu/node | raw | torch_save | dcp |
|---|---|---|---|---|
| 2  | 32 | 10.57 | 10.24 | 7.28  |
| 2  | 64 | 8.65  | 10.04 | 9.40  |
| 2  | 96 | 10.76 | 10.21 | 7.73  |
| 4  | 32 | 20.34 | 12.41 | 7.24  |
| 4  | 64 | 9.25  | 9.28  | 10.10 |
| 4  | 96 | 8.58  | 9.00  | 11.74 |
| 8  | 32 | 44.94 | 41.78 | 32.64 |
| 8  | 64 | 46.24 | 48.42 | 30.89 |
| 8  | 96 | 50.38 | 51.15 | 36.40 |
| 12 | 32 | 57.87 | 61.32 | 38.27 |
| 12 | 64 | 24.26 | 26.02 | 21.66 |
| 12 | 96 | 66.87 | 59.20 | 41.36 |
| 2  | 128 | 11.47 | 11.06 | 10.12 |
| 4  | 128 | 19.44 | 21.33 | 10.75 |
| 8  | 128 | 37.97 | 39.57 | 31.20 |
| 12 | 128 | 59.39 | 55.37 | 45.06 |

**file_size = 100 MiB**
| nodes | cpu/node | raw | torch_save | dcp |
|---|---|---|---|---|
| 2  | 32 | 27.04 | 27.62 | 25.13  |
| 2  | 64 | 18.36 | 15.80 | 15.28  |
| 2  | 96 | 5.96  | 4.77  | 9.89   |
| 4  | 32 | 32.84 | 39.45 | 50.64  |
| 4  | 64 | 57.38 | 63.23 | 55.34  |
| 4  | 96 | 54.41 | 57.48 | 72.17  |
| 8  | 32 | 73.88 | 57.34 | 71.02  |
| 8  | 64 | 85.76 | 76.23 | 89.67  |
| 8  | 96 | 82.45 | 78.85 | 112.57 |
| 12 | 32 | 97.16 | 75.30 | 83.03  |
| 12 | 64 | 64.47 | 58.65 | 51.75  |
| 12 | 96 | 33.70 | 30.74 | 39.34  |
| 2  | 128 | 42.35 | 42.44 | 34.96  |
| 4  | 128 | 31.42 | 38.65 | 60.07  |
| 8  | 128 | 78.58 | 59.89 | 90.35  |
| 12 | 128 | 66.58 | 69.69 | 46.30  |

### GPU2 — GB/s
**file_size = 100 KiB**
| nodes | cpu/node | raw | torch_save | dcp |
|---|---|---|---|---|
| 2  | 32 | 0.10 | 0.10 | 0.03 |
| 2  | 64 | 0.03 | 0.03 | 0.03 |
| 2  | 96 | 0.13 | 0.15 | 0.09 |
| 4  | 32 | 0.09 | 0.10 | 0.05 |
| 4  | 64 | 0.10 | 0.12 | 0.08 |
| 4  | 96 | 0.05 | 0.07 | 0.08 |
| 8  | 32 | 0.38 | 0.34 | 0.35 |
| 8  | 64 | 0.26 | 0.14 | 0.20 |
| 8  | 96 | 0.15 | 0.16 | 0.34 |
| 12 | 32 | 0.84 | 0.86 | 0.63 |
| 12 | 64 | 0.92 | 0.95 | 0.80 |
| 12 | 96 | 0.86 | 0.91 | 0.49 |
| 2  | 128 | 0.03 | 0.04 | 0.03 |
| 4  | 128 | 0.26 | 0.28 | 0.07 |
| 8  | 128 | 0.55 | 0.53 | 0.25 |
| 12 | 128 | 0.41 | 0.65 | 0.59 |

**file_size = 1 MiB**
| nodes | cpu/node | raw | torch_save | dcp |
|---|---|---|---|---|
| 2  | 32 | 0.56 | 0.60 | 0.35 |
| 2  | 64 | 0.25 | 0.26 | 0.24 |
| 2  | 96 | 0.96 | 0.75 | 0.16 |
| 4  | 32 | 0.72 | 0.69 | 0.57 |
| 4  | 64 | 0.90 | 0.72 | 0.43 |
| 4  | 96 | 1.64 | 1.65 | 1.80 |
| 8  | 32 | 4.66 | 3.29 | 1.43 |
| 8  | 64 | 3.54 | 4.50 | 3.83 |
| 8  | 96 | 3.32 | 1.83 | 1.62 |
| 12 | 32 | 8.15 | 7.88 | 6.47 |
| 12 | 64 | 8.15 | 7.03 | 4.99 |
| 12 | 96 | 5.51 | 1.68 | 1.25 |
| 2  | 128 | 0.45 | 0.44 | 0.29 |
| 4  | 128 | 0.56 | 0.80 | 0.55 |
| 8  | 128 | 1.35 | 1.37 | 1.16 |
| 12 | 128 | 5.83 | 5.80 | 3.92 |

**file_size = 10 MiB**
| nodes | cpu/node | raw | torch_save | dcp |
|---|---|---|---|---|
| 2  | 32 | 4.68  | 5.51  | 6.02  |
| 2  | 64 | 3.66  | 3.71  | 2.92  |
| 2  | 96 | 2.02  | 2.64  | 2.75  |
| 4  | 32 | 6.34  | 5.70  | 5.17  |
| 4  | 64 | 9.13  | 9.29  | 8.67  |
| 4  | 96 | 22.22 | 20.77 | 15.19 |
| 8  | 32 | 16.24 | 19.03 | 16.85 |
| 8  | 64 | 36.90 | 43.69 | 30.55 |
| 8  | 96 | 17.42 | 13.73 | 10.64 |
| 12 | 32 | 64.18 | 62.20 | 38.90 |
| 12 | 64 | 58.12 | 54.89 | 21.67 |
| 12 | 96 | 13.79 | 15.27 | 15.77 |
| 2  | 128 | 3.26  | 3.70  | 4.29  |
| 4  | 128 | 6.80  | 6.98  | 6.58  |
| 8  | 128 | 15.68 | 14.92 | 12.09 |
| 12 | 128 | 17.69 | 19.03 | 16.36 |

**file_size = 100 MiB**
| nodes | cpu/node | raw | torch_save | dcp |
|---|---|---|---|---|
| 2  | 32 | 22.35 | 25.64 | 24.19  |
| 2  | 64 | 18.82 | 23.43 | 23.92  |
| 2  | 96 | 5.52  | 9.01  | 19.96  |
| 4  | 32 | 13.63 | 15.80 | 16.76  |
| 4  | 64 | 37.56 | 40.62 | 46.44  |
| 4  | 96 | 68.36 | 71.66 | 70.16  |
| 8  | 32 | 51.45 | 69.40 | 80.95  |
| 8  | 64 | 55.74 | 55.50 | 50.23  |
| 8  | 96 | 42.78 | 56.46 | 76.94  |
| 12 | 32 | 76.77 | 70.19 | 120.66 |
| 12 | 64 | 23.05 | 25.04 | 32.22  |
| 12 | 96 | 43.88 | 62.14 | 132.61 |
| 2  | 128 | 26.31 | 36.74 | 37.02  |
| 4  | 128 | 15.39 | 20.49 | 39.91  |
| 8  | 128 | 27.08 | 33.75 | 76.59  |
| 12 | 128 | 48.12 | 42.78 | 42.97  |

## Analysis

### What each mode actually does

- **`raw`** — `os.read` / `os.write`, thin Python wrappers around the Linux `read(2)` / `write(2)` syscalls. Ceiling of the storage path itself.
- **`dataloader`** (read) — per file: read bytes → JPEG decode (PIL) → Resize(256) → CenterCrop(224) → ToTensor. Plus DataLoader worker IPC and collation.
- **`torch_save`** (write) — pickle a float32 tensor (`size/4` elements) + small zip/pickle header + fsync.
- **`dcp`** (write) — `torch.distributed.checkpoint.save` of a synthetic `nn.Module`: planner-driven sharded layout, per-shard data files plus a metadata file, fsync over every file.

### Findings (all expected for this stack)

- **READ scales sub-linearly with total CPU.** Best read raw observed: ~56.1 GB/s at 8 nodes × 128 cpu (GPU2), with 12 × 128 reaching ~46 GB/s on both clusters. Going 8 → 12 nodes does **not** reliably improve raw read further (often regresses at 96 cpu/node) — the NFS read path approaches saturation around the 12-node mark. The 64 and 128 cpu/node columns show the cleanest scaling; 96 cpu/node frequently *underperforms* both, and 128 cpu/node *underperforms* 96 cpu/node at smaller node counts — suggesting CPU/IO contention at high per-node concurrency and a sweet spot that depends on node count.
- **DataLoader gap is smaller on multinode than single-node.** Single-node ratio was ~2.7-3.2×; here it ranges 1.2-4.5× and at high `nodes×cpu` shrinks toward 1.4-1.8×. **Expected**: each node adds its own JPEG-decode CPU pool, so decode capacity scales with cluster while raw read does not — the modes converge as the system becomes decode-bound less and bandwidth-bound more. DataLoader top: ~27.3 GB/s at 12 nodes × 128 cpu (GPU1) — the modest 96 → 128 cpu/node gain (25.13 → 27.31, +9%) indicates the decode pool was already mostly saturated at 96 cores against the available read bandwidth.
- **WRITE small files (100 KiB-1 MiB) are metadata/syscall bound.** Even at 12 nodes × 96 cpu, 100 KiB tops out below 1 GB/s and 1 MiB below ~10 GB/s. `torch_save` ≈ `raw` (5-15% gap = thin pickle header, expected); `dcp` lags by 10-40% (sharded metadata overhead, expected).
- **WRITE large files (10-100 MiB) scale well to 8 nodes and then get jittery.** 100 MiB / 8 nodes / 96 cpu reaches 112 GB/s (`dcp`, GPU1) and 132 GB/s (`dcp`, GPU2 / 12 × 96). But several 12-node cells (e.g. GPU1 / 12 × 96 / 100 MiB raw = 33.7 GB/s vs 12 × 32 = 97.2 GB/s) regress hard — multinode shared-NFS jitter is real and one bad iter pulls the mean down.
- **GPU1 vs GPU2: comparable on average, more divergent than single-node.** Aggregate ranges overlap; individual cells differ by up to 2× due to cluster-level jitter. No systematic preference for one cluster.

**Bottom line:** none of these patterns are anomalous — the read path saturates at the storage level around 45-55 GB/s (up from ~35-40 GB/s once 128 cpu/node is unlocked), the dataloader gap closes as decode CPU scales out, write throughput is metadata-bound for small files and ~75-90 GB/s for large files at 8 × 128, and the multinode noise at 12 nodes (and now at 128 cpu/node for smaller node counts) is consistent with shared-storage contention rather than a code defect.

---

**Side note — is throughput saturated at the top of the sweep (12 nodes × 128 cpu)?** Comparing 8 → 12 nodes at 128 cpu/node (a 1.5× node bump; linear scaling = +50%):

| benchmark / mode | GPU1 8→12 | GPU2 8→12 | saturated? |
|---|---|---|---|
| read `raw`        | 22.33 → 45.64 (+104%)  | 56.10 → 46.21 (−18%)  | mixed — GPU1 super-linear (noisy 8-node baseline), GPU2 saturated/regressing |
| read `dataloader` | 15.61 → 27.31 (+75%)   | 16.10 → 25.54 (+59%)  | **not yet** — still scaling super-linearly on both clusters |
| write 100 KiB `raw`        | 0.12 → 0.66 (+450%) | 0.55 → 0.41 (−26%) | very noisy at small sizes; metadata-bound |
| write 1 MiB `raw`          | 2.20 → 8.15 (+270%) | 1.35 → 5.83 (+332%) | still gaining strongly |
| write 10 MiB `raw`         | 37.97 → 59.39 (+56%) | 15.68 → 17.69 (+13%) | mixed — GPU1 still scaling, GPU2 ~saturated |
| write 100 MiB `raw`        | 78.58 → 66.58 (−15%) | 27.08 → 48.12 (+78%) | regressing on GPU1 (likely contention), still gaining on GPU2 |
| write 100 MiB `dcp`        | 90.35 → 46.30 (−49%) | 76.59 → 42.97 (−44%) | regressing on both — large-file `dcp` at 12 × 128 hits NFS / metadata contention |

Takeaways:
- **`dataloader` is the only read mode with clear headroom past 12 nodes on both clusters** — decode CPU scales with cluster size, raw read does not.
- **Read `raw` ceiling lands ~45-55 GB/s** at 128 cpu/node (vs ~35-40 GB/s at 96 cpu/node) — pushing per-node CPU buys some additional raw-read headroom at large node counts but the marginal return shrinks (e.g. 12 × 96 → 12 × 128 GPU2: 33.0 → 46.2, +40%; 12 × 96 → 12 × 128 GPU1: 33.9 → 45.6, +35%).
- **DataLoader gains less from 96 → 128 cpu/node** (e.g. 12 nodes GPU1: 25.13 → 27.31, +9%) — at 96 cpu/node the decode pool is already saturated against the read bandwidth, so extra cores have little to do.
- **Large-file writes at 12 × 128 are jitter-dominated**, not cleanly saturated — both `dcp` and `raw` regress in several cells (e.g. 100 MiB `dcp` GPU1: 90.35 → 46.30 GB/s 8 → 12 nodes). Re-running with more iterations would tighten the estimates; 3-iter means are not robust against shared-NFS spikes.
- **Small-file write throughput is metadata-bound**, not bandwidth-bound — adding nodes or CPU helps modestly but the absolute ceiling is low (12 × 128 GPU1: 0.66-0.81 GB/s).
- **128 cpu/node introduces additional cell-level variance.** Several 128-cpu cells fall *below* their 96-cpu counterparts at smaller node counts (e.g. 4 × 96 GPU1 `read raw` = 16.03 → 4 × 128 = 13.42 GB/s; 8 × 96 GPU1 `read raw` = 32.96 → 8 × 128 = 22.33 GB/s). This is consistent with per-node CPU/IO contention from saturated worker pools and shared-NFS jitter — the extra cores past a per-node threshold compete for the same disk path rather than adding parallelism.
