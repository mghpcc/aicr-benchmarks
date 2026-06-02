# DDP Results Summary

Purpose: summarize the public ResNet-50 DDP findings and link each claim to
the underlying study evidence.

DDP measures selected input-pipeline candidates inside fixed-iteration
ResNet-50 training, including model compute, backward pass, optimizer work,
rank timing, distributed sharding, gradient communication, and rank
synchronization.

For the input-side candidate selection that precedes these rows, read the
[DataLoader Results Summary](../dataloader/results-summary.md) first; this
page reports the training-throughput validation.

## Headline Findings

| Finding | Evidence |
| --- | --- |
| At `canonical-224` ImageNet shape, tuned PyTorch CPU DataLoader remains the best real-input training path. | One-node DDP training reached `33,114` images/s on B200 and `18,502` images/s on RTX Pro 6000, slightly ahead of DALI on both platforms. [Results](studies/dataloader-candidate-followup.md#result-summary) |
| At `derived-jpeg-1024`, DALI remains the strongest measured training candidate. | One-node DDP training reached `30,480` images/s on B200 and `16,484` images/s on RTX Pro 6000 with DALI, versus `6,431` and `5,504` images/s with PyTorch CPU. [Results](studies/dataloader-candidate-followup.md#result-summary) |
| Multi-node validation shows standard ImageNet CPU scaling and B200 DALI queue-depth sensitivity for large-JPEG rows. | Through four nodes, B200 `canonical-224` CPU reached `94,997` images/s and RTX reached `62,146`; derived `1024` DALI queue-depth `1` reached `78,007` on B200 and `61,352` on RTX. [Results](studies/multinode-scale-validation.md#result-summary) |
| Prepared-input rows are ceiling evidence. | At `224`, NumPy fp16 reached `27,590` images/s on B200 and `16,415` on RTX, below the tuned CPU DataLoader training anchors. [Results](studies/input-ceilings.md#result-summary) |
| Synthetic large-JPEG training measures decode-stress behavior. | For compressed large-image inputs, DALI cuts input wait and improves training throughput; the claim is scoped to that decode-stress workload. [Results](studies/synthetic-large-jpeg-training.md#result-summary) |

## One-Node Training

The one-node validation compares the selected DataLoader candidates after they
enter ResNet-50 DDP training. It reports canonical and derived endpoints
separately:

| Platform | Endpoint | PyTorch CPU images/s | DALI images/s | Reading |
| --- | --- | ---: | ---: | --- |
| B200 | `canonical-224` | `33,114` | `31,980` | CPU remains ahead. |
| B200 | `derived-jpeg-1024` | `6,431` | `30,480` | DALI wins by `4.74x`. |
| RTX Pro 6000 | `canonical-224` | `18,502` | `17,979` | CPU remains slightly ahead. |
| RTX Pro 6000 | `derived-jpeg-1024` | `5,504` | `16,484` | DALI wins by `3.00x`. |

The multi-node scale validation reports how the same candidates behave beyond
one node.

## Multi-Node Scaling

| Platform | Candidate | 1 node img/s | 2 node img/s | 4 node img/s | 4-node efficiency | Reading |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| B200 | ImageNet `224` PyTorch CPU | `33,114` | `57,780` | `94,997` | `72%` | Scales usefully, with expected per-node taper. |
| B200 | Derived `1024` JPEG DALI qd1 | `31,536` | `60,071` | `78,007` | `62%` | Queue-depth tuning corrects the earlier B200 input-wait pattern through four nodes. |
| RTX Pro 6000 | ImageNet `224` PyTorch CPU | `18,502` | `34,323` | `62,146` | `84%` | Scales cleanly through `4` nodes. |
| RTX Pro 6000 | Derived `1024` JPEG DALI qd1 | `16,484` | `32,116` | `61,352` | `93%` | Large-JPEG DALI candidate scales cleanly. |

One-node wins identify candidates for the multi-node scale study.

## Ceilings And Branches

- [DDP input ceilings](studies/input-ceilings.md) compare prepared NumPy input
  against a synthetic GPU compute/input-free ceiling. That page is the public
  home for the current synthetic GPU ceiling rows.
- [DDP prepared-tensor GPU/cuFile transport pilot](studies/prepared-tensor-gds-transport.md)
  measures a prepared fp16 block endpoint on one B200 node. DALI NumPy
  GPU/cuFile reached `33,799` images/s versus `17,471` for PyTorch CPU mmap on
  the same block layout. The DALI row uses synthetic GPU labels. The result is
  prepared-tensor transport evidence, separate from canonical ImageNet JPEG and
  DALI JPEG/GDS evidence.
- [DDP prepared-tensor GPU/cuFile scale follow-up](studies/prepared-tensor-gds-scale-followup.md)
  measures the same B200 prepared-block endpoint beyond one node. The `spc=64`
  ladder shows DALI NumPy GPU/cuFile faster than the PyTorch CPU mmap block
  comparator at one, two, four, and eight B200 nodes. The separate five-repeat
  `spc=128` one-, two-, four-, eight-, and sixteen-node ladder shows DALI NumPy
  GPU/cuFile faster than the PyTorch CPU mmap block comparator at every node
  count (`1.64x`, `2.02x`, `2.59x`, `4.03x`, and `7.24x`), with per-rank
  PyTorch CPU mmap dropping more sharply than per-rank DALI NumPy GPU/cuFile
  across that ladder. The `spc=64` and `spc=128` ladders are separate
  prepared-fp16 tensor transport evidence, with synthetic GPU labels for the
  DALI rows.
- [DDP RTX prepared-tensor GPU/cuFile transport study](studies/rtx-prepared-tensor-gds-transport.md)
  measures the prepared-block endpoint on RTX Pro 6000. Five-repeat one-node
  `1.385x`, two-node `1.571x`, four-node `2.108x`, and eight-node `4.094x`
  `100/500` DDP medians show a DALI NumPy GPU/cuFile advantage over the
  PyTorch CPU mmap block comparator at this prepared fp16 tensor transport
  endpoint. The DALI rows use synthetic GPU labels, and eight-node GDS runs
  include sixty-four rank-local cuFile logs.
- [DDP synthetic large JPEG training](studies/synthetic-large-jpeg-training.md)
  explains large compressed-image decode pressure under training.

## Read Next

Start with the DataLoader
[Results Summary](../dataloader/results-summary.md) and
[optimized backend crossover](../dataloader/studies/optimized-backend-crossover.md)
for the input-side candidate selection. Then use
[DDP Studies](studies.md) as the complete training-throughput evidence index.
