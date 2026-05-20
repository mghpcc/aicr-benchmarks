# System Verification Runbook 2026-05-16

Purpose: document the verification command trail that produced the May 16 public evidence for benchmark readiness.

This runbook covers GPU topology, GDS, NCCL suite, archive manifests, report rendering, report validation, and public evidence publication. Benchmark runbooks are listed on the individual benchmark report pages.

## Verification Submit

```bash
make setup CLUSTER=b200 DATE=2026-05-16 APPLY=1
make setup CLUSTER=rtxpro6000 DATE=2026-05-16 APPLY=1

make verify CLUSTER=b200 DATE=2026-05-16 PROFILE=small REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic APPLY=1
make verify CLUSTER=rtxpro6000 DATE=2026-05-16 PROFILE=small REPEAT_COUNT=5 REPEAT_AGGREGATION=olympic GPU_PREFLIGHT_FILTER=1 APPLY=1
```

## Archive, Render, Validate

```bash
for cluster in b200 rtxpro6000; do
  make archive-verify CLUSTER="$cluster" DATE=2026-05-16 ARCHIVE_ROTATE=1
  make render CLUSTER="$cluster" DATE=2026-05-16
  make validate-reports CLUSTER="$cluster" DATE=2026-05-16
done
```

Expected dashboard rows:

```text
2026-05-16 | rtxpro6000 | verification | passed | 4/4 | report | report | report | report | report
2026-05-16 | b200       | verification | passed | 4/4 | report | report | report | report | report
```

## Candidate Selection

```bash
bash scripts/lib/run-repo-python.sh scripts/benchmark/select-benchmark-nodes.py --date 2026-05-16 --cluster b200 --format lines
bash scripts/lib/run-repo-python.sh scripts/benchmark/select-benchmark-nodes.py --date 2026-05-16 --cluster rtxpro6000 --format lines
```

## Public Evidence Publication

```bash
PATH=/work/aicr/commissioning/benchmarks/runtime/rclone:$PATH \
  make archive-verification-campaign-all DATE=2026-05-16 ARCHIVE_ROTATE=1
```

The public OSN copy contains curated verification report bundles and manifests. Additional raw and parsed evidence is retained in the HPC results archive for audit/debug.
