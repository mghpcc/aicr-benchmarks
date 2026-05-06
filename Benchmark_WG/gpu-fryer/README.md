# gpu-fryer SLURM Benchmarks

Runs [gpu-fryer](https://github.com/PieselBois/gpu-fryer) across a SLURM cluster to measure per-GPU TFLOPS (FP32, BF16, FP8), thermals, and power draw. Each job fires three back-to-back precision runs and writes a self-contained `.out` file.

## Prerequisites

- SLURM cluster with GPU partitions
- Singularity/Apptainer available on compute nodes
- gpu-fryer SIF image placed at the path referenced in `job.sh`
- NVML library available on compute nodes (path set via `--nvml-lib-path`)

## Getting the image

Pull the Singularity/Apptainer SIF from the upstream Docker image:

```bash
apptainer pull gpu-fryer.sif docker://ghcr.io/huggingface/gpu-fryer:1.1.0
```

Or with the older `singularity` command:

```bash
singularity pull gpu-fryer.sif docker://ghcr.io/huggingface/gpu-fryer:1.1.0
```

Then set the `SIF` variable in `job.sh` to the absolute path of the resulting `.sif` file.

## Files

| File | Purpose |
|------|---------|
| `job.sh` | SLURM job script — runs FP32 → BF16 → FP8 on all GPUs of one node |
| `submit.sh` | One-liner commands to submit `job.sh` to a specific partition |
| `loop-node.sh` | Submits `job.sh` to every node in `nodes.b200` and `nodes.rtx6000` |
| `nodes.b200` | List of B200 node names (one per line) |
| `nodes.rtx6000` | List of RTX PRO 6000 node names (one per line) |

## Single-node submission

Edit `job.sh` to set the target partition, GPU count, and duration, then submit:

```bash
# 8-GPU node on partition GPU2 (B200)
sbatch -N 1 -n 8 -c 8 --mem=1000GB --gres=gpu:8 -p GPU2 job.sh

# 8-GPU node on partition GPU1 (RTX PRO 6000)
sbatch -N 1 -n 8 -c 8 --mem=1000GB --gres=gpu:8 -p GPU1 job.sh
```

These commands are also recorded in `submit.sh` for reference.

> **CPU requirement:** pass `-c 8` (minimum `-c 2`). gpu-fryer uses Tokio async workers for timers and progress reporting — if the CPU count equals or is less than the GPU count, those workers starve and the job appears to hang.

## Fleet-wide submission

To benchmark every node in the fleet at once:

```bash
bash loop-node.sh
```

Output files land in `all-out/` named `<nodename>-<jobid>.out`. The node lists read from `nodes.b200` and `nodes.rtx6000` — edit those files to add or remove nodes before running.

## Configuring `job.sh`

Key variables near the top of the script:

```bash
SIF="/path/to/gpu-fryer.sif"        # path to Singularity image
FLAGS="--nvml-lib-path /path/to/libnvidia-ml.so.1"
ELAPSE="300"                         # seconds per precision run
```

The `#SBATCH` directives at the top of `job.sh` serve as defaults when submitting without command-line overrides. Command-line flags passed to `sbatch` take precedence.

## Output

Each `.out` file contains three sections separated by `======== Run with <precision> ==========` headers. At the end of each section gpu-fryer prints per-GPU TFLOPS and a health summary.

Example (B200, 8 GPUs):

```
======== Run with fp32 ==========
...
GPU 0: 779.7 GFLOPS (mean)
...
All GPUs seem healthy
======== Run with bf16 ==========
...
======== Run with fp8  ==========
...
```

## Expected performance

| GPU | FP32 (TFLOPS) | BF16 (TFLOPS) | FP8 (TFLOPS) |
|-----|--------------|--------------|-------------|
| NVIDIA B200 | ~768 | ~1,491 | ~4,086 |
| RTX PRO 6000 Blackwell | ~205 | ~419 | ~881 |

Values are per-GPU means at the default matrix size. FP8 on B200 achieves ~91% of dense Tensor Core peak.
