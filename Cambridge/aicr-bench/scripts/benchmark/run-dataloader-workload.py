#!/usr/bin/env python3
import argparse
import json
import os
import platform
import resource
import sys
import time
import traceback
from pathlib import Path

from dataloader_input_backends import (
    NumpyBlockDataset,
    NumpyBlockDatasetMetadata,
    NumpyFileDatasetMetadata,
    NumpyShardDataset,
    derived_metadata_fields,
    estimate_numpy_block_dataset_bytes,
    estimate_numpy_dataset_bytes,
    estimate_numpy_file_dataset_bytes,
    is_dali_numpy_backend,
    is_dali_numpy_block_backend,
    is_dali_numpy_file_backend,
    is_numpy_block_backend,
    is_numpy_backend,
    requires_derived_root,
    resolve_dali_numpy_block_root,
    resolve_dali_numpy_file_root,
    resolve_numpy_block_root,
    resolve_numpy_shard_root,
)


DALI_NUMPY_BLOCK_CPU_MAX_SAFE_FILE_BATCH = 4


def build_parser():
    parser = argparse.ArgumentParser(description="Run the v1 ImageNet dataloader benchmark.")
    parser.add_argument("--dataset-root", required=True, help="ImageNet root containing train/ and val/")
    parser.add_argument("--split", default="train", choices=["train", "val"])
    parser.add_argument(
        "--input-backend",
        default="pytorch-cpu-dataloader",
        choices=[
            "pytorch-cpu-dataloader",
            "dali-gpu-decode",
            "numpy-uint8-shards",
            "numpy-fp16-shards",
            "numpy-fp16-blocks-pytorch",
            "dali-numpy-fp16-cpu",
            "dali-numpy-fp16-gds",
            "dali-numpy-fp16-blocks-cpu",
            "dali-numpy-fp16-blocks-gds",
        ],
        help="Input path for DataLoader-only comparisons.",
    )
    parser.add_argument("--derived-root", default=os.environ.get("AICR_DATALOADER_DERIVED_ROOT"))
    parser.add_argument("--derived-image-size", type=int, default=224)
    parser.add_argument("--derived-samples-per-class", type=int, default=16)
    parser.add_argument("--derived-seed", type=int, default=1234)
    parser.add_argument("--batch-size", type=int, required=True)
    parser.add_argument("--num-workers", type=int, required=True)
    parser.add_argument("--prefetch-factor", type=int, required=True)
    parser.add_argument("--dali-num-threads", type=int, default=0)
    parser.add_argument("--dali-prefetch-queue-depth", type=int, default=2)
    parser.add_argument(
        "--dali-numpy-reader-prefetch-queue-depth",
        type=int,
        default=int(os.environ.get("DATALOADER_DALI_NUMPY_READER_PREFETCH_QUEUE_DEPTH", "1")),
        help="Reader-level prefetch queue depth for DALI NumPy file/block readers.",
    )
    parser.add_argument("--dali-decode-mode", default="random-crop", choices=["random-crop", "decode-resize"])
    parser.add_argument("--dali-hw-decoder-load", type=float, default=0.65)
    parser.add_argument(
        "--numpy-block-cache-size",
        type=int,
        default=int(os.environ.get("DATALOADER_NUMPY_BLOCK_CACHE_SIZE", "1")),
        help="Per-worker mmap block cache size for the PyTorch NumPy block backend.",
    )
    parser.add_argument(
        "--dali-gds-chunk-size",
        default=os.environ.get("DATALOADER_DALI_GDS_CHUNK_SIZE"),
        help="Optional DALI_GDS_CHUNK_SIZE override for DALI NumPy GDS reader experiments.",
    )
    parser.add_argument(
        "--cufile-log-path",
        default=os.environ.get("DATALOADER_CUFILE_LOG_PATH"),
        help="Optional cuFile log path for DALI NumPy GDS reader experiments.",
    )
    parser.add_argument(
        "--cufile-log-level",
        default=os.environ.get("DATALOADER_CUFILE_LOG_LEVEL"),
        help="Optional CUFILE_LOGGING_LEVEL value for DALI NumPy GDS reader experiments.",
    )
    parser.add_argument("--pin-memory", type=int, choices=[0, 1], required=True)
    parser.add_argument("--persistent-workers", type=int, choices=[0, 1], required=True)
    parser.add_argument("--warmup-batches", type=int, required=True)
    parser.add_argument("--measured-batches", type=int, required=True)
    parser.add_argument("--selected-gpu", default="0")
    parser.add_argument("--sampler-mode", default="single", choices=["single", "replicated", "distributed-sharded"])
    parser.add_argument("--rank", type=int, default=None)
    parser.add_argument("--world-size", type=int, default=None)
    parser.add_argument("--local-rank", type=int, default=None)
    parser.add_argument("--node-rank", type=int, default=None)
    parser.add_argument("--local-gpu-index", type=int, default=None)
    parser.add_argument("--node-list", default="")
    parser.add_argument("--node-count", type=int, default=None)
    parser.add_argument("--launcher", default="local")
    parser.add_argument("--epoch", type=int, default=0)
    parser.add_argument("--h2d", type=int, choices=[0, 1], default=1)
    parser.add_argument("--transfer-labels", type=int, choices=[0, 1], default=1)
    parser.add_argument("--drop-last", type=int, choices=[0, 1], default=0)
    parser.add_argument(
        "--byte-estimate-sample-count",
        type=int,
        default=1024,
        help="Number of ImageFolder paths to stat for estimated JPEG bytes/read bandwidth; 0 disables.",
    )
    parser.add_argument("--output", default=None)
    parser.add_argument("--output-dir", default=None)
    return parser


def nofile_provenance():
    soft = None
    hard = None
    try:
        soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
    except (OSError, ValueError):
        pass
    open_fd_count = None
    try:
        open_fd_count = len(list(Path("/proc/self/fd").iterdir()))
    except (OSError, FileNotFoundError):
        pass
    return {
        "nofile_requested": os.environ.get("DATALOADER_NOFILE_LIMIT"),
        "nofile_soft": soft,
        "nofile_hard": hard,
        "open_file_descriptor_count": open_fd_count,
    }


def transport_class_for_backend(input_backend):
    if input_backend in {"dali-numpy-fp16-gds", "dali-numpy-fp16-blocks-gds"}:
        return "gds-numpy-o-direct"
    if input_backend in {"dali-numpy-fp16-cpu", "dali-numpy-fp16-blocks-cpu"}:
        return "cpu-dali-numpy-reader"
    if input_backend == "numpy-fp16-blocks-pytorch":
        return "cpu-mmap-pytorch"
    if input_backend in {"numpy-uint8-shards", "numpy-fp16-shards"}:
        return "cpu-mmap-numpy-shard"
    if input_backend == "dali-gpu-decode":
        return "cpu-file-reader-dali-mixed-decode"
    if input_backend == "pytorch-cpu-dataloader":
        return "cpu-file-reader-pytorch"
    return None


def evidence_scope_for_backend(input_backend, metadata=None):
    metadata = metadata or {}
    if input_backend in {
        "numpy-fp16-blocks-pytorch",
        "dali-numpy-fp16-cpu",
        "dali-numpy-fp16-gds",
        "dali-numpy-fp16-blocks-cpu",
        "dali-numpy-fp16-blocks-gds",
    }:
        return {
            "study_class": "diagnostic",
            "representation_class": "prepared-tensor",
            "transport_class": transport_class_for_backend(input_backend),
            "canonical_imagenet": False,
            "derived_jpeg": False,
            "prepared_input_ceiling": False,
        }
    if input_backend == "numpy-fp16-shards":
        return {
            "study_class": "ceiling",
            "representation_class": "prepared-tensor",
            "transport_class": transport_class_for_backend(input_backend),
            "canonical_imagenet": False,
            "derived_jpeg": False,
            "prepared_input_ceiling": True,
        }
    if input_backend == "numpy-uint8-shards":
        return {
            "study_class": "ceiling",
            "representation_class": "prepared-array",
            "transport_class": transport_class_for_backend(input_backend),
            "canonical_imagenet": False,
            "derived_jpeg": False,
            "prepared_input_ceiling": True,
        }
    derived_jpeg = metadata.get("derived_format") == "jpeg"
    return {
        "study_class": "canonical" if input_backend in {"pytorch-cpu-dataloader", "dali-gpu-decode"} else None,
        "representation_class": "jpeg",
        "transport_class": transport_class_for_backend(input_backend),
        "canonical_imagenet": False if derived_jpeg else (
            True if input_backend in {"pytorch-cpu-dataloader", "dali-gpu-decode"} else None
        ),
        "derived_jpeg": bool(derived_jpeg),
        "prepared_input_ceiling": False,
    }


def validate_backend_safety_policy(args):
    if (
        args.input_backend == "dali-numpy-fp16-blocks-cpu"
        and args.batch_size > DALI_NUMPY_BLOCK_CPU_MAX_SAFE_FILE_BATCH
    ):
        raise ValueError(
            "dali-numpy-fp16-blocks-cpu with --batch-size > "
            f"{DALI_NUMPY_BLOCK_CPU_MAX_SAFE_FILE_BATCH} is excluded for "
            "prepared-tensor transport campaigns: job 28906 OOMed at DALI "
            "CPU NumPy block file-batch 8 on the 8-GPU full-node shape. Use "
            "--batch-size <= 4, numpy-fp16-blocks-pytorch, or "
            "dali-numpy-fp16-blocks-gds."
        )


def delivery_endpoint(input_backend, h2d_enabled):
    if input_backend == "numpy-fp16-blocks-pytorch":
        return "storage_to_host_mmap_then_gpu" if h2d_enabled else "storage_to_host_mmap"
    if input_backend == "dali-numpy-fp16-blocks-gds":
        return "dali_numpy_gpu_gds"
    if input_backend == "dali-numpy-fp16-blocks-cpu":
        return "dali_numpy_cpu_reader_then_gpu" if h2d_enabled else "dali_numpy_cpu_reader"
    if input_backend == "dali-numpy-fp16-gds":
        return "dali_numpy_gpu_gds"
    if input_backend == "dali-numpy-fp16-cpu":
        return "dali_numpy_cpu_reader_then_gpu" if h2d_enabled else "dali_numpy_cpu_reader"
    if input_backend in {"numpy-uint8-shards", "numpy-fp16-shards"}:
        return "storage_to_host_mmap_then_gpu" if h2d_enabled else "storage_to_host_mmap"
    if input_backend == "dali-gpu-decode":
        return "dali_jpeg_mixed_decode_gpu_output"
    if input_backend == "pytorch-cpu-dataloader":
        return "storage_to_host_then_gpu" if h2d_enabled else "storage_to_host"
    return None


def split_batch(batch):
    if isinstance(batch, dict):
        images = batch.get("images")
        labels = batch.get("labels")
        return images, labels
    if isinstance(batch, (list, tuple)) and batch:
        images = batch[0]
        labels = batch[1] if len(batch) > 1 else None
        return images, labels
    return batch, None


def batch_sample_count(batch, input_backend=None):
    images, _ = split_batch(batch)
    if hasattr(images, "shape") and images.shape:
        if is_dali_numpy_block_backend(input_backend) and len(images.shape) >= 2:
            return int(images.shape[0]) * int(images.shape[1])
        return int(images.shape[0])
    if hasattr(images, "__len__"):
        return int(len(images))
    raise TypeError(f"Unsupported batch type for sample counting: {type(batch)!r}")


def next_batch(loader, iterator):
    try:
        batch = next(iterator)
    except StopIteration:
        iterator = iter(loader)
        batch = next(iterator)
    return batch, iterator


def write_payload(path, payload):
    output_path = Path(path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def stat_process_ticks(pid):
    stat_path = Path("/proc") / str(pid) / "stat"
    try:
        text = stat_path.read_text(encoding="utf-8")
    except OSError:
        return None
    try:
        fields = text.rsplit(") ", 1)[1].split()
        return int(fields[11]) + int(fields[12])
    except (IndexError, ValueError):
        return None


def dataloader_worker_pids(iterator):
    workers = getattr(iterator, "_workers", None) or []
    pids = []
    for worker in workers:
        pid = getattr(worker, "pid", None)
        if pid:
            pids.append(int(pid))
    return pids


def sample_process_ticks(pids):
    samples = {}
    for pid in pids:
        ticks = stat_process_ticks(pid)
        if ticks is not None:
            samples[pid] = ticks
    return samples


def cpu_utilization_rows(before, after, elapsed_seconds):
    if elapsed_seconds <= 0:
        return []
    try:
        ticks_per_second = os.sysconf(os.sysconf_names["SC_CLK_TCK"])
    except (AttributeError, KeyError, ValueError, OSError):
        return []
    rows = []
    for pid, before_ticks in sorted(before.items()):
        after_ticks = after.get(pid)
        if after_ticks is None or after_ticks < before_ticks:
            continue
        cpu_seconds = (after_ticks - before_ticks) / ticks_per_second
        rows.append({
            "pid": pid,
            "cpu_seconds": cpu_seconds,
            "utilization_percent": (cpu_seconds / elapsed_seconds) * 100.0,
        })
    return rows


def estimate_dataset_bytes(dataset, sample_count):
    samples = getattr(dataset, "samples", None) or []
    total_count = len(samples)
    if sample_count <= 0 or total_count <= 0:
        return {
            "sample_count": 0,
            "sampled_bytes": None,
            "average_sample_bytes": None,
            "estimated_total_bytes": None,
            "missing_sample_count": 0,
        }
    target_count = min(sample_count, total_count)
    if target_count == total_count:
        indices = range(total_count)
    elif target_count == 1:
        indices = [0]
    else:
        indices = sorted({round(index * (total_count - 1) / (target_count - 1)) for index in range(target_count)})
    sampled_bytes = 0
    sampled_count = 0
    missing_count = 0
    for index in indices:
        try:
            sampled_bytes += Path(samples[index][0]).stat().st_size
            sampled_count += 1
        except OSError:
            missing_count += 1
    average_bytes = (sampled_bytes / sampled_count) if sampled_count else None
    return {
        "sample_count": sampled_count,
        "sampled_bytes": sampled_bytes if sampled_count else None,
        "average_sample_bytes": average_bytes,
        "estimated_total_bytes": average_bytes * total_count if average_bytes is not None else None,
        "missing_sample_count": missing_count,
    }


def build_torch_loader(args, split_root, rank, world_size):
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
    dataset_byte_estimate = estimate_dataset_bytes(dataset, args.byte_estimate_sample_count)
    derived_fields = derived_metadata_fields(split_root.parent)
    sampler = None
    shuffle = args.split == "train"
    if args.sampler_mode == "distributed-sharded":
        sampler = DistributedSampler(
            dataset,
            num_replicas=world_size,
            rank=rank,
            shuffle=shuffle,
            drop_last=bool(args.drop_last),
        )
        sampler.set_epoch(args.epoch)
        shuffle = False

    loader_kwargs = {
        "batch_size": args.batch_size,
        "shuffle": shuffle,
        "sampler": sampler,
        "num_workers": args.num_workers,
        "pin_memory": bool(args.pin_memory),
        "persistent_workers": bool(args.persistent_workers) if args.num_workers > 0 else False,
        "drop_last": bool(args.drop_last),
    }
    if args.num_workers > 0:
        loader_kwargs["prefetch_factor"] = args.prefetch_factor
    state = {
        "loader": DataLoader(dataset, **loader_kwargs),
        "dataset": dataset,
        "dataset_byte_estimate": dataset_byte_estimate,
        "sampler": sampler,
        "sampler_length": len(sampler) if sampler is not None else len(dataset),
        "shuffle": args.split == "train",
        "effective_shuffle": shuffle,
        "prefetch_factor": args.prefetch_factor if args.num_workers > 0 else None,
        "persistent_workers": bool(args.persistent_workers) if args.num_workers > 0 else False,
        "input_gpu_resident": False,
        "labels_gpu_resident": False,
        "transform_pipeline": [
            "RandomResizedCrop(224)",
            "RandomHorizontalFlip()",
            "ToTensor()",
            "Normalize(mean=(0.485,0.456,0.406), std=(0.229,0.224,0.225))",
        ],
    }
    if derived_fields:
        state.update(derived_fields)
        state["transform_pipeline"] = [
            "Pre-resized JPEG ImageFolder",
            derived_fields.get("transform_policy", ""),
            *state["transform_pipeline"],
        ]
    return state


def build_dali_loader(args, split_root, rank, world_size, local_gpu_index):
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
    dataset_byte_estimate = estimate_dataset_bytes(metadata, args.byte_estimate_sample_count)
    derived_fields = derived_metadata_fields(split_root.parent)
    dali_num_threads = args.dali_num_threads if args.dali_num_threads > 0 else max(1, args.num_workers)
    pipe = imagenet_pipeline(
        batch_size=args.batch_size,
        num_threads=dali_num_threads,
        device_id=local_gpu_index,
        seed=1234 + rank,
        prefetch_queue_depth=args.dali_prefetch_queue_depth,
        data_dir=str(split_root),
        shard_id=rank if args.sampler_mode == "distributed-sharded" else 0,
        num_shards=world_size if args.sampler_mode == "distributed-sharded" else 1,
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
        "dataset": metadata,
        "dataset_byte_estimate": dataset_byte_estimate,
        "sampler": None,
        "sampler_length": len(metadata) // world_size if world_size else None,
        "shuffle": args.split == "train",
        "effective_shuffle": args.split == "train",
        "prefetch_factor": None,
        "persistent_workers": None,
        "input_gpu_resident": True,
        "labels_gpu_resident": False,
        "dali_num_threads": dali_num_threads,
        "transform_pipeline": [
            f"DALI {args.dali_decode_mode}",
            "Resize/CropMirrorNormalize(CHW,float,224)",
        ],
    }
    if derived_fields:
        state.update(derived_fields)
        state["transform_pipeline"] = [
            "Pre-resized JPEG ImageFolder",
            derived_fields.get("transform_policy", ""),
            *state["transform_pipeline"],
        ]
    return state


def configure_dali_gds_environment(args, use_o_direct, rank):
    if args.dali_gds_chunk_size:
        os.environ["DALI_GDS_CHUNK_SIZE"] = str(args.dali_gds_chunk_size)
    if use_o_direct and args.cufile_log_path:
        log_path = Path(str(args.cufile_log_path).replace("{rank}", str(rank)))
        log_path.parent.mkdir(parents=True, exist_ok=True)
        os.environ["CUFILE_LOGFILE_PATH"] = str(log_path)
        os.environ["CUFILE_LOGGING_LEVEL"] = str(args.cufile_log_level or "INFO")
        os.environ["CUFILE_LOG_LEVEL"] = os.environ["CUFILE_LOGGING_LEVEL"]
        args.cufile_log_path = str(log_path)
        args.cufile_log_level = os.environ["CUFILE_LOGGING_LEVEL"]


def build_dali_numpy_file_loader(args, rank, world_size, local_gpu_index):
    use_o_direct = args.input_backend == "dali-numpy-fp16-gds"
    configure_dali_gds_environment(args, use_o_direct, rank)

    try:
        from nvidia.dali import fn
        from nvidia.dali.pipeline import pipeline_def
        from nvidia.dali.plugin.pytorch import DALIGenericIterator, LastBatchPolicy
    except ImportError as exc:
        raise RuntimeError("DALI NumPy input backend requested, but nvidia.dali is not available in the runtime image") from exc

    dataset_root = resolve_dali_numpy_file_root(args)
    metadata = NumpyFileDatasetMetadata(dataset_root, args.input_backend)
    dataset_byte_estimate = estimate_numpy_file_dataset_bytes(metadata)
    reader_device = "gpu" if args.input_backend == "dali-numpy-fp16-gds" else "cpu"

    @pipeline_def
    def numpy_file_pipeline(sample_root, shard_id, num_shards, random_shuffle):
        images = fn.readers.numpy(
            device=reader_device,
            file_root=sample_root,
            shard_id=shard_id,
            num_shards=num_shards,
            random_shuffle=random_shuffle,
            dont_use_mmap=True,
            use_o_direct=use_o_direct,
            prefetch_queue_depth=args.dali_numpy_reader_prefetch_queue_depth,
            name="reader",
        )
        return images

    dali_num_threads = args.dali_num_threads if args.dali_num_threads > 0 else max(1, args.num_workers)
    pipe = numpy_file_pipeline(
        batch_size=args.batch_size,
        num_threads=dali_num_threads,
        device_id=local_gpu_index,
        seed=1234 + rank,
        prefetch_queue_depth=args.dali_prefetch_queue_depth,
        sample_root=str(metadata.sample_root),
        shard_id=rank if args.sampler_mode == "distributed-sharded" else 0,
        num_shards=world_size if args.sampler_mode == "distributed-sharded" else 1,
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
    return {
        "loader": loader,
        "dataset": metadata,
        "dataset_byte_estimate": dataset_byte_estimate,
        "sampler": None,
        "sampler_length": len(metadata) // world_size if world_size else None,
        "shuffle": args.split == "train",
        "effective_shuffle": args.split == "train",
        "prefetch_factor": None,
        "persistent_workers": None,
        "input_gpu_resident": reader_device == "gpu",
        "labels_gpu_resident": None,
        "dali_num_threads": dali_num_threads,
        "dali_reader_device": reader_device,
        "dali_numpy_use_o_direct": use_o_direct,
        "dali_numpy_reader_prefetch_queue_depth": args.dali_numpy_reader_prefetch_queue_depth,
        "dali_gds_chunk_size": args.dali_gds_chunk_size,
        "cufile_log_path": args.cufile_log_path if use_o_direct else None,
        "cufile_log_level": args.cufile_log_level if use_o_direct else None,
        "gds_requested": use_o_direct,
        "storage_transport_path": "dali-numpy-gpu-gds" if use_o_direct else "dali-numpy-cpu-reader",
        "dataset_file_count": dataset_byte_estimate["dataset_file_count"],
        "dataset_total_bytes": dataset_byte_estimate["dataset_total_bytes"],
        "derived_root": str(dataset_root),
        "derived_image_size": metadata.image_size,
        "derived_samples_per_class": metadata.metadata.get("samples_per_class"),
        "derived_seed": metadata.metadata.get("seed"),
        "derived_format": metadata.format,
        "derived_storage_dtype": metadata.storage_dtype,
        "derived_storage_layout": metadata.storage_layout,
        "derived_source_policy": metadata.metadata.get("source_policy"),
        "derived_jpeg_quality": metadata.metadata.get("jpeg_quality"),
        "transform_pipeline": [
            f"DALI NumPy reader device={reader_device}",
            metadata.transform_policy,
        ],
    }


def build_dali_numpy_block_loader(args, rank, world_size, local_gpu_index):
    use_o_direct = args.input_backend == "dali-numpy-fp16-blocks-gds"
    configure_dali_gds_environment(args, use_o_direct, rank)

    try:
        from nvidia.dali import fn
        from nvidia.dali.pipeline import pipeline_def
        from nvidia.dali.plugin.pytorch import DALIGenericIterator, LastBatchPolicy
    except ImportError as exc:
        raise RuntimeError("DALI NumPy block input backend requested, but nvidia.dali is not available in the runtime image") from exc

    dataset_root = resolve_dali_numpy_block_root(args)
    metadata = NumpyBlockDatasetMetadata(dataset_root, args.input_backend)
    dataset_byte_estimate = estimate_numpy_block_dataset_bytes(metadata)
    reader_device = "gpu" if use_o_direct else "cpu"

    @pipeline_def
    def numpy_block_pipeline(block_root, shard_id, num_shards, random_shuffle):
        images = fn.readers.numpy(
            device=reader_device,
            file_root=block_root,
            shard_id=shard_id,
            num_shards=num_shards,
            random_shuffle=random_shuffle,
            dont_use_mmap=True,
            use_o_direct=use_o_direct,
            prefetch_queue_depth=args.dali_numpy_reader_prefetch_queue_depth,
            name="reader",
        )
        return images

    dali_num_threads = args.dali_num_threads if args.dali_num_threads > 0 else max(1, args.num_workers)
    pipe = numpy_block_pipeline(
        batch_size=args.batch_size,
        num_threads=dali_num_threads,
        device_id=local_gpu_index,
        seed=1234 + rank,
        prefetch_queue_depth=args.dali_prefetch_queue_depth,
        block_root=str(metadata.block_root),
        shard_id=rank if args.sampler_mode == "distributed-sharded" else 0,
        num_shards=world_size if args.sampler_mode == "distributed-sharded" else 1,
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
    return {
        "loader": loader,
        "dataset": metadata,
        "dataset_byte_estimate": dataset_byte_estimate,
        "sampler": None,
        "sampler_length": metadata.block_count // world_size if world_size else None,
        "shuffle": args.split == "train",
        "effective_shuffle": args.split == "train",
        "prefetch_factor": None,
        "persistent_workers": None,
        "input_gpu_resident": reader_device == "gpu",
        "labels_gpu_resident": None,
        "dali_num_threads": dali_num_threads,
        "dali_reader_device": reader_device,
        "dali_numpy_use_o_direct": use_o_direct,
        "dali_numpy_reader_prefetch_queue_depth": args.dali_numpy_reader_prefetch_queue_depth,
        "dali_gds_chunk_size": args.dali_gds_chunk_size,
        "cufile_log_path": args.cufile_log_path if use_o_direct else None,
        "cufile_log_level": args.cufile_log_level if use_o_direct else None,
        "gds_requested": use_o_direct,
        "storage_transport_path": "dali-numpy-block-gpu-gds" if use_o_direct else "dali-numpy-block-cpu-reader",
        "dataset_file_count": dataset_byte_estimate["dataset_file_count"],
        "dataset_block_count": dataset_byte_estimate["dataset_block_count"],
        "dataset_total_bytes": dataset_byte_estimate["dataset_total_bytes"],
        "logical_sample_count": dataset_byte_estimate["logical_sample_count"],
        "numpy_block_size": metadata.block_size,
        "derived_root": str(dataset_root),
        "derived_image_size": metadata.image_size,
        "derived_samples_per_class": metadata.metadata.get("samples_per_class"),
        "derived_seed": metadata.metadata.get("seed"),
        "derived_format": metadata.format,
        "derived_storage_dtype": metadata.storage_dtype,
        "derived_storage_layout": metadata.storage_layout,
        "derived_source_policy": metadata.metadata.get("source_policy"),
        "derived_jpeg_quality": metadata.metadata.get("jpeg_quality"),
        "transform_pipeline": [
            f"DALI blocked NumPy reader device={reader_device}",
            metadata.transform_policy,
        ],
    }


def build_numpy_loader(args, rank, world_size):
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
    sampler = None
    shuffle = args.split == "train"
    if args.sampler_mode == "distributed-sharded":
        sampler = DistributedSampler(
            dataset,
            num_replicas=world_size,
            rank=rank,
            shuffle=shuffle,
            drop_last=bool(args.drop_last),
        )
        sampler.set_epoch(args.epoch)
        shuffle = False
    loader_kwargs = {
        "batch_size": args.batch_size,
        "shuffle": shuffle,
        "sampler": sampler,
        "num_workers": args.num_workers,
        "pin_memory": bool(args.pin_memory),
        "persistent_workers": bool(args.persistent_workers) if args.num_workers > 0 else False,
        "drop_last": bool(args.drop_last),
    }
    if args.num_workers > 0:
        loader_kwargs["prefetch_factor"] = args.prefetch_factor
    return {
        "loader": DataLoader(dataset, **loader_kwargs),
        "dataset": dataset,
        "dataset_byte_estimate": dataset_byte_estimate,
        "sampler": sampler,
        "sampler_length": len(sampler) if sampler is not None else len(dataset),
        "shuffle": args.split == "train",
        "effective_shuffle": shuffle,
        "prefetch_factor": args.prefetch_factor if args.num_workers > 0 else None,
        "persistent_workers": bool(args.persistent_workers) if args.num_workers > 0 else False,
        "input_gpu_resident": False,
        "labels_gpu_resident": False,
        "gds_requested": False,
        "dali_reader_device": None,
        "dali_numpy_use_o_direct": None,
        "dali_numpy_reader_prefetch_queue_depth": None,
        "dali_gds_chunk_size": None,
        "cufile_log_path": None,
        "cufile_log_level": None,
        "storage_transport_path": storage_transport_path,
        "dataset_file_count": dataset_byte_estimate.get("dataset_file_count"),
        "dataset_block_count": dataset_byte_estimate.get("dataset_block_count"),
        "dataset_total_bytes": dataset_byte_estimate.get("dataset_total_bytes"),
        "logical_sample_count": dataset_byte_estimate.get("logical_sample_count", len(dataset)),
        "numpy_block_size": getattr(dataset, "block_size", None),
        "numpy_block_cache_size": getattr(dataset, "block_cache_size", None),
        "derived_root": str(dataset_root),
        "derived_image_size": dataset.image_size,
        "derived_samples_per_class": dataset.metadata.get("samples_per_class"),
        "derived_seed": dataset.metadata.get("seed"),
        "derived_format": dataset.format,
        "derived_storage_dtype": dataset.storage_dtype,
        "derived_storage_layout": dataset.storage_layout,
        "transform_pipeline": [
            f"NumPy {dataset.format}",
            dataset.transform_policy,
        ],
    }


def next_input_batch(input_state, input_backend):
    if input_backend == "dali-gpu-decode" or is_dali_numpy_backend(input_backend):
        try:
            return next(input_state["iterator"])[0]
        except StopIteration:
            input_state["iterator"] = iter(input_state["loader"])
            return next(input_state["iterator"])[0]
    batch, iterator = next_batch(input_state["loader"], input_state["iterator"])
    input_state["iterator"] = iterator
    return batch


def env_int(name, default=None):
    value = os.environ.get(name)
    if value is None or value == "":
        return default
    return int(value)


def configure_rank_metadata(args):
    selected_gpu = int(args.selected_gpu)
    rank = args.rank if args.rank is not None else env_int("RANK", env_int("SLURM_PROCID", 0))
    world_size = args.world_size if args.world_size is not None else env_int("WORLD_SIZE", env_int("SLURM_NTASKS", 1))
    local_rank = args.local_rank if args.local_rank is not None else env_int("LOCAL_RANK", env_int("SLURM_LOCALID", selected_gpu))
    local_world_size = env_int("LOCAL_WORLD_SIZE", env_int("SLURM_NTASKS_PER_NODE", None))
    node_rank = args.node_rank
    if node_rank is None:
        node_rank = env_int("GROUP_RANK", env_int("SLURM_NODEID", None))
    if node_rank is None and local_world_size:
        node_rank = rank // local_world_size
    if node_rank is None:
        node_rank = 0
    local_gpu_index = args.local_gpu_index if args.local_gpu_index is not None else local_rank
    node_count = args.node_count if args.node_count is not None else env_int("SLURM_NNODES", None)
    if node_count is None and local_world_size:
        node_count = max(1, world_size // local_world_size)
    if node_count is None:
        node_count = 1
    return rank, world_size, local_rank, node_rank, local_gpu_index, node_count


def main():
    args = build_parser().parse_args()
    if args.dali_numpy_reader_prefetch_queue_depth <= 0:
        raise SystemExit("--dali-numpy-reader-prefetch-queue-depth must be a positive integer")
    if args.numpy_block_cache_size <= 0:
        raise SystemExit("--numpy-block-cache-size must be a positive integer")
    rank, world_size, local_rank, node_rank, local_gpu_index, node_count = configure_rank_metadata(args)
    if args.output:
        output_path = Path(args.output)
    elif args.output_dir:
        output_path = Path(args.output_dir) / f"rank-{rank}" / "dataloader-metrics.json"
    else:
        raise SystemExit("--output or --output-dir is required")
    dataset_root = Path(args.dataset_root)
    split_root = dataset_root / args.split

    try:
        validate_backend_safety_policy(args)

        import torch
        from torchvision import __version__ as torchvision_version

        if not dataset_root.is_dir() and not requires_derived_root(args.input_backend):
            raise FileNotFoundError(f"dataset root not found: {dataset_root}")
        if not requires_derived_root(args.input_backend) and not split_root.is_dir():
            raise FileNotFoundError(f"missing requested split directory: {split_root}")
        if world_size < 1:
            raise ValueError("--world-size must be positive")
        if rank < 0 or rank >= world_size:
            raise ValueError("--rank must be in [0, world_size)")

        selected_gpu = int(args.selected_gpu)
        cuda_available = bool(torch.cuda.is_available())
        visible_gpu_count = int(torch.cuda.device_count())
        h2d_enabled = bool(args.h2d and cuda_available and visible_gpu_count > 0)
        logical_gpu_index = local_gpu_index if local_gpu_index < visible_gpu_count else 0
        device = torch.device("cuda", logical_gpu_index) if h2d_enabled else torch.device("cpu")
        if h2d_enabled:
            torch.cuda.set_device(device)

        if args.input_backend == "dali-gpu-decode":
            if not cuda_available or visible_gpu_count <= 0:
                raise RuntimeError("DALI GPU decode requires CUDA-visible GPUs")
            input_state = build_dali_loader(args, split_root, rank, world_size, logical_gpu_index)
        elif is_dali_numpy_block_backend(args.input_backend):
            if not cuda_available or visible_gpu_count <= 0:
                raise RuntimeError("DALI NumPy block backends require CUDA-visible GPUs")
            input_state = build_dali_numpy_block_loader(args, rank, world_size, logical_gpu_index)
        elif is_dali_numpy_file_backend(args.input_backend):
            if not cuda_available or visible_gpu_count <= 0:
                raise RuntimeError("DALI NumPy backends require CUDA-visible GPUs")
            input_state = build_dali_numpy_file_loader(args, rank, world_size, logical_gpu_index)
        elif is_numpy_backend(args.input_backend):
            input_state = build_numpy_loader(args, rank, world_size)
        else:
            input_state = build_torch_loader(args, split_root, rank, world_size)
        input_state["iterator"] = iter(input_state["loader"])
        dataset = input_state["dataset"]
        dataset_byte_estimate = input_state["dataset_byte_estimate"]

        def transfer_batch(batch):
            images, labels = split_batch(batch)
            if not h2d_enabled:
                return images, labels
            if hasattr(images, "device") and images.device.type != "cuda":
                images = images.to(device, non_blocking=bool(args.pin_memory))
            if labels is not None and args.transfer_labels and hasattr(labels, "device") and labels.device.type != "cuda":
                labels = labels.to(device, non_blocking=bool(args.pin_memory))
            torch.cuda.synchronize(device)
            return images, labels

        for _ in range(args.warmup_batches):
            batch = next_input_batch(input_state, args.input_backend)
            transfer_batch(batch)

        if h2d_enabled:
            torch.cuda.synchronize(device)

        samples_total = 0
        load_elapsed_seconds = 0.0
        h2d_elapsed_seconds = 0.0
        worker_pids = dataloader_worker_pids(input_state["iterator"])
        worker_ticks_before = sample_process_ticks(worker_pids)
        total_started = time.perf_counter()
        for _ in range(args.measured_batches):
            load_started = time.perf_counter()
            batch = next_input_batch(input_state, args.input_backend)
            load_elapsed_seconds += time.perf_counter() - load_started
            samples_total += batch_sample_count(batch, args.input_backend)

            h2d_started = time.perf_counter()
            transfer_batch(batch)
            h2d_elapsed_seconds += time.perf_counter() - h2d_started

        if h2d_enabled:
            torch.cuda.synchronize(device)
        total_elapsed_seconds = time.perf_counter() - total_started
        worker_ticks_after = sample_process_ticks(worker_pids)
        worker_cpu_rows = cpu_utilization_rows(worker_ticks_before, worker_ticks_after, total_elapsed_seconds)

        if total_elapsed_seconds <= 0:
            raise RuntimeError("elapsed measurement time was not positive")

        scope_fields = evidence_scope_for_backend(args.input_backend, input_state)
        sampler_length = input_state["sampler_length"]
        average_sample_bytes = dataset_byte_estimate["average_sample_bytes"]
        estimated_read_bytes = average_sample_bytes * samples_total if average_sample_bytes is not None else None
        estimated_vast_read_gb_per_second = (
            estimated_read_bytes / total_elapsed_seconds / 1_000_000_000
            if estimated_read_bytes is not None
            else None
        )
        worker_util_values = [row["utilization_percent"] for row in worker_cpu_rows]
        payload = {
            "status": "passed",
            "notes": "",
            "dataset_root": str(dataset_root),
            "dataset_split": args.split,
            "dataset_split_root": str(split_root),
            "dataset_size": len(dataset),
            "class_count": len(getattr(dataset, "classes", []) or []),
            "input_backend": args.input_backend,
            "study_class": scope_fields["study_class"],
            "representation_class": scope_fields["representation_class"],
            "transport_class": scope_fields["transport_class"],
            "canonical_imagenet": scope_fields["canonical_imagenet"],
            "derived_jpeg": scope_fields["derived_jpeg"],
            "prepared_input_ceiling": scope_fields["prepared_input_ceiling"],
            "input_delivery_endpoint": delivery_endpoint(args.input_backend, h2d_enabled),
            "input_gpu_resident": bool(input_state["input_gpu_resident"]),
            "labels_gpu_resident": bool(input_state["labels_gpu_resident"]),
            "derived_root": input_state.get("derived_root"),
            "derived_image_size": input_state.get("derived_image_size"),
            "derived_samples_per_class": input_state.get("derived_samples_per_class"),
            "derived_seed": input_state.get("derived_seed"),
            "derived_format": input_state.get("derived_format"),
            "derived_storage_dtype": input_state.get("derived_storage_dtype"),
            "derived_storage_layout": input_state.get("derived_storage_layout"),
            "derived_source_policy": input_state.get("derived_source_policy"),
            "derived_jpeg_quality": input_state.get("derived_jpeg_quality"),
            "gds_requested": input_state.get("gds_requested"),
            "dali_reader_device": input_state.get("dali_reader_device"),
            "dali_numpy_use_o_direct": input_state.get("dali_numpy_use_o_direct"),
            "dali_numpy_reader_prefetch_queue_depth": input_state.get("dali_numpy_reader_prefetch_queue_depth"),
            "dali_gds_chunk_size": input_state.get("dali_gds_chunk_size"),
            "cufile_log_path": input_state.get("cufile_log_path"),
            "cufile_log_level": input_state.get("cufile_log_level"),
            "storage_transport_path": input_state.get("storage_transport_path"),
            "dataset_file_count": input_state.get("dataset_file_count"),
            "dataset_block_count": input_state.get("dataset_block_count"),
            "dataset_total_bytes": input_state.get("dataset_total_bytes"),
            "logical_sample_count": input_state.get("logical_sample_count", len(dataset)),
            "numpy_block_size": input_state.get("numpy_block_size"),
            "numpy_block_cache_size": input_state.get("numpy_block_cache_size"),
            "sampler_mode": args.sampler_mode,
            "rank": rank,
            "world_size": world_size,
            "local_rank": local_rank,
            "node_rank": node_rank,
            "local_gpu_index": local_gpu_index,
            "node_list": args.node_list,
            "node_count": node_count,
            "launcher": args.launcher,
            "sampler_length": sampler_length,
            "sampler_epoch": args.epoch,
            "drop_last": bool(args.drop_last),
            "batch_size": args.batch_size,
            "num_workers": args.num_workers,
            "prefetch_factor": input_state["prefetch_factor"],
            "dali_num_threads": input_state.get("dali_num_threads") if args.input_backend == "dali-gpu-decode" or is_dali_numpy_backend(args.input_backend) else None,
            "dali_prefetch_queue_depth": args.dali_prefetch_queue_depth if args.input_backend == "dali-gpu-decode" or is_dali_numpy_backend(args.input_backend) else None,
            "dali_decode_mode": args.dali_decode_mode if args.input_backend == "dali-gpu-decode" else None,
            "dali_hw_decoder_load": args.dali_hw_decoder_load if args.input_backend == "dali-gpu-decode" else None,
            "pin_memory": bool(args.pin_memory) if args.input_backend != "dali-gpu-decode" and not is_dali_numpy_backend(args.input_backend) else None,
            "persistent_workers": input_state["persistent_workers"],
            "shuffle": input_state["shuffle"],
            "effective_shuffle": input_state["effective_shuffle"],
            "warmup_batches": args.warmup_batches,
            "measured_batches": args.measured_batches,
            "samples_total": samples_total,
            "elapsed_seconds": total_elapsed_seconds,
            "total_elapsed_seconds": total_elapsed_seconds,
            "load_elapsed_seconds": load_elapsed_seconds,
            "h2d_elapsed_seconds": h2d_elapsed_seconds,
            "samples_per_second": samples_total / total_elapsed_seconds,
            "load_samples_per_second": samples_total / load_elapsed_seconds if load_elapsed_seconds > 0 else None,
            "h2d_samples_per_second": samples_total / h2d_elapsed_seconds if h2d_elapsed_seconds > 0 else None,
            "byte_estimate_sample_count": args.byte_estimate_sample_count,
            "dataset_byte_estimate_sample_count": dataset_byte_estimate["sample_count"],
            "dataset_byte_estimate_missing_sample_count": dataset_byte_estimate["missing_sample_count"],
            "dataset_sampled_bytes": dataset_byte_estimate["sampled_bytes"],
            "dataset_average_sample_bytes": average_sample_bytes,
            "dataset_estimated_total_bytes": dataset_byte_estimate["estimated_total_bytes"],
            "estimated_read_bytes": estimated_read_bytes,
            "estimated_vast_read_gb_per_second": estimated_vast_read_gb_per_second,
            "worker_pids": worker_pids,
            "worker_cpu_utilization": worker_cpu_rows,
            "worker_cpu_utilization_sample_count": len(worker_cpu_rows),
            "worker_cpu_utilization_mean_percent": (sum(worker_util_values) / len(worker_util_values)) if worker_util_values else None,
            "worker_cpu_utilization_max_percent": max(worker_util_values) if worker_util_values else None,
            "worker_cpu_utilization_total_percent": sum(worker_util_values) if worker_util_values else None,
            "selected_gpu": args.selected_gpu,
            "logical_gpu_index": logical_gpu_index if h2d_enabled else None,
            "h2d_enabled": h2d_enabled,
            "transfer_labels": bool(args.transfer_labels),
            "cuda_available": cuda_available,
            "visible_gpu_count": visible_gpu_count,
            "torch_version": torch.__version__,
            "torchvision_version": torchvision_version,
            "python_version": platform.python_version(),
            "transform_pipeline": input_state["transform_pipeline"],
        }
        payload.update(nofile_provenance())
        write_payload(output_path, payload)
        return 0
    except Exception as exc:  # pragma: no cover - exercised through shell runner
        traceback.print_exc(file=sys.stderr)
        failure_derived_fields = {}
        if not requires_derived_root(args.input_backend):
            try:
                failure_derived_fields = derived_metadata_fields(Path(args.dataset_root))
            except Exception:
                failure_derived_fields = {}
        failure_scope_fields = evidence_scope_for_backend(args.input_backend, failure_derived_fields)
        payload = {
            "status": "failed",
            "notes": str(exc),
            "dataset_root": str(dataset_root),
            "dataset_split": args.split,
            "dataset_split_root": str(split_root),
            "input_backend": args.input_backend,
            "study_class": failure_scope_fields["study_class"],
            "representation_class": failure_scope_fields["representation_class"],
            "transport_class": failure_scope_fields["transport_class"],
            "canonical_imagenet": failure_scope_fields["canonical_imagenet"],
            "derived_jpeg": failure_scope_fields["derived_jpeg"],
            "prepared_input_ceiling": failure_scope_fields["prepared_input_ceiling"],
            "input_delivery_endpoint": delivery_endpoint(args.input_backend, bool(args.h2d)),
            "sampler_mode": args.sampler_mode,
            "rank": rank,
            "world_size": world_size,
            "local_rank": local_rank,
            "node_rank": node_rank,
            "local_gpu_index": local_gpu_index,
            "node_list": args.node_list,
            "node_count": node_count,
            "launcher": args.launcher,
            "batch_size": args.batch_size,
            "num_workers": args.num_workers,
            "prefetch_factor": args.prefetch_factor,
            "dali_num_threads": args.dali_num_threads if args.input_backend == "dali-gpu-decode" or is_dali_numpy_backend(args.input_backend) else None,
            "dali_prefetch_queue_depth": args.dali_prefetch_queue_depth if args.input_backend == "dali-gpu-decode" or is_dali_numpy_backend(args.input_backend) else None,
            "dali_decode_mode": args.dali_decode_mode if args.input_backend == "dali-gpu-decode" else None,
            "dali_hw_decoder_load": args.dali_hw_decoder_load if args.input_backend == "dali-gpu-decode" else None,
            "pin_memory": bool(args.pin_memory),
            "persistent_workers": bool(args.persistent_workers),
            "derived_root": args.derived_root if requires_derived_root(args.input_backend) else failure_derived_fields.get("derived_root"),
            "derived_image_size": args.derived_image_size if requires_derived_root(args.input_backend) else failure_derived_fields.get("derived_image_size"),
            "derived_samples_per_class": args.derived_samples_per_class if requires_derived_root(args.input_backend) else failure_derived_fields.get("derived_samples_per_class"),
            "derived_seed": args.derived_seed if requires_derived_root(args.input_backend) else failure_derived_fields.get("derived_seed"),
            "derived_format": failure_derived_fields.get("derived_format"),
            "derived_storage_dtype": failure_derived_fields.get("derived_storage_dtype"),
            "derived_storage_layout": failure_derived_fields.get("derived_storage_layout"),
            "gds_requested": args.input_backend in {"dali-numpy-fp16-gds", "dali-numpy-fp16-blocks-gds"},
            "dali_reader_device": (
                "gpu"
                if args.input_backend in {"dali-numpy-fp16-gds", "dali-numpy-fp16-blocks-gds"}
                else ("cpu" if args.input_backend in {"dali-numpy-fp16-cpu", "dali-numpy-fp16-blocks-cpu"} else None)
            ),
            "dali_numpy_use_o_direct": (
                args.input_backend in {"dali-numpy-fp16-gds", "dali-numpy-fp16-blocks-gds"}
                if is_dali_numpy_backend(args.input_backend)
                else None
            ),
            "dali_numpy_reader_prefetch_queue_depth": (
                args.dali_numpy_reader_prefetch_queue_depth if is_dali_numpy_backend(args.input_backend) else None
            ),
            "dali_gds_chunk_size": args.dali_gds_chunk_size if is_dali_numpy_backend(args.input_backend) else None,
            "cufile_log_path": args.cufile_log_path if args.input_backend in {"dali-numpy-fp16-gds", "dali-numpy-fp16-blocks-gds"} else None,
            "cufile_log_level": args.cufile_log_level if args.input_backend in {"dali-numpy-fp16-gds", "dali-numpy-fp16-blocks-gds"} else None,
            "storage_transport_path": (
                "dali-numpy-gpu-gds"
                if args.input_backend == "dali-numpy-fp16-gds"
                else (
                    "dali-numpy-block-gpu-gds"
                    if args.input_backend == "dali-numpy-fp16-blocks-gds"
                    else (
                        "dali-numpy-cpu-reader"
                        if args.input_backend == "dali-numpy-fp16-cpu"
                        else (
                            "dali-numpy-block-cpu-reader"
                            if args.input_backend == "dali-numpy-fp16-blocks-cpu"
                            else (
                                "pytorch-numpy-block-cpu-mmap"
                                if args.input_backend == "numpy-fp16-blocks-pytorch"
                                else None
                            )
                        )
                    )
                )
            ),
            "dataset_file_count": None,
            "dataset_block_count": None,
            "dataset_total_bytes": None,
            "logical_sample_count": None,
            "numpy_block_size": None,
            "numpy_block_cache_size": args.numpy_block_cache_size if args.input_backend == "numpy-fp16-blocks-pytorch" else None,
            "derived_source_policy": failure_derived_fields.get("derived_source_policy"),
            "derived_jpeg_quality": failure_derived_fields.get("derived_jpeg_quality"),
            "warmup_batches": args.warmup_batches,
            "measured_batches": args.measured_batches,
            "selected_gpu": args.selected_gpu,
            "h2d_enabled": bool(args.h2d),
        }
        payload.update(nofile_provenance())
        write_payload(output_path, payload)
        return 1


if __name__ == "__main__":
    sys.exit(main())
