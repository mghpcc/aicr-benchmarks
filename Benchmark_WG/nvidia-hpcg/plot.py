#!/usr/bin/env python3
"""
Parse HPCG output files and plot GFLOP/s vs GPU count
with a dashed ideal linear scaling reference line.

Usage:
    python plot_hpcg.py *.out
    python plot_hpcg.py /path/to/results/hpcg_*.out
"""

import re
import sys
import glob
import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np


def parse_files(patterns):
    """
    Find HPCG output files matching the given glob patterns,
    extract GPU count from the filename and GFLOP/s from the content.

    Filename pattern expected:  ..._<N>_gpu_...
    Result line pattern:        ...VALID with a GFLOP/s rating of=<value>
    """
    results = {}

    # Expand globs and deduplicate
    files = []
    for pattern in patterns:
        files.extend(glob.glob(pattern))
    files = sorted(set(files))

    if not files:
        print("No files matched the given pattern(s).", file=sys.stderr)
        sys.exit(1)

    gpu_re  = re.compile(r'_(\d+)_gpu_', re.IGNORECASE)
    gflop_re = re.compile(
        r'HPCG result is VALID with a GFLOP/s rating of\s*=\s*([\d.]+)',
        re.IGNORECASE
    )

    for fpath in files:
        fname = Path(fpath).name

        # --- GPU count from filename ---
        m = gpu_re.search(fname)
        if not m:
            print(f"  [skip] Cannot extract GPU count from: {fname}", file=sys.stderr)
            continue
        n_gpu = int(m.group(1))

        # --- GFLOP/s from file content ---
        gflops = None
        try:
            with open(fpath) as f:
                for line in f:
                    m2 = gflop_re.search(line)
                    if m2:
                        gflops = float(m2.group(1))
                        break
        except OSError as e:
            print(f"  [skip] Cannot read {fpath}: {e}", file=sys.stderr)
            continue

        if gflops is None:
            print(f"  [skip] No VALID result line found in: {fname}", file=sys.stderr)
            continue

        print(f"  {fname}: {n_gpu} GPU(s) → {gflops:.3f} GFLOP/s")
        # Keep the best result if the same GPU count appears more than once
        if n_gpu not in results or gflops > results[n_gpu]:
            results[n_gpu] = gflops

    return results


def plot(results):
    gpus   = np.array(sorted(results.keys()))
    gflops = np.array([results[g] for g in gpus])

    # Ideal linear scaling anchored to the single-GPU result
    baseline   = gflops[0]
    ideal      = baseline * gpus

    # Efficiency (actual / ideal)
    efficiency = gflops / ideal * 100

    # ── figure ────────────────────────────────────────────────────────────────
    fig, ax = plt.subplots(figsize=(8, 5))
    fig.patch.set_facecolor('#0f1117')
    ax.set_facecolor('#0f1117')

    grid_kw = dict(color='#2a2d3a', linewidth=0.6, linestyle='--')
    ax.grid(True, which='both', **grid_kw)
    ax.set_axisbelow(True)

    # Ideal line
    ax.plot(gpus, ideal,
            linestyle='--', linewidth=1.8,
            color='#4fc3f7', alpha=0.7,
            label='Ideal linear scaling')

    # Measured data
    ax.plot(gpus, gflops,
            marker='o', markersize=9, linewidth=2.4,
            color='#76ff03', markerfacecolor='white',
            markeredgecolor='#76ff03', markeredgewidth=2,
            label='Measured GFLOP/s')

    # Annotate each point with GFLOP/s and efficiency
    for g, v, e in zip(gpus, gflops, efficiency):
        ax.annotate(
            f'{v:.1f}\n({e:.1f}%)',
            xy=(g, v),
            xytext=(0, 14),
            textcoords='offset points',
            ha='center', va='bottom',
            fontsize=8.5,
            color='#e0e0e0',
        )

    # Axes
    ax.set_xscale('log', base=2)
    ax.set_yscale('log')
    ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f'{int(x)}'))
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda y, _: f'{y:,.0f}'))
    ax.set_xticks(gpus)

    for spine in ax.spines.values():
        spine.set_edgecolor('#2a2d3a')

    ax.tick_params(colors='#9e9e9e', labelsize=10)
    ax.set_xlabel('Number of GPUs', color='#e0e0e0', fontsize=12, labelpad=8)
    ax.set_ylabel('GFLOP/s', color='#e0e0e0', fontsize=12, labelpad=8)
    ax.set_title('HPCG Scaling — NVIDIA RTX Pro 6000',
                 color='#ffffff', fontsize=14, fontweight='bold', pad=14)

    legend = ax.legend(
        framealpha=0.25, facecolor='#1e2130',
        edgecolor='#3a3d4a', labelcolor='#e0e0e0',
        fontsize=10, loc='upper left'
    )

    plt.tight_layout()
    out = 'hpcg_scaling.png'
    plt.savefig(out, dpi=150, bbox_inches='tight', facecolor=fig.get_facecolor())
    print(f"\nPlot saved to: {out}")
    plt.show()


def main():
    parser = argparse.ArgumentParser(
        description='Plot HPCG GFLOP/s scaling from output files.'
    )
    parser.add_argument(
        'files', nargs='+',
        help='HPCG output file(s) or glob pattern(s), e.g. "*.out"'
    )
    args = parser.parse_args()

    print("Parsing files:")
    results = parse_files(args.files)

    if not results:
        print("No valid results found.", file=sys.stderr)
        sys.exit(1)

    plot(results)


if __name__ == '__main__':
    main()
