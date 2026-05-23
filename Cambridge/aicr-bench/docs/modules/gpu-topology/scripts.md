# GPU Topology Script Interface

Purpose: document topology collection primitives for custom verification workflows.

## Inspect The Interface

Allocation-side runner:

<!-- aicr-test
id: gpu-topology-run-help
suite: gpu-topology
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Usage:"
    - "AICR_CLUSTER_NAME"
-->
```bash
scripts/verify/run-gpu-topology.sh --help
```

Host-side fleet runner:

<!-- aicr-test
id: gpu-topology-fleet-help
suite: gpu-topology
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Usage:"
    - "--cluster"
    - "--nodes"
    - "--apply"
-->
```bash
scripts/verify/run-gpu-topology-fleet.sh --help
```

## Direct Use

Use [run-gpu-topology.sh](../../../man/run-gpu-topology.md) inside a Slurm allocation. Use [run-gpu-topology-fleet.sh](../../../man/run-gpu-topology-fleet.md) from the install root to dry-run or submit one topology job per selected node.

Topology collection can still be useful when a node fails visible-GPU preflight:
the collected `nvidia-smi -L`, topology, CPU, and NIC evidence explains what
the scheduler-visible node actually exposed.

## Artifacts

Direct topology runner and fleet-runner executions write node-level raw captures,
parsed summaries, fleet manifests, and index records. Rendered dashboards are
renderer or Make outputs and are intentionally not listed here.

Raw run directory:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/gpu-topology/<run_id>/
```

Canonical files:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/gpu-topology/<run_id>/canonical/nvidia-smi-L.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gpu-topology/<run_id>/canonical/nvidia-smi-topo-m.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gpu-topology/<run_id>/canonical/lscpu.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gpu-topology/<run_id>/canonical/mlx5-topology.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gpu-topology/<run_id>/canonical/gds-storage-topology.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gpu-topology/<run_id>/canonical/gpu-topology-summary.txt
```

Parsed, manifest, and index files:

```text
results/by-date/<date>/parsed/<cluster>/nodes/<node>/gpu-topology/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/nodes/<node>/gpu-topology/<run_id>/status.json
results/reports/<date>/gpu-topology/<manifest>.json
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
```
