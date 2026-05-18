# GPU Topology Examples

Purpose: provide representative topology commands.

## Build Your Own Slurm Workload

This example starts from the script primitive directly. Keep one `exec` line
active and align scheduler resources with the selected cluster.

```bash
#!/usr/bin/env bash
#SBATCH --job-name=aicr-gpu-topology
#SBATCH --partition=<GPU1-or-GPU2>
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=<gpu-type-and-count>
#SBATCH --time=00:10:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

REPO_ROOT="${AICR_BMARK_DIR:?set AICR_BMARK_DIR to your aicr-bench install root}"
cd "$REPO_ROOT"
source "${AICR_SETTINGS_FILE:-$REPO_ROOT/benchmark-settings.env}"

# Keep exactly one exec line active.
exec ./scripts/verify/run-gpu-topology.sh
```

Use the cluster-specific templates when you want the repo's scheduler defaults
already spelled out:

- [b200-gpu-topology-1n-8g.sbatch](../../../slurm/verify/b200-gpu-topology-1n-8g.sbatch)
- [rtxpro6000-gpu-topology-1n-8g.sbatch](../../../slurm/verify/rtxpro6000-gpu-topology-1n-8g.sbatch)

## Dry Run

```bash
make verify-topology CLUSTER=b200
```

## Submit A One-Node Collection

<!-- aicr-test
id: gpu-topology-example-one-node-apply
suite: gpu-topology
kind: slurm-apply
safety: one-node
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Submitted"
-->
```bash
make verify-topology CLUSTER={{cluster}} NODELIST={{node}} APPLY=1
```

## Render Existing Evidence

Dashboard re-render is an HPC replay step. It expects the
`results/reports/<date>/gpu-topology/` manifest tree produced by an applied
topology collection.

```bash
scripts/operator/aicr render gpu-topology --date <YYYY-MM-DD> --cluster b200 --both
```

Artifacts produced after `APPLY=1`:

- GPU inventory and topology captures.
- CPU, NUMA, and mlx5/NIC affinity evidence.
- Parsed topology status and fleet dashboard.
- Reviewed evidence lives in [GPU topology studies](studies.md).
