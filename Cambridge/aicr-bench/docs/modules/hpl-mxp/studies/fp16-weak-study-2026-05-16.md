# HPL-MxP FP16 Weak Scaling

<!-- aicr-study-status: appendix -->

Appendix - Supporting Reference, Not A Standalone Study.

This page preserves the May 16 FP16 aggregate summary. Public bundle status is
pending, so treat the table as historical context, not standalone public-result
evidence. Promote it only after the OSN bundle, provenance JSON, checksum, and
retrieve/verify commands are published.

Purpose: show FP16 weak scaling on RTX PRO 6000 and B200 using the HPL-MxP
`N` values from the NVIDIA HPC Benchmarks container defaults and the reviewed
[NPS4-derived placement policy](../placement.md).

This study uses one MPI rank per GPU, five independent samples per
row, and an Olympic mean for PFLOP/s: drop the lowest and highest passing
samples, then average the middle three.

## Run Shape

| Field | Value |
| --- | --- |
| Date | 2026-05-16 |
| Runtime image | `${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif` |
| Launcher | Slurm + Apptainer |
| MPI ranks | 8 per node, 1 rank per GPU |
| Sloppy type | `FP16` |
| NB | `2048` |
| `u-panel-chunk-nbs` | `16` |
| RTX PRO 6000 nodes | 1, 2, 4 |
| B200 nodes | 1, 2, 4, 8, 16 |
| Samples per row | 5 |
| Aggregation | Olympic mean |
| RTX PRO 6000 run IDs | `21597-21611` |
| B200 run IDs | `21615-21639` |
| Completed/passed | `40/40` |

## Matrix Sizes

| Nodes | GPUs | N | Grid |
| ---: | ---: | ---: | --- |
| 1 | 8 | 380000 | `4x2` |
| 2 | 16 | 530000 | `4x4` |
| 4 | 32 | 750000 | `4x8` |
| 8 | 64 | 1050000 | `8x8` |
| 16 | 128 | 1500000 | `16x8` |

The 8-node and 16-node rows were collected on B200 only.

Rows use the reviewed [NPS4-derived placement policy](../placement.md).

## Representative Command Shape

Representative B200 16-node row:

```bash
scripts/benchmark/submit-hpl-mxp.sh \
  --cluster b200 \
  --nodes 16 \
  --preset weak-study \
  --matrix-size 1500000 \
  --nb 2048 \
  --nprow 16 \
  --npcol 8 \
  --sloppy-type FP16 \
  --u-panel-chunk-nbs 16 \
  --cpu-affinity 16-31:32-47:48-63:0-15:80-95:96-111:112-127:64-79 \
  --mem-affinity 1:2:3:0:5:6:7:4 \
  --ucx-affinity mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_6:mlx5_11 \
  --scaling-study weak \
  --baseline-matrix-size 380000 \
  --repeat-count 5 \
  --repeat-stagger-seconds 5 \
  --time 00:30:00 \
  --apply
```

## Results

All FP16 rows completed with residual pass, parsed PFLOP/s, and the expected
GPU count.

| Platform | Type | Nodes | GPUs | N | NB | Grid | Olympic PFLOP/s | PFLOP/s/GPU |
| --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| RTX PRO 6000 | `FP16` | 1 | 8 | 380000 | 2048 | `4x2` | 1.26 | 0.158 |
| RTX PRO 6000 | `FP16` | 2 | 16 | 530000 | 2048 | `4x4` | 2.92 | 0.183 |
| RTX PRO 6000 | `FP16` | 4 | 32 | 750000 | 2048 | `4x8` | 6.67 | 0.208 |
| B200 | `FP16` | 1 | 8 | 380000 | 2048 | `4x2` | 1.90 | 0.238 |
| B200 | `FP16` | 2 | 16 | 530000 | 2048 | `4x4` | 4.83 | 0.302 |
| B200 | `FP16` | 4 | 32 | 750000 | 2048 | `4x8` | 12.61 | 0.394 |
| B200 | `FP16` | 8 | 64 | 1050000 | 2048 | `8x8` | 28.62 | 0.447 |
| B200 | `FP16` | 16 | 128 | 1500000 | 2048 | `16x8` | 65.36 | 0.511 |

The larger weak-scaling rows have better PFLOP/s per GPU than the one-node
rows. That means the one-node weak-study rows are smaller than the size needed
to saturate the platforms as well as the larger rows. B200 is reported through
16 nodes; RTX PRO 6000 is reported through 4 nodes.

## Artifact Status

This page is not standalone public-result evidence yet. Public bundle status is
pending. Do not use the aggregate table for publication claims until the public
bundle, provenance JSON, checksum, and retrieve/verify commands are added.

Rendered report references are retained as operator context:

- `results/reports/2026-05-16/hpl-mxp/hpl-mxp-b200-2026-05-16.md`
- `results/reports/2026-05-16/hpl-mxp/hpl-mxp-rtxpro6000-2026-05-16.md`

Runtime trees, Slurm logs, and uncurated provenance files are not committed to
Git.
