# GDS RTX Focused Serial Fleet Olympic

<!-- aicr-study-status: published -->

Purpose: RTX Pro 6000 five-node `medium` profile fleet run with staggered submission and Olympic aggregation.

## Run Configuration

- `5` selected RTX Pro 6000 nodes
- `5` GDS samples per node
- `25/25` focused jobs passed
- Olympic aggregation per node: drop the lowest and highest passed numeric
  sample, then average the remaining three

## Command Run

```bash
make verify-gds CLUSTER=rtxpro6000 PROFILE=medium \
  NODELIST=a0001,a0002,a0005,a0006,a0007 \
  REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic \
  GDS_SUBMIT_STAGGER_SECONDS=30 \
  GDS_ROUND_STAGGER_SECONDS=60 \
  APPLY=1
```

The run used the current Slurm partition name `rtx-batch`.

## Run Summary

- Cluster: `rtxpro6000`
- Nodes: `a0001,a0002,a0005,a0006,a0007`
- Profile: `medium`
- Source commit: `8aa3264`
- Public artifact commit: `22cf1a9`
- Samples: `25` jobs, `5` samples per node
- Result: all focused GDS jobs passed
- Collection mode: five nodes submitted with a `30` second stagger per round

| Metric | Fleet median of node centers | Min node center | Max node center |
| --- | ---: | ---: | ---: |
| Sequential read | `10.813 GiB/s` | `10.273` | `11.135` |
| Sequential write | `6.822 GiB/s` | `6.484` | `7.017` |
| Random read | `0.241 GiB/s` | `0.229` | `0.251` |
| Random write | `0.067 GiB/s` | `0.060` | `0.070` |

## Node Centers

| Node | Samples | Passes | Sequential read | Sequential write | Random read | Random write |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `a0001` | `5/5` | `5/5` | `11.135` | `6.983` | `0.241` | `0.060` |
| `a0002` | `5/5` | `5/5` | `10.676` | `6.484` | `0.251` | `0.060` |
| `a0005` | `5/5` | `5/5` | `10.999` | `6.733` | `0.229` | `0.069` |
| `a0006` | `5/5` | `5/5` | `10.813` | `6.822` | `0.243` | `0.067` |
| `a0007` | `5/5` | `5/5` | `10.273` | `7.017` | `0.232` | `0.070` |

## Dashboard Snapshot

<details>
<summary>Dashboard snapshot</summary>

### GDS RTX Pro 6000 2026-05-23

- Check: `gds`
- Cluster: `rtxpro6000`
- Partition: `rtx-batch`
- Discovery time: `2026-05-23T15:18:07Z`
- Mode: `apply`
- GDS profile: `medium`
- Time limit: `01:00:00`
- Repeat count: `5`
- Repeat aggregation: `olympic`
- Round stagger seconds: `60`

| Node | Slurm | Samples | Passes | Status | Sequential Read olympic avg | Sequential Read min..max | Sequential Read drop min/max | Sequential Write olympic avg | Sequential Write min..max | Sequential Write drop min/max | Random Read olympic avg | Random Read min..max | Random Read drop min/max | Random Write olympic avg | Random Write min..max | Random Write drop min/max | Aggregation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a0001 | idle | 5/5 | 5/5 | passed | 11.135 | 8.462..11.359 | 8.462/11.359 | 6.983 | 6.451..7.096 | 6.451/7.096 | 0.241 | 0.215..0.269 | 0.215/0.269 | 0.060 | 0.047..0.060 | 0.047/0.060 | - |
| a0002 | idle | 5/5 | 5/5 | passed | 10.676 | 8.635..11.748 | 8.635/11.748 | 6.484 | 5.470..6.755 | 5.470/6.755 | 0.251 | 0.228..0.261 | 0.228/0.261 | 0.060 | 0.052..0.064 | 0.052/0.064 | - |
| a0005 | idle | 5/5 | 5/5 | passed | 10.999 | 9.751..11.541 | 9.751/11.541 | 6.733 | 5.532..6.902 | 5.532/6.902 | 0.229 | 0.225..0.244 | 0.225/0.244 | 0.069 | 0.053..0.070 | 0.053/0.070 | - |
| a0006 | idle | 5/5 | 5/5 | passed | 10.813 | 10.195..11.322 | 10.195/11.322 | 6.822 | 6.453..6.971 | 6.453/6.971 | 0.243 | 0.235..0.249 | 0.235/0.249 | 0.067 | 0.060..0.070 | 0.060/0.070 | - |
| a0007 | idle | 5/5 | 5/5 | passed | 10.273 | 9.789..10.444 | 9.789/10.444 | 7.017 | 6.934..7.152 | 6.934/7.152 | 0.232 | 0.215..0.249 | 0.215/0.249 | 0.070 | 0.069..0.071 | 0.069/0.071 | - |

### GDS Statistics

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 5 | 10.779 | 10.813 | 0.333 | 10.273 | 10.434 | 10.676 | 10.999 | 11.081 | 11.135 | 0.186 | 0.031 |
| Sequential Write GiB/s | 5 | 6.808 | 6.822 | 0.215 | 6.484 | 6.584 | 6.733 | 6.983 | 7.003 | 7.017 | 0.161 | 0.032 |
| Random Read GiB/s | 5 | 0.239 | 0.241 | 0.009 | 0.229 | 0.230 | 0.232 | 0.243 | 0.248 | 0.251 | 0.009 | 0.037 |
| Random Write GiB/s | 5 | 0.065 | 0.067 | 0.005 | 0.060 | 0.060 | 0.060 | 0.069 | 0.070 | 0.070 | 0.003 | 0.075 |

### GDS Anomalies

| Severity | Node | Metric | Value | Median | Delta | Robust Z |
| --- | --- | --- | --- | --- | --- | --- |
| low_tail | a0005 | Random Read GiB/s | 0.229 | 0.241 | -5.0% | -0.899 |
| low_tail | a0001 | Random Write GiB/s | 0.060 | 0.067 | -10.4% | -1.574 |
| low_tail | a0002 | Random Write GiB/s | 0.060 | 0.067 | -10.4% | -1.574 |
| low_tail | a0007 | Sequential Read GiB/s | 10.273 | 10.813 | -5.0% | -1.958 |
| low_tail | a0002 | Sequential Write GiB/s | 6.484 | 6.822 | -5.0% | -1.416 |

### Missing/Skipped Jobs

(none)

</details>

## Artifact Bundle

- VAST tarball: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/22cf1a9/gds/2026-05-23/gds-rtx-focused-serial-fleet-olympic-2026-05-23.tar.gz`
- VAST provenance: `/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/22cf1a9/gds/2026-05-23/gds-rtx-focused-serial-fleet-olympic-2026-05-23.provenance.json`
- OSN HTTPS tarball: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/22cf1a9/gds/2026-05-23/gds-rtx-focused-serial-fleet-olympic-2026-05-23.tar.gz>
- OSN HTTPS provenance: <https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/22cf1a9/gds/2026-05-23/gds-rtx-focused-serial-fleet-olympic-2026-05-23.provenance.json>
- SHA-256: `b738a01b9a587cfc0f991eeb83dc321027bd4e9012038389531fe7cd92e242fc`

## Retrieve And Verify

```bash
mkdir -p public-study-artifacts/gds-rtx-focused-serial-fleet-olympic
cd public-study-artifacts/gds-rtx-focused-serial-fleet-olympic
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/22cf1a9/gds/2026-05-23/gds-rtx-focused-serial-fleet-olympic-2026-05-23.tar.gz
wget https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/22cf1a9/gds/2026-05-23/gds-rtx-focused-serial-fleet-olympic-2026-05-23.provenance.json
printf "%s  %s\n" "b738a01b9a587cfc0f991eeb83dc321027bd4e9012038389531fe7cd92e242fc" "gds-rtx-focused-serial-fleet-olympic-2026-05-23.tar.gz" | sha256sum -c -
tar -tzf gds-rtx-focused-serial-fleet-olympic-2026-05-23.tar.gz | head
```
