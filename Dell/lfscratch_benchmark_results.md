# lfscratch Disk Benchmark Results

**Run dates:** 2026-05-20 / 2026-05-21  
**Tool:** fio 3.35 (via `fio-benchmark.sif` Apptainer container)  
**Filesystem:** XFS, mounted at `/lfscratch`, `noatime`

---

## Test Configuration

| Parameter | Compute (R6715) | GPU1 (XE7745) | GPU2 (XE9685L) |
|-----------|----------------|---------------|----------------|
| Storage | Single 1.7 TB NVMe (nvme0n1) | 8× 3.5 TB NVMe RAID0 (~27.9 TB) | 8× 3.5 TB NVMe RAID0 (~27.9 TB) |
| Partition | cpu | rtx-batch | b200-batch |
| fio numjobs | 1 | 8 (NUMA-interleaved) | 1 |
| fio test file size | 16 GB | 32 GB | 32 GB |
| Sequential write | 1M BS, QD=8, 30 s, direct I/O | 1M BS, QD=8×8 jobs, 30 s, direct I/O | 1M BS, QD=8, 30 s, direct I/O |
| Sequential read | 1M BS, QD=8, 30 s, direct I/O | 1M BS, QD=8×8 jobs, 30 s, direct I/O | 1M BS, QD=8, 30 s, direct I/O |
| Random 4K read | 4K BS, QD=32, 30 s, direct I/O | 4K BS, QD=32×8 jobs, 30 s, direct I/O | 4K BS, QD=32, 30 s, direct I/O |
| Random 4K write | 4K BS, QD=32, 30 s, direct I/O | 4K BS, QD=32×8 jobs, 30 s, direct I/O | 4K BS, QD=32, 30 s, direct I/O |
| Nodes tested | w0001–w0005 (5/5) | a0002–a0012 (11/19) | b0005–b0028 (22/31) |

> **Note:** `mdadm --detail /dev/md0` requires root; RAID health output was not available in job context. Run `mdadm --detail /dev/md0` manually or via a privileged job to inspect RAID member status.

> **Note on GPU1 methodology:** The GPU1 script was updated mid-run to use `numjobs=8` with NUMA topology awareness (`--numa_cpu_nodes=0,1 --numa_mem_policy=interleave`). All reported GPU1 values are aggregates across all 8 fio processes from the final run per node. Sequential read numbers in particular show high run-to-run variance (29–75 GiB/s range) because 8 competing processes share the same file path; **sequential read is not a reliable metric for this configuration** and should be treated as informational only. Sequential write and both random tests are stable and comparable within the GPU1 fleet.

---

## Compute Nodes — Dell R6715 (w0001–w0005)

Single 1.7 TB NVMe, XFS. Results are extremely consistent across all five nodes.

| Node | Seq Write (MB/s) | Seq Read (MB/s) | Rand 4K Read (IOPS) | Rand 4K Write (IOPS) |
|------|----------------:|----------------:|--------------------:|---------------------:|
| w0001 | 2,809 | 6,881 | 401k | 340k |
| w0002 | 2,809 | 6,892 | 401k | 339k |
| w0003 | 2,809 | 6,881 | 401k | 338k |
| w0004 | 2,809 | 6,882 | 401k | 335k |
| w0005 | 2,809 | 6,887 | 401k | 339k |
| **Min** | **2,809** | **6,881** | **401k** | **335k** |
| **Max** | **2,809** | **6,892** | **401k** | **340k** |
| **Avg** | **2,809** | **6,885** | **401k** | **338k** |

**Observations:**
- Sequential write is locked at 2,809 MB/s on every node — effectively at the drive's rated sequential write ceiling with zero variance.
- Sequential read at ~6,885 MB/s is exceptionally strong, well above write speed as expected for NVMe asymmetric performance.
- Random 4K IOPS are healthy and uniform: 401k read / ~338k write. Avg clat ~79 µs read, ~93 µs write.
- All five compute nodes are healthy and performing identically. No concerns.

---

## GPU1 Nodes — Dell XE7745 (a0002–a0012)

8× 3.5 TB NVMe in RAID0 (`/dev/md0`), XFS. Run with `numjobs=8`, NUMA-interleaved. All values are aggregate across 8 fio processes. Several early test runs on a0002, a0003, and a0004 were made during script development; only the final complete run per node is reported here.

| Node | Seq Write (GiB/s) | Seq Read (GiB/s)† | Rand 4K Read (GiB/s) | Rand 4K Write (GiB/s) |
|------|------------------:|------------------:|---------------------:|----------------------:|
| a0002 | 41.5 | 50.7 | 10.0 | 4.65 |
| a0003 | 41.9 | 35.6 | 9.96 | 4.43 |
| a0004 | 42.3 | 70.8 | 9.92 | 4.72 |
| a0005 | 42.3 | 32.8 | 9.93 | 4.72 |
| a0006 | 42.3 | 34.6 | 9.92 | 4.41 |
| a0007 | 42.1 | 38.0 | 9.79 | 5.24 |
| a0008 | 41.9 | 74.6 | 9.98 | 4.69 |
| a0009 | 42.1 | 39.6 | 9.97 | 4.64 |
| a0010 | 42.1 | 69.0 | 9.85 | 4.80 |
| a0011 | 42.1 | 29.4 | 9.99 | 4.58 |
| a0012 | 41.9 | 35.5 | 10.1 | 4.71 |
| **Min** | **41.5** | **29.4** | **9.79** | **4.41** |
| **Max** | **42.3** | **74.6** | **10.1** | **5.24** |
| **Avg** | **42.0** | **46.4** | **9.95** | **4.69** |

† Sequential read is highly variable due to 8 competing processes sharing the same file — see methodology note above.

**Observations:**
- Sequential write is very consistent at **41.5–42.3 GiB/s** (±0.4 GiB/s spread) across all 11 nodes. This is the most reliable metric from this configuration and shows all RAID arrays are healthy and performing uniformly.
- Random 4K read aggregate is extremely tight at **9.79–10.1 GiB/s** (~320k IOPS per job, ~2.6M IOPS aggregate). Random 4K write is **4.41–5.24 GiB/s** (~150k IOPS per job, ~1.2M IOPS aggregate) — a0007 runs slightly higher at 5.24 GiB/s but is within acceptable variance for a multi-job shared-file workload.
- All 11 tested GPU1 nodes are healthy. No anomalies.

---

## GPU2 Nodes — Dell XE9685L (b0005–b0028)

8× 3.5 TB NVMe in RAID0 (`/dev/md0`), XFS. Run with `numjobs=1`. All values are from a single fio process.

| Node | Seq Write (GiB/s) | Seq Read (GiB/s) | Rand 4K Read (IOPS) | Rand 4K Write (IOPS) |
|------|------------------:|-----------------:|--------------------:|---------------------:|
| b0005 | 38.9 | 15.7 | 466k | 381k |
| b0006 | 39.1 | 17.2 | 467k | 388k |
| b0007 | 39.6 | 15.1 | 467k | 393k |
| b0008 | 39.9 | 15.5 | 468k | 394k |
| b0009 | 39.5 | 15.1 | 466k | 392k |
| b0010 | 39.2 | 15.4 | 463k | 385k |
| b0011 | 39.2 | 15.0 | 467k | 396k |
| b0012 | 39.1 | 15.4 | 466k | 381k |
| b0013 | 39.3 | 15.3 | 467k | 397k |
| b0014 | 39.7 | 17.0 | 467k | 394k |
| b0015 | 39.0 | 15.0 | 467k | 385k |
| b0016 | 39.6 | 16.5 | 468k | 390k |
| b0017 | 38.8 | 15.0 | 467k | 385k |
| b0018 | 39.2 | 15.2 | 466k | 378k |
| b0019 | 39.2 | 15.3 | 468k | 392k |
| b0020 | 39.3 | 14.8 | 468k | 394k |
| b0021 | 39.4 | 15.2 | 467k | 398k |
| **b0022** ⚠️ | **29.8** | 15.4 | 469k | 404k |
| b0023 | 38.6 | 15.3 | 469k | 401k |
| b0024 | 38.5 | 15.1 | 468k | 395k |
| b0026 | 39.0 | 15.0 | 467k | 397k |
| b0027 | 38.9 | 15.4 | 467k | 400k |
| b0028 | 38.8 | 15.0 | 468k | 402k |

### Fleet Summary (excluding b0022)

| Metric | Min | Max | Avg |
|--------|----:|----:|----:|
| Seq Write (GiB/s) | 38.5 | 39.9 | 39.1 |
| Seq Read (GiB/s) | 14.8 | 17.2 | 15.5 |
| Rand 4K Read (IOPS) | 463k | 469k | 467k |
| Rand 4K Write (IOPS) | 378k | 404k | 393k |

**Observations:**
- Sequential write is very consistent across the healthy fleet at **~39.1 GiB/s** with only ±0.7 GiB/s spread.
- Sequential read shows more variance (14.8–17.2 GiB/s) — expected with a single fio job at QD=8 against an 8-drive stripe; at low queue depths a single reader does not always distribute I/O evenly across all drives.
- Random 4K performance is extremely consistent: ~467k read IOPS / ~393k write IOPS. Avg clat ~67 µs read, ~82 µs write.

---

## Anomalies and Action Items

### ⚠️ b0022 — Degraded Sequential Write (nvme2n1 bottleneck)

b0022 produced **29.8 GiB/s** sequential write, **23.8% below the fleet average** of 39.1 GiB/s. The per-drive utilization from fio disk stats exposes the root cause:

| Drive | Utilization during seq_write |
|-------|-----------------------------:|
| nvme0n1 | 69.73% |
| nvme1n1 | 69.71% |
| **nvme2n1** | **99.49%** ← bottleneck |
| nvme3n1 | 70.06% |
| nvme4n1 | 70.10% |
| nvme5n1 | 70.02% |
| nvme7n1 | 69.62% |
| nvme8n1 | 70.11% |

nvme2n1 is fully saturated while every other drive is at ~70%, making it the limiting member of the RAID stripe. The bimodal clat distribution confirms this: ~70% of writes complete fast (~93–99 µs) while ~25% stall at 709–750 µs waiting for nvme2n1.

Notably, random 4K performance on b0022 is **normal** (469k read IOPS, 404k write IOPS), indicating the drive is present and responsive — the issue is specific to sustained sequential write throughput. Likely causes: thermal throttling under sustained load, early-stage wear or media degradation on the sequential write path, or a firmware-level regression.

**Recommended actions:**
1. Check nvme2n1 SMART data: `nvme smart-log /dev/nvme2n1` — look for critical warnings, temperature, percentage used, or media errors.
2. Verify drive temperature under sustained write load to rule out thermal throttling.
3. Run `mdadm --detail /dev/md0` to confirm all RAID members report clean/active status.
4. If SMART shows wear or errors, schedule drive replacement. The RAID0 configuration has no redundancy — a failure on any single member results in total data loss on `/lfscratch`.

---

## Summary

| Group | Nodes Tested | Total Nodes | Status |
|-------|------------:|------------:|--------|
| Compute (R6715) w0001–w0005 | 5 | 5 | All healthy, perfectly consistent |
| GPU1 (XE7745) a0002–a0012 | 11 | 19 | All healthy, consistent at ~42.0 GiB/s seq write |
| GPU2 (XE9685L) healthy fleet | 22 | 31 | All healthy, consistent at ~39.1 GiB/s seq write |
| GPU2 b0022 | — | — | Degraded — sequential write 23.8% below fleet avg, investigate nvme2n1 |

---

## Nodes Not Tested

The following nodes were in a drained or in-use state at the time of the benchmark run and could not be included:

- **GPU1:** a0001, a0013, a0014, a0015, a0016, a0017, a0018, a0019
- **GPU2:** b0001, b0002, b0003, b0004, b0025, b0029, b0030, b0031
