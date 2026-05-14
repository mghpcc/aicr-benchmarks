# submit-container-install.sh

## Purpose

Submit Apptainer image installation as a Slurm job so OCI-to-SIF conversion runs on a compute node.

## Usage

```text
scripts/setup/submit-container-install.sh [--refresh] [--image-dir <path>] [--partition <name>] [--nodelist <node[,node...]>] [--time <HH:MM:SS>] [--no-wait]
```

## Options

- `--refresh`: Re-pull and replace existing images.
- `--image-dir <path>`: Override `AICR_APPTAINER_IMAGE_DIR`.
- `--partition <name>`: Slurm partition. Default: `GPU1`.
- `--nodelist <node[,node...]>`, `--nodes <node[,node...]>`: Submit to a specific node list.
- `--time <HH:MM:SS>`: Slurm time limit. Default: `04:00:00`.
- `--no-wait`: Return after job submission.
- `-h`, `--help`: Print usage.

## Outputs

- Slurm job `aicr-install-containers`.
- Logs under `results/setup/container-install-<jobid>.out` and `.err`.
- SIF images under `AICR_APPTAINER_IMAGE_DIR`.

## Examples

Submit and wait:

```bash
scripts/setup/submit-container-install.sh --nodelist a0002
```

Submit and return:

```bash
scripts/setup/submit-container-install.sh --nodelist a0002 --no-wait
```

Use Make:

```bash
make install-containers CONTAINER_NODELIST=a0002 CONTAINER_WAIT=0
```
