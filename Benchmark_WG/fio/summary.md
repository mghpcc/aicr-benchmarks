# fio Peak Aggregate Run Analysis — `fio_1779399220`

## What the Benchmark Measures

`peak_aggregate_fio.sh` launches a Slurm job array of independent fio
processes against the Vast `/work` NFS mount, each task writing into its
own private subtree of `${DATA_ROOT}/${TAG}/task_<N>/<host>/<workload>/`
(no cache overlap, no false sharing). Four workloads run back-to-back
inside every task:

| workload     | direction | block size | metric  | engine        |
|---           |---        |---         |---      |---            |
| `seq_write`  | write     | 1 MiB      | GB/s    | direct I/O, `end_fsync=1` |
| `seq_read`   | read      | 1 MiB      | GB/s    | direct I/O                |
| `rand_write` | write     | 4 KiB      | IOPS    | direct I/O, `end_fsync=1` |
| `rand_read`  | read      | 4 KiB      | IOPS    | direct I/O                |

Every workload runs `time_based=1 runtime=60s ramp_time=10s` with
`numjobs=32` and `iodepth=64` per node (2048 in-flight ops per node).
The aggregator (`peak_aggregate_summary.py`) sums per-process fio JSON
output across all 42 nodes for a cluster-wide BW / IOPS figure, plus a
"conservative" wall-clock aggregate (`total_bytes_all / max_runtime_all`)
that doesn't overcount when nodes finish at slightly different moments.

## Cluster Configuration Used

| dimension                | value                                         |
|---                       |---                                            |
| b200 nodes               | 13 tasks × 2 nodes = **26 nodes**             |
| rtx nodes                | 8 tasks × 2 nodes  = **16 nodes**             |
| total client nodes       | **42 nodes**, running simultaneously          |
| cores per node (physical)| **128** on both partitions                    |
| cores used per node      | 96 (`--cpus-per-task=96`)                     |
| fio processes per node   | 1 fio binary, `numjobs=32` worker threads     |
| in-flight ops per node   | 32 × 64 = **2,048**                           |
| total in-flight ops      | 2,048 × 42 = **~86,000**                      |
| NFS mount                | `vers=3, proto=rdma, nconnect=16, rsize/wsize=1M` |
| async engine selected    | `posixaio` on every node (io_uring blocked even on compute nodes) |

## Headline Results

| workload     | cluster_sum  | conservative | vs Vast spec       |
|---           |---           |---           |---                 |
| `seq_read`   | 472.8 GB/s   | **432.9 GB/s** | spec 462 GB/s → 94% of spec (conservative) |
| `seq_write`  |  66.5 GB/s   | **65.5 GB/s**  | spec 165 GB/s → 40% of spec               |
| `rand_read`  | 778.8 kIOPS  | 775.4 kIOPS    | no public Vast IOPS target                |
| `rand_write` | 446.6 kIOPS  | 433.6 kIOPS    | no public Vast IOPS target                |

Per-process bandwidth spread is wide for reads (3.4 → 30.9 GB/s,
median 10.4 GB/s/node), narrow for writes (1.23 → 5.4 GB/s, median 1.4
GB/s/node) — see below for what that means.

## Did This Run Push the Cluster to its Limit?

**For reads — yes against this client pool, but the number is inflated
by server-side cache.** Two pieces of evidence:

1. Per-node read rate (median 10.4 GB/s) is **2× the cold per-NFS-mount
   cap** of ~4.9 GB/s/node that `../raw-io/` measured against cold
   ImageNet data (`../raw-io/out.summary.b200`: 204 GB/s sum-of-rates /
   169 GB/s conservative on the same 42-node pool).
2. The cluster_sum of 472 GB/s is literally above the 462 GB/s Vast spec.
   Storage can't deliver more than its own spec; the extra comes from
   the CBOX server-side cache, which still holds the files this run
   just wrote during its preceding `seq_write` phase.

So the read number is a **storage + cache** measurement, not a pure
storage-tier measurement. Apps that read cold data (like `../raw-io/`'s
ImageNet reads) will see ~200–270 GB/s on this client pool — that's the
honest cold-read ceiling on 42 stock-NFS clients.

**For writes — limited by the client side, not the storage.** 65 GB/s
across 42 nodes = 1.55 GB/s/node, well below the ~5 GB/s per-mount cap.
End_fsync commits, posixaio thread-pool overhead, and the 16x cost of
RPC bookkeeping vs reads all contribute. Storage was not asked to work
hard here.

**For IOPS — engine-bound, not storage-bound.** posixaio implements
async via a glibc userspace thread pool: every op costs a context
switch. The `IOENGINE=auto` probe fell back from io_uring → posixaio on
**every** compute node (visible in `output-peak/*.out`: "engine=posixaio
cpus=0-95"), meaning io_uring is blocked cluster-wide, not just on the
login host. Per-node IOPS of ~18.5k read / 10.6k write is at posixaio's
ceiling, not Vast's.

## Where the Headroom Is

| lever                            | gain potential   | how to apply                      |
|---                               |---               |---                                |
| **Unblock `io_uring` on compute nodes** | ~2–4× IOPS, ~10–20% BW | sysadmin needs to relax kernel.io_uring_disabled or container seccomp |
| Bigger client pool (more nodes)  | +5 GB/s per cold node added | impossible right now — every idle node is already in the run |
| Vast DPC (Data Path Client)      | ~10× per-host BW | proprietary client; ask Vast/cluster team for availability |
| `IODEPTH=128` on b200 (128c)     | a few percent on IOPS | already aggressive at 64; diminishing returns |
| Drop `end_fsync` for writes      | sizable write BW jump, but result is dishonest (ack ≠ committed) | not recommended |

The biggest single lever is **io_uring** — if a compute-node admin can
enable it, the IOPS numbers double or better with no other changes.
Everything else is hardware (more clients or DPC).

## Comparison to the Vast Paper Spec

Vast spec (AICR proposal, 16×7 Gen5/Ceres 1350):
- Max Read **462 GB/s**, Max Write **165 GB/s**, Sustained Write 87.5 GB/s.

| direction | this run (conservative) | % of spec | gap explained by                   |
|---        |---                      |---        |---                                  |
| read      | 432.9 GB/s              | 93.7%     | inflated by CBOX cache; honest cold ≈ 200–270 GB/s on this client pool |
| write     | 65.5 GB/s               | 39.7%     | client-pool-bound + posixaio overhead; ~5 GB/s/client × 42 ≈ 200 GB/s would be possible with io_uring + zero fsync, but writes can't cache |

The Vast paper spec was almost certainly measured with either **many
more clients (100+ hosts) over stock NFS**, or — much more likely —
**DPC**, which lets a single host open parallel data paths to every
CBOX simultaneously and bypass the per-NFS-mount ~5 GB/s cap. Without
DPC, this cluster's stock-NFS ceiling at full availability (~55 nodes
across b200 + rtx + cpu + devel) is:

```
cold-read ceiling  ≈ 55 nodes × 4.9 GB/s/node ≈ 270 GB/s   (~58% of spec)
write     ceiling  ≈ 55 nodes × ~1.5 GB/s/node ≈ 80 GB/s   (~50% of spec, posixaio)
                   ≈ 55 nodes × ~3 GB/s/node   ≈ 165 GB/s  (with io_uring + tuning)
```

In other words, **42 of those 55 nodes ran here**, so the *available*
cluster headroom on top of this run is roughly +30% nodes, not +10×.

## Predicted Real-World Multi-User Aggregate

If many users submit many jobs concurrently across the cluster, the
aggregate they collectively achieve is governed by three properties of
the stock NFS path:

1. **Per-NFS-mount cap**: ~5 GB/s per client mount, even with
   `nconnect=16`. Adding more processes on the same client past saturation
   gives nothing.
2. **VIP-pool fan-out**: each new mount lands on a different CBOX VIP via
   DNS round-robin, so 16 distinct CBOXes each see roughly 1/16 of the
   client mounts. With enough clients (≥16), the CBOXes are evenly
   loaded.
3. **Total client count**: ~55 idle nodes on this cluster on a good day.

Putting these together, the **realistic multi-user aggregate ceiling on
this cluster** is:

```
~55 client nodes × ~5 GB/s read  ≈  275 GB/s read   (≈ 60% of 462 GB/s spec)
~55 client nodes × ~3 GB/s write ≈  165 GB/s write  (≈ 100% of 165 GB/s spec, in theory)
```

The read ceiling stays well under the Vast paper number because the
cluster simply doesn't have enough client nodes to multiply ~5 GB/s up
to 462. To genuinely close the gap to the paper spec, the cluster would
need either:

- **~100+ stock-NFS client nodes** in concurrent use (≈ 2× the present
  client pool), OR
- **Vast DPC available on a handful of hosts**, which would each drive
  20–50 GB/s and bypass the per-mount cap.

Until one of those exists, the **best honest steady-state aggregate this
cluster can show is roughly 250–280 GB/s read and 100–150 GB/s write**,
even with every idle node and every user pushing simultaneously — about
half to 60% of the Vast paper read number, and approaching the paper
write number.

## TL;DR

- 42 nodes (26 b200 + 16 rtx), 128 cores each, 96 used per node, posixaio engine (io_uring blocked everywhere on this cluster, not just login).
- Reads hit **433 GB/s conservative = 94% of Vast spec**, but that's
  cache-inflated; the honest cold-read figure is ~200–270 GB/s, matching
  what `../raw-io/` sees against cold ImageNet data.
- Writes hit **65 GB/s = 40% of spec**, limited by client side, not
  storage (would roughly double with io_uring).
- The gap to the Vast paper number is **client-pool-bound and
  per-mount-cap-bound**, not a fio tuning miss. Closing the gap needs
  DPC or many more clients.
- The two practical knobs left: get io_uring unblocked on compute nodes
  (~2–4× IOPS, ~15% BW) and request DPC access for high-throughput hosts.
