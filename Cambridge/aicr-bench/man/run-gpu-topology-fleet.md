# run-gpu-topology-fleet.sh

## Purpose

Submit GPU topology collection jobs across selected or discovered nodes.

## Usage

```text
scripts/verify/run-gpu-topology-fleet.sh --cluster <b200|rtxpro6000> [--partition <name>] [--nodes <nodelist>] [--submit-stagger-seconds <n>] [--apply] [--no-wait] [--no-render]
```

Default behavior is a dry run.

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--partition <name>`: Override the default partition.
- `--nodes <nodelist>`: Limit collection to an explicit comma-separated node list or Slurm hostlist.
- `--submit-stagger-seconds <n>`: Delay between submissions. Default: `2`.
- `--apply`: Submit jobs. Without this flag, the command is a dry run.
- `--no-wait`: Do not wait for jobs to leave the Slurm queue.
- `--no-render`: Skip report rendering after jobs complete.
- `-h`, `--help`: Print usage.

## Outputs

- One Slurm topology job per exactly-idle selected node.
- Fleet manifest under `results/reports/<date>/gpu-topology/`.
- Rendered topology dashboard unless `--no-render` is used.

## Examples

Dry-run B200 topology collection:

```bash
scripts/verify/run-gpu-topology-fleet.sh --cluster b200
```

Submit RTX topology collection:

```bash
scripts/verify/run-gpu-topology-fleet.sh --cluster rtxpro6000 --nodes a0001 --apply
```
