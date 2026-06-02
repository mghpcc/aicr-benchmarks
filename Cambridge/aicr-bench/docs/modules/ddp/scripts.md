# DDP Script Interface

Purpose: document DDP benchmark primitives for custom Slurm workflows.

DDP exposes a one-job Slurm submitter, a launcher-comparison submitter, and an
allocation-side runner. The shell runner and submitters are the supported
entrypoints; the workload engine is available for direct help and renderer
coverage checks.

## Dataset Contract

DDP expects `AICR_IMAGENET_DIR` to point at an ImageNet-style dataset root with
`train` or `val` splits. See
[ImageNet dataset preparation](../../resources/imagenet.md) for acquisition,
validation split preparation, and layout checks.
When both are set, the runner's `--dataset-root` argument overrides
`AICR_IMAGENET_DIR`.

## Inspect The Interface

Allocation-side runner:

<!-- aicr-test
id: ddp-runner-help
suite: ddp
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--launcher"
    - "--input-backend"
    - "numpy-fp16-blocks-pytorch"
    - "dali-numpy-fp16-blocks-gds"
    - "--cufile-log-path"
-->
```bash
AICR_CLUSTER_NAME=b200 scripts/benchmark/run-ddp-resnet50.sh --help
```

Host-side one-job Slurm submitter:

<!-- aicr-test
id: ddp-submit-help
suite: ddp
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--launcher"
    - "--repeat-count"
-->
```bash
scripts/benchmark/submit-ddp-resnet50.sh --help
```

Host-side launcher-comparison submitter:

<!-- aicr-test
id: ddp-launcher-comparison-help
suite: ddp
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--scales"
    - "--srun-cpu-bind"
-->
```bash
scripts/benchmark/submit-ddp-launcher-comparison.sh --help
```

Low-level workload engine:

<!-- aicr-test
id: ddp-workload-help
suite: ddp
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--input-backend"
    - "--prepared-block-label-source"
    - "--dali-numpy-reader-prefetch-queue-depth"
    - "--cufile-log-level"
-->
```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh scripts/benchmark/run-ddp-resnet50-workload.py --help
```

Report renderer:

<!-- aicr-test
id: ddp-render-help
suite: ddp
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--date"
    - "--include-short-runs"
    - "--ascii"
-->
```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh scripts/report/render-ddp-resnet50-report.py --help
```

## Direct Use

Use [submit-ddp-resnet50.sh](../../../man/submit-ddp-resnet50.md) for one
Slurm job shape and
[submit-ddp-launcher-comparison.sh](../../../man/submit-ddp-launcher-comparison.md)
for paired `torchrun` and `srun` launcher studies. Use
[run-ddp-resnet50.sh](../../../man/run-ddp-resnet50.md) inside an existing
allocation. Arguments after `--` in the submitters are forwarded to
[run-ddp-resnet50.sh](../../../man/run-ddp-resnet50.md).

[run-ddp-resnet50-workload.py](../../../man/run-ddp-resnet50-workload.md) is
called by the shell runner. When checking its help directly, run it through
`scripts/lib/run-repo-python.sh` so the UV-managed repo environment is used.

## Launcher Controls

The standard benchmark path uses `torchrun`. The `srun` path is available for
launcher comparison studies and accepts `DDP_SRUN_MPI`, `DDP_SRUN_CPU_BIND`, and
`DDP_SRUN_MEM_BIND` through the submitter or environment.

## Input Backends

The standard benchmark path uses `pytorch-cpu-dataloader`. Alternate input
backends belong in clearly labeled input-pipeline studies:

| Backend | Public role |
| --- | --- |
| `pytorch-cpu-dataloader` | Standard real-input benchmark path for canonical ImageNet. |
| `dali-gpu-decode` | Study path for DALI GPU decode and large-JPEG training candidates. |
| `numpy-uint8-shards` | Prepared-input ceiling path with JPEG decode moved offline. |
| `numpy-fp16-shards` | Prepared-input ceiling path with more preprocessing fixed into stored tensors. |
| `numpy-fp16-blocks-pytorch` | Prepared-block comparator path using PyTorch CPU mmap plus GPU transfer. |
| `dali-numpy-fp16-blocks-gds` | Prepared-block transport path using DALI NumPy GPU/cuFile reads with `use_o_direct=True`; distinct from DALI JPEG/GDS. |
| `synthetic-gpu` | DDP-only compute/input-free ceiling. |

DALI rows expose the same main tuning controls as the DataLoader module:
thread count, queue depth, decode mode, and hardware decoder load. Synthetic GPU
rows expose image size and dtype so ceiling rows can be matched to the
DataLoader candidates they are meant to contextualize.

For derived JPEG input studies, pass the derived ImageFolder root as
`--dataset-root` and keep the derived metadata arguments aligned in the command
and provenance. NumPy shard backends resolve their concrete shard path from
`--derived-root`, `--derived-image-size`, `--derived-samples-per-class`, and
`--derived-seed`.

Prepared-block DDP rows use `numpy-fp16-blocks` from the derived dataset tree.
The DALI path is a DALI NumPy GPU/cuFile path and records
`prepared_block_label_source` when synthetic GPU labels are used. It is
prepared-tensor transport evidence and is distinct from canonical ImageNet JPEG
evidence and DALI `readers.file` GDS evidence.

## Slurm Memory

Full-node DDP submissions default to `--mem=0` so Slurm grants the job the node
memory cgroup. Use an explicit `--mem <size>` for memory-specific or site
policy experiments.

## Artifacts

Direct DDP runner, one-job submitter, and launcher-comparison runs write
multi-node raw captures, parsed summaries, and index records. Rendered reports
are renderer or Make outputs.

Raw run directory:

```text
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/
```

Canonical files:

```text
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ddp-resnet50-summary.txt
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ddp-resnet50-env.txt
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ddp-resnet50-command.sh
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ddp-resnet50-stdout.txt
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ddp-resnet50-stderr.txt
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/nvidia-smi-L.txt
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/rank-metrics.tsv
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ranks/rank-*/ddp-resnet50-metrics.json
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/canonical/ranks/rank-*/cufile.log
```

Wrapper, metadata, parsed, and index files:

```text
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/wrapper/slurm-<job_id>.out
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/wrapper/slurm-<job_id>.err
results/by-date/<date>/raw/<cluster>/multi-node/ddp-resnet50/<run_id>/metadata/record.json
results/by-date/<date>/parsed/<cluster>/multi-node/ddp-resnet50/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/multi-node/ddp-resnet50/<run_id>/status.json
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
```
