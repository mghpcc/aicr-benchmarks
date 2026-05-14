# Make Driver

Purpose: explain when to use Make instead of direct scripts.

Use Make when you want AICR-Bench to drive a repeatable benchmark campaign shape: select nodes, submit jobs, wait when needed, render dashboards, and write artifacts into the standard tree.

Use scripts directly when you are composing your own Slurm wrapper, debugging one primitive, embedding AICR-Bench checks in another suite, or inspecting the exact interface behind a Make target.

## Common Controls

| Variable | Meaning |
| --- | --- |
| `CLUSTER` | `b200` or `rtxpro6000`. |
| `PROFILE` | Selected profile for modules that use `small`, `medium`, `large`, or `custom`. |
| `NODELIST` | Explicit node or comma-separated node pool. |
| `APPLY=1` | Submit Slurm jobs. Omit it for dry-run previews. |
| `REPEAT_COUNT` | Repeat rounds for modules that support repeat submissions. |
| `REPEAT_AGGREGATION` | `standard` or `olympic` repeat summary. |

Applied examples should always use explicit `NODELIST` plus `APPLY=1`.

For promoted benchmark-style studies, prefer `REPEAT_COUNT=12` with
`REPEAT_AGGREGATION=olympic` when the module supports repeats. Olympic
aggregation drops the lowest and highest passed numeric samples, then averages
the remaining ten. Smaller repeat counts are useful for workflow examples and
first-pass exploration.

For storage-backed promoted studies, also prefer a dependency-chain stagger mode
when the module supports it. In GDS, set
`GDS_SUBMIT_STAGGER_SECONDS=benchmark` to submit the full campaign while Slurm
starts only one selected GDS job at a time. Numeric stagger values remain useful
when you intentionally want to study filesystem launch pressure.

## Inspect Make

```bash
make help
```

The command reference remains [man/make.md](../../man/make.md).
