# run-gpu-topology.sh

## Purpose

Collect GPU inventory, topology, CPU affinity, and NIC proximity evidence inside a Slurm allocation.

## Usage

```text
scripts/verify/run-gpu-topology.sh [--help]
```

Cluster normally comes from `AICR_CLUSTER_NAME` or GPU auto-detection inside the
Slurm allocation.

## Options

- `-h`, `--help`: Print usage.

## Outputs

- Raw evidence under `results/by-date/<date>/raw/.../gpu-topology/<run_id>/`.
- Parsed `summary.json` and `status.json`.
- Canonical captures for GPU inventory, GPU topology, CPU topology, and mlx5/NIC topology.

## Examples

Run inside an allocated B200 or RTX job:

```bash
scripts/verify/run-gpu-topology.sh
```

Use [run-gpu-topology-fleet.sh](run-gpu-topology-fleet.md) or `make verify-topology` for normal fleet collection.
