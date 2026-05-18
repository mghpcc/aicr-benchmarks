# run-gds-fleet.sh

## Purpose

Discover or target nodes and submit one GDS verification job per selected node.

## Usage

```text
scripts/verify/run-gds-fleet.sh --cluster <b200|rtxpro6000> [--profile <smoke|small|medium|large>] [--nodes <node[,node...]>] [--partition <name>] [--repeat-count <n>] [--repeat-aggregation <standard|olympic>] [--gpu-preflight-filter] [--submit-stagger-seconds <n|benchmark>] [--round-stagger-seconds <n>] [--apply] [--no-wait] [--no-render]
scripts/verify/run-gds-fleet.sh --cluster <b200|rtxpro6000> --custom-gdsio-args '<gdsio args>' [--nodes <node[,node...]>] [--apply]
```

Default behavior is a dry run: discover exactly-idle nodes and print `sbatch`
commands without submitting.

Direct script use and the curated `make verify-gds` interface default to a
30-second numeric submission stagger unless overridden.

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--profile <name>`: Select `smoke`, `small`, `medium`, `large`, or `custom`. Default: `small`.
- `--nodes <node[,node...]>`: Limit to named nodes or Slurm hostlist expressions.
- `--partition <name>`: Override the default partition for the selected cluster.
- `--repeat-count <n>`: Number of repeat rounds. Default: `1`.
- `--repeat-aggregation <standard|olympic>`: Repeat dashboard aggregation. Default: `standard`.
- `--gpu-preflight-filter`: Exclude nodes without same-day GPU topology evidence for the expected GPU count.
- `--submit-stagger-seconds <n|benchmark>`: Delay between submissions. Use `benchmark` to pace `sbatch` calls by five seconds while chaining selected jobs with `afterany` dependencies so only one selected GDS job runs at a time.
- `--round-stagger-seconds <n>`: Delay between repeat rounds.
- `--apply`: Submit jobs. Without this flag, the command is a dry run.
- `--no-wait`: Do not wait for submitted jobs. Not allowed with repeat count greater than 1.
- `--no-render`: Skip report rendering after jobs complete.
- `--custom-gdsio-args <args>`: Submit one custom GDS command.
- `-h`, `--help`: Print usage.

## Outputs

- One Slurm job per selected node per round.
- Fleet manifest under `results/reports/<date>/gds/`.
- Rendered GDS dashboard unless `--no-render` is used.

## Examples

Dry-run one node:

```bash
scripts/verify/run-gds-fleet.sh --cluster b200 --profile small --nodes <node>
```

Submit one smoke run on one node:

```bash
scripts/verify/run-gds-fleet.sh --cluster b200 --profile smoke --nodes <node> --apply
```

Run five olympic repeats with benchmark-style serialized storage pressure:

```bash
scripts/verify/run-gds-fleet.sh --cluster b200 --profile medium --nodes <nodes> --repeat-count 5 --repeat-aggregation olympic --submit-stagger-seconds benchmark --apply
```

## Notes

[submit-gds-fleet.sh](submit-gds-fleet.md) is a compatibility wrapper for this script.
