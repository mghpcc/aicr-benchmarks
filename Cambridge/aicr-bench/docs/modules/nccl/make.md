# NCCL Make Interface

Purpose: run curated NCCL local, RDMA, and scale jobs through Make.

## One Node Dry Run

<!-- aicr-test
id: nccl-dry-run-small-one-node
suite: nccl
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Dry run"
    - "scope=local"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0002
```

## Run On One Node

Add `APPLY=1` only when you want to submit.

<!-- aicr-test
id: nccl-one-node-small
suite: nccl
kind: slurm-apply
safety: one-node
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Submitted"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER={{cluster}} PROFILE=smoke NODELIST={{node}} APPLY=1
```

## Local Mode Vs RDMA Mode

<!-- aicr-test
id: nccl-rdma-two-node-dry-run
suite: nccl
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "scope=rdma"
    - "nodes_per_job=2"
    - "--ntasks-per-node=8"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER=b200 PROFILE=small NODELIST=b0002,b0003 NCCL_NODES_PER_JOB=2
```

RTX RDMA uses the same suite interface and supports 2-, 4-, and 8-node groups.

<!-- aicr-test
id: nccl-rdma-rtx-two-node-dry-run
suite: nccl
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "scope=rdma"
    - "rtxpro6000"
    - "nodes_per_job=2"
    - "rtxpro6000-nccl-suite-rdma.sbatch"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER=rtxpro6000 PROFILE=small NODELIST=a0002,a0003 NCCL_NODES_PER_JOB=2
```

Two-node RDMA apply is an explicit AICR HPC smoke test.

<!-- aicr-test
id: nccl-rdma-two-node-apply
suite: nccl
kind: slurm-apply
safety: two-node
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Submitted"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER={{cluster}} PROFILE=smoke NODELIST={{nodes2}} NCCL_NODES_PER_JOB=2 APPLY=1
```

## Alternative Local Modes

The default local suite class is `b200_8rank_1g` on B200 and `rtx_8rank_1g`
on RTX. Both are rank-per-GPU shapes.

<!-- aicr-test
id: nccl-b200-default-suite-class-dry-run
suite: nccl
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "suite_class=b200_8rank_1g"
    - "scope=local"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0002 NCCL_SUITE_CLASS=b200_8rank_1g
```

<!-- aicr-test
id: nccl-rtx-default-suite-class-dry-run
suite: nccl
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "suite_class=rtx_8rank_1g"
    - "rtxpro6000"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=rtxpro6000 PROFILE=small NODELIST=a0002 NCCL_SUITE_CLASS=rtx_8rank_1g
```

```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0002 NCCL_SUITE_CLASS=b200_1proc_8g
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0002 NCCL_SUITE_CLASS=b200_2rank_socket_4g
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=rtxpro6000 PROFILE=small NODELIST=a0002 NCCL_SUITE_CLASS=rtx_pair_policy
```

## Multi-node Jobs

```bash
make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER=b200 PROFILE=small NODELIST=b0002,b0003,b0004,b0005 NCCL_NODES_PER_JOB=4
```

## Fleet Runs

Omit `NODELIST` only when you intentionally want the submitter to discover idle nodes in the selected partition.

## Repeat Runs

```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0002 REPEAT_COUNT=3 APPLY=1
```

## Scale Ladder

For `NCCL_SCOPE=scale`, Make submits rank-per-GPU scale groups across the candidate nodes. Set `NCCL_SCALES` when you want a specific ladder; omitting it uses the script default for the selected cluster.

<!-- aicr-test
id: nccl-scale-two-node-dry-run
suite: nccl
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "scope=scale"
    - "scales=1 2"
    - "--nodes=2"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=scale CLUSTER=b200 PROFILE=small NODELIST=b0002,b0003 NCCL_SCALES=1,2
```

RTX scale defaults to `1,2,4`; the same dry-run pattern previews a small
two-node ladder.

<!-- aicr-test
id: nccl-scale-rtx-two-node-dry-run
suite: nccl
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "scope=scale"
    - "rtxpro6000"
    - "scales=1 2"
    - "--nodes=2"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=scale CLUSTER=rtxpro6000 PROFILE=small NODELIST=a0002,a0003 NCCL_SCALES=1,2
```

Tiny scale apply is an explicit AICR HPC smoke test.

<!-- aicr-test
id: nccl-scale-two-node-apply
suite: nccl
kind: slurm-apply
safety: two-node
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Submitted"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=scale CLUSTER={{cluster}} PROFILE=smoke NODELIST={{nodes2}} NCCL_SCALES=1,2 APPLY=1
```

The May 16 verification campaign used `NCCL_SCOPE=scale`, `PROFILE=small`,
`REPEAT_COUNT=5`, `REPEAT_AGGREGATION=olympic`, and rank-per-GPU scale ladders.
B200 used `NCCL_SCALES=1,2,4,8,16`; RTX used `NCCL_SCALES=1,2,4`.

<!-- aicr-test
id: nccl-campaign-shape-dry-run
suite: nccl
kind: slurm-dry-run
safety: dry-run
cwd: install-root
expect:
  mode: contains
  patterns:
    - "scope=scale"
    - "repeat_count=5"
    - "repeat_aggregation=olympic"
    - "scales=1 2 4 8 16"
    - "--ntasks-per-node=8"
    - "--cpus-per-task=16"
-->
```bash
make verify-nccl-suite NCCL_SCOPE=scale CLUSTER=b200 PROFILE=small NODELIST=b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017 NCCL_SCALES=1,2,4,8,16 REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic
```

## Markdown Dashboard

Use Make to replay reports from existing or freshly generated result trees:

```bash
make render-nccl-suite NCCL_SCOPE=local CLUSTER=b200 DATE=today
```

`NCCL_SCOPE=local`, `rdma`, or `scale` selects the report shape. For RDMA
reports, set `NCCL_NODES_PER_JOB=<n>` when you want a specific node-count view.

## Custom Profiles

NCCL profiles are `smoke`, `small`, `medium`, and `large`. Custom
message-shape work belongs in script-level experimentation.

## Artifacts

NCCL runs produce raw captures, parsed summaries, suite reports, and optional
submitter manifests under the configured `results` root.

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

Metadata and parsed files:

```text
results/by-date/<date>/raw/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/metadata/record.json
results/by-date/<date>/parsed/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/<scope-path>/nccl-suite-<scope>/<run_id>/status.json
```

Manifest, index, and rendered report files:

```text
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
results/reports/<date>/nccl-suite/<manifest>.json
results/reports/<date>/nccl-suite-local-<cluster>.md
results/reports/<date>/nccl-suite-rdma-<cluster>-<nodes>n.md
results/reports/<date>/nccl-suite-<cluster>.md
results/reports/<date>/nccl-suite-<cluster>-<scale>.md
```

Reviewed study pages link downloadable bundles, provenance, checksums, and
retrieve/verify commands rather than raw generated run trees.
