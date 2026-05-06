# 01 — Original prompt and later additions

## Cluster context (assumed by every script in `bin/`)

- 31 GPU nodes named `b0001` ... `b0031`.
- 8 NVIDIA B200 GPUs per node.
- Each GPU has a directly-affined PCIe network card (an `mlx5_*` HCA),
  identifiable via `nvidia-smi topo -m`.
- Each GPU↔HCA has a 400 Gb/s NDR uplink to a leaf switch.
- The fabric is a **rail-optimized** NDR InfiniBand network — i.e. GPU `N`
  on every node is wired to the same rail's leaf, so the natural
  point-to-point test is GPU `N` ↔ GPU `N` between two nodes.
- Jobs run under SLURM with regular (unprivileged) account credentials.

## Original deliverable as asked

The user asked for a SLURM **sbatch driver** that takes four arguments —
`<nodeA> <nodeB> <gpuA> <gpuB>` — and runs **one** point-to-point bandwidth
test between that GPU pair, recording results into a dated, per-pair
sub-directory tree. Optionally also record the IB switch path between the
two HCAs.

That deliverable lives at [`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch),
with a thin submission wrapper at
[`bin/submit_p2p_pair.sh`](../bin/submit_p2p_pair.sh) that supplies
`--account` / `--partition` / `--nodelist` / `--chdir` / `--export` and
the SLURM `--output` location.

## Building blocks the user provided

Three short markdown files at the top level show what the user already
knew worked on this cluster:

- [`read_command_example.md`](../read_command_example.md) —
  `ib_read_bw -d mlx5_0 --use_cuda=0 -q 8 -a --report_gbits` (server side
  invocation; no host argument).
- [`write_command_example.md`](../write_command_example.md) —
  `ib_write_bw -d mlx5_0 --use_cuda=0 -q 8 -a --report_gbits b0025`
  (client side invocation; with host argument).
- [`salloc_example.md`](../salloc_example.md) —
  `salloc --account test -p GPU2 -N 2 -w b0025,b0026 --time=12:00:00`
  (allocation pattern: two nodes by name, partition `GPU2`, account
  `test`).

**Important:** those two `ib_*_bw` examples are *one half each* of two
**same-tool** tests (read↔read on one pair, write↔write on another).
They are **not** the two halves of one combined `read↔write` test —
that combination fails at the protocol level. See
[`04_pitfalls.md`](04_pitfalls.md) item 1.

## Subsequent additions (in the order asked)

These are layered on top of the original deliverable:

1. **Random sampler** ([`bin/submit_random_pairs.sh`](../bin/submit_random_pairs.sh)) —
   takes a `count`, samples that many pairings from the full ordered
   population and submits one sbatch job each. `P2P_SEED` env var pins
   the PRNG for reproducibility; the seed actually used is always echoed.

2. **`rail` vs `arbitrary` mode flag** for the sampler — `rail`
   (`gpuA == gpuB`, default) tests each GPU's own rail; `arbitrary`
   includes cross-rail pairs that traverse spine.

3. **`--exclude-nodes` flag** on the sampler — accepts comma-separated
   node names *or* a Slurm bracketed hostlist (e.g. `b[0005,0010-0012]`);
   expansion uses `scontrol show hostnames`.

4. **Self-describing `summary.txt`** — the last data row in
   `summary.txt` is now prefixed with
   `<server_node> gpu<N> <client_node> gpu<M>` so a `cat results/.../summary.txt`
   stream is grep-friendly without needing path context.

5. **Restructured output tree** — moved from a flat
   `results/<pair>/<ts>/` layout to a nested
   `results/<server>-gpu<N>/<client>/<pair>/<ts>/` layout, so the
   top-level `ls results/` doesn't blow up to thousands of entries.

6. **One-shot migrator** ([`bin/migrate_results.sh`](../bin/migrate_results.sh)) —
   relocates an existing flat-layout results tree to the new nested
   layout. Idempotent; non-destructive on collisions; supports
   `--dry-run`.

7. **Jobid-bucketed `.slurm/` outputs** — the wrapper now writes SLURM
   stdout to `results/.slurm/<lo>-<hi>/p2p-<jobid>.out` in 2000-id
   buckets, so the `.slurm/` directory itself stays browsable.

## What was deliberately *not* built

These were considered and pushed off in the name of simplicity-first
(see [`02_behavioral_rules.md`](02_behavioral_rules.md)):

- A "test the entire cluster" enumerator (the random sampler is the
  step toward this; full coverage is left to a future iteration).
- Bidirectional / reverse-direction automation in a single job
  (one direction per job; submit the reverse explicitly).
- CSV / JSON aggregation across runs (the prefixed `summary.txt`
  one-liner is the aggregation primitive).
- Retries on perftest failure.
- Same-node (NVLink) tests — out of scope for IB P2P.
