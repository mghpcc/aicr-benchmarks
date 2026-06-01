# PyTorch DataLoader

Purpose: navigate the DataLoader module.

DataLoader measures ImageNet input-pipeline behavior across single-GPU,
replicated, and distributed-sharded modes.

## Benchmark Role

DataLoader is an input-pipeline benchmark module. Published DataLoader rows
link to study pages and public artifacts. DDP pages report fixed-iteration
training throughput, while verify-stack modules cover system checks.
Use DataLoader rows to compare input paths, and use DDP rows for training
throughput results.

The main public workflow is `make benchmark-dataloader`, which delegates to the
dry-run-first submitter and sweep scripts. Additional input-pipeline studies
cover PyTorch CPU DataLoader, DALI GPU decode, derived NumPy shard backends,
and DALI NumPy prepared-tensor GPU/cuFile transport rows.
The `synthetic-gpu` backend belongs to the DDP input-ceilings context rather
than the DataLoader benchmark surface.

For headline findings, start with [Results Summary](results-summary.md), then
use [Studies](studies.md) as the complete public evidence index.

- [Script interface](scripts.md)
- [Make interface](make.md)
- [Examples](examples.md)
- [Studies](studies.md)
- [Test plan](test-plan.md)

Examples start with the Slurm primitive file for custom automation, then show the curated Make implementation.

Supporting references are linked from the study pages where they matter:
[Input Pipeline Reference](input-pipeline-reference.md) defines metric and
input-path terminology, and [Derived ImageNet Datasets](derived-datasets.md)
documents controlled derived JPEG, NumPy shard, and DALI NumPy file inputs.
