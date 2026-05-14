# submit-nccl-fleet.sh

## Purpose

Preview or submit NCCL suite Slurm jobs for explicit node pools or discovered idle nodes.

## Usage

```text
scripts/verify/submit-nccl-fleet.sh --scope <local|rdma|survey> --cluster <b200|rtxpro6000> [options]
```

Make entrypoint:

```bash
make verify-nccl-suite NCCL_SCOPE=<local|rdma|survey> CLUSTER=<b200|rtxpro6000> PROFILE=<small|medium|large> NODELIST=<node[,node...]>
```

## Options

- `--apply`: Submit jobs with `sbatch`. Omit for dry-run preview.
- `--scope <local|rdma|survey>`: Suite scope. `local` disables IB and defaults to eight processes, one process per GPU, with 16 CPU cores per process; `rdma` uses fixed multi-node groups; `survey` samples candidate node groups for campaign planning.
- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--profile <name>`: `small`, `medium`, or `large`. Default: `small`.
- `--suite-class <name>`: Optional local-mode class filter. Supported examples include B200 `b200_1proc_8g`, B200 `b200_2rank_socket_4g`, and RTX `rtx_pair_policy`.
- `--nodes <list>`: Candidate nodes, separated by commas or spaces.
- `--nodes-per-job <n>`: RDMA group size. B200 accepts `2,4,8,16`; RTX accepts `2,4,8`.
- `--survey-sizes <list>`: Survey node counts, separated by commas or spaces. B200 accepts `1,2,4,8,16`; RTX accepts `1,2,4,8`.
- `--allow-nonstandard-node-count`: Allow RDMA or survey node counts outside the standard ladders, such as B200 `3` or `31`.
- `--partition <name>`: Override Slurm partition.
- `--time <value>`: Override Slurm time limit.
- `--repeat-count <n>`: Submit repeated jobs. Default: `1`.
- `--repeat-aggregation <name>`: `standard` or `olympic`. Default: `standard`.
- `--submit-stagger-seconds <n>`: Delay between submissions. Default: `5`.
- `--survey-stagger-seconds <n>`: Delay between completed survey sizes. Default: `0`.
- `--round-stagger-seconds <n>`: Delay between repeat rounds. Default: `0`.
- `--gpu-preflight-filter`: Keep only nodes with passing same-day GPU topology evidence.
- `--no-wait`: Return after submitting jobs.
- `--no-render`: Skip report rendering after waited jobs finish.
- `--help`: Print help.

## Examples

Preview one B200 node:

```bash
scripts/verify/submit-nccl-fleet.sh --scope survey --cluster b200 --profile small --nodes b0001 --survey-sizes 1
```

Preview one local-mode B200 node:

```bash
scripts/verify/submit-nccl-fleet.sh --scope local --cluster b200 --profile small --nodes b0001
```

Preview the B200 single-process, 8-GPU local class:

```bash
scripts/verify/submit-nccl-fleet.sh --scope local --cluster b200 --profile small --nodes b0001 --suite-class b200_1proc_8g
```

Preview the B200 two-process NUMA/socket-pinned local class. Each process gets 64 CPU cores and four GPUs from the same NUMA domain:

```bash
scripts/verify/submit-nccl-fleet.sh --scope local --cluster b200 --profile small --nodes b0001 --suite-class b200_2rank_socket_4g
```

Preview one RTX two-GPU P2P pair-policy node:

```bash
scripts/verify/submit-nccl-fleet.sh --scope local --cluster rtxpro6000 --profile small --nodes a0002 --suite-class rtx_pair_policy
```

Preview one four-node RTX RDMA group:

```bash
scripts/verify/submit-nccl-fleet.sh --scope rdma --cluster rtxpro6000 --profile small --nodes a0001,a0002,a0003,a0004 --nodes-per-job 4
```

Preview one eight-node RTX RDMA group:

```bash
scripts/verify/submit-nccl-fleet.sh --scope rdma --cluster rtxpro6000 --profile small --nodes a0001,a0002,a0003,a0004,a0005,a0006,a0007,a0008 --nodes-per-job 8
```

Preview one nonstandard B200 RDMA group:

```bash
scripts/verify/submit-nccl-fleet.sh --scope rdma --cluster b200 --profile small --nodes b0001,b0002,b0003 --nodes-per-job 3 --allow-nonstandard-node-count
```

Preview one-node and two-node groups:

```bash
scripts/verify/submit-nccl-fleet.sh --scope survey --cluster b200 --profile small --nodes b0001,b0002 --survey-sizes 1,2
```

Submit one explicit small job:

```bash
scripts/verify/submit-nccl-fleet.sh --scope survey --cluster b200 --profile small --nodes b0001 --survey-sizes 1 --apply
```
