# setup-python-local.sh

## Purpose

Build or refresh the checkout-local UV virtual environment from `uv.lock`.

## Usage

```text
scripts/setup/setup-python-local.sh [--force]
```

## Options

- `--force`: Rebuild even if the current local environment matches the lockfile.
- `-h`, `--help`: Print usage.

## Outputs

- Creates `.tools/uv-envs/aicr-bench`.
- Uses the site `uv` module on AICR HPC when available.
- Falls back to an existing `uv` in `PATH`, then local UV bootstrap.

## Examples

Build the local environment:

```bash
scripts/setup/setup-python-local.sh
```

Force a rebuild:

```bash
scripts/setup/setup-python-local.sh --force
```

Make target:

```bash
make setup-python-local
```

## Notes

This command does not edit `benchmark-settings.env`.
