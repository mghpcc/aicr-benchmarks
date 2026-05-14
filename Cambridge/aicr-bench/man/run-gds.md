# run-gds.sh

## Purpose

Run GDS validation on one allocated GPU node.

## Usage

```text
scripts/verify/run-gds.sh [--profile <small|medium|large>] [--inspect-profile]
scripts/verify/run-gds.sh --custom-gdsio-args '<gdsio args>'
```

## Options

- `--profile <name>`: Select `small`, `medium`, `large`, or `custom`. Default: `small`.
- `--profile-config <path>`: Override the selected profile config JSON.
- `--custom-gdsio-args <args>`: Run one custom `gdsio` phase only.
- `--allow-custom-target-file`: Permit `--custom-gdsio-args` to provide its
  own `gdsio -f/--file` target. Without this flag, AICR-Bench rejects custom
  target files and appends a managed per-run scratch target automatically.
- `--inspect-profile`: Validate and print the profile without running GDS.
- `-h`, `--help`: Print usage.

## Outputs

- Raw command output under `results/by-date/<date>/raw/.../gds/<run_id>/`.
- Parsed `summary.json` and `status.json`.
- Hidden GPU preflight evidence: `nvidia-smi-L.txt` and `nvidia-smi-topo-m.txt`.

## Examples

Inspect the default profile:

```bash
scripts/verify/run-gds.sh --profile small --inspect-profile
```

Run on an allocated node:

```bash
scripts/verify/run-gds.sh --profile small
```

Run one custom command:

```bash
scripts/verify/run-gds.sh --custom-gdsio-args '-x 0 -I 0 -d 0 -w 8 -m 0 -s 32G -i 16M -T 30'
```

Run one custom command against an expert-provided target file:

```bash
custom_target="/path/to/custom/gdsio-target.dat"
mkdir -p "$(dirname "$custom_target")"

scripts/verify/run-gds.sh \
  --allow-custom-target-file \
  --custom-gdsio-args "-x 0 -I 0 -d 0 -w 8 -m 0 -s 32G -i 16M -T 30 -f ${custom_target}"

rm -f -- "$custom_target"
```

Use this only when the target path itself is part of the experiment. In this
mode AICR-Bench records the command and parsed results, but it does not choose,
isolate, or clean up the custom target file for you.

Use a custom JSON profile:

```bash
AICR_GDS_PROFILE_CONFIG=/path/to/custom-gds.json scripts/verify/run-gds.sh --profile custom
```
