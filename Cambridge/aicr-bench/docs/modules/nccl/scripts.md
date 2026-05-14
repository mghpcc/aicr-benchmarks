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
submitter manifests, and index records under the configured `results` root.
Rendered reports are renderer or Make outputs and are intentionally not listed
here.

Raw run directories:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/nccl-suite-local/<run_id>/
results/by-date/<date>/raw/<cluster>/multi-node/nccl-suite-rdma/<run_id>/
results/by-date/<date>/raw/<cluster>/multi-node/nccl-suite-survey/<run_id>/
```

Canonical files:

```text
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/canonical/nccl-suite-summary.md
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/canonical/nccl-suite-env.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/canonical/nccl-suite-command.sh
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/canonical/nccl-suite-records.jsonl
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/canonical/nccl-suite-capabilities.json
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/canonical/nccl-suite-capability-probe-stdout.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/canonical/nccl-suite-capability-probe-stderr.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/canonical/gpu-preflight.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/canonical/<suite-class>--<collective>-stdout.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/canonical/<suite-class>--<collective>-stderr.txt
```

Metadata, parsed, manifest, and index files:

```text
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/metadata/record.json
results/by-date/<date>/parsed/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/status.json
results/reports/<date>/nccl-suite-local/<manifest>.json
results/reports/<date>/nccl-suite-rdma/<manifest>.json
results/reports/<date>/nccl-suite-survey/<manifest>.json
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
```

Reviewed study pages link downloadable bundles, provenance, checksums, and
retrieve/verify commands rather than raw generated run trees.
