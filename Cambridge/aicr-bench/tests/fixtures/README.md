# Test Fixtures

Purpose: define committed synthetic and curated fixtures for public test-driven documentation and future repo tests.

Fixtures are small, reviewed inputs with known expected outputs. They let the
repo test parsers, renderers, doc examples, and aggregation rules without
committing raw benchmark results or depending on live Slurm jobs.

Fixture-specific validators live under `tests/scripts/`. The reusable
documentation-test runner remains under `scripts/docs/`.

## Fixture Contract

Use this shape for new fixtures:

```text
tests/fixtures/<module>/<fixture-id>/
  README.md
  metadata.json
  input/
    ...
```

- `README.md`: short purpose, what behavior the fixture tests, and why it is
  synthetic or curated.
- `metadata.json`: schema version, fixture id, fixture type, input globs,
  purpose, expected values, at least one `input*` field, and
  `not_benchmark_evidence: true` when applicable.
- `input/`: minimal test inputs, using names that describe their role instead
  of runtime artifact roots such as `results/`.

## Rules

- Keep fixtures tiny enough for fast local checks.
- Prefer synthetic known-answer fixtures for aggregation, parsing, and renderer
  behavior.
- Mark synthetic or non-promoted fixtures as not benchmark evidence.
- Do not place raw runtime `results/`, tarballs, provenance JSON, operator
  logs, or Graphify artifacts in fixtures.
- If a fixture is derived from real evidence, reduce it to the minimum reviewed
  fields needed for the test and document the source boundary in metadata.
- Keep fixture validators in `tests/scripts/`; keep reusable public-doc checks
  in `scripts/docs/`.
- Run the public-docs hygiene check to enforce fixture metadata and
  runtime-artifact hygiene.

## Current Fixtures

- `dataloader/olympic-repeat`: validates that DataLoader Olympic aggregation
  drops the lowest and highest throughput samples and computes paired metrics
  from the retained jobs.
- `nccl/scaling-math`: validates NCCL `busbw` scaling efficiency, B200
  4-node-normalized AllReduce interpretation, and AICR public
  fabric-utilization denominators.
