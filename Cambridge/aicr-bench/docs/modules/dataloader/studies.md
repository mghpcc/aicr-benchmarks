# DataLoader Studies

Purpose: index the public DataLoader studies by platform, study role, and
reading path.

DataLoader studies measure input-pipeline throughput before training. The
hardware progression uses `canonical-224` ImageNet input across single-GPU,
one-node, and multi-node shapes. Cross-platform studies cover DALI,
backend-crossover, derived-JPEG, and prepared-input results without duplicating
shared pages inside each platform section.

Reading order: start with the single-GPU surface, then one-node eight-GPU
replicated rows, then multi-node parameter selection, and finally the
multi-node scale study. The [DDP Studies](../ddp/studies.md) page covers
training-throughput results.

For headline conclusions, start with [Results Summary](results-summary.md).
Metric definitions, input-path diagrams, and derived-dataset details live in
[Input Pipeline Reference](input-pipeline-reference.md) and
[Derived ImageNet Datasets](derived-datasets.md).

Study roles:

- `Hardware progression`: platform progression on `canonical-224`.
- `Backend comparison`: backend or representation comparison across platforms.
- `Prepared-input ceiling`: prepared-input rows that move JPEG decode and, for
  fp16, normalization offline.
- `Prepared-tensor transport`: prepared fp16 block rows comparing PyTorch CPU
  mmap with DALI NumPy GPU/cuFile transport.
- `Reference`: mechanism or context page outside the main reading path.

## B200 Studies

| Study | Input | Backend | What It Tests | Role | Results |
| --- | --- | --- | --- | --- | --- |
| [B200 single-GPU surface](studies/b200-single-gpu-surface.md) | `canonical-224` | PyTorch CPU | Batch, worker, and prefetch plateau on one GPU. | Hardware progression | [Results](studies/b200-single-gpu-surface.md#result-summary) |
| [B200 one-node 8-GPU replicated](studies/b200-single-node-replicated.md) | `canonical-224` | PyTorch CPU | Worker count selection across eight replicated ranks. | Hardware progression | [Results](studies/b200-single-node-replicated.md#result-summary) |
| [B200 multi-node parameter selection](studies/b200-multinode-dataloader.md) | `canonical-224` | PyTorch CPU, sharded | Two- and four-node parameter selection before the scale study. | Hardware progression | [Results](studies/b200-multinode-dataloader.md#result-summary) |
| [B200 2-16-node scale study](studies/b200-multinode-scale-probe.md) | `canonical-224` | PyTorch CPU, sharded | Per-node throughput and rank balance through sixteen nodes. | Hardware progression | [Results](studies/b200-multinode-scale-probe.md#result-summary) |

## RTX Studies

| Study | Input | Backend | What It Tests | Role | Results |
| --- | --- | --- | --- | --- | --- |
| [RTX single-GPU surface](studies/rtx-single-gpu-surface.md) | `canonical-224` | PyTorch CPU | Batch, worker, and prefetch plateau on one GPU. | Hardware progression | [Results](studies/rtx-single-gpu-surface.md#result-summary) |
| [RTX one-node 8-GPU replicated](studies/rtx-single-node-replicated.md) | `canonical-224` | PyTorch CPU | Worker, batch, and prefetch selection across eight ranks. | Hardware progression | [Results](studies/rtx-single-node-replicated.md#result-summary) |
| [RTX multi-node parameter selection](studies/rtx-multinode-dataloader.md) | `canonical-224` | PyTorch CPU, sharded | Two- and four-node parameter selection before the scale study. | Hardware progression | [Results](studies/rtx-multinode-dataloader.md#result-summary) |
| [RTX 2-8-node scale study](studies/rtx-multinode-scale-probe.md) | `canonical-224` | PyTorch CPU, sharded | Per-node throughput and rank balance through eight nodes. | Hardware progression | [Results](studies/rtx-multinode-scale-probe.md#result-summary) |

## Cross-Platform Studies

These studies contain B200 and RTX rows in the same page. They support the
platform progressions above but are not separate platform-specific study pages.

DALI JPEG rows cover JPEG decode and input-pipeline behavior. Prepared-tensor
GPU/cuFile pages cover blocked tensor transport, and related DDP pages cover
training-throughput results for the same prepared input representation.

| Study | Platform Scope | Input | Backend | What It Tests | Role | Results |
| --- | --- | --- | --- | --- | --- | --- |
| [DALI standard-ImageNet optimization](studies/dali-standard-imagenet-optimization.md) | B200, RTX | `canonical-224` | DALI GPU decode | DALI versus tuned CPU at ordinary ImageNet shape. | Backend comparison | [Results](studies/dali-standard-imagenet-optimization.md#result-summary) |
| [DALI large-JPEG optimization](studies/dali-large-image-optimization.md) | B200, RTX | `derived-jpeg-1024` | DALI GPU decode | DALI batch, thread, and queue-depth tuning for large JPEG input. | Backend comparison | [Results](studies/dali-large-image-optimization.md#result-summary) |
| [Tuned backend crossover](studies/optimized-backend-crossover.md) | B200, RTX | `canonical-224`, `derived-jpeg-1024` | PyTorch CPU and DALI | Where the tuned backend choice changes by input size. | Backend comparison | [Results](studies/optimized-backend-crossover.md#result-summary) |
| [Prepared-input ceilings](studies/prepared-input-ceilings.md) | B200, RTX | `prepared-input-ceiling` | NumPy uint8/fp16 | Throughput after moving decode or preprocessing offline. | Prepared-input ceiling | [Results](studies/prepared-input-ceilings.md#result-summary) |
| [Fixed-config DALI crossover](studies/backend-dali-crossover.md) | B200, RTX | `derived-jpeg` size ladder | PyTorch CPU and DALI | Derived pre-resized JPEG representation results; explains why DALI can win on derived `224` while CPU still wins canonical ImageNet. | Reference | [Results](studies/backend-dali-crossover.md#result-summary) |

## Prepared-Tensor GPU/cuFile Transport

These are DataLoader-only prepared-block transport studies. They belong in the
DataLoader module because they compare input-reader paths before training. The
DDP module reports related training-throughput results.

| Study | Platform Scope | Input | Backend | What It Tests | Role | Results |
| --- | --- | --- | --- | --- | --- | --- |
| [B200 prepared-tensor GPU/cuFile transport](studies/b200-prepared-tensor-gds-transport.md) | B200 | `numpy-fp16-blocks` | PyTorch mmap blocks and DALI NumPy GPU/cuFile | B200 DataLoader size ladder for prepared fp16 block transport. | Prepared-tensor transport | [Results](studies/b200-prepared-tensor-gds-transport.md#result-summary) |
| [RTX prepared-tensor GPU/cuFile transport](studies/rtx-prepared-tensor-gds-transport.md) | RTX | `numpy-fp16-blocks` | PyTorch mmap blocks and DALI NumPy GPU/cuFile | RTX one-node `256`/`384`/`512` size ladder plus `size=512` block-size sensitivity. | Prepared-tensor transport | [Results](studies/rtx-prepared-tensor-gds-transport.md#result-summary) |

## Reference Pages

| Reference | What It Contains |
| --- | --- |
| [Input Pipeline Reference](input-pipeline-reference.md) | Metric names, input-path diagrams, DALI versus CPU interpretation, prepared-input tradeoffs, and related DDP links. |
| [Derived ImageNet Datasets](derived-datasets.md) | How derived JPEG and NumPy datasets are created, what they are for, and how to preview or submit the preparation job. |
| [Where the input work lives](studies/input-representations.md) | Gateway reference for DataLoader input representations and storage, CPU, H2D, GPU, prepared-input, and DDP data paths. |
| [Appendix: DataLoader Input Pipeline Lab](studies/input-pipeline-lab.md) | Combined input-representation study with shorter-run context. |
| [Synthetic large JPEG decode stress appendix](studies/synthetic-large-jpeg-decode-stress.md) | Decode-pressure interpretation for large compressed JPEG rows, separate from canonical ImageNet evidence. |
