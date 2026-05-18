# submit-ddp-launcher-comparison.sh

## Purpose

Preview or submit paired DDP ResNet-50 launcher-comparison jobs. For each
requested scale, the helper submits a `torchrun` row and a controlled-bind
`srun` row through [submit-ddp-resnet50.sh](submit-ddp-resnet50.md).

## Usage

```text
scripts/benchmark/submit-ddp-launcher-comparison.sh --cluster <b200|rtxpro6000> [--scales <csv>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--nodelist <csv>] [--time <HH:MM:SS>] [--srun-cpu-bind <value>] [--srun-mem-bind <value>] [--srun-mpi <value>] [--include-default-srun] [--submit-stagger-seconds <n>] [--apply] [--] [run-ddp-resnet50 args...]
```

The Make entrypoint is:

```bash
make benchmark-ddp-launcher-comparison CLUSTER=<b200|rtxpro6000> NODELIST=<node[,node...]> DDP_COMPARISON_SCALES=<csv>
```

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--scales <csv>`: Node-count ladder. B200 supports `1,2,4,8,16`; RTX supports `1,2,4`.
- `--from-node-report`: Select strict-passed nodes for each scale from the node report.
- `--date <value>`: Node-report date for `--from-node-report`. Default: `today`.
- `--nodelist <csv>`: Ordered node pool. Each scale uses the first `N` nodes.
- `--time <HH:MM:SS>`: Slurm time limit. Default: `02:00:00`.
- `--srun-cpu-bind <value>`: CPU binding value for the controlled `srun` row.
- `--srun-mem-bind <value>`: Memory binding value for the controlled `srun` row.
- `--srun-mpi <value>`: MPI plugin value for the `srun` row. Default: `pmix`.
- `--include-default-srun`: Also submit an `srun` row without explicit binding overrides.
- `--submit-stagger-seconds <n>`: Seconds between applied submissions.
- `--apply`: Submit jobs. Omit for dry-run preview.
- `-- <runner args...>`: Forward remaining arguments to [run-ddp-resnet50.sh](run-ddp-resnet50.md).
- `--help`: Print help.

## Examples

Preview B200 `torchrun` versus controlled-bind `srun` rows:

```bash
scripts/benchmark/submit-ddp-launcher-comparison.sh --cluster b200 --scales 1,2,4 --nodelist b0002,b0003,b0004,b0005 --srun-cpu-bind none --srun-mem-bind none -- --warmup-iters 100 --measured-iters 500 --batch-size 64 --num-workers 8
```

Preview using strict-passed node selection:

```bash
scripts/benchmark/submit-ddp-launcher-comparison.sh --cluster b200 --scales 1,2,4 --from-node-report --date today
```

## Outputs

The comparison submitter prints each delegated
[submit-ddp-resnet50.sh](submit-ddp-resnet50.md) command and, with `--apply`,
submits the paired jobs. Each job writes the standard DDP raw and parsed
artifacts documented in [run-ddp-resnet50.sh](run-ddp-resnet50.md).
