# DDP Report Shape Fixture

Purpose: provide a small synthetic DDP result set for local renderer-shape
checks.

The fixture is not benchmark evidence. It gives the renderer five PyTorch CPU
rows and five DALI rows so local tests can verify Markdown sections, repeat
aggregation, generated CSV/JSON files, and public wording without requiring
Slurm or generated AICR HPC artifacts.
