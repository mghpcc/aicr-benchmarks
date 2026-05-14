# NCCL Studies

Purpose: list NCCL studies and their artifact bundles.

One-node communication checks use local mode. RDMA studies compare explicit
multi-node groups.

## B200 Studies

### Local Mode

| Study | Shape | Artifact bundle |
| --- | --- | --- |
| [Default local B200](studies/local-b200-default.md) | one node, default local suite | `nccl-b200-local-suite-2026-05-10.tar.gz` |
| [B200 single-process 8-GPU](studies/local-b200-1proc8g.md) | one process using 8 GPUs | `nccl-b200-local-suite-2026-05-10.tar.gz` |
| [B200 two-rank socket split](studies/local-b200-2rank-socket4g.md) | two ranks split by socket, 4 GPUs each | `nccl-b200-local-suite-2026-05-10.tar.gz` |

### RDMA

| Study | Shape | Artifact bundle |
| --- | --- | --- |
| [B200 RDMA ladder](studies/b200-rdma-ladder.md) | clean-prefix `2,4,8,16` nodes, `PROFILE=medium`, `REPEAT_COUNT=12`, olympic | `nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12.tar.gz` |
| [B200 31-node RDMA result](studies/b200-rdma-31-node-clean-prefix.md) | clean-prefix `31` nodes, `PROFILE=medium`, `REPEAT_COUNT=12`, olympic | `nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12.tar.gz` |

## RTX Studies

### Local Mode

| Study | Shape | Artifact bundle |
| --- | --- | --- |
| [Default local RTX](studies/local-rtx-default.md) | one node, default local suite | `nccl-rtx-local-suite-2026-05-10.tar.gz` |
| [RTX pair policy](studies/local-rtx-pair-policy.md) | one node, pair-policy local suite | `nccl-rtx-local-suite-2026-05-10.tar.gz` |

### RDMA

| Study | Shape | Artifact bundle |
| --- | --- | --- |
| [RTX RDMA ladder](studies/rtx-rdma-ladder.md) | clean-prefix `2,4,8` nodes, `PROFILE=medium`, `REPEAT_COUNT=12`, olympic | `nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12.tar.gz` |
