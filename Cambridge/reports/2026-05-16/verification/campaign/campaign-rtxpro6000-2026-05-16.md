# AICR System Verification Summary: rtxpro6000 2026-05-16

## Campaign Status

- Status: `passed`
- Campaign type: `verification`
- Check coverage: `4/4` expected checks present
- Candidate nodes: `16` strict passed nodes from `18` enumerated RTX nodes
- Generated at UTC: `2026-05-16T15:03:39Z`

## Related Reports

- Node triage: [dashboard](../nodes/nodes-rtxpro6000-2026-05-16.md)
- Node JSON: [manifest](../nodes/nodes-rtxpro6000-2026-05-16.json)

## Check Coverage Matrix

| Check | Status | Samples | Passes | Headline | Dashboard | Manifest |
| --- | --- | ---: | ---: | --- | --- | --- |
| GPU topology | passed | 1 | 1/1 | 16 idle RTX PRO 6000 nodes captured | [dashboard](../gpu-topology/gpu-topology-rtxpro6000.md) | [manifest](../gpu-topology/130007Z-gpu-topology-rtxpro6000.json) |
| GDS | passed | 5 | 5/5 | repeated GDS complete | [dashboard](../gds/gds-rtxpro6000.md) | [manifest](../gds/130055Z-gds-rtxpro6000.json) |
| NCCL suite | passed | 5 | 5/5 | NCCL rank-per-GPU scale suite complete (1n, 2n, 4n) | [dashboard](../nccl-suite/nccl-suite-rtxpro6000.md) | [manifest](../nccl-suite/141024Z-nccl-suite-rtxpro6000.json) |
| Archive manifest | passed | 1 | 1/1 | checksum manifest present | - | [manifest](../../../../archives/2026-05-16/aicr-results-2026-05-16-rtxpro6000-verify.json) |

## Major Findings

- GDS retained 4 low-tail anomaly finding(s); these are report-only tails and do not change pass/fail.
- RTX enumeration captured 18 nodes; a0017 and a0018 were skipped by state, leaving 16 strict benchmark candidates.

## Operational Gaps

- No campaign-level operational gaps were derived from committed summaries.

## Archive Evidence

- Status: `present`
- Checksum manifest: [manifest](../../../../archives/2026-05-16/aicr-results-2026-05-16-rtxpro6000-verify.json)
- Compression: `zstd`
- Byte size: `84640108`
- SHA256: `de7b6ad9fb31e107993f6a7e73274d6527a39b2733c6090366ab18923d4a7a6f`

## Debug Artifacts

- Node-debug summary: none
- Node-debug compare pages: none
- Node-debug archive manifest: none

## Recommended Next Actions

- Use the archive checksum manifest to retrieve full raw/parsed evidence from VAST if needed.

## Notes On Semantics

- Child dashboards remain authoritative for per-check detail.
- This system verification page summarizes committed evidence, coverage, status rollup, and navigation.
- Raw and parsed evidence is archived outside Git.
- Archive manifests are provenance anchors for the collected evidence; this public report is the audit boundary for publishable verification status.
- Report-only anomaly filtering remains child-dashboard behavior.
- Rows below the existing 1.0% anomaly display cutoff may be suppressed in child anomaly tables.
- Report-only anomaly rows do not redefine campaign pass/fail.
- A tiny `index.md` can be added later if repository browsing still needs directory landing behavior.
