# DataLoader ImageFolder Dry-Run Fixture

Purpose: provide a tiny ImageFolder-shaped tree for documentation dry-runs that
inspect `prepare-dataloader-derived-dataset.py` without opening image pixels or
writing derived datasets.

The placeholder `.jpg` file is intentionally used only with
`--formats procedural-jpeg` and without `--apply`. It is not benchmark evidence
and must not be used for applied data preparation.
