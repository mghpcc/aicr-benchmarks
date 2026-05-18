# GPU Topology Make Interface

Purpose: document the curated Make entrypoint for topology collection.

## Fleet Verification

```bash
make verify-topology CLUSTER=<b200|rtxpro6000>
```

Default behavior is a dry run. Add `NODELIST=<node[,node...]>` to limit the
collection to explicit nodes. Add `APPLY=1` to submit jobs.

## Executable Documentation

Plan the replayable GPU Topology documentation checks:

```bash
make docs-test-plan-gpu-topology
```

Run the local-safe GPU Topology documentation checks:

```bash
make docs-test-gpu-topology
```

On AICR HPC, one-node apply checks must use explicit apply mode and a selected
node:

```bash
DOCS_APPLY=1 NODELIST=<node> make docs-test-gpu-topology
```

## Campaign Verification

Topology is included in the combined verification flow:

```bash
make system-verify CLUSTER=<b200|rtxpro6000> PROFILE=small APPLY=1
```

## Artifacts

Topology Make flows produce node-level raw captures, parsed summaries, fleet
manifests, and rendered dashboards.

Node-level raw and parsed files:

```text
results/by-date/<date>/raw/<cluster>/nodes/<node>/gpu-topology/<run_id>/
results/by-date/<date>/parsed/<cluster>/nodes/<node>/gpu-topology/<run_id>/summary.json
results/by-date/<date>/parsed/<cluster>/nodes/<node>/gpu-topology/<run_id>/status.json
```

Fleet and report files:

```text
results/by-date/<date>/index.jsonl
results/by-node/<cluster>/<node>/history.jsonl
results/reports/<date>/gpu-topology/<manifest>.json
results/reports/<date>/gpu-topology-<cluster>.md
```
