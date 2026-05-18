# NCCL B200 RDMA Ladder

<!-- aicr-study-status: published -->


Purpose: May 12, 2026 B200 medium-profile NCCL RDMA ladder results.

## Run Shape

| Field | Value |
| --- | --- |
| Cluster | `b200` |
| Profile | `medium` |
| Node groups | `2,4,8,16` |
| Repeat count | `12` |
| Aggregation | `olympic` |
| Headline bandwidth | largest-message `busbw` in GB/s |
| Source commit | `b01c7cc` |
| Validation | every node group completed `12/12`, passed `12/12`, `wrong=0` |

The olympic center drops one lowest and one highest passed numeric sample for
each node group and collective, then averages the retained ten samples.

## Command Run

Replay the campaign with [submit-nccl-suite.sh](../../../../man/submit-nccl-suite.md)
from the checkout. Each node group is submitted as a fixed-node RDMA job with
one MPI rank per GPU.

```bash
scripts/verify/submit-nccl-suite.sh \
  --scope rdma \
  --cluster b200 \
  --profile medium \
  --nodes <explicit-node-list> \
  --nodes-per-job <2|4|8|16> \
  --repeat-count 12 \
  --repeat-aggregation olympic \
  --submit-stagger-seconds 0 \
  --round-stagger-seconds 0 \
  --apply
```

| Nodes per job | Node list |
| ---: | --- |
| 2 | `b0001,b0002` |
| 4 | `b0001,b0002,b0003,b0004` |
| 8 | `b0001,b0002,b0003,b0004,b0005,b0006,b0007,b0008` |
| 16 | `b0001,b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016` |

## Result Summary

| Nodes | GPUs | Samples | Passes | Status | AR Olympic avg (GB/s) | RS Olympic avg (GB/s) | AG Olympic avg (GB/s) | A2A Olympic avg (GB/s) | Wrong |
| ---: | ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 2 | 16 | `12/12` | `12/12` | `passed` | 399.868 | 217.261 | 217.186 | 50.467 | 0 |
| 4 | 32 | `12/12` | `12/12` | `passed` | 217.720 | 217.278 | 217.213 | 33.285 | 0 |
| 8 | 64 | `12/12` | `12/12` | `passed` | 217.835 | 215.893 | 216.128 | 28.648 | 0 |
| 16 | 128 | `12/12` | `12/12` | `passed` | 202.709 | 215.914 | 216.137 | 26.580 | 0 |

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### Rows Needing Review

- None

### Group Rows

| Node Group | Nodes | GPUs | Samples | Passes | Status | AR Olympic avg (GB/s) | AR min..max (GB/s) | AR drop min/max (GB/s) | RS Olympic avg (GB/s) | RS min..max (GB/s) | RS drop min/max (GB/s) | AG Olympic avg (GB/s) | AG min..max (GB/s) | AG drop min/max (GB/s) | A2A Olympic avg (GB/s) | A2A min..max (GB/s) | A2A drop min/max (GB/s) | Wrong | Aggregation | Jobs |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |
| `b0001,b0002` | 2 | 16 | 12/12 | 12/12 | `passed` | 399.868 | 399.770..400.010 | 399.770/400.010 | 217.261 | 217.080..217.380 | 217.080/217.380 | 217.186 | 216.900..217.340 | 216.900/217.340 | 50.467 | 50.460..50.470 | 50.460/50.470 | 0 | olympic avg | `18094,18103,18112,18121,18130,18139,18148,18157,18166,18175,18184,18193` |
| `b0001,b0002,b0003,b0004` | 4 | 32 | 12/12 | 12/12 | `passed` | 217.720 | 217.570..217.880 | 217.570/217.880 | 217.278 | 217.160..217.340 | 217.160/217.340 | 217.213 | 217.130..217.300 | 217.130/217.300 | 33.285 | 33.280..33.290 | 33.280/33.290 | 0 | olympic avg | `18095,18104,18113,18122,18131,18140,18149,18158,18167,18176,18185,18194` |
| `b0001,b0002,b0003,b0004,b0005,b0006,b0007,b0008` | 8 | 64 | 12/12 | 12/12 | `passed` | 217.835 | 217.540..218.010 | 217.540/218.010 | 215.893 | 215.590..216.140 | 215.590/216.140 | 216.128 | 215.810..216.740 | 215.810/216.740 | 28.648 | 28.640..28.650 | 28.640/28.650 | 0 | olympic avg | `18096,18105,18114,18123,18132,18141,18150,18159,18168,18177,18186,18195` |
| `b0001,b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016` | 16 | 128 | 12/12 | 12/12 | `passed` | 202.709 | 201.410..203.870 | 201.410/203.870 | 215.914 | 215.560..216.330 | 215.560/216.330 | 216.137 | 215.830..216.460 | 215.830/216.460 | 26.580 | 26.570..26.590 | 26.570/26.590 | 0 | olympic avg | `18097,18106,18115,18124,18133,18142,18151,18160,18169,18178,18187,18196` |

Bandwidth columns are largest-message `busbw` in GB/s. Olympic avg columns
aggregate passed samples for each node group. See
[Stats Explained](../../../stats-explained.md) for repeat aggregation and
min/max definitions.

</details>

## Artifact Bundle

This study shares one collection-day artifact bundle with the
[RTX RDMA ladder](rtx-rdma-ladder.md) and
[B200 31-node RDMA result](b200-rdma-31-node-clean-prefix.md).

| Field | Value |
| --- | --- |
| Study id | `nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12` |
| VAST bundle | `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/b01c7cc/nccl/2026-05-12/nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12.tar.gz` |
| VAST provenance | `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/b01c7cc/nccl/2026-05-12/nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12-provenance.json` |
| OSN bundle | <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/b01c7cc/nccl/2026-05-12/nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12.tar.gz> |
| OSN provenance | <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/b01c7cc/nccl/2026-05-12/nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12-provenance.json> |
| OSN checksum | <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/b01c7cc/nccl/2026-05-12/nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12.sha256> |
| Bundle SHA-256 | `dfaa89229f1cb5994b45f7d487e97da6f2834896c2128bb9f86641fc4956a63b` |
| Provenance SHA-256 | `be065fca24aa00476d3e6a9bd9e88903c6e1e029ab6ad5d343f0c94da4dec32a` |

## Retrieve And Verify

```bash
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/b01c7cc/nccl/2026-05-12/nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/b01c7cc/nccl/2026-05-12/nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12-provenance.json
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/b01c7cc/nccl/2026-05-12/nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12.sha256
sha256sum -c nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12.sha256
tar -tzf nccl-b200-rtx-clean-prefix-rdma-results-olympic-2026-05-12.tar.gz | head
```
