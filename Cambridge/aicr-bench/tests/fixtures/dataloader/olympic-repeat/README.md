# DataLoader Olympic Repeat Fixture

Purpose: provide a small synthetic known-answer fixture for DataLoader repeat aggregation.

This fixture is not benchmark evidence. It contains five synthetic parsed
DataLoader summaries with throughput values `100,110,120,130,140`. Olympic
aggregation should drop `100` and `140`, retain `110,120,130`, and report an
Olympic average of `120.00` samples/s.

The synthetic summaries live under `input/parsed-summaries/` instead of
`results/` so they are clearly curated test inputs, not runtime artifacts. The
expected values and input glob live in `metadata.json`. Public documentation
tests use this fixture to validate the aggregation behavior in
[render-dataloader-report.py](../../../../man/render-dataloader-report.md)
without committing raw `results/` artifacts.

This fixture follows the repository fixture contract in
[`tests/fixtures/README.md`](../../README.md).
