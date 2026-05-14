#!/usr/bin/env python3
import argparse
import json
import os
import platform
import sys
import time
import traceback
from pathlib import Path


def build_parser():
    parser = argparse.ArgumentParser(description="Run the v1 ImageNet dataloader benchmark.")
    parser.add_argument("--dataset-root", required=True, help="ImageNet root containing train/ and val/")
    parser.add_argument("--split", default="train", choices=["train", "val"])
    parser.add_argument("--batch-size", type=int, required=True)
    parser.add_argument("--num-workers", type=int, required=True)
    parser.add_argument("--prefetch-factor", type=int, required=True)
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


def split_batch(batch):
    if isinstance(batch, (list, tuple)) and batch:
        images = batch[0]
        labels = batch[1] if len(batch) > 1 else None
        return images, labels
    return batch, None


def batch_sample_count(batch):
    images, _ = split_batch(batch)
    if hasattr(images, "shape") and images.shape:
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
        import torch
        from torch.utils.data import DataLoader
        from torch.utils.data.distributed import DistributedSampler
        from torchvision import __version__ as torchvision_version
        from torchvision import datasets, transforms

        if not dataset_root.is_dir():
            raise FileNotFoundError(f"dataset root not found: {dataset_root}")
        if not (dataset_root / "train").is_dir():
            raise FileNotFoundError(f"missing train split under dataset root: {dataset_root / 'train'}")
        if not (dataset_root / "val").is_dir():
            raise FileNotFoundError(f"missing val split under dataset root: {dataset_root / 'val'}")
        if not split_root.is_dir():
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

        transform = transforms.Compose([
            transforms.RandomResizedCrop(224),
            transforms.RandomHorizontalFlip(),
            transforms.ToTensor(),
            transforms.Normalize(mean=(0.485, 0.456, 0.406), std=(0.229, 0.224, 0.225)),
        ])

        dataset = datasets.ImageFolder(str(split_root), transform=transform)
        dataset_byte_estimate = estimate_dataset_bytes(dataset, args.byte_estimate_sample_count)
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
        loader = DataLoader(dataset, **loader_kwargs)
        iterator = iter(loader)

        def transfer_batch(batch):
            images, labels = split_batch(batch)
            if not h2d_enabled:
                return images, labels
            images = images.to(device, non_blocking=bool(args.pin_memory))
            if labels is not None and args.transfer_labels:
                labels = labels.to(device, non_blocking=bool(args.pin_memory))
            torch.cuda.synchronize(device)
            return images, labels

        for _ in range(args.warmup_batches):
            batch, iterator = next_batch(loader, iterator)
            transfer_batch(batch)

        if h2d_enabled:
            torch.cuda.synchronize(device)

        samples_total = 0
        load_elapsed_seconds = 0.0
        h2d_elapsed_seconds = 0.0
        worker_pids = dataloader_worker_pids(iterator)
        worker_ticks_before = sample_process_ticks(worker_pids)
        total_started = time.perf_counter()
        for _ in range(args.measured_batches):
            load_started = time.perf_counter()
            batch, iterator = next_batch(loader, iterator)
            load_elapsed_seconds += time.perf_counter() - load_started
            samples_total += batch_sample_count(batch)

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

        sampler_length = len(sampler) if sampler is not None else len(dataset)
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
            "prefetch_factor": args.prefetch_factor if args.num_workers > 0 else None,
            "pin_memory": bool(args.pin_memory),
            "persistent_workers": bool(args.persistent_workers) if args.num_workers > 0 else False,
            "shuffle": args.split == "train",
            "effective_shuffle": shuffle,
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
            "transform_pipeline": [
                "RandomResizedCrop(224)",
                "RandomHorizontalFlip()",
                "ToTensor()",
                "Normalize(mean=(0.485,0.456,0.406), std=(0.229,0.224,0.225))",
            ],
        }
        write_payload(output_path, payload)
        return 0
    except Exception as exc:  # pragma: no cover - exercised through shell runner
        traceback.print_exc(file=sys.stderr)
        payload = {
            "status": "failed",
            "notes": str(exc),
            "dataset_root": str(dataset_root),
            "dataset_split": args.split,
            "dataset_split_root": str(split_root),
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
            "pin_memory": bool(args.pin_memory),
            "persistent_workers": bool(args.persistent_workers),
            "warmup_batches": args.warmup_batches,
            "measured_batches": args.measured_batches,
            "selected_gpu": args.selected_gpu,
            "h2d_enabled": bool(args.h2d),
        }
        write_payload(output_path, payload)
        return 1


if __name__ == "__main__":
    sys.exit(main())
