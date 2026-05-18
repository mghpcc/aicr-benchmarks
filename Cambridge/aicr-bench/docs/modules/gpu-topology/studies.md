# GPU Topology Studies

Purpose: identify topology readiness evidence used before benchmark execution.

GPU topology is not a natural parameter-study tool. It does not sweep workload
settings or tune benchmark performance. It documents node topology and confirms
that each node has the expected GPU inventory, CPU/GPU affinity, and NIC
proximity evidence before benchmark and test runs.

## Readiness Dashboards

Use these pages as self-contained examples of topology readiness evidence:

| Date | Scope | Dashboard |
| --- | --- | --- |
| 2026-05-16 | B200 and RTX Pro 6000 topology readiness | [May 16 readiness dashboard](studies/readiness-dashboard-2026-05-16.md) |

## Interpretation

Topology evidence is most useful as a prerequisite check for other modules:

- GDS uses GPU, PCIe, NIC, and storage-path context when interpreting local IO.
- NCCL uses GPU/NIC proximity and fleet consistency to interpret communication behavior.
- DataLoader, DDP, HPL-MxP, and Elbencho use node readiness to avoid confusing infrastructure problems with benchmark results.

Topology collection is also the RTX diagnostic exception to visible-GPU
preflight filtering: unhealthy nodes still need inventory, topology, CPU, and
NIC evidence so the failure can be understood.
