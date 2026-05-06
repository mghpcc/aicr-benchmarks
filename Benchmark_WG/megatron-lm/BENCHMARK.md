# Megatron-LM Benchmark

GPT pretraining throughput benchmark across RTX-6000 and B200 GPUs using Slurm + Apptainer.

## Script overview

| Script | Role |
|--------|------|
| `submit.sh` | Top-level entry point — submits all benchmark jobs via `sbatch` |
| `job.sh` | Slurm batch script — sets up the environment and launches the Apptainer container |
| `run.sh` | Runs **inside the container** — configures the model and launches `torchrun` |

## Quick start

```bash
bash submit.sh
```

This submits the full benchmark matrix: 1–16 GPUs (1–2 nodes) on both RTX-6000 (GPU1 partition) and B200 (GPU2 partition).

## Submitting a single job

```bash
sbatch -p GPU2 -N 1 -n 1 --gpus-per-node=b200:4 job.sh 512
```

The only required argument to `job.sh` is the **global batch size (GBS)**. The recommended formula is:

```
GBS = 128 × total_GPUs
```

With micro-batch-size fixed at 4, gradient accumulation steps = `GBS / (4 × total_GPUs) = 32`.

## Benchmark matrix

GBS is set to `128 × total_GPUs` in all cases.

### RTX-6000 — 2B-param model (partition: GPU1)

| Nodes | GPUs/node | Total GPUs | GBS  |
|-------|-----------|-----------|------|
| 1     | 1         | 1         | 128  |
| 1     | 2         | 2         | 256  |
| 1     | 4         | 4         | 512  |
| 1     | 8         | 8         | 1024 |
| 2     | 1         | 2         | 256  |
| 2     | 2         | 4         | 512  |
| 2     | 4         | 8         | 1024 |
| 2     | 8         | 16        | 2048 |

### B200 — 7B-param model (partition: GPU2)

| Nodes | GPUs/node | Total GPUs | GBS  |
|-------|-----------|-----------|------|
| 1     | 1         | 1         | 128  |
| 1     | 2         | 2         | 256  |
| 1     | 4         | 4         | 512  |
| 1     | 8         | 8         | 1024 |
| 2     | 1         | 2         | 256  |
| 2     | 2         | 4         | 512  |
| 2     | 4         | 8         | 1024 |
| 2     | 8         | 16        | 2048 |

## Model configurations

Model size is selected automatically by `run.sh` based on GPU type.

| GPU type  | Layers | Hidden | FFN   | Heads | Approx params |
|-----------|--------|--------|-------|-------|---------------|
| rtx6000   | 24     | 2048   | 8192  | 16    | ~2B           |
| b200      | 36     | 4096   | 14336 | 32    | ~7B           |

All runs use sequence length 2048, BF16, mock data, and 100 training iterations.

## GPU pinning

The cluster has no cgroup GPU isolation, so `job.sh` pins `CUDA_VISIBLE_DEVICES` explicitly:

- **1 GPU/node** — hardcoded to `0` to prevent NCCL deadlocks (PyTorch maps rank N → GPU N by default, which collides when ranks share a physical GPU 0).
- **>1 GPU/node** — set from `SLURM_JOB_GPUS` (evaluated per-node inside each `srun` task).

## Container image

The job runs inside `pytorch_26.02-py3.sif`, pulled from the NVIDIA NGC registry.

**1. Create the image directory**

```bash
mkdir -p /home/shaohao_mit/benchmarks/megatron-lm/imag
cd /home/shaohao_mit/benchmarks/megatron-lm/imag
```

**2. (First time only) Authenticate with NGC**

Create a free account at https://ngc.nvidia.com and generate an API key under
*Organization → Setup → Generate API Key*. Then log in:

```bash
apptainer registry login --username '$oauthtoken' --password <YOUR_NGC_API_KEY> docker://nvcr.io
```

**3. Pull the image**

```bash
apptainer pull pytorch_26.02-py3.sif docker://nvcr.io/nvidia/pytorch:26.02-py3
```

This converts the Docker image to a `.sif` file in place. It takes ~10–20 minutes
and requires ~20 GB of free disk space. Run it on a login node (no GPU needed).

**4. Verify**

```bash
apptainer exec pytorch_26.02-py3.sif python -c "import torch; print(torch.__version__)"
```

## Paths

All paths are set in `job.sh` and `run.sh`:

```
work_path   /home/shaohao_mit/benchmarks/megatron-lm
megatron_path  $work_path/Megatron-LM
imag_path   $work_path/imag   # Apptainer image: pytorch_26.02-py3.sif
```

## Output logs

Job output is written to `output/out.<hostname>-<jobid>` (configured via `#SBATCH -o`).

```bash
ls output/
tail -f output/out.<node>-<jobid>
```

Look for `throughput` lines in the log to get tokens/sec per GPU.
