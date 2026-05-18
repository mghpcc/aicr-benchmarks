# submit-nccl-suite.sh

## Purpose

Submit the instrumented NCCL suite for local, RDMA, or scale scopes.

## Usage

```text
scripts/verify/submit-nccl-suite.sh --scope <local|rdma|scale> --cluster <b200|rtxpro6000> [options]
```

## Options

- `--apply`: Submit jobs. Without this flag, the command is a dry run.
- `--scope <local|rdma|scale>`: Suite scope.
- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--profile <name>`: `smoke`, `small`, `medium`, or `large`. Default: `small`.
- `--suite-class <name>`: Optional local suite-class filter.
- `--nodes <list>`: Optional space- or comma-separated candidate node list.
- `--nodes-per-job <n>`: RDMA group size, or one scale for `--scope scale`.
- `--scales <list>`: Scale scope node counts.
- `--repeat-count <n>`: Repeat jobs as separate Slurm jobs. Default: `1`.
- `--repeat-aggregation <standard|olympic>`: Repeat aggregation. Default: `standard`.
- `--gpu-preflight-filter`: Keep only nodes with passing same-day GPU topology evidence.
- `--no-wait`: Do not wait for submitted jobs.
- `--no-render`: Do not render the suite report after jobs finish.
- `-h`, `--help`: Print usage.

## Notes

Default behavior is a dry run. [submit-nccl-fleet.sh](submit-nccl-fleet.md) is a compatibility wrapper for this script.
