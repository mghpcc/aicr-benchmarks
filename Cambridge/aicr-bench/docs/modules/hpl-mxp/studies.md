# HPL-MxP Studies

Purpose: index the public HPL-MxP studies by platform, precision mode, and
evidence type.

HPL-MxP studies report residual-validated PFLOP/s for NVIDIA HPC Benchmarks
HPL-MxP rows. Public rows use one MPI rank per GPU and the reviewed
[NPS4-derived CPU, memory, GPU, and UCX/NIC placement policy](placement.md).

## Reading Path

Start with the aligned weak study for the broadest B200 and RTX PRO 6000
public-result comparison. Use the FP16 weak-scaling page only as supporting
historical context until its public artifact bundle, provenance JSON, checksum,
and retrieve/verify commands are published.

| Study | Platforms | Precision Modes | What It Tests | Evidence Type | Results |
| --- | --- | --- | --- | --- | --- |
| [HPL-MxP aligned weak study](studies/precision-weak-study-2026-05-24.md) | B200 and RTX PRO 6000 | B200 `FP16`, `FP8`, `FP4`; RTX `FP16`, `FP8` | Weak-scaling precision comparison on the aligned ladder. | Public result | [Results](studies/precision-weak-study-2026-05-24.md#b200-results) |
| [HPL-MxP FP16 weak scaling](studies/fp16-weak-study-2026-05-16.md) | B200 and RTX PRO 6000 | `FP16` | Weak scaling at the NVIDIA HPC Benchmarks container default `N` values. | Appendix/supporting context; public bundle pending | [Context](studies/fp16-weak-study-2026-05-16.md#results) |

## Result Summary

The table below summarizes the weak-scaling precision comparison. Each row is
the standard mean of three passing samples from the same nodelist and the same
HPL-MxP shape.

| Platform | Type | Nodes | GPUs | N | NB | Grid | Mean PFLOP/s | PFLOP/s/GPU |
| --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| RTX PRO 6000 | `FP16` | 1 | 8 | 379904 | 2048 | `4x2` | 1.25 | 0.156 |
| RTX PRO 6000 | `FP16` | 2 | 16 | 530432 | 2048 | `4x4` | 2.94 | 0.184 |
| RTX PRO 6000 | `FP16` | 4 | 32 | 749568 | 2048 | `4x8` | 6.67 | 0.208 |
| RTX PRO 6000 | `FP8` | 1 | 8 | 379904 | 2048 | `4x2` | 1.52 | 0.191 |
| RTX PRO 6000 | `FP8` | 2 | 16 | 530432 | 2048 | `4x4` | 3.76 | 0.235 |
| RTX PRO 6000 | `FP8` | 4 | 32 | 749568 | 2048 | `4x8` | 9.04 | 0.282 |
| B200 | `FP16` | 1 | 8 | 379904 | 2048 | `4x2` | 1.89 | 0.236 |
| B200 | `FP16` | 2 | 16 | 530432 | 2048 | `4x4` | 4.84 | 0.303 |
| B200 | `FP16` | 4 | 32 | 749568 | 2048 | `4x8` | 12.44 | 0.389 |
| B200 | `FP16` | 8 | 64 | 1049600 | 2048 | `8x8` | 28.53 | 0.446 |
| B200 | `FP16` | 16 | 128 | 1500160 | 2048 | `16x8` | 65.27 | 0.510 |
| B200 | `FP8` | 1 | 8 | 379904 | 2048 | `4x2` | 2.08 | 0.260 |
| B200 | `FP8` | 2 | 16 | 530432 | 2048 | `4x4` | 5.51 | 0.344 |
| B200 | `FP8` | 4 | 32 | 749568 | 2048 | `4x8` | 14.76 | 0.461 |
| B200 | `FP8` | 8 | 64 | 1049600 | 2048 | `8x8` | 34.80 | 0.544 |
| B200 | `FP8` | 16 | 128 | 1500160 | 2048 | `16x8` | 82.59 | 0.645 |
| B200 | `FP4` | 1 | 8 | 379904 | 2048 | `4x2` | 2.12 | 0.265 |
| B200 | `FP4` | 2 | 16 | 530432 | 2048 | `4x4` | 5.63 | 0.352 |
| B200 | `FP4` | 4 | 32 | 749568 | 2048 | `4x8` | 15.26 | 0.477 |
| B200 | `FP4` | 8 | 64 | 1049600 | 2048 | `8x8` | 36.05 | 0.563 |
| B200 | `FP4` | 16 | 128 | 1500160 | 2048 | `16x8` | 86.85 | 0.679 |

The full [weak-scaling precision comparison](studies/precision-weak-study-2026-05-24.md)
contains row-level sample ranges, artifact links, provenance, and
retrieve/verify commands.

## Precision Boundary

B200 has public FP16, FP8, and FP4 performance rows in the weak-scaling
precision comparison. RTX PRO 6000 has public FP16 and FP8 rows.

## Collection Shape

Public HPL-MxP study rows use the public submitter or
`make benchmark-hpl-mxp` with:

- one MPI rank per GPU;
- `HPL_MXP_PRESET=weak-study`;
- `HPL_MXP_AFFINITY_PROFILE=derived-nps4`;
- `HPL_MXP_SCALING_STUDY=weak`;
- `HPL_MXP_MEM=0`;
- `HPL_MXP_SLOPPY_TYPE=FP16`, `FP8`, or B200-only `FP4`;
- repeated samples and an explicit aggregation policy.

The aligned weak-scaling ladder is:

| Nodes | N | Grid |
| ---: | ---: | --- |
| 1 | 379904 | `4x2` |
| 2 | 530432 | `4x4` |
| 4 | 749568 | `4x8` |
| 8 | 1049600 | `8x8` |
| 16 | 1500160 | `16x8` |

The B200 weak-scaling comparison includes the 1-, 2-, 4-, 8-, and 16-node
rows. The RTX PRO 6000 weak-scaling comparison includes the 1-, 2-, and 4-node
rows.

## Evidence Boundaries

HPL-MxP study pages should show the platform, node count, GPU count, matrix
size `N`, block size `NB`, process grid, precision mode, placement policy,
container image, repeat count, aggregation policy, residual status, PFLOP/s,
and artifact links for public result rows.

Public aggregate tables intentionally exclude skipped, failed, proof, smoke,
staged, diagnostic, superseded, and one-off rows. Renderer outputs may retain
excluded rows in diagnostic sections when they include an exclusion reason.
