# valprep.sh

Purpose: prepare the ImageNet validation split for PyTorch `ImageFolder`.

## Synopsis

```bash
cd "${AICR_IMAGENET_DIR}/val"
bash /path/to/aicr-bench/scripts/benchmark/valprep.sh
```

## Description

`scripts/benchmark/valprep.sh` is a vendored ImageNet validation split helper.
It creates the 1000 ImageNet class directories under `val/` and moves
`ILSVRC2012_val_*.JPEG` files into those class directories.

Use this helper after ImageNet has been acquired and unpacked by an operator.
The repository does not automate ImageNet download and does not store
credentials, tokens, or dataset files.

## Inputs

- Current working directory: the ImageNet validation image directory.
- Files: `ILSVRC2012_val_00000001.JPEG` through
  `ILSVRC2012_val_00050000.JPEG`.

## Outputs

- 1000 class directories named with ImageNet synset IDs.
- Validation JPEGs moved into the PyTorch `ImageFolder` layout.

## License

The helper is vendored from
<https://github.com/soumith/imagenetloader.torch/blob/master/valprep.sh>.
See `scripts/benchmark/valprep.LICENSE` for provenance and BSD-3-Clause
license text.
