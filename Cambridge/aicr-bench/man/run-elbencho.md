# run-elbencho.sh

## Purpose

Run an Elbencho workload inside a Slurm allocation and write raw and parsed storage benchmark artifacts.

## Usage

```text
scripts/benchmark/run-elbencho.sh --cluster <b200|rtxpro6000> --workload <small-block|small-file|metadata|peak-cluster> --profile <smoke|small> [options]
```

Use [submit-elbencho.sh](submit-elbencho.md) or `make benchmark-elbencho` for
normal Slurm submissions.

## Options

- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--workload <name>`: `peak-cluster`, `small-block`, `small-file`, or `metadata`.
- `--profile <name>`: `smoke` or `small`.
- `--command <value>`: Elbencho command template to execute.
- `--help`: Print help.

## Outputs

```text
results/by-date/<date>/raw/<cluster>/multi-node/elbencho/<run_id>/
results/by-date/<date>/parsed/<cluster>/multi-node/elbencho/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/multi-node/elbencho/<run_id>/status.json
```

Canonical artifacts include the Elbencho command, stdout, stderr, text summary,
parsed `summary.json`, `status.json`, and `record.json`, plus a by-date index
row for report discovery.
