#!/usr/bin/env python3
"""Extract converged (16 GB) algbw/busbw from the post-firmware a0007 NCCL outputs.

Handles every section-label form used by the a0007-*.sh scripts:
    %%%%%%%%% <prog> %%%%%%%%%%                    (a0007-1node-8gpu.sh)
    %%%%%%%%% CASE=<case> <prog> %%%%%%%%%%        (a0007-socket.sh)
    %%%%%%%%% NGPUS=<n> <prog> %%%%%%%%%%          (a0007-sweep.sh)
    %%%%%%%%% PAIR=<i>-<j> sendrecv_perf %%%%%%%%%% (a0007-pair-matrix.sh)

Usage: extract_a0007.py out-1node-a0007/a0007-*   ->  TSV on stdout
Read-only; writes nothing.
"""
import re
import sys

COLLECTIVES = [
    "sendrecv_perf", "reduce_perf", "broadcast_perf", "gather_perf", "scatter_perf",
    "reduce_scatter_perf", "all_gather_perf", "all_reduce_perf", "alltoall_perf",
    "hypercube_perf",
]

TARGET = 17179869184  # 16 GB — the converged point
SECTION = re.compile(r"^%{9}\s+(.*?)\s+%{10}\s*$")
FAIL = re.compile(r"Test (failure|NOT PASSED)|ncclInternalError|unhandled cuda error|"
                  r"Segmentation fault|Aborted|error :|ERROR", re.I)


def parse(path):
    """Return an ordered list of (case, collective, record) for one output file."""
    with open(path, errors="replace") as fh:
        lines = fh.readlines()

    recs = []          # preserves run order
    index = {}         # (case, prog) -> record
    cur = None

    for ln in lines:
        m = SECTION.match(ln)
        if m:
            label = m.group(1)
            if label.startswith("DONE"):
                cur = None
                continue
            parts = label.split()
            prog = parts[-1]
            case = " ".join(parts[:-1]) or "all"
            for pre in ("CASE=", "NGPUS=", "PAIR="):
                if case.startswith(pre):
                    case = case[len(pre):] if pre != "NGPUS=" else "ngpus" + case[len(pre):]
            if prog not in COLLECTIVES:
                cur = None
                continue
            key = (case, prog)
            rec = index.get(key)
            if rec is None:
                rec = {"case": case, "prog": prog, "algbw": None, "busbw": None,
                       "avg": None, "wrong": None, "status": "no data"}
                index[key] = rec
                recs.append(rec)
            cur = rec
            continue

        if cur is None:
            continue

        m = re.match(r"^#\s*Avg bus bandwidth\s*:\s*([\d.]+)", ln)
        if m:
            cur["avg"] = float(m.group(1))
            continue

        if FAIL.search(ln):
            if cur["status"] in ("no data", "ok"):
                cur["status"] = "FAILED"
            continue

        f = ln.split()
        if len(f) < 12 or not f[0].isdigit() or int(f[0]) != TARGET:
            continue
        try:
            alg_o, bus_o = float(f[-7]), float(f[-6])
            alg_i, bus_i = float(f[-3]), float(f[-2])
        except ValueError:
            continue
        # best of out-of-place / in-place, same convention as results_rtx6000.md
        cur["algbw"], cur["busbw"] = (alg_o, bus_o) if bus_o >= bus_i else (alg_i, bus_i)
        cur["wrong"] = f[-5]
        if cur["status"] == "no data":
            cur["status"] = "ok" if cur["wrong"] in ("0", "N/A") else "WRONG=%s" % cur["wrong"]

    return recs


def main(paths):
    fmt = lambda v: "-" if v is None else ("%g" % v)
    print("file\tcase\tcollective\talgbw\tbusbw\tavg_busbw\twrong\tstatus")
    for p in paths:
        base = p.split("/")[-1]
        for r in parse(p):
            print("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s" % (
                base, r["case"], r["prog"], fmt(r["algbw"]), fmt(r["busbw"]),
                fmt(r["avg"]), r["wrong"] or "-", r["status"]))


if __name__ == "__main__":
    main(sys.argv[1:])
