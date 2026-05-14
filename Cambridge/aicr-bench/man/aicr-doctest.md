# aicr-doctest.py

## Purpose

Parse and run executable Markdown examples from the public AICR-Bench documentation.

## Usage

```text
scripts/docs/aicr-doctest.py [--suite SUITE] [--docs PATH ...] [--cluster CLUSTER] [--nodelist NODELIST] [--date DATE] [--runtime-root PATH] [--test-id ID] [--apply] {plan,run}
```

The normal entrypoints are:

```bash
make docs-test
make docs-test-plan
```

## Options

- `--suite <name>`: Select a suite such as `gds`, `nccl`, `dataloader`, or `all`. Script default: `gds`; Make default: `all`.
- `--docs <path> ...`: Markdown files or directories to scan.
- `--cluster <name>`: Cluster placeholder value. Default: `b200`.
- `--nodelist <csv>`: Node list used for one-node and two-node applied checks.
- `--date <value>`: Date placeholder value. Default: `today`.
- `--runtime-root <path>`: Runtime root placeholder value.
- `--test-id <id>`: Run only a specific test id. May be repeated.
- `--apply`: Allow `slurm-apply` tests. `make docs-test` sets this through `DOCS_APPLY=1`.
- `plan`: Print selected tests without running them.
- `run`: Run selected tests and write a summary.

## Outputs

Documentation test artifacts are written under:

```text
results/doc-tests/<date>/<run-id>/
```

The runner writes `summary.json`, `summary.md`, and per-test stdout/stderr files.

## Examples

List selected public documentation tests:

```bash
make docs-test-plan
```

Run the local and dry-run public documentation tests:

```bash
make docs-test
```

Allow one applied Slurm documentation test on an explicit node:

```bash
make docs-test DOCS_APPLY=1 NODELIST=b0001 DOCS_TEST_ID=gds-one-node-small
```

## Notes

Applied tests require `DOCS_APPLY=1` and an explicit `NODELIST`. The runner refuses GDS, NCCL, and DataLoader submission examples without `NODELIST` so executable docs do not accidentally become fleet or broad runs.
