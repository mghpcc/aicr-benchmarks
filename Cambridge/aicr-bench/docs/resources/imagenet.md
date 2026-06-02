# ImageNet Dataset Preparation

Purpose: document the ImageNet layout required by the public DataLoader and DDP modules.

DataLoader and DDP use a real ImageNet `torchvision.datasets.ImageFolder`
tree. The repository does not automate ImageNet acquisition and does not store
ImageNet data, Kaggle credentials, or API tokens.

## Dataset Root Contract

`AICR_IMAGENET_DIR` must point at the directory that directly contains:

- `train/`
- `val/`

Canonical AICR HPC shared dataset tree:

```text
/work/aicr/commissioning/benchmarks/imagenet
```

For the benchmark modules, set:

```bash
AICR_IMAGENET_DIR=/work/aicr/commissioning/benchmarks/imagenet/ILSVRC/Data/CLS-LOC
```

The DataLoader and DDP public studies currently run against:

```text
${AICR_IMAGENET_DIR}/train
```

## Acquisition

ImageNet acquisition is a user-managed external step. One confirmed
workflow is:

```bash
uv venv --python 3.11 ~/.venvs/kaggle
source ~/.venvs/kaggle/bin/activate
uv pip install kaggle
```

Authenticate with Kaggle using your own user-managed credentials. Do not
commit API keys or tokens into the repository, shell history snapshots, or
repo-tracked config files.

Download and unpack:

```bash
kaggle competitions download -c imagenet-object-localization-challenge -p ~/imagenet/
cd ~/imagenet
unzip -q imagenet-object-localization-challenge.zip
```

## Validation Split Preparation

The public repo includes the vendored validation split helper
[valprep.sh](../../man/valprep.md). It creates the 1000 ImageNet class
directories under `val/` and moves validation JPEGs into the `ImageFolder`
layout expected by PyTorch.

Run it from the validation directory:

```bash
REPO_ROOT=/path/to/aicr-bench
cd "${REPO_ROOT}"
source benchmark-settings.env
cd "${AICR_IMAGENET_DIR}/val/"
bash "${REPO_ROOT}/scripts/benchmark/valprep.sh"
```

The helper is vendored from the upstream ImageNet loader helper. See
`scripts/benchmark/valprep.LICENSE` for provenance and BSD-3-Clause license
text.

## Layout Checks

Sanity-check the prepared layout:

```bash
source benchmark-settings.env
find "${AICR_IMAGENET_DIR}/train" -mindepth 1 -maxdepth 1 -type d | wc -l
find "${AICR_IMAGENET_DIR}/val" -mindepth 1 -maxdepth 1 -type d | wc -l
find "${AICR_IMAGENET_DIR}/train" -name "*.JPEG" | wc -l
find "${AICR_IMAGENET_DIR}/val" -name "*.JPEG" | wc -l
```

Validated AICR HPC layout-count output on May 2, 2026, in the command order
shown above:

```text
1000
1000
1281167
50000
```

## PyTorch ImageFolder Check

Use the same Apptainer options as the Slurm benchmark jobs:

```bash
source benchmark-settings.env
export AICR_IMAGENET_DIR
apptainer exec ${AICR_APPTAINER_COMMON_OPTS} --nv "${AICR_APPTAINER_IMAGE_DIR}/pytorch-25.10-py3.sif" python3 -c "
import os
import torchvision.datasets as datasets
dataset_root = os.environ['AICR_IMAGENET_DIR']
train = datasets.ImageFolder(os.path.join(dataset_root, 'train'))
val = datasets.ImageFolder(os.path.join(dataset_root, 'val'))
print(f'Dataset root: {dataset_root}')
print(f'Train classes: {len(train.classes)}')
print(f'Train images:  {len(train)}')
print(f'Val classes:   {len(val.classes)}')
print(f'Val images:    {len(val)}')
"
```

Validated AICR HPC output on May 2, 2026:

```text
Dataset root: /work/aicr/commissioning/benchmarks/imagenet/ILSVRC/Data/CLS-LOC
Train classes: 1000
Train images:  1281167
Val classes:   1000
Val images:    50000
```

On AICR HPC, `AICR_APPTAINER_COMMON_OPTS` should expand to
`--no-mount /etc/localtime --bind /work:/work --bind /scratch:/scratch`.
That keeps ad hoc checks aligned with Slurm-driven benchmark jobs, makes the
shared `/work` ImageNet tree visible inside the container, and exposes
scratch-hosted derived datasets when you choose `/scratch/$USER` for
regenerated data.

## Derived Experiment Inputs

Some DataLoader and DDP studies create ImageNet-derived JPEG and NumPy inputs
from this canonical ImageFolder tree. Those derived datasets are controlled
experiment inputs for decode-pressure, backend-crossover, and prepared-input
ceiling studies. They are not replacements for canonical ImageNet evidence.

See [Derived ImageNet Datasets](../modules/dataloader/derived-datasets.md) for
the supported formats, dry-run planner, CPU-queue submitter, Make wrapper, and
storage policy.
