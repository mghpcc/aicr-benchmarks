# GDS B200 Focused Serial Fleet Olympic

Purpose: B200 five-node `medium` profile fleet run with serial submission and olympic aggregation.

## Run Configuration

- `5` selected B200 nodes
- `5` GDS samples per node
- `25/25` focused jobs passed
- olympic aggregation per node: drop the lowest and highest passed numeric
  sample, then average the remaining three

## Command Run

```bash
make verify-gds CLUSTER=b200 PROFILE=medium \
  NODELIST=b0002,b0003,b0004,b0005,b0006 \
  REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic \
  GDS_SUBMIT_STAGGER_SECONDS=benchmark \
  APPLY=1
```

## Run Summary

- Cluster: `b200`
- Nodes: `b0002,b0003,b0004,b0005,b0006`
- Profile: `medium`
- Source commit: `4fd6b5c`
- Samples: `25` jobs, `5` samples per node
- Result: all focused GDS jobs passed
- Collection mode: one selected GDS job at a time

| Metric | Fleet median of node centers | Min node center | Max node center |
| --- | ---: | ---: | ---: |
| Sequential read | `9.768 GiB/s` | `9.755` | `9.928` |
| Sequential write | `7.329 GiB/s` | `7.293` | `7.391` |
| Random read | `0.237 GiB/s` | `0.226` | `0.242` |
| Random write | `0.072 GiB/s` | `0.070` | `0.072` |

## Node Centers

| Node | Samples | Passes | Sequential read | Sequential write | Random read | Random write |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `b0002` | `5/5` | `5/5` | `9.761` | `7.329` | `0.238` | `0.070` |
| `b0003` | `5/5` | `5/5` | `9.755` | `7.298` | `0.226` | `0.072` |
| `b0004` | `5/5` | `5/5` | `9.928` | `7.350` | `0.235` | `0.072` |
| `b0005` | `5/5` | `5/5` | `9.768` | `7.293` | `0.242` | `0.072` |
| `b0006` | `5/5` | `5/5` | `9.891` | `7.391` | `0.237` | `0.072` |

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### GDS b200 2026-05-11

- Check: `gds`
- Cluster: `b200`
- Partition: `GPU2`
- Discovery time: `2026-05-11T05:29:52Z`
- Mode: `apply-focused-front-end-serial`
- GDS profile: `medium`
- Time limit: `01:00:00`
- Repeat count: `5`
- Repeat aggregation: `olympic`
- Round stagger seconds: `0`

| Node | Slurm | Samples | Passes | Status | Sequential Read olympic avg | Sequential Read min..max | Sequential Read drop min/max | Sequential Write olympic avg | Sequential Write min..max | Sequential Write drop min/max | Random Read olympic avg | Random Read min..max | Random Read drop min/max | Random Write olympic avg | Random Write min..max | Random Write drop min/max | Aggregation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| b0002 | idle | 5/5 | 5/5 | passed | 9.761 | 9.235..9.980 | 9.235/9.980 | 7.329 | 7.234..7.437 | 7.234/7.437 | 0.238 | 0.227..0.251 | 0.227/0.251 | 0.070 | 0.067..0.072 | 0.067/0.072 | - |
| b0003 | idle | 5/5 | 5/5 | passed | 9.755 | 9.358..10.110 | 9.358/10.110 | 7.298 | 7.171..7.353 | 7.171/7.353 | 0.226 | 0.217..0.244 | 0.217/0.244 | 0.072 | 0.070..0.075 | 0.070/0.075 | - |
| b0004 | idle | 5/5 | 5/5 | passed | 9.928 | 9.106..10.086 | 9.106/10.086 | 7.350 | 7.310..7.449 | 7.310/7.449 | 0.235 | 0.221..0.242 | 0.221/0.242 | 0.072 | 0.071..0.072 | 0.071/0.072 | - |
| b0005 | idle | 5/5 | 5/5 | passed | 9.768 | 9.116..10.136 | 9.116/10.136 | 7.293 | 7.196..7.450 | 7.196/7.450 | 0.242 | 0.218..0.249 | 0.218/0.249 | 0.072 | 0.071..0.073 | 0.071/0.073 | - |
| b0006 | idle | 5/5 | 5/5 | passed | 9.891 | 8.883..10.081 | 8.883/10.081 | 7.391 | 7.210..7.460 | 7.210/7.460 | 0.237 | 0.217..0.248 | 0.217/0.248 | 0.072 | 0.067..0.073 | 0.067/0.073 | - |

### GDS Statistics

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 5 | 9.821 | 9.768 | 0.082 | 9.755 | 9.757 | 9.761 | 9.891 | 9.913 | 9.928 | 0.013 | 0.008 |
| Sequential Write GiB/s | 5 | 7.332 | 7.329 | 0.040 | 7.293 | 7.295 | 7.298 | 7.350 | 7.375 | 7.391 | 0.031 | 0.005 |
| Random Read GiB/s | 5 | 0.236 | 0.237 | 0.006 | 0.226 | 0.230 | 0.235 | 0.238 | 0.240 | 0.242 | 0.002 | 0.025 |
| Random Write GiB/s | 5 | 0.072 | 0.072 | 0.001 | 0.070 | 0.071 | 0.072 | 0.072 | 0.072 | 0.072 | 0.000 | 0.012 |

### GDS Anomalies

| Severity | Node | Metric | Value | Median | Delta | Robust Z |
| --- | --- | --- | --- | --- | --- | --- |
| low_tail | b0003 | Random Read GiB/s | 0.226 | 0.237 | -4.6% | -3.710 |
| low_tail | b0002 | Random Write GiB/s | 0.070 | 0.072 | -2.8% | - |
| high_info | b0004 | Sequential Read GiB/s | 9.928 | 9.768 | 1.6% | 8.302 |
| high_info | b0006 | Sequential Read GiB/s | 9.891 | 9.768 | 1.3% | 6.382 |

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4fd6b5c/gds/2026-05-11/gds-b200-focused-serial-fleet-olympic-2026-05-11.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/4fd6b5c/gds/2026-05-11/gds-b200-focused-serial-fleet-olympic-2026-05-11.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4fd6b5c/gds/2026-05-11/gds-b200-focused-serial-fleet-olympic-2026-05-11.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4fd6b5c/gds/2026-05-11/gds-b200-focused-serial-fleet-olympic-2026-05-11.provenance.json>
- SHA-256: `054aa45fbbc5e5248dc869ea16a72abd89eeb4cefc36ee30a95e42837ecef152`

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-b200-focused-serial-fleet-olympic
cd public-study-artifacts/gds-b200-focused-serial-fleet-olympic
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4fd6b5c/gds/2026-05-11/gds-b200-focused-serial-fleet-olympic-2026-05-11.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/4fd6b5c/gds/2026-05-11/gds-b200-focused-serial-fleet-olympic-2026-05-11.provenance.json
printf "%s  %s\n" "054aa45fbbc5e5248dc869ea16a72abd89eeb4cefc36ee30a95e42837ecef152" "gds-b200-focused-serial-fleet-olympic-2026-05-11.tar.gz" | sha256sum -c -
tar -tzf gds-b200-focused-serial-fleet-olympic-2026-05-11.tar.gz | head
```
