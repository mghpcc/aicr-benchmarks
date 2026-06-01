# DataLoader Script Interface

Purpose: document DataLoader primitives for custom benchmark workflows.

The DataLoader script layer is dry-run-first. Use it for one-off jobs, matrix
sweeps, input-backend comparisons, and report replays outside the curated Make
target.

## Dataset Contract

DataLoader expects `AICR_IMAGENET_DIR` to point at an ImageNet-style dataset
root with `train` or `val` splits. See
[ImageNet dataset preparation](../../resources/imagenet.md) for acquisition,
validation split preparation, and layout checks.
Derived JPEG, NumPy shard, and DALI NumPy file inputs are documented in
[Derived ImageNet Datasets](derived-datasets.md).

## Modes

| Mode | Use |
| --- | --- |
| `single` | One GPU on one node. |
| `replicated` | Eight GPUs on one node, each rank sees the same dataset view. |
| `distributed-sharded` | Eight GPUs per node with distributed sharding across one or more nodes. |

## Inspect The Interface

Allocation-side runner:

<!-- aicr-test
id: dataloader-run-help
suite: dataloader
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--input-backend"
    - "--inspect-profile"
-->
```bash
scripts/benchmark/run-dataloader.sh --help
```

Host-side one-job Slurm submitter:

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
    - "--profile"
-->
```bash
scripts/benchmark/submit-dataloader.sh --help
```

Host-side matrix sweep submitter:

<!-- aicr-test
id: dataloader-sweep-help
suite: dataloader
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--input-backend-list"
    - "--dali-num-threads-list"
    - "--profile"
-->
```bash
scripts/benchmark/sweep-dataloader.sh --help
```

Low-level workload engine:

<!-- aicr-test
id: dataloader-workload-help
suite: dataloader
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--input-backend"
    - "--output-dir"
    - "--dali-numpy-reader-prefetch-queue-depth"
    - "--cufile-log-level"
    - "--numpy-block-cache-size"
-->
```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh scripts/benchmark/run-dataloader-workload.py --help
```

## Command Roles

| Script | Role |
| --- | --- |
| [run-dataloader.sh](../../../man/run-dataloader.md) | Allocation-side runner called by Slurm templates. |
| [submit-dataloader.sh](../../../man/submit-dataloader.md) | Host-side dry-run-first submitter for one DataLoader job. |
| [sweep-dataloader.sh](../../../man/sweep-dataloader.md) | Host-side matrix sweep submitter for module studies and Make targets. |
| [submit-dataloader-derived-dataset.sh](../../../man/submit-dataloader-derived-dataset.md) | CPU-queue submitter for derived dataset planning and writes. |
| [render-dataloader-report.py](../../../man/render-dataloader-report.md) | Standard DataLoader report renderer. |
| [render-dataloader-input-lab-report.py](../../../man/render-dataloader-input-lab-report.md) | Input Pipeline Lab renderer for representation/backend evidence. |
| [render-dataloader-dali-standard-imagenet-report.py](../../../man/render-dataloader-dali-standard-imagenet-report.md) | Standard ImageNet DALI optimization study renderer. |

## Profiles

Profiles set workload-intensity defaults. Explicit runner or sweep arguments
override profile defaults.

| Profile | Batch size | Workers | Prefetch | Warmup batches | Measured batches |
| --- | ---: | ---: | ---: | ---: | ---: |
| `small` | 512 | 16 | 4 | 20 | 100 |
| `medium` | 512 | 16 | 4 | 100 | 500 |
| `large` | 512 | 16 | 4 | 200 | 5000 |

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

## Input Backends

The default benchmark path is `pytorch-cpu-dataloader`. The input-pipeline lab
also exposes `dali-gpu-decode`, `numpy-uint8-shards`, `numpy-fp16-shards`,
`numpy-fp16-blocks-pytorch`, `dali-numpy-fp16-cpu`, `dali-numpy-fp16-gds`,
`dali-numpy-fp16-blocks-cpu`, and `dali-numpy-fp16-blocks-gds`. NumPy shard
and block backends plus DALI NumPy backends require a derived dataset root. The
portable default lives under `$AICR_BMARK_DIR/scratch`; on AICR HPC, prefer
`/scratch/$USER` for regenerated datasets unless long-term storage is required.
Canonical ImageNet may remain on `/work`.
The DDP module also has a `synthetic-gpu` input backend. That backend is
DDP-only and is not part of the DataLoader script surface.

## Input-Pipeline Controls

DALI JPEG rows use the standard sweep controls for thread count, queue depth,
decode mode, and hardware decoder load. DALI NumPy rows use the thread and
queue-depth controls, while decode mode and hardware decoder load stay inert
because no JPEG decode is in that path. DALI NumPy GPU/O_DIRECT reader rows use
the GDS controls below.
GDS variants can also set
`--dali-gds-chunk-size`, which becomes `DALI_GDS_CHUNK_SIZE` before DALI builds
the pipeline, `--dali-numpy-reader-prefetch-queue-depth` for DALI NumPy reader
buffering, plus `--cufile-log-path` and `--cufile-log-level` to capture cuFile
logs. Non-DALI rows keep those fields at inert defaults in the recorded
metadata so same-size comparisons remain filterable.
`numpy-fp16-blocks-pytorch` reads the same blocked prepared-tensor layout through
PyTorch with mmap and a bounded per-worker block cache. Use
`--numpy-block-cache-size` when testing CPU-reader cache sensitivity.

DataLoader submissions default to `--mem=0` at the Slurm layer. This keeps rows
from inheriting a small per-CPU memory cgroup on systems where DataLoader worker
shared memory grows with batch size, worker count, prefetch depth, and derived
image size. Sweeps expose `--mem-list` for focused memory checks.

The runner raises the soft file-descriptor limit to
`DATALOADER_NOFILE_LIMIT`, default `65536`, before launching the workload. This
matters for per-sample DALI NumPy file rows because the CPU reader can hold
many `.npy` files open during pipeline construction. Rank-local metrics and
parsed summaries record the requested limit, effective soft and hard limits,
and a best-effort open file-descriptor count.

Derived dataset rows use `--derived-root`, `--derived-image-size`,
`--derived-samples-per-class`, and `--derived-seed` to select a prepared input
tree. NumPy shard and DALI NumPy file backends require a derived root.
Pre-resized JPEG rows also use the derived selectors when the ImageFolder tree
is a regenerated input representation. See
[Derived ImageNet Datasets](derived-datasets.md) for the dataset purpose,
storage policy, and dry-run/apply preparation commands.

Derived dataset planner:

<!-- aicr-test
id: dataloader-derived-help
suite: dataloader
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--formats"
    - "--numpy-block-size"
    - "--apply"
-->
```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh scripts/benchmark/prepare-dataloader-derived-dataset.py --help
```

CPU Slurm submitter for derived dataset prep:

<!-- aicr-test
id: dataloader-derived-submit-help
suite: dataloader
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--write"
    - "--partition"
    - "CPU Slurm"
-->
```bash
scripts/benchmark/submit-dataloader-derived-dataset.sh --help
```

Safe planner dry-run using the committed ImageFolder-shaped fixture:

<!-- aicr-test
id: dataloader-derived-dry-run
suite: dataloader
kind: local
safety: inspect
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Derived DataLoader dataset plan"
    - "Apply        : False"
    - "Dry run only"
-->
```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh scripts/benchmark/prepare-dataloader-derived-dataset.py --dataset-root tests/fixtures/dataloader/imagefolder-dry-run --derived-root /tmp/aicr-dataloader-derived-docs --samples-per-class 1 --image-size-list 224 --formats procedural-jpeg
```

Submit derived dataset prep through the CPU queue. Keep `--write` off until the
planner output and storage estimate are reviewed. The submitter accepts the
explicit derived root; on AICR HPC, prefer scratch-backed storage for
regenerated data.

## Renderers

Main DataLoader report renderer:

<!-- aicr-test
id: dataloader-render-help
suite: dataloader
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--repeat-aggregation"
    - "--include-smoke"
-->
```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh scripts/report/render-dataloader-report.py --help
```

Input-pipeline lab renderer:

<!-- aicr-test
id: dataloader-input-lab-render-help
suite: dataloader
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--baseline-samples-per-second"
    - "--input-backends"
-->
```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh scripts/report/render-dataloader-input-lab-report.py --help
```

Standard ImageNet DALI optimization renderer:

<!-- aicr-test
id: dataloader-dali-standard-imagenet-render-help
suite: dataloader
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "standard ImageNet"
    - "--include-smoke"
-->
```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh scripts/report/render-dataloader-dali-standard-imagenet-report.py --help
```

## Fixture Checks

The DataLoader fixtures validate renderer and shared-backend behavior without
live Slurm results.

<!-- aicr-test
id: dataloader-input-backends-fixture
suite: dataloader
kind: local
safety: inspect
cwd: install-root
expect:
  mode: contains
  patterns:
    - "backend_contract=passed"
    - "numpy_formats=numpy-uint8,numpy-fp16"
    - "dali_numpy_formats=numpy-fp16-files,numpy-fp16-blocks"
-->
```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh tests/scripts/check-dataloader-input-backends.py
```

<!-- aicr-test
id: dataloader-input-lab-report-fixture
suite: dataloader
kind: local
safety: inspect
cwd: install-root
expect:
  mode: contains
  patterns:
    - "fixture=dataloader-input-lab-report-shape"
    - "input_lab_report_shape=passed"
    - "aggregate_row_count=5"
-->
```bash
AICR_ALLOW_SYSTEM_PYTHON=0 bash scripts/lib/run-repo-python.sh tests/scripts/check-dataloader-input-lab-report-fixture.py
```

## Direct Use

Use [submit-dataloader.sh](../../../man/submit-dataloader.md) for one job and
[sweep-dataloader.sh](../../../man/sweep-dataloader.md) for parameter matrices.
Use [submit-dataloader-derived-dataset.sh](../../../man/submit-dataloader-derived-dataset.md)
for CPU-queue derived dataset prep.
Use [run-dataloader.sh](../../../man/run-dataloader.md) only inside an existing
allocation. The Python workload engine is documented for troubleshooting in
[run-dataloader-workload.py](../../../man/run-dataloader-workload.md).

## Artifacts

Direct DataLoader runner, one-job submitter, and matrix sweep runs write node
or multi-node raw captures, parsed summaries, and index records. Rendered
reports are renderer or Make outputs.

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

Input Pipeline Lab rendered report files:

```text
results/reports/<date>/dataloader-input-lab/dataloader-input-lab-<cluster>-<date>.md
results/reports/<date>/dataloader-input-lab/dataloader-input-lab-summary-<cluster>-<date>.csv
results/reports/<date>/dataloader-input-lab/dataloader-input-lab-summary-<cluster>-<date>.json
results/reports/<date>/dataloader-input-lab/dataloader-input-lab-aggregate-<cluster>-<date>.csv
results/reports/<date>/dataloader-input-lab/dataloader-input-lab-aggregate-<cluster>-<date>.json
results/reports/<date>/dataloader-input-lab/dataloader-input-lab-throughput-<cluster>-<date>.png
results/reports/<date>/dataloader-input-lab/dataloader-input-lab-image-size-<cluster>-<date>.png
results/reports/<date>/dataloader-input-lab/dataloader-input-lab-speedup-original-<cluster>-<date>.png
results/reports/<date>/dataloader-input-lab/dataloader-input-lab-speedup-same-size-<cluster>-<date>.png
```

Standard ImageNet DALI optimization rendered report files:

```text
results/reports/<date>/dataloader-dali-standard-imagenet/dataloader-dali-standard-imagenet-<cluster>-<date>.md
results/reports/<date>/dataloader-dali-standard-imagenet/dataloader-dali-standard-imagenet-<cluster>-<date>-summary.csv
results/reports/<date>/dataloader-dali-standard-imagenet/dataloader-dali-standard-imagenet-<cluster>-<date>-summary.json
results/reports/<date>/dataloader-dali-standard-imagenet/dataloader-dali-standard-imagenet-<cluster>-<date>-aggregate.csv
results/reports/<date>/dataloader-dali-standard-imagenet/dataloader-dali-standard-imagenet-<cluster>-<date>-aggregate.json
results/reports/<date>/dataloader-dali-standard-imagenet/dataloader-dali-standard-imagenet-<cluster>-<date>-dali-tuning.png
results/reports/<date>/dataloader-dali-standard-imagenet/dataloader-dali-standard-imagenet-<cluster>-<date>-top-configs.png
```
