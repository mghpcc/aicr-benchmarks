# Install-Tree GPU Smoke Suite

Purpose: validate that an installed AICR-Bench tree can run the GPU Topology,
GDS, NCCL, HPL-MxP, DataLoader, and DDP public surfaces with tiny Slurm
workloads.

Run this from an installed tree, not from a development checkout, after
`benchmark-settings.env` has been configured for the runtime assets to test.
The suite is dry-run first. It only submits jobs when `--apply` or `APPLY=1`
is provided.

For upstream install validation, first clone into a fresh scratch checkout and
install into a separate scratch prefix:

```bash
stamp=$(date -u +%Y%m%d-%H%M%S)
clone_root=/scratch/csim/validate/aicr-benchmarks-install-smoke-${stamp}
install_prefix=/scratch/csim/validate/aicr-install-smoke-${stamp}
runtime_root=/scratch/csim/validate/aicr-runtime-install-smoke-${stamp}

git clone git@github.com:mghpcc/aicr-benchmarks.git "${clone_root}"
cd "${clone_root}/Cambridge/aicr-bench"
cp benchmark-settings.env.example benchmark-settings.env
```

Configure the scratch checkout's `benchmark-settings.env` to use private
runtime assets for the run:

```bash
AICR_RUNTIME_ROOT="${runtime_root}"
AICR_APPTAINER_IMAGE_DIR="${runtime_root}/apptainer/images"
AICR_UV_ROOT="${runtime_root}/uv"
AICR_UV_ENVS_DIR="${runtime_root}/uv-envs"
AICR_UV_ENV_PREFIX="${runtime_root}/uv-envs/aicr-bench"
```

Then install and run the smoke suite from the installed tree:

```bash
./install.sh --prefix="${install_prefix}"
cd "${install_prefix}/aicr-bench"
```

## Scope

The suite checks:

- shell syntax for GPU Topology, GDS, NCCL, HPL-MxP, DataLoader, DDP, render
  commands, and Slurm templates
- public documentation links and module doctests
- public `--help` surfaces
- Make dry-runs for GPU Topology, GDS smoke, NCCL local smoke, NCCL RDMA smoke,
  HPL-MxP smoke, DataLoader smoke, and DDP smoke
- matching script submitter dry-runs
- explicit `sbatch --test-only` coverage for Slurm templates
- optional Slurm GPU visibility probes on selected nodes
- optional tiny apply jobs and report rendering

It is intended as an install validation smoke suite, not a benchmark campaign.
Use `system-verify` for campaign-day repeated sampling.

## Manual Driver

Choose explicit idle nodes first. Provide two nodes per cluster when RDMA should
be tested.

```bash
cd /scratch/csim/validate/aicr-install-smoke-YYYYMMDD-HHMM/aicr-bench
cp benchmark-settings.env.example benchmark-settings.env  # only if not already configured

bash scripts/verify/run-install-gpu-smoke-suite.sh \
  --rtx-nodes a0002,a0003 \
  --b200-nodes b0001,b0002
```

That command runs local-safe checks, Slurm dry-runs, and `sbatch --test-only`
template checks. It writes evidence under:

```text
/scratch/csim/validate/install-gpu-smoke-audit-<UTC>/
```

To submit smoke jobs after the dry-run layer passes:

```bash
bash scripts/verify/run-install-gpu-smoke-suite.sh \
  --rtx-nodes a0002,a0003 \
  --b200-nodes b0001,b0002 \
  --audit-root /scratch/csim/validate/install-gpu-smoke-audit-$(date -u +%Y%m%d-%H%M%S) \
  --apply
```

The apply path runs, per enabled cluster:

- one GPU Topology job on the first node
- one GDS `PROFILE=smoke` job on the first node
- one NCCL local `PROFILE=smoke` `allreduce` job on the first node
- one NCCL RDMA `PROFILE=smoke` `allreduce` two-node job when at least two nodes are given
- one B200 HPL-MxP smoke row on the first B200 node
- optional RTX HPL-MxP smoke row when `--hpl-mxp-apply-rtx` is set
- one DataLoader `pytorch-cpu-dataloader` one-GPU smoke row per cluster
- one DDP ResNet-50 `synthetic-gpu` one-node smoke row per cluster

The NCCL install-smoke path intentionally narrows the module smoke matrix.
It uses one local suite class per cluster, `rtx_8rank_1g` or `b200_8rank_1g`,
and `NCCL_SUITE_OPS=allreduce`. The full NCCL module smoke remains available
through `make verify-nccl-suite PROFILE=smoke`.

The HPL-MxP install-smoke path uses the public `smoke` preset, `FP16`,
`HPL_MXP_AFFINITY_PROFILE=derived-nps4`, `HPL_MXP_MEM=0`, and
`HPL_MXP_TEST_LOOP=1`. Prior B200 validation completed in about one minute;
the driver allows `00:10:00`. RTX HPL-MxP apply is opt-in because non-topology
RTX GPU work is gated on visible GPU count and explicit operator intent.

The DataLoader install-smoke path uses one GPU, `pytorch-cpu-dataloader`, and
one warmup plus one measured batch. It validates the installed PyTorch
container, configured ImageNet root, submitter, parser, and renderer; it is not
performance evidence.

The DDP install-smoke path uses one full node, `torchrun`, `synthetic-gpu`, and
one warmup plus one measured iteration. It validates distributed launch and
training plumbing without depending on the shared ImageNet path.

Elbencho install-smoke coverage is optional and disabled by default because the
Elbencho container is not part of the default runtime image set and the smoke
row writes a scratch storage target. Enable it only after building or pulling
the optional image into the runtime root under test:

```bash
make install-elbencho APPLY=1
```

or, for the Slurm container install workflow:

```bash
make install-containers INSTALL_ELBENCHO_CONTAINER=1 APPLY=1
```

When enabled, Elbencho install smoke uses the public `smoke` profile, one
explicit node per enabled cluster, `--mem=0`, and a scratch target root under
`/scratch/$USER/elbencho/install-smoke-<UTC>` unless overridden.

Before apply jobs, the driver submits short `nvidia-smi -L` probe jobs with
explicit `--nodelist`, cluster GPU GRES, and `--mem=0`. The run stops if a
selected node does not expose 8 GPUs.

## Make Interface

The Make target wraps the same driver:

```bash
make install-gpu-smoke-suite \
  INSTALL_SMOKE_RTX_NODES=a0002,a0003 \
  INSTALL_SMOKE_B200_NODES=b0001,b0002
```

Submit smoke jobs by adding `APPLY=1`:

```bash
make install-gpu-smoke-suite \
  INSTALL_SMOKE_RTX_NODES=a0002,a0003 \
  INSTALL_SMOKE_B200_NODES=b0001,b0002 \
  APPLY=1
```

Opt into optional Elbencho dry-runs and tiny smoke jobs after the Elbencho image
exists:

```bash
make install-gpu-smoke-suite \
  INSTALL_SMOKE_RTX_NODES=a0002,a0003 \
  INSTALL_SMOKE_B200_NODES=b0001,b0002 \
  INSTALL_SMOKE_INCLUDE_ELBENCHO=1
```

Useful switches:

- `INSTALL_SMOKE_AUDIT_ROOT=<path>` fixes the evidence directory.
- `INSTALL_SMOKE_SKIP_RDMA=1` skips two-node NCCL RDMA.
- `INSTALL_SMOKE_SKIP_HPL_MXP=1` skips HPL-MxP install-smoke coverage.
- `INSTALL_SMOKE_SKIP_DATALOADER=1` skips DataLoader install-smoke coverage.
- `INSTALL_SMOKE_SKIP_DDP=1` skips DDP install-smoke coverage.
- `INSTALL_SMOKE_HPL_MXP_B200_NODE=<node>` overrides the B200 HPL-MxP node.
- `INSTALL_SMOKE_HPL_MXP_RTX_NODE=<node>` overrides the RTX HPL-MxP node.
- `INSTALL_SMOKE_HPL_MXP_APPLY_RTX=1` enables RTX HPL-MxP apply after preflight.
- `INSTALL_SMOKE_HPL_MXP_TIME=00:10:00` sets the HPL-MxP time limit.
- `INSTALL_SMOKE_DATALOADER_TIME=00:10:00` sets the DataLoader time limit.
- `INSTALL_SMOKE_DDP_TIME=00:10:00` sets the DDP time limit.
- `INSTALL_SMOKE_INCLUDE_ELBENCHO=1` enables optional Elbencho coverage.
- `INSTALL_SMOKE_ELBENCHO_B200_NODE=<node>` overrides the B200 Elbencho node.
- `INSTALL_SMOKE_ELBENCHO_RTX_NODE=<node>` overrides the RTX Elbencho node.
- `INSTALL_SMOKE_ELBENCHO_TARGET_ROOT=<path>` sets the scratch target root.
- `INSTALL_SMOKE_ELBENCHO_TIME=00:10:00` sets the Elbencho time limit.
- `INSTALL_SMOKE_SKIP_RTX=1` or `INSTALL_SMOKE_SKIP_B200=1` narrows cluster coverage.
- `INSTALL_SMOKE_SKIP_LOCAL_CHECKS=1` skips docs/help/syntax checks.
- `INSTALL_SMOKE_SKIP_EXPLICIT_SBATCH=1` skips `sbatch --test-only`.
- `INSTALL_SMOKE_NO_RENDER=1` skips final report rendering.
- `INSTALL_SMOKE_RENDER_ONLY=1` renders reports from existing evidence without
  repeating dry-runs or submitting jobs.

## Evidence

Each run writes:

- `context.txt`: installed tree, runtime settings, node selections, mode, and date
- `logs/`: local checks and apply command output
- `dryruns/`: Make and script dry-run command output
- `sbatch-test/`: explicit Slurm template parser checks
- `preflight/`: selected node `scontrol`, GPU probe jobs, `sacct`, and `nvidia-smi -L`
- `reports/`: render command output
- `SUMMARY.md`: compact evidence map

Generated results remain under the installed tree `results/` and the audit root.
Do not commit generated runtime assets, Slurm logs, or result trees.

## Stop Rules

Stop new submissions if any selected node drains, goes down, loses GPUs, reports
NVML/device-handle errors, hits Slurm OOM, or shows severe NCCL/fabric symptoms.
Capture `sinfo`, `squeue`, `sacct`, `scontrol show node`, and affected logs before
choosing replacement nodes.
