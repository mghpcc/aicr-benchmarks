# bin/

The seven scripts that make up this toolkit. Read the top-level
[`README.md`](../README.md) first for end-to-end usage; this file is the
"what does each script do" map.

## Entry points (you invoke these directly)

| script | purpose | argument signature |
| ------ | ------- | ------------------ |
| [`submit_p2p_pair.sh`](submit_p2p_pair.sh) | Submit one single-pair sbatch job. Sets `--account` / `--partition` / `--nodelist` / `--chdir` / `--export` and the SLURM `--output` location. | `<nodeA> <nodeB> <gpuA> <gpuB>` |
| [`submit_random_pairs.sh`](submit_random_pairs.sh) | Sample N pairings without replacement and submit each via `submit_p2p_pair.sh`. Honors `P2P_SEED` for reproducibility; the seed used is always echoed. | `[--exclude-nodes HOSTLIST] <count> [rail\|arbitrary]` |
| [`migrate_results.sh`](migrate_results.sh) | One-shot in-place migration of an old flat `results/` tree to the current nested layout. Idempotent; non-destructive on collisions. | `[-n\|--dry-run] [--results-dir DIR]` |
| [`p2p_pair.sbatch`](p2p_pair.sbatch) | The SLURM driver itself. Normally invoked via the wrapper above; can also be `sbatch`'d directly with `--account` / `--partition` / `--nodelist` / `--chdir=$PWD` / `--export=ALL,P2P_SCRIPT_DIR=$PWD/bin`. | `<nodeA> <nodeB> <gpuA> <gpuB>` |

Environment variables honored by the entry points:

- `SBATCH_ACCOUNT` (default `test`) — forwarded to `sbatch --account=...`.
- `SBATCH_PARTITION` (default `GPU2`) — forwarded to `sbatch --partition=...`.
- `P2P_SEED` (sampler only) — pin the PRNG for reproducible samples.

## Helpers (used internally; you don't normally call these)

These are `srun`-launched on compute nodes by [`p2p_pair.sbatch`](p2p_pair.sbatch).

| script | purpose | argument signature |
| ------ | ------- | ------------------ |
| [`select_nic_for_gpu.sh`](select_nic_for_gpu.sh) | Pick the rail-correct `mlx5_*` device for a GPU (parses `nvidia-smi topo -m` for PCIe-distance ranking) and read its NUMA node from sysfs. Prints `<mlx5_dev> <numa_node>`. | `<gpu_index>` |
| [`run_perftest.sh`](run_perftest.sh) | Run one `ib_read_bw` / `ib_write_bw` invocation, NUMA-pinned via `numactl --cpunodebind=$numa --membind=$numa` when available. Used as both server (no `<server_host>`) and client. | `<tool> <nic> <gpu> <numa> [server_host]` |
| [`record_switch_path.sh`](record_switch_path.sh) | Best-effort: read each side's LID via `ibstat`, then run `ibtracert <lidA> <lidB>` to dump the switch hop list. Always exits 0; failure is logged into `switch_path.txt` but never fails the bandwidth test. | `<nodeA> <nicA> <nodeB> <nicB>` |

## When you change anything here

If a script's name, argument signature, or environment-variable contract
changes, update the corresponding rows above **and** the relevant
sections of the top-level [`README.md`](../README.md) in the same change.
See [`AGENT_PROMPT.md`](../AGENT_PROMPT.md) ("Documentation discipline")
and [`provenance/README.md`](../provenance/README.md) for the rationale.
