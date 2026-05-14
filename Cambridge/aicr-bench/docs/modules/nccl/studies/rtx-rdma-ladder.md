# NCCL RTX RDMA Ladder

<!-- aicr-study-status: published -->


Purpose: May 12, 2026 RTX PRO 6000 medium-profile NCCL RDMA ladder results.

## Run Shape

| Field | Value |
| --- | --- |
| Cluster | `rtxpro6000` |
| Profile | `medium` |
| Node groups | `2,4,8` |
| Repeat count | `12` |
| Aggregation | `olympic` |
| Headline bandwidth | largest-message `busbw` in GB/s |
| Source commit | `b01c7cc` |
| Validation | every node group completed `12/12`, passed `12/12`, `wrong=0` |

The olympic center drops one lowest and one highest passed numeric sample for
each node group and collective, then averages the retained ten samples.

## Command Run

The campaign used `scripts/verify/submit-nccl-fleet.sh` from the
checkout. Each node group was submitted as a fixed-node RDMA job with one MPI
rank per GPU.

```bash
scripts/verify/submit-nccl-fleet.sh \
  --scope rdma \
  --cluster rtxpro6000 \
  --profile medium \
  --nodes <explicit-node-list> \
  --nodes-per-job <2|4|8> \
  --repeat-count 12 \
  --repeat-aggregation olympic \
  --submit-stagger-seconds 0 \
  --round-stagger-seconds 0 \
  --apply
```

| Nodes per job | Node list |
| ---: | --- |
| 2 | `a0001,a0002` |
| 4 | `a0001,a0002,a0003,a0004` |
| 8 | `a0001,a0002,a0003,a0004,a0005,a0006,a0007,a0008` |

## Result Summary

| Nodes | GPUs | Samples | Passes | Status | AR Olympic avg (GB/s) | RS Olympic avg (GB/s) | AG Olympic avg (GB/s) | A2A Olympic avg (GB/s) | Wrong |
| ---: | ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 2 | 16 | `12/12` | `12/12` | `passed` | 24.480 | 24.200 | 24.653 | 13.398 | 0 |
| 4 | 32 | `12/12` | `12/12` | `passed` | 24.381 | 24.231 | 24.567 | 11.750 | 0 |
| 8 | 64 | `12/12` | `12/12` | `passed` | 24.382 | 24.250 | 24.494 | 11.051 | 0 |

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### Rows Needing Review

- None

### Group Rows

| Node Group | Nodes | GPUs | Samples | Passes | Status | AR Olympic avg (GB/s) | AR min..max (GB/s) | AR drop min/max (GB/s) | RS Olympic avg (GB/s) | RS min..max (GB/s) | RS drop min/max (GB/s) | AG Olympic avg (GB/s) | AG min..max (GB/s) | AG drop min/max (GB/s) | A2A Olympic avg (GB/s) | A2A min..max (GB/s) | A2A drop min/max (GB/s) | Wrong | Aggregation | Jobs |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |
| `a0001,a0002` | 2 | 16 | 12/12 | 12/12 | `passed` | 24.480 | 24.410..24.580 | 24.410/24.580 | 24.200 | 24.110..24.330 | 24.110/24.330 | 24.653 | 24.510..24.800 | 24.510/24.800 | 13.398 | 13.360..13.430 | 13.360/13.430 | 0 | olympic avg | `18099,18108,18117,18126,18135,18144,18153,18162,18171,18180,18189,18198` |
| `a0001,a0002,a0003,a0004` | 4 | 32 | 12/12 | 12/12 | `passed` | 24.381 | 24.260..24.520 | 24.260/24.520 | 24.231 | 24.050..24.350 | 24.050/24.350 | 24.567 | 24.390..24.700 | 24.390/24.700 | 11.750 | 11.650..11.810 | 11.650/11.810 | 0 | olympic avg | `18100,18109,18118,18127,18136,18145,18154,18163,18172,18181,18190,18199` |
| `a0001,a0002,a0003,a0004,a0005,a0006,a0007,a0008` | 8 | 64 | 12/12 | 12/12 | `passed` | 24.382 | 24.280..24.520 | 24.280/24.520 | 24.250 | 24.110..24.340 | 24.110/24.340 | 24.494 | 24.260..24.690 | 24.260/24.690 | 11.051 | 10.830..11.140 | 10.830/11.140 | 0 | olympic avg | `18101,18110,18119,18128,18137,18146,18155,18164,18173,18182,18191,18200` |

Bandwidth columns are largest-message `busbw` in GB/s. Olympic avg columns
aggregate passed samples for each node group. See
[Stats Explained](../../../stats-explained.md) for repeat aggregation and
min/max definitions.

</details>

## Artifact Bundle

This study shares one collection-day artifact bundle with the
[B200 RDMA ladder](b200-rdma-ladder.md) and
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
