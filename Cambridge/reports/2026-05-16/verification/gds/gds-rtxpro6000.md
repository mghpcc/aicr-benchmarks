# GDS rtxpro6000 2026-05-16

- Check: `gds`
- Cluster: `rtxpro6000`
- Partition: `GPU1`
- Discovery time: `2026-05-16T13:00:55Z`
- Mode: `apply`
- GDS profile: `small`
- Time limit: `00:25:00`
- Repeat count: `5`
- Repeat aggregation: `olympic`
- Round stagger seconds: `60`
- GPU preflight filter: `enabled`
- GPU preflight source: `latest same-day gpu-topology parsed summaries`
- GPU preflight expected count: `8`
- GPU preflight excluded nodes: `0`

| Node | Slurm | Samples | Passes | Status | Sequential Read olympic avg | Sequential Read min..max | Sequential Read drop min/max | Sequential Write olympic avg | Sequential Write min..max | Sequential Write drop min/max | Random Read olympic avg | Random Read min..max | Random Read drop min/max | Random Write olympic avg | Random Write min..max | Random Write drop min/max | Aggregation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| a0002 | idle | 5/5 | 5/5 | passed | 8.547 | 8.268..8.676 | 8.268/8.676 | 5.181 | 5.051..5.727 | 5.051/5.727 | - | - | - | - | - | - | - |
| a0003 | idle | 5/5 | 5/5 | passed | 8.439 | 8.133..8.647 | 8.133/8.647 | 5.341 | 5.027..5.749 | 5.027/5.749 | - | - | - | - | - | - | - |
| a0004 | idle | 5/5 | 5/5 | passed | 8.479 | 8.335..8.574 | 8.335/8.574 | 5.147 | 5.084..5.279 | 5.084/5.279 | - | - | - | - | - | - | - |
| a0005 | idle | 5/5 | 5/5 | passed | 8.343 | 7.347..8.491 | 7.347/8.491 | 5.176 | 4.947..5.378 | 4.947/5.378 | - | - | - | - | - | - | - |
| a0006 | idle | 5/5 | 5/5 | passed | 8.673 | 8.496..8.872 | 8.496/8.872 | 5.200 | 5.114..5.488 | 5.114/5.488 | - | - | - | - | - | - | - |
| a0007 | idle | 5/5 | 5/5 | passed | 8.440 | 8.214..8.679 | 8.214/8.679 | 5.058 | 4.920..5.281 | 4.920/5.281 | - | - | - | - | - | - | - |
| a0008 | idle | 5/5 | 5/5 | passed | 8.445 | 8.396..8.473 | 8.396/8.473 | 5.269 | 5.187..5.520 | 5.187/5.520 | - | - | - | - | - | - | - |
| a0009 | idle | 5/5 | 5/5 | passed | 8.491 | 8.270..8.588 | 8.270/8.588 | 5.371 | 5.097..5.683 | 5.097/5.683 | - | - | - | - | - | - | - |
| a0010 | idle | 5/5 | 5/5 | passed | 8.474 | 7.739..8.711 | 7.739/8.711 | 5.323 | 4.867..5.565 | 4.867/5.565 | - | - | - | - | - | - | - |
| a0011 | idle | 5/5 | 5/5 | passed | 8.568 | 8.444..8.691 | 8.444/8.691 | 5.279 | 5.080..5.323 | 5.080/5.323 | - | - | - | - | - | - | - |
| a0012 | idle | 5/5 | 5/5 | passed | 8.590 | 8.479..8.783 | 8.479/8.783 | 5.198 | 5.062..5.436 | 5.062/5.436 | - | - | - | - | - | - | - |
| a0013 | idle | 5/5 | 5/5 | passed | 8.208 | 7.739..8.574 | 7.739/8.574 | 5.224 | 4.842..5.435 | 4.842/5.435 | - | - | - | - | - | - | - |
| a0014 | idle | 5/5 | 5/5 | passed | 8.436 | 8.180..8.648 | 8.180/8.648 | 5.243 | 4.836..5.695 | 4.836/5.695 | - | - | - | - | - | - | - |
| a0015 | idle | 5/5 | 5/5 | passed | 8.395 | 8.155..8.621 | 8.155/8.621 | 5.253 | 4.670..5.588 | 4.670/5.588 | - | - | - | - | - | - | - |
| a0016 | idle | 5/5 | 5/5 | passed | 8.557 | 7.730..8.791 | 7.730/8.791 | 5.254 | 5.195..5.498 | 5.195/5.498 | - | - | - | - | - | - | - |
| a0017 | drained* | 0/0 | 0/0 | skipped | - |  |  | - |  |  | - |  |  | - |  |  |  |
| a0018 | mixed | 0/0 | 0/0 | skipped | - |  |  | - |  |  | - |  |  | - |  |  |  |
| a0019 | idle | 5/5 | 5/5 | passed | 8.453 | 8.050..8.809 | 8.050/8.809 | 5.323 | 5.161..5.959 | 5.161/5.959 | - | - | - | - | - | - | - |

Olympic avg columns aggregate passed numeric samples for each node.

## GDS Statistics

Only passed rows with numeric throughput values are included. Mean shows the overall level; median and MAD are preferred for anomaly detection because severe outliers can distort standard deviation.
See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for definitions of Mean, Median, StdDev, percentiles, MAD, CV, Delta, and Robust Z.

| Metric | n | Mean | Median | StdDev | Min | P10 | P25 | P75 | P90 | Max | MAD | CV |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sequential Read GiB/s | 16 | 8.471 | 8.463 | 0.108 | 8.208 | 8.369 | 8.438 | 8.550 | 8.579 | 8.673 | 0.048 | 0.013 |
| Sequential Write GiB/s | 16 | 5.240 | 5.248 | 0.080 | 5.058 | 5.162 | 5.194 | 5.290 | 5.332 | 5.371 | 0.058 | 0.015 |

## GDS Anomalies

Anomalies are report evidence only and do not change canonical `status.json` pass/fail. Rows below `1.0%` absolute delta are suppressed from this table. See [Stats Explained](../../../../aicr-bench/docs/stats-explained.md) for `Delta` and `Robust Z` definitions.

| Severity | Node | Metric | Value | Median | Delta | Robust Z |
| --- | --- | --- | --- | --- | --- | --- |
| low_tail | a0005 | Sequential Read GiB/s | 8.343 | 8.463 | -1.4% | -1.693 |
| low_tail | a0013 | Sequential Read GiB/s | 8.208 | 8.463 | -3.0% | -3.590 |
| low_tail | a0004 | Sequential Write GiB/s | 5.147 | 5.248 | -1.9% | -1.165 |
| low_tail | a0007 | Sequential Write GiB/s | 5.058 | 5.248 | -3.6% | -2.191 |

## Missing/Skipped Jobs

| Node | Slurm | Job | Run | Samples | Passes | Status |
| --- | --- | --- | --- | --- | --- | --- |
| a0017 | drained* | - | - | 0/0 | 0/0 | skipped |
| a0018 | mixed | - | - | 0/0 | 0/0 | skipped |

## Skipped Nodes

- `drained*`: a0017
- `mixed`: a0018
