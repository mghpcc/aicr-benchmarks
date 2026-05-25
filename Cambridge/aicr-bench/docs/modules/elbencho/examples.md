# Elbencho Examples

Purpose: provide a Slurm primitive workload, representative Make commands, and expected artifact classes.

## Build Your Own Slurm Workload

This example starts from the script primitive directly. Keep one `exec` line
active and align the scheduler shape with the workload. Committed copy:
[slurm-elbencho.sbatch](slurm-elbencho.sbatch).

```bash
#!/usr/bin/env bash
#SBATCH --job-name=aicr-elbencho-primitive
#SBATCH --partition=<rtx-batch-or-b200-batch>
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=64
#SBATCH --mem=0
#SBATCH --exclusive
#SBATCH --time=01:00:00
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err
set -euo pipefail

REPO_ROOT="${AICR_BMARK_DIR:?set AICR_BMARK_DIR to your aicr-bench install root}"
cd "$REPO_ROOT"
source "${AICR_SETTINGS_FILE:-$REPO_ROOT/benchmark-settings.env}"

export ELBENCHO_TARGET_ROOT="${ELBENCHO_TARGET_ROOT:-/scratch/$USER/elbencho}"

# Keep exactly one exec line active. Use the committed profile templates first.
exec ./scripts/benchmark/run-elbencho.sh --cluster b200 --workload small-block --profile small --command "$(cat configs/elbencho/profiles/small/small-block.sh)"
# exec ./scripts/benchmark/run-elbencho.sh --cluster b200 --workload metadata --profile small --command "$(cat configs/elbencho/profiles/small/metadata.sh)"
```

Submit a customized workload from the install tree:

```bash
sbatch --mem=0 --export=ALL,AICR_BMARK_DIR=/path/to/aicr-bench slurm-elbencho.sbatch
```

## Using the Make Interface

Install the optional Elbencho image before running smoke or benchmark rows from
a private runtime root:

```bash
make install-elbencho
make install-elbencho APPLY=1
```

### One-Node Small-Block Sweep Point

<!-- aicr-test
id: elbencho-example-small-block-dry-run
suite: elbencho
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Elbencho submission dry run"
    - "small-block"
-->
```bash
ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho \
ELBENCHO_THREADS=64 \
ELBENCHO_IODEPTH=16 \
make benchmark-elbencho CLUSTER=b200 WORKLOAD=small-block NODES=1 NODELIST=b0002 ELBENCHO_PROFILE=small ELBENCHO_CPUS_PER_TASK=128
```

Artifacts produced after `APPLY=1`:

- Elbencho command capture and stdout/stderr.
- Parsed throughput, IOPS, and operation-rate summaries.
- Rendered reports after `scripts/report/render-elbencho-report.py --write`.

## Render Or Replay Reports

Use the renderer to rebuild Elbencho reports from existing parsed rows. This is
a replay step; it does not submit new Slurm jobs.

```bash
scripts/operator/aicr render elbencho --date 2026-05-17 --cluster b200 --both --write
```

Rendered reports are generated under `results/reports/<date>/`. Study reports
and artifact bundles are linked from [Elbencho studies](studies.md).

### One-Node Metadata Row

```bash
ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho \
ELBENCHO_THREADS=64 \
make benchmark-elbencho CLUSTER=b200 WORKLOAD=metadata NODES=1 NODELIST=b0002 ELBENCHO_PROFILE=small ELBENCHO_CPUS_PER_TASK=128 APPLY=1
```

### Peak-Cluster Row

```bash
ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho \
make benchmark-elbencho CLUSTER=b200 WORKLOAD=peak-cluster NODES=30 NODELIST=b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031 ELBENCHO_PROFILE=small ELBENCHO_CPUS_PER_TASK=128 APPLY=1
```

Artifacts produced after `APPLY=1`:

- Multi-node Elbencho service and client output.
- Parsed peak-cluster throughput and operation metrics.
- Study artifacts are linked from [Elbencho studies](studies.md).
