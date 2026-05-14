# doctor-python.sh

## Purpose

Check the repo Python runtime selected by `scripts/lib/run-repo-python.sh`.

## Usage

```text
scripts/setup/doctor-python.sh
```

## Options

- `-h`, `--help`: Print usage.

## Outputs

- Prints selected Python environment paths.
- Verifies Python 3.11.
- Imports required Python packages.

## Examples

Run directly:

```bash
scripts/setup/doctor-python.sh
```

Run through Make:

```bash
make doctor-python
```

Expected success ends with package versions for `jsonschema`, `matplotlib`, `pandas`, and `snakemake`.
