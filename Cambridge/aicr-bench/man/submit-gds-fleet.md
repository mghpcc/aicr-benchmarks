# submit-gds-fleet.sh

## Purpose

Preview or submit GDS Slurm jobs across selected nodes.

## Usage

```text
scripts/verify/submit-gds-fleet.sh --cluster <b200|rtxpro6000> [--profile <small|medium|large>] [--nodes <node[,node...]>] [--partition <name>] [--repeat-count <n>] [--repeat-aggregation <standard|olympic>] [--submit-stagger-seconds <n|benchmark>] [--round-stagger-seconds <n>] [--apply] [--no-wait] [--no-render]
scripts/verify/submit-gds-fleet.sh --cluster <b200|rtxpro6000> --custom-gdsio-args '<gdsio args>' [--nodes <node[,node...]>] [--apply]
```

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--profile <name>`: GDS profile. Default: `small`.
- `--nodes <node[,node...]>`: Limit to named nodes.
- `--partition <name>`: Override default Slurm partition.
- `--repeat-count <n>`: Repeat rounds. Default: `1`.
- `--repeat-aggregation <standard|olympic>`: Repeat dashboard aggregation. Default: `standard`.
- `--submit-stagger-seconds <n|benchmark>`: Delay between submissions. Default: `60`. Use `benchmark` to submit a Slurm dependency chain with five seconds between `sbatch` calls and only one selected GDS job running at a time.
- `--round-stagger-seconds <n>`: Delay between repeat rounds.
- `--apply`: Submit jobs. Without this flag, the command is a dry run.
- `--no-wait`: Do not wait for jobs. Not allowed with repeat count greater than 1.
- `--no-render`: Skip report rendering after jobs complete.
- `--custom-gdsio-args <args>`: Submit one custom GDS command.
- `-h`, `--help`: Print usage.

## Outputs

- One Slurm job per selected node per round.
- Fleet manifest under `results/reports/<date>/gds/`.
- The submitter may invoke the GDS renderer unless `--no-render` is used. Renderer output details live in [render-verify-dashboard.py](render-verify-dashboard.md).

## Examples

Dry-run two nodes:

```bash
scripts/verify/submit-gds-fleet.sh --cluster b200 --profile small --nodes b0001,b0002
```

Submit two nodes:

```bash
scripts/verify/submit-gds-fleet.sh --cluster b200 --profile small --nodes b0001,b0002 --apply
```

Run three standard repeats:

```bash
scripts/verify/submit-gds-fleet.sh --cluster b200 --profile small --nodes b0001,b0002 --repeat-count 3 --repeat-aggregation standard --apply
```

Run five olympic repeats:

```bash
scripts/verify/submit-gds-fleet.sh --cluster b200 --profile small --nodes b0001,b0002 --repeat-count 5 --repeat-aggregation olympic --apply
```

For promoted benchmark-style studies, prefer twelve olympic repeats:

```bash
scripts/verify/submit-gds-fleet.sh --cluster b200 --profile medium --nodes b0001,b0002 --repeat-count 12 --repeat-aggregation olympic --submit-stagger-seconds benchmark --apply
```

With twelve passed numeric samples, olympic aggregation drops the lowest and
highest value and averages the remaining ten. Benchmark stagger mode chains the
submitted Slurm jobs with `afterany` dependencies so only one selected GDS job
starts at a time.
