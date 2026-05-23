# GDS Test Plan

Purpose: define executable coverage and HPC replay expectations for the GDS module.

GDS is a storage-backed readiness module. Its tests must prove the documented
command surfaces are usable without turning routine documentation replay into a
filesystem stress test.

## Current Coverage

- Documentation links and man-page links are checked by `make docs-link-check`.
- Local documentation replay checks script help, profile inspection, one-node dry
  runs, custom dry runs, and benchmark-stagger dry runs.
- Applied documentation replay is AICR HPC only and uses one explicit node with
  `PROFILE=smoke`.
- Dashboard rendering is an AICR HPC replay step because it requires generated
  GDS manifests and node-level parsed summaries.

## Replay Entry Points

Plan GDS documentation tests:

```bash
make docs-test-plan-gds
```

Run local-safe GDS documentation tests:

```bash
make docs-test-gds
```

Run the same scan through the generic interface:

```bash
make docs-test DOCS=docs/modules/gds DOCS_TEST_SUITE=gds
```

On AICR HPC, applied documentation checks must be explicit and node-scoped:

```bash
DOCS_APPLY=1 CLUSTER=<b200|rtxpro6000> NODELIST=<node> make docs-test-gds
```

## Command Coverage

| Source | Command | Replay level | Acceptance |
| --- | --- | --- | --- |
| `scripts.md` | `scripts/verify/run-gds.sh --help` | Local doctest | Exits zero and prints usage plus profile inspection options. |
| `scripts.md` | `scripts/verify/run-gds-fleet.sh --help` | Local doctest | Exits zero and documents `--submit-stagger-seconds <n\|benchmark>`. |
| `scripts.md` | `scripts/verify/submit-gds-fleet.sh --help` | Local doctest | Compatibility wrapper reaches the fleet submitter help. |
| `scripts.md` | `scripts/verify/run-gds.sh --profile small --inspect-profile` | Local doctest | Parses the committed small profile without running GDS. |
| `scripts.md` | `scripts/verify/run-gds.sh --profile smoke --inspect-profile` | Local doctest | Parses the committed smoke profile used by applied docs tests. |
| `scripts.md` | custom `--custom-gdsio-args ... --inspect-profile` | Local doctest | Prints the synthetic custom profile without launching `gdsio`. |
| `man/run-gds.md` | `scripts/verify/run-gds.sh --profile smoke` | AICR HPC allocation replay | Runs inside Slurm and writes raw plus parsed GDS evidence. |
| `man/run-gds-fleet.md` | `scripts/verify/run-gds-fleet.sh --cluster b200 --profile small --nodes <node>` | AICR HPC dry-run replay | Prints a one-node `sbatch` command and writes a dry-run manifest. |
| `man/run-gds-fleet.md` | `scripts/verify/run-gds-fleet.sh --cluster <cluster> --profile smoke --nodes <node> --apply` | AICR HPC apply replay | Submits one smoke job only after intentional apply mode. |
| `man/run-gds-fleet.md` | `--repeat-count ... --repeat-aggregation olympic --submit-stagger-seconds benchmark` | AICR HPC dry-run replay | Shows 5-second `sbatch` pacing and `afterany` dependency-chain semantics without submitting storage work. |
| `man/submit-gds-fleet.md` | `scripts/verify/submit-gds-fleet.sh ...` | Local doctest | Wrapper behavior is covered by help and direct fleet replay. |
| `make.md` | `make verify-gds CLUSTER=b200 PROFILE=small NODELIST=b0001` | Local dry-run doctest | Prints the one-node GDS dry-run plan. |
| `make.md` | `make verify-gds CLUSTER={{cluster}} PROFILE=smoke NODELIST={{node}} APPLY=1` | AICR HPC apply doctest | Submits one smoke job and waits for completion. |
| `make.md` | `make verify-gds ... GDS_SUBMIT_STAGGER_SECONDS=benchmark` | Local dry-run doctest | Shows benchmark dependency-chain submission shape and 5-second scheduler pacing. |
| `make.md` | `make render-gds-ascii CLUSTER=<cluster> DATE=today` | AICR HPC render replay | Reads generated manifests and prints the GDS dashboard. |
| `examples.md` | Slurm primitive template | Manual/HPC review | One active `exec` line, scheduler placeholders clearly marked. |
| `examples.md` | module-local `slurm-gds.sbatch` | Manual/HPC review | Runs after replacing partition/GRES placeholders or passing an install root. |
| `examples.md` | cluster-specific `slurm/verify/*-gds-1n-8g.sbatch` templates | Manual/HPC review | Scheduler resources match one-node, eight-GPU GDS validation on the selected cluster. |
| `examples.md` | `make verify-gds CLUSTER={{cluster}} PROFILE=smoke NODELIST={{node}} APPLY=1` | AICR HPC apply doctest | Submits one smoke job only after intentional apply mode and explicit node selection. |
| `examples.md` | custom `make verify-gds ... PROFILE=custom ... AICR_GDS_CUSTOM_GDSIO_ARGS=...` | Local dry-run doctest | Prints the custom GDS profile shape without submitting work. |

## Local Replay

Local replay is intentionally narrow:

```bash
make docs-test-plan-gds
make docs-test-gds
make docs-test DOCS=docs/modules/gds DOCS_TEST_SUITE=gds
```

These checks should pass without Slurm, GPUs, `gdscheck`, or `gdsio` because
they use help, inspect, and dry-run command surfaces.

## AICR HPC Replay

Dry-run one explicit node on each cluster:

```bash
make verify-gds CLUSTER=b200 PROFILE=smoke NODELIST=<b-node>
make verify-gds CLUSTER=rtxpro6000 PROFILE=smoke NODELIST=<a-node>
```

Run one smoke apply on each cluster:

```bash
DOCS_APPLY=1 CLUSTER=b200 NODELIST=<b-node> make docs-test-gds
DOCS_APPLY=1 CLUSTER=rtxpro6000 NODELIST=<a-node> make docs-test-gds
make verify-gds CLUSTER=b200 PROFILE=smoke NODELIST=<b-node> APPLY=1
scripts/verify/run-gds-fleet.sh --cluster rtxpro6000 --profile smoke --nodes <a-node> --apply
```

Render dashboards from generated manifests:

```bash
make render-gds-ascii CLUSTER=b200 DATE=today
make render-gds-ascii CLUSTER=rtxpro6000 DATE=today
```

Dry-run storage-pressure and filtering controls:

```bash
make verify-gds CLUSTER=b200 PROFILE=custom NODELIST=<b-node> AICR_GDS_CUSTOM_GDSIO_ARGS="-x 0 -I 0 -d 0 -w 1 -m 0 -s 1G -i 1M"
make verify-gds CLUSTER=b200 PROFILE=smoke NODELIST=<b-node>,<b-node-2> REPEAT_COUNT=2 REPEAT_AGGREGATION=olympic GDS_SUBMIT_STAGGER_SECONDS=benchmark
GPU_PREFLIGHT_FILTER=1 make verify-gds CLUSTER=b200 PROFILE=smoke NODELIST=<b-node>
GPU_PREFLIGHT_FILTER=1 make verify-gds CLUSTER=rtxpro6000 PROFILE=smoke NODELIST=<a-node>
```

## Known Gaps

- `small`, `medium`, and `large` apply tests remain manual study replay because
  they intentionally create more storage work than documentation validation.
- Repeat and Olympic GDS applies are not default docs tests; the replayable
  coverage verifies their submission shape and renderer metadata.
- No committed fixture currently renders GDS dashboards without generated
  result manifests.
