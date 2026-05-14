# pull-verified-containers.sh

## Purpose

Pull the verified Apptainer images into the configured image directory.

## Usage

```text
apptainer/pull/pull-verified-containers.sh [--refresh] [--image-dir <path>]
```

## Options

- `--refresh`: Re-pull and replace existing verified SIF images.
- `--image-dir <path>`: Override `AICR_APPTAINER_IMAGE_DIR`.
- `-h`, `--help`: Print usage.

## Outputs

- `pytorch-25.10-py3.sif`
- `hpc-benchmarks-26.02.sif`

## Examples

Routine AICR HPC usage goes through Slurm:

```bash
make install-containers CONTAINER_NODELIST=a0002
```

Direct local debugging:

```bash
apptainer/pull/pull-verified-containers.sh --image-dir /path/to/images
```

Refresh images:

```bash
apptainer/pull/pull-verified-containers.sh --refresh
```
