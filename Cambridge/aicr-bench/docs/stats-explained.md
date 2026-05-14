# Stats Explained

Purpose: define the dashboard statistics used in curated AICR-Bench examples
and public study pages.

## General Statistics

- `CV`: coefficient of variation, `StdDev / Mean`.
- `Delta`: percent difference from the fleet median.
- `MAD`: median absolute deviation from the median.
- `Mean`: arithmetic average of included numeric samples.
- `Median`: middle value after sorting; preferred for quick fleet comparison.
- `Min` / `Max`: lowest and highest included values.
- `Olympic avg`: repeat-run average after dropping one lowest and one highest
  passed numeric sample when at least five samples exist.
- `P10`, `P25`, `P75`, `P90`: percentile values.
- `Robust Z`: median/MAD-based outlier score.
- `StdDev`: standard deviation; useful for spread but sensitive to outliers.

## NCCL Statistics

- `NCCL algbw`: algorithm bandwidth from `nccl-tests`; message size divided by
  elapsed time for the collective operation. AICR-Bench preserves this in raw
  artifacts.
- `NCCL busbw`: bus bandwidth from `nccl-tests`; `algbw` adjusted by a
  collective-specific factor so the value better reflects the communication
  bottleneck. AICR-Bench dashboard `busbw` values are reported in GB/s.
  AICR-Bench NCCL result tables use `busbw`, not `algbw`.

The `nccl-tests` project documents the `algbw` and `busbw` definitions and the
collective-specific correction factors used to turn operation bandwidth into
bus bandwidth: <https://github.com/NVIDIA/nccl-tests/blob/master/doc/PERFORMANCE.md>

For AICR-Bench NCCL collectives, the correction factors are:

| Collective | `busbw` correction from `algbw` |
| --- | --- |
| AllGather | `algbw * (n - 1) / n` |
| AllReduce | `algbw * 2 * (n - 1) / n` |
| AllToAll | `algbw * (n - 1) / n` |
| ReduceScatter | `algbw * (n - 1) / n` |

Here `n` is the NCCL rank count. The correction makes large-message
collective results easier to compare with the hardware communication
bottleneck, but it does not prove which NCCL algorithm or topology was selected.

## DataLoader Statistics

- `Est. VAST GB/s`: estimated dataset read bandwidth from sample counts and
  elapsed time. This is an input-pressure estimate, not a storage benchmark.
- `H2D samples/s`: host-to-device transfer throughput. If this is much higher
  than `samples/s`, H2D transfer is probably not the main limiter.
- `Jitter`: unwanted run-to-run variation in timing or throughput for the same
  benchmark configuration. In HPC, jitter often comes from background system
  activity, scheduler placement, filesystem variation, network effects, or rank
  skew. In AICR-Bench DataLoader tables, jitter is reported as the retained
  `samples/s` range after repeat aggregation; for Olympic aggregation, that
  means `max(samples/s) - min(samples/s)` after dropping the lowest and highest
  throughput samples.
- `load samples/s`: input-pipeline throughput before the GPU/H2D portion of the
  measured path. Use it to understand whether worker count, prefetch, and
  storage reads are improving the loading side.
- `rank_imbalance_percent`: multi-rank throughput spread. It is meaningful for
  one-node 8-GPU and multi-node runs, but not for single-GPU surface maps.
- `samples/s`: end-to-end DataLoader benchmark throughput for the measured
  loop. Use this as the headline configuration comparison.
