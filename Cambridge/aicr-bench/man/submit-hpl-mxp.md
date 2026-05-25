# submit-hpl-mxp.sh

## Purpose

Resolve and optionally submit one or more Slurm jobs for an NVIDIA HPL-MxP row.

## Usage

```text
scripts/benchmark/submit-hpl-mxp.sh --cluster <b200|rtxpro6000> --nodes <1|2|4|8|16> [--preset <smoke|staged|campaign-candidate|weak-study>] [--matrix-size <N|auto>] [--nb <N|auto>] [--nprow <auto|N>] [--npcol <auto|N>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--nodelist <csv>] [--partition <name>] [--time <HH:MM:SS>] [--mem <size>] [--image <path>] [--sloppy-type <precision>] [--test-loop <n>] [--repeat-count <n>] [--repeat-stagger-seconds <n>] [--cpus-per-task <n>] [--affinity-profile <none|derived-nps4>] [--ompi-coll <value|none>] [--ompi-pml <value|none>] [--ompi-btl <value|none>] [--ompi-btl-tcp-if-include <value|none>] [--ompi-oob-tcp-if-include <value|none>] [--ucx-tls <value|none>] [--ucx-net-devices <value|none>] [--pmix-mca-gds <value|none>] [--mpi-use-mpi <0|1>] [--use-mpi-panel-broadcast <0-100>] [--prioritize-trsm <0|1>] [--prioritize-factorization <0|1>] [--anq-device <columns>] [--fill-device <0|1>] [--fill-device-buffer-size <MB>] [--call-dgemv-with-multiple-threads <threads>] [--preset-gemm-kernel <n>] [--cpu-affinity <map>] [--mem-affinity <map>] [--ucx-affinity <map>] [--u-panel-chunk-nbs <N>] [--scaling-study <exploratory|strong|weak>] [--baseline-matrix-size <N>] [--apply]
```

Default behavior is dry-run. The script prints the resolved matrix size, block
size, processor grid policy, image path, Slurm partition, explicit node list,
MPI and NPS4-derived affinity controls, Slurm memory request, and `sbatch`
command. Add `--apply` only after reviewing the plan.

Full-node HPL-MxP submissions default to `--mem=0` so Slurm grants the node
memory cgroup. Override `--mem` only for reviewed diagnostics.

## Important Options

| Option | Meaning |
| --- | --- |
| `--cluster` | Cluster family, `b200` or `rtxpro6000`. |
| `--nodes` | Slurm node count. B200 supports `1`, `2`, `4`, `8`, or `16`; RTX supports `1`, `2`, or `4`. |
| `--preset` | `smoke`, `staged`, `campaign-candidate`, or `weak-study`. |
| `--matrix-size` | Matrix size `N`, or `auto`. |
| `--nb` | Block size `NB`, or `auto`. |
| `--nprow`, `--npcol` | Processor-grid override, or `auto`. |
| `--from-node-report` | Select strict-passed nodes from the node report. |
| `--date` | Node-report date for `--from-node-report`. |
| `--nodelist` | Explicit comma-separated node list. |
| `--partition` | Slurm partition override. Defaults to the current partition for the selected cluster. |
| `--time` | Slurm time limit. |
| `--mem` | Slurm memory request. Default: `0` for full-node HPL-MxP rows. |
| `--image` | NVIDIA HPC Benchmarks Apptainer image path. |
| `--test-loop` | HPL-MxP loop count. |
| `--sloppy-type` | HPL-MxP sloppy type: `FP4`, `FP8`, or `FP16`. Default: `FP16`; `FP4` is B200-only in the public wrapper. |
| `--repeat-count` | Submit independent repeated samples. |
| `--repeat-stagger-seconds` | Seconds between repeated submissions. |
| `--cpus-per-task` | Slurm CPU allocation per task. |
| `--affinity-profile` | `derived-nps4` by default for AICR GPU benchmark rows. |
| `--ompi-coll`, `--ompi-pml`, `--ompi-btl` | Open MPI MCA overrides. |
| `--ompi-btl-tcp-if-include`, `--ompi-oob-tcp-if-include` | Open MPI TCP interface filters. |
| `--ucx-tls`, `--ucx-net-devices` | UCX transport and network-device filters. |
| `--pmix-mca-gds` | PMIx GDS MCA setting. |
| `--mpi-use-mpi`, `--use-mpi-panel-broadcast` | HPL-MxP MPI and panel-broadcast controls. |
| `--prioritize-trsm`, `--prioritize-factorization` | HPL-MxP algorithm priority controls. |
| `--anq-device`, `--fill-device`, `--fill-device-buffer-size` | FP64 matrix placement and fill-device controls. |
| `--call-dgemv-with-multiple-threads` | DGEMV thread override. |
| `--preset-gemm-kernel` | GEMM kernel preset. |
| `--cpu-affinity`, `--mem-affinity`, `--ucx-affinity` | Explicit affinity maps. |
| `--u-panel-chunk-nbs` | HPL-MxP U-panel chunk size. |
| `--scaling-study` | `exploratory`, `strong`, or `weak` metadata. |
| `--baseline-matrix-size` | Baseline matrix size for scaling metadata. |
| `--apply` | Submit the Slurm job. |

## Preset Policy

| Preset | Intended use |
| --- | --- |
| `smoke` | Tiny row that confirms launch, parsing, and artifact layout. |
| `staged` | Smaller controlled rows for dry-run or replay rehearsal. |
| `campaign-candidate` | Compatibility preset for existing target-size rows. |
| `weak-study` | Reviewed weak-scaling preset; resolves the matrix ladder, derived NPS4 affinity, weak-scaling metadata, and reviewed HPL-MxP controls. |

FP8 and B200 FP4 rows use the same preset plus `--sloppy-type FP8` or
`--sloppy-type FP4`; keep them labeled separately from FP16 rows.

The current `weak-study` matrix ladder uses `NB=2048` and 1024-aligned matrix
sizes:

| Nodes | B200 N | RTX PRO 6000 N | Grid |
| ---: | ---: | ---: | --- |
| 1 | 379904 | 379904 | `4x2` |
| 2 | 530432 | 530432 | `4x4` |
| 4 | 749568 | 749568 | `4x8` |
| 8 | 1049600 | - | `8x8` |
| 16 | 1500160 | - | `16x8` |

## Example

```bash
scripts/benchmark/submit-hpl-mxp.sh \
  --cluster b200 \
  --nodes 1 \
  --preset smoke \
  --nodelist b0001
```

Preview a weak-study FP16 row:

```bash
scripts/benchmark/submit-hpl-mxp.sh --cluster b200 --nodes 4 --preset weak-study --nodelist b0002,b0006,b0007,b0008 --repeat-count 3
```

## Outputs

Applied jobs write Slurm output under `results/slurm/` and run artifacts under
`results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/`.
