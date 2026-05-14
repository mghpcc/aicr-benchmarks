# Runtime Assets

Runtime assets are Python environments and Apptainer containers used by AICR-Bench modules.

## Runtime Root

`AICR_RUNTIME_ROOT` is the base directory for shared runtime assets. On AICR HPC the default is:

```bash
AICR_RUNTIME_ROOT=/work/aicr/commissioning/benchmarks/runtime
```

To use a private runtime tree, set it in `benchmark-settings.env`:

```bash
AICR_RUNTIME_ROOT=/path/to/aicr-runtime
AICR_APPTAINER_IMAGE_DIR="${AICR_RUNTIME_ROOT}/apptainer/images"
AICR_UV_ROOT="${AICR_RUNTIME_ROOT}/uv"
AICR_UV_ENVS_DIR="${AICR_RUNTIME_ROOT}/uv-envs"
AICR_UV_ENV_PREFIX="${AICR_UV_ENVS_DIR}/aicr-bench"
AICR_UV_BIN="${AICR_UV_ROOT}/bin/uv"
```

The `AICR_UV_*` settings are the supported Python runtime interface.

## Python Environment

On AICR HPC, `make setup-python-local` first tries the site `uv` module:

```bash
source /apps/umass/.utilities/environment
module load uv
```

The setup helper performs that load automatically when `AICR_USE_UV_MODULE=1`, including the Lmod shell initialization needed by non-interactive Slurm or SSH shells. If the module environment is not present, it falls back to an existing `uv` in `PATH`, then to a local `uv` bootstrap.

For checkout-local development:

```bash
make setup-python-local
make doctor-python
```

Shared container builds run through Slurm. This keeps large OCI-to-SIF conversions off the login node.

## Containers

GDS does not require a container on AICR systems; it uses host CUDA/GDS tools such as `gdscheck` and `gdsio`.

NCCL uses the NVIDIA HPC Benchmarks image:

```bash
${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif
```

Container-backed modules use Apptainer images under:

```bash
${AICR_APPTAINER_IMAGE_DIR}
```

Install the default public runtime containers through an RTX Slurm node:

```bash
make install-containers
```

The target submits `slurm/setup/install-containers.sbatch` to `CONTAINER_PARTITION=GPU1` and waits for the job to finish. The default image set pulls one PyTorch image and one NVIDIA HPC Benchmarks image.

Refresh existing images:

```bash
make install-containers CONTAINER_REFRESH=1
```

Submit to a specific RTX node when needed:

```bash
make install-containers CONTAINER_NODELIST=a0002
```

Submit and return immediately:

```bash
make install-containers CONTAINER_NODELIST=a0002 CONTAINER_WAIT=0
```

The submit wrapper prints the Slurm job id and writes logs under `results/setup/container-install-<jobid>.out` and `results/setup/container-install-<jobid>.err`.

Monitor or cancel a submitted build:

```bash
squeue -j <jobid>
tail -f results/setup/container-install-<jobid>.out
scancel <jobid>
```

Use a private runtime tree by setting `AICR_RUNTIME_ROOT` and the derived paths in `benchmark-settings.env` before submitting the job:

```bash
AICR_RUNTIME_ROOT=/path/to/aicr-runtime
AICR_APPTAINER_IMAGE_DIR="${AICR_RUNTIME_ROOT}/apptainer/images"
AICR_UV_ROOT="${AICR_RUNTIME_ROOT}/uv"
AICR_UV_ENVS_DIR="${AICR_RUNTIME_ROOT}/uv-envs"
AICR_UV_ENV_PREFIX="${AICR_UV_ENVS_DIR}/aicr-bench"
AICR_UV_BIN="${AICR_UV_ROOT}/bin/uv"
```

The default image set includes one PyTorch image and one NVIDIA HPC Benchmarks image. Optional probe images are installed only when their flags are enabled.

For exceptional local-only debugging, `make install-containers-local` runs the pull helper in the current shell. Do not use that path for routine AICR HPC runtime builds.
