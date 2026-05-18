# check-artifact-policy.sh

## Purpose

Check the Git working tree for raw, generated, or unpromoted benchmark artifacts
that should not be committed by default.

## Usage

```text
scripts/report/check-artifact-policy.sh
```

## Options

- `-h`, `--help`: Print usage.

## Environment

- `AICR_ARTIFACT_POLICY_ALLOW=1`: Allow the command to exit successfully while
  still printing paths that need explicit review before commit.

## Examples

Run the policy check:

```bash
scripts/report/check-artifact-policy.sh
```

Allow a reviewed promotion pass:

```bash
AICR_ARTIFACT_POLICY_ALLOW=1 scripts/report/check-artifact-policy.sh
```

## Notes

Generated runtime evidence is not committed by default. Use the override only
when intentionally promoting reviewed reports, results, or archive evidence.
