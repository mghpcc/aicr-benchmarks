# Synthetic Large JPEG Decode Stress

<!-- aicr-study-status: appendix -->

Purpose: show how PyTorch CPU DataLoader and DALI behave when the input path is
stressed with prepared synthetic JPEG files at increasing image sizes.

This appendix comes from the
[DataLoader Input Pipeline Lab](input-pipeline-lab.md) and focuses on JPEG
decode and preprocessing behavior for large compressed inputs.

**Appendix - Decode-Path Detail**

## What Was Measured

The study used an ImageFolder-style tree of compressed JPEG files generated
before measurement. During measurement, the loaders read those prepared JPEG
files and performed the online input-pipeline work: decode, crop/resize,
normalize, batch, and host-to-device transfer.

Each nominal size is a square RGB image size:

- `512` means `512 x 512` pixels.
- `768` means `768 x 768` pixels.
- `1024` means `1024 x 1024` pixels.
- `1536` means `1536 x 1536` pixels.

The comparison is same-size PyTorch CPU DataLoader versus DALI:

- PyTorch CPU DataLoader reads JPEG files, decodes and transforms them on CPU
  workers, then batches and transfers tensors.
- DALI reads the same compressed JPEG input and moves decode/preprocessing work
  into the DALI pipeline.

JPEG decode and image preprocessing cost grow quickly as square image area
increases. This appendix asks whether the DALI pipeline becomes more valuable
as that online work increases.

## Run Shape

| Field | Value |
| --- | --- |
| Study type | Appendix / decode-path detail |
| Platforms | B200, RTX Pro 6000 |
| Input representation | Prepared synthetic large JPEG ImageFolder tree |
| Image sizes | `512`, `768`, `1024`, `1536` square pixels |
| Backends | PyTorch CPU DataLoader, DALI |
| Measurement scope | DataLoader-only input throughput |
| Source study | [DataLoader Input Pipeline Lab](input-pipeline-lab.md) |

## Result

Five-sample DataLoader-only measurements showed that DALI speedup increased
with JPEG size:

| Platform | `512` | `768` | `1024` | `1536` |
| --- | ---: | ---: | ---: | ---: |
| B200 | `1.169x` | `1.596x` | `2.159x` | `3.429x` |
| RTX Pro 6000 | `1.105x` | `1.546x` | `2.106x` | `3.415x` |

The trend is the important result. DALI is only modestly faster at `512 x 512`,
but the advantage grows as the compressed image size increases. By
`1536 x 1536`, DALI is more than `3.4x` faster than the same-size PyTorch CPU
DataLoader path on both platforms.

## Interpretation

This study keeps the input compressed as JPEG, so the measured advantage is
about online JPEG decode and preprocessing for this synthetic input
representation. A DALI win here means the DALI pipeline helped for large
compressed JPEG input.

The corresponding DDP training study is
[synthetic large JPEG training](../../ddp/studies/synthetic-large-jpeg-training.md).
That page tests whether this DataLoader-only trend remains visible once model
compute, backward pass, optimizer work, distributed timing, and sharding enter
the measured loop.

Use this result to understand compressed large-image input behavior and to
motivate DALI-specific DDP follow-up for similar workloads.

## Source Artifact Bundle

This appendix is drawn from the
[DataLoader Input Pipeline Lab](input-pipeline-lab.md). Use that source study
for the public artifact bundle, provenance, checksum, and retrieve/verify
commands.

| Artifact | Location |
| --- | --- |
| OSN bundle | <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/8d17114/dataloader/2026-05-19/dataloader-input-pipeline-lab-2026-05-19.tar.gz> |
| OSN provenance | <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/8d17114/dataloader/2026-05-19/dataloader-input-pipeline-lab-2026-05-19-provenance.json> |
| OSN checksum | <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/8d17114/dataloader/2026-05-19/dataloader-input-pipeline-lab-2026-05-19.sha256> |
