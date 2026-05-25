# HPL-MxP Examples

Purpose: provide a Slurm primitive workload, representative Make commands, and expected artifact classes.

## Build Your Own Slurm Workload

This example starts from the script primitive directly. Prefer
`make benchmark-hpl-mxp` or [submit-hpl-mxp.sh](../../../man/submit-hpl-mxp.md)
for routine rows so the submitter resolves the reviewed NPS4-derived placement.
If you copy the primitive, keep one `exec` line active and preserve the explicit
CPU, memory, GPU, and UCX maps. Committed copy:
[slurm-hpl-mxp.sbatch](slurm-hpl-mxp.sbatch).

```bash
#!/usr/bin/env bash
#SBATCH --job-name=aicr-hpl-mxp-primitive
#SBATCH --partition=b200-batch
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=16
#SBATCH --mem=0
#SBATCH --gres=gpu:b200:8
#SBATCH --time=00:30:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

# This primitive is a B200 smoke template. For routine rows, prefer
# make benchmark-hpl-mxp or scripts/benchmark/submit-hpl-mxp.sh so the
# submitter resolves the reviewed NPS4-derived placement.

REPO_ROOT="${AICR_BMARK_DIR:?set AICR_BMARK_DIR to your aicr-bench install root}"
cd "$REPO_ROOT"
source "${AICR_SETTINGS_FILE:-$REPO_ROOT/benchmark-settings.env}"

# Keep exactly one exec line active. Direct runner use must carry the reviewed
# NPS4-derived CPU, memory, GPU, and UCX maps explicitly.
exec ./scripts/benchmark/run-hpl-mxp.sh \
  --cluster b200 \
  --nodes 1 \
  --preset smoke \
  --matrix-size 8192 \
  --nb 1024 \
  --cpu-affinity 16-31:32-47:48-63:0-15:80-95:96-111:112-127:64-79 \
  --mem-affinity 1:2:3:0:5:6:7:4 \
  --ucx-affinity mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_6:mlx5_11
# exec ./scripts/benchmark/run-hpl-mxp.sh \
#   --cluster b200 \
#   --nodes 1 \
#   --preset weak-study \
#   --matrix-size 379904 \
#   --nb 2048 \
#   --nprow 4 \
#   --npcol 2 \
#   --scaling-study weak \
#   --cpu-affinity 16-31:32-47:48-63:0-15:80-95:96-111:112-127:64-79 \
#   --mem-affinity 1:2:3:0:5:6:7:4 \
#   --ucx-affinity mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_6:mlx5_11
```

Review the scheduler directives, then submit the customized workload. If the
template is copied outside the install tree, pass the install root explicitly:

```bash
sbatch --mem=0 --export=ALL,AICR_BMARK_DIR=/path/to/aicr-bench slurm-hpl-mxp.sbatch
```

## Slurm Sbatch Scripts

Use the module-local primitive when you want a compact starting point. The
sample NVIDIA wrapper remains available for direct container comparison.

- [slurm-hpl-mxp.sbatch](slurm-hpl-mxp.sbatch)
- [hpl-mxp-nvidia-sample-1n.sbatch](../../../slurm/benchmark/hpl-mxp-nvidia-sample-1n.sbatch)

## Using the Make Interface

### Smoke Row

<!-- aicr-test
id: hpl-mxp-example-smoke-dry-run
suite: hpl-mxp
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "HPL-MxP dry run"
    - "Preset      : smoke"
-->
```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=b0002 HPL_MXP_PRESET=smoke
```

Artifacts produced after `APPLY=1`:

- HPL-MxP command capture and GPU preflight/postflight.
- Parsed PFLOPS, residual, matrix, block, and process-grid summaries.
- Rendered reports after `make render-hpl-mxp`.

### Weak-Study Row

```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=4 NODELIST=b0002,b0006,b0007,b0008 HPL_MXP_PRESET=weak-study HPL_MXP_REPEAT_COUNT=3
```

Artifacts produced after `APPLY=1`:

- Repeated HPL-MxP raw and parsed captures.
- Standard repeat aggregation when rendered with `REPEAT_AGGREGATION=standard`.
- Published studies are linked from [HPL-MxP studies](studies.md) only after
  public results, rendered reports, artifacts, and provenance exist.

### Low-Precision Comparison Rows

```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=b0002 HPL_MXP_PRESET=weak-study HPL_MXP_SLOPPY_TYPE=FP8
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=b0002 HPL_MXP_PRESET=weak-study HPL_MXP_SLOPPY_TYPE=FP4
```

This uses the weak-study ladder controls but changes HPL-MxP sloppy type to
FP8 or B200 FP4. Use repeated samples for public precision rows and keep those
rows labeled separately from FP16 rows.

## Render Or Replay Reports

```bash
make render-hpl-mxp CLUSTER=b200 DATE=<YYYY-MM-DD> REPEAT_AGGREGATION=standard
```

This rebuilds HPL-MxP reports from existing run summaries under
`results/by-date/<date>/...`. Public HPL-MxP studies are linked from
[HPL-MxP studies](studies.md) only after reviewed evidence exists.

When a date contains earlier diagnostic rows, restrict the renderer to the
current campaign job range:

```bash
make render-hpl-mxp CLUSTER=b200 DATE=<YYYY-MM-DD> REPEAT_AGGREGATION=standard HPL_MXP_RENDER_JOB_ID_MIN=<first-job> HPL_MXP_RENDER_JOB_ID_MAX=<last-job>
```
