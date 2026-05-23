# GDS Script Interface

Purpose: document the GDS primitives for users building their own validation workflow.

GDS scripts validate host CUDA/GDS tooling with `gdscheck -p` and profile-selected `gdsio` phases. The script layer is useful when you want to inspect a profile, run inside your own Slurm allocation, or compose custom GDS validation outside the Make driver.

## Inspect The Interface

Allocation-side runner:

<!-- aicr-test
id: gds-run-help
suite: gds
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "Usage:"
    - "--inspect-profile"
-->
```bash
scripts/verify/run-gds.sh --help
```

Host-side fleet submitter:

<!-- aicr-test
id: gds-fleet-help
suite: gds
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--submit-stagger-seconds"
    - "benchmark"
-->
```bash
scripts/verify/run-gds-fleet.sh --help
```

Compatibility wrapper:

<!-- aicr-test
id: gds-submit-wrapper-help
suite: gds
kind: local
safety: help
cwd: install-root
expect:
  mode: contains
  patterns:
    - "--submit-stagger-seconds"
-->
```bash
scripts/verify/submit-gds-fleet.sh --help
```

## Inspect A Profile

The `small` profile is the default learning and readiness profile.

<!-- aicr-test
id: gds-inspect-small
suite: gds
kind: local
safety: inspect
cwd: install-root
expect:
  mode: contains
  patterns:
    - "profile=small"
-->
```bash
scripts/verify/run-gds.sh --profile small --inspect-profile
```

The `smoke` profile is the default applied documentation test profile because
it proves the allocation-side flow without sustained storage pressure.

<!-- aicr-test
id: gds-inspect-smoke
suite: gds
kind: local
safety: inspect
cwd: install-root
expect:
  mode: contains
  patterns:
    - "profile=smoke"
-->
```bash
scripts/verify/run-gds.sh --profile smoke --inspect-profile
```

Custom argument profiles can also be inspected without launching `gdsio`.

<!-- aicr-test
id: gds-inspect-custom-args
suite: gds
kind: local
safety: inspect
cwd: install-root
expect:
  mode: contains
  patterns:
    - "profile=custom"
    - "config=custom-gdsio-args"
-->
```bash
scripts/verify/run-gds.sh --custom-gdsio-args '-x 0 -I 0 -d 0 -w 1 -m 0 -s 1G -i 1M' --inspect-profile
```

## Profiles

| Profile | Use |
| --- | --- |
| `smoke` | Tiny launch, construction, and teardown proof. |
| `small` | Teaching-sized readiness check. |
| `medium` | Longer readiness check. |
| `large` | Extended validation. |
| `custom` | One custom `gdsio` command or JSON profile config. |

## Custom Direct Use

Use [run-gds.sh](../../../man/run-gds.md) inside an existing Slurm allocation.
Use [run-gds-fleet.sh](../../../man/run-gds-fleet.md) when you want the
script layer to discover or target nodes and submit GDS jobs directly.

The direct fleet submitter and curated Make interface default to a 30-second
numeric GDS stagger for public examples and repeatable validation.

Use JSON for durable custom profiles, or `--custom-gdsio-args` for one-off
experiments. The script owns the target file unless expert target-file override
is explicitly enabled.

By default, a custom `gdsio` command omits `-f` and lets AICR-Bench append a
managed per-run target file:

```bash
scripts/verify/run-gds.sh --custom-gdsio-args '-x 0 -I 0 -d 0 -w 8 -m 0 -s 32G -i 16M -T 30'
```

Only use `--allow-custom-target-file` when the target path is itself part of
the experiment. The target directory must already exist or be created by the
calling wrapper, and the caller is responsible for cleanup:

```bash
custom_target="/path/to/custom/gdsio-target.dat"
mkdir -p "$(dirname "$custom_target")"

scripts/verify/run-gds.sh \
  --allow-custom-target-file \
  --custom-gdsio-args "-x 0 -I 0 -d 0 -w 8 -m 0 -s 32G -i 16M -T 30 -f ${custom_target}"

rm -f -- "$custom_target"
```

For promoted benchmark-style GDS runs, use
`--submit-stagger-seconds benchmark` with
[run-gds-fleet.sh](../../../man/run-gds-fleet.md). Numeric stagger values
are useful when you intentionally want to study filesystem launch pressure;
`benchmark` spaces `sbatch` calls by five seconds and creates a Slurm
`afterany` dependency chain by job ID so only one selected GDS job runs at a
time.

## Artifacts

Direct GDS runner and fleet-submitter runs write node-level raw captures, parsed summaries, and index records. Rendered dashboards are renderer or Make outputs and are intentionally not listed here.

Raw run directory:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/
```

Canonical files:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/canonical/nvidia-smi-L.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/canonical/nvidia-smi-topo-m.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/canonical/gds-summary.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/canonical/gdscheck-platform.txt
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/canonical/gdsio-<phase>.txt
```

Wrapper and metadata files:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/wrapper/cufile.log
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/wrapper/slurm-<job_id>.out
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/wrapper/slurm-<job_id>.err
results/by-date/<date>/raw/<cluster>/nodes/<node>/gds/<run_id>/metadata/record.json
```

Parsed and index files:

```text
results/by-date/<date>/parsed/<cluster>/nodes/<node>/gds/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/nodes/<node>/gds/<run_id>/status.json
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
```
