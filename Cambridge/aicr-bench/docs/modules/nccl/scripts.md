# NCCL Script Interface

Purpose: document NCCL primitives for custom Slurm workflows and suite composition.

The NCCL script layer exposes local, RDMA, and survey submission primitives. Use it directly when you need to build your own grouping policy or inspect the workload profile behind a Make target. Study runs use local baselines and explicit RDMA groups; survey mode samples candidate node groups before choosing a `NODELIST`.

## Inspect The Interface

Allocation-side runner:

```bash
scripts/verify/run-nccl-suite.sh --help
```

Host-side submitter:

<!-- aicr-test
id: nccl-submit-help
suite: nccl
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--scope"
    - "--survey-sizes"
-->
```bash
scripts/verify/submit-nccl-fleet.sh --help
```

## Inspect A Profile

<!-- aicr-test
id: nccl-inspect-small
suite: nccl
kind: local
safety: inspect
cwd: install-root
expect:
  mode: contains
  patterns:
    - "profile=small"
    - "max_bytes=1G"
-->
```bash
scripts/verify/run-nccl-suite.sh --profile small --inspect-profile
```

## Profiles

| Profile | Use |
| --- | --- |
| `small` | Teaching-sized local, RDMA, and survey checks. |
| `medium` | Longer NCCL message sweep. |
| `large` | Extended NCCL message sweep. |

## Direct Use

Use [submit-nccl-fleet.sh](../../../man/submit-nccl-fleet.md) when you need
script-level control over `--scope`, `--nodes-per-job`, `--survey-sizes`, or
grouping behavior. Use [run-nccl-suite.sh](../../../man/run-nccl-suite.md)
inside an existing Slurm allocation.

## RDMA Baseline Note

The NCCL RDMA submitter starts multi-node RDMA studies at two nodes. For one-node baselines, use local mode. B200 RDMA studies support `--nodes-per-job 2,4,8,16`; RTX supports `--nodes-per-job 2,4,8`. Use `NCCL_SCOPE=survey` when you need to sample candidate node groups across a fleet before building the `NODELIST`.

## Artifacts

Direct NCCL runner and submitter runs write raw suite captures, parsed summaries,
and index records under the configured `results` root. Reviewed study pages
link downloadable bundles, provenance, checksums, and retrieve/verify commands.
