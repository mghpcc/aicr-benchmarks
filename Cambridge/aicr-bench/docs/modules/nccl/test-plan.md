# NCCL Test Plan

Purpose: define replayable checks for the NCCL module and separate short
documentation tests from longer AICR HPC validation.

NCCL has local, RDMA, and scale scopes; B200 and RTX suite classes; submitter
grouping; repeat aggregation; Slurm templates; parser output; renderer output;
and long campaign ladders. Default documentation tests prove the public command
surfaces and dry-run plans without launching jobs. Applied Slurm tests are
explicit, smoke-sized, and node-scoped.

## Current Coverage

- `make docs-link-check` checks public documentation, man-page inventory,
  script links, fixture hygiene, and node-name examples.
- `make docs-test-plan-nccl` lists the selected NCCL `aicr-test` blocks without
  running them.
- `make docs-test-nccl` runs local help and dry-run examples only.
- `DOCS_APPLY=1 NODELIST=<node> make docs-test-nccl` enables one-node local
  NCCL apply tests.
- `DOCS_APPLY=1 NODELIST=<node1>,<node2> make docs-test-nccl` enables the
  two-node RDMA and tiny scale NCCL apply tests.

## Command Coverage

| Source | Command | Replay level | Acceptance |
| --- | --- | --- | --- |
| `scripts.md` | [run-nccl-suite.sh](../../../man/run-nccl-suite.md) `--help` | Local doctest | Help exposes `--scope` and `--nodes-per-job`. |
| `scripts.md` | [submit-nccl-suite.sh](../../../man/submit-nccl-suite.md) `--help` | Local doctest | Help exposes `--scope`, `--scales`, and grouping controls. |
| `scripts.md` | [render-nccl-suite-report.py](../../../man/render-nccl-suite-report.md) `--help` | Local doctest | Help exposes `--scope` and `--cluster`. |
| `make.md` | `make verify-nccl-suite NCCL_SCOPE=local ...` | Local dry-run doctest | Prints dry-run mode and `scope=local` with explicit `NODELIST`. |
| `make.md` | `NCCL_SUITE_CLASS=<class>` | Local dry-run doctest | Accepts documented B200 and RTX local class names. |
| `make.md` | `make verify-nccl-suite NCCL_SCOPE=rdma ...` | Local dry-run doctest | Prints `nodes_per_job=2` and rank-per-GPU Slurm shape. |
| `make.md` | `CLUSTER=rtxpro6000 NCCL_SCOPE=rdma ...` | Local dry-run doctest | Uses the RTX suite RDMA template and supports two-node groups. |
| `make.md` | `make verify-nccl-suite NCCL_SCOPE=scale ...` | Local dry-run doctest | Prints `scales=1 2` and `--nodes=2`. |
| `make.md` | `CLUSTER=rtxpro6000 NCCL_SCOPE=scale ...` | Local dry-run doctest | Prints RTX scale ladder shape for `1,2`. |
| `make.md` | May 16 B200 scale shape | Local dry-run doctest | Prints repeat 5, Olympic aggregation, B200 `1,2,4,8,16`, 8 ranks/node, and 16 CPUs/rank. |
| `make.md` | `make verify-nccl-suite NCCL_SCOPE=local ... APPLY=1` | AICR HPC apply doctest | One-node smoke job submits only with `DOCS_APPLY=1` and explicit node. |
| `make.md` | `make verify-nccl-suite NCCL_SCOPE=rdma ... APPLY=1` | AICR HPC apply doctest | Two-node smoke job submits only with `DOCS_APPLY=1` and two explicit nodes. |
| `make.md` | `make verify-nccl-suite NCCL_SCOPE=scale ... APPLY=1` | AICR HPC apply doctest | Tiny `NCCL_SCALES=1,2` smoke replay submits only with two explicit nodes. |
| `make.md` | `make render-nccl-suite ... DATE=<YYYY-MM-DD>` | AICR HPC render replay | Reads generated summaries and the shared `results/reports/<date>/nccl-suite/<manifest>.json` submitter manifest tree. |
| `test-plan.md` | `bash scripts/report/check-artifact-policy.sh` | Local replay | Keeps generated raw result trees out of Git. |
| `test-plan.md` | `bash -n` on NCCL scripts | Local replay | Runner and submitter remain shell-parseable. |

## Local Replay

Run from the installed `aicr-bench` root:

```bash
make docs-link-check
make docs-test-plan-nccl
make docs-test-nccl
bash scripts/report/check-artifact-policy.sh
bash -n scripts/verify/run-nccl-suite.sh scripts/verify/submit-nccl-suite.sh
git diff --check
```

The default docs run should remain short. It may run help commands and dry-runs,
but it should not submit Slurm jobs or render dashboards that require restored
runtime result trees.

## AICR HPC Smoke Replay

Run after syncing or freshly cloning the repo on AICR HPC and creating
`benchmark-settings.env` from the example file.

B200 smoke:

```bash
DOCS_APPLY=1 CLUSTER=b200 NODELIST=<b-node-1>,<b-node-2> make docs-test-nccl
make render-nccl-suite NCCL_SCOPE=local CLUSTER=b200 DATE=<YYYY-MM-DD>
make render-nccl-suite NCCL_SCOPE=rdma CLUSTER=b200 NCCL_NODES_PER_JOB=2 DATE=<YYYY-MM-DD>
make render-nccl-suite NCCL_SCOPE=scale CLUSTER=b200 DATE=<YYYY-MM-DD>
```

RTX smoke:

```bash
DOCS_APPLY=1 CLUSTER=rtxpro6000 NODELIST=<a-node-1>,<a-node-2> make docs-test-nccl
make render-nccl-suite NCCL_SCOPE=local CLUSTER=rtxpro6000 DATE=<YYYY-MM-DD>
make render-nccl-suite NCCL_SCOPE=rdma CLUSTER=rtxpro6000 NCCL_NODES_PER_JOB=2 DATE=<YYYY-MM-DD>
make render-nccl-suite NCCL_SCOPE=scale CLUSTER=rtxpro6000 DATE=<YYYY-MM-DD>
```

Acceptance criteria:

- Slurm jobs complete with `COMPLETED 0:0`.
- Each parsed `status.json` is `passed`.
- Runner command captures show `--ntasks-per-node=8` for rank-per-GPU jobs.
- Local scope has `NCCL_IB_DISABLE=1`; RDMA and scale scopes use IB unless an
  explicit diagnostic override is set.
- Render replay succeeds for the generated date.

## Render Replay

The renderer has a local `--help` doctest. Full render replay remains an AICR
HPC validation step because it needs completed NCCL result trees or restored
reviewed evidence.

Submitter manifests live under `results/reports/<date>/nccl-suite/`; rendered
Markdown outputs are scope-specific files under `results/reports/<date>/`.

```bash
make render-nccl-suite NCCL_SCOPE=local CLUSTER=b200 DATE=<YYYY-MM-DD>
make render-nccl-suite NCCL_SCOPE=rdma CLUSTER=b200 NCCL_NODES_PER_JOB=2 DATE=<YYYY-MM-DD>
make render-nccl-suite NCCL_SCOPE=scale CLUSTER=b200 DATE=<YYYY-MM-DD>
```

Repeat for `CLUSTER=rtxpro6000` when RTX data exists for that scope.

## Campaign Replay

Full campaign replay is manual because it can run for hours.

May 16 verification shape:

```bash
make verify-nccl-suite NCCL_SCOPE=scale CLUSTER=b200 PROFILE=small NODELIST=<b-node-list> NCCL_SCALES=1,2,4,8,16 REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic APPLY=1
make verify-nccl-suite NCCL_SCOPE=scale CLUSTER=rtxpro6000 PROFILE=small NODELIST=<a-node-list> NCCL_SCALES=1,2,4 REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic APPLY=1
```

The campaign shape is rank-per-GPU: eight MPI ranks per node, one GPU per rank,
and 16 CPU cores per rank.

## Known Gaps

- Default docs tests do not submit Slurm jobs.
- Full render replay is intentionally not part of default docs tests because it
  depends on runtime result trees.
- Full RDMA and scale ladders remain manual AICR HPC campaign workflows.
- Committed render fixtures are deferred to a cross-module fixture effort.
