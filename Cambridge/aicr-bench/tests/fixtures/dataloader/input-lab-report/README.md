# DataLoader Input-Lab Report Fixture

Purpose: provide a tiny synthetic result tree for the DataLoader input-lab renderer.

This fixture is not benchmark evidence. It contains five synthetic parsed
DataLoader summaries that cover the original PyTorch CPU path, a same-size
pre-resized JPEG PyTorch row, a DALI row, a NumPy uint8 shard row, and a NumPy
fp16 shard row. The fixture lets local checks prove input-lab Markdown, CSV,
JSON, and PNG output shape without live Slurm results.

The synthetic summaries live under `input/by-date/` so the renderer can read
them through the normal report-loading path while remaining clearly separate
from runtime `results/` artifacts.
