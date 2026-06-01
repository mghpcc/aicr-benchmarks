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
- `--suite-class <name>`: Optional local suite-class filter. Supported values
  are B200 `b200_8rank_1g`, `b200_1proc_8g`, `b200_2rank_socket_4g`, and RTX
  `rtx_8rank_1g`, `rtx_pair_policy`.
- `--ops <list>`: Optional comma-separated operation filter. Supported values
  are `allreduce`, `allgather`, `reduce_scatter`, `alltoall`, and `sendrecv`.
- `--nodes <list>`: Optional space- or comma-separated candidate node list.
- `--nodes-per-job <n>`: RDMA group size, or one scale for `--scope scale`.
- `--scales <list>`: Scale scope node counts.
- `--partition <name>`: Override the cluster default partition.
- `--time <value>`: Override the Slurm time limit.
- `--repeat-count <n>`: Repeat jobs as separate Slurm jobs. Default: `1`.
- `--repeat-aggregation <standard|olympic>`: Repeat aggregation. Default: `standard`.
- `--gpu-preflight-filter`: Keep only nodes with passing same-day GPU topology evidence.
- `--submit-stagger-seconds <n>`: Delay between job submissions. Default: `5`.
  The GDS fleet submitter additionally accepts `benchmark` to serialize storage
  pressure via an `afterany` dependency chain; that mode is GDS-specific and is
  not used for NCCL.
- `--scale-stagger-seconds <n>`: Additional delay after one scale finishes before the next starts. Default: `0`.
- `--round-stagger-seconds <n>`: Delay between repeat rounds. Default: `0`.
- `--no-wait`: Do not wait for submitted jobs.
- `--no-render`: Do not render the suite report after jobs finish.
- `-h`, `--help`: Print usage.

## Notes

Default behavior is a dry run.

`local` scope runs one-node communication checks. `rdma` scope runs explicit
multi-node groups. `scale` scope walks a rank-per-GPU ladder, submitting one
scale at a time in apply mode so the smaller scale finishes before the next
scale is submitted.

B200 scale defaults to `1,2,4,8,16`. RTX scale defaults to `1,2,4`. B200 RDMA
supports `--nodes-per-job 2,4,8,16`; RTX RDMA supports `--nodes-per-job 2,4,8`.

RDMA and scale runs synthesize suite-class labels from their scope and node
count, such as `b200_rdma_2n_8rank_1g_per_node` or
`rtxpro6000_scale_4n_8rank_1g_per_node`.
