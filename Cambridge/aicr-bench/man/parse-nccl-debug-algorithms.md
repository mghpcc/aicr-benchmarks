# parse-nccl-debug-algorithms.py

## Purpose

Summarize NCCL debug log lines that expose algorithm, topology, protocol, and channel-selection hints.

## Usage

```text
scripts/parse/parse-nccl-debug-algorithms.py <log-or-directory>... [--root <path>] [--markdown-output <path>] [--csv-output <path>] [--json-output <path>]
```

## Options

- `<log-or-directory>`: One or more NCCL debug log files or directories. Directories are searched recursively.
- `--root <path>`: Relativize source paths in the report.
- `--markdown-output <path>`: Write a Markdown summary. Without this option, Markdown is printed to standard output.
- `--csv-output <path>`: Write matched debug lines as CSV.
- `--json-output <path>`: Write matched debug lines as JSON.
- `--help`: Print help.

## Examples

Parse a diagnostic artifact directory:

```bash
scripts/parse/parse-nccl-debug-algorithms.py \
  /work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/<commit>/nccl/diagnostics/<run-id>/debug \
  --markdown-output nccl-debug-algorithm-summary.md \
  --csv-output nccl-debug-algorithm-lines.csv \
  --json-output nccl-debug-algorithm-lines.json
```

## Notes

This parser looks for debug lines containing NCCL tree, ring, algorithm,
protocol, and channel hints. It is intended for diagnostic evidence, not
performance certification. The parser preserves matched source lines so a human
can review the original NCCL wording before any public claim is made.
