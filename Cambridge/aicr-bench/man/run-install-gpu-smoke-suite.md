# run-install-gpu-smoke-suite.sh

## Purpose

Validate an installed AICR-Bench tree across the GPU Topology, GDS, NCCL,
HPL-MxP, DataLoader, and DDP public surfaces with dry-run-first checks and
optional tiny Slurm smoke jobs.

Run this from an installed tree with `benchmark-settings.env` already configured.

## Usage

```text
scripts/verify/run-install-gpu-smoke-suite.sh --rtx-nodes <node[,node...]> --b200-nodes <node[,node...]> [options]
```

Default behavior runs local checks, submitter dry-runs, and explicit
`sbatch --test-only` template checks. It submits no workload jobs unless
`--apply` is provided.

## Options

- `--rtx-nodes <list>`: RTX candidate nodes. The first node is used for one-node
  smoke jobs; the first two nodes are used for RDMA when RDMA is enabled.
- `--b200-nodes <list>`: B200 candidate nodes. Same selection policy as RTX.
- `--audit-root <path>`: Evidence directory. Default:
  `/scratch/csim/validate/install-gpu-smoke-audit-<UTC>`.
- `--date <YYYY-MM-DD>`: Report date. Default: current UTC date.
- `--apply`: Submit tiny node-scoped smoke jobs after dry-runs and GPU probes pass.
- `--resume-from-audit-root <path>`: Resume an interrupted apply run from an
  existing audit root. This reuses recorded job IDs, skips local checks,
  skips dry-runs, skips explicit `sbatch --test-only`, and continues with
  apply/report phases.
- `--skip-local-checks`: Skip docs, links, help, and syntax checks.
- `--skip-dry-runs`: Skip Make/script dry-runs. This is intended for resume
  workflows after a dry-run layer already passed.
- `--skip-explicit-sbatch`: Skip explicit `sbatch --test-only` template coverage.
- `--skip-topology`: Skip GPU Topology install-smoke coverage.
- `--skip-gds`: Skip GDS install-smoke coverage.
- `--skip-nccl`: Skip NCCL local/RDMA install-smoke coverage.
- `--skip-rdma`: Skip two-node NCCL RDMA.
- `--skip-hpl-mxp`: Skip HPL-MxP install-smoke coverage.
- `--skip-dataloader`: Skip DataLoader install-smoke coverage.
- `--skip-ddp`: Skip DDP install-smoke coverage.
- `--only-elbencho`: Run only Elbencho plus required node preflight. This
  implies `--include-elbencho` and skips the other module workloads.
- `--hpl-mxp-b200-node <node>`: B200 node for HPL-MxP one-node smoke. Defaults
  to the first `--b200-nodes` entry.
- `--hpl-mxp-rtx-node <node>`: RTX node for HPL-MxP dry-run and optional apply.
  Defaults to the first `--rtx-nodes` entry.
- `--hpl-mxp-apply-rtx`: Include RTX HPL-MxP in apply mode after RTX preflight.
  B200 HPL-MxP apply is enabled by default.
- `--hpl-mxp-time <HH:MM:SS>`: HPL-MxP smoke time limit. Default: `00:10:00`.
- `--hpl-mxp-preset <name>`: HPL-MxP preset. Default: `smoke`.
- `--hpl-mxp-sloppy-type <precision>`: HPL-MxP precision. Default: `FP16`.
- `--dataloader-time <HH:MM:SS>`: DataLoader smoke time limit. Default:
  `00:10:00`.
- `--ddp-time <HH:MM:SS>`: DDP smoke time limit. Default: `00:10:00`.
- `--include-elbencho`: Include optional Elbencho runtime and tiny storage
  smoke coverage. The Elbencho image must already exist in the runtime root.
- `--elbencho-b200-node <node>`: B200 node for Elbencho smoke. Defaults to the
  first `--b200-nodes` entry.
- `--elbencho-rtx-node <node>`: RTX node for Elbencho smoke. Defaults to the
  first `--rtx-nodes` entry.
- `--elbencho-target-root <path>`: Scratch target root. Default:
  `/scratch/$USER/elbencho/install-smoke-<UTC>`.
- `--elbencho-time <HH:MM:SS>`: Elbencho smoke time limit. Default: `00:10:00`.
- `--skip-rtx`: Skip RTX coverage.
- `--skip-b200`: Skip B200 coverage.
- `--no-render`: Skip final report rendering.
- `--render-only`: Render reports from existing evidence and exit without
  repeating dry-runs or submitting jobs.
- `-h`, `--help`: Print usage.

## Apply Coverage

With `--apply`, each enabled cluster runs:

- GPU visibility probes through Slurm using explicit `--nodelist`, GPU GRES,
  and `--mem=0`
- one GPU Topology job on the first selected node
- one GDS `PROFILE=smoke` job on the first selected node
- one NCCL local `PROFILE=smoke` `allreduce` job on the first selected node
- one NCCL RDMA `PROFILE=smoke` `allreduce` job on the first two selected nodes
  unless `--skip-rdma` is set
- one B200 HPL-MxP smoke row with `HPL_MXP_MEM=0`, `FP16`,
  `HPL_MXP_AFFINITY_PROFILE=derived-nps4`, and `HPL_MXP_TEST_LOOP=1`
- optional RTX HPL-MxP smoke row when `--hpl-mxp-apply-rtx` is set
- one DataLoader `pytorch-cpu-dataloader` one-GPU smoke row on the first node
- one DDP ResNet-50 `synthetic-gpu` one-node smoke row on the first node

The command stops if a selected node does not expose 8 GPUs in the Slurm probe.
NCCL install smoke intentionally uses `NCCL_SUITE_OPS=allreduce` and one local
suite class per cluster instead of the full NCCL module smoke matrix.
HPL-MxP install smoke is a one-node functional row, not public performance
evidence; prior B200 validation completed in about one minute, with a
`00:10:00` time limit.
DataLoader install smoke uses one warmup and one measured batch to validate the
installed container, configured ImageNet path, parser, and renderer.
DDP install smoke uses `synthetic-gpu`, one warmup, and one measured iteration
to validate distributed launch and training plumbing without using ImageNet.

Elbencho install smoke is optional and disabled by default. It runs only when
`--include-elbencho` is set, uses the public `smoke` profile, one explicit
node, `--mem=0`, and a scratch target root. The Elbencho image is optional and
is not built by the default container install path; build it first with
`make install-elbencho APPLY=1` or
`make install-containers INSTALL_ELBENCHO_CONTAINER=1 APPLY=1`.
Use `--only-elbencho` for a targeted Elbencho loop after the broader GPU module
suite has already passed.

## Outputs

The audit root contains:

- `context.txt`
- `SUMMARY.md`
- `logs/`
- `dryruns/`
- `sbatch-test/`
- `preflight/`
- `reports/`

Module result artifacts remain in the installed tree under `results/`.

## Examples

Dry-run the full install-smoke surface:

```bash
scripts/verify/run-install-gpu-smoke-suite.sh \
  --rtx-nodes a0002,a0003 \
  --b200-nodes b0001,b0002
```

Submit tiny smoke jobs:

```bash
scripts/verify/run-install-gpu-smoke-suite.sh \
  --rtx-nodes a0002,a0003 \
  --b200-nodes b0001,b0002 \
  --apply
```

Resume an interrupted applied run:

```bash
scripts/verify/run-install-gpu-smoke-suite.sh \
  --rtx-nodes a0002,a0003 \
  --b200-nodes b0001,b0002 \
  --resume-from-audit-root /scratch/csim/validate/install-gpu-smoke-audit-YYYYMMDD-HHMMSS
```

For long applied runs, launch from AICR HPC inside `tmux` or with `nohup` so an
SSH disconnect does not stop the operator process.
