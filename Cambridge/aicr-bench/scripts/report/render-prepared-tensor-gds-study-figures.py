#!/usr/bin/env python3
"""Render public prepared-tensor GPU/cuFile study figures."""

from __future__ import annotations

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


PYTORCH_BACKEND = "numpy-fp16-blocks-pytorch"
DALI_GDS_BACKEND = "dali-numpy-fp16-blocks-gds"

BACKEND_LABELS = {
    PYTORCH_BACKEND: "PyTorch mmap blocks",
    DALI_GDS_BACKEND: "DALI NumPy GPU/cuFile",
}

BACKEND_COLORS = {
    PYTORCH_BACKEND: "tab:green",
    DALI_GDS_BACKEND: "tab:orange",
}


B200_DATALOADER = [
    {"size": 256, "backend": PYTORCH_BACKEND, "samples": 61558.71, "read_gbps": 20.72},
    {"size": 256, "backend": DALI_GDS_BACKEND, "samples": 105577.78, "read_gbps": 40.83},
    {"size": 384, "backend": PYTORCH_BACKEND, "samples": 44159.69, "read_gbps": 35.06},
    {"size": 384, "backend": DALI_GDS_BACKEND, "samples": 47551.82, "read_gbps": 41.57},
    {"size": 512, "backend": PYTORCH_BACKEND, "samples": 26855.27, "read_gbps": 39.33},
    {"size": 512, "backend": DALI_GDS_BACKEND, "samples": 27282.93, "read_gbps": 42.41},
    {"size": 1024, "backend": PYTORCH_BACKEND, "samples": 3095.04, "read_gbps": 18.07},
    {"size": 1024, "backend": DALI_GDS_BACKEND, "samples": 7066.03, "read_gbps": 43.63},
]

RTX_DATALOADER = [
    {"size": 256, "backend": PYTORCH_BACKEND, "samples": 78156.07, "read_gbps": 28.03},
    {"size": 256, "backend": DALI_GDS_BACKEND, "samples": 112379.21, "read_gbps": 43.64},
    {"size": 384, "backend": PYTORCH_BACKEND, "samples": 45101.94, "read_gbps": 34.70},
    {"size": 384, "backend": DALI_GDS_BACKEND, "samples": 50624.43, "read_gbps": 44.42},
    {"size": 512, "backend": PYTORCH_BACKEND, "samples": 27662.47, "read_gbps": 38.68},
    {"size": 512, "backend": DALI_GDS_BACKEND, "samples": 27676.51, "read_gbps": 43.26},
]

B200_DDP_SPC64 = [
    {
        "nodes": 1,
        "backend": DALI_GDS_BACKEND,
        "images": 33799.04,
        "read_gbps": 13.29,
        "speedup": 1.93,
    },
    {
        "nodes": 1,
        "backend": PYTORCH_BACKEND,
        "images": 17471.25,
        "read_gbps": 6.87,
        "speedup": 1.0,
    },
    {
        "nodes": 2,
        "backend": DALI_GDS_BACKEND,
        "images": 66771.71,
        "read_gbps": 26.26,
        "speedup": 2.58,
    },
    {
        "nodes": 2,
        "backend": PYTORCH_BACKEND,
        "images": 25850.19,
        "read_gbps": 10.16,
        "speedup": 1.0,
    },
    {
        "nodes": 4,
        "backend": DALI_GDS_BACKEND,
        "images": 132099.42,
        "read_gbps": 51.94,
        "speedup": 3.92,
    },
    {
        "nodes": 4,
        "backend": PYTORCH_BACKEND,
        "images": 33717.13,
        "read_gbps": 13.26,
        "speedup": 1.0,
    },
    {
        "nodes": 8,
        "backend": DALI_GDS_BACKEND,
        "images": 248318.06,
        "read_gbps": 97.64,
        "speedup": 8.89,
    },
    {
        "nodes": 8,
        "backend": PYTORCH_BACKEND,
        "images": 27924.64,
        "read_gbps": 10.98,
        "speedup": 1.0,
    },
]

B200_DDP_SPC128_16 = [
    {"backend": DALI_GDS_BACKEND, "images": 246481.42, "read_gbps": 96.92},
    {"backend": PYTORCH_BACKEND, "images": 52759.36, "read_gbps": 20.75},
]

RTX_DDP = [
    {"nodes": 1, "backend": DALI_GDS_BACKEND, "images": 15516.05, "speedup": 1.385},
    {"nodes": 1, "backend": PYTORCH_BACKEND, "images": 11204.54, "speedup": 1.0},
    {"nodes": 2, "backend": DALI_GDS_BACKEND, "images": 30978.19, "speedup": 1.571},
    {"nodes": 2, "backend": PYTORCH_BACKEND, "images": 19720.05, "speedup": 1.0},
    {"nodes": 4, "backend": DALI_GDS_BACKEND, "images": 61788.28, "speedup": 2.108},
    {"nodes": 4, "backend": PYTORCH_BACKEND, "images": 29310.72, "speedup": 1.0},
    {"nodes": 8, "backend": DALI_GDS_BACKEND, "images": 123023.05, "speedup": 4.094},
    {"nodes": 8, "backend": PYTORCH_BACKEND, "images": 30051.79, "speedup": 1.0},
]


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def ensure_dirs() -> tuple[Path, Path]:
    root = repo_root()
    dataloader_dir = root / "docs" / "modules" / "dataloader" / "studies" / "figures"
    ddp_dir = root / "docs" / "modules" / "ddp" / "studies" / "figures"
    dataloader_dir.mkdir(parents=True, exist_ok=True)
    ddp_dir.mkdir(parents=True, exist_ok=True)
    return dataloader_dir, ddp_dir


def style_axes(ax, *, xgrid: bool = False, ygrid: bool = False) -> None:
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    if xgrid:
        ax.grid(axis="x", alpha=0.25)
    if ygrid:
        ax.grid(axis="y", alpha=0.25)


def save(fig, path: Path) -> None:
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"Wrote {path}")


def by_backend(rows, x_key: str, y_key: str) -> dict[str, list[tuple[float, float]]]:
    grouped: dict[str, list[tuple[float, float]]] = {}
    for row in rows:
        grouped.setdefault(row["backend"], []).append((row[x_key], row[y_key]))
    return {key: sorted(value) for key, value in grouped.items()}


def grouped_bar(rows, *, x_key: str, y_key: str, xlabel: str, ylabel: str, title: str, path: Path) -> None:
    x_values = sorted({row[x_key] for row in rows})
    width = 0.36
    positions = np.arange(len(x_values))
    fig, ax = plt.subplots(figsize=(9, 5))
    for offset, backend in [(-width / 2, PYTORCH_BACKEND), (width / 2, DALI_GDS_BACKEND)]:
        values = [next(row[y_key] for row in rows if row[x_key] == x and row["backend"] == backend) for x in x_values]
        ax.bar(positions + offset, values, width=width, label=BACKEND_LABELS[backend], color=BACKEND_COLORS[backend])
    ax.set_xticks(positions)
    ax.set_xticklabels([str(x) for x in x_values])
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.16), ncol=2)
    style_axes(ax, ygrid=True)
    save(fig, path)


def line_by_backend(rows, *, x_key: str, y_key: str, xlabel: str, ylabel: str, title: str, path: Path) -> None:
    fig, ax = plt.subplots(figsize=(8, 5))
    all_xs = sorted({row[x_key] for row in rows})
    for backend, points in by_backend(rows, x_key, y_key).items():
        xs = [point[0] for point in points]
        ys = [point[1] for point in points]
        ax.plot(xs, ys, marker="o", linewidth=2, label=BACKEND_LABELS[backend], color=BACKEND_COLORS[backend])
    ax.set_xticks(all_xs)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.legend()
    style_axes(ax, ygrid=True)
    save(fig, path)


def backend_bar(rows, *, y_key: str, ylabel: str, title: str, path: Path, threshold: float | None = None) -> None:
    rows = sorted(rows, key=lambda row: row["backend"] == DALI_GDS_BACKEND)
    labels = [BACKEND_LABELS[row["backend"]] for row in rows]
    colors = [BACKEND_COLORS[row["backend"]] for row in rows]
    values = [row[y_key] for row in rows]
    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.bar(labels, values, color=colors)
    if threshold is not None:
        ax.axhline(threshold, color="#d62728", linestyle="--", linewidth=1.5, label=f"{threshold:g}% threshold")
        ax.legend()
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    style_axes(ax, ygrid=True)
    save(fig, path)


def speedup_line(rows, *, title: str, path: Path) -> None:
    points = sorted((row for row in rows if row["backend"] == DALI_GDS_BACKEND), key=lambda row: row["nodes"])
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(
        [row["nodes"] for row in points],
        [row["speedup"] for row in points],
        marker="o",
        linewidth=2,
        color=BACKEND_COLORS[DALI_GDS_BACKEND],
    )
    ax.axhline(1.0, color="#666666", linestyle="--", linewidth=1)
    ax.set_xticks([row["nodes"] for row in points])
    ax.set_xlabel("Nodes")
    ax.set_ylabel("Speedup vs PyTorch mmap blocks")
    ax.set_title(title)
    style_axes(ax, ygrid=True)
    save(fig, path)


def main() -> None:
    dataloader_dir, ddp_dir = ensure_dirs()

    grouped_bar(
        B200_DATALOADER,
        x_key="size",
        y_key="samples",
        xlabel="Prepared tensor size",
        ylabel="Samples/s",
        title="B200 prepared-tensor DataLoader throughput",
        path=dataloader_dir / "dataloader-b200-prepared-tensor-gds-throughput-2026-05-26.png",
    )
    grouped_bar(
        B200_DATALOADER,
        x_key="size",
        y_key="read_gbps",
        xlabel="Prepared tensor size",
        ylabel="Estimated read GB/s",
        title="B200 prepared-tensor estimated read bandwidth",
        path=dataloader_dir / "dataloader-b200-prepared-tensor-gds-read-gbps-2026-05-26.png",
    )
    grouped_bar(
        RTX_DATALOADER,
        x_key="size",
        y_key="samples",
        xlabel="Prepared tensor size",
        ylabel="Samples/s",
        title="RTX prepared-tensor DataLoader throughput",
        path=dataloader_dir / "dataloader-rtx-prepared-tensor-gds-throughput-2026-05-27.png",
    )
    grouped_bar(
        RTX_DATALOADER,
        x_key="size",
        y_key="read_gbps",
        xlabel="Prepared tensor size",
        ylabel="Estimated read GB/s",
        title="RTX prepared-tensor estimated read bandwidth",
        path=dataloader_dir / "dataloader-rtx-prepared-tensor-gds-read-gbps-2026-05-27.png",
    )

    line_by_backend(
        B200_DDP_SPC64,
        x_key="nodes",
        y_key="images",
        xlabel="Nodes",
        ylabel="Images/s",
        title="B200 prepared-tensor DDP throughput (spc=64)",
        path=ddp_dir / "ddp-b200-prepared-tensor-gds-spc64-throughput-2026-05-26.png",
    )
    speedup_line(
        B200_DDP_SPC64,
        title="B200 prepared-tensor DDP speedup (spc=64)",
        path=ddp_dir / "ddp-b200-prepared-tensor-gds-spc64-speedup-2026-05-26.png",
    )
    one_node_b200 = [row for row in B200_DDP_SPC64 if row["nodes"] == 1]
    backend_bar(
        one_node_b200,
        y_key="images",
        ylabel="Images/s",
        title="B200 prepared-tensor DDP one-node throughput",
        path=ddp_dir / "ddp-b200-prepared-tensor-gds-one-node-throughput-2026-05-26.png",
    )
    backend_bar(
        one_node_b200,
        y_key="read_gbps",
        ylabel="Estimated read GB/s",
        title="B200 prepared-tensor DDP one-node read bandwidth",
        path=ddp_dir / "ddp-b200-prepared-tensor-gds-one-node-read-gbps-2026-05-26.png",
    )
    backend_bar(
        B200_DDP_SPC128_16,
        y_key="images",
        ylabel="Images/s",
        title="B200 prepared-tensor DDP 16-node comparator (spc=128)",
        path=ddp_dir / "ddp-b200-prepared-tensor-gds-spc128-16node-throughput-2026-05-26.png",
    )

    line_by_backend(
        RTX_DDP,
        x_key="nodes",
        y_key="images",
        xlabel="Nodes",
        ylabel="Images/s",
        title="RTX prepared-tensor DDP throughput",
        path=ddp_dir / "ddp-rtx-prepared-tensor-gds-throughput-2026-05-26.png",
    )
    speedup_line(
        RTX_DDP,
        title="RTX prepared-tensor DDP speedup",
        path=ddp_dir / "ddp-rtx-prepared-tensor-gds-speedup-2026-05-26.png",
    )


if __name__ == "__main__":
    main()
