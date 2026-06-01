# submit-container-install.sh

## Purpose

Submit Apptainer image installation as a Slurm job so OCI-to-SIF conversion runs on a CPU compute node.

## Usage

```text
scripts/setup/submit-container-install.sh [--refresh] [--image-dir <path>] [--partition <name>] [--nodelist <node[,node...]>] [--time <HH:MM:SS>] [--mem <size>] [--no-wait]
```

## Options

- `--refresh`: Re-pull and replace existing images.
- `--image-dir <path>`: Override `AICR_APPTAINER_IMAGE_DIR`.
- `--partition <name>`: Slurm partition. Default: `cpu`.
- `--nodelist <node[,node...]>`, `--nodes <node[,node...]>`: Submit to a specific node list.
- `--time <HH:MM:SS>`: Slurm time limit. Default: `04:00:00`.
- `--mem <size>`: Slurm memory request. Default: `0`.
- `--no-wait`: Return after job submission.
- `-h`, `--help`: Print usage.

## Outputs

- Slurm job `aicr-install-containers`.
- Logs under `results/setup/container-install-<jobid>.out` and `.err`.
- SIF images under `AICR_APPTAINER_IMAGE_DIR`.

## Examples

Submit and wait:

```bash
scripts/setup/submit-container-install.sh --nodelist w0002
```

Submit and return:

```bash
scripts/setup/submit-container-install.sh --nodelist w0002 --no-wait
```

Use a non-default partition only when the CPU queue is unavailable or the site
runtime policy changes:

```bash
scripts/setup/submit-container-install.sh --partition rtx-batch --nodelist a0002
```

Use Make:

```bash
make install-containers CONTAINER_NODELIST=w0002 CONTAINER_WAIT=0
```
