# GDS B200 Fleet medium olympic

Purpose: Repeated medium-profile fleet teaching run with olympic aggregation.

This published study is teaching and support evidence for the public AICR-Bench workflow. It is not benchmark certification evidence.

## Command Run

```bash
make verify-gds CLUSTER=b200 PROFILE=medium NODELIST=b0002 GDS_REPEAT_COUNT=5 GDS_REPEAT_AGGREGATION=olympic APPLY=1
```

## Result Summary

- Module: `gds`
- Cluster: `b200`
- Profile: `medium`
- Date: `2026-05-10`
- Source commit: `4770fd1`
- Nodes: `b0002`
- Slurm jobs: `16545, 16549, 16551, 16555, 16560`
- Run IDs: `223741Z-r01, 224243Z-r01, 224745Z-r01, 225247Z-r01, 225750Z-r01`
- Result: all promoted rows/jobs in this study passed.
- Focus: Olympic repeated-run aggregation for one selected B200 node.

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.provenance.json>
- SHA-256: `4b39fe8546b281d5e707af26d3fb9c7fa2de0fee71667222b13aa4369cb1fe85`
- Bundle size: `12972` bytes

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-b200-fleet-medium-olympic
cd public-study-artifacts/gds-b200-fleet-medium-olympic
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4770fd1/gds/2026-05-10/gds-b200-fleet-medium-olympic-2026-05-10.provenance.json
printf "%s  %s\n" "4b39fe8546b281d5e707af26d3fb9c7fa2de0fee71667222b13aa4369cb1fe85" "gds-b200-fleet-medium-olympic-2026-05-10.tar.gz" | sha256sum -c -
tar -tzf gds-b200-fleet-medium-olympic-2026-05-10.tar.gz | head
```

The matching provenance file is `gds-b200-fleet-medium-olympic-2026-05-10.provenance.json`.

## Generated Artifacts

<details>
<summary>Full generated artifact list from provenance</summary>

- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/223741Z-r01/status.json` (66 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/223741Z-r01/summary.json` (10410 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/224243Z-r01/status.json` (66 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/224243Z-r01/summary.json` (10414 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/224745Z-r01/status.json` (66 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/224745Z-r01/summary.json` (10414 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/225247Z-r01/status.json` (66 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/225247Z-r01/summary.json` (10418 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/225750Z-r01/status.json` (66 bytes)
- `results/by-date/2026-05-10/parsed/b200/nodes/b0002/gds/225750Z-r01/summary.json` (10415 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223741Z-r01/canonical/gds-summary.txt` (3744 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223741Z-r01/canonical/gdscheck-platform.txt` (4003 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223741Z-r01/canonical/gdsio-random-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223741Z-r01/canonical/gdsio-random-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223741Z-r01/canonical/gdsio-sequential-read.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223741Z-r01/canonical/gdsio-sequential-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223741Z-r01/canonical/nvidia-smi-L.txt` (544 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223741Z-r01/canonical/nvidia-smi-topo-m.txt` (3016 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223741Z-r01/metadata/record.json` (2044 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/223741Z-r01/wrapper/cufile.log` (0 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224243Z-r01/canonical/gds-summary.txt` (3749 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224243Z-r01/canonical/gdscheck-platform.txt` (4003 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224243Z-r01/canonical/gdsio-random-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224243Z-r01/canonical/gdsio-random-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224243Z-r01/canonical/gdsio-sequential-read.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224243Z-r01/canonical/gdsio-sequential-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224243Z-r01/canonical/nvidia-smi-L.txt` (544 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224243Z-r01/canonical/nvidia-smi-topo-m.txt` (3016 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224243Z-r01/metadata/record.json` (2044 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224243Z-r01/wrapper/cufile.log` (0 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224745Z-r01/canonical/gds-summary.txt` (3749 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224745Z-r01/canonical/gdscheck-platform.txt` (4003 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224745Z-r01/canonical/gdsio-random-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224745Z-r01/canonical/gdsio-random-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224745Z-r01/canonical/gdsio-sequential-read.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224745Z-r01/canonical/gdsio-sequential-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224745Z-r01/canonical/nvidia-smi-L.txt` (544 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224745Z-r01/canonical/nvidia-smi-topo-m.txt` (3016 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224745Z-r01/metadata/record.json` (2044 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/224745Z-r01/wrapper/cufile.log` (0 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225247Z-r01/canonical/gds-summary.txt` (3750 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225247Z-r01/canonical/gdscheck-platform.txt` (4003 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225247Z-r01/canonical/gdsio-random-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225247Z-r01/canonical/gdsio-random-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225247Z-r01/canonical/gdsio-sequential-read.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225247Z-r01/canonical/gdsio-sequential-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225247Z-r01/canonical/nvidia-smi-L.txt` (544 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225247Z-r01/canonical/nvidia-smi-topo-m.txt` (3016 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225247Z-r01/metadata/record.json` (2044 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225247Z-r01/wrapper/cufile.log` (0 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225750Z-r01/canonical/gds-summary.txt` (3748 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225750Z-r01/canonical/gdscheck-platform.txt` (4003 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225750Z-r01/canonical/gdsio-random-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225750Z-r01/canonical/gdsio-random-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225750Z-r01/canonical/gdsio-sequential-read.txt` (194 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225750Z-r01/canonical/gdsio-sequential-write.txt` (195 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225750Z-r01/canonical/nvidia-smi-L.txt` (544 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225750Z-r01/canonical/nvidia-smi-topo-m.txt` (3016 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225750Z-r01/metadata/record.json` (2044 bytes)
- `results/by-date/2026-05-10/raw/b200/nodes/b0002/gds/225750Z-r01/wrapper/cufile.log` (0 bytes)
- `results/reports/2026-05-10/gds/223738Z-gds-b200.json` (1827 bytes)
- `results/reports/2026-05-10/gds/gds-b200-fleet-medium-olympic-dashboard.md` (2340 bytes)
- `results/slurm/b200-gds-1n-8g-16545.err` (0 bytes)
- `results/slurm/b200-gds-1n-8g-16545.out` (358 bytes)
- `results/slurm/b200-gds-1n-8g-16549.err` (0 bytes)
- `results/slurm/b200-gds-1n-8g-16549.out` (358 bytes)
- `results/slurm/b200-gds-1n-8g-16551.err` (0 bytes)
- `results/slurm/b200-gds-1n-8g-16551.out` (358 bytes)
- `results/slurm/b200-gds-1n-8g-16555.err` (0 bytes)
- `results/slurm/b200-gds-1n-8g-16555.out` (358 bytes)
- `results/slurm/b200-gds-1n-8g-16560.err` (0 bytes)
- `results/slurm/b200-gds-1n-8g-16560.out` (358 bytes)

</details>

## Dashboard Snapshot

Copied from `results/reports/2026-05-10/gds/gds-b200-fleet-medium-olympic-dashboard.md` in the artifact bundle.

# GDS b200 2026-05-10

- Check: `gds`
- Cluster: `b200`
- Partition: `GPU2`
- Discovery time: `2026-05-10T22:37:38Z`
- Mode: `apply`
- GDS profile: `medium`
- Time limit: `01:00:00`
- Repeat count: `5`
- Repeat aggregation: `olympic`
- Round stagger seconds: `0`

| Node | Slurm | Samples | Passes | Status | Sequential Read olympic avg | Sequential Read min..max | Sequential Read drop min/max | Sequential Write olympic avg | Sequential Write min..max | Sequential Write drop min/max | Random Read olympic avg | Random Read min..max | Random Read drop min/max | Random Write olympic avg | Random Write min..max | Random Write drop min/max | Aggregation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | idle | 5/5 | 5/5 | passed | 10.116 | 7.445..10.662 | 7.445/10.662 | 7.214 | 5.474..7.434 | 5.474/7.434 | 0.230 | 0.220..0.241 | 0.220/0.241 | 0.071 | 0.069..0.073 | 0.069/0.073 | - |

Olympic avg columns aggregate passed numeric samples for each node.

## GDS Statistics

Only passed rows with numeric throughput values are included. Mean shows the overall level; median and MAD are preferred for anomaly detection because severe outliers can distort standard deviation.
See [Stats Explained](../../../stats-explained.md) for definitions of Mean, Median, StdDev, percentiles, MAD, CV, Delta, and Robust Z.

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 1 | 10.116 | 10.116 | 0.000 | 10.116 | 10.116 | 10.116 | 10.116 | 10.116 | 10.116 | 0.000 | 0.000 |
| Sequential Write GiB/s | 1 | 7.214 | 7.214 | 0.000 | 7.214 | 7.214 | 7.214 | 7.214 | 7.214 | 7.214 | 0.000 | 0.000 |
| Random Read GiB/s | 1 | 0.230 | 0.230 | 0.000 | 0.230 | 0.230 | 0.230 | 0.230 | 0.230 | 0.230 | 0.000 | 0.000 |
| Random Write GiB/s | 1 | 0.071 | 0.071 | 0.000 | 0.071 | 0.071 | 0.071 | 0.071 | 0.071 | 0.071 | 0.000 | 0.000 |

## GDS Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. Rows below `1.0%` absolute delta are suppressed from this table. See [Stats Explained](../../../stats-explained.md) for `Delta` and `Robust Z` definitions.

(none)

## Missing/Skipped Jobs

(none)
