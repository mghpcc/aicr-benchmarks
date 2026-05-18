# GPU Topology Test Plan

Purpose: define executable coverage and HPC replay expectations for the GPU Topology module.

GPU Topology is a readiness and provenance module. Its tests prove that the
documented command surfaces are usable and that AICR HPC can collect and render
topology evidence. It is not a performance study tool.

## Current Coverage

- Documentation links and man-page links are checked by `make docs-link-check`.
- Local documentation replay checks the public help surfaces for the allocation-side runner and fleet runner.
- Slurm collection and dashboard re-render are AICR HPC replay steps because they require Slurm, compute-node hardware, and generated `results/` manifests.
- The standalone study page is checked as documentation; it does not link out to the Cambridge verification campaign as its source of truth.

## Replay Entry Points

Plan GPU Topology documentation tests:

```bash
make docs-test-plan-gpu-topology
```

Run local-safe GPU Topology documentation tests:

```bash
make docs-test-gpu-topology
```

Run the same scan through the generic interface:

```bash
make docs-test DOCS=docs/modules/gpu-topology DOCS_TEST_SUITE=gpu-topology
```

On AICR HPC, applied documentation checks must be explicit and node-scoped:

```bash
DOCS_APPLY=1 NODELIST=<node> make docs-test-gpu-topology
```

## Command Coverage

| Source | Command | Replay level | Acceptance |
| --- | --- | --- | --- |
| `scripts.md` | `scripts/verify/run-gpu-topology.sh --help` | Local doctest | Exits zero and prints usage plus environment controls. |
| `scripts.md` | `scripts/verify/run-gpu-topology-fleet.sh --help` | Local doctest | Exits zero and prints cluster/apply options. |
| `man/run-gpu-topology.md` | `scripts/verify/run-gpu-topology.sh [--help]` | Local doctest through `scripts.md` | Man-page usage matches script help and documents environment-based cluster selection. |
| `man/run-gpu-topology.md` | `scripts/verify/run-gpu-topology.sh` | AICR HPC allocation replay | Runs inside a Slurm allocation and writes raw plus parsed node evidence. |
| `man/run-gpu-topology-fleet.md` | `scripts/verify/run-gpu-topology-fleet.sh --cluster b200` | AICR HPC dry-run replay | Discovers candidate B200 nodes and prints `sbatch` commands without submitting jobs. |
| `man/run-gpu-topology-fleet.md` | `scripts/verify/run-gpu-topology-fleet.sh --cluster rtxpro6000 --nodes <node> --apply` | AICR HPC apply replay | Submits a node-scoped RTX topology job only after intentional apply mode. |
| `examples.md` | Slurm wrapper template | Manual/HPC review | One active `exec` line, scheduler resources match a one-node topology collection. |
| `examples.md` | `make verify-topology CLUSTER=b200` | AICR HPC dry-run replay | Discovers candidate nodes and prints `sbatch` commands without submitting jobs. |
| `examples.md` | `make verify-topology CLUSTER={{cluster}} NODELIST={{node}} APPLY=1` | AICR HPC apply doctest | Submits one topology job only after intentional apply mode and explicit node selection. |
| `examples.md` | `scripts/operator/aicr render gpu-topology --date <YYYY-MM-DD> --cluster b200 --both` | AICR HPC dashboard replay | Reads the applied-run manifest tree and emits ASCII plus Markdown dashboard output. |
| `make.md` | `make verify-topology CLUSTER=<b200\|rtxpro6000>` | AICR HPC dry-run replay | Prints the fleet collection plan for the selected cluster. |
| `make.md` | `make system-verify CLUSTER=<b200\|rtxpro6000> PROFILE=small APPLY=1` | AICR HPC apply replay | Includes topology collection in the combined verification flow. |

## Local Replay

Local replay is intentionally narrow:

```bash
make docs-test-plan-gpu-topology
make docs-test-gpu-topology
```

These checks should pass on a workstation without Slurm, GPUs, or the public
evidence manifest tree.

## AICR HPC Replay

Dry-run replay:

```bash
make verify-topology CLUSTER=b200
make verify-topology CLUSTER=rtxpro6000
```

One-node apply replay:

```bash
make verify-topology CLUSTER=b200 NODELIST=<node> APPLY=1
```

Dashboard replay after applied collection:

```bash
scripts/operator/aicr render gpu-topology --date <YYYY-MM-DD> --cluster b200 --both
scripts/operator/aicr render gpu-topology --date <YYYY-MM-DD> --cluster rtxpro6000 --both
```

## Known Gaps

- The fleet dry-run command uses Slurm node discovery, so it is not a default
  laptop test.
- Applied topology collection intentionally remains HPC-only.
- Dashboard re-render is HPC replay because the renderer needs generated
  `results/reports/<date>/gpu-topology/` manifests from applied runs.
- No committed fixture currently exercises GPU topology dashboard rendering
  without generated result manifests.
