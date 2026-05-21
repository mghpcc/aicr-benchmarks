# Peak Aggregate Read — Analysis of `results-peak/out.summary-v1`

Analysis of the v1 job-array run logged in `results-peak/out.summary-v1` (run dir `results-peak/combo_1779385074`).

## What the benchmark does

A Slurm **job array** of many independent client jobs that all read the same dataset (ImageNet train tree, ~21 GB / 186 K JPEG files on Vast NFS-over-RDMA) at the same time. Each array task:

- Allocates its own compute node(s) and shards the 1000 ImageNet class directories so different tasks read **disjoint** file sets (no inter-task cache overlap).
- Runs `read_benchmark.py --mode raw` — pure `os.open` + `os.read` + `os.close`, with `posix_fadvise(POSIX_FADV_DONTNEED)` after each file to drop the client-side page cache. No JPEG decode, no PyTorch DataLoader — this is the storage-path ceiling, not a training pipeline.
- Each rank uses `nproc = 128` worker processes for parallel reads.
- Each iter reads the full shard (~5 GB / rank), repeated for `ITERS=15` iterations.
- `nfsstat -m` confirms mounts already use `nconnect=16`, so each client's NFS uses 16 parallel TCP/RDMA connections to its CBOX.

The cluster-side `peak_aggregate_summary.py` aggregates all per-rank CSVs, summing per-iter GBps across all ranks to produce a **sum-of-rank-rates** (matches the convention in `../dataloader/results-multinodes/summary.md`) and a **conservative** number (`total_bytes / max_elapsed`) that's an honest cluster wall-clock rate when ranks finish near-simultaneously.

## Cluster shape in this run

- **Requested**: 28 tasks (`--array=0-27`) × 2 nodes each = 56 client nodes.
- **Actual concurrent**: 43 unique hosts — **16 rtx (a0001-a0017)** + **27 b200 (b00xx)**.
- The b200 partition had only ~27 idle nodes at submit time, so Slurm ran the b200 array in two waves: 13 tasks first, then 7 more after those finished. **At no wall-clock moment were all 28 tasks running simultaneously.**
- Per node: `nproc=128` worker processes, 128 cpu/node, `nconnect=16` NFS mounts.

## Did this run push the cluster to its limit?

**Partly — and the "best iter" number partly reflects an aggregation artifact, not real cluster ceiling.**

Full per-iter table from `out.summary-v1` (run dir `results-peak/combo_1779385074`, 56 ranks across 43 unique hosts):

| iter | cluster_sum_GBps | conservative_GBps | vs_462_spec | ranks |
|---|---|---|---|---|
|  0 | 188.76 | 110.25 | 40.9% | 56 |
|  1 | 198.22 | 148.39 | 42.9% | 56 |
|  2 | 197.54 | 151.22 | 42.8% | 56 |
|  3 | 195.23 | 145.42 | 42.3% | 56 |
|  4 | 195.12 | 137.97 | 42.2% | 56 |
|  5 | 194.04 | 133.44 | 42.0% | 56 |
|  6 | 169.99 | 118.94 | 36.8% | 56 |
|  7 | 190.65 | 130.25 | 41.3% | 56 |
|  8 | 190.65 | 122.41 | 41.3% | 56 |
|  9 | 191.42 | 125.62 | 41.4% | 56 |
| 10 | 194.85 | 133.24 | 42.2% | 56 |
| 11 | 194.55 | 106.39 | 42.1% | 56 |
| 12 | 204.63 | 138.51 | 44.3% | 56 |
| 13 | 224.64 | 159.95 | 48.6% | 56 |
| 14 | **254.91** | **174.45** | **55.2%** | 56 |

**Mean across iters:**
- `cluster_sum_GBps` (sum-of-rank-rates):       **199.01 GB/s** → **43.1%** of Vast Max Read (462 GB/s)
- `conservative_GBps` (bytes/max_elapsed):      **135.76 GB/s** → **29.4%** of Vast Max Read (462 GB/s)

> **What `iter` means.** Each task re-reads its full ~5 GB shard `ITERS` times in a row; `iter=0` is the first pass, `iter=14` the fifteenth. Each row in the table sums "everyone's iter N" across all 56 ranks. We run multiple iters to absorb warm-up cost (cold caches, Python startup, Slurm launch) and to smooth out per-run jitter. **But `iter` is an iteration *index*, not a wall-clock time bucket** — if some tasks start late (as in this run), rank A's iter 14 and rank B's iter 14 may happen tens of seconds apart, so the iter-14 row pools data that didn't actually occur simultaneously.

The reported peak (254.91 GB/s sum, 174.45 GB/s conservative) at iter 14 is misleading because **iter 14 of an early-wave task and iter 14 of a late-wave task happened tens of seconds apart on the wall clock**. The summary sums per-iter rates across tasks regardless of when those iters actually occurred, so the 255 GB/s number includes contributions from tasks that had already finished by the time the late tasks reached their iter 14.

Per-rank reads were ~3 GB/s (each rank: ~5.3 GB in ~1.7 s) — well below the ~5 GB/s a single NFS-over-RDMA mount can deliver with `nconnect=16`. So per-client headroom existed, but **wall-clock concurrent throughput** was lower than the headline number suggests.

A later, cleaner v2 run with all 21 tasks truly concurrent (42 nodes, no waves) peaked at iter-4 sum = **206 GB/s = 42 nodes × 4.9 GB/s/node** — essentially the per-mount cap × node count. That's the real ceiling at this scale.

**Is there room to push?** Yes — by adding **more concurrent client nodes**. The 462 GB/s cluster spec is a per-cluster aggregate, not a per-client one; you reach it by having enough clients to add up to it. The per-mount cap (~5 GB/s) is the hard ceiling per node.

## Does this reach the Vast spec on paper? Why not?

The Vast spec from the AICR proposal (Cluster 16×7 Gen5 / Ceres 1350):

| metric | spec | this run's best | utilization |
|---|---|---|---|
| Max Read | 462 GB/s | 254 GB/s (sum) / 174 GB/s (conservative) | 38-55% |

**No — the run reaches ~55% of the spec, and the cluster cannot reach 100% with stock NFS from the available compute partitions.** Three reasons:

1. **Per-NFS-mount cap.** Each NFS-over-RDMA client mount pulls ~5 GB/s with `nconnect=16`. To reach 462 GB/s you need ~95 concurrent clients (95 × ~5 = 462).
2. **Limited client nodes.** This cluster has ~28 b200 + ~17 rtx + 5 cpu + 5 *-devel ≈ **55 nodes max**, so even with every node idle and participating the stock-NFS ceiling is ~55 × 5 = **~270 GB/s**.
3. **Aggregation artifact.** The run's "best iter" 254 GB/s is inflated by mixing data from tasks that ran at different wall-clock times due to Slurm running b200 in two waves. The honest wall-clock concurrent throughput was lower.

The 462 spec assumes either (a) a fully loaded client population of 100+ clients hitting the cluster simultaneously, or (b) Vast's proprietary **DPC (Data Path Client)**, which multiplexes a single host across all 16 CBOXes in parallel and bypasses the per-mount cap.

## Real-world prediction: many users, many jobs, simultaneous I/O

In a production scenario where multiple users each submit jobs that drive I/O concurrently across the cluster's compute pool, the aggregate behavior would be:

- **Each user's job behaves like one of our array tasks** — it mounts NFS, reads at ~5 GB/s per node (limited by per-mount cap), and its mount is distributed to one of the 16 CBOX VIPs via DNS round-robin.
- **Independent jobs naturally spread across CBOXes** — DNS rotation ensures distinct mounts land on different CBOXes. With dozens of mounts in flight, all 16 CBOXes get meaningful load.
- **Per-job throughput drops slightly under contention** but doesn't collapse — the Vast back-end is designed for many concurrent clients.

**Maximum total bandwidth in a busy cluster:**

| scenario | concurrent client nodes | expected aggregate |
|---|---|---|
| Light load (1-2 small jobs)         | 1-4 nodes   | 4-20 GB/s |
| Moderate (10 users × 1 job each)    | 10-20 nodes | 50-100 GB/s |
| Heavy (this benchmark or equivalent) | 42-55 nodes | **200-270 GB/s** |
| Theoretical max with stock NFS       | ~55 nodes (all idle) | **~270 GB/s** |
| To reach Vast spec (462 GB/s)        | ~95 nodes   | **not reachable from this cluster** |

**Would it be close to the Vast spec?** **No.** Even with every compute node in the cluster fully loaded with concurrent I/O jobs, the stock-NFS ceiling is ~60% of the 462 GB/s spec. Real-world workloads typically use a fraction of available nodes, so realistic aggregate would more often be in the 50-200 GB/s range (10-45% of spec).

**To approach the spec in production:**

- Install **Vast DPC** on the compute nodes — a single DPC-mounted client can drive 20-50 GB/s, so 10-20 nodes could collectively saturate the cluster.
- Add more compute nodes (not under your control).
- Use **larger per-mount `nconnect`** values (current is 16; Vast supports higher) — diminishing returns past 16.

Bottom line: the cluster's read fabric (462 GB/s) is correctly sized for the workload it's designed to serve, but the **stock-NFS client population available to you can only access ~60% of it**. The gap is a client-side limitation, not a storage-side one.
