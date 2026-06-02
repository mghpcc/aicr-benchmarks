# Module Conventions

Purpose: document shared naming, workflow, and artifact conventions for public AICR-Bench modules.

AICR-Bench has two public layers:

- Scripts are workflow primitives for users building their own Slurm workflows, studies, reports, or automation.
- Make is the curated campaign driver that composes those primitives into repeatable runs, dashboards, and repo-standard artifact layouts.

## Module Shape

Each public module directory provides:

- `README.md`: module landing page.
- `scripts.md`: primitive script interface.
- `make.md`: curated Make interface.
- `examples.md`: Slurm primitive example, representative Make commands, and produced artifact lists.
- `studies.md`: recommended studies, collection roadmaps, or curated reports.
- `test-plan.md`: executable coverage, HPC replay steps, known gaps, and acceptance criteria for documented commands.

Module index pages group modules by role:

- Profiling and readiness modules document system state, readiness, or
  infrastructure behavior. Current examples are GPU Topology, GDS, and NCCL.
- Benchmarking modules document user-facing benchmark workloads and result
  campaigns. Current examples are Elbencho, DataLoader, DDP, and HPL-MxP.

The role affects study language. A readiness module can have a `studies.md`
page, but it should say when the module is not a performance study tool and
should keep example studies self-contained inside `docs/modules/<module>/`.

## Page Contracts

Use the same headings and intent across modules:

- `README.md`: purpose, page map, when to use the module, and primary entry
  points.
- `scripts.md`: public primitive scripts, command roles, safe examples, and a
  final artifact section.
- `make.md`: curated Make targets, common variables, dry-run and apply shape,
  and a final artifact section.
- `examples.md`: Slurm primitive templates, representative Make examples, and
  artifact classes.
- `studies.md`: recommended studies, campaign replay notes, or a clear statement
  that study use is limited.
- `test-plan.md`: current coverage, replay entry points, command coverage table,
  local replay, AICR HPC replay, render replay when relevant, campaign replay
  when relevant, and known gaps.

Do not use visible prose to promise a command, Make target, script, Slurm
template, man page, or report path unless the referenced surface exists or the
page explicitly marks it as planned.

## Test Plan Replay Levels

Use one `Replay level` column in module test-plan command coverage tables.
Use these labels consistently:

- `Local doctest`: runs in the default `make docs-test-*` target without Slurm,
  GPUs, or generated result trees.
- `Local dry-run doctest`: runs in the default docs test and exercises a
  dry-run command without submitting Slurm jobs. Use this when the command can
  run on a workstation with explicit inputs and does not need Slurm discovery.
- `Local fixture replay`: runs in the default docs test against committed
  synthetic or reduced fixtures. Use this for parser, aggregation, and renderer
  behavior that can be proven without generated result trees.
- `Local replay`: local validation command that is run during handoff checks but
  is not an `aicr-test` block.
- `AICR HPC dry-run doctest`: reserved for future default docs tests that must
  run on AICR HPC because they use Slurm-aware discovery, but still submit no
  jobs.
- `AICR HPC dry-run replay`: documented Slurm-aware dry-run command that is
  replayed manually on AICR HPC.
- `AICR HPC apply doctest`: runs only with `DOCS_APPLY=1` and explicit
  `NODELIST`; submits smoke-sized Slurm work.
- `AICR HPC apply replay`: documented applied command that is replayed manually
  on AICR HPC.
- `AICR HPC allocation replay`: runs inside an existing Slurm allocation or
  through a Slurm wrapper; not part of default docs tests.
- `AICR HPC render replay`: reads generated or restored result trees.
- `Manual/HPC review`: templates, long campaigns, or study workflows that are
  documented but not default doctests.

## Executable Documentation

Documentation tests use `aicr-test` metadata blocks. Defaults must be safe:

- Default `make docs-test-*` targets may run local help, inspect, and dry-run
  commands.
- Default docs tests must not submit Slurm jobs, require GPUs, require VAST
  pressure, or require generated result trees. Avoid default doctests for
  dry-run commands that perform Slurm node discovery or write fleet manifests;
  document those commands as AICR HPC dry-run replay instructions.
- Applied docs tests must require `DOCS_APPLY=1` and an explicit `NODELIST`.
- Applied docs tests should use smoke-sized profiles or tiny scale ladders.
- Long campaign replay belongs in the module test plan, not in default doctests.
- Render replay reads generated or restored result trees. It is an AICR HPC
  replay step unless the module has committed render fixtures.

Every mature module should expose:

- `make docs-test-plan-<module>` to list selected tests.
- `make docs-test-<module>` to run local-safe tests.
- `DOCS_APPLY=1 ... make docs-test-<module>` for gated AICR HPC apply checks
  when the module has an applied Slurm path.

## Node And Cluster Examples

Use real AICR node-name conventions only:

- RTX Pro 6000 nodes: `a0001` through `a0019`.
- B200 nodes: `b0001` through `b0031`.

Prefer placeholders such as `<a-node>`, `<b-node>`, `<node>`, or
`<node1>,<node2>` when the exact node is not important. Do not introduce
alternate naming schemes in examples, test plans, or man pages.

## Script Roles

Use these roles consistently:

- `render-*`: report or dashboard renderer that reads existing parsed artifacts.
- `run-*`: allocation-side runner used inside sbatch script or on a compute node directly.
- `run-*-workload.py`: low-level workload engine called by the shell runner, not a top-level public primitive.
- `submit-*`: host-side Slurm submitter that prints or submits one job or job family.
- `sweep-*`: host-side matrix submitter for parameter sweeps.

Existing script and Make target names are stable public interfaces.

## Make Interface

Make targets are the curated public driver and should compose script primitives
without hiding the important runtime shape.

Use these naming patterns:

- `verify-<module>` for verification/readiness workflows.
- `benchmark-<module>` for benchmark workflows.
- `render-<module>` or `render-<module>-<view>` for read-only report replay.
- `docs-test-plan-<module>` and `docs-test-<module>` for executable docs.

Make examples should show dry-run first, then gated apply examples. Apply
examples should include `APPLY=1` and explicit node or node-count controls.

## Man Page Links

Every public script listed in [the command reference](../../man/README.md)
must have a man page. When a public script is named in prose, link the script
name to that man page every time. Copy-paste command blocks and inline command
snippets should stay literal and are the only exception.

## Fleet Boundary

Explicit fleet submitters are verification-module primitives. GDS uses
[run-gds-fleet.sh](../../man/run-gds-fleet.md), and NCCL uses
[submit-nccl-suite.sh](../../man/submit-nccl-suite.md) for local, RDMA, and
scale job families. DataLoader and DDP use explicit one-job submitters,
DataLoader sweeps, and Make campaign shapes instead of standalone fleet
submitters.

GDS direct fleet submissions and the curated `make verify-gds` interface
default to a conservative 30-second numeric stagger because each node can run
sustained filesystem traffic. Faster launch rates should be treated as
intentional stress behavior, not the public teaching default.

## Benchmark Stagger Policy

Storage-backed modules can change the measured result by changing how many jobs
hit VAST at the same time. For these modules, a numeric stagger is a controlled
pressure setting: lower values increase concurrent filesystem pressure, and
higher values reduce it. Published benchmark-style studies should run only one
job of that IO-heavy type at a time by using a Slurm dependency-chain stagger
mode when the module submitter supports it.

GDS supports this as `--submit-stagger-seconds benchmark`. In that mode the
submitter still spaces `sbatch` calls by five seconds to avoid scheduler bursts,
but every job after the first is submitted with
`--dependency=afterany:<previous_job_id>`, so Slurm starts only one selected GDS
job at a time even though the submitter has queued the whole chain.

This policy applies to GDS now and should apply to DataLoader and DDP when their
storage-backed campaign submitters grow the same mode. It does not apply to NCCL
or HPL-MxP study interpretation in the same way: those modules primarily measure
network or local compute behavior, so their public stagger controls are scheduler
pacing and campaign-shape controls rather than VAST IO isolation controls.

## Renderer Boundary

Renderers read existing parsed artifacts and create dashboards, reports, CSV, JSON metadata, or PNG outputs. Make may call renderers as part of an opinionated campaign flow. Script artifact sections should list only the artifacts produced by the documented runner, submitter, or sweep scripts, not duplicate rendered report outputs.

Dashboard statistic definitions live in [Stats Explained](../stats-explained.md).
Generated reports should link there directly.

Render replay belongs in `test-plan.md` when a module produces reports or
dashboards. If no committed fixture exists, the test plan should say that render
replay requires generated or restored `results/` trees and is not part of the
default docs tests.

## Profiles And Overrides

Profiles provide named workload intensity or behavior, usually `small`, `medium`, `large`, or `custom`.

Use `PROFILE=<name>` consistently to select a module profile from Make or the environment. Module-specific profile config environment variables, such as `AICR_GDS_PROFILE_CONFIG`, point to custom JSON profile definitions and do not select the active profile by themselves.

When a module has profiles, precedence is:

```text
explicit CLI or Make run arguments > environment variables > profile defaults
```

DataLoader and DDP profiles control workload intensity only. Nodes, GPU counts, modes, launchers, partitions, and node lists stay explicit.

## Slurm Primitive Examples

The `slurm-<module>.sbatch` files show how to wrap a script primitive in your own Slurm workload. The sbatch wrapper owns scheduler shape: partition, node count, task count, GPU resource request, CPU count, and time limit.

The primitive command inside the wrapper should avoid cluster-specific defaults. Set `AICR_CLUSTER_NAME` explicitly when detection is not enough, or let the runner detect the cluster from the allocated GPU type. If you submit a copied template from outside the install root, pass `AICR_BMARK_DIR` with `sbatch --mem=0 --export=ALL,AICR_BMARK_DIR=/path/to/aicr-bench ...`.

When customizing a Slurm primitive example:

- Keep one `exec` line active.
- Align `#SBATCH --nodes`, `#SBATCH --ntasks`, `#SBATCH --ntasks-per-node`, and GPU count with that active command.
- Keep `#SBATCH --mem=0` unless a documented diagnostic intentionally tests a
  smaller Slurm memory cgroup.
- Use `rtx-batch` for RTX jobs and `b200-batch` for B200 jobs on AICR HPC.
- Use profile inspection from `scripts.md`; submitted workload examples should run work, not inspect profiles.

## Artifact Sections

Every implemented module documents artifacts at the end of both `scripts.md` and `make.md`.

- Script artifact sections describe what direct primitive runs, submitters, or sweeps write.
- Make artifact sections describe the curated campaign layout, reports, dashboards, manifests, and rendered files.
- Examples describe expected artifact classes. Studies and reviewed reports link published evidence bundles; examples should not link raw generated `results/` trees.
