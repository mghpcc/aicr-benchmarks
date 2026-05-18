# NCCL B200 31-node RDMA Result

<!-- aicr-study-status: published -->


Purpose: May 12, 2026 B200 31-node medium-profile NCCL RDMA result.

## Run Shape

| Field | Value |
| --- | --- |
| Cluster | `b200` |
| Profile | `medium` |
| Node group | `31` |
| Repeat count | `12` |
| Aggregation | `olympic` |
| Headline bandwidth | largest-message `busbw` in GB/s |
| Source commit | `b01c7cc` |
| Validation | completed `12/12`, passed `12/12`, `wrong=0` |

The olympic center drops one lowest and one highest passed numeric sample for
each collective, then averages the retained ten samples.

## Command Run

The 31-node run used the B200 RDMA Slurm wrapper with one MPI rank per GPU.

[submit-nccl-suite.sh](../../../../man/submit-nccl-suite.md):

```bash
scripts/verify/submit-nccl-suite.sh \
  --scope rdma \
  --cluster b200 \
  --profile medium \
  --nodes b0001,b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031 \
  --nodes-per-job 31 \
  --repeat-count 12 \
  --repeat-aggregation olympic \
  --apply
```

## Result Summary

| Nodes | GPUs | Samples | Passes | Status | AR Olympic avg (GB/s) | RS Olympic avg (GB/s) | AG Olympic avg (GB/s) | A2A Olympic avg (GB/s) | Wrong |
| ---: | ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 31 | 248 | `12/12` | `12/12` | `passed` | 204.612 | 205.307 | 205.082 | 25.836 | 0 |

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### Rows Needing Review

- None

### Group Rows

| Node Group | Nodes | GPUs | Samples | Passes | Status | AR Olympic avg (GB/s) | AR min..max (GB/s) | AR drop min/max (GB/s) | RS Olympic avg (GB/s) | RS min..max (GB/s) | RS drop min/max (GB/s) | AG Olympic avg (GB/s) | AG min..max (GB/s) | AG drop min/max (GB/s) | A2A Olympic avg (GB/s) | A2A min..max (GB/s) | A2A drop min/max (GB/s) | Wrong | Aggregation | Jobs |
| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- | ---: | --- | --- |
| `b0001,b0002,b0003,b0004,b0005,b0006,b0007,b0008,b0009,b0010,b0011,b0012,b0013,b0014,b0015,b0016,b0017,b0018,b0019,b0020,b0021,b0022,b0023,b0024,b0025,b0026,b0027,b0028,b0029,b0030,b0031` | 31 | 248 | 12/12 | 12/12 | `passed` | 204.612 | 203.820..204.940 | 203.820/204.940 | 205.307 | 205.070..205.810 | 205.070/205.810 | 205.082 | 204.920..205.470 | 204.920/205.470 | 25.836 | 25.830..25.840 | 25.830/25.840 | 0 | olympic avg | `18081,18082,18083,18084,18085,18086,18087,18088,18089,18090,18091,18092` |

Bandwidth columns are largest-message `busbw` in GB/s. Olympic avg columns
aggregate passed samples for the node group. See
[Stats Explained](../../../stats-explained.md) for repeat aggregation and
min/max definitions.

</details>

## Artifact Bundle

This study shares one collection-day artifact bundle with the
[B200 RDMA ladder](b200-rdma-ladder.md) and
[RTX RDMA ladder](rtx-rdma-ladder.md).

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
