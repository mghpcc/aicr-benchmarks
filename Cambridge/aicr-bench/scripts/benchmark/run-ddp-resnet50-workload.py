#!/usr/bin/env python3
import argparse
import json
import os
import platform
import socket
import sys
import time
import traceback
from pathlib import Path

from dataloader_input_backends import (
    NumpyBlockDataset,
    NumpyBlockDatasetMetadata,
    NumpyShardDataset,
    derived_metadata_fields,
    estimate_numpy_block_dataset_bytes,
    estimate_numpy_dataset_bytes,
    is_dali_numpy_block_backend,
    is_numpy_backend,
    is_numpy_block_backend,
    resolve_dali_numpy_block_root,
    resolve_numpy_block_root,
    resolve_numpy_shard_root,
)


def build_parser():
    parser = argparse.ArgumentParser(description="Run fixed-iteration ResNet-50 DDP on ImageNet.")
    parser.add_argument("--dataset-root", required=True)
    parser.add_argument("--split", default="train", choices=["train", "val"])
    parser.add_argument(
        "--input-backend",
        choices=[
            "pytorch-cpu-dataloader",
            "dali-gpu-decode",
            "numpy-uint8-shards",
            "numpy-fp16-shards",
            "numpy-fp16-blocks-pytorch",
            "dali-numpy-fp16-blocks-gds",
            "synthetic-gpu",
        ],
        default="pytorch-cpu-dataloader",
        help="Input path to compare against the baseline PyTorch CPU DataLoader.",
    )
    parser.add_argument("--derived-root", default=os.environ.get("AICR_DATALOADER_DERIVED_ROOT"))
    parser.add_argument("--derived-image-size", type=int, default=224)
    parser.add_argument("--derived-samples-per-class", type=int, default=16)
    parser.add_argument("--derived-seed", type=int, default=1234)
    parser.add_argument("--batch-size", type=int, default=256, help="Per-rank batch size.")
    parser.add_argument("--num-workers", type=int, default=16)
    parser.add_argument("--prefetch-factor", type=int, default=4)
    parser.add_argument("--dali-num-threads", type=int, default=0)
    parser.add_argument("--dali-prefetch-queue-depth", type=int, default=2)
    parser.add_argument("--dali-numpy-reader-prefetch-queue-depth", type=int, default=1)
    parser.add_argument("--dali-decode-mode", default="random-crop", choices=["random-crop", "decode-resize"])
    parser.add_argument("--dali-hw-decoder-load", type=float, default=0.65)
    parser.add_argument("--dali-gds-chunk-size", default=os.environ.get("DDP_DALI_GDS_CHUNK_SIZE", ""))
    parser.add_argument("--numpy-block-cache-size", type=int, default=1)
    parser.add_argument("--cufile-log-path", default=os.environ.get("DDP_CUFILE_LOG_PATH"))
    parser.add_argument("--cufile-log-level", default=os.environ.get("DDP_CUFILE_LOG_LEVEL", "INFO"))
    parser.add_argument(
        "--prepared-block-label-source",
        choices=["synthetic-gpu"],
        default="synthetic-gpu",
        help="Label source for DALI prepared-block DDP rows; image transport remains the measured GDS path.",
    )
    parser.add_argument("--synthetic-class-count", type=int, default=1000)
    parser.add_argument("--synthetic-image-size", type=int, default=224)
    parser.add_argument("--synthetic-dtype", default="float32", choices=["float32", "float16", "bfloat16"])
    parser.add_argument("--pin-memory", type=int, choices=[0, 1], default=1)
    parser.add_argument("--persistent-workers", type=int, choices=[0, 1], default=1)
    parser.add_argument("--drop-last", type=int, choices=[0, 1], default=1)
    parser.add_argument("--warmup-iters", type=int, default=20)
    parser.add_argument("--measured-iters", type=int, default=100)
    parser.add_argument("--precision", choices=["bf16", "fp32"], default="bf16")
    parser.add_argument("--channels-last", type=int, choices=[0, 1], default=1)
    parser.add_argument("--launcher", choices=["torchrun", "srun"], default="torchrun")
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--node-list", default="")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--summary-output", required=True)
    parser.add_argument("--status-output", required=True)
    parser.add_argument("--local-rank", "--local_rank", type=int, default=None)
    return parser


def env_int(name, default=None):
    value = os.environ.get(name)
    if value is None or value == "":
        return default
    return int(value)


def configure_rank_env(local_rank_arg):
    rank = env_int("RANK", env_int("SLURM_PROCID", 0))
    world_size = env_int("WORLD_SIZE", env_int("SLURM_NTASKS", 1))
    local_rank = env_int("LOCAL_RANK", env_int("SLURM_LOCALID", local_rank_arg if local_rank_arg is not None else 0))
    local_world_size = env_int("LOCAL_WORLD_SIZE", env_int("SLURM_NTASKS_PER_NODE", None))
    os.environ.setdefault("RANK", str(rank))
    os.environ.setdefault("WORLD_SIZE", str(world_size))
    os.environ.setdefault("LOCAL_RANK", str(local_rank))
    if local_world_size is not None:
        os.environ.setdefault("LOCAL_WORLD_SIZE", str(local_world_size))
    return rank, world_size, local_rank, local_world_size


def write_json(path, payload):
    out = Path(path)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def timed_cuda(device, fn):
    import torch

    torch.cuda.synchronize(device)
    started = time.perf_counter()
    value = fn()
    torch.cuda.synchronize(device)
    return value, time.perf_counter() - started


def batches_per_rank(args, sampler_length):
    if sampler_length is None or args.batch_size <= 0:
        return None
    if args.drop_last:
        return sampler_length // args.batch_size
    return (sampler_length + args.batch_size - 1) // args.batch_size


def enforce_finite_input_epoch_shape(args, dataset_size, sampler_length, rank, world_size, metadata=None):
    batch_count = batches_per_rank(args, sampler_length)
    if args.input_backend == "synthetic-gpu" or sampler_length is None:
        return batch_count
    if args.drop_last and batch_count == 0:
        details = {
            "input_backend": args.input_backend,
            "dataset_size": dataset_size,
            "world_size": world_size,
            "rank": rank,
            "sampler_length": sampler_length,
            "batch_size": args.batch_size,
            "drop_last": args.drop_last,
            "batches_per_rank": batch_count,
        }
        if metadata:
            for key in [
                "derived_root",
                "derived_image_size",
                "derived_samples_per_class",
                "derived_seed",
                "derived_format",
                "derived_storage_dtype",
                "derived_storage_layout",
            ]:
                if metadata.get(key) is not None:
                    details[key] = metadata.get(key)
        detail_text = ", ".join(f"{key}={value}" for key, value in details.items())
        raise RuntimeError(
            "DDP finite input shape has zero full batches per rank with drop_last=1: "
            f"{detail_text}. Reduce --batch-size, increase the derived corpus size or "
            "--derived-samples-per-class, reduce world size, or use --drop-last 0 for a "
            "diagnostic row."
        )
    return batch_count


def next_batch(loader, iterator):
    try:
        batch = next(iterator)
    except StopIteration:
        iterator = iter(loader)
        batch = next(iterator)
    return batch, iterator


def configure_dali_gds_environment(args, rank):
    if args.dali_gds_chunk_size:
        os.environ["DALI_GDS_CHUNK_SIZE"] = str(args.dali_gds_chunk_size)
    if args.cufile_log_path:
        log_path = Path(str(args.cufile_log_path).replace("{rank}", str(rank)))
        log_path.parent.mkdir(parents=True, exist_ok=True)
        os.environ["CUFILE_LOGFILE_PATH"] = str(log_path)
        os.environ["CUFILE_LOGGING_LEVEL"] = str(args.cufile_log_level or "INFO")
        os.environ["CUFILE_LOG_LEVEL"] = os.environ["CUFILE_LOGGING_LEVEL"]
        args.cufile_log_path = str(log_path)
        args.cufile_log_level = os.environ["CUFILE_LOGGING_LEVEL"]


def build_torch_input(args, split_root, rank, world_size):
    from torch.utils.data import DataLoader
    from torch.utils.data.distributed import DistributedSampler
    from torchvision import datasets, transforms

    transform = transforms.Compose([
        transforms.RandomResizedCrop(224),
        transforms.RandomHorizontalFlip(),
        transforms.ToTensor(),
        transforms.Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
    ])
    dataset = datasets.ImageFolder(str(split_root), transform=transform)
    sampler = DistributedSampler(
        dataset,
        num_replicas=world_size,
        rank=rank,
        shuffle=args.split == "train",
        drop_last=bool(args.drop_last),
    )
    sampler.set_epoch(0)
    derived_metadata = derived_metadata_fields(split_root.parent)
    sampler_length = len(sampler)
    batch_count = enforce_finite_input_epoch_shape(
        args,
        dataset_size=len(dataset),
        sampler_length=sampler_length,
        rank=rank,
        world_size=world_size,
        metadata=derived_metadata,
    )
    loader_kwargs = {
        "batch_size": args.batch_size,
        "sampler": sampler,
        "num_workers": args.num_workers,
        "pin_memory": bool(args.pin_memory),
        "persistent_workers": bool(args.persistent_workers) if args.num_workers > 0 else False,
        "drop_last": bool(args.drop_last),
    }
    if args.num_workers > 0:
        loader_kwargs["prefetch_factor"] = args.prefetch_factor
    loader = DataLoader(dataset, **loader_kwargs)
    state = {
        "loader": loader,
        "iterator": iter(loader),
        "dataset_size": len(dataset),
        "class_count": len(getattr(dataset, "classes", []) or []),
        "sampler_length": sampler_length,
        "batches_per_rank": batch_count,
        "input_gpu_resident": False,
    }
    state.update(derived_metadata)
    return state


def build_dali_input(args, split_root, rank, world_size, local_rank):
    from torchvision import datasets

    try:
        from nvidia.dali import fn, types
        from nvidia.dali.pipeline import pipeline_def
        from nvidia.dali.plugin.pytorch import DALIGenericIterator, LastBatchPolicy
    except ImportError as exc:
        raise RuntimeError("DALI input backend requested, but nvidia.dali is not available in the runtime image") from exc

    @pipeline_def
    def imagenet_pipeline(data_dir, shard_id, num_shards, random_shuffle, decode_mode, hw_decoder_load):
        jpegs, labels = fn.readers.file(
            file_root=data_dir,
            shard_id=shard_id,
            num_shards=num_shards,
            random_shuffle=random_shuffle,
            dont_use_mmap=True,
            name="reader",
        )
        if decode_mode == "random-crop":
            images = fn.decoders.image_random_crop(
                jpegs,
                device="mixed",
                output_type=types.RGB,
                random_area=[0.08, 1.0],
                random_aspect_ratio=[0.75, 1.3333333333333333],
                hw_decoder_load=hw_decoder_load,
            )
            images = fn.resize(images, resize_x=224, resize_y=224)
        else:
            images = fn.decoders.image(
                jpegs,
                device="mixed",
                output_type=types.RGB,
                hw_decoder_load=hw_decoder_load,
            )
            images = fn.resize(images, resize_x=256, resize_y=256)
        mirror = fn.random.coin_flip(probability=0.5)
        images = fn.crop_mirror_normalize(
            images,
            dtype=types.FLOAT,
            output_layout="CHW",
            crop=(224, 224),
            mean=[0.485 * 255.0, 0.456 * 255.0, 0.406 * 255.0],
            std=[0.229 * 255.0, 0.224 * 255.0, 0.225 * 255.0],
            mirror=mirror,
        )
        return images, labels

    metadata = datasets.ImageFolder(str(split_root))
    derived_metadata = derived_metadata_fields(split_root.parent)
    sampler_length = len(metadata) // world_size if world_size else None
    batch_count = enforce_finite_input_epoch_shape(
        args,
        dataset_size=len(metadata),
        sampler_length=sampler_length,
        rank=rank,
        world_size=world_size,
        metadata=derived_metadata,
    )
    dali_num_threads = args.dali_num_threads if args.dali_num_threads > 0 else max(1, args.num_workers)
    pipe = imagenet_pipeline(
        batch_size=args.batch_size,
        num_threads=dali_num_threads,
        device_id=local_rank,
        seed=1234 + rank,
        prefetch_queue_depth=args.dali_prefetch_queue_depth,
        data_dir=str(split_root),
        shard_id=rank,
        num_shards=world_size,
        random_shuffle=args.split == "train",
        decode_mode=args.dali_decode_mode,
        hw_decoder_load=args.dali_hw_decoder_load,
    )
    pipe.build()
    last_batch_policy = LastBatchPolicy.DROP if args.drop_last else LastBatchPolicy.PARTIAL
    loader = DALIGenericIterator(
        [pipe],
        ["images", "labels"],
        reader_name="reader",
        auto_reset=True,
        last_batch_policy=last_batch_policy,
    )
    state = {
        "loader": loader,
        "iterator": iter(loader),
        "dataset_size": len(metadata),
        "class_count": len(getattr(metadata, "classes", []) or []),
        "sampler_length": sampler_length,
        "batches_per_rank": batch_count,
        "input_gpu_resident": True,
        "dali_num_threads": dali_num_threads,
    }
    state.update(derived_metadata)
    return state


def build_numpy_input(args, rank, world_size):
    from torch.utils.data import DataLoader
    from torch.utils.data.distributed import DistributedSampler

    if is_numpy_block_backend(args.input_backend):
        dataset_root = resolve_numpy_block_root(args)
        dataset = NumpyBlockDataset(dataset_root, args.input_backend, args.numpy_block_cache_size)
        dataset_byte_estimate = estimate_numpy_block_dataset_bytes(dataset)
        storage_transport_path = "pytorch-numpy-block-cpu-mmap"
    else:
        dataset_root = resolve_numpy_shard_root(args)
        dataset = NumpyShardDataset(dataset_root, args.input_backend)
        dataset_byte_estimate = estimate_numpy_dataset_bytes(dataset)
        storage_transport_path = "pytorch-numpy-shard-cpu-mmap"
    sampler = DistributedSampler(
        dataset,
        num_replicas=world_size,
        rank=rank,
        shuffle=args.split == "train",
        drop_last=bool(args.drop_last),
    )
    sampler.set_epoch(0)
    derived_metadata = {
        "derived_root": str(dataset_root),
        "derived_image_size": dataset.image_size,
        "derived_samples_per_class": dataset.metadata.get("samples_per_class"),
        "derived_seed": dataset.metadata.get("seed"),
        "derived_format": dataset.format,
        "derived_storage_dtype": dataset.storage_dtype,
        "derived_storage_layout": dataset.storage_layout,
        "storage_transport_path": storage_transport_path,
        "dataset_file_count": dataset_byte_estimate.get("dataset_file_count"),
        "dataset_block_count": dataset_byte_estimate.get("dataset_block_count"),
        "dataset_total_bytes": dataset_byte_estimate.get("dataset_total_bytes"),
        "logical_sample_count": dataset_byte_estimate.get("logical_sample_count", len(dataset)),
        "numpy_block_size": getattr(dataset, "block_size", None),
        "numpy_block_cache_size": getattr(dataset, "block_cache_size", None),
        "gds_requested": False,
        "dali_reader_device": None,
        "dali_numpy_use_o_direct": None,
        "dali_numpy_reader_prefetch_queue_depth": None,
        "dali_gds_chunk_size": None,
        "cufile_log_path": None,
        "cufile_log_level": None,
        "prepared_block_label_source": None,
    }
    sampler_length = len(sampler)
    batch_count = enforce_finite_input_epoch_shape(
        args,
        dataset_size=len(dataset),
        sampler_length=sampler_length,
        rank=rank,
        world_size=world_size,
        metadata=derived_metadata,
    )
    loader_kwargs = {
        "batch_size": args.batch_size,
        "sampler": sampler,
        "num_workers": args.num_workers,
        "pin_memory": bool(args.pin_memory),
        "persistent_workers": bool(args.persistent_workers) if args.num_workers > 0 else False,
        "drop_last": bool(args.drop_last),
    }
    if args.num_workers > 0:
        loader_kwargs["prefetch_factor"] = args.prefetch_factor
    loader = DataLoader(dataset, **loader_kwargs)
    return {
        "loader": loader,
        "iterator": iter(loader),
        "dataset_size": len(dataset),
        "class_count": len(getattr(dataset, "classes", []) or []),
        "sampler_length": sampler_length,
        "batches_per_rank": batch_count,
        "input_gpu_resident": False,
        "reader_batch_size_per_rank": None,
        "logical_batch_size_per_rank": args.batch_size,
        **derived_metadata,
    }


def build_dali_numpy_block_input(args, rank, world_size, local_rank):
    configure_dali_gds_environment(args, rank)

    try:
        from nvidia.dali import fn
        from nvidia.dali.pipeline import pipeline_def
        from nvidia.dali.plugin.pytorch import DALIGenericIterator, LastBatchPolicy
    except ImportError as exc:
        raise RuntimeError("DALI NumPy block input backend requested, but nvidia.dali is not available in the runtime image") from exc

    dataset_root = resolve_dali_numpy_block_root(args)
    metadata = NumpyBlockDatasetMetadata(dataset_root, args.input_backend)
    dataset_byte_estimate = estimate_numpy_block_dataset_bytes(metadata)
    reader_device = "gpu"

    @pipeline_def
    def numpy_block_pipeline(block_root, shard_id, num_shards, random_shuffle):
        images = fn.readers.numpy(
            device=reader_device,
            file_root=block_root,
            shard_id=shard_id,
            num_shards=num_shards,
            random_shuffle=random_shuffle,
            dont_use_mmap=True,
            use_o_direct=True,
            prefetch_queue_depth=args.dali_numpy_reader_prefetch_queue_depth,
            name="reader",
        )
        return images

    dali_num_threads = args.dali_num_threads if args.dali_num_threads > 0 else max(1, args.num_workers)
    pipe = numpy_block_pipeline(
        batch_size=args.batch_size,
        num_threads=dali_num_threads,
        device_id=local_rank,
        seed=1234 + rank,
        prefetch_queue_depth=args.dali_prefetch_queue_depth,
        block_root=str(metadata.block_root),
        shard_id=rank,
        num_shards=world_size,
        random_shuffle=args.split == "train",
    )
    pipe.build()
    last_batch_policy = LastBatchPolicy.DROP if args.drop_last else LastBatchPolicy.PARTIAL
    loader = DALIGenericIterator(
        [pipe],
        ["images"],
        reader_name="reader",
        auto_reset=True,
        last_batch_policy=last_batch_policy,
    )
    sampler_length = metadata.block_count // world_size if world_size else None
    batch_count = enforce_finite_input_epoch_shape(
        args,
        dataset_size=metadata.block_count,
        sampler_length=sampler_length,
        rank=rank,
        world_size=world_size,
        metadata={
            "derived_root": str(dataset_root),
            "derived_image_size": metadata.image_size,
            "derived_samples_per_class": metadata.metadata.get("samples_per_class"),
            "derived_seed": metadata.metadata.get("seed"),
            "derived_format": metadata.format,
            "derived_storage_dtype": metadata.storage_dtype,
            "derived_storage_layout": metadata.storage_layout,
        },
    )
    return {
        "loader": loader,
        "iterator": iter(loader),
        "dataset_size": len(metadata),
        "class_count": len(getattr(metadata, "classes", []) or []) or args.synthetic_class_count,
        "sampler_length": sampler_length,
        "batches_per_rank": batch_count,
        "input_gpu_resident": True,
        "dali_num_threads": dali_num_threads,
        "reader_batch_size_per_rank": args.batch_size,
        "logical_batch_size_per_rank": args.batch_size * metadata.block_size,
        "gds_requested": True,
        "dali_reader_device": reader_device,
        "dali_numpy_use_o_direct": True,
        "dali_numpy_reader_prefetch_queue_depth": args.dali_numpy_reader_prefetch_queue_depth,
        "dali_gds_chunk_size": args.dali_gds_chunk_size,
        "cufile_log_path": args.cufile_log_path,
        "cufile_log_level": args.cufile_log_level,
        "storage_transport_path": "dali-numpy-block-gpu-gds",
        "dataset_file_count": dataset_byte_estimate["dataset_file_count"],
        "dataset_block_count": dataset_byte_estimate["dataset_block_count"],
        "dataset_total_bytes": dataset_byte_estimate["dataset_total_bytes"],
        "logical_sample_count": dataset_byte_estimate["logical_sample_count"],
        "numpy_block_size": metadata.block_size,
        "numpy_block_cache_size": None,
        "prepared_block_label_source": args.prepared_block_label_source,
        "derived_root": str(dataset_root),
        "derived_image_size": metadata.image_size,
        "derived_samples_per_class": metadata.metadata.get("samples_per_class"),
        "derived_seed": metadata.metadata.get("seed"),
        "derived_format": metadata.format,
        "derived_storage_dtype": metadata.storage_dtype,
        "derived_storage_layout": metadata.storage_layout,
    }


def build_synthetic_input(args, device):
    import torch

    dtype_by_name = {
        "float32": torch.float32,
        "float16": torch.float16,
        "bfloat16": torch.bfloat16,
    }
    image_size = int(args.synthetic_image_size)
    images = torch.randn(args.batch_size, 3, image_size, image_size, device=device, dtype=dtype_by_name[args.synthetic_dtype])
    if args.channels_last:
        images = images.to(memory_format=torch.channels_last)
    labels = torch.randint(0, args.synthetic_class_count, (args.batch_size,), device=device)
    return {
        "batch": (images, labels),
        "dataset_size": None,
        "class_count": args.synthetic_class_count,
        "sampler_length": None,
        "batches_per_rank": None,
        "input_gpu_resident": True,
        "derived_image_size": image_size,
        "derived_format": "synthetic",
        "derived_storage_dtype": args.synthetic_dtype,
        "derived_storage_layout": "nchw",
    }


def next_input_batch(input_state, input_backend):
    if input_backend == "synthetic-gpu":
        return input_state["batch"]
    if input_backend == "dali-gpu-decode" or is_dali_numpy_block_backend(input_backend):
        try:
            return next(input_state["iterator"])[0]
        except StopIteration:
            input_state["iterator"] = iter(input_state["loader"])
            return next(input_state["iterator"])[0]
    batch, iterator = next_batch(input_state["loader"], input_state["iterator"])
    input_state["iterator"] = iterator
    return batch


def prepare_input_batch(batch, args, device):
    import torch

    if args.input_backend in {
        "pytorch-cpu-dataloader",
        "numpy-uint8-shards",
        "numpy-fp16-shards",
        "numpy-fp16-blocks-pytorch",
    }:
        images, labels = batch
        if args.channels_last:
            images = images.to(device, non_blocking=bool(args.pin_memory), memory_format=torch.channels_last)
        else:
            images = images.to(device, non_blocking=bool(args.pin_memory))
        labels = labels.to(device, non_blocking=bool(args.pin_memory))
        return images, labels, True

    if args.input_backend == "dali-gpu-decode":
        images = batch["images"]
        labels = batch["labels"].view(-1).long()
        h2d_needed = images.device.type != "cuda" or labels.device.type != "cuda"
        if images.device.type != "cuda":
            images = images.to(device, non_blocking=True)
        if args.channels_last:
            images = images.to(memory_format=torch.channels_last)
        if labels.device.type != "cuda":
            labels = labels.to(device, non_blocking=True)
        return images, labels, h2d_needed

    if args.input_backend == "dali-numpy-fp16-blocks-gds":
        images = batch["images"]
        if images.ndim == 5:
            images = images.reshape(-1, images.shape[-3], images.shape[-2], images.shape[-1])
        elif images.ndim != 4:
            raise RuntimeError(f"unexpected DALI NumPy block tensor shape: {tuple(images.shape)}")
        h2d_needed = images.device.type != "cuda"
        if images.device.type != "cuda":
            images = images.to(device, non_blocking=True)
        if args.channels_last:
            images = images.to(memory_format=torch.channels_last)
        class_count = int(getattr(args, "effective_class_count", args.synthetic_class_count))
        labels = torch.randint(0, class_count, (int(images.shape[0]),), device=device)
        return images, labels, h2d_needed

    images, labels = batch
    return images, labels, False


def aggregate_rank_metrics(rank_paths, args, rank, world_size):
    rows = []
    status = "passed"
    notes = []
    for path in rank_paths:
        if not path.exists():
            status = "failed"
            notes.append(f"missing rank metrics: {path.name}")
            continue
        row = json.loads(path.read_text(encoding="utf-8"))
        rows.append(row)
        if row.get("status") != "passed":
            status = "failed"
            notes.append(f"rank {row.get('rank')} failed: {row.get('notes', '')}")

    measured = [row for row in rows if row.get("status") == "passed"]
    total_samples = sum(row.get("samples_total") or 0 for row in measured)
    aggregate_sps = sum(row.get("samples_per_second") or 0 for row in measured) if measured else None
    step_values = [row.get("step_mean_seconds") for row in measured if row.get("step_mean_seconds") is not None]
    data_values = [row.get("data_wait_mean_seconds") for row in measured if row.get("data_wait_mean_seconds") is not None]
    h2d_values = [row.get("h2d_mean_seconds") for row in measured if row.get("h2d_mean_seconds") is not None]
    input_prepare_values = [row.get("input_prepare_mean_seconds") for row in measured if row.get("input_prepare_mean_seconds") is not None]
    train_values = [row.get("train_mean_seconds") for row in measured if row.get("train_mean_seconds") is not None]
    sps_values = [row.get("samples_per_second") for row in measured if row.get("samples_per_second") is not None]
    first_measured = measured[0] if measured else {}
    dataset_size = first_measured.get("dataset_size")
    class_count = first_measured.get("class_count")
    input_batches_per_rank = first_measured.get("batches_per_rank")
    logical_batch_size_per_rank = first_measured.get("logical_batch_size_per_rank") or args.batch_size
    epoch_time_minutes = (dataset_size / aggregate_sps / 60.0) if dataset_size and aggregate_sps else None

    rank_imbalance_ratio = (max(sps_values) / min(sps_values)) if sps_values and min(sps_values) else None
    rank_imbalance_percent = (rank_imbalance_ratio - 1.0) * 100.0 if rank_imbalance_ratio is not None else None

    summary = {
        "schema_version": 1,
        "status": status,
        "notes": "; ".join(note for note in notes if note),
        "benchmark": "ddp-resnet50",
        "run_id": args.run_id,
        "date": os.environ.get("AICR_DATE_UTC"),
        "cluster": os.environ.get("AICR_CLUSTER_NAME", "b200"),
        "launcher": args.launcher,
        "input_backend": args.input_backend,
        "input_gpu_resident": bool(first_measured.get("input_gpu_resident")) if first_measured else None,
        "node_list": args.node_list,
        "node_count": env_int("SLURM_NNODES", None),
        "world_size": world_size,
        "gpus_per_node": env_int("LOCAL_WORLD_SIZE", None),
        "precision": args.precision,
        "channels_last": bool(args.channels_last),
        "dataset_root": args.dataset_root,
        "dataset_split": args.split,
        "dataset_size": dataset_size,
        "class_count": class_count,
        "batches_per_rank": input_batches_per_rank,
        "batch_size_per_rank": args.batch_size,
        "logical_batch_size_per_rank": logical_batch_size_per_rank,
        "reader_batch_size_per_rank": first_measured.get("reader_batch_size_per_rank") if first_measured else None,
        "global_batch_size": logical_batch_size_per_rank * world_size,
        "num_workers": args.num_workers,
        "prefetch_factor": args.prefetch_factor if args.num_workers > 0 else None,
        "dali_num_threads": first_measured.get("dali_num_threads") if first_measured and args.input_backend in {"dali-gpu-decode", "dali-numpy-fp16-blocks-gds"} else None,
        "dali_prefetch_queue_depth": args.dali_prefetch_queue_depth if args.input_backend in {"dali-gpu-decode", "dali-numpy-fp16-blocks-gds"} else None,
        "dali_numpy_reader_prefetch_queue_depth": args.dali_numpy_reader_prefetch_queue_depth if args.input_backend == "dali-numpy-fp16-blocks-gds" else None,
        "dali_decode_mode": args.dali_decode_mode if args.input_backend == "dali-gpu-decode" else None,
        "dali_hw_decoder_load": args.dali_hw_decoder_load if args.input_backend == "dali-gpu-decode" else None,
        "gds_requested": first_measured.get("gds_requested") if first_measured else None,
        "dali_reader_device": first_measured.get("dali_reader_device") if first_measured else None,
        "dali_numpy_use_o_direct": first_measured.get("dali_numpy_use_o_direct") if first_measured else None,
        "dali_gds_chunk_size": first_measured.get("dali_gds_chunk_size") if first_measured else None,
        "cufile_log_path": first_measured.get("cufile_log_path") if first_measured else None,
        "cufile_log_level": first_measured.get("cufile_log_level") if first_measured else None,
        "storage_transport_path": first_measured.get("storage_transport_path") if first_measured else None,
        "dataset_file_count": first_measured.get("dataset_file_count") if first_measured else None,
        "dataset_block_count": first_measured.get("dataset_block_count") if first_measured else None,
        "dataset_total_bytes": first_measured.get("dataset_total_bytes") if first_measured else None,
        "logical_sample_count": first_measured.get("logical_sample_count") if first_measured else None,
        "numpy_block_size": first_measured.get("numpy_block_size") if first_measured else None,
        "numpy_block_cache_size": first_measured.get("numpy_block_cache_size") if first_measured else None,
        "prepared_block_label_source": first_measured.get("prepared_block_label_source") if first_measured else None,
        "synthetic_class_count": args.synthetic_class_count if args.input_backend == "synthetic-gpu" else None,
        "synthetic_image_size": args.synthetic_image_size if args.input_backend == "synthetic-gpu" else None,
        "synthetic_dtype": args.synthetic_dtype if args.input_backend == "synthetic-gpu" else None,
        "derived_root": first_measured.get("derived_root") if first_measured else None,
        "derived_image_size": first_measured.get("derived_image_size") if first_measured else None,
        "derived_samples_per_class": first_measured.get("derived_samples_per_class") if first_measured else None,
        "derived_seed": first_measured.get("derived_seed") if first_measured else None,
        "derived_format": first_measured.get("derived_format") if first_measured else None,
        "derived_storage_dtype": first_measured.get("derived_storage_dtype") if first_measured else None,
        "derived_storage_layout": first_measured.get("derived_storage_layout") if first_measured else None,
        "pin_memory": bool(args.pin_memory),
        "persistent_workers": bool(args.persistent_workers) if args.num_workers > 0 else False,
        "drop_last": bool(args.drop_last),
        "warmup_iters": args.warmup_iters,
        "measured_iters": args.measured_iters,
        "samples_total": total_samples,
        "samples_per_second": aggregate_sps,
        "aggregate_samples_per_second": aggregate_sps,
        "estimated_epoch_time_minutes": epoch_time_minutes,
        "rank_min_samples_per_second": min(sps_values) if sps_values else None,
        "rank_max_samples_per_second": max(sps_values) if sps_values else None,
        "rank_imbalance_ratio": rank_imbalance_ratio,
        "rank_imbalance_percent": rank_imbalance_percent,
        "step_mean_seconds_max_rank": max(step_values) if step_values else None,
        "data_wait_mean_seconds_max_rank": max(data_values) if data_values else None,
        "h2d_mean_seconds_max_rank": max(h2d_values) if h2d_values else None,
        "input_prepare_mean_seconds_max_rank": max(input_prepare_values) if input_prepare_values else None,
        "train_mean_seconds_max_rank": max(train_values) if train_values else None,
        "per_rank": sorted(rows, key=lambda item: item.get("rank", 0)),
    }
    return summary


def main():
    args = build_parser().parse_args()
    if args.dali_numpy_reader_prefetch_queue_depth <= 0:
        raise SystemExit("--dali-numpy-reader-prefetch-queue-depth must be a positive integer")
    if args.numpy_block_cache_size <= 0:
        raise SystemExit("--numpy-block-cache-size must be a positive integer")
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    rank, world_size, local_rank, local_world_size = configure_rank_env(args.local_rank)
    rank_path = output_dir / f"rank-{rank}.json"
    host = socket.gethostname().split(".", 1)[0]

    try:
        import torch
        import torch.distributed as dist
        from torch.nn.parallel import DistributedDataParallel
        from torchvision import __version__ as torchvision_version
        from torchvision import models

        if not torch.cuda.is_available():
            raise RuntimeError("CUDA is not available")
        torch.cuda.set_device(local_rank)
        device = torch.device("cuda", local_rank)
        dist.init_process_group(backend="nccl", init_method="env://")

        dataset_root = Path(args.dataset_root)
        split_root = dataset_root / args.split
        if args.input_backend not in {"synthetic-gpu"} and not is_numpy_backend(args.input_backend) and not is_dali_numpy_block_backend(args.input_backend) and not split_root.is_dir():
            raise FileNotFoundError(f"missing requested split directory: {split_root}")

        if args.input_backend == "pytorch-cpu-dataloader":
            input_state = build_torch_input(args, split_root, rank, world_size)
        elif args.input_backend == "dali-gpu-decode":
            input_state = build_dali_input(args, split_root, rank, world_size, local_rank)
        elif is_numpy_backend(args.input_backend):
            input_state = build_numpy_input(args, rank, world_size)
        elif is_dali_numpy_block_backend(args.input_backend):
            input_state = build_dali_numpy_block_input(args, rank, world_size, local_rank)
        else:
            input_state = build_synthetic_input(args, device)

        class_count = input_state["class_count"] or args.synthetic_class_count
        args.effective_class_count = class_count
        model = models.resnet50(weights=None, num_classes=class_count).to(device)
        if args.channels_last:
            model = model.to(memory_format=torch.channels_last)
        model = DistributedDataParallel(model, device_ids=[local_rank], output_device=local_rank)
        criterion = torch.nn.CrossEntropyLoss().to(device)
        optimizer = torch.optim.SGD(model.parameters(), lr=0.1, momentum=0.9)
        autocast_enabled = args.precision == "bf16"

        def train_one(images, labels):
            with torch.autocast(device_type="cuda", dtype=torch.bfloat16, enabled=autocast_enabled):
                outputs = model(images)
                loss = criterion(outputs, labels)
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            optimizer.step()
            return int(images.shape[0]), float(loss.detach().item())

        for _ in range(args.warmup_iters):
            batch = next_input_batch(input_state, args.input_backend)
            images, labels, _h2d_needed = prepare_input_batch(batch, args, device)
            train_one(images, labels)
        torch.cuda.synchronize(device)

        data_wait_total = 0.0
        h2d_total = 0.0
        input_prepare_total = 0.0
        train_total = 0.0
        step_total = 0.0
        samples_total = 0
        last_loss = None

        for _ in range(args.measured_iters):
            step_started = time.perf_counter()
            data_started = time.perf_counter()
            batch = next_input_batch(input_state, args.input_backend)
            data_wait_total += time.perf_counter() - data_started

            h2d_needed = False

            def prepare_batch():
                nonlocal h2d_needed
                images, labels, h2d_needed = prepare_input_batch(batch, args, device)
                return images, labels

            (images, labels), input_prepare_elapsed = timed_cuda(device, prepare_batch)
            input_prepare_total += input_prepare_elapsed
            if h2d_needed:
                h2d_total += input_prepare_elapsed

            def train_moved():
                nonlocal last_loss
                with torch.autocast(device_type="cuda", dtype=torch.bfloat16, enabled=autocast_enabled):
                    outputs = model(images)
                    loss = criterion(outputs, labels)
                optimizer.zero_grad(set_to_none=True)
                loss.backward()
                optimizer.step()
                last_loss = float(loss.detach().item())
                return int(images.shape[0])

            sample_count, train_elapsed = timed_cuda(device, train_moved)
            train_total += train_elapsed
            samples_total += sample_count
            step_total += time.perf_counter() - step_started

        elapsed = step_total
        row = {
            "schema_version": 1,
            "status": "passed",
            "notes": "",
            "rank": rank,
            "local_rank": local_rank,
            "world_size": world_size,
            "local_world_size": local_world_size,
            "host": host,
            "launcher": args.launcher,
            "input_backend": args.input_backend,
            "input_gpu_resident": bool(input_state["input_gpu_resident"]),
            "dataset_size": input_state["dataset_size"],
            "class_count": input_state["class_count"],
            "sampler_length": input_state["sampler_length"],
            "batches_per_rank": input_state["batches_per_rank"],
            "batch_size": args.batch_size,
            "logical_batch_size_per_rank": input_state.get("logical_batch_size_per_rank", args.batch_size),
            "reader_batch_size_per_rank": input_state.get("reader_batch_size_per_rank"),
            "num_workers": args.num_workers,
            "prefetch_factor": args.prefetch_factor if args.num_workers > 0 else None,
            "dali_num_threads": input_state.get("dali_num_threads") if args.input_backend in {"dali-gpu-decode", "dali-numpy-fp16-blocks-gds"} else None,
            "dali_prefetch_queue_depth": args.dali_prefetch_queue_depth if args.input_backend in {"dali-gpu-decode", "dali-numpy-fp16-blocks-gds"} else None,
            "dali_numpy_reader_prefetch_queue_depth": input_state.get("dali_numpy_reader_prefetch_queue_depth"),
            "dali_decode_mode": args.dali_decode_mode if args.input_backend == "dali-gpu-decode" else None,
            "dali_hw_decoder_load": args.dali_hw_decoder_load if args.input_backend == "dali-gpu-decode" else None,
            "gds_requested": input_state.get("gds_requested"),
            "dali_reader_device": input_state.get("dali_reader_device"),
            "dali_numpy_use_o_direct": input_state.get("dali_numpy_use_o_direct"),
            "dali_gds_chunk_size": input_state.get("dali_gds_chunk_size"),
            "cufile_log_path": input_state.get("cufile_log_path"),
            "cufile_log_level": input_state.get("cufile_log_level"),
            "storage_transport_path": input_state.get("storage_transport_path"),
            "dataset_file_count": input_state.get("dataset_file_count"),
            "dataset_block_count": input_state.get("dataset_block_count"),
            "dataset_total_bytes": input_state.get("dataset_total_bytes"),
            "logical_sample_count": input_state.get("logical_sample_count"),
            "numpy_block_size": input_state.get("numpy_block_size"),
            "numpy_block_cache_size": input_state.get("numpy_block_cache_size"),
            "prepared_block_label_source": input_state.get("prepared_block_label_source"),
            "synthetic_class_count": args.synthetic_class_count if args.input_backend == "synthetic-gpu" else None,
            "synthetic_image_size": args.synthetic_image_size if args.input_backend == "synthetic-gpu" else None,
            "synthetic_dtype": args.synthetic_dtype if args.input_backend == "synthetic-gpu" else None,
            "derived_root": input_state.get("derived_root"),
            "derived_image_size": input_state.get("derived_image_size"),
            "derived_samples_per_class": input_state.get("derived_samples_per_class"),
            "derived_seed": input_state.get("derived_seed"),
            "derived_format": input_state.get("derived_format"),
            "derived_storage_dtype": input_state.get("derived_storage_dtype"),
            "derived_storage_layout": input_state.get("derived_storage_layout"),
            "pin_memory": bool(args.pin_memory),
            "persistent_workers": bool(args.persistent_workers) if args.num_workers > 0 else False,
            "drop_last": bool(args.drop_last),
            "warmup_iters": args.warmup_iters,
            "measured_iters": args.measured_iters,
            "samples_total": samples_total,
            "elapsed_seconds": elapsed,
            "samples_per_second": samples_total / elapsed if elapsed > 0 else None,
            "step_mean_seconds": step_total / args.measured_iters,
            "data_wait_mean_seconds": data_wait_total / args.measured_iters,
            "h2d_mean_seconds": h2d_total / args.measured_iters,
            "input_prepare_mean_seconds": input_prepare_total / args.measured_iters,
            "train_mean_seconds": train_total / args.measured_iters,
            "precision": args.precision,
            "channels_last": bool(args.channels_last),
            "loss_last": last_loss,
            "torch_version": torch.__version__,
            "torchvision_version": torchvision_version,
            "python_version": platform.python_version(),
        }
        write_json(rank_path, row)
        dist.barrier()

        if rank == 0:
            rank_paths = [output_dir / f"rank-{idx}.json" for idx in range(world_size)]
            summary = aggregate_rank_metrics(rank_paths, args, rank, world_size)
            write_json(args.summary_output, summary)
            write_json(args.status_output, {
                "status": summary["status"],
                "pass_basis": "parsed.summary.status",
            })
        dist.barrier()
        dist.destroy_process_group()
        return 0
    except Exception as exc:  # pragma: no cover - exercised through Slurm/container runs
        traceback.print_exc(file=sys.stderr)
        write_json(rank_path, {
            "schema_version": 1,
            "status": "failed",
            "notes": str(exc),
            "rank": rank,
            "local_rank": local_rank,
            "world_size": world_size,
            "host": host,
            "launcher": args.launcher,
            "input_backend": args.input_backend,
        })
        try:
            import torch.distributed as dist
            if dist.is_available() and dist.is_initialized():
                dist.destroy_process_group()
        except Exception:
            pass
        return 1


if __name__ == "__main__":
    sys.exit(main())
