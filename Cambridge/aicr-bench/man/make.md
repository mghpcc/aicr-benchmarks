# make

## Purpose

Provide the curated AICR-Bench campaign driver. Make targets compose lower-level
script primitives into repeatable dry-runs, Slurm submissions, dashboard
rendering, and repo-standard artifact layouts.

Use Make when you want the repo's opinionated workflow. Use the script man pages
when you want the primitive interface behind a target. For a brief overview, see
[docs/modules/make-driver.md](../docs/modules/make-driver.md).

## Quick Start

Run these from the installed `aicr-bench` root:

```bash
cp benchmark-settings.env.example benchmark-settings.env
make setup-python-local
make doctor-python
make help
```

Most submission targets are dry-run first. Add `APPLY=1` only when you want to
submit Slurm jobs.

## Target Groups

### Setup And Validation

| Target | Purpose |
| --- | --- |
| `make help` | Print the public Make interface. |
| `make setup-python-local` | Build or refresh the local UV-managed Python environment. |
| `make doctor-python` | Validate the configured Python runtime and required packages. |
| `make docs-link-check` | Check public docs and man-page links. |
| `make docs-test` | Run executable documentation checks. |
| `make docs-test-plan` | Print selected executable documentation checks without running them. |
| `make install-gpu-smoke-suite` | Validate installed-tree GPU Topology, GDS, NCCL, and HPL-MxP surfaces. |

### Runtime Containers

| Target | Purpose |
| --- | --- |
| `make install-containers` | Submit the default container install as a Slurm job. |
| `make install-containers CONTAINER_NODELIST=<node>` | Install containers on a specific CPU node. |
| `make install-containers CONTAINER_REFRESH=1` | Rebuild or replace default images through the same Slurm path. |
| `make install-containers CONTAINER_WAIT=0` | Submit and return immediately. |
| `make install-containers-local` | Pull verified containers from the current host. |

### GDS

| Target | Purpose |
| --- | --- |
| `make verify-gds` | Dry-run or submit GDS validation jobs. |
| `make render-gds-ascii` | Print the GDS ASCII dashboard from existing results. |

Common GDS shapes:

```bash
make verify-gds CLUSTER=b200 PROFILE=small NODELIST=b0001
make verify-gds CLUSTER=b200 PROFILE=smoke NODELIST=<node> APPLY=1
make verify-gds CLUSTER=b200 PROFILE=custom NODELIST=b0001 AICR_GDS_CUSTOM_GDSIO_ARGS="-x 0 -I 0 -d 0 -w 1 -m 0 -s 1G -i 1M"
make render-gds-ascii CLUSTER=b200 DATE=today
```

### Install GPU Smoke Suite

The install smoke suite validates an installed tree rather than a development
checkout. It is dry-run first by default:

```bash
make install-gpu-smoke-suite INSTALL_SMOKE_RTX_NODES=a0002,a0003 INSTALL_SMOKE_B200_NODES=b0001,b0002
make install-gpu-smoke-suite INSTALL_SMOKE_RTX_NODES=a0002,a0003 INSTALL_SMOKE_B200_NODES=b0001,b0002 APPLY=1
make install-gpu-smoke-suite INSTALL_SMOKE_RTX_NODES=a0002,a0003 INSTALL_SMOKE_B200_NODES=b0001,b0002 INSTALL_SMOKE_HPL_MXP_APPLY_RTX=1 APPLY=1
```

In apply mode the suite runs one-node GPU Topology and GDS smoke jobs, narrowed
NCCL local `allreduce` smoke jobs, two-node NCCL RDMA `allreduce` smoke jobs
when two nodes are supplied, a one-node B200 HPL-MxP smoke row, one DataLoader
one-GPU smoke row per cluster, and one DDP `synthetic-gpu` one-node smoke row
per cluster. HPL-MxP uses `HPL_MXP_PRESET=smoke`, `HPL_MXP_MEM=0`, `FP16`,
`derived-nps4` affinity, and `HPL_MXP_TEST_LOOP=1`. RTX HPL-MxP apply is
opt-in through `INSTALL_SMOKE_HPL_MXP_APPLY_RTX=1`.

Elbencho install-smoke coverage is optional because the Elbencho container is
not built by default and the smoke job writes a scratch target. Build the image
first with `make install-elbencho APPLY=1` or
`make install-containers INSTALL_ELBENCHO_CONTAINER=1 APPLY=1`, then enable the
coverage with `INSTALL_SMOKE_INCLUDE_ELBENCHO=1`.

Useful variables:

- `INSTALL_SMOKE_RTX_NODES`: RTX node list. First node is used for one-node
  jobs; first two nodes are used for RDMA.
- `INSTALL_SMOKE_B200_NODES`: B200 node list. Same selection policy as RTX.
- `INSTALL_SMOKE_AUDIT_ROOT`: fixed evidence directory.
- `INSTALL_SMOKE_SKIP_RDMA=1`: skip NCCL RDMA.
- `INSTALL_SMOKE_SKIP_HPL_MXP=1`: skip HPL-MxP coverage.
- `INSTALL_SMOKE_SKIP_DATALOADER=1`: skip DataLoader coverage.
- `INSTALL_SMOKE_SKIP_DDP=1`: skip DDP coverage.
- `INSTALL_SMOKE_HPL_MXP_B200_NODE`: override the B200 HPL-MxP node.
- `INSTALL_SMOKE_HPL_MXP_RTX_NODE`: override the RTX HPL-MxP node.
- `INSTALL_SMOKE_HPL_MXP_APPLY_RTX=1`: enable RTX HPL-MxP apply.
- `INSTALL_SMOKE_HPL_MXP_TIME=00:10:00`: set the HPL-MxP time limit.
- `INSTALL_SMOKE_DATALOADER_TIME=00:10:00`: set the DataLoader time limit.
- `INSTALL_SMOKE_DDP_TIME=00:10:00`: set the DDP time limit.
- `INSTALL_SMOKE_INCLUDE_ELBENCHO=1`: enable optional Elbencho coverage.
- `INSTALL_SMOKE_ELBENCHO_B200_NODE`: override the B200 Elbencho node.
- `INSTALL_SMOKE_ELBENCHO_RTX_NODE`: override the RTX Elbencho node.
- `INSTALL_SMOKE_ELBENCHO_TARGET_ROOT`: set the scratch target root.
- `INSTALL_SMOKE_ELBENCHO_TIME=00:10:00`: set the Elbencho time limit.
- `INSTALL_SMOKE_SKIP_RTX=1` or `INSTALL_SMOKE_SKIP_B200=1`: limit cluster coverage.
- `INSTALL_SMOKE_SKIP_LOCAL_CHECKS=1`: skip docs/help/syntax checks.
- `INSTALL_SMOKE_SKIP_EXPLICIT_SBATCH=1`: skip explicit `sbatch --test-only`.
- `INSTALL_SMOKE_NO_RENDER=1`: skip final report rendering.
- `INSTALL_SMOKE_RENDER_ONLY=1`: render reports from existing evidence without
  repeating dry-runs or submitting jobs.

### NCCL

| Target | Purpose |
| --- | --- |
| `make verify-nccl-suite` | Dry-run or submit NCCL local, RDMA, or scale jobs. |
| `make render-nccl-suite` | Print the NCCL suite Markdown dashboard from existing results. |

Common NCCL shapes:

```bash
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0002
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0002 NCCL_SUITE_CLASS=b200_1proc_8g APPLY=1
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=b200 PROFILE=small NODELIST=b0002 NCCL_SUITE_CLASS=b200_2rank_socket_4g APPLY=1
make verify-nccl-suite NCCL_SCOPE=local CLUSTER=rtxpro6000 PROFILE=small NODELIST=a0002 NCCL_SUITE_CLASS=rtx_pair_policy APPLY=1
make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER=b200 PROFILE=small NODELIST=b0002,b0003 NCCL_NODES_PER_JOB=2 APPLY=1
make verify-nccl-suite NCCL_SCOPE=scale CLUSTER=rtxpro6000 PROFILE=small NODELIST=a0002,a0003 NCCL_SCALES=1,2
make render-nccl-suite NCCL_SCOPE=rdma CLUSTER=b200 DATE=today
```

Campaign-scale NCCL replay is manual because it can run for hours:

```bash
make verify-nccl-suite NCCL_SCOPE=scale CLUSTER=b200 PROFILE=small NODELIST=<nodes> NCCL_SCALES=1,2,4,8,16 REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic APPLY=1
make verify-nccl-suite NCCL_SCOPE=scale CLUSTER=rtxpro6000 PROFILE=small NODELIST=<nodes> NCCL_SCALES=1,2,4 REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic APPLY=1
```

### DataLoader

| Target | Purpose |
| --- | --- |
| `make benchmark-dataloader` | Dry-run or submit PyTorch DataLoader sweeps. |
| `make prep-dataloader-derived-dataset` | Dry-run or submit CPU-queue derived dataset prep. |
| `make render-dataloader` | Print the DataLoader Markdown report from existing results. |
| `make render-dataloader-input-lab` | Render experimental input-pipeline lab tables and plots. |

Common DataLoader shapes:

```bash
make benchmark-dataloader CLUSTER=rtxpro6000 GPU_COUNT=1 MODE=single NODELIST=a0001 DATALOADER_NUM_WORKERS=8 DATALOADER_RUN_ARGS="--warmup-batches 100 --measured-batches 500 --byte-estimate-sample-count 0"
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=8 MODE=replicated NODELIST=b0001 DATALOADER_BATCH_SIZES=512,768 DATALOADER_NUM_WORKERS=16 DATALOADER_PREFETCH_FACTORS=4
make benchmark-dataloader CLUSTER=rtxpro6000 GPU_COUNT=8 MODE=distributed-sharded DATALOADER_NODES=2 NODELIST=a0001,a0002 DATALOADER_BATCH_SIZES=640 DATALOADER_NUM_WORKERS=16 DATALOADER_PREFETCH_FACTORS=4 APPLY=1
make benchmark-dataloader CLUSTER=b200 GPU_COUNT=1 MODE=single NODELIST=b0001 DATALOADER_INPUT_BACKENDS=pytorch-cpu-dataloader,dali-gpu-decode DATALOADER_BATCH_SIZES=256 DATALOADER_NUM_WORKERS=8
make prep-dataloader-derived-dataset DATALOADER_PREP_DERIVED_ROOT=$PWD/scratch/derived-datasets/dataloader-lab/example
make prep-dataloader-derived-dataset DATALOADER_PREP_DERIVED_ROOT=$PWD/scratch/derived-datasets/dataloader-lab/example APPLY=1
make prep-dataloader-derived-dataset DATALOADER_PREP_DERIVED_ROOT=$PWD/scratch/derived-datasets/dataloader-lab/example APPLY=1 DATALOADER_PREP_WRITE=1
make render-dataloader CLUSTER=rtxpro6000 DATE=today
make render-dataloader-input-lab CLUSTER=b200 DATE=today
```

### DDP ResNet-50

| Target | Purpose |
| --- | --- |
| `make benchmark-ddp-resnet50` | Dry-run or submit fixed-iteration DDP ResNet-50 jobs. |
| `make render-ddp-resnet50` | Print the DDP Markdown summary from existing results. |
| `make render-ddp-resnet50-ascii` | Print the DDP ASCII dashboard from existing results. |

Common DDP shapes:

```bash
make benchmark-ddp-resnet50 CLUSTER=b200 NODES=1 NODELIST=b0001 DDP_RUN_ARGS="--warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0"
make benchmark-ddp-resnet50 CLUSTER=rtxpro6000 NODES=2 NODELIST=a0001,a0002 LAUNCHER=torchrun
make benchmark-ddp-resnet50 CLUSTER=b200 NODES=1 NODELIST=b0001 LAUNCHER=srun DDP_RUN_ARGS="--warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 0 --persistent-workers 0"
make render-ddp-resnet50 CLUSTER=b200 DATE=today
make render-ddp-resnet50-ascii CLUSTER=b200 DATE=today
```

### HPL-MxP

| Target | Purpose |
| --- | --- |
| `make benchmark-hpl-mxp` | Dry-run or submit NVIDIA HPL-MxP rows. |
| `make benchmark-hpl-mxp-smoke` | Convenience target for the small smoke preset. |
| `make render-hpl-mxp` | Render the HPL-MxP report from existing results. |

Common HPL-MxP shapes:

```bash
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=b0001 HPL_MXP_PRESET=smoke
make benchmark-hpl-mxp CLUSTER=b200 NODES=4 NODELIST=b0001,b0002,b0003,b0004 HPL_MXP_PRESET=weak-study HPL_MXP_REPEAT_COUNT=3
make benchmark-hpl-mxp CLUSTER=b200 NODES=1 NODELIST=b0001 HPL_MXP_PRESET=weak-study HPL_MXP_SLOPPY_TYPE=FP8
make benchmark-hpl-mxp CLUSTER=b200 NODES=4 NODELIST=b0001,b0002,b0003,b0004 HPL_MXP_PRESET=staged
make render-hpl-mxp CLUSTER=b200 DATE=today REPEAT_AGGREGATION=standard
```

## Common Variables

| Variable | Meaning |
| --- | --- |
| `CLUSTER` | `b200` or `rtxpro6000`. Default: `b200`. |
| `PROFILE` | Module profile such as `small`, `medium`, `large`, or `custom`. Default: `small`. |
| `NODELIST` | Explicit node or comma-separated node list. |
| `DATE` | Report date, `today` or `YYYY-MM-DD`. |
| `APPLY` | `0` previews; `1` submits Slurm jobs. Default: `0`. |
| `REPEAT_COUNT` | Repeat rounds for modules that support repeated submissions. Default: `1`. |
| `REPEAT_AGGREGATION` | `standard` or `olympic`. Default: `standard`. |
| `ROUND_STAGGER_SECONDS` | Delay between repeat rounds. Default: `60`. |

Applied examples should use explicit `NODELIST` plus `APPLY=1`.

## Module Variables

### GDS Variables

| Variable | Meaning |
| --- | --- |
| `GDS_SUBMIT_STAGGER_SECONDS` | Delay between GDS fleet submissions. Default: `15`. Use `benchmark` for dependency-chain submission with one selected GDS job running at a time. |
| `AICR_GDS_CUSTOM_GDSIO_ARGS` | Custom `gdsio` argument string for `PROFILE=custom`. |

### NCCL Variables

| Variable | Meaning |
| --- | --- |
| `NCCL_SCOPE` | `local`, `rdma`, or `scale`. Default: `scale`. |
| `NCCL_SUITE_OPS` | Optional comma-separated NCCL operation filter, such as `allreduce`. |
| `NCCL_SUITE_CLASS` | Optional local-mode class filter, such as `b200_8rank_1g`, `b200_1proc_8g`, `b200_2rank_socket_4g`, `rtx_8rank_1g`, or `rtx_pair_policy`. |
| `NCCL_NODES_PER_JOB` | RDMA group size, or one scale for `NCCL_SCOPE=scale`. B200 RDMA supports `2`, `4`, `8`, `16`; RTX RDMA supports `2`, `4`, `8`. |
| `NCCL_SCALES` | Scale node counts. B200 default: `1,2,4,8,16`; RTX default: `1,2,4`. |
| `NCCL_SUBMIT_STAGGER_SECONDS` | Delay between NCCL suite submissions. Default: `5`. |
| `NCCL_SCALE_STAGGER_SECONDS` | Delay after one scale finishes before the next starts. Default: `0`. |
| `GPU_PREFLIGHT_FILTER` | `1` keeps only nodes with passing same-day GPU Topology evidence before submitter grouping. |
| `NCCL_DEBUG`, `NCCL_DEBUG_SUBSYS`, `NCCL_DEBUG_FILE` | Optional NCCL debug controls. |

### DataLoader Variables

| Variable | Meaning |
| --- | --- |
| `GPU_COUNT` | DataLoader GPU count, normally `1` or `8`. |
| `MODE` | `single`, `replicated`, or `distributed-sharded`. |
| `DATALOADER_NODES` | Node-count list for DataLoader sweeps. Default: `1`. |
| `DATALOADER_PROFILE` | Optional workload-intensity profile. Non-default `PROFILE=medium|large` also selects a DataLoader profile. |
| `DATALOADER_INPUT_BACKENDS` | Comma-separated backend list: `pytorch-cpu-dataloader`, `dali-gpu-decode`, `numpy-uint8-shards`, `numpy-fp16-shards`, `dali-numpy-fp16-cpu`, or `dali-numpy-fp16-gds`. |
| `DATALOADER_BATCH_SIZES` | Comma-separated batch-size list. |
| `DATALOADER_NUM_WORKERS` | Comma-separated worker-count list. |
| `DATALOADER_PREFETCH_FACTORS` | Comma-separated prefetch-factor list. |
| `DATALOADER_DALI_NUM_THREADS` | Comma-separated DALI thread counts. |
| `DATALOADER_DALI_PREFETCH_QUEUE_DEPTHS` | Comma-separated DALI prefetch queue depths. |
| `DATALOADER_DALI_DECODE_MODES` | Comma-separated DALI decode modes. |
| `DATALOADER_DALI_HW_DECODER_LOADS` | Comma-separated DALI hardware decoder load values. |
| `DATALOADER_DALI_GDS_CHUNK_SIZE` | Optional `--dali-gds-chunk-size` forwarded to DataLoader runs. |
| `DATALOADER_PIN_MEMORY` | `1` or `0`. |
| `DATALOADER_PERSISTENT_WORKERS` | `1` or `0`. |
| `DATALOADER_CPUS_PER_TASK` | CPU cores requested per task. Default: `16`. |
| `DATALOADER_MEM` | Slurm memory request for DataLoader jobs. Default: `0`. |
| `DATALOADER_REPEAT_COUNT` | Repeat count for DataLoader sweeps. |
| `DATALOADER_REPEAT_AGGREGATION` | Repeat aggregation used by the renderer. |
| `DATALOADER_RUN_ARGS` | Extra runner arguments forwarded after `--`. |
| `DATALOADER_PREP_PARTITION` | CPU Slurm partition for derived dataset prep. Default: `cpu`. |
| `DATALOADER_PREP_TIME` | Derived prep Slurm time limit. Default: `04:00:00`. |
| `DATALOADER_PREP_CPUS_PER_TASK` | Derived prep CPU request. Default: `16`. |
| `DATALOADER_PREP_MEM` | Derived prep memory request. Default: `0`. |
| `DATALOADER_PREP_NODELIST` | Optional CPU node for derived prep. |
| `DATALOADER_PREP_DATASET_ROOT` | Optional ImageFolder root override. Defaults to `AICR_IMAGENET_DIR`. |
| `DATALOADER_PREP_DERIVED_ROOT` | Derived dataset output root. Defaults to `AICR_DATALOADER_DERIVED_ROOT`. |
| `DATALOADER_PREP_SPLIT` | Dataset split. Default: `train`. |
| `DATALOADER_PREP_SAMPLES_PER_CLASS` | Bounded samples per class. Default: `16`. |
| `DATALOADER_PREP_SEED` | Deterministic sample seed. Default: `1234`. |
| `DATALOADER_PREP_IMAGE_SIZE_LIST` | Derived image sizes. Default: `224,384,512`. |
| `DATALOADER_PREP_FORMATS` | Derived formats. Default: `jpeg,numpy-uint8,numpy-fp16`; add `numpy-fp16-files` for DALI NumPy GDS experiments. |
| `DATALOADER_PREP_JPEG_QUALITY` | JPEG quality for derived JPEG formats. Default: `95`. |
| `DATALOADER_PREP_WRITE` | `1` writes outputs inside the CPU Slurm job. Default: `0`. |
| `DATALOADER_PREP_OVERWRITE` | `1` replaces existing derived dataset directories. Default: `0`. |

### DDP Variables

| Variable | Meaning |
| --- | --- |
| `DDP_NODES` | DDP node count. B200 supports `1`, `2`, `4`, `8`, `16`; RTX supports `1`, `2`, `4`, `8`. |
| `DDP_LAUNCHER` | `torchrun` or `srun`. Default: `torchrun`. |
| `DDP_CPUS_PER_TASK` | Optional Slurm CPU count per task override. |
| `DDP_MEM` | Slurm memory request for DDP jobs. Default: `0`. |
| `DDP_RUN_ARGS` | Extra runner arguments forwarded after `--`. |

### HPL-MxP Variables

| Variable | Meaning |
| --- | --- |
| `HPL_MXP_PRESET` | `smoke`, `staged`, `campaign-candidate`, or `weak-study`. Default: `smoke`. |
| `HPL_MXP_MATRIX_SIZE` | Matrix size `N`, or `auto` for reviewed defaults. |
| `HPL_MXP_NB` | Block size `NB`, or `auto` for reviewed defaults. |
| `HPL_MXP_NPROW`, `HPL_MXP_NPCOL` | Processor grid override, or `auto`. |
| `HPL_MXP_TIME` | Slurm time limit. Default: `00:30:00`. |
| `HPL_MXP_MEM` | Slurm memory request. Default: `0` for full-node HPL-MxP rows. |
| `HPL_MXP_IMAGE` | Optional NVIDIA HPC Benchmarks image override. |
| `HPL_MXP_SLOPPY_TYPE` | HPL-MxP sloppy type: `FP16`, `FP8`, or B200-only `FP4`. Default: `FP16`. |
| `HPL_MXP_TEST_LOOP` | Optional loop count forwarded to HPL-MxP. |
| `HPL_MXP_CPUS_PER_TASK` | Slurm CPU request per task. Default: `16`. |
| `HPL_MXP_REPEAT_COUNT` | Independent repeated rows for the same HPL-MxP shape. Default: `1`. |
| `HPL_MXP_REPEAT_STAGGER_SECONDS` | Delay between repeated submissions. Default: `30`. |
| `HPL_MXP_RENDER_JOB_ID_MIN`, `HPL_MXP_RENDER_JOB_ID_MAX`, `HPL_MXP_RENDER_JOB_ID_LIST` | Optional render filters for excluding unrelated same-day rows. |
| `HPL_MXP_AFFINITY_PROFILE` | `derived-nps4` by default for AICR GPU benchmark rows. |
| `HPL_MXP_OMPI_COLL` | Open MPI collective MCA setting. Default: `^ucc`. |
| `HPL_MXP_OMPI_PML`, `HPL_MXP_OMPI_BTL` | Optional Open MPI PML and BTL MCA settings. |
| `HPL_MXP_OMPI_BTL_TCP_IF_INCLUDE`, `HPL_MXP_OMPI_OOB_TCP_IF_INCLUDE` | Optional Open MPI TCP interface filters. |
| `HPL_MXP_UCX_TLS`, `HPL_MXP_UCX_NET_DEVICES` | Optional UCX transport and network-device filters. |
| `HPL_MXP_PMIX_MCA_GDS` | PMIx GDS MCA setting. Default: `^ds12`. |
| `HPL_MXP_MPI_USE_MPI` | HPL-MxP MPI-use-MPI flag. Default: `0`; `weak-study` sets `1`. |
| `HPL_MXP_MPI_PANEL_BROADCAST` | HPL-MxP panel-broadcast percentage. Default: `1`; `weak-study` sets `50`. |
| `HPL_MXP_PRIORITIZE_TRSM` | HPL-MxP TRSM priority flag. Default: `0`. |
| `HPL_MXP_PRIORITIZE_FACTORIZATION` | HPL-MxP factorization priority flag. Default: `0`; `weak-study` sets `1`. |
| `HPL_MXP_ANQ_DEVICE` | Optional FP64 matrix column placement override. |
| `HPL_MXP_FILL_DEVICE` | Optional fill-device toggle. |
| `HPL_MXP_FILL_DEVICE_BUFFER_SIZE` | Optional fill-device buffer reserve in MB. |
| `HPL_MXP_CALL_DGEMV_THREADS` | Optional DGEMV thread override. |
| `HPL_MXP_PRESET_GEMM_KERNEL` | Optional GEMM kernel preset. |
| `HPL_MXP_CPU_AFFINITY`, `HPL_MXP_MEM_AFFINITY`, `HPL_MXP_UCX_AFFINITY` | Explicit affinity maps. |
| `HPL_MXP_U_PANEL_CHUNK_NBS` | HPL-MxP U-panel chunk size. |
| `HPL_MXP_SCALING_STUDY` | `exploratory`, `strong`, or `weak`. `weak-study` resolves to `weak`. |
| `HPL_MXP_BASELINE_MATRIX_SIZE` | Optional baseline matrix size recorded in summary metadata. |

### Documentation And Container Variables

| Variable | Meaning |
| --- | --- |
| `DOCS_SUITE` | Documentation test suite, such as `all`, `gds`, `nccl`, `dataloader`, `ddp`, or `hpl-mxp`. |
| `DOCS_APPLY` | `1` allows gated applied Slurm documentation checks. |
| `DOCS_TEST_ID` | Run or plan one selected documentation test ID. |
| `CONTAINER_PARTITION` | Slurm partition for container install jobs. Default: `cpu`. |
| `CONTAINER_NODELIST` | Optional node for container install jobs. |
| `CONTAINER_MEM` | Slurm memory request for container install jobs. Default: `0`. |
| `CONTAINER_REFRESH` | `1` refreshes/replaces images. |
| `CONTAINER_WAIT` | `1` waits for completion; `0` returns after submission. |
| `RUNTIME_MEM` | Slurm memory request for runtime rebuild jobs. Default: `0`. |
| `PYTHON_DOCTOR_MEM` | Slurm memory request for compute-node Python doctor jobs. Default: `0`. |

## Outputs

- Submission targets write Slurm captures and parsed summaries under the
  standard runtime result tree.
- Render targets read existing results and print Markdown or ASCII summaries.
- HPL-MxP render targets write Markdown, CSV, and SVG report artifacts under
  `results/reports/<date>/hpl-mxp/`.
- Public studies link curated bundles and reports rather than raw generated run
  trees.

## Safety Notes

- `benchmark-settings.env` is required before Slurm submission targets run.
- Omit `APPLY=1` for previews.
- Use explicit `NODELIST` for applied examples and study reproduction.
- HPL-MxP is compute- and memory-intensive; start with `HPL_MXP_PRESET=smoke`
  on explicit nodes before running larger shapes.
