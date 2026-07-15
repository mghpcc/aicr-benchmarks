#!/usr/bin/env python3
"""Parse ddl benchmark output logs into a markdown results table.

Usage:  python3 parse_results.py [output_dir]         (default: output)

Per log file it extracts:
  * the DDL_CONFIG banner echoed by run_ddl.sh (model, prec, tp, pp, gbs, ...)
  * the LAST training-iteration line: step time (ms), TFLOP/s/GPU, lm loss
  * the last per-rank timer blocks: all-grads-sync, forward-backward, optimizer
    (mean over ranks, ms) -> grads-sync share of step time
  * MFU against both dense-peak ceilings: BF16 2250 and FP8 4500 TFLOP/s

Note: Megatron's reported TFLOP/s/GPU is analytic model FLOPs / measured step
time, so it is precision-independent and directly comparable BF16 vs FP8.
"""
import re
import sys
from pathlib import Path

BF16_PEAK = 2250.0   # B200 dense BF16 TFLOP/s (paper Table "peak")
FP8_PEAK = 4500.0    # B200 dense FP8 TFLOP/s

ITER_RE = re.compile(
    r"iteration\s+(\d+)/\s*\d+ \|.*?"
    r"elapsed time per iteration \(ms\): ([\d.]+) \|.*?"
    r"throughput per GPU \(TFLOP/s/GPU\): ([\d.]+) \|.*?"
    r"lm loss: ([\dE+.\-]+)"
)
CONFIG_RE = re.compile(r"^DDL_CONFIG (.*)$", re.M)
TIMERS = ["all-grads-sync", "forward-backward", "optimizer"]


def parse_timer_blocks(text, name):
    """Return mean over ranks (ms) of the LAST '  <name>:' per-rank block."""
    vals, last = [], None
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.strip() == f"{name}:":
            cur = []
            for l in lines[i + 1:]:
                m = re.match(r"\s+rank\s+\d+: ([\d.]+)", l)
                if not m:
                    break
                cur.append(float(m.group(1)))
            if cur:
                last = cur
    return sum(last) / len(last) if last else None


def parse_file(path):
    text = path.read_text(errors="replace")
    row = {"file": path.name}
    m = CONFIG_RE.search(text)
    if m:
        row.update(dict(kv.split("=", 1) for kv in m.group(1).split()))
    iters = ITER_RE.findall(text)
    if not iters:
        row["status"] = "NO ITERATIONS (failed?)"
        return row
    it, ms, tflops, loss = iters[-1]
    row.update(iter=it, step_ms=float(ms), tflops=float(tflops), loss=loss)
    row["mfu_bf16_%"] = round(100 * float(tflops) / BF16_PEAK, 1)
    row["mfu_fp8_%"] = round(100 * float(tflops) / FP8_PEAK, 1)
    for t in TIMERS:
        v = parse_timer_blocks(text, t)
        if v is not None:
            row[t + "_ms"] = round(v, 1)
    if "all-grads-sync_ms" in row:
        row["grads_sync_%"] = round(100 * row["all-grads-sync_ms"] / row["step_ms"], 2)
    return row


def main():
    outdir = Path(sys.argv[1] if len(sys.argv) > 1 else "output")
    rows = [parse_file(p) for p in sorted(outdir.glob("out.*"))]
    if not rows:
        print(f"no out.* files in {outdir}/", file=sys.stderr)
        return
    cols = ["file", "model", "prec", "nodes", "gpus_per_node", "tp", "pp", "dp",
            "gbs", "sharp", "iter", "step_ms", "tflops", "mfu_bf16_%",
            "mfu_fp8_%", "all-grads-sync_ms", "grads_sync_%", "loss", "status"]
    cols = [c for c in cols if any(c in r for r in rows)]
    print("| " + " | ".join(cols) + " |")
    print("|" + "---|" * len(cols))
    for r in rows:
        print("| " + " | ".join(str(r.get(c, "")) for c in cols) + " |")


if __name__ == "__main__":
    main()
