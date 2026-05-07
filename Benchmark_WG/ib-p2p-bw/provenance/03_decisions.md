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

## 10. Concurrent multi-pair toolkit lives in its own subdir

**Decision.** The concurrent multi-pair tooling lives entirely under
[`bin/concurrent/`](../bin/concurrent/) -- three TSV generators
(`gen_all_on_pair.sh`, `gen_spray_from_node.sh`,
`gen_random_pair_sets.sh`), one TSV-consuming submitter
(`submit_concurrent.sh`), and one sbatch driver
(`p2p_concurrent.sbatch`). The single-pair scripts in
[`bin/`](../bin/) are not modified. Output goes to
`results_concurrent/<run_id>/`, parallel to the existing
`results/`.

**Rationale.** The user's exact phrasing: *"this should be a separate
set of scripting from the current tools so things in the current tools
stay simple."* That rules out (a) bolting `--concurrent` flags onto
[`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch) and (b) growing
[`bin/run_perftest.sh`](../bin/run_perftest.sh) with a `--port` arg.
Both were tempting -- they'd save a few lines -- but each one would
have made the single-pair flow harder to read.

**Where.** Everything new is under
[`bin/concurrent/`](../bin/concurrent/) plus the corresponding doc
edits in [`README.md`](../README.md), [`bin/README.md`](../bin/README.md),
and this file.

## 11. Concurrent driver inlines perftest, reuses helpers read-only

**Decision.** [`bin/concurrent/p2p_concurrent.sbatch`](../bin/concurrent/p2p_concurrent.sbatch)
calls `numactl ... ib_write_bw -d $nic --use_cuda=$gpu -q 8 -a
--report_gbits -p $port [<host>]` inline rather than invoking
[`bin/run_perftest.sh`](../bin/run_perftest.sh). It does reuse
[`bin/select_nic_for_gpu.sh`](../bin/select_nic_for_gpu.sh) and
[`bin/record_switch_path.sh`](../bin/record_switch_path.sh) without
modification.

**Rationale.** The single-pair `run_perftest.sh` has no concept of a
TCP port -- adding `--port N` would touch the simplest, most stable
script in the project for a feature only the concurrent driver needs.
Five inline lines in the concurrent driver was strictly cheaper than
a shared abstraction. By contrast, `select_nic_for_gpu.sh` and
`record_switch_path.sh` are true read-only primitives that ask one
question of the system and print the answer; reusing them as-is keeps
the concurrent driver's responsibilities narrow.

**Where.** Inline `ib_write_bw` invocations in the `[4/6]` and
`[5/6]` blocks of
[`bin/concurrent/p2p_concurrent.sbatch`](../bin/concurrent/p2p_concurrent.sbatch);
borrowed helpers used in `[1/6]` and `[3/6]`.

## 12. Per-pair TCP port = `18515 + pair_index`

**Decision.** Each concurrent pair gets a distinct perftest TCP port
assigned by the submitter: pair `i` uses `18515 + i`. The port is
recorded as column 2 of the materialized `pairs.tsv` and passed to
both server and client via `ib_write_bw -p`.

**Rationale.** perftest defaults to TCP `18515` for its handshake.
With the use-case-1 layout (8 pairs sharing the same two nodes), all
8 servers on `nodeA` and all 8 clients on `nodeB` would otherwise try
to bind/connect on `18515`, only one would win, the rest would fail
in non-obvious ways. Port-per-pair, assigned centrally by the
submitter, is the simplest correct answer and stays well inside the
unprivileged port range. There is no port reuse across concurrent
pairs in a single allocation.

**Where.** Port assignment in the materialization block of
[`bin/concurrent/submit_concurrent.sh`](../bin/concurrent/submit_concurrent.sh);
the inline `ib_write_bw -p $port` in the driver.

## 13. Plain TSV pair-list format (no YAML/JSON)

**Decision.** The pair list is a whitespace-separated TSV: one row per
concurrent pair with fields `nodeA nodeB gpuA gpuB`. After the submitter
materializes it, two more leading fields appear: `idx port nodeA nodeB
gpuA gpuB`. `#` lines and blank lines are ignored.

**Rationale.** Same shape as what
[`bin/submit_random_pairs.sh`](../bin/submit_random_pairs.sh) already
emits internally. Pure-bash parseable -- no YAML/JSON dependency, no
`yq`/`jq` on the cluster nodes. The Karpathy "minimum code that
solves the problem" rule was explicit here. Generators emit; the
submitter validates; the driver consumes. One contract.

**Where.** Format documented in
[`bin/concurrent/README.md`](../bin/concurrent/README.md) and at the
top of each generator. Validation in
[`bin/concurrent/submit_concurrent.sh`](../bin/concurrent/submit_concurrent.sh).

## 14. Balanced sampling is the default for `gen_random_pair_sets.sh`

**Decision.** [`bin/concurrent/gen_random_pair_sets.sh`](../bin/concurrent/gen_random_pair_sets.sh)
defaults to `--balance` -- meaning every `(node, gpu)` tuple appears in
**at most one row** across the whole emitted TSV. `--no-balance` (with
`--off-balance` as a synonym) restores the prior arbitrary-mode
behavior, where the same `gpuA` value can appear in multiple rows of a
single node pair (one source GPU loaded against several remote GPUs).

In rail mode the flag has no effect: `gpuA == gpuB` and the M GPU
indices are picked by Fisher-Yates over `{0..7}` truncated to M, so M
distinct indices are used on each side. Combined with K disjoint node
pairs, rail mode is structurally always balanced.

The behavioral change is therefore only in arbitrary mode:

- `--balance` arbitrary: per node pair, two independent Fisher-Yates
  shuffles of `{0..7}` produce `gA` and `gB`; emit `M` rows
  `(A, B, gA[i], gB[i])`. M cap = 8.
- `--no-balance` arbitrary: Fisher-Yates over the 64-cell `(gpuA,
  gpuB)` grid; emit M rows in shuffled order. M cap = 64.

**Rationale.** When the user wants concurrent fabric load (use case
3), the typical question is "how does the cluster handle K*M
distinct GPU-to-GPU streams running at once". The unbalanced
behavior reuses GPUs on one side, which means the *same* HCA pushes
multiple of those streams -- a different test (HCA-saturation) and
rarely what the operator actually wanted. Making balance the default
makes the typical case the natural case; the unbalanced case is
still one flag away when explicitly desired.

K-disjoint-node-pairs structure is preserved either way -- the flag
changes only the within-pair gpu-pairing rule, not which nodes
participate. M cap reduction (64 -> 8) under `--balance` is enforced
with a clear error pointing at `--no-balance` for the higher cap.

**Where.** Flag parsing, M validation, and the third (balanced)
branch of the inner awk in
[`bin/concurrent/gen_random_pair_sets.sh`](../bin/concurrent/gen_random_pair_sets.sh).
The CLI documentation lives in
[`bin/concurrent/README.md`](../bin/concurrent/README.md) under the
generator's section.

The chosen flag value is echoed in the `# generator: ...` header
comment so any TSV is self-describing about how it was sampled.
