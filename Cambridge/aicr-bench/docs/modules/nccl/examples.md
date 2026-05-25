# NCCL Examples

Purpose: provide a Slurm primitive workload, representative Make commands, and expected artifact classes.

## Build Your Own Slurm Workload

This example starts from the script primitive directly. Keep one `exec` line active and comment out the others while customizing. Committed copy: [slurm-nccl.sbatch](slurm-nccl.sbatch).

```bash
#!/usr/bin/env bash
#SBATCH --job-name=aicr-nccl-primitive
#SBATCH --partition=<rtx-batch-or-b200-batch>
#SBATCH --nodes=1
#SBATCH --ntasks=8
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --mem=0
#SBATCH --gres=<gpu-type-and-count>
#SBATCH --time=02:30:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

# Replace the partition and GRES placeholders before submitting.
# AICR HPC scheduler examples:
#   RTX:  #SBATCH --partition=rtx-batch and #SBATCH --gres=gpu:rtxpro6000:8
#   B200: #SBATCH --partition=b200-batch and #SBATCH --gres=gpu:b200:8

# Keep #SBATCH --mem=0 or --mem=0 on the sbatch command line so the job
# inherits the full per-node memory; NCCL validation is sensitive to Slurm's
# default per-job memory cap.

REPO_ROOT="${AICR_BMARK_DIR:?set AICR_BMARK_DIR to your aicr-bench install root}"
cd "$REPO_ROOT"
source "${AICR_SETTINGS_FILE:-$REPO_ROOT/benchmark-settings.env}"
# Optional when GPU auto-detection is not enough:
# export AICR_CLUSTER_NAME=rtxpro6000
# export AICR_CLUSTER_NAME=b200
PEER_NODES_CSV="$(scontrol show hostnames "$SLURM_JOB_NODELIST" | paste -sd, -)"
export PEER_NODES_CSV

# Keep exactly one exec line active. Align #SBATCH nodes, tasks, and GPUs with it.
exec ./scripts/verify/run-nccl-suite.sh --scope local --profile small
# exec ./scripts/verify/run-nccl-suite.sh --scope rdma --profile small --nodes-per-job 2
```

Replace the scheduler placeholders, then submit the customized workload. If the template was copied outside the install tree, pass the install root explicitly:

```bash
sbatch --mem=0 --export=ALL,AICR_BMARK_DIR=/path/to/aicr-bench slurm-nccl.sbatch
```

## Slurm Sbatch Scripts

Use the module-local primitive when you want a compact starting point. Use the
cluster-specific templates when you want the repo's scope and cluster defaults
already spelled out.

- [slurm-nccl.sbatch](slurm-nccl.sbatch)
- [b200-nccl-suite-local-1n-8g.sbatch](../../../slurm/verify/b200-nccl-suite-local-1n-8g.sbatch)
- [b200-nccl-suite-rdma.sbatch](../../../slurm/verify/b200-nccl-suite-rdma.sbatch)
- [b200-nccl-suite-scale.sbatch](../../../slurm/verify/b200-nccl-suite-scale.sbatch)
- [rtxpro6000-nccl-suite-local-1n-8g.sbatch](../../../slurm/verify/rtxpro6000-nccl-suite-local-1n-8g.sbatch)
- [rtxpro6000-nccl-suite-rdma.sbatch](../../../slurm/verify/rtxpro6000-nccl-suite-rdma.sbatch)
- [rtxpro6000-nccl-suite-scale.sbatch](../../../slurm/verify/rtxpro6000-nccl-suite-scale.sbatch)

## Using the Make Interface

### One Node Local Dry Run

<!-- aicr-test
id: nccl-example-one-node-dry-run
suite: nccl
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "scope=local"
    - "Dry run"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0002
```

Artifacts produced after `APPLY=1`:

- NCCL suite command capture.
- Parsed operation rows for the selected profile and scope.
- Rendered suite report.
- Reviewed evidence and downloadable bundles live in [NCCL studies](studies.md).

## Render Or Replay Reports

Use the NCCL suite renderer after collection to rebuild the report from
existing evidence. This is a replay step; it does not submit new Slurm jobs.

```bash
make render-nccl-suite NCCL_SCOPE=local CLUSTER=b200 REPORT_DATE=2026-05-16
```

For Markdown output through the render command:

```bash
scripts/operator/aicr render nccl-suite --date 2026-05-16 --cluster b200 --both --write
```

Published, curated NCCL studies and artifact bundles are linked from
[NCCL studies](studies.md).

### RDMA Group Preview

<!-- aicr-test
id: nccl-example-rdma-preview
suite: nccl
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "scope=rdma"
    - "rtxpro6000"
    - "--nodes=4"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER=rtxpro6000 PROFILE=small NODELIST=a0002,a0003,a0004,a0005 NCCL_NODES_PER_JOB=4
```

Artifacts produced after `APPLY=1`:

- RDMA suite summary.
- Node-group metadata.
- Reviewed RDMA evidence lives in [NCCL studies](studies.md).
