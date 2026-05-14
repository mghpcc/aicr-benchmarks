# DataLoader Studies

Purpose: collect DataLoader input-pipeline studies for B200 and RTX.

## Metric Names

DataLoader reports use a few similar throughput names:

- `H2D samples/s`: host-to-device transfer throughput. When this is much higher
  than `samples/s`, H2D transfer is probably not the limiting step.
- `load samples/s`: DataLoader/input-pipeline throughput before the GPU/H2D
  portion of the measured path. Use it to see whether workers, prefetch, and
  storage reads are helping the input side.
- `rank_imbalance_percent`: multi-rank spread across workers/ranks. This is not
  meaningful for single-GPU runs; it becomes important in one-node 8-GPU and
  multi-node studies.
- `samples/s`: end-to-end benchmark throughput for the measured loop. This is
  the headline number for comparing configurations.

See [Stats Explained](../../stats-explained.md) for shared aggregation terms
such as Olympic average, jitter, and coefficient of variation.

## B200 Studies

| Study | Scope |
| --- | --- |
| [B200 single-GPU surface](studies/b200-single-gpu-surface.md) | Candidate batch, worker, and prefetch settings for B200. |
| [B200 one-node 8-GPU replicated](studies/b200-single-node-replicated.md) | B200 finalist settings with eight ranks on one node. |
| [B200 multi-node parameter selection](studies/b200-multinode-dataloader.md) | 2-node and 4-node distributed-sharded parameter selection. |
| [B200 2/4/8/16-node scale probe](studies/b200-multinode-scale-probe.md) | 2/4/8/16-node comparison using `samples/s/node` and rank balance. |

## RTX Studies

| Study | Scope |
| --- | --- |
| [RTX single-GPU surface](studies/rtx-single-gpu-surface.md) | Candidate batch, worker, and prefetch settings for RTX. |
| [RTX one-node 8-GPU replicated](studies/rtx-single-node-replicated.md) | RTX finalist settings with eight ranks on one node. |
| [RTX multi-node parameter selection](studies/rtx-multinode-dataloader.md) | 2-node and 4-node distributed-sharded parameter selection. |
| [RTX 2/4/8-node scale probe](studies/rtx-multinode-scale-probe.md) | 2/4/8-node comparison using `samples/s/node` and rank balance. |
