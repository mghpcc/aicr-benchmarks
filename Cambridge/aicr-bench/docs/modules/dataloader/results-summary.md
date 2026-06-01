# DataLoader Results Summary

Purpose: summarize the published DataLoader findings before readers dive into
individual study pages.

On B200 and RTX Pro 6000, the `canonical-224` ImageNet DataLoader evidence
favors the tuned PyTorch CPU DataLoader, while the `derived-jpeg-1024`
evidence favors tuned DALI as the strongest measured input-side path. These
are input-pipeline results; DDP pages report the corresponding ResNet-50
training throughput.

The canonical studies use `canonical-224` ImageNet input to choose PyTorch CPU
DataLoader settings across one GPU, one node, and multi-node shapes. Supporting
studies explain when DALI, derived JPEG input, and prepared NumPy inputs become
useful.

The `224` DALI win in the fixed-config crossover is for derived pre-resized
JPEG input, not canonical ImageNet. Canonical ImageNet still favors the tuned
PyTorch CPU DataLoader in the standard ImageNet DALI study.

## Headline Findings

| Finding | Evidence |
| --- | --- |
| For `canonical-224` ImageNet on these platforms, start with tuned PyTorch CPU DataLoader. | At standard ImageNet shape, DALI reached `0.44x` of the B200 CPU anchor and `0.41x` of the RTX CPU anchor in the DataLoader-only DALI study. [Results](studies/dali-standard-imagenet-optimization.md#artifact-bundle) |
| DALI becomes useful for large derived JPEG input. | At `derived-jpeg-1024`, tuned DALI reached `49,911 samples/s` on B200 and `49,257 samples/s` on RTX; the optimized crossover showed DALI/CPU of `3.11x` on B200 and `2.95x` on RTX. [Results](studies/optimized-backend-crossover.md#artifact-bundle) |
| B200 canonical DataLoader throughput scales through sixteen nodes. | The B200 scale study reached `584,032 samples/s` at sixteen nodes with `batch=384`, `workers=16`, and `prefetch=6`. [Results](studies/b200-multinode-scale-probe.md#artifact-bundle) |
| RTX canonical DataLoader throughput scales through eight nodes. | The RTX scale study reached `338,146 samples/s` at eight nodes with `batch=512`, `workers=16`, and `prefetch=4`. [Results](studies/rtx-multinode-scale-probe.md#artifact-bundle) |
| Prepared NumPy fp16 inputs show the effect of moving preprocessing offline. | Prepared fp16 improved over prepared uint8 by `2.15x` to `2.75x` on B200 and `2.09x` to `2.77x` on RTX Pro 6000 across `224` to `1024`; DDP pages report the matching training-throughput results. [Results](studies/prepared-input-ceilings.md#artifact-bundle) |

## Canonical DataLoader Progression

| Platform | Selected one-node row | Multi-node reading | Study |
| --- | --- | --- | --- |
| B200 | `45,954 samples/s`, `768/16/4`, `4.19%` rank imbalance | Best sixteen-node row is `384/16/6` at `584,032 samples/s`; per-node throughput tapers to `36,502 samples/s/node`. | [B200 scale study](studies/b200-multinode-scale-probe.md) |
| RTX Pro 6000 | `48,974 samples/s`, `768/16/6`, `4.39%` rank imbalance | Best eight-node row is `512/16/4` at `338,146 samples/s`; the best balance row is `640/16/4`. | [RTX scale study](studies/rtx-multinode-scale-probe.md) |

## Backend And Input Representation

| Input | Best public reading |
| --- | --- |
| `canonical-224` | Start with tuned PyTorch CPU DataLoader. DALI did not amortize its pipeline overhead at ordinary ImageNet shape in the DataLoader-only loop. |
| `derived-jpeg-1024` | Use DALI as the strongest measured input-side path. The fixed-config derived-JPEG ladder shows DALI's advantage is modest at derived `224`, material by `512`, and large by `1024`; the optimized endpoint study then reports the tuned `1024` DALI result. |
| `prepared-input-ceiling` | Use NumPy uint8/fp16 rows to see how much online decode and preprocessing can be removed. DDP pages report the matching training-throughput results. |
| `numpy-fp16-blocks` | Use DataLoader-only prepared-block rows to compare the CPU-safe PyTorch mmap block reader with DALI NumPy GPU/cuFile transport. B200 has a size ladder; RTX has a one-node `256`/`384`/`512` ladder plus `size=512` block-size sensitivity. |
| `decode-stress` | Use for JPEG decode-pressure interpretation. |

## Prepared-Tensor GPU/cuFile Transport

Prepared-tensor GPU/cuFile rows compare DALI's NumPy GPU/cuFile reader with a
CPU-side PyTorch mmap reader over the same prepared fp16 block layout.

| Platform | DataLoader result | Related DDP study |
| --- | --- | --- |
| B200 | The [B200 prepared-tensor transport ladder](studies/b200-prepared-tensor-gds-transport.md) shows DALI NumPy GPU/cuFile ahead of PyTorch mmap at `256`, `384`, and `1024`, with `512` effectively tied. | [B200 prepared-tensor pilot](../ddp/studies/prepared-tensor-gds-transport.md) and [B200 prepared-tensor scale study](../ddp/studies/prepared-tensor-gds-scale-followup.md). |
| RTX Pro 6000 | The [RTX prepared-tensor transport ladder](studies/rtx-prepared-tensor-gds-transport.md) shows DALI NumPy GPU/cuFile ahead of PyTorch mmap at `256`, modestly ahead at `384`, and effectively tied at `512`. A `size=512` block-size sensitivity check found that `numpy_block_size=128` and `64` did not reopen a DALI lead, so the ladder still stops at `512`. | [RTX prepared-tensor transport study](../ddp/studies/rtx-prepared-tensor-gds-transport.md). |

## Training Results

Input-pipeline throughput and training throughput are reported separately:

### One-Node DDP Training

- For ordinary ImageNet shape, the tuned CPU path remains slightly ahead in
  one-node DDP: B200 `33,114` images/s versus DALI `31,980`, and RTX `18,502`
  images/s versus DALI `17,979`.
- For `derived-jpeg-1024`, DALI remains strong in one-node DDP: B200 `30,480`
  images/s versus CPU `6,431`, and RTX `16,484` images/s versus CPU `5,504`.

### Multi-Node DDP Scaling

- Multi-node DDP reports scale behavior and DALI queue-depth sensitivity.

For training-throughput results, see the
[DDP one-node DataLoader comparison](../ddp/studies/dataloader-candidate-followup.md) and
[DDP multi-node scale study](../ddp/studies/multinode-scale-validation.md)
pages. Read [DataLoader Studies](studies.md) for the full DataLoader evidence
index.

## References

- [Input Pipeline Reference](input-pipeline-reference.md) explains metric names,
  input labels, DALI interpretation, prepared-input tradeoffs, and related DDP
  studies.
- [Derived ImageNet Datasets](derived-datasets.md) documents how derived JPEG
  and NumPy datasets are created and when they should be used.
