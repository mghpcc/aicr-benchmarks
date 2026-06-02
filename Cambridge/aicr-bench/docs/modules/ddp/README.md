# DDP ResNet-50

Purpose: navigate the ResNet-50 Distributed Data Parallel benchmark module.

DDP measures fixed-iteration PyTorch ResNet-50 training throughput using the
configured ImageNet ImageFolder input path. It is the training side of the
DataLoader story: DataLoader studies identify input-pipeline candidates, and
DDP checks whether those candidates still help once model compute, backward
pass, optimizer work, rank timing, and distributed sharding enter the measured
loop.

## Benchmark-result role

DDP is a training-throughput benchmark-result module once rows have completed,
rendered, and been linked to public artifacts and provenance. It is not a
DataLoader-only input-pipeline module and not a verify-stack diagnostic module.
Use DataLoader rows for input-candidate selection, then use DDP rows to compare
fixed-iteration training throughput, rank timing, and distributed behavior.

For headline findings, start with [Results Summary](results-summary.md), then
use [Studies](studies.md) as the complete public training-throughput evidence
index. The standard benchmark path uses `torchrun` with PyTorch CPU DataLoader
input. DALI, NumPy shard, synthetic GPU, and synthetic large-JPEG rows are
study-specific paths and should be read through the labeled study pages.

- [Script interface](scripts.md)
- [Make interface](make.md)
- [Examples](examples.md)
- [Studies](studies.md)
- [Test plan](test-plan.md)

The module also keeps explicit `srun` launcher controls for comparison studies
and input-backend controls for separately labeled input-pipeline work.
