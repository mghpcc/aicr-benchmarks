# Module Conventions

Purpose: document shared naming, workflow, and artifact conventions for public AICR-Bench modules.

AICR-Bench has two public layers:

- Scripts are benchmark primitives for users building their own Slurm workflows, studies, reports, or automation.
- Make is the curated campaign driver that composes those primitives into repeatable runs, dashboards, and repo-standard artifact layouts.

## Module Shape

Each public module directory provides:

- `README.md`: module landing page.
- `scripts.md`: primitive script interface.
- `make.md`: curated Make interface.
- `examples.md`: Slurm primitive example, representative Make commands, and produced artifact lists.
- `studies.md`: recommended studies, collection roadmaps, or curated reports.
- `test-plan.md`: executable coverage, HPC replay steps, known gaps, and acceptance criteria for documented commands.

## Script Roles

Use these roles consistently:

- `render-*`: report or dashboard renderer that reads existing parsed artifacts.
- `run-*`: allocation-side runner used inside sbatch script or on a compute node directly.
- `run-*-workload.py`: low-level workload engine called by the shell runner, not a top-level public primitive.
- `submit-*`: host-side Slurm submitter that prints or submits one job or job family.
- `sweep-*`: host-side matrix submitter for parameter sweeps.

Existing script and Make target names are stable public interfaces.

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
higher values reduce it. Promoted benchmark-style studies should run only one
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
Generated reports should link there rather than to operator-private paths.

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

The primitive command inside the wrapper should avoid cluster-specific defaults. Set `AICR_CLUSTER_NAME` explicitly when detection is not enough, or let the runner detect the cluster from the allocated GPU type. If you submit a copied template from outside the install root, pass `AICR_BMARK_DIR` with `sbatch --export=ALL,AICR_BMARK_DIR=/path/to/aicr-bench ...`.

When customizing a Slurm primitive example:

- Keep one `exec` line active.
- Align `#SBATCH --nodes`, `#SBATCH --ntasks`, `#SBATCH --ntasks-per-node`, and GPU count with that active command.
- Use `GPU1` for RTX jobs and `GPU2` for B200 jobs on AICR HPC.
- Use profile inspection from `scripts.md`; submitted workload examples should run work, not inspect profiles.

## Artifact Sections

Every implemented module documents artifacts at the end of both `scripts.md` and `make.md`.

- Script artifact sections describe what direct primitive runs, submitters, or sweeps write.
- Make artifact sections describe the curated campaign layout, reports, dashboards, manifests, and rendered files.
- Examples describe expected artifact classes. Studies and reviewed reports link promoted evidence bundles; examples should not link raw generated `results/` trees.
