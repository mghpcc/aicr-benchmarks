#!/bin/bash
# Autonomous watcher for the phase-0 smoke-test jobs. Survives logout (launch
# with nohup/setsid). Waits for the jobs, then writes results-phase0-smoke.md.
# Usage: bash watch_phase0.sh "JOBID JOBID ..." (default: the 2026-07-13 smoke set)

JOBIDS=${1:-"152990 152991 152992 152993"}
DDL=/home/shaohao_mit/benchmarks/ddl
OUT=$DDL/output
MD=$DDL/results-phase0-smoke.md
DEADLINE=$(( $(date +%s) + 24*3600 ))

regex=$(echo $JOBIDS | tr ' ' '|')
while :; do
    n=$(squeue -h -o %i -u "$USER" 2>/dev/null | grep -cE "^($regex)$")
    [ "$n" -eq 0 ] && break
    if [ "$(date +%s)" -gt "$DEADLINE" ]; then
        echo "# Phase 0 smoke test — TIMED OUT after 24 h; jobs still queued/running: " > "$MD"
        squeue -u "$USER" >> "$MD"
        exit 1
    fi
    sleep 120
done
sleep 30   # let output files flush

JOBIDS="$JOBIDS" OUT="$OUT" MD="$MD" python3 - <<'EOF'
import os, re, subprocess, glob
from datetime import datetime

jobids = os.environ["JOBIDS"].split()
outdir = os.environ["OUT"]
md_path = os.environ["MD"]

def job_file(jid):
    g = glob.glob(f"{outdir}/out.*-{jid}")
    return g[0] if g else None

BF16_PEAK, FP8_PEAK = 2250.0, 4500.0
ITER_RE = re.compile(r"iteration\s+(\d+)/\s*\d+ \|.*?elapsed time per iteration \(ms\): ([\d.]+) \|.*?"
                     r"throughput per GPU \(TFLOP/s/GPU\): ([\d.]+) \|.*?lm loss: ([\dE+.\-]+).*?"
                     r"number of nan iterations:\s+(\d+)")
rows = []
for jid in jobids:
    f = job_file(jid)
    r = {"job": jid}
    if not f:
        r["status"] = "no output file"; rows.append(r); continue
    text = open(f, errors="replace").read()
    m = re.search(r"^DDL_CONFIG (.*)$", text, re.M)
    if m: r.update(dict(kv.split("=", 1) for kv in m.group(1).split()))
    # fp8 engagement: Megatron prints the resolved args table at startup
    fp8arg = re.search(r"^\s*fp8 \.+ (\S+)", text, re.M)
    rcp = re.search(r"^\s*fp8_recipe \.+ (\S+)", text, re.M)
    r["fp8_arg"] = (fp8arg.group(1) if fp8arg else "?") + "/" + (rcp.group(1) if rcp else "?")
    its = ITER_RE.findall(text)
    if "CUDA out of memory" in text: r["status"] = "OOM"
    elif "Traceback" in text and not its: r["status"] = "CRASHED"
    elif not its: r["status"] = "no iterations"
    else:
        it, ms, tf, loss, nans = its[-1]
        r.update(status="ok", iter=it, step_ms=float(ms), tflops=float(tf),
                 loss=loss, nan_iters=int(nans),
                 mfu_bf16=round(100*float(tf)/BF16_PEAK, 1),
                 mfu_fp8=round(100*float(tf)/FP8_PEAK, 1))
    rows.append(r)

base = next((r for r in rows if r.get("prec") == "bf16" and r.get("status") == "ok"), None)
for r in rows:
    if base and r.get("status") == "ok":
        r["speedup_vs_bf16"] = round(r["tflops"]/base["tflops"], 3)

cols = ["job", "prec", "status", "iter", "step_ms", "tflops", "speedup_vs_bf16",
        "mfu_bf16", "mfu_fp8", "fp8_arg", "nan_iters", "loss"]
lines = [f"# Phase 0 smoke test results (auto-generated {datetime.now():%Y-%m-%d %H:%M})",
         "", "1.3b, 1 node x 8 B200, DP=8, GBS 1024, MBS 4, 20 iters, mock data.",
         "Goal: verify every precision recipe runs (TE engaged, no NaN/OOM) before real sweeps.",
         "", "| " + " | ".join(cols) + " |", "|" + "---|"*len(cols)]
for r in rows:
    lines.append("| " + " | ".join(str(r.get(c, "")) for c in cols) + " |")
lines += ["",
          "Notes: tflops is analytic FLOPs/step-time (precision-independent, comparable",
          "across rows). mfu_bf16 = tflops/2250, mfu_fp8 = tflops/4500 (%). At 1.3b the",
          "FP8 speedup is expected to be modest (Amdahl); the 7b/13b phases are the",
          "headline. 20-iter runs are smoke tests, not benchmark numbers.",
          "", "Next steps: if all rows ok -> `bash submit_phase0b_mbs.sh` (MBS tuning),",
          "then phase 1. If a recipe failed, see readme.md troubleshooting.", ""]
open(md_path, "w").write("\n".join(lines))
print("wrote", md_path)
EOF
