#!/usr/bin/env python3
"""Shared DataLoader input helpers for ImageNet-derived lab datasets."""

import json
import os
from collections import OrderedDict
from pathlib import Path


NUMPY_INPUT_BACKENDS = {"numpy-uint8-shards", "numpy-fp16-shards"}
NUMPY_BLOCK_INPUT_BACKENDS = {"numpy-fp16-blocks-pytorch"}
DALI_NUMPY_FILE_BACKENDS = {"dali-numpy-fp16-cpu", "dali-numpy-fp16-gds"}
DALI_NUMPY_BLOCK_BACKENDS = {"dali-numpy-fp16-blocks-cpu", "dali-numpy-fp16-blocks-gds"}
IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)


def is_numpy_backend(input_backend):
    return input_backend in NUMPY_INPUT_BACKENDS or input_backend in NUMPY_BLOCK_INPUT_BACKENDS


def is_numpy_shard_backend(input_backend):
    return input_backend in NUMPY_INPUT_BACKENDS


def is_numpy_block_backend(input_backend):
    return input_backend in NUMPY_BLOCK_INPUT_BACKENDS


def is_dali_numpy_file_backend(input_backend):
    return input_backend in DALI_NUMPY_FILE_BACKENDS


def is_dali_numpy_block_backend(input_backend):
    return input_backend in DALI_NUMPY_BLOCK_BACKENDS


def is_dali_numpy_backend(input_backend):
    return is_dali_numpy_file_backend(input_backend) or is_dali_numpy_block_backend(input_backend)


def requires_derived_root(input_backend):
    return is_numpy_backend(input_backend) or is_dali_numpy_backend(input_backend)


def numpy_format_for_backend(input_backend):
    if input_backend == "numpy-uint8-shards":
        return "numpy-uint8"
    if input_backend == "numpy-fp16-shards":
        return "numpy-fp16"
    raise ValueError(f"not a NumPy shard backend: {input_backend}")


def numpy_block_format_for_backend(input_backend):
    if input_backend in NUMPY_BLOCK_INPUT_BACKENDS:
        return "numpy-fp16-blocks"
    raise ValueError(f"not a NumPy block backend: {input_backend}")


def dali_numpy_format_for_backend(input_backend):
    if input_backend in DALI_NUMPY_FILE_BACKENDS:
        return "numpy-fp16-files"
    if input_backend in DALI_NUMPY_BLOCK_BACKENDS:
        return "numpy-fp16-blocks"
    raise ValueError(f"not a DALI NumPy file backend: {input_backend}")


def numpy_block_dataset_format_for_backend(input_backend):
    if input_backend in DALI_NUMPY_BLOCK_BACKENDS:
        return dali_numpy_format_for_backend(input_backend)
    if input_backend in NUMPY_BLOCK_INPUT_BACKENDS:
        return numpy_block_format_for_backend(input_backend)
    raise ValueError(f"not a NumPy block dataset backend: {input_backend}")


def resolve_derived_root(args):
    value = getattr(args, "derived_root", None) or os.environ.get("AICR_DATALOADER_DERIVED_ROOT")
    if not value:
        raise ValueError(
            "derived input backends require --derived-root or AICR_DATALOADER_DERIVED_ROOT"
        )
    return Path(value)


def derived_subset_name(samples_per_class, seed):
    return f"spc-{samples_per_class}-seed-{seed}"


def load_derived_metadata(root):
    metadata_path = Path(root) / "metadata.json"
    if not metadata_path.is_file():
        return {}
    return json.loads(metadata_path.read_text(encoding="utf-8"))


def derived_metadata_fields(root):
    metadata = load_derived_metadata(root)
    if not metadata:
        return {}
    return {
        "derived_root": str(Path(root)),
        "derived_image_size": metadata.get("image_size"),
        "derived_samples_per_class": metadata.get("samples_per_class"),
        "derived_seed": metadata.get("seed"),
        "derived_format": metadata.get("format"),
        "derived_storage_dtype": metadata.get("storage_dtype"),
        "derived_storage_layout": metadata.get("storage_layout"),
        "derived_source_policy": metadata.get("source_policy"),
        "derived_jpeg_quality": metadata.get("jpeg_quality"),
        "transform_policy": metadata.get("transform_policy", ""),
    }


def resolve_numpy_shard_root(args):
    return (
        resolve_derived_root(args)
        / "imagenet"
        / getattr(args, "split")
        / derived_subset_name(getattr(args, "derived_samples_per_class"), getattr(args, "derived_seed"))
        / f"size-{getattr(args, 'derived_image_size')}"
        / numpy_format_for_backend(getattr(args, "input_backend"))
    )


def resolve_dali_numpy_file_root(args):
    return (
        resolve_derived_root(args)
        / "imagenet"
        / getattr(args, "split")
        / derived_subset_name(getattr(args, "derived_samples_per_class"), getattr(args, "derived_seed"))
        / f"size-{getattr(args, 'derived_image_size')}"
        / dali_numpy_format_for_backend(getattr(args, "input_backend"))
    )


def resolve_dali_numpy_block_root(args):
    return (
        resolve_derived_root(args)
        / "imagenet"
        / getattr(args, "split")
        / derived_subset_name(getattr(args, "derived_samples_per_class"), getattr(args, "derived_seed"))
        / f"size-{getattr(args, 'derived_image_size')}"
        / dali_numpy_format_for_backend(getattr(args, "input_backend"))
    )


def resolve_numpy_block_root(args):
    return (
        resolve_derived_root(args)
        / "imagenet"
        / getattr(args, "split")
        / derived_subset_name(getattr(args, "derived_samples_per_class"), getattr(args, "derived_seed"))
        / f"size-{getattr(args, 'derived_image_size')}"
        / numpy_block_format_for_backend(getattr(args, "input_backend"))
    )


def estimate_numpy_dataset_bytes(dataset):
    image_bytes = Path(dataset.image_path).stat().st_size if Path(dataset.image_path).exists() else None
    label_bytes = Path(dataset.label_path).stat().st_size if Path(dataset.label_path).exists() else None
    total_bytes = None
    if image_bytes is not None and label_bytes is not None:
        total_bytes = image_bytes + label_bytes
    average_bytes = total_bytes / len(dataset) if total_bytes is not None and len(dataset) else None
    return {
        "sample_count": len(dataset) if total_bytes is not None else 0,
        "sampled_bytes": total_bytes,
        "average_sample_bytes": average_bytes,
        "estimated_total_bytes": total_bytes,
        "missing_sample_count": 0,
    }


def estimate_numpy_file_dataset_bytes(dataset):
    sample_bytes = sum(path.stat().st_size for path in dataset.sample_paths)
    label_bytes = dataset.label_path.stat().st_size if dataset.label_path.exists() else None
    total_bytes = sample_bytes + label_bytes if label_bytes is not None else sample_bytes
    average_bytes = sample_bytes / len(dataset) if len(dataset) else None
    return {
        "sample_count": len(dataset),
        "sampled_bytes": sample_bytes,
        "average_sample_bytes": average_bytes,
        "estimated_total_bytes": sample_bytes,
        "missing_sample_count": 0,
        "dataset_file_count": len(dataset.sample_paths),
        "dataset_total_bytes": total_bytes,
    }


def estimate_numpy_block_dataset_bytes(dataset):
    block_bytes = sum(path.stat().st_size for path in dataset.block_paths)
    label_bytes = dataset.label_path.stat().st_size if dataset.label_path.exists() else None
    total_bytes = block_bytes + label_bytes if label_bytes is not None else block_bytes
    average_bytes = block_bytes / len(dataset) if len(dataset) else None
    return {
        "sample_count": len(dataset),
        "sampled_bytes": block_bytes,
        "average_sample_bytes": average_bytes,
        "estimated_total_bytes": block_bytes,
        "missing_sample_count": 0,
        "dataset_file_count": len(dataset.block_paths),
        "dataset_block_count": len(dataset.block_paths),
        "dataset_total_bytes": total_bytes,
        "logical_sample_count": len(dataset),
    }


class NumpyShardDataset:
    """Lazy memmap dataset for AICR-Bench derived ImageNet NumPy shards."""

    def __init__(self, root, input_backend):
        self.root = Path(root)
        self.input_backend = input_backend
        self.format = numpy_format_for_backend(input_backend)
        self.metadata_path = self.root / "metadata.json"
        self.image_path = self.root / "images.npy"
        self.label_path = self.root / "labels.npy"
        if not self.metadata_path.is_file():
            raise FileNotFoundError(f"missing derived metadata: {self.metadata_path}")
        if not self.image_path.is_file():
            raise FileNotFoundError(f"missing derived image shard: {self.image_path}")
        if not self.label_path.is_file():
            raise FileNotFoundError(f"missing derived label shard: {self.label_path}")
        self.metadata = json.loads(self.metadata_path.read_text(encoding="utf-8"))
        self.classes = list(self.metadata.get("classes") or [])
        self.class_to_idx = dict(self.metadata.get("class_to_idx") or {})
        self.image_size = self.metadata.get("image_size")
        self.transform_policy = self.metadata.get("transform_policy", "")
        self.storage_dtype = self.metadata.get("storage_dtype", "")
        self.storage_layout = self.metadata.get("storage_layout", "")
        self._images = None
        self._labels = None
        self._length = int(self.metadata.get("sample_count") or 0)

    def __getstate__(self):
        state = self.__dict__.copy()
        state["_images"] = None
        state["_labels"] = None
        return state

    def _ensure_open(self):
        import numpy as np

        if self._images is None:
            self._images = np.load(self.image_path, mmap_mode="r")
        if self._labels is None:
            self._labels = np.load(self.label_path, mmap_mode="r")
        if not self._length:
            self._length = int(self._labels.shape[0])

    def __len__(self):
        return self._length

    def __getitem__(self, index):
        import numpy as np
        import torch

        self._ensure_open()
        label = int(self._labels[index])
        if self.input_backend == "numpy-uint8-shards":
            array = np.array(self._images[index], copy=True)
            tensor = torch.from_numpy(array).permute(2, 0, 1).float().div_(255.0)
            mean = torch.tensor(IMAGENET_MEAN, dtype=tensor.dtype).view(3, 1, 1)
            std = torch.tensor(IMAGENET_STD, dtype=tensor.dtype).view(3, 1, 1)
            tensor = (tensor - mean) / std
        else:
            array = np.array(self._images[index], copy=True)
            tensor = torch.from_numpy(array)
        return tensor, label


class NumpyFileDatasetMetadata:
    """Metadata wrapper for per-sample NumPy files read by DALI."""

    def __init__(self, root, input_backend):
        self.root = Path(root)
        self.input_backend = input_backend
        self.format = dali_numpy_format_for_backend(input_backend)
        self.metadata_path = self.root / "metadata.json"
        self.sample_root = self.root / "samples"
        self.label_path = self.root / "labels.npy"
        if not self.metadata_path.is_file():
            raise FileNotFoundError(f"missing derived metadata: {self.metadata_path}")
        if not self.sample_root.is_dir():
            raise FileNotFoundError(f"missing derived sample directory: {self.sample_root}")
        if not self.label_path.is_file():
            raise FileNotFoundError(f"missing derived label shard: {self.label_path}")
        self.metadata = json.loads(self.metadata_path.read_text(encoding="utf-8"))
        self.classes = list(self.metadata.get("classes") or [])
        self.class_to_idx = dict(self.metadata.get("class_to_idx") or {})
        self.image_size = self.metadata.get("image_size")
        self.transform_policy = self.metadata.get("transform_policy", "")
        self.storage_dtype = self.metadata.get("storage_dtype", "")
        self.storage_layout = self.metadata.get("storage_layout", "")
        self._length = int(self.metadata.get("sample_count") or 0)
        self.sample_paths = sorted(self.sample_root.glob("*.npy"))
        if len(self.sample_paths) != self._length:
            raise FileNotFoundError(
                f"expected {self._length} per-sample .npy files under {self.sample_root}, "
                f"found {len(self.sample_paths)}"
            )

    def __len__(self):
        return self._length


class NumpyBlockDatasetMetadata:
    """Metadata wrapper for blocked NumPy files."""

    def __init__(self, root, input_backend):
        self.root = Path(root)
        self.input_backend = input_backend
        self.format = numpy_block_dataset_format_for_backend(input_backend)
        self.metadata_path = self.root / "metadata.json"
        self.block_root = self.root / "blocks"
        self.block_index_path = self.root / "block-index.jsonl"
        self.label_path = self.root / "labels.npy"
        if not self.metadata_path.is_file():
            raise FileNotFoundError(f"missing derived metadata: {self.metadata_path}")
        if not self.block_root.is_dir():
            raise FileNotFoundError(f"missing derived block directory: {self.block_root}")
        if not self.block_index_path.is_file():
            raise FileNotFoundError(f"missing derived block index: {self.block_index_path}")
        if not self.label_path.is_file():
            raise FileNotFoundError(f"missing derived label shard: {self.label_path}")
        self.metadata = json.loads(self.metadata_path.read_text(encoding="utf-8"))
        self.classes = list(self.metadata.get("classes") or [])
        self.class_to_idx = dict(self.metadata.get("class_to_idx") or {})
        self.image_size = self.metadata.get("image_size")
        self.transform_policy = self.metadata.get("transform_policy", "")
        self.storage_dtype = self.metadata.get("storage_dtype", "")
        self.storage_layout = self.metadata.get("storage_layout", "")
        self.block_size = int(self.metadata.get("block_size") or 0)
        self.block_count = int(self.metadata.get("block_count") or 0)
        self._length = int(self.metadata.get("sample_count") or 0)
        self.block_paths = sorted(self.block_root.glob("*.npy"))
        if len(self.block_paths) != self.block_count:
            raise FileNotFoundError(
                f"expected {self.block_count} block .npy files under {self.block_root}, "
                f"found {len(self.block_paths)}"
            )
        if self.block_size <= 0:
            raise ValueError(f"invalid block_size in metadata: {self.block_size}")

    def __len__(self):
        return self._length


class NumpyBlockDataset(NumpyBlockDatasetMetadata):
    """Lazy per-sample PyTorch dataset over blocked fp16 NumPy files."""

    def __init__(self, root, input_backend, block_cache_size=1):
        super().__init__(root, input_backend)
        self.block_cache_size = max(1, int(block_cache_size))
        self._labels = None
        self._block_cache = None
        self._block_rows = self._load_block_rows()

    def __getstate__(self):
        state = self.__dict__.copy()
        state["_labels"] = None
        state["_block_cache"] = None
        return state

    def _load_block_rows(self):
        rows = []
        with self.block_index_path.open("r", encoding="utf-8") as handle:
            for line in handle:
                if not line.strip():
                    continue
                row = json.loads(line)
                block_index = int(row["block_index"])
                start = int(row["start_sample_index"])
                sample_count = int(row["sample_count"])
                path = self.root / str(row["path"])
                if not path.is_file():
                    raise FileNotFoundError(f"missing derived block file: {path}")
                rows.append({
                    "block_index": block_index,
                    "start_sample_index": start,
                    "sample_count": sample_count,
                    "path": path,
                })
        rows.sort(key=lambda row: row["block_index"])
        if len(rows) != self.block_count:
            raise FileNotFoundError(
                f"expected {self.block_count} block index rows in {self.block_index_path}, "
                f"found {len(rows)}"
            )
        return rows

    def _ensure_open(self):
        import numpy as np

        if self._labels is None:
            self._labels = np.load(self.label_path, mmap_mode="r")
        if self._block_cache is None:
            self._block_cache = OrderedDict()

    def _row_for_index(self, index):
        block_index = int(index) // self.block_size
        if 0 <= block_index < len(self._block_rows):
            row = self._block_rows[block_index]
            start = row["start_sample_index"]
            stop = start + row["sample_count"]
            if start <= index < stop:
                return row
        for row in self._block_rows:
            start = row["start_sample_index"]
            stop = start + row["sample_count"]
            if start <= index < stop:
                return row
        raise IndexError(index)

    def _load_block(self, row):
        import numpy as np

        block_index = row["block_index"]
        cached = self._block_cache.get(block_index)
        if cached is not None:
            self._block_cache.move_to_end(block_index)
            return cached
        block = np.load(row["path"], mmap_mode="r")
        self._block_cache[block_index] = block
        while len(self._block_cache) > self.block_cache_size:
            self._block_cache.popitem(last=False)
        return block

    def __getitem__(self, index):
        import numpy as np
        import torch

        if index < 0 or index >= len(self):
            raise IndexError(index)
        self._ensure_open()
        row = self._row_for_index(index)
        block = self._load_block(row)
        block_offset = int(index) - row["start_sample_index"]
        array = np.array(block[block_offset], copy=True)
        return torch.from_numpy(array), int(self._labels[index])
