# Elbencho Test Plan

Purpose: define executable coverage and replay expectations for the Elbencho
module.

Elbencho has a dry-run-first Slurm submitter, an allocation-side runner,
profile templates, setup-gate runtime smoke, and a report renderer.
Default documentation tests prove help and dry-run surfaces without launching
Slurm jobs, writing storage rows, or requiring generated result trees.

## Coverage

- Documentation link and man-page coverage is checked by `make docs-link-check`.
- `make docs-test-plan-elbencho` lists selected Elbencho `aicr-test` blocks
  without running them.
- `make docs-test-elbencho` runs local help and dry-run examples plus the
  renderer fixture test.
- Command examples with `aicr-test` metadata cover submitter help and dry-run
  storage workload planning.
- `scripts/verify/smoke-test-elbencho.sh` checks the optional Elbencho runtime
  image for CUDA and cufile/GDS feature signals during setup-gate smoke.
- The renderer fixture covers small-block, metadata, and 30-node peak-cluster
  summary rows.

## Command Coverage

| Source | Command | Replay level | Acceptance |
| --- | --- | --- | --- |
| `scripts.md` | [submit-elbencho.sh](../../../man/submit-elbencho.md) `--help` | Local doctest | Help exposes workloads, profiles, repeats, memory, node selection, and dry-run/apply controls. |
| `scripts.md` | [run-elbencho.sh](../../../man/run-elbencho.md) `--help` | Local replay | Help exposes cluster, workload, profile, and command-template controls. |
| `make.md` | `make benchmark-elbencho ... WORKLOAD=small-block` | Local dry-run doctest | Prints resolved workload, explicit node list, `--mem=0`, and `sbatch` command. |
| `examples.md` | one-node small-block dry-run | Local dry-run doctest | Prints the same dry-run contract from the examples page. |
| `scripts.md` | [install-elbencho-runtime.sh](../../../man/install-elbencho-runtime.md) `--help` | Local replay | Help documents the optional container runtime install path. |
| `scripts.md` | [render-elbencho-report.py](../../../man/render-elbencho-report.md) `--help` | Local replay | Help exposes date, cluster, results root, format, and write controls. |
| `test-plan.md` | renderer fixture test | Local replay | Renders small-block, metadata, and 30-node peak-cluster rows without generated result trees. |
| `make.md` | `make benchmark-elbencho ... APPLY=1` | AICR HPC apply replay | Submits a one-node smoke or small row on an explicit node and writes raw/parsed artifacts. |
| `studies.md` | study requirements | Manual review | Keeps study claims tied to completed rows, artifact bundles, provenance, and the 31-node partial caveat. |

## Local Replay

Run from the installed `aicr-bench` root:

```bash
make docs-link-check
make docs-test-plan-elbencho
make docs-test-elbencho
bash -n scripts/benchmark/install-elbencho-runtime.sh scripts/benchmark/run-elbencho.sh scripts/benchmark/submit-elbencho.sh scripts/verify/smoke-test-elbencho.sh
scripts/lib/run-repo-python.sh -m py_compile scripts/report/render-elbencho-report.py
scripts/lib/run-repo-python.sh tests/scripts/check-elbencho-report-shape-fixture.py
git diff --check
```

The default docs run should remain short. It may run help, dry-run commands,
and synthetic renderer fixtures. It must not submit Slurm jobs, require GPUs,
require the Elbencho image, or require generated Elbencho result trees.

## Optional Install-Smoke Replay

The install GPU smoke suite does not include Elbencho by default because the
Elbencho image is optional and the workload writes storage targets. Enable it
only after building or pulling the optional image into the runtime root under
test.

```bash
make install-elbencho APPLY=1
make install-gpu-smoke-suite \
  INSTALL_SMOKE_RTX_NODES=<rtx-node-1>,<rtx-node-2> \
  INSTALL_SMOKE_B200_NODES=<b-node-1>,<b-node-2> \
  INSTALL_SMOKE_INCLUDE_ELBENCHO=1
```

Apply mode must stay tiny, explicit-node, and scratch-scoped:

```bash
make install-gpu-smoke-suite \
  INSTALL_SMOKE_RTX_NODES=<rtx-node-1>,<rtx-node-2> \
  INSTALL_SMOKE_B200_NODES=<b-node-1>,<b-node-2> \
  INSTALL_SMOKE_INCLUDE_ELBENCHO=1 \
  INSTALL_SMOKE_ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho/install-smoke-<run-id> \
  APPLY=1
```

Acceptance criteria:

- Dry-run logs show Elbencho submitter commands only when
  `INSTALL_SMOKE_INCLUDE_ELBENCHO=1` is set.
- Applied Elbencho jobs use `PROFILE=smoke`, one explicit node, `--mem=0`, and
  the configured scratch target root.
- Slurm jobs complete with `COMPLETED 0:0`.
- Each parsed `status.json` is `passed`.
- Render replay succeeds for the generated date.

## AICR HPC Benchmark Replay

Run after syncing or freshly cloning the repo on AICR HPC and creating
`benchmark-settings.env` from the example file.

```bash
ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho \
make benchmark-elbencho CLUSTER=b200 WORKLOAD=small-block NODES=1 NODELIST=<b-node> ELBENCHO_PROFILE=smoke

ELBENCHO_TARGET_ROOT=/scratch/$USER/elbencho \
make benchmark-elbencho CLUSTER=b200 WORKLOAD=small-block NODES=1 NODELIST=<b-node> ELBENCHO_PROFILE=smoke APPLY=1
```

Acceptance criteria:

- Dry-run precedes apply.
- Applied commands use explicit `NODELIST` and `--mem=0`.
- B200 apply is intentionally gated with `AICR_ELBENCHO_B200_APPLY_ALLOW=1`.
- Raw command, stdout, stderr, text summary, parsed summary, parsed status,
  Slurm logs, and index records exist for each row.
- Render replay succeeds for the generated date.

## Known Gaps

- Full Elbencho replay is HPC-only because it requires the optional runtime
  image, scratch target, Slurm allocation, and storage policy approval.
- The peak-cluster study row remains a 30-node partial row until a future
  31-node row can be collected with `b0001`.
- Metadata rows without a cache-drop helper remain non-cache-neutral.
