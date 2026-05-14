# GDS Examples

Purpose: provide a Slurm primitive workload, compact Make examples, and expected artifact classes.

## Build Your Own Slurm Workload

This example starts from the script primitive directly. Keep one `exec` line active and comment out the others while customizing. Committed copy: [slurm-gds.sbatch](slurm-gds.sbatch).

```bash
#!/usr/bin/env bash
#SBATCH --job-name=aicr-gds-primitive
#SBATCH --partition=<GPU1-or-GPU2>
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --gres=<gpu-type-and-count>
#SBATCH --time=00:15:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

# Replace the partition and GRES placeholders before submitting.
# AICR HPC scheduler examples:
#   RTX:  #SBATCH --partition=GPU1 and #SBATCH --gres=gpu:rtxpro6000:8
#   B200: #SBATCH --partition=GPU2 and #SBATCH --gres=gpu:b200:8

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
sbatch --export=ALL,AICR_BMARK_DIR=/path/to/aicr-bench slurm-gds.sbatch
```

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
make verify-gds CLUSTER={{cluster}} PROFILE=small NODELIST={{node}} APPLY=1
```

Artifacts produced:

- GDS phase output and parsed status.
- GDS dashboard report.
- Reviewed evidence and downloadable bundles live in [GDS studies](studies.md).

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
