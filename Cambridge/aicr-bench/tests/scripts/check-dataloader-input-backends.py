#!/usr/bin/env python3
"""Validate the shared DataLoader input-backend helper contract."""

from __future__ import annotations

import importlib.util
import os
import tempfile
from pathlib import Path
from types import SimpleNamespace


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def load_backends(root: Path):
    module_path = root / "scripts" / "benchmark" / "dataloader_input_backends.py"
    spec = importlib.util.spec_from_file_location("dataloader_input_backends", module_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"could not load {module_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def assert_raises(expected_exception, func, *args, **kwargs) -> None:
    try:
        func(*args, **kwargs)
    except expected_exception:
        return
    raise SystemExit(f"{func.__name__}: expected {expected_exception.__name__}")


def main() -> int:
    module = load_backends(repo_root())
    expected_backends = {"numpy-uint8-shards", "numpy-fp16-shards"}
    if module.NUMPY_INPUT_BACKENDS != expected_backends:
        raise SystemExit(f"NUMPY_INPUT_BACKENDS={module.NUMPY_INPUT_BACKENDS!r}")
    expected_block_backends = {"numpy-fp16-blocks-pytorch"}
    if module.NUMPY_BLOCK_INPUT_BACKENDS != expected_block_backends:
        raise SystemExit(f"NUMPY_BLOCK_INPUT_BACKENDS={module.NUMPY_BLOCK_INPUT_BACKENDS!r}")
    expected_dali_numpy_backends = {"dali-numpy-fp16-cpu", "dali-numpy-fp16-gds"}
    if module.DALI_NUMPY_FILE_BACKENDS != expected_dali_numpy_backends:
        raise SystemExit(f"DALI_NUMPY_FILE_BACKENDS={module.DALI_NUMPY_FILE_BACKENDS!r}")
    expected_dali_numpy_block_backends = {"dali-numpy-fp16-blocks-cpu", "dali-numpy-fp16-blocks-gds"}
    if module.DALI_NUMPY_BLOCK_BACKENDS != expected_dali_numpy_block_backends:
        raise SystemExit(f"DALI_NUMPY_BLOCK_BACKENDS={module.DALI_NUMPY_BLOCK_BACKENDS!r}")

    if not module.is_numpy_backend("numpy-uint8-shards"):
        raise SystemExit("numpy-uint8-shards should be a NumPy backend")
    if not module.is_numpy_backend("numpy-fp16-shards"):
        raise SystemExit("numpy-fp16-shards should be a NumPy backend")
    if module.is_numpy_backend("pytorch-cpu-dataloader"):
        raise SystemExit("pytorch-cpu-dataloader should not be a NumPy backend")
    if module.is_numpy_backend("dali-gpu-decode"):
        raise SystemExit("dali-gpu-decode should not be a NumPy backend")
    if not module.is_numpy_block_backend("numpy-fp16-blocks-pytorch"):
        raise SystemExit("numpy-fp16-blocks-pytorch should be a NumPy block backend")
    if not module.is_numpy_backend("numpy-fp16-blocks-pytorch"):
        raise SystemExit("numpy-fp16-blocks-pytorch should be a NumPy backend")
    if not module.is_dali_numpy_file_backend("dali-numpy-fp16-cpu"):
        raise SystemExit("dali-numpy-fp16-cpu should be a DALI NumPy file backend")
    if not module.is_dali_numpy_file_backend("dali-numpy-fp16-gds"):
        raise SystemExit("dali-numpy-fp16-gds should be a DALI NumPy file backend")
    if module.is_dali_numpy_file_backend("dali-gpu-decode"):
        raise SystemExit("dali-gpu-decode should not be a DALI NumPy file backend")
    if not module.is_dali_numpy_block_backend("dali-numpy-fp16-blocks-cpu"):
        raise SystemExit("dali-numpy-fp16-blocks-cpu should be a DALI NumPy block backend")
    if not module.is_dali_numpy_block_backend("dali-numpy-fp16-blocks-gds"):
        raise SystemExit("dali-numpy-fp16-blocks-gds should be a DALI NumPy block backend")
    if not module.is_dali_numpy_backend("dali-numpy-fp16-blocks-gds"):
        raise SystemExit("dali-numpy-fp16-blocks-gds should be a DALI NumPy backend")

    if module.numpy_format_for_backend("numpy-uint8-shards") != "numpy-uint8":
        raise SystemExit("unexpected uint8 format mapping")
    if module.numpy_format_for_backend("numpy-fp16-shards") != "numpy-fp16":
        raise SystemExit("unexpected fp16 format mapping")
    assert_raises(ValueError, module.numpy_format_for_backend, "dali-gpu-decode")
    if module.numpy_block_format_for_backend("numpy-fp16-blocks-pytorch") != "numpy-fp16-blocks":
        raise SystemExit("unexpected PyTorch NumPy block format mapping")
    assert_raises(ValueError, module.numpy_block_format_for_backend, "dali-numpy-fp16-blocks-gds")
    if module.dali_numpy_format_for_backend("dali-numpy-fp16-cpu") != "numpy-fp16-files":
        raise SystemExit("unexpected DALI NumPy CPU format mapping")
    if module.dali_numpy_format_for_backend("dali-numpy-fp16-gds") != "numpy-fp16-files":
        raise SystemExit("unexpected DALI NumPy GDS format mapping")
    if module.dali_numpy_format_for_backend("dali-numpy-fp16-blocks-gds") != "numpy-fp16-blocks":
        raise SystemExit("unexpected DALI NumPy block GDS format mapping")
    assert_raises(ValueError, module.dali_numpy_format_for_backend, "dali-gpu-decode")

    if module.derived_subset_name(16, 20260518) != "spc-16-seed-20260518":
        raise SystemExit("unexpected derived subset name")
    old_derived_root = os.environ.pop("AICR_DATALOADER_DERIVED_ROOT", None)
    try:
        assert_raises(ValueError, module.resolve_derived_root, SimpleNamespace(derived_root=None))
    finally:
        if old_derived_root is not None:
            os.environ["AICR_DATALOADER_DERIVED_ROOT"] = old_derived_root

    with tempfile.TemporaryDirectory(prefix="aicr-dataloader-backends-") as tmp:
        args = SimpleNamespace(
            derived_root=tmp,
            split="train",
            derived_samples_per_class=16,
            derived_seed=20260518,
            derived_image_size=224,
            input_backend="numpy-fp16-shards",
        )
        shard_root = module.resolve_numpy_shard_root(args)
        expected_suffix = Path("imagenet/train/spc-16-seed-20260518/size-224/numpy-fp16")
        if shard_root != Path(tmp) / expected_suffix:
            raise SystemExit(f"unexpected shard root: {shard_root}")
        assert_raises(FileNotFoundError, module.NumpyShardDataset, shard_root, "numpy-fp16-shards")

        args.input_backend = "numpy-fp16-blocks-pytorch"
        pytorch_block_root = module.resolve_numpy_block_root(args)
        expected_pytorch_block_suffix = Path("imagenet/train/spc-16-seed-20260518/size-224/numpy-fp16-blocks")
        if pytorch_block_root != Path(tmp) / expected_pytorch_block_suffix:
            raise SystemExit(f"unexpected PyTorch NumPy block root: {pytorch_block_root}")
        assert_raises(FileNotFoundError, module.NumpyBlockDataset, pytorch_block_root, "numpy-fp16-blocks-pytorch")

        args.input_backend = "dali-numpy-fp16-gds"
        file_root = module.resolve_dali_numpy_file_root(args)
        expected_file_suffix = Path("imagenet/train/spc-16-seed-20260518/size-224/numpy-fp16-files")
        if file_root != Path(tmp) / expected_file_suffix:
            raise SystemExit(f"unexpected DALI NumPy file root: {file_root}")
        assert_raises(FileNotFoundError, module.NumpyFileDatasetMetadata, file_root, "dali-numpy-fp16-gds")

        samples = file_root / "samples"
        samples.mkdir(parents=True)
        (file_root / "metadata.json").write_text(
            '{"sample_count": 2, "image_size": 224, "storage_dtype": "float16", "storage_layout": "per-sample-npy-nchw"}',
            encoding="utf-8",
        )
        (file_root / "labels.npy").write_bytes(b"labels")
        (samples / "00000000.npy").write_bytes(b"sample0")
        (samples / "00000001.npy").write_bytes(b"sample1")
        dataset = module.NumpyFileDatasetMetadata(file_root, "dali-numpy-fp16-gds")
        if len(dataset) != 2:
            raise SystemExit(f"unexpected DALI NumPy file dataset length: {len(dataset)}")
        byte_estimate = module.estimate_numpy_file_dataset_bytes(dataset)
        if byte_estimate.get("dataset_file_count") != 2:
            raise SystemExit(f"unexpected DALI NumPy file count: {byte_estimate}")
        if byte_estimate.get("dataset_total_bytes") != len(b"sample0sample1labels"):
            raise SystemExit(f"unexpected DALI NumPy file byte estimate: {byte_estimate}")

        args.input_backend = "dali-numpy-fp16-blocks-gds"
        block_root = module.resolve_dali_numpy_block_root(args)
        expected_block_suffix = Path("imagenet/train/spc-16-seed-20260518/size-224/numpy-fp16-blocks")
        if block_root != Path(tmp) / expected_block_suffix:
            raise SystemExit(f"unexpected DALI NumPy block root: {block_root}")
        assert_raises(FileNotFoundError, module.NumpyBlockDatasetMetadata, block_root, "dali-numpy-fp16-blocks-gds")

        blocks = block_root / "blocks"
        blocks.mkdir(parents=True)
        (block_root / "metadata.json").write_text(
            '{"sample_count": 3, "image_size": 224, "storage_dtype": "float16", "storage_layout": "blocked-npy-nchw", "block_size": 2, "block_count": 2}',
            encoding="utf-8",
        )
        (block_root / "labels.npy").write_bytes(b"labels")
        (block_root / "block-index.jsonl").write_text(
            '{"block_index": 0, "path": "blocks/000000.npy", "sample_count": 2, "start_sample_index": 0}\n'
            '{"block_index": 1, "path": "blocks/000001.npy", "sample_count": 1, "start_sample_index": 2}\n',
            encoding="utf-8",
        )
        (blocks / "000000.npy").write_bytes(b"block0")
        (blocks / "000001.npy").write_bytes(b"block1")
        block_dataset = module.NumpyBlockDatasetMetadata(block_root, "dali-numpy-fp16-blocks-gds")
        if len(block_dataset) != 3:
            raise SystemExit(f"unexpected DALI NumPy block dataset length: {len(block_dataset)}")
        block_estimate = module.estimate_numpy_block_dataset_bytes(block_dataset)
        if block_estimate.get("dataset_block_count") != 2:
            raise SystemExit(f"unexpected DALI NumPy block count: {block_estimate}")
        if block_estimate.get("logical_sample_count") != 3:
            raise SystemExit(f"unexpected DALI NumPy logical sample count: {block_estimate}")
        if block_estimate.get("dataset_total_bytes") != len(b"block0block1labels"):
            raise SystemExit(f"unexpected DALI NumPy block byte estimate: {block_estimate}")
        pytorch_block_dataset = module.NumpyBlockDataset(block_root, "numpy-fp16-blocks-pytorch", block_cache_size=1)
        if len(pytorch_block_dataset) != 3 or pytorch_block_dataset.block_cache_size != 1:
            raise SystemExit("unexpected PyTorch NumPy block dataset metadata")

    print("backend_contract=passed")
    print("numpy_formats=numpy-uint8,numpy-fp16")
    print("numpy_block_formats=numpy-fp16-blocks")
    print("dali_numpy_formats=numpy-fp16-files,numpy-fp16-blocks")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
