#!/usr/bin/env python3
"""Prepare bounded ImageNet-derived datasets for input-pipeline experiments."""

import argparse
import hashlib
import json
import os
import random
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

from dataloader_input_backends import IMAGENET_MEAN, IMAGENET_STD, derived_subset_name


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
RESAMPLE_BICUBIC = getattr(getattr(Image, "Resampling", Image), "BICUBIC")
CACHE_SCHEMA_VERSION = 1


def build_parser():
    parser = argparse.ArgumentParser(
        description="Prepare pre-resized JPEG and NumPy shard datasets from ImageNet ImageFolder input."
    )
    parser.add_argument("--dataset-root", required=True, help="ImageNet ImageFolder root containing train/ and val/.")
    parser.add_argument("--split", default="train", choices=["train", "val"])
    parser.add_argument(
        "--derived-root",
        default=os.environ.get("AICR_DATALOADER_DERIVED_ROOT"),
        help="Output root for derived datasets. May also be set with AICR_DATALOADER_DERIVED_ROOT.",
    )
    parser.add_argument("--samples-per-class", type=int, default=16)
    parser.add_argument("--seed", type=int, default=1234)
    parser.add_argument("--image-size-list", default="224,384,512,768,1024,1536")
    parser.add_argument("--formats", default="jpeg,numpy-uint8,numpy-fp16")
    parser.add_argument(
        "--numpy-block-size",
        type=int,
        default=128,
        help="Images per .npy block for numpy-fp16-blocks.",
    )
    parser.add_argument("--jpeg-quality", type=int, default=95)
    parser.add_argument("--apply", action="store_true", help="Write outputs. Without this flag, only print the plan.")
    parser.add_argument("--overwrite", action="store_true", help="Replace existing derived dataset directories.")
    return parser


def parse_csv_ints(value, label):
    items = [item.strip() for item in value.split(",") if item.strip()]
    if not items:
        raise ValueError(f"{label} cannot be empty")
    values = [int(item) for item in items]
    if any(item <= 0 for item in values):
        raise ValueError(f"{label} values must be positive")
    return values


def parse_formats(value):
    formats = [item.strip() for item in value.split(",") if item.strip()]
    allowed = {
        "jpeg",
        "synthetic-jpeg",
        "procedural-jpeg",
        "numpy-uint8",
        "numpy-fp16",
        "numpy-fp16-files",
        "numpy-fp16-blocks",
    }
    if not formats:
        raise ValueError("--formats cannot be empty")
    unsupported = sorted(set(formats) - allowed)
    if unsupported:
        raise ValueError(f"unsupported --formats values: {','.join(unsupported)}")
    return formats


def estimated_format_bytes(sample_count, image_size, fmt):
    label_bytes = sample_count * np.dtype(np.int64).itemsize
    if fmt == "numpy-uint8":
        return sample_count * image_size * image_size * 3 * np.dtype(np.uint8).itemsize + label_bytes
    if fmt == "numpy-fp16":
        return sample_count * 3 * image_size * image_size * np.dtype(np.float16).itemsize + label_bytes
    if fmt in {"numpy-fp16-files", "numpy-fp16-blocks"}:
        return sample_count * 3 * image_size * image_size * np.dtype(np.float16).itemsize + label_bytes
    return None


def format_bytes(value):
    if value is None:
        return "unknown"
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    amount = float(value)
    for unit in units:
        if amount < 1024.0 or unit == units[-1]:
            return f"{amount:.1f} {unit}"
        amount /= 1024.0


def discover_imagefolder(split_root):
    classes = sorted(path.name for path in split_root.iterdir() if path.is_dir())
    if not classes:
        raise FileNotFoundError(f"no class directories found under {split_root}")
    rows = []
    for class_index, class_name in enumerate(classes):
        class_dir = split_root / class_name
        paths = sorted(
            path
            for path in class_dir.rglob("*")
            if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
        )
        if not paths:
            continue
        rows.append((class_index, class_name, paths))
    if not rows:
        raise FileNotFoundError(f"no image files found under {split_root}")
    return classes, rows


def select_samples(class_rows, samples_per_class, seed):
    selected = []
    for class_index, class_name, paths in class_rows:
        rng = random.Random(f"{seed}:{class_name}")
        shuffled = list(paths)
        rng.shuffle(shuffled)
        for offset, path in enumerate(sorted(shuffled[:samples_per_class])):
            selected.append({
                "source_path": str(path),
                "class_index": class_index,
                "class_name": class_name,
                "class_offset": offset,
            })
    selected.sort(key=lambda item: (item["class_index"], item["source_path"]))
    return selected


def cache_path(output_base):
    return output_base / "selected-samples-cache.json"


def cache_matches(metadata, args, dataset_root):
    return (
        int(metadata.get("schema_version") or 0) == CACHE_SCHEMA_VERSION
        and str(metadata.get("source_dataset_root")) == str(dataset_root.resolve())
        and metadata.get("split") == args.split
        and int(metadata.get("samples_per_class") or -1) == int(args.samples_per_class)
        and int(metadata.get("seed") or -1) == int(args.seed)
    )


def load_sample_cache(output_base, args, dataset_root):
    path = cache_path(output_base)
    if not path.is_file():
        return None
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not cache_matches(payload, args, dataset_root):
        return None
    classes = list(payload.get("classes") or [])
    samples = list(payload.get("samples") or [])
    if not classes or not samples:
        return None
    return classes, samples, f"cache:{path}"


def load_existing_derived_selection(output_base, args, dataset_root):
    if not output_base.is_dir():
        return None
    candidates = sorted(output_base.glob("size-*/*/metadata.json"))
    for metadata_path in candidates:
        try:
            metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if not cache_matches(metadata, args, dataset_root):
            continue
        index_path = metadata_path.parent / "index.jsonl"
        if not index_path.is_file():
            continue
        samples = []
        with index_path.open("r", encoding="utf-8") as handle:
            for line in handle:
                if line.strip():
                    row = json.loads(line)
                    row.pop("sample_index", None)
                    samples.append(row)
        classes = list(metadata.get("classes") or [])
        if classes and samples:
            return classes, samples, f"existing-derived:{metadata_path.parent}"
    return None


def write_sample_cache(output_base, args, dataset_root, classes, samples):
    output_base.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema_version": CACHE_SCHEMA_VERSION,
        "source_dataset_root": str(dataset_root.resolve()),
        "split": args.split,
        "samples_per_class": args.samples_per_class,
        "seed": args.seed,
        "class_count": len(classes),
        "sample_count": len(samples),
        "classes": classes,
        "samples": samples,
    }
    cache_path(output_base).write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def open_square_rgb(path, image_size):
    with Image.open(path) as image:
        image = image.convert("RGB")
        return ImageOps.fit(image, (image_size, image_size), method=RESAMPLE_BICUBIC)


def write_metadata(
    root,
    args,
    classes,
    samples,
    image_size,
    fmt,
    storage_dtype,
    storage_layout,
    *,
    source_policy,
    transform_policy,
    extra_metadata=None,
):
    root.mkdir(parents=True, exist_ok=True)
    metadata = {
        "schema_version": 1,
        "source_dataset_root": str(Path(args.dataset_root).resolve()),
        "split": args.split,
        "samples_per_class": args.samples_per_class,
        "seed": args.seed,
        "image_size": image_size,
        "sample_count": len(samples),
        "class_count": len(classes),
        "classes": classes,
        "class_to_idx": {name: index for index, name in enumerate(classes)},
        "format": fmt,
        "storage_dtype": storage_dtype,
        "storage_layout": storage_layout,
        "source_policy": source_policy,
        "jpeg_quality": args.jpeg_quality if fmt.endswith("jpeg") else None,
        "transform_policy": transform_policy,
    }
    if extra_metadata:
        metadata.update(extra_metadata)
    (root / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    with (root / "index.jsonl").open("w", encoding="utf-8") as handle:
        for sample_index, sample in enumerate(samples):
            row = dict(sample)
            row["sample_index"] = sample_index
            handle.write(json.dumps(row, sort_keys=True) + "\n")
    return metadata


def prepare_output_dir(path, overwrite):
    if path.exists():
        if not overwrite:
            raise FileExistsError(f"derived output exists; use --overwrite to replace: {path}")
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def stable_seed(*parts):
    digest = hashlib.sha256(":".join(str(part) for part in parts).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "little", signed=False)


def procedural_rgb(sample, image_size, seed):
    rng = np.random.default_rng(stable_seed(seed, sample["class_name"], sample["class_offset"], image_size))
    array = rng.integers(0, 256, size=(image_size, image_size, 3), dtype=np.uint8)
    # Add a deterministic class tint so labels are not completely arbitrary while
    # preserving the high-entropy JPEG stress behavior.
    tint = np.asarray(
        [
            (int(sample["class_index"]) * 37) % 256,
            (int(sample["class_index"]) * 73) % 256,
            (int(sample["class_index"]) * 109) % 256,
        ],
        dtype=np.uint16,
    )
    array = ((array.astype(np.uint16) * 3 + tint.reshape(1, 1, 3)) // 4).astype(np.uint8)
    return Image.fromarray(array, mode="RGB")


def jpeg_image_for_sample(sample, image_size, fmt, seed):
    if fmt == "procedural-jpeg":
        return procedural_rgb(sample, image_size, seed)
    return open_square_rgb(sample["source_path"], image_size)


def write_jpeg_dataset(root, args, classes, samples, image_size, fmt):
    train_root = root / args.split
    for class_name in classes:
        (train_root / class_name).mkdir(parents=True, exist_ok=True)
    labels = np.empty((len(samples),), dtype=np.int64)
    for sample_index, sample in enumerate(samples):
        image = jpeg_image_for_sample(sample, image_size, fmt, args.seed)
        labels[sample_index] = int(sample["class_index"])
        output_name = f"{sample_index:08d}.jpg"
        image.save(
            train_root / sample["class_name"] / output_name,
            format="JPEG",
            quality=args.jpeg_quality,
            optimize=False,
        )
    np.save(root / "labels.npy", labels)


def write_numpy_dataset(root, args, samples, image_size, fmt):
    labels = np.empty((len(samples),), dtype=np.int64)
    if fmt == "numpy-uint8":
        images = np.lib.format.open_memmap(
            root / "images.npy",
            mode="w+",
            dtype=np.uint8,
            shape=(len(samples), image_size, image_size, 3),
        )
    else:
        images = np.lib.format.open_memmap(
            root / "images.npy",
            mode="w+",
            dtype=np.float16,
            shape=(len(samples), 3, image_size, image_size),
        )
        mean = np.asarray(IMAGENET_MEAN, dtype=np.float32).reshape(3, 1, 1)
        std = np.asarray(IMAGENET_STD, dtype=np.float32).reshape(3, 1, 1)
    for sample_index, sample in enumerate(samples):
        image = open_square_rgb(sample["source_path"], image_size)
        array = np.asarray(image, dtype=np.uint8)
        labels[sample_index] = int(sample["class_index"])
        if fmt == "numpy-uint8":
            images[sample_index] = array
        else:
            chw = array.transpose(2, 0, 1).astype(np.float32) / 255.0
            images[sample_index] = ((chw - mean) / std).astype(np.float16)
    images.flush()
    np.save(root / "labels.npy", labels)


def write_numpy_file_dataset(root, args, samples, image_size):
    sample_root = root / "samples"
    sample_root.mkdir(parents=True, exist_ok=True)
    labels = np.empty((len(samples),), dtype=np.int64)
    mean = np.asarray(IMAGENET_MEAN, dtype=np.float32).reshape(3, 1, 1)
    std = np.asarray(IMAGENET_STD, dtype=np.float32).reshape(3, 1, 1)
    for sample_index, sample in enumerate(samples):
        image = open_square_rgb(sample["source_path"], image_size)
        array = np.asarray(image, dtype=np.uint8)
        chw = array.transpose(2, 0, 1).astype(np.float32) / 255.0
        labels[sample_index] = int(sample["class_index"])
        np.save(sample_root / f"{sample_index:08d}.npy", ((chw - mean) / std).astype(np.float16))
    np.save(root / "labels.npy", labels)


def write_numpy_block_dataset(root, args, samples, image_size):
    block_root = root / "blocks"
    block_root.mkdir(parents=True, exist_ok=True)
    labels = np.empty((len(samples),), dtype=np.int64)
    mean = np.asarray(IMAGENET_MEAN, dtype=np.float32).reshape(3, 1, 1)
    std = np.asarray(IMAGENET_STD, dtype=np.float32).reshape(3, 1, 1)
    block_rows = []
    block_size = int(args.numpy_block_size)
    if len(samples) % block_size != 0:
        raise ValueError(
            f"numpy-fp16-blocks requires sample_count divisible by --numpy-block-size; "
            f"got sample_count={len(samples)} block_size={block_size}"
        )

    for block_index, block_start in enumerate(range(0, len(samples), block_size)):
        block_samples = samples[block_start:block_start + block_size]
        block = np.empty((len(block_samples), 3, image_size, image_size), dtype=np.float16)
        for block_offset, sample in enumerate(block_samples):
            sample_index = block_start + block_offset
            image = open_square_rgb(sample["source_path"], image_size)
            array = np.asarray(image, dtype=np.uint8)
            chw = array.transpose(2, 0, 1).astype(np.float32) / 255.0
            labels[sample_index] = int(sample["class_index"])
            block[block_offset] = ((chw - mean) / std).astype(np.float16)
        block_name = f"{block_index:06d}.npy"
        block_path = block_root / block_name
        np.save(block_path, block)
        block_rows.append({
            "block_index": block_index,
            "path": f"blocks/{block_name}",
            "start_sample_index": block_start,
            "sample_count": len(block_samples),
        })

    np.save(root / "labels.npy", labels)
    with (root / "block-index.jsonl").open("w", encoding="utf-8") as handle:
        for row in block_rows:
            handle.write(json.dumps(row, sort_keys=True) + "\n")

    dataset_total_bytes = sum((block_root / row["path"].split("/", 1)[1]).stat().st_size for row in block_rows)
    dataset_total_bytes += (root / "labels.npy").stat().st_size
    return {
        "block_size": block_size,
        "block_count": len(block_rows),
        "dataset_total_bytes": dataset_total_bytes,
    }


def main():
    args = build_parser().parse_args()
    if not args.derived_root:
        raise SystemExit("--derived-root or AICR_DATALOADER_DERIVED_ROOT is required")
    if args.samples_per_class <= 0:
        raise SystemExit("--samples-per-class must be positive")
    if args.numpy_block_size <= 0:
        raise SystemExit("--numpy-block-size must be positive")
    image_sizes = parse_csv_ints(args.image_size_list, "--image-size-list")
    formats = parse_formats(args.formats)
    dataset_root = Path(args.dataset_root)
    split_root = dataset_root / args.split
    if not split_root.is_dir():
        raise SystemExit(f"missing ImageFolder split: {split_root}")
    subset = derived_subset_name(args.samples_per_class, args.seed)
    output_base = Path(args.derived_root) / "imagenet" / args.split / subset
    cached = load_sample_cache(output_base, args, dataset_root)
    if cached is None:
        cached = load_existing_derived_selection(output_base, args, dataset_root)
    if cached is not None:
        classes, samples, selection_source = cached
    else:
        classes, class_rows = discover_imagefolder(split_root)
        samples = select_samples(class_rows, args.samples_per_class, args.seed)
        selection_source = "fresh-scan"

    print("Derived DataLoader dataset plan")
    print(f"  Source split : {split_root}")
    print(f"  Output root  : {output_base}")
    print(f"  Classes      : {len(classes)}")
    print(f"  Samples      : {len(samples)}")
    print(f"  Selection    : {selection_source}")
    print(f"  Image sizes  : {','.join(str(item) for item in image_sizes)}")
    print(f"  Formats      : {','.join(formats)}")
    if "numpy-fp16-blocks" in formats:
        print(f"  Block size   : {args.numpy_block_size}")
    print(f"  Apply        : {args.apply}")
    print("  Storage estimate:")
    for image_size in image_sizes:
        for fmt in formats:
            estimate = estimated_format_bytes(len(samples), image_size, fmt)
            if estimate is not None:
                print(f"    size={image_size} format={fmt}: {format_bytes(estimate)}")
            else:
                print(f"    size={image_size} format={fmt}: depends on JPEG quality/content")
    if not args.apply:
        print("Dry run only. Re-run with --apply to write derived datasets.")
        return 0

    write_sample_cache(output_base, args, dataset_root, classes, samples)

    for image_size in image_sizes:
        size_root = output_base / f"size-{image_size}"
        for fmt in formats:
            fmt_root = size_root / fmt
            prepare_output_dir(fmt_root, args.overwrite)
            if fmt in {"jpeg", "synthetic-jpeg", "procedural-jpeg"}:
                if fmt == "jpeg":
                    source_policy = "imagenet-fit"
                    transform_policy = "ImageOps.fit(center crop/resize to square); runtime decode/normalize"
                elif fmt == "synthetic-jpeg":
                    source_policy = "imagenet-derived-photo-like-large-jpeg"
                    transform_policy = "ImageNet-derived deterministic square JPEG; runtime decode/normalize"
                else:
                    source_policy = "deterministic-high-entropy-procedural-jpeg"
                    transform_policy = "Procedural deterministic RGB JPEG stress input; runtime decode/normalize"
                write_metadata(
                    fmt_root,
                    args,
                    classes,
                    samples,
                    image_size,
                    fmt,
                    "uint8-jpeg",
                    "ImageFolder",
                    source_policy=source_policy,
                    transform_policy=transform_policy,
                )
                write_jpeg_dataset(fmt_root, args, classes, samples, image_size, fmt)
            elif fmt == "numpy-uint8":
                write_metadata(
                    fmt_root,
                    args,
                    classes,
                    samples,
                    image_size,
                    fmt,
                    "uint8",
                    "NHWC",
                    source_policy="imagenet-fit",
                    transform_policy="ImageOps.fit(center crop/resize to square); runtime normalization",
                )
                write_numpy_dataset(fmt_root, args, samples, image_size, fmt)
            elif fmt == "numpy-fp16":
                write_metadata(
                    fmt_root,
                    args,
                    classes,
                    samples,
                    image_size,
                    fmt,
                    "float16",
                    "NCHW",
                    source_policy="imagenet-fit",
                    transform_policy="ImageOps.fit(center crop/resize to square); ImageNet normalization for numpy-fp16",
                )
                write_numpy_dataset(fmt_root, args, samples, image_size, fmt)
            else:
                if fmt == "numpy-fp16-blocks":
                    block_metadata = write_numpy_block_dataset(fmt_root, args, samples, image_size)
                    write_metadata(
                        fmt_root,
                        args,
                        classes,
                        samples,
                        image_size,
                        fmt,
                        "float16",
                        "blocked-npy-nchw",
                        source_policy="imagenet-fit",
                        transform_policy="ImageOps.fit(center crop/resize to square); ImageNet normalization for DALI blocked NumPy reader",
                        extra_metadata=block_metadata,
                    )
                else:
                    write_metadata(
                        fmt_root,
                        args,
                        classes,
                        samples,
                        image_size,
                        fmt,
                        "float16",
                        "per-sample-npy-nchw",
                        source_policy="imagenet-fit",
                        transform_policy="ImageOps.fit(center crop/resize to square); ImageNet normalization for DALI NumPy reader",
                    )
                    write_numpy_file_dataset(fmt_root, args, samples, image_size)
            print(f"Wrote {fmt_root}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
