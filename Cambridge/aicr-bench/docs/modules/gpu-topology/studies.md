# GPU Topology Studies

Purpose: list published GPU topology readiness evidence and explain how to use it.

GPU topology is readiness evidence, not a performance benchmark. It records GPU
inventory, CPU/GPU affinity, PCIe or NVLink topology, and NIC proximity so later
benchmark results can be interpreted against a known system layout.

## Quick Read

Read GPU topology before interpreting GDS, NCCL, DataLoader, DDP, HPL-MxP, or
Elbencho results. A topology readiness dashboard answers these questions:

- Did the selected nodes expose the expected GPU count and model?
- Did topology and CPU-affinity parsing succeed?
- Did the fleet share a consistent topology signature?
- Were any nodes skipped, unhealthy, or outside the readiness set?

Topology pages should not be read as throughput comparisons. Their value is the
inventory, affinity, NIC proximity, parsed summaries, and provenance that make
the other module studies easier to trust.

## Readiness Dashboards

Use the dashboard below as the published topology readiness record for the
Cambridge benchmark evidence set.

| Dashboard | Scope | Coverage | Artifact status |
| --- | --- | --- | --- |
| [Cambridge GPU topology readiness](studies/readiness-dashboard-2026-05-16.md) | B200 and RTX Pro 6000 | B200: 30 collected nodes; RTX Pro 6000: 16 collected nodes and 2 skipped nodes | Published VAST/OSN bundle with provenance and checksum |

Current public coverage is one readiness dashboard. It is sufficient for the
published benchmark evidence that references this collection window, but it is
not a longitudinal topology history. A future readiness dashboard from another
collection window should be published as a separate page rather than folded into
this result.

## How To Use This Evidence

Use topology evidence as prerequisite context for the performance modules:

- GDS uses GPU, PCIe, NIC, and storage-path context when interpreting local IO behavior.
- NCCL uses GPU/NIC proximity and fleet consistency when interpreting communication behavior.
- DataLoader and DDP use node readiness context to avoid confusing input or training behavior with infrastructure problems.
- HPL-MxP and Elbencho use the same readiness context when comparing compute or storage runs across nodes.

When a topology page reports skipped nodes, treat those skips as a coverage
boundary for the benchmark evidence. Do not generalize benchmark conclusions to
nodes that were not part of the readiness set.

## Artifact Expectations

Each published topology dashboard should include:

- the node list and skipped-node list;
- expected and observed GPU inventory;
- parsed CPU/GPU/NIC topology summaries;
- majority topology signature and outlier notes;
- provenance, checksum, and retrieve/verify commands.

The linked readiness dashboard owns the artifact bundle and verification
commands. This index is only the public map to the available topology evidence.
