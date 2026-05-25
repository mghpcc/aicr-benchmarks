# submit-elbencho.sh

## Purpose

Submit serialized Elbencho storage benchmark jobs.

## Usage

```text
scripts/benchmark/submit-elbencho.sh --cluster <b200|rtxpro6000> --workload <peak-cluster|small-block|small-file|metadata> [--profile <smoke|small>] [--partition <name>] [--nodes <n>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--nodelist <nodes>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--mem <size>] [--repeat-count <n>] [--repeat-stagger-seconds <n>] [--dependency <slurm-dependency>] [--command <elbencho command>] [--apply]
```

Default behavior is a dry run. Repeats are submitted as a Slurm dependency
chain. The Slurm memory request defaults to `--mem=0`.

The Make entrypoint is:

```bash
make benchmark-elbencho CLUSTER=<b200|rtxpro6000> WORKLOAD=<peak-cluster|small-block|small-file|metadata> NODES=<n> ELBENCHO_PROFILE=<smoke|small>
```

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--workload <name>`: `peak-cluster`, `small-block`, `small-file`, or `metadata`.
- `--profile <name>`: `smoke` or `small`. Default comes from `ELBENCHO_PROFILE` or `PROFILE`.
- `--partition <name>`: Override Slurm partition.
- `--nodes <n>`: Slurm node count.
- `--from-node-report`: Select strict-passed nodes for the selected cluster from the latest node report.
- `--date <value>`: Node-report date for `--from-node-report`. Default: `today`.
- `--nodelist <nodes>`: Explicit node or comma-separated nodes.
- `--time <HH:MM:SS>`: Slurm time limit.
- `--cpus-per-task <n>`: CPU allocation per Slurm task.
- `--mem <size>`: Slurm memory request. Default: `0`.
- `--repeat-count <n>`: Submit independent repeated samples.
- `--repeat-stagger-seconds <n>`: Seconds between repeated submissions.
- `--dependency <value>`: External Slurm dependency for the first submitted job.
- `--command <value>`: Expert Elbencho command override.
- `--apply`: Submit jobs. Omit for dry-run preview.
- `--help`: Print help.

## Examples

Preview a one-node small-block row:

```bash
scripts/benchmark/submit-elbencho.sh \
  --cluster b200 \
  --workload small-block \
  --profile small \
  --nodes 1 \
  --nodelist b0002 \
  --cpus-per-task 128 \
  --mem 0
```

Preview a serialized repeat set:

```bash
scripts/benchmark/submit-elbencho.sh \
  --cluster b200 \
  --workload small-block \
  --profile small \
  --nodes 1 \
  --nodelist b0002 \
  --mem 0 \
  --repeat-count 5
```

## Outputs

The submitter prints the resolved command and, with `--apply`, submits the job
chain. Each job writes the standard Elbencho raw and parsed artifacts documented
in [run-elbencho.sh](run-elbencho.md).
