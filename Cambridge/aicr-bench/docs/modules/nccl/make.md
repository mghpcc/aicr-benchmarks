# NCCL Make Interface

Purpose: run curated NCCL local and RDMA jobs through Make, with survey mode available for node discovery.

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
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0001
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
make verify-nccl-suite NCCL_SCOPE=local CLUSTER={{cluster}} PROFILE=small NODELIST={{node}} APPLY=1
```

## Local Mode Vs RDMA Mode

```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0001
make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER=b200 PROFILE=small NODELIST=b0001,b0002 NCCL_NODES_PER_JOB=2
```

## Alternative Local Modes

```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0001 NCCL_SUITE_CLASS=b200_1proc_8g
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0001 NCCL_SUITE_CLASS=b200_2rank_socket_4g
```

## Multi-node Jobs

```bash
make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER=b200 PROFILE=small NODELIST=b0001,b0002,b0003,b0004 NCCL_NODES_PER_JOB=4
```

## Fleet Runs

Omit `NODELIST` only when you intentionally want the submitter to discover idle nodes in the selected partition.

## Repeat Runs

```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0001 REPEAT_COUNT=3 APPLY=1
```

## Campaign Node Discovery

For `NCCL_SCOPE=survey`, Make submits rank-per-GPU survey groups across the candidate nodes. Use it to sample candidate nodes before selecting the explicit `NODELIST` for local and RDMA study runs. Set `NCCL_SURVEY_SIZES` when you want a specific ladder; at the script layer, omitting `--survey-sizes` uses the cluster ladder: B200 `1,2,4,8,16` and RTX `1,2,4,8`.

## ASCII Dashboard

NCCL currently renders a Markdown dashboard:

```bash
make render-nccl-suite NCCL_SCOPE=local CLUSTER=b200 DATE=today
```

## Custom Profiles

NCCL profiles are `small`, `medium`, and `large`. Custom message-shape work belongs in script-level experimentation.

## Artifacts

NCCL runs produce raw captures, parsed summaries, suite reports, and optional
submitter manifests under the configured `results` root.

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
results/reports/<date>/nccl-suite-local/<manifest>.json
results/reports/<date>/nccl-suite-rdma/<manifest>.json
results/reports/<date>/nccl-suite-survey/<manifest>.json
results/reports/<date>/nccl-suite-<cluster>.md
results/reports/<date>/nccl-suite-survey/<cluster>-index.md
results/reports/<date>/nccl-suite-survey/<cluster>-<nodes>n.md
```

Reviewed study pages link downloadable bundles, provenance, checksums, and
retrieve/verify commands rather than raw generated run trees.
