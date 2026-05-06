# bin/concurrent/

Tools for running **multiple** point-to-point IB+CUDA bandwidth tests
**simultaneously** inside a single SLURM allocation, so the pairs all
contend for the fabric at the same time. The single-pair tools in
[`../`](../) are unchanged; this is a separate, layered toolkit.

## How it fits together

```
generators (emit TSV)        submitter             driver
gen_all_on_pair.sh    \                     \
gen_spray_from_node.sh ->  pairs.tsv  ->  submit_concurrent.sh  ->  p2p_concurrent.sbatch
gen_random_pair_sets.sh /                   (validates + ports)      (one allocation,
                                                                      K servers + K clients
                                                                      in parallel)
```

Generators are independent; the submitter only consumes a TSV pair-list
file (or stdin). You can hand-write a TSV too -- the generators are
just convenience.

## TSV pair-list format

One concurrent pair per line. Fields are whitespace separated (tabs or
spaces):

```
nodeA  nodeB  gpuA  gpuB
```

`#` lines and blank lines are ignored. `nodeA != nodeB` per row. GPU
indices are in `0..7`. The submitter validates these.

## Scripts

### Entry points

| script | purpose |
| ------ | ------- |
| [`submit_concurrent.sh`](submit_concurrent.sh) | Read/validate a TSV pair-list (file or stdin), compute the unique node set, assign a unique TCP port per pair (`18515 + i`), and submit one sbatch job that runs every pair concurrently. |
| [`gen_all_on_pair.sh`](gen_all_on_pair.sh) | Use case 1: rail-aligned GPU pairs between two named nodes. |
| [`gen_spray_from_node.sh`](gen_spray_from_node.sh) | Use case 2: each GPU on a single source node sprays at a randomly chosen `(remote_node, remote_gpu)`. |
| [`gen_random_pair_sets.sh`](gen_random_pair_sets.sh) | Use case 3: `K` disjoint node pairs, `M` GPU-GPU pairings inside each (rail or arbitrary). |

### Driver

| script | purpose |
| ------ | ------- |
| [`p2p_concurrent.sbatch`](p2p_concurrent.sbatch) | The SLURM driver. Resolves NIC+NUMA per `(node, gpu)`, captures `nvidia-smi topo -m` per node, records best-effort `ibtracert` per pair, then runs all `K` `ib_write_bw` server+client pairs in parallel inside one allocation. Reuses [`../select_nic_for_gpu.sh`](../select_nic_for_gpu.sh) and [`../record_switch_path.sh`](../record_switch_path.sh); inlines the perftest invocation rather than reusing [`../run_perftest.sh`](../run_perftest.sh) (the single-pair wrapper has no port flag and we don't want to grow it). |

### Helpers reused from the parent `bin/`

- [`../select_nic_for_gpu.sh`](../select_nic_for_gpu.sh) -- pick rail-correct mlx5 + read NUMA from sysfs (used once per unique `(node, gpu)`, results cached).
- [`../record_switch_path.sh`](../record_switch_path.sh) -- best-effort `ibtracert` per pair.

The single-pair scripts under [`../`](../) are not modified or
imported.

## CLI reference

### `gen_all_on_pair.sh <nodeA> <nodeB> [gpu_list]`

Use case 1. `gpu_list` is `all` (default = `0..7`) or a comma list
(`0,2,4,6`).

```bash
gen_all_on_pair.sh b0025 b0026
gen_all_on_pair.sh b0025 b0026 0,2,4,6
```

### `gen_spray_from_node.sh <source_node> [count] [--exclude-nodes HOSTLIST]`

Use case 2. Source node `source_node`'s GPUs `0..count-1` (default
`count=8`) each sprays at a uniformly random `(remote_node,
remote_gpu)` where `remote_node != source_node`. Honors `P2P_SEED`.

```bash
gen_spray_from_node.sh b0025
gen_spray_from_node.sh b0025 8 --exclude-nodes b[0010-0012]
P2P_SEED=12345 gen_spray_from_node.sh b0025
```

### `gen_random_pair_sets.sh <K> [M] [rail|arbitrary] [--exclude-nodes HOSTLIST]`

Use case 3. `K` disjoint node pairs (`2*K` distinct nodes), each pair
emitting `M` GPU-GPU pairings.

- `rail` (default): `gpuA == gpuB`; default `M=8`, max `M=8`.
- `arbitrary`: `gpuA, gpuB` independent; default `M=1`, max `M=64`.

Honors `P2P_SEED`.

```bash
gen_random_pair_sets.sh 4
gen_random_pair_sets.sh 4 8 rail --exclude-nodes b0005,b0017
gen_random_pair_sets.sh 6 2 arbitrary
```

### `submit_concurrent.sh [--file PATH | -] [options]`

```
--file PATH       read TSV from PATH ('-' = stdin; default if omitted)
--name NAME       SLURM job name (default 'p2p_conc')
--time HH:MM:SS   SLURM walltime (default 00:30:00)
--account ACCT    SLURM account (default $SBATCH_ACCOUNT or 'test')
--partition P     SLURM partition (default $SBATCH_PARTITION or 'GPU2')
--max-pairs N     refuse if pair count exceeds N (default 64)
--dry-run, -n     validate, print sbatch invocation, do not submit
```

The submitter materializes the parsed TSV (with assigned ports) into
`results_concurrent/<run_id>/pairs.tsv` before submitting, so the
driver works from a stable file.

## End-to-end examples

```bash
# Use case 1: every rail saturated between two nodes
bin/concurrent/gen_all_on_pair.sh b0025 b0026 \
  | bin/concurrent/submit_concurrent.sh --name allrails

# Use case 2: spray from b0025 across the cluster
bin/concurrent/gen_spray_from_node.sh b0025 \
  | bin/concurrent/submit_concurrent.sh --name spray-b0025

# Use case 3: 4 disjoint node pairs, all 8 rails inside each
bin/concurrent/gen_random_pair_sets.sh 4 8 rail \
  | bin/concurrent/submit_concurrent.sh --name 4x8 --time 01:00:00

# From a hand-written TSV
bin/concurrent/submit_concurrent.sh --file my_pairs.tsv

# Dry run: validate and print the sbatch invocation, submit nothing
bin/concurrent/gen_random_pair_sets.sh 4 8 rail \
  | bin/concurrent/submit_concurrent.sh --dry-run
```

## Output layout

Each submission lands under `results_concurrent/<run_id>/`, where
`<run_id>` is `<YYYY-MM-DD_HHMMSS>__npairs<K>__<name>`:

```
results_concurrent/
  <run_id>/
    pairs.tsv                              # validated input + assigned ports
    params.txt                             # job id, nodelist, K, account/partition, etc.
    nic_selection.txt                      # one line per unique (node, gpu)
    topo.<node>.txt                        # one per unique node
    switch_path.<i>.txt                    # one per pair (i = pair index)
    server.<i>.<nodeA>.log                 # full perftest server log
    client.<i>.<nodeB>.log                 # full perftest client log (the BW table)
    summary.<i>.txt                        # last data row, prefixed with pair identity
    summary.txt                            # aggregate: per-pair rows + sum of BW_avg
  .slurm/<lo>-<hi>/p2p_conc-<jobid>.out    # bucketed sbatch stdout (same scheme as ../)
```

The existing `results/` tree (used by [`../p2p_pair.sbatch`](../p2p_pair.sbatch)
and [`../migrate_results.sh`](../migrate_results.sh)) is not touched.

## Defaults and limits

- **Direction.** Each TSV row is unidirectional (`nodeB -> nodeA`,
  matching [`../../provenance/03_decisions.md`](../../provenance/03_decisions.md)
  decision 5). For full-duplex measurement, list the same pair twice
  with `nodeA` and `nodeB` swapped -- both directions then run
  concurrently in the same allocation.
- **Tool.** `ib_write_bw` on both sides (matches the single-pair
  default; cross-tool combinations are protocol-incompatible per
  [`../../provenance/04_pitfalls.md`](../../provenance/04_pitfalls.md)
  item 1). For read-bandwidth, change *both* `ib_write_bw`
  invocations near the bottom of `p2p_concurrent.sbatch` to
  `ib_read_bw`.
- **Ports.** Pair `i` uses TCP port `18515 + i` (perftest's `-p`).
  This avoids handshake collisions when one node hosts multiple
  servers/clients (e.g. use case 1 with 8 pairs).
- **Max pairs.** `--max-pairs 64` by default. Raise it explicitly
  if you really mean to submit more.
- **Walltime.** Default `00:30:00` (more headroom than the
  single-pair `00:15:00` because the per-pair start-up cost adds
  up). Pass `--time` for very large `K`.

## Per-pair bandwidth below line rate is expected

When concurrent pairs share an HCA or an upstream switch port, each
pair's per-stream BW will be below ~387 Gb/s line rate -- that's the
fabric load you're measuring. The aggregate sum at the bottom of
`summary.txt` is the headline number for "how much total bandwidth
did the cluster actually push during this test."

## See also

- [`../README.md`](../README.md) -- the per-script map for the
  parent `bin/` (single-pair tools, sampler, migrator).
- [`../../README.md`](../../README.md) -- top-level overview, including
  the Concurrent multi-pair tests section pointing here.
- [`../../provenance/`](../../provenance/) -- design decisions,
  behavioral rules, and pitfalls for the project as a whole.
