# GPU Topology

Purpose: navigate the GPU topology verification module.

GPU topology records GPU inventory, PCIe/NVLink topology, CPU affinity, and NIC proximity evidence used by system verification and benchmark-readiness checks.

## Verify-stack role

This module is part of the AICR verify stack. Use it to validate hardware,
storage, or communication readiness before interpreting workload benchmark
modules. Treat collected rates, topology signatures, and pass/fail rows as
validation evidence, not benchmark-result evidence.

GPU Topology is diagnostic readiness evidence. It explains the hardware and
fabric context that GDS and NCCL use for validation, and it is not a
benchmark-result module.

For graphical single-node examples, see [Topology Map](topology-map.md).

- [Script interface](scripts.md)
- [Make interface](make.md)
- [Examples](examples.md)
- [Studies](studies.md)
- [Test plan](test-plan.md)
