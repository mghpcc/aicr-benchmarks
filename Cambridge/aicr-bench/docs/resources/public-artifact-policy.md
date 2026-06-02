# Public Study Artifact Policy

Purpose: document how public study bundles are named, retrieved, and verified.

Published module studies cite compact GitHub pages and figures, but full
generated reports live outside Git as public artifact bundles.

## Bundle Location

Public bundles use the producing public commit in the path:

```text
/work/aicr/commissioning/benchmarks/public-study-artifacts/aicr-public/<short-sha>/<module>/<date>/
https://uma1.osn.mghpcc.org/csim-bmark/public-study-artifacts/aicr-public/<short-sha>/<module>/<date>/
```

The `<short-sha>` is the public commit that packaged or produced the evidence
bundle. Later documentation commits may clarify prose, add navigation, or fix
curated figures while preserving the original evidence bundle.

## Required Files

Every promoted study bundle should include:

- rendered Markdown report;
- summary CSV/JSON;
- repeat aggregate CSV/JSON when repeats exist;
- curated figures used by the public study;
- exact commands or submission logs;
- job IDs and node provenance;
- provenance JSON;
- SHA-256 checksum file.

## Retrieve And Verify

Published study pages should include a `Retrieve And Verify` block that:

- creates a local scratch directory;
- downloads the OSN tarball and checksum;
- runs `sha256sum -c`;
- lists the tarball contents with `tar -tzf`.

Do not commit full generated result trees, tarballs, or raw public artifact
bundles to Git. Commit only the curated figures and documentation needed to
read the study.
