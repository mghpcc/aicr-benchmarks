# DataLoader Input Pipeline Reference

Purpose: explain DataLoader metric names, input representations, and how
input-pipeline studies connect to training results.

Use [DataLoader studies](studies.md) for the public evidence index. This page
defines the shared labels and interpretation rules used by those studies.

## Metric Names

DataLoader reports use several throughput names:

- `samples/s`: end-to-end throughput for the measured DataLoader loop. This is
  the headline comparison metric.
- `load samples/s`: input-pipeline throughput before the GPU transfer portion
  of the measured path. Use it to see whether workers, prefetch, and storage
  reads are helping the input side.
- `H2D samples/s`: host-to-device transfer throughput. When this is much higher
  than `samples/s`, host-to-device transfer is probably not the limiting step.
- `rank_imbalance_percent`: multi-rank throughput spread. It matters for
  one-node eight-GPU and multi-node studies, but not for one-GPU rows.

Shared aggregation terms such as Olympic average, jitter, and coefficient of
variation are defined in [Stats Explained](../../stats-explained.md).

## Input Representations

| Label | Data path | Why it exists |
| --- | --- | --- |
| `canonical-224` | Standard ImageNet ImageFolder JPEG input with the ordinary online training crop/resize/normalize path. | The primary DataLoader and DDP input path. |
| `derived-jpeg-1024` | ImageNet-derived pre-resized JPEG ImageFolder input. | Changes image representation and size while preserving a JPEG path, so it can study backend crossover at larger image sizes. |
| `prepared-input-ceiling` | ImageNet-derived NumPy uint8 or fp16 shards. | Measures how much online work can be removed by paying preprocessing offline. |
| `numpy-fp16-blocks` | ImageNet-derived blocked fp16 `.npy` tensors read through PyTorch mmap or DALI's NumPy reader. | Compares prepared-tensor transport paths after JPEG decode and preprocessing have been moved offline. |
| `decode-stress` | Large compressed JPEG input. | Studies JPEG decode pressure. |

Derived inputs are controlled experiment inputs. They help explain mechanisms
and compare input paths, while canonical ImageNet remains the primary input for
hardware progression rows.

## Study Flow

The canonical DataLoader sequence is:

1. Single-GPU surface study.
2. One-node eight-GPU replicated study.
3. Multi-node parameter selection.
4. Multi-node scale study.

### Canonical Progression

The canonical progression stays on `canonical-224` ImageNet input. It is the
hardware progression path and the default place to compare B200 and RTX
DataLoader behavior.

### Supporting Studies

Supporting input-pipeline studies answer different questions:

- [DALI optimization on standard ImageNet](studies/dali-standard-imagenet-optimization.md)
  checks whether GPU decode helps when the input remains ordinary ImageNet.
- [CPU PyTorch DataLoader optimization at 1024](studies/cpu-large-image-optimization.md)
  and [DALI optimization at 1024](studies/dali-large-image-optimization.md)
  tune the large-JPEG endpoint before comparing backends.
- [Optimized 224/1024 backend crossover](studies/optimized-backend-crossover.md)
  compares tuned CPU and tuned DALI endpoints.
- [Prepared-input ceilings](studies/prepared-input-ceilings.md) measures
  NumPy shard backends that remove JPEG decode and, for fp16, most online
  preprocessing.
- [B200 prepared-tensor GPU/cuFile transport](studies/b200-prepared-tensor-gds-transport.md)
  compares PyTorch mmap blocks with DALI NumPy GPU/cuFile transport across a
  B200 prepared-block size ladder.
- [RTX prepared-tensor GPU/cuFile transport](studies/rtx-prepared-tensor-gds-transport.md)
  summarizes the RTX one-node prepared-tensor transport ladder.

The `dali-numpy-fp16-cpu`, `dali-numpy-fp16-gds`,
`numpy-fp16-blocks-pytorch`, `dali-numpy-fp16-blocks-cpu`, and
`dali-numpy-fp16-blocks-gds` backends compare prepared-tensor CPU-reader and
DALI NumPy GPU/cuFile paths.

## Input Path Guidance

Use `canonical-224` with the tuned PyTorch CPU DataLoader as the baseline for
ordinary ImageNet-like training. It is the default input path for the
DataLoader hardware progression and small-image DDP comparisons.

Use DALI when runtime JPEG decode and image processing are large enough to
offset DALI pipeline overhead. In the current public studies, tuned CPU remains
stronger for ordinary `canonical-224` ImageNet input, while tuned DALI is the
strongest measured DataLoader path for `derived-jpeg-1024`.

Use derived pre-resized JPEG datasets to study input-pipeline behavior at a
controlled image size. These datasets preserve the ImageFolder/JPEG path while
changing image area, decode pressure, and crop work. A derived `224` DALI win is
specific to pre-resized JPEG input; canonical ImageNet `224` remains a separate
result.

### DALI JPEG And GPU/cuFile

Treat DALI JPEG and DALI NumPy GPU/cuFile as separate paths. The DALI JPEG rows
in this module use `fn.readers.file` followed by `fn.decoders.image` or
`fn.decoders.image_random_crop` in a mixed decode path. NVIDIA documents
`fn.readers.file` with a CPU backend, while the DALI image decoder documents
CPU and mixed decode backends for JPEG. Those rows can use GPU-accelerated
decode and GPU image operators.

The documented DALI GPU/cuFile path used by this module is
`fn.readers.numpy(device="gpu", use_o_direct=True)`. NVIDIA documents the GPU
backend of `fn.readers.numpy` as requiring cuFile/GDS support and provides the
`DALI_GDS_CHUNK_SIZE` and `use_o_direct` controls there. A DALI maintainer also
clarified that DALI uses GPUDirect Storage for the GPU variant of the NumPy
reader, while file-reader JPEG input still requires CPU-side parsing before
image decode. Therefore `dali-numpy-fp16-blocks-gds` is prepared-tensor
transport, and `dali-gpu-decode` is a JPEG decode/input-pipeline backend.

References:
[DALI `readers.file`](https://docs.nvidia.com/deeplearning/dali/user-guide/docs/operations/nvidia.dali.fn.readers.file.html),
[DALI `readers.numpy`](https://docs.nvidia.com/deeplearning/dali/user-guide/docs/operations/nvidia.dali.fn.readers.numpy.html),
[DALI `decoders.image`](https://docs.nvidia.com/deeplearning/dali/user-guide/docs/operations/nvidia.dali.fn.decoders.image.html),
and [NVIDIA/DALI issue 4701](https://github.com/NVIDIA/DALI/issues/4701).

Use NumPy uint8 or fp16 shards to measure prepared-input ceilings. NumPy uint8
removes JPEG decode while leaving runtime tensor conversion and normalization
in the measured path. NumPy fp16 also moves most normalization offline, so it
shows the effect of moving more preprocessing out of the measured DataLoader
loop.

Use DALI NumPy CPU/GPU-cuFile backends for prepared-tensor transport studies.
The per-sample backends use one fp16 `.npy` file per image; the block backends
use larger fp16 `.npy` files containing multiple normalized NCHW tensors.
`numpy-fp16-blocks-pytorch` reads that same blocked layout through PyTorch with
mmap and a bounded CPU block cache, so it is the safer CPU comparison path when
DALI's CPU NumPy block reader is too memory-intensive.

### Input Labels

| Label | Public interpretation |
| --- | --- |
| `derived-jpeg-1024` | Backend-crossover input for larger pre-resized JPEG files. |
| `prepared-input-ceiling` | Offline preprocessing comparison for NumPy uint8 and fp16 inputs. |
| `numpy-fp16-blocks` | Prepared fp16 tensor transport through PyTorch mmap or DALI NumPy GPU/cuFile reader paths. |
| `synthetic-gpu-ceiling` | DDP input path with the real input pipeline removed. |

Derived datasets should be created through the documented preparation
interfaces. Keep generated data out of Git, and use scratch storage unless a
study requires long-term retention.

## Related DDP Studies

DataLoader-only rows measure input-side behavior before model compute,
backward pass, optimizer work, rank timing, distributed sharding, gradient
communication, and rank synchronization enter the measured loop. DDP studies
report the matching training-throughput results.

Related DDP pages:

- [DataLoader comparison](../ddp/studies/dataloader-candidate-followup.md)
- [DDP studies index](../ddp/studies.md)
- [Input ceilings](../ddp/studies/input-ceilings.md)
- [B200 prepared-tensor GPU/cuFile transport pilot](../ddp/studies/prepared-tensor-gds-transport.md)
- [B200 prepared-tensor GPU/cuFile scale study](../ddp/studies/prepared-tensor-gds-scale-followup.md)
- [RTX prepared-tensor GPU/cuFile transport study](../ddp/studies/rtx-prepared-tensor-gds-transport.md)
- [Synthetic large JPEG training](../ddp/studies/synthetic-large-jpeg-training.md)

## Detailed Diagrams

The reference page [Where the input work lives](studies/input-representations.md)
contains diagrams for PyTorch CPU DataLoader, DALI, NumPy uint8, NumPy fp16,
DALI NumPy CPU/GPU-cuFile prepared tensors, synthetic GPU input, and DDP training
paths.
