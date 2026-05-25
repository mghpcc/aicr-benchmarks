# smoke-test-elbencho.sh

## Purpose

Validate the optional Elbencho runtime image inside a Slurm smoke allocation.

## Usage

```text
scripts/verify/smoke-test-elbencho.sh [image.sif]
```

The helper is normally launched through the setup-gate Slurm templates:

```bash
sbatch --mem=0 slurm/verify/b200-elbencho-smoke.sbatch
sbatch --mem=0 slurm/verify/rtxpro6000-elbencho-smoke.sbatch
```

## Behavior

The check runs `elbencho --version` inside the configured Apptainer image and
requires CUDA plus cufile/GDS feature signals. It writes setup-scope raw,
parsed, status, and record artifacts under `results/setup/`.

## Notes

The Elbencho image is optional and is not built by the default container
install path. Build it first with `make install-elbencho APPLY=1` or
`make install-containers INSTALL_ELBENCHO_CONTAINER=1 APPLY=1` when validating
a private runtime root.
