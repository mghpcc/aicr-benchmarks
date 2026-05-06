# 03 — Design decisions

The choices below shaped the code in [`bin/`](../bin/). Each has a
short rationale and a pointer to where it actually lives. Future
maintainers: if you find yourself proposing to *reverse* one of these
without strong cause, please re-read the rationale and the linked
[`04_pitfalls.md`](04_pitfalls.md) entry first.

## 1. Same perftest tool on both sides

**Decision.** `bin/p2p_pair.sbatch` runs `ib_write_bw` as the server
(no host arg) on `nodeA` and `ib_write_bw` as the client (with host
arg `nodeA`) on `nodeB`. Direction is `B → A` (client writes to
server).

**Rationale.** Initially planned as mixed `ib_read_bw` server +
`ib_write_bw` client, taking the two example files literally. That
combination passes the Ethernet handshake and then dies at the first
RDMA op with `IBV_WC_REM_OP_ERR` syndrome `0x8a` because the
read-side server's MR is registered with READ-only access. See
[`04_pitfalls.md`](04_pitfalls.md) item 1.

**Where.** Server and client invocations near the bottom of
[`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch).

**Read-bandwidth variant.** Change *both* sides to `ib_read_bw` —
one-line edit. Direction then becomes `A → B` (client reads from
server).

## 2. Defaults `test` / `GPU2`, env-overridable

**Decision.** `SBATCH_ACCOUNT` defaults to `test`, `SBATCH_PARTITION`
defaults to `GPU2`. Both can be overridden by environment variables
of the same name.

**Rationale.** The user asked for these specific defaults to match
their cluster's policy, plus an escape hatch for other accounts.
Hardcoding them in `#SBATCH` headers would have made the override
clumsy.

**Where.** Top of
[`bin/submit_p2p_pair.sh`](../bin/submit_p2p_pair.sh): `acct=...`
and `part=...` lines, which are then passed to `sbatch` as
`--account` / `--partition`. The wrapper owns the policy; the
sbatch script is policy-free.

## 3. NUMA pinning via `numactl`, NUMA index from sysfs

**Decision.** Each perftest process is wrapped with
`numactl --cpunodebind=$numa --membind=$numa`. The NUMA index is
read directly from
`/sys/class/infiniband/<dev>/device/numa_node` (a single integer).

**Rationale.** B200 / NDR setups need CPU-NUMA locality with the
HCA to avoid PCIe-cross-NUMA bottlenecks; the user said "yes,
NUMA pin." The first cut tried to read NUMA from the
`nvidia-smi topo -m` matrix, which broke (see
[`04_pitfalls.md`](04_pitfalls.md) item 2). Sysfs gives a single
integer, never wrong.

**Where.** NIC pick + sysfs NUMA read in
[`bin/select_nic_for_gpu.sh`](../bin/select_nic_for_gpu.sh);
the wrapping `numactl` invocation in
[`bin/run_perftest.sh`](../bin/run_perftest.sh) (with a graceful
no-pin fallback if `numactl` is missing).

## 4. Bare hostnames work for the client connect target

**Decision.** The client invokes `ib_write_bw -d ... <nodeA>` using
the bare SLURM hostname (e.g. `b0025`).

**Rationale.** On this cluster the bare hostname resolves to an
Ethernet IP, RDMA-CM negotiates the IB link, and it just works. No
separate `<host>-ib` or static-route mapping is needed.

**Where.** Client invocation block in
[`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch). If you ever port
this to a cluster where the bare name *doesn't* resolve to an
RDMA-CM-reachable address, this is where the change lands.

## 5. One direction per job

**Decision.** Each submitted sbatch job tests one direction
(`B → A` for the default `ib_write_bw`/write-bw setup). To test
the reverse, submit a second job with `nodeA` and `nodeB` swapped.

**Rationale.** Cleanest semantics: one job, one log, one
`summary.txt`, one bandwidth number. The alternative (build the
reverse direction into the same job) doubles the script's surface
area for marginal benefit.

**Where.** The four CLI args of
[`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch) are
`<nodeA> <nodeB> <gpuA> <gpuB>`; nothing in the script is
direction-symmetric.

## 6. Output tree nesting (server-gpu / client / pair / ts)

**Decision.** Per-run outputs live under
`results/<nodeA>-gpu<gpuA>/<nodeB>/<nodeA>-gpu<gpuA>__<nodeB>-gpu<gpuB>/<YYYY-MM-DD_HHMMSS>/`.

**Rationale.** A flat `results/<pair>/<ts>/` layout produced
~2300 entries at the top level after a few hundred submissions.
The nested layout caps `ls results/` at ~248 (one per
*tested* `(server, server_gpu)` endpoint), then narrows
quickly. Timestamp stays innermost so re-runs of the same pair
never overwrite.

**Where.** `outdir=` line in
[`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch). Migration from
the old flat layout: [`bin/migrate_results.sh`](../bin/migrate_results.sh).

## 7. Random sampler design

**Decision.** [`bin/submit_random_pairs.sh`](../bin/submit_random_pairs.sh)
enumerates the full population, shuffles via Fisher-Yates inside
awk seeded by `srand(P2P_SEED ?: per-call random)`, slices the
top `count`, and submits each via the wrapper.

Population:

- **Ordered tuples** — `(A, B, gA, gB)` and `(B, A, gA, gB)` are
  distinct samples, since each tests one direction (decision 5).
- **`rail` mode** (default) — `gpuA == gpuB`. Population
  `31 × 30 × 8 = 7440`.
- **`arbitrary` mode** — `gpuA, gpuB` independent. Population
  `31 × 30 × 8 × 8 = 59520`.
- **`--exclude-nodes`** — drops any pairing whose `nodeA` or `nodeB`
  is in the exclude set, before sampling.

**Rationale.** Awk's PRNG is sufficient for this; pulling in
`shuf` or Python would be over-engineering. Fisher-Yates +
top-N is correct uniform sampling without replacement.
Hostlist parsing delegates to `scontrol show hostnames` so we
inherit Slurm's syntax (`b[0001-0003,0010]`) for free.

**Where.** Awk block in
[`bin/submit_random_pairs.sh`](../bin/submit_random_pairs.sh);
hostlist expansion and seed printing are in the surrounding
bash.

## 8. Self-describing summary lines

**Decision.** The last data row in each `summary.txt` is prefixed
with `<server_node> gpu<server_gpu> <client_node> gpu<client_gpu>`,
so:

```
b0016 gpu2 b0031 gpu1 8388608    40000            387.16  387.16  0.005769
```

**Rationale.** `cat results/*/*/*/*/summary.txt | grep -v '^#'`
becomes self-explanatory — one line per run, no path-context
needed for downstream parsing. Cheaper than building a
CSV/JSON pipeline and carries the same information.

**Where.** Awk block in the `summarizing` step of
[`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch).

## 9. Jobid-bucketed `.slurm/` outputs

**Decision.** SLURM stdout files go to
`results/.slurm/<bucket_lo>-<bucket_hi>/p2p-<jobid>.out` where the
bucket is the 2000-id range containing the predicted next jobid
(read from `scontrol show config | NextJobId`).

**Rationale.** Same goal as decision 6 (keep `ls` browsable) but
for the SLURM stdout dir. The user's instruction was explicit:
*"Just have the wrapper script set the slurm output dir. Don't try
and do anything clever."* So the wrapper computes the bucket once
from the predicted jobid, creates the dir, and passes
`--output=...` to sbatch. Bucket-edge slop is at most one bucket;
the actual jobid in the filename is always correct.

**Where.** `slurm_out_dir=` block in
[`bin/submit_p2p_pair.sh`](../bin/submit_p2p_pair.sh). Falls back
to flat `results/.slurm/` if `scontrol` is unavailable or doesn't
report `NextJobId`.
