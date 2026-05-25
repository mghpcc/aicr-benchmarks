# HPL-MxP Aligned Weak Study

<!-- aicr-study-status: published -->

Purpose: report HPL-MxP `weak-study` results across B200 and RTX PRO 6000
using a matrix ladder aligned to the NVIDIA HPC Benchmarks container default
weak-scaling `N` values and the reviewed placement policy.

This study uses the public HPL-MxP wrapper, one MPI rank per GPU, the
[NPS4-derived CPU, memory, GPU, and UCX/NIC maps](../placement.md), `--mem=0`,
and three samples per row with standard mean aggregation.

Aligned means each row uses the nearest 1024-divisible matrix dimension `N` to
the NVIDIA HPC Benchmarks container's default weak-scaling `N` for the same
node count. In this context, `N` is the global HPL-MxP matrix dimension. The
1024 value is the matrix-dimension alignment multiple used so the tested B200
FP4 runtime path accepts the same ladder; it is not the HPL-MxP block size
`NB`, which remains `2048`. The aligned ladder rounds `380000`, `530000`,
`750000`, `1050000`, and `1500000` to `379904`, `530432`, `749568`, `1049600`,
and `1500160`.

## Scope

| Field | Value |
| --- | --- |
| Date | 2026-05-24 |
| Runtime image | `${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif` |
| Launcher | Slurm + Apptainer |
| Preset | `weak-study` |
| Scaling study | `weak` |
| Samples per row | 3 |
| Aggregation | Standard mean |
| B200 sloppy types | `FP16`, `FP8`, `FP4` |
| RTX PRO 6000 sloppy types | `FP16`, `FP8` |
| Placement | [NPS4-derived CPU, memory, GPU, and UCX/NIC maps](../placement.md) |
| Slurm memory | `--mem=0` |
| Job range | HPL-MxP jobs `28201-28264`, applied through `--job-id-min 28201 --job-id-max 28264` at render time; unrelated job `28226` (`sbatch_job_qwen.sh`) is excluded by both the job-id filter and the absence of an HPL-MxP parsed summary |

RTX PRO 6000 FP4 is excluded from public performance results because the tested
HPL-MxP/cuBLASLt FP4 launch path with the NVIDIA HPC Benchmarks 26.02 image
fails before residual check. This is a software-stack and descriptor-path
observation tied to the tested wrapper settings; it is not a general hardware
capability statement about the RTX PRO 6000 platform.

## Matrix Ladder

All public rows in this study use the same 1024-aligned `weak-study` matrix
ladder.

| Nodes | Container Default N | Aligned N | NB | Grid |
| ---: | ---: | ---: | ---: | --- |
| 1 | 380000 | 379904 | 2048 | `4x2` |
| 2 | 530000 | 530432 | 2048 | `4x4` |
| 4 | 750000 | 749568 | 2048 | `4x8` |
| 8 | 1050000 | 1049600 | 2048 | `8x8` |
| 16 | 1500000 | 1500160 | 2048 | `16x8` |

The 8-node and 16-node rows were collected on B200 only.

## B200 Results

All B200 rows below completed with `status=passed`, `return_code=0`, and
`residual_check=passed`.

| Type | Nodes | GPUs | N | NB | Grid | Samples | Mean PFLOP/s | PFLOP/s/GPU | PFLOP/s range |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- |
| `FP16` | 1 | 8 | 379904 | 2048 | `4x2` | 3 | 1.89 | 0.236 | 1.88-1.90 |
| `FP16` | 2 | 16 | 530432 | 2048 | `4x4` | 3 | 4.84 | 0.303 | 4.83-4.85 |
| `FP16` | 4 | 32 | 749568 | 2048 | `4x8` | 3 | 12.44 | 0.389 | 12.43-12.47 |
| `FP16` | 8 | 64 | 1049600 | 2048 | `8x8` | 3 | 28.53 | 0.446 | 28.52-28.54 |
| `FP16` | 16 | 128 | 1500160 | 2048 | `16x8` | 3 | 65.27 | 0.510 | 65.19-65.34 |
| `FP8` | 1 | 8 | 379904 | 2048 | `4x2` | 3 | 2.08 | 0.260 | 2.08-2.09 |
| `FP8` | 2 | 16 | 530432 | 2048 | `4x4` | 3 | 5.51 | 0.344 | 5.46-5.55 |
| `FP8` | 4 | 32 | 749568 | 2048 | `4x8` | 3 | 14.76 | 0.461 | 14.74-14.79 |
| `FP8` | 8 | 64 | 1049600 | 2048 | `8x8` | 3 | 34.80 | 0.544 | 34.58-34.94 |
| `FP8` | 16 | 128 | 1500160 | 2048 | `16x8` | 3 | 82.59 | 0.645 | 82.25-82.90 |
| `FP4` | 1 | 8 | 379904 | 2048 | `4x2` | 3 | 2.12 | 0.265 | 2.11-2.13 |
| `FP4` | 2 | 16 | 530432 | 2048 | `4x4` | 3 | 5.63 | 0.352 | 5.61-5.68 |
| `FP4` | 4 | 32 | 749568 | 2048 | `4x8` | 3 | 15.26 | 0.477 | 15.25-15.29 |
| `FP4` | 8 | 64 | 1049600 | 2048 | `8x8` | 3 | 36.05 | 0.563 | 35.74-36.33 |
| `FP4` | 16 | 128 | 1500160 | 2048 | `16x8` | 3 | 86.85 | 0.679 | 86.59-87.33 |

## RTX PRO 6000 Results

All RTX rows below completed with `status=passed`, `return_code=0`, and
`residual_check=passed`.

| Type | Nodes | GPUs | N | NB | Grid | Samples | Mean PFLOP/s | PFLOP/s/GPU | PFLOP/s range |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- |
| `FP16` | 1 | 8 | 379904 | 2048 | `4x2` | 3 | 1.25 | 0.156 | 1.25-1.26 |
| `FP16` | 2 | 16 | 530432 | 2048 | `4x4` | 3 | 2.94 | 0.184 | 2.94-2.94 |
| `FP16` | 4 | 32 | 749568 | 2048 | `4x8` | 3 | 6.67 | 0.208 | 6.66-6.67 |
| `FP8` | 1 | 8 | 379904 | 2048 | `4x2` | 3 | 1.52 | 0.191 | 1.52-1.53 |
| `FP8` | 2 | 16 | 530432 | 2048 | `4x4` | 3 | 3.76 | 0.235 | 3.75-3.77 |
| `FP8` | 4 | 32 | 749568 | 2048 | `4x8` | 3 | 9.04 | 0.282 | 9.00-9.08 |

## Artifacts

Public retrieval uses the OSN bundle, OSN provenance JSON, and OSN checksum
below. VAST paths are AICR operator-retention references and are not required
for public verification.

- OSN bundle: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/0d634a0/hpl-mxp/2026-05-24/hpl-mxp-aligned-weak-study-2026-05-24.tar.gz>
- OSN provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/0d634a0/hpl-mxp/2026-05-24/hpl-mxp-aligned-weak-study-2026-05-24.provenance.json>
- OSN checksum: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/0d634a0/hpl-mxp/2026-05-24/hpl-mxp-aligned-weak-study-2026-05-24.sha256>
- Bundle SHA-256: `8f77ee2481833299f6da4e6803c3150d549e41246f2419fe3ac092622cd15b5b`
- Bundle size: `857983` bytes
- VAST bundle: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/0d634a0/hpl-mxp/2026-05-24/hpl-mxp-aligned-weak-study-2026-05-24.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/0d634a0/hpl-mxp/2026-05-24/hpl-mxp-aligned-weak-study-2026-05-24.provenance.json`

Retrieve and verify:

```bash
mkdir -p public-study-artifacts/hpl-mxp-aligned-weak-study
cd public-study-artifacts/hpl-mxp-aligned-weak-study
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/0d634a0/hpl-mxp/2026-05-24/hpl-mxp-aligned-weak-study-2026-05-24.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/0d634a0/hpl-mxp/2026-05-24/hpl-mxp-aligned-weak-study-2026-05-24.sha256
sha256sum -c hpl-mxp-aligned-weak-study-2026-05-24.sha256
test "$(wc -c < hpl-mxp-aligned-weak-study-2026-05-24.tar.gz | tr -d ' ')" = "857983"
tar -tzf hpl-mxp-aligned-weak-study-2026-05-24.tar.gz | sed -n '1,20p'
```

The bundle includes filtered rendered Markdown/CSV/JSON reports, per-row parsed
`summary.json` and `status.json`, run `record.json`, command files, HPL-MxP
stdout/stderr/summary files, and GPU preflight/postflight captures for public
sample rows. The bundle was rendered with
`--job-id-min 28201 --job-id-max 28264` and `REPEAT_AGGREGATION=standard`.
