# Cambridge Handoff Inventory - 2026-05-18

Purpose: record the local inventory and gap assessment for moving the Cambridge public package from `ohpcsim/aicr-public` to `mghpcc/aicr-benchmarks` after explicit copy approval.

## Source Decision

`aicr-public/Cambridge` is the review buffer and source of truth for the Cambridge public package. The canonical `/Users/chrissimmons/git/aicr-bench` repo is used only as a comparison source for public-relevant fixes. The `/Users/chrissimmons/git/aicr-benchmarks` repo remains read-only until explicit copy approval.

Current local state at inventory time:

| Repo | State |
| --- | --- |
| `/Users/chrissimmons/git/aicr-public` | `main` clean and aligned with `origin/main` before these inventory edits |
| `/Users/chrissimmons/git/aicr-bench` | `main` clean, one local commit ahead of origin: `819c837 Allow RTX DataLoader 8 and 16 node sweeps` |
| `/Users/chrissimmons/git/aicr-benchmarks` | `main` clean and aligned with `origin/main`; do not write without explicit copy approval |

## Inventory

Tracked-file counts from local manifests:

| Package | Count | Notes |
| --- | ---: | --- |
| `aicr-public/Cambridge` | 379 | Public handoff package including reports, archives, SOW mapping, runbook, and embedded suite |
| `aicr-public/Cambridge/aicr-bench` | 295 | Public embedded suite |
| canonical `aicr-bench` | 614 | Full internal/canonical repo with historical results, plans, wiki, examples, and debug tools |
| `aicr-benchmarks/Cambridge/aicr-bench` | 172 | Older embedded suite currently missing several public handoff components |
| `aicr-public/Cambridge/reports` | 78 | May 16 campaign/verification reports plus May 17 supplemental artifacts |
| `aicr-public/Cambridge/archives` | 2 | May 16 B200 and RTX verification archive manifests |

## Gap Classification

Required for SOW handoff and already present in `aicr-public/Cambridge`:

- Top-level Cambridge index, SOW conformance page, and verification runbook.
- May 16 benchmark summaries for B200 and RTX Pro 6000.
- DataLoader, DDP, HPL-MxP, and Elbencho public reports and selected CSV/JSON/PNG artifacts referenced by the SOW page.
- May 16 system verification dashboards, node reports, GDS, GPU topology, NCCL suite reports, and verification archive manifests.
- Embedded `aicr-bench` module docs, command man pages, campaign requirements registry, report renderers, benchmark launchers, setup helpers, fixtures, and validation scripts.

Required when copying to `aicr-benchmarks` later:

- Replace the older `aicr-benchmarks/Cambridge/aicr-bench` with the finalized public embedded suite.
- Add the full `Cambridge/reports`, `Cambridge/archives`, `Cambridge/README.md`, `Cambridge/sow-conformance-2026-05-16.md`, and `Cambridge/verification-runbook-2026-05-16.md` package.
- Treat the 125 files present in the public embedded suite but missing from the current benchmarks embedded suite as required public handoff material.

Optional operator convenience:

- Runtime rebuild and setup promotion helpers, container install helpers, and dry-run benchmark composition scripts are useful for a runnable public suite and should stay in the public embedded package.
- Study pages and figures under `docs/modules/*/studies/` provide useful provenance context for operators but are not the source of truth for the final SOW result tables.

Canonical-only or internal material to exclude by default:

- Historical canonical `results/`, broad `docs/plan/`, `docs/reporting/`, `examples/`, `wiki/`, graphify cache files, and node-debug/sync/export tooling.
- Canonical debug scripts under `scripts/debug/` and node-debug render/archive helpers unless a future handoff explicitly includes node-debug evidence.

Stale or replace-on-copy material in current `aicr-benchmarks`:

- `slurm/verify/*-nccl-suite-survey.sbatch` exists only in the current benchmarks embedded suite. The public suite uses the newer `*-nccl-suite-scale.sbatch` naming and should replace the older survey wrappers during the approved copy.

## Canonical Comparison

The canonical `aicr-bench` local commit `819c837` updates RTX DataLoader 8/16-node support. The public embedded suite already contains the corresponding runtime behavior in the DataLoader runner and sweep/submit scripts. The public Make help text was updated in this pass so the documented DataLoader node support now matches the scripts.

No broad canonical copy is recommended. The canonical tree contains important internal history, but the public Cambridge package should stay focused on SOW evidence and runnable public tooling.

## Validation Checklist

Run from `Cambridge/aicr-bench` in `aicr-public`:

```bash
make docs-link-check
bash scripts/lib/run-repo-python.sh tests/scripts/check-dataloader-olympic-fixture.py
bash scripts/lib/run-repo-python.sh tests/scripts/check-dataloader-report-shape-fixture.py
bash scripts/lib/run-repo-python.sh scripts/report/validate-benchmark-campaign-registry.py
bash scripts/report/check-artifact-policy.sh
git diff --check
```

Run from `aicr-public` after code changes:

```bash
graphify update .
```

Copying into `aicr-benchmarks` is a separate manual step and requires explicit approval.
