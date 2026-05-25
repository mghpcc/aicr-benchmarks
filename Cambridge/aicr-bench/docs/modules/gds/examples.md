# GDS Examples

Purpose: provide a Slurm primitive workload, compact Make examples, and expected artifact classes.

## Build Your Own Slurm Workload

This example starts from the script primitive directly. Keep one `exec` line active and comment out the others while customizing. Committed copy: [slurm-gds.sbatch](slurm-gds.sbatch).

```bash
#!/usr/bin/env bash
#SBATCH --job-name=aicr-gds-primitive
#SBATCH --partition=<rtx-batch-or-b200-batch>
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=0
#SBATCH --gres=<gpu-type-and-count>
#SBATCH --time=00:15:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

# Replace the partition and GRES placeholders before submitting.
# AICR HPC scheduler examples:
#   RTX:  #SBATCH --partition=rtx-batch and #SBATCH --gres=gpu:rtxpro6000:8
#   B200: #SBATCH --partition=b200-batch and #SBATCH --gres=gpu:b200:8

# Keep #SBATCH --mem=0 or --mem=0 on the sbatch command line so the job
# inherits the full per-node memory; GDS validation is sensitive to Slurm's
# default per-job memory cap.

REPO_ROOT="${AICR_BMARK_DIR:?set AICR_BMARK_DIR to your aicr-bench install root}"
cd "$REPO_ROOT"
source "${AICR_SETTINGS_FILE:-$REPO_ROOT/benchmark-settings.env}"
# Optional when GPU auto-detection is not enough:
# export AICR_CLUSTER_NAME=rtxpro6000
# export AICR_CLUSTER_NAME=b200

# Keep exactly one exec line active. Align #SBATCH nodes, tasks, and GPUs with it.
exec ./scripts/verify/run-gds.sh --profile small
# exec ./scripts/verify/run-gds.sh --profile medium
# exec ./scripts/verify/run-gds.sh --profile large
# exec ./scripts/verify/run-gds.sh --custom-gdsio-args "-x 0 -I 0 -d 0 -w 1 -m 0 -s 1G -i 1M"
```

Replace the scheduler placeholders, then submit the customized workload. If the template was copied outside the install tree, pass the install root explicitly:

```bash
sbatch --mem=0 --export=ALL,AICR_BMARK_DIR=/path/to/aicr-bench slurm-gds.sbatch
```

## Slurm Sbatch Scripts

Use the module-local primitive when you want a compact starting point. Use the
cluster-specific templates when you want the repo's cluster defaults already
spelled out.

- [slurm-gds.sbatch](slurm-gds.sbatch)
- [b200-gds-1n-8g.sbatch](../../../slurm/verify/b200-gds-1n-8g.sbatch)
- [rtxpro6000-gds-1n-8g.sbatch](../../../slurm/verify/rtxpro6000-gds-1n-8g.sbatch)

## Using the Make Interface

### One Node Applied Example

<!-- aicr-test
id: gds-example-one-node-command
suite: gds
kind: slurm-apply
safety: one-node
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Submitted"
-->
```bash
make verify-gds CLUSTER={{cluster}} PROFILE=smoke NODELIST={{node}} APPLY=1
```

Artifacts produced:

- GDS phase output and parsed status.
- GDS dashboard report.
- Reviewed evidence and downloadable bundles live in [GDS studies](studies.md).

## Render Or Replay Reports

Use the render command to rebuild GDS dashboards from existing verification
evidence. This report replay does not submit new Slurm jobs.

```bash
scripts/operator/aicr render gds --date 2026-05-16 --cluster b200 --both
```

For a terminal-only view through the Make interface:

```bash
make render-gds-ascii CLUSTER=b200 REPORT_DATE=2026-05-16
```

Published, curated GDS studies and artifact bundles are linked from
[GDS studies](studies.md).

### Custom Dry Run

<!-- aicr-test
id: gds-example-custom-dry-run
suite: gds
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "GDS profile"
-->
```bash
make verify-gds CLUSTER=b200 PROFILE=custom NODELIST=b0001 AICR_GDS_CUSTOM_GDSIO_ARGS="-x 0 -I 0 -d 0 -w 1 -m 0 -s 1G -i 1M"
```

Artifacts produced after `APPLY=1`:

- One custom `gdsio` phase.
- Parsed status and notes.
- Reviewed custom examples live in [GDS studies](studies.md).
