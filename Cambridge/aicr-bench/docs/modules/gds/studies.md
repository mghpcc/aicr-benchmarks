# GDS Studies

Purpose: list curated GDS studies and their external artifact bundles.

## Quick Read

Start with the single-node `small` page for command shape, then read the
single-node `medium` or `large` page for a fuller profile. Use the B200 fleet
studies when the question is node-to-node consistency rather than one-node
throughput. Each linked study page owns its artifact bundle, provenance,
checksum, and retrieve/verify commands; this index is the map.

Artifact traceability: the index keeps bundle filenames short so the tables
remain readable. Each linked study page includes the full VAST path, OSN HTTPS
URL, provenance JSON, checksum, and retrieve/verify commands.

## B200 Studies

| Study | Cluster | Profile | Artifact bundle | Purpose |
| --- | --- | --- | --- | --- |
| [Single-node small](studies/b200-single-node-small.md) | B200 | `small` | `gds-b200-single-node-small-2026-05-10.tar.gz` | Baseline teaching run. |
| [Single-node medium](studies/b200-single-node-medium.md) | B200 | `medium` | `gds-b200-single-node-medium-2026-05-10.tar.gz` | Extended validation run. |
| [Single-node large](studies/b200-single-node-large.md) | B200 | `large` | `gds-b200-single-node-large-2026-05-10.tar.gz` | Full throughput characterization. |
| [Focused serial fleet olympic](studies/b200-focused-serial-fleet-olympic.md) | B200 | `medium` | `gds-b200-focused-serial-fleet-olympic-2026-05-11.tar.gz` | Five-node benchmark-mode fleet result. |
| [Custom gdsio](studies/b200-custom-gdsio.md) | B200 | `custom` | `gds-b200-custom-gdsio-2026-05-10.tar.gz` | Custom primitive command teaching. |

## RTX Studies

| Study | Cluster | Profile | Artifact bundle | Purpose |
| --- | --- | --- | --- | --- |
| [Single-node small](studies/rtx-single-node-small.md) | RTX | `small` | `gds-rtx-single-node-small-2026-05-10.tar.gz` | RTX baseline teaching run. |
| [Single-node medium](studies/rtx-single-node-medium.md) | RTX | `medium` | `gds-rtx-single-node-medium-2026-05-10.tar.gz` | RTX extended validation run. |
| [Single-node large](studies/rtx-single-node-large.md) | RTX | `large` | `gds-rtx-single-node-large-2026-05-10.tar.gz` | RTX full throughput characterization. |
| [Focused serial fleet olympic](studies/rtx-focused-serial-fleet-olympic.md) | RTX | `medium` | `gds-rtx-focused-serial-fleet-olympic-2026-05-23.tar.gz` | Five-node staggered fleet result. |
