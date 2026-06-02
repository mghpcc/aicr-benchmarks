# DDP Studies

Purpose: collect DDP studies that test whether DataLoader input-pipeline
candidates still help in fixed-iteration ResNet-50 training.

The studies here connect DataLoader candidates to model compute, backward
pass, optimizer work, rank timing, distributed sharding, gradient
communication, and rank synchronization in the measured training loop.

For headline conclusions, start with [Results Summary](results-summary.md).

## Published Studies

Read these after the DataLoader
[Results Summary](../dataloader/results-summary.md) and
[optimized backend crossover](../dataloader/studies/optimized-backend-crossover.md).
The DDP studies measure how selected input candidates behave inside fixed-
iteration ResNet-50 training. Published DDP study rows use at least `100`
warmup iterations and `500` measured iterations.

Recommended reading order: one-node DataLoader training validation,
multi-node scale validation, input ceilings, and synthetic large-JPEG
decode-stress evidence. The ceiling pages show how close a measured path gets
to a no-input-work bound.

Evidence labels used in this path:

- `canonical-224`: ordinary ImageNet-like training shape.
- `derived-jpeg-1024`: large JPEG input candidate that still feeds the normal
  ResNet-50 crop/resize path.
- `full-res-1024`: model input size is actually `1024`, unlike JPEG rows that
  crop or resize to `224`.
- `prepared-input-ceiling`: offline-prepared NumPy input rows.
- `synthetic-gpu-ceiling`: GPU-resident synthetic input with the real input
  path removed.
- `decode-stress`: synthetic large-JPEG training evidence for decode-pressure
  behavior.

Every published row is fixed-iteration evidence with at least `100` warmup and
`500` measured iterations. Conclusions are scoped to the labeled endpoint and
input representation.

| Step | Evidence Type | Study | Scope | Results |
| ---: | --- | --- | --- | --- |
| 1 | Training validation | [DataLoader training validation](studies/dataloader-candidate-followup.md) | One-node training-throughput validation for optimized DataLoader candidates at the small and large endpoints. | [Results](studies/dataloader-candidate-followup.md#result-summary) |
| 2 | Scale validation | [DDP multi-node scale validation](studies/multinode-scale-validation.md) | Multi-node scale behavior for the same endpoint candidates, with corrected `100`/`500` replacement rows and B200 queue-depth follow-up. | [Results](studies/multinode-scale-validation.md#result-summary) |
| 3 | Ceiling | [DDP input ceilings](studies/input-ceilings.md) | Prepared-input and synthetic GPU ceiling rows for `224` and full-resolution `1024` model inputs. | [Results](studies/input-ceilings.md#result-summary) |
| 4 | Decode-stress branch | [DDP synthetic large JPEG training](studies/synthetic-large-jpeg-training.md) | Synthetic large-JPEG training branch at `1024` and `1536`; decode-stress evidence separate from canonical ImageNet. | [Results](studies/synthetic-large-jpeg-training.md#result-summary) |

## Supporting Studies

These studies cover prepared-tensor transport and related supporting evidence.
They use prepared fp16 tensor inputs and synthetic GPU labels where noted, so
their results are interpreted separately from canonical ImageNet JPEG and DALI
JPEG/GDS studies.

| Evidence Type | Study | Scope | Results |
| --- | --- | --- | --- |
| Prepared-tensor transport | [DDP prepared-tensor GPU/cuFile transport pilot](studies/prepared-tensor-gds-transport.md) | One-node B200 prepared-block DDP pilot for the DALI NumPy GPU/cuFile path. Prepared-tensor transport evidence, separate from canonical ImageNet JPEG and DALI JPEG/GDS evidence. | [Results](studies/prepared-tensor-gds-transport.md#result-summary) |
| Prepared-tensor scale | [DDP prepared-tensor GPU/cuFile scale follow-up](studies/prepared-tensor-gds-scale-followup.md) | B200 scale follow-up: same-input `spc=64` one-, two-, four-, and eight-node prepared-block ladder plus a separate five-repeat `spc=128` one-, two-, four-, eight-, and sixteen-node ladder. Prepared fp16 tensor transport evidence with synthetic GPU labels for the DALI rows and cuFile compatibility mode logged. | [Results](studies/prepared-tensor-gds-scale-followup.md#spc64-scale-follow-up) |
| Prepared-tensor transport | [DDP RTX prepared-tensor GPU/cuFile transport study](studies/rtx-prepared-tensor-gds-transport.md) | RTX prepared-block DDP study with five-repeat one-, two-, four-, and eight-node `100/500` rows. Prepared fp16 tensor transport evidence with synthetic GPU labels for the DALI rows and rank-local cuFile logs for GDS rows. | [Results](studies/rtx-prepared-tensor-gds-transport.md#result-summary-one--two--four--and-eight-node-diagnostic) |

## Reference Notes

| Page | Use |
| --- | --- |
| [Appendix reference: Synthetic GPU ceiling](studies/synthetic-gpu-ceiling.md) | Earlier synthetic-only scale context for the compute/network ceiling with the input pipeline removed. |

## How To Read These Studies

The DataLoader module answers input-side questions before training. DDP
measures whether the candidate still helps once ResNet-50 training work is in
the loop.

Keep the evidence types separate:

- DataLoader-only rows identify candidates and explain input bottlenecks.
- DDP rows test training throughput and rank behavior.
- One-node DDP training evidence and multi-node scale evidence answer separate
  questions.
- Synthetic GPU rows are ceilings.
- Repeated supporting rows can explain bottlenecks without changing the
  endpoint recommendation.

For the input-side context, start with the
[DataLoader Results Summary](../dataloader/results-summary.md) and
[optimized DataLoader backend crossover](../dataloader/studies/optimized-backend-crossover.md).
