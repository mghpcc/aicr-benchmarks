# DataLoader Script Interface

Purpose: document DataLoader primitives for custom benchmark workflows.

The DataLoader script layer is useful when composing your own sweep, Slurm wrapper, or report workflow. Profiles control workload intensity defaults only; topology, mode, and node selection remain explicit.

## Dataset Contract

DataLoader expects `AICR_IMAGENET_DIR` to point at an ImageNet-style dataset
root with `train` or `val` splits. See
[ImageNet dataset preparation](../../resources/imagenet.md) for acquisition,
validation split preparation, and layout checks.

## Modes

| Mode | Use |
| --- | --- |
| `single` | One GPU on one node. |
| `replicated` | Eight GPUs on one node, each rank sees the same dataset view. |
| `distributed-sharded` | Eight GPUs per node with distributed sharding across one or more nodes. |

## Inspect The Interface

Allocation-side runner:

```bash
scripts/benchmark/run-dataloader.sh --help
```

Host-side submitter:

<!-- aicr-test
id: dataloader-submit-help
suite: dataloader
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--mode"
    - "--gpu-count"
-->
```bash
scripts/benchmark/submit-dataloader.sh --help
```

Host-side sweep submitter:

```bash
scripts/benchmark/sweep-dataloader.sh --help
```

## Inspect A Profile

<!-- aicr-test
id: dataloader-inspect-small
suite: dataloader
kind: local
safety: inspect
cwd: install-root
expect:
  mode: contains
  patterns:
    - "profile=small"
    - "measured_batches=100"
-->
```bash
scripts/benchmark/submit-dataloader.sh --profile small --inspect-profile
```

## Profiles

| Profile | Batch size | Workers | Prefetch | Warmup batches | Measured batches |
| --- | ---: | ---: | ---: | ---: | ---: |
| `small` | 512 | 16 | 4 | 20 | 100 |
| `medium` | 512 | 16 | 4 | 100 | 500 |
| `large` | 512 | 16 | 4 | 200 | 5000 |

## Direct Use

Use [submit-dataloader.sh](../../../man/submit-dataloader.md) for one job and
[sweep-dataloader.sh](../../../man/sweep-dataloader.md) for parameter matrices.
Use [run-dataloader.sh](../../../man/run-dataloader.md) inside an existing
allocation. Arguments after `--` are forwarded to
[run-dataloader.sh](../../../man/run-dataloader.md).

The Python workload engine is called by
[run-dataloader.sh](../../../man/run-dataloader.md); use the shell entrypoints
for routine runs.

## Artifacts

Direct DataLoader runner, submitter, and sweep runs write node or multi-node raw captures, parsed summaries, and index records. Rendered reports are renderer or Make outputs and are intentionally not listed here.

Raw run directories:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/dataloader/<run_id>/
results/by-date/<date>/raw/<cluster>/multi-node/dataloader/<run_id>/
```

Canonical files:

```text
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-summary.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-env.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-command.sh
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-stdout.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-stderr.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/dataloader-metrics.json
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/nvidia-smi-L.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/rank-metrics.tsv
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/ranks/rank-*/dataloader-metrics.json
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/ranks/rank-*/dataloader-stdout.txt
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/canonical/ranks/rank-*/dataloader-stderr.txt
```

Wrapper, metadata, parsed, and index files:

```text
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/wrapper/slurm-<job_id>.out
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/wrapper/slurm-<job_id>.err
results/by-date/<date>/raw/<cluster>/<scope-path>/dataloader/<run_id>/metadata/record.json
results/by-date/<date>/parsed/<cluster>/<scope-path>/dataloader/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/<scope-path>/dataloader/<run_id>/status.json
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
```
