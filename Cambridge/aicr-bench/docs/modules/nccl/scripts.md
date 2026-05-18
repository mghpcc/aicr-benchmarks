# NCCL Script Interface

Purpose: document NCCL primitives for custom Slurm workflows and suite composition.

The NCCL script layer exposes local, RDMA, and scale submission primitives. Use it directly when you need to build your own grouping policy or inspect the workload profile behind a Make target. Study runs use local baselines, explicit RDMA groups, and rank-per-GPU scale ladders.

## Inspect The Interface

Allocation-side runner:

<!-- aicr-test
id: nccl-run-help
suite: nccl
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--scope"
    - "--nodes-per-job"
-->
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
    - "--scales"
-->
```bash
scripts/verify/submit-nccl-suite.sh --help
```

Report renderer:

<!-- aicr-test
id: nccl-render-help
suite: nccl
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--scope"
    - "--cluster"
-->
```bash
bash scripts/lib/run-repo-python.sh scripts/report/render-nccl-suite-report.py --help
```

## Profiles

| Profile | Use |
| --- | --- |
| `smoke` | Tiny launch and parser proof. |
| `small` | Teaching-sized local, RDMA, and scale checks. |
| `medium` | Longer NCCL message sweep. |
| `large` | Extended NCCL message sweep. |

## Suite Classes And Operations

Local-mode suite classes are explicit and cluster scoped:

| Cluster | Suite class | Shape |
| --- | --- | --- |
| `b200` | `b200_8rank_1g` | Default rank-per-GPU local run: eight ranks, one GPU per rank. |
| `b200` | `b200_1proc_8g` | One process drives all eight GPUs. |
| `b200` | `b200_2rank_socket_4g` | Two socket-local ranks, four GPUs per rank. |
| `rtxpro6000` | `rtx_8rank_1g` | Default rank-per-GPU local run: eight ranks, one GPU per rank. |
| `rtxpro6000` | `rtx_pair_policy` | Four preferred two-GPU pair checks. |

The default operation set is `allreduce`, `allgather`, `reduce_scatter`, and
`alltoall`. The RTX pair-policy class replaces `alltoall` with `sendrecv`.

RDMA and scale runs synthesize suite-class labels from their scope and node
count, such as `b200_rdma_2n_8rank_1g_per_node` or
`rtxpro6000_scale_4n_8rank_1g_per_node`.

## Direct Use

Use [submit-nccl-suite.sh](../../../man/submit-nccl-suite.md) when you need
script-level control over `--scope`, `--nodes-per-job`, `--scales`, or
grouping behavior. Use [run-nccl-suite.sh](../../../man/run-nccl-suite.md)
inside an existing Slurm allocation.

## RDMA Baseline Note

The NCCL RDMA submitter starts multi-node RDMA studies at two nodes. For
one-node baselines, use local mode. B200 RDMA studies support
`--nodes-per-job 2,4,8,16`; RTX supports `--nodes-per-job 2,4,8`. Use
`NCCL_SCOPE=scale` when you need a rank-per-GPU scale ladder.

RTX RDMA support lives in the standard suite submitter and Make interface:
[submit-nccl-suite.sh](../../../man/submit-nccl-suite.md) and
`make verify-nccl-suite NCCL_SCOPE=rdma`.

## Command Roles

| Script | Role |
| --- | --- |
| [submit-nccl-suite.sh](../../../man/submit-nccl-suite.md) | Host-side dry-run-first submitter for local, RDMA, and scale suite jobs. |
| [run-nccl-suite.sh](../../../man/run-nccl-suite.md) | Allocation-side runner called by Slurm templates. |
| [render-nccl-suite-report.py](../../../man/render-nccl-suite-report.md) | Report renderer used by `make render-nccl-suite`. |

## Artifacts

Direct NCCL runner and submitter runs write raw suite captures, parsed summaries,
submitter manifests, and index records under the configured `results` root.
Rendered reports are renderer or Make outputs and are intentionally not listed
here.

Raw run directories:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/nccl-suite-local/<run_id>/
results/by-date/<date>/raw/<cluster>/multi-node/nccl-suite-rdma/<run_id>/
results/by-date/<date>/raw/<cluster>/multi-node/nccl-suite-scale/<run_id>/
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
results/reports/<date>/nccl-suite/<manifest>.json
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
```

The submitter manifest directory is shared across local, RDMA, and scale
scopes. Scope-specific Markdown reports are renderer or Make outputs under
`results/reports/<date>/`.

Reviewed study pages link downloadable bundles, provenance, checksums, and
retrieve/verify commands rather than raw generated run trees.
