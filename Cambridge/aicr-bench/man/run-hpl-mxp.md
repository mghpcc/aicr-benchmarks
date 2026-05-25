# run-hpl-mxp.sh

## Purpose

Run one guarded HPL-MxP row inside a Slurm allocation and write canonical
AICR-Bench artifacts.

Most users call this through
[submit-hpl-mxp.sh](submit-hpl-mxp.md) or `make benchmark-hpl-mxp`; direct use
is for debugging an existing allocation.

## Usage

```bash
scripts/benchmark/run-hpl-mxp.sh \
  --cluster <b200|rtxpro6000> \
  --nodes <count> \
  --preset <smoke|staged|campaign-candidate|weak-study> \
  --matrix-size <N> \
  --nb <NB> \
  --nprow <auto|rows> \
  --npcol <auto|cols> \
  [--image <path>] \
  [--sloppy-type <precision>] \
  [--test-loop <n>] \
  [--ompi-coll <value|none>] \
  [--ompi-pml <value|none>] \
  [--ompi-btl <value|none>] \
  [--ompi-btl-tcp-if-include <value|none>] \
  [--ompi-oob-tcp-if-include <value|none>] \
  [--ucx-tls <value|none>] \
  [--ucx-net-devices <value|none>] \
  [--pmix-mca-gds <value|none>] \
  [--mpi-use-mpi <0|1>] \
  [--use-mpi-panel-broadcast <0-100>] \
  [--prioritize-trsm <0|1>] \
  [--prioritize-factorization <0|1>] \
  [--anq-device <columns>] \
  [--fill-device <0|1>] \
  [--fill-device-buffer-size <MB>] \
  [--call-dgemv-with-multiple-threads <threads>] \
  [--preset-gemm-kernel <n>] \
  [--cpu-affinity <map>] \
  [--mem-affinity <map>] \
  [--ucx-affinity <map>] \
  [--u-panel-chunk-nbs <N>] \
  [--scaling-study <exploratory|strong|weak>]
```

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--nodes <n>`: Allocated node count.
- `--preset <name>`: `smoke`, `staged`, `campaign-candidate`, or `weak-study`.
- `--matrix-size <n>`: HPL-MxP matrix size `N`.
- `--nb <n>`: HPL-MxP block size `NB`.
- `--nprow <auto|n>`: Process-grid rows.
- `--npcol <auto|n>`: Process-grid columns.
- `--image <path>`: NVIDIA HPC Benchmarks Apptainer image.
- `--sloppy-type <FP4|FP8|FP16>`: HPL-MxP sloppy type. Default: `FP16`;
  `FP4` is B200-only in the public wrapper.
- `--test-loop <n>`: HPL-MxP loop count.
- `--ompi-coll <value|none>`: Open MPI collective setting.
- `--ompi-pml <value|none>`: Open MPI PML setting.
- `--ompi-btl <value|none>`: Open MPI BTL setting.
- `--ompi-btl-tcp-if-include <value|none>`: Open MPI BTL TCP interface filter.
- `--ompi-oob-tcp-if-include <value|none>`: Open MPI OOB TCP interface filter.
- `--ucx-tls <value|none>`: UCX transport filter.
- `--ucx-net-devices <value|none>`: UCX network-device filter.
- `--pmix-mca-gds <value|none>`: PMIx GDS setting.
- `--mpi-use-mpi <0|1>`: HPL-MxP MPI-use-MPI flag.
- `--use-mpi-panel-broadcast <0-100>`: MPI panel broadcast percentage.
- `--prioritize-trsm <0|1>`: TRSM prioritization flag.
- `--prioritize-factorization <0|1>`: Factorization prioritization flag.
- `--anq-device <columns>`: FP64 matrix column placement override.
- `--fill-device <0|1>`: HPL-MxP fill-device toggle.
- `--fill-device-buffer-size <MB>`: Fill-device buffer reserve.
- `--call-dgemv-with-multiple-threads <threads>`: DGEMV thread override.
- `--preset-gemm-kernel <n>`: GEMM kernel preset.
- `--cpu-affinity <map>`: CPU affinity map.
- `--mem-affinity <map>`: Memory affinity map.
- `--ucx-affinity <map>`: UCX affinity map.
- `--u-panel-chunk-nbs <n>`: U-panel chunk block count.
- `--scaling-study <name>`: `exploratory`, `strong`, or `weak`.
- `--baseline-matrix-size <n>`: Baseline matrix size for scaling metadata.
- `--help`: Print help.

## Outputs

```text
results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/
results/by-date/<date>/parsed/<cluster>/multi-node/hpl-mxp/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/multi-node/hpl-mxp/<run_id>/status.json
```

Canonical artifacts include the resolved HPL-MxP command, stdout, stderr,
preflight/postflight GPU captures, parsed `summary.json`, `status.json`, and
`record.json`, plus a by-date index row for report discovery.

## Runtime

The runner uses `${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif` unless
an image override is supplied. It launches one MPI rank per GPU through Slurm
and records the processor grid used for the run.
