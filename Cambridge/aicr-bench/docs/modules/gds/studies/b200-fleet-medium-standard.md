# GDS B200 Fleet medium standard

Purpose: Repeated medium-profile fleet teaching run with standard aggregation.

This published study is teaching and support evidence for the public AICR-Bench workflow. It is not benchmark certification evidence.

## Command Run

```bash
make verify-gds CLUSTER=b200 PROFILE=medium NODELIST=b0002 GDS_REPEAT_COUNT=3 APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `b200`
- Profile: `medium`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `b0002`
- Slurm jobs: `16540, 16542, 16543`
- Run IDs: `221749Z-r01, 222731Z-r01, 223238Z-r01`
- Result: all promoted rows/jobs in this study passed.
- Focus: Standard repeated-run aggregation for one selected B200 node.

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.provenance.json>
- SHA-256: `b3a9bcfb890d106347fe48b0005b66adb5a5846cea2a2fe9aa15dcd176436887`
- Bundle size: `9856` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-b200-fleet-medium-standard
cd public-study-artifacts/gds-b200-fleet-medium-standard
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-standard-2026-05-10.provenance.json
printf "%s  %s\n" "b3a9bcfb890d106347fe48b0005b66adb5a5846cea2a2fe9aa15dcd176436887" "gds-b200-fleet-medium-standard-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-b200-fleet-medium-standard-2026-05-10.tar.gz | head
```

The matching provenance file is `gds-b200-fleet-medium-standard-2026-05-10.provenance.json`.

## Generated Artifacts

<details>
<summary>Full generated artifact list from provenance</summary>

- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/221749Z-r01/status.json` (66 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/221749Z-r01/summary.json` (10405 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/222731Z-r01/status.json` (66 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/222731Z-r01/summary.json` (10407 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/223238Z-r01/status.json` (66 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/223238Z-r01/summary.json` (10407 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/221749Z-r01/canonical/gds-summary.txt` (3740 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/221749Z-r01/canonical/gdscheck-platform.txt` (4003 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/221749Z-r01/canonical/gdsio-random-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/221749Z-r01/canonical/gdsio-random-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/221749Z-r01/canonical/gdsio-sequential-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/221749Z-r01/canonical/gdsio-sequential-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/221749Z-r01/canonical/nvidia-smi-L.txt` (544 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/221749Z-r01/canonical/nvidia-smi-topo-m.txt` (3016 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/221749Z-r01/metadata/record.json` (2044 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/221749Z-r01/wrapper/cufile.log` (0 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/222731Z-r01/canonical/gds-summary.txt` (3742 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/222731Z-r01/canonical/gdscheck-platform.txt` (4003 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/222731Z-r01/canonical/gdsio-random-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/222731Z-r01/canonical/gdsio-random-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/222731Z-r01/canonical/gdsio-sequential-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/222731Z-r01/canonical/gdsio-sequential-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/222731Z-r01/canonical/nvidia-smi-L.txt` (544 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/222731Z-r01/canonical/nvidia-smi-topo-m.txt` (3016 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/222731Z-r01/metadata/record.json` (2044 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/222731Z-r01/wrapper/cufile.log` (0 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223238Z-r01/canonical/gds-summary.txt` (3746 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223238Z-r01/canonical/gdscheck-platform.txt` (4003 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223238Z-r01/canonical/gdsio-random-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223238Z-r01/canonical/gdsio-random-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223238Z-r01/canonical/gdsio-sequential-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223238Z-r01/canonical/gdsio-sequential-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223238Z-r01/canonical/nvidia-smi-L.txt` (544 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223238Z-r01/canonical/nvidia-smi-topo-m.txt` (3016 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223238Z-r01/metadata/record.json` (2044 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223238Z-r01/wrapper/cufile.log` (0 bytes)
- `results/reports/2026-05-10/gds/221746Z-gds-b200.json` (1392 bytes)
- `results/reports/2026-05-10/gds/gds-b200-fleet-medium-standard-dashboard.md` (2095 bytes)
- `results/slurm/b200-gds-1n-8g-16540.err` (0 bytes)
- `results/slurm/b200-gds-1n-8g-16540.out` (358 bytes)
- `results/slurm/b200-gds-1n-8g-16542.err` (0 bytes)
- `results/slurm/b200-gds-1n-8g-16542.out` (358 bytes)
- `results/slurm/b200-gds-1n-8g-16543.err` (0 bytes)
- `results/slurm/b200-gds-1n-8g-16543.out` (358 bytes)

</details>

## Dashboard Snapshot

Copied from `results/reports/2026-05-10/gds/gds-b200-fleet-medium-standard-dashboard.md` in the artifact bundle.

# GDS b200 2026-05-10

- Check: `gds`
- Cluster: `b200`
- Partition: `GPU2`
- Discovery time: `2026-05-10T22:17:46Z`
- Mode: `apply`
- GDS profile: `medium`
- Time limit: `01:00:00`
- Repeat count: `3`
- Repeat aggregation: `standard`
- Round stagger seconds: `0`

| Node | Slurm | Samples | Passes | Status | Sequential Read med | Sequential Read min..max | Sequential Write med | Sequential Write min..max | Random Read med | Random Read min..max | Random Write med | Random Write min..max | Aggregation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | idle | 3/3 | 3/3 | passed | 9.502 | 9.337..9.602 | 7.267 | 7.221..7.375 | 0.238 | 0.218..0.245 | 0.070 | 0.070..0.073 | - |

Median columns aggregate passed numeric samples for each node.

## GDS Statistics

Only passed rows with numeric throughput values are included. Mean shows the overall level; median and MAD are preferred for anomaly detection because severe outliers can distort standard deviation.
See [Stats Explained](../../../stats-explained.md) for definitions of Mean, Median, StdDev, percentiles, MAD, CV, Delta, and Robust Z.

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 9.502 | 9.502 | 0.000 | 9.502 | 9.502 | 9.502 | 9.502 | 9.502 | 9.502 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 7.267 | 7.267 | 0.000 | 7.267 | 7.267 | 7.267 | 7.267 | 7.267 | 7.267 | 0.000 | 0.000 |
| Random Read GiB/s | 1 | 0.238 | 0.238 | 0.000 | 0.238 | 0.238 | 0.238 | 0.238 | 0.238 | 0.238 | 0.000 | 0.000 |
| Random Write GiB/s | 1 | 0.070 | 0.070 | 0.000 | 0.070 | 0.070 | 0.070 | 0.070 | 0.070 | 0.070 | 0.000 | 0.000 |

## GDS Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. Rows below `1.0%` absolute delta are suppressed from this table. See [Stats Explained](../../../stats-explained.md) for `Delta` and `Robust Z` definitions.

(none)

## Missing/Skipped Jobs

(none)
