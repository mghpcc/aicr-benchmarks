# run-nccl-suite.sh

## Purpose

Run NCCL suite commands inside an existing Slurm allocation and write raw, parsed, and record artifacts.

## Usage

```text
scripts/verify/run-nccl-suite.sh --scope <local|rdma|survey> [options]
scripts/verify/run-nccl-suite.sh --profile <small|medium|large> --inspect-profile
```

This script is normally called by Slurm wrappers under `slurm/verify/`. Use `make verify-nccl-suite` or `scripts/verify/submit-nccl-fleet.sh` from the install root for normal operation.

## Options

- `--scope <local|rdma|survey>`: Required suite scope.
- `--cluster <name>`: `b200` or `rtxpro6000`. Defaults from environment when present.
- `--profile <name>`: `small`, `medium`, or `large`. Default: `small`.
- `--suite-class <name>`: Optional local diagnostic class filter. Public examples include B200 `b200_1proc_8g`, B200 `b200_2rank_socket_4g`, and RTX `rtx_pair_policy`.
- `--nodes-per-job <n>`: Multi-node node-count metadata.
- `--inspect-profile`: Print the selected profile without running NCCL.
- `--help`: Print help.

## Environment

- `HPCBENCH_IMAGE`: Override the NVIDIA HPC Benchmarks SIF image.
- `NCCL_SUITE_RUN_ID`: Override the generated run id.
- `NCCL_SUITE_OPS`: Optional comma-separated operation filter, such as `allreduce`.
- `NCCL_DEBUG_FILE`: Optional NCCL debug log path pattern, such as `/work/.../nccl-debug-%h-%p.log`.
- `AICR_RUNTIME_ROOT`: Base runtime tree.
- `AICR_APPTAINER_IMAGE_DIR`: Image directory. Default: `${AICR_RUNTIME_ROOT}/apptainer/images`.

## Examples

Inspect help:

```bash
scripts/verify/run-nccl-suite.sh --help
```

Inspect the small profile:

```bash
scripts/verify/run-nccl-suite.sh --profile small --inspect-profile
```

Run manually inside an allocated one-node B200 Slurm job:

```bash
scripts/verify/run-nccl-suite.sh --scope survey --cluster b200 --profile small --nodes-per-job 1
```

## Notes

Manual use requires an active GPU Slurm allocation with `benchmark-settings.env` loaded by the wrapper or current shell. The script expects the HPC Benchmarks container to already exist in the configured runtime image directory.

For `--scope local`, the runner sets `NCCL_IB_DISABLE=1` by default and the default local shape is eight processes, one process per GPU, with 16 CPU cores per process. For `--scope rdma` and `--scope survey`, it defaults `NCCL_IB_DISABLE=0`.

The B200 `b200_1proc_8g` class runs one process across the node CPU allocation while communicating simultaneously with all eight GPUs. The B200 `b200_2rank_socket_4g` class runs two processes; each process receives 64 CPU cores, is pinned to a socket, and communicates with four GPUs in the same NUMA domain.

The RTX `rtx_pair_policy` class runs preferred two-GPU pairs `0,1`, `2,3`, `4,5`, and `6,7` with `allreduce`, `allgather`, `reduce_scatter`, and `sendrecv`.
