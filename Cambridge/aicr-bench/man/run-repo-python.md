# run-repo-python.sh

## Purpose

Run a Python command through the repository-managed Python runtime. The wrapper
loads the AICR path helpers and then delegates to the configured UV-managed
environment.

## Usage

```text
scripts/lib/run-repo-python.sh <python-script-or-module> [args...]
```

## Options

- `<python-script-or-module>`: Python entrypoint or module arguments accepted by
  the repo Python runner.
- `[args...]`: Arguments forwarded unchanged to the Python entrypoint.

## Examples

Run a docs hygiene check:

```bash
bash scripts/lib/run-repo-python.sh scripts/docs/check-public-docs.py
```

Run a DataLoader fixture check:

```bash
bash scripts/lib/run-repo-python.sh tests/scripts/check-dataloader-olympic-fixture.py
```

## Notes

Use this wrapper for repo validation, report rendering, and one-off Python
helpers so local and HPC runs use the same managed Python environment.
