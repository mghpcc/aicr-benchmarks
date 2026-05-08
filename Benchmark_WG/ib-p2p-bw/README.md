# b200-ib-cuda-point-to-point

Tools for measuring point-to-point GPU↔GPU bandwidth between B200 nodes over a
rail-optimized NDR InfiniBand fabric, via CUDA-aware `perftest`.

## What this does

The toolkit covers four tasks:

1. Run **one** point-to-point bandwidth test between a chosen GPU pair on
   two named nodes ([`bin/submit_p2p_pair.sh`](bin/submit_p2p_pair.sh) +
   [`bin/p2p_pair.sbatch`](bin/p2p_pair.sbatch)).
2. **Randomly sample** N pairings across the cluster and submit them as
   N independent jobs
   ([`bin/submit_random_pairs.sh`](bin/submit_random_pairs.sh)).
3. Run **multiple pairs concurrently inside a single SLURM allocation**
   so they all contend for the fabric at the same time
   ([`bin/concurrent/`](bin/concurrent/)). Use cases include "every
   rail between two nodes", "spray from one node across the cluster",
   and "K disjoint node pairs in parallel".
4. **Migrate** an existing flat-layout `results/` tree to the current
   nested layout ([`bin/migrate_results.sh`](bin/migrate_results.sh)).

The single-pair driver is the core; the others are layered on top.

### Single pair

One SLURM job tests **one direction** between **one pair of GPUs**:

- `nodeA` runs `ib_write_bw -d <nicA> --use_cuda=<gpuA> -q 8 -a --report_gbits`         (server)
- `nodeB` runs `ib_write_bw -d <nicB> --use_cuda=<gpuB> -q 8 -a --report_gbits <nodeA>` (client)

The client writes to the server, so this measures RDMA-WRITE bandwidth in
the direction **`nodeB` → `nodeA`**. To test the reverse direction, submit a
second job with the node arguments swapped.

Per side, the rail-correct `mlx5_*` device is auto-selected from
`nvidia-smi topo -m` (closest PCIe affinity to the requested GPU), the NUMA
node is read from `/sys/class/infiniband/<dev>/device/numa_node`, and the
perftest process is NUMA-pinned (`numactl --cpunodebind --membind`).
The IB switch path between the two HCAs is recorded best-effort via
`ibtracert`.

## Layout

```
bin/
  submit_p2p_pair.sh      wrapper: sets account/partition/nodelist, calls sbatch
  submit_random_pairs.sh  random-sampler driver: submits N independent jobs
  migrate_results.sh      one-shot flat-to-nested results migrator
  p2p_pair.sbatch         the SLURM driver (the main deliverable)
  select_nic_for_gpu.sh   parse `nvidia-smi topo -m`, pick rail-correct mlx5 + NUMA
  run_perftest.sh         NUMA-pinned wrapper around ib_read_bw / ib_write_bw
  record_switch_path.sh   best-effort `ibtracert` between two HCAs
  concurrent/             multi-pair concurrent tests (separate toolkit)
results/
  <nodeA>-gpu<N>/                                # server endpoint
    <nodeB>/                                     # client node
      <nodeA>-gpu<N>__<nodeB>-gpu<M>/            # full pair name
        <YYYY-MM-DD_HHMMSS>/                     # one dir per run
  .slurm/                                        # raw sbatch stdout
    <jobid_lo>-<jobid_hi>/                       # bucketed 2000 ids per dir
      p2p-<jobid>.out
```

See [`bin/README.md`](bin/README.md) for the per-script signature map.

## Usage: single pair

```bash
# Defaults: --account=test --partition=GPU2 (override via env)
bin/submit_p2p_pair.sh b0025 b0026 0 0

# Override account / partition:
SBATCH_ACCOUNT=myproj SBATCH_PARTITION=GPU2 \
  bin/submit_p2p_pair.sh b0025 b0026 0 0

# Or invoke sbatch directly:
sbatch --account=test --partition=GPU2 --nodelist=b0025,b0026 \
       bin/p2p_pair.sbatch b0025 b0026 0 0
```

Each run produces a dated subdirectory under
`<submit_dir>/results/<nodeA>-gpu<N>/<nodeB>/<nodeA>-gpu<N>__<nodeB>-gpu<M>/`,
where `<submit_dir>` is the directory you ran `submit_p2p_pair.sh` from
(i.e. SLURM's `$SLURM_SUBMIT_DIR`). The extra nesting (server endpoint /
client node / pair name) keeps the top-level `results/` listing small even
across thousands of runs. Multiple runs of the same pair never overwrite.

Direct `sbatch` invocations: pass
`--chdir=$PWD --export=ALL,P2P_SCRIPT_DIR=/abs/path/to/bin` so the script can
locate its helpers and write outputs into your submit directory rather than
the slurmd spool directory.

## Usage: random sampling

[`bin/submit_random_pairs.sh`](bin/submit_random_pairs.sh) enumerates the
full population of ordered `(nodeA, nodeB, gpuA, gpuB)` tuples, samples
without replacement via Fisher-Yates, and submits each sample as its own
`submit_p2p_pair.sh` job.

Modes (population sizes for the default 31-node, 8-GPU cluster):

| mode        | constraint            | population        |
| ----------- | --------------------- | ----------------- |
| `rail`      | `gpuA == gpuB`        | 31 × 30 × 8 = 7440  |
| `arbitrary` | `gpuA`, `gpuB` independent | 31 × 30 × 8 × 8 = 59520 |

In both modes `nodeA != nodeB`, and `(A,B,...)` and `(B,A,...)` are
distinct samples (each tests one direction).

Reproducibility: if `P2P_SEED` is set in the environment it's used as the
PRNG seed; otherwise a fresh seed is generated per invocation. The seed
actually used is **always echoed**, with a one-line "re-run with this
P2P_SEED= ..." hint so any sample can be reproduced exactly.

`--exclude-nodes` accepts comma-separated names, a Slurm bracketed
hostlist, or a mix; expansion uses `scontrol show hostnames`.

```bash
bin/submit_random_pairs.sh 5

P2P_SEED=12345 bin/submit_random_pairs.sh 5 rail

bin/submit_random_pairs.sh --exclude-nodes 'b[0005,0017-0019]' 20 arbitrary
```

`SBATCH_ACCOUNT` / `SBATCH_PARTITION` env overrides are forwarded to the
per-pair wrapper, so the same overrides work here.

## Migrating an old results tree

If you have an existing `results/` tree from before the nested layout
landed (top-level dirs named `<nodeA>-gpu<a>__<nodeB>-gpu<b>`),
[`bin/migrate_results.sh`](bin/migrate_results.sh) relocates them
in place:

```
old:  results/<nodeA>-gpu<a>__<nodeB>-gpu<b>/<ts>/...
new:  results/<nodeA>-gpu<a>/<nodeB>/<nodeA>-gpu<a>__<nodeB>-gpu<b>/<ts>/...
```

```bash
bin/migrate_results.sh -n        # dry run — print MOVE / SKIP lines, do nothing
bin/migrate_results.sh           # actually move the directories
bin/migrate_results.sh --results-dir /path/to/results  # non-default location
```

Idempotent: re-runs only move what's still in the old layout; already-
nested dirs and `.slurm/` are left alone. Collisions on the destination
side are reported with `SKIP` and never overwrite.

## SLURM stdout layout

The wrapper writes per-job sbatch stdout under
`results/.slurm/<lo>-<hi>/p2p-<jobid>.out`, where `<lo>-<hi>` is the
2000-id bucket containing the predicted next jobid (read from
`scontrol show config | NextJobId`). This keeps the `.slurm/` listing
browsable across thousands of submissions. If the actual jobid lands
across the next 2000-boundary the file is at most one bucket off; the
filename always encodes the real jobid. If `scontrol` is unavailable or
doesn't report `NextJobId`, the wrapper falls back to a flat
`results/.slurm/p2p-<jobid>.out`.

## Concurrent multi-pair tests

Sometimes the question isn't "what bandwidth can one rail sustain" but
"what happens when many pairs share the fabric at once". The
[`bin/concurrent/`](bin/concurrent/) tools run **K pairs simultaneously
inside a single SLURM allocation**, so the fabric is genuinely loaded
during the measurement. The single-pair tools above are unchanged --
this is a separate, layered toolkit. See
[`bin/concurrent/README.md`](bin/concurrent/README.md) for the full
reference.

The data flow is generator -> TSV pair-list -> submitter ->
sbatch driver. Each generator emits a TSV; the submitter validates it,
assigns a unique TCP port per pair (`18515 + i`), and submits one
sbatch job that runs all pairs in parallel.

```bash
bin/concurrent/gen_all_on_pair.sh b0025 b0026 \
  | bin/concurrent/submit_concurrent.sh --name allrails

bin/concurrent/gen_spray_from_node.sh b0025 \
  | bin/concurrent/submit_concurrent.sh --name spray-b0025

bin/concurrent/gen_random_pair_sets.sh 4 8 rail \
  | bin/concurrent/submit_concurrent.sh --name 4x8 --time 01:00:00
```

`P2P_SEED`, `--exclude-nodes`, `SBATCH_ACCOUNT`, and `SBATCH_PARTITION`
all behave the same as in [`bin/submit_random_pairs.sh`](bin/submit_random_pairs.sh).
Add `--dry-run` to the submitter to see the parsed pair list and the
exact `sbatch` invocation without submitting anything.

Output goes to `results_concurrent/<run_id>/`, parallel to (and
disjoint from) `results/`. Each run produces per-pair logs and an
aggregate `summary.txt` whose final line is the sum of measured
`BW_avg` across all concurrent pairs.

When concurrent pairs share an HCA or upstream link, **per-pair BW will
fall below line rate** -- that's the test, not a bug. The aggregate
sum is the headline number.

## Output files (per run)

| file                                  | contents                                                     |
| ------------------------------------- | ------------------------------------------------------------ |
| `params.txt`                          | the four CLI args, timestamp, SLURM job id, nodelist         |
| `nic_selection.txt`                   | resolved `(nic, numa)` for each (node, gpu)                  |
| `topo.<nodeA>.txt`, `topo.<nodeB>.txt`| `nvidia-smi topo -m` snapshot from each node                 |
| `switch_path.txt`                     | LIDs and `ibtracert` hop list (or failure note)              |
| `server.<nodeA>.ib_write_bw.log`      | full server-side perftest output                             |
| `client.<nodeB>.ib_write_bw.log`      | full client-side perftest output (the bandwidth table)       |
| `summary.txt`                         | one-line headline: last data row from the client log         |

## Assumptions / caveats

- **Same tool on both sides (`ib_write_bw`/`ib_write_bw`).** Mixing
  `ib_read_bw` server with `ib_write_bw` client passes the Ethernet handshake
  but fails at the first packet with `IBV_WC_REM_OP_ERR` / syndrome 0x8a:
  the read-side server registers its memory region with READ-only access, so
  the client's RDMA_WRITE is rejected. To measure read-bandwidth instead,
  change *both* sides in `bin/p2p_pair.sbatch` to `ib_read_bw`.
- **Bare hostnames work for the client connect target.** `ib_write_bw b0025`
  resolves the host's IP and lets RDMA-CM negotiate the IB connection.
- **`numactl` is available on compute nodes.** If absent, the wrapper
  silently runs without pinning.
- **`ibtracert` is best-effort.** Some clusters' subnet managers restrict it;
  failures are logged but don't fail the bandwidth test.
- **Nodelist must be passed at submit time.** The sbatch script re-uses the
  job's allocated nodes via `srun -w`; it does not fan out beyond them.
- **CPU frequency.** perftest may print `Conflicting CPU frequency values
  detected: ... CPU Frequency is not max.` This is informational; on this
  cluster you still hit ~387 / 400 Gb/s line rate, so it's not worth chasing
  unless you're investigating a slower-than-expected pair.

## Not included (deliberately)

- No bidirectional / reverse-direction automation in a single job. To
  cover both directions, submit a second job with the node arguments
  swapped (or rely on the random sampler — `(A,B,…)` and `(B,A,…)` are
  distinct samples there).
- No CSV/JSON aggregation across runs (`summary.txt` is grep-friendly
  and self-describing — see [`provenance/03_decisions.md`](provenance/03_decisions.md)
  decision 8).
- No retries on perftest failure.
- No same-node (NVLink) tests — out of scope for IB P2P.

## See also

- [`bin/README.md`](bin/README.md) — per-script purpose + arg signatures.
- [`bin/concurrent/README.md`](bin/concurrent/README.md) — multi-pair
  concurrent tests (separate from the single-pair toolkit).
- [`provenance/`](provenance/README.md) — design decisions, behavioral
  rules, and pitfalls; read top-to-bottom before changing anything in
  [`bin/`](bin/).
- [`provenance/agent_guidance/`](provenance/agent_guidance/) — pinned
  copies of the external behavioral-rule files this repo was built
  under.
- [`AGENT_PROMPT.md`](AGENT_PROMPT.md) — the as-given task description
  and meta-rules.
- Building-block command examples used during the original design:
  [`read_command_example.md`](read_command_example.md),
  [`write_command_example.md`](write_command_example.md),
  [`salloc_example.md`](salloc_example.md).
