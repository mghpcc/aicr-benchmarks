#!/bin/bash
# Autonomous watcher for phase-0b MBS-tuning jobs. Survives logout
# (launch with nohup/setsid). Waits, then writes results-phase0b-mbs.md.
# Usage: bash watch_phase0b.sh "JOBID JOBID ..."

JOBIDS=${1:?usage: watch_phase0b.sh \"JOBID ...\"}
DDL=/home/shaohao_mit/benchmarks/ddl
OUT=$DDL/output
MD=$DDL/results-phase0b-mbs.md
DEADLINE=$(( $(date +%s) + 24*3600 ))

regex=$(echo $JOBIDS | tr ' ' '|')
while :; do
    n=$(squeue -h -o %i -u "$USER" 2>/dev/null | grep -cE "^($regex)$")
    [ "$n" -eq 0 ] && break
    if [ "$(date +%s)" -gt "$DEADLINE" ]; then
        echo "# Phase 0b MBS tuning — TIMED OUT after 24 h; still queued:" > "$MD"
        squeue -u "$USER" >> "$MD"; exit 1
    fi
    sleep 120
done
sleep 30   # let output files flush

JOBIDS="$JOBIDS" OUT="$OUT" MD="$MD" python3 - <<'EOF'
import os, re, glob
from datetime import datetime

jobids = os.environ["JOBIDS"].split()
outdir, md_path = os.environ["OUT"], os.environ["MD"]
BF16_PEAK, FP8_PEAK = 2250.0, 4500.0
ITER_RE = re.compile(r"iteration\s+(\d+)/\s*\d+ \|.*?elapsed time per iteration \(ms\): ([\d.]+) \|.*?"
                     r"throughput per GPU \(TFLOP/s/GPU\): ([\d.]+) \|.*?lm loss: ([\dE+.\-]+).*?"
                     r"number of nan iterations:\s+(\d+)")

def job_file(jid):
    g = glob.glob(f"{outdir}/out.*-{jid}")
    return g[0] if g else None

rows = []
for jid in jobids:
    f = job_file(jid); r = {"job": jid}
    if not f:
        r["status"] = "no output file"; rows.append(r); continue
    text = open(f, errors="replace").read()
    m = re.search(r"^DDL_CONFIG (.*)$", text, re.M)
    if m: r.update(dict(kv.split("=", 1) for kv in m.group(1).split()))
    its = ITER_RE.findall(text)
    if "out of memory" in text.lower(): r["status"] = "OOM"
    elif "Traceback" in text and not its: r["status"] = "CRASHED"
    elif not its: r["status"] = "no iterations"
    else:
        it, ms, tf, loss, nans = its[-1]
        r.update(status="ok", iter=it, step_ms=float(ms), tflops=float(tf),
                 loss=loss, nan_iters=int(nans),
                 mfu_bf16=round(100*float(tf)/BF16_PEAK, 1),
                 mfu_fp8=round(100*float(tf)/FP8_PEAK, 1))
    rows.append(r)

def mbs_int(r):
    try: return int(r.get("mbs", 0))
    except: return 0
rows.sort(key=lambda r: (r.get("prec", ""), mbs_int(r)))

# Best (max tflops) MBS per precision among ok rows.
best = {}
for r in rows:
    if r.get("status") == "ok":
        p = r.get("prec")
        if p not in best or r["tflops"] > best[p]["tflops"]:
            best[p] = r

cols = ["job", "prec", "mbs", "status", "iter", "step_ms", "tflops",
        "mfu_bf16", "mfu_fp8", "nan_iters"]
L = [f"# Phase 0b — micro-batch-size tuning (auto-generated {datetime.now():%Y-%m-%d %H:%M})",
     "", "7b, 1 node x 8 B200, DP=8, GBS 1024, 20 iters, mock data.",
     "Sweep MBS in {2,4,8,16} x {bf16, fp8ds} to pick the best micro-batch per",
     "precision before phases 1-4. OOM is an expected result, not a failure.",
     "", "| " + " | ".join(cols) + " |", "|" + "---|"*len(cols)]
for r in rows:
    L.append("| " + " | ".join(str(r.get(c, "")) for c in cols) + " |")

L += ["", "## Recommendation", ""]
if best:
    for p in sorted(best):
        b = best[p]
        L.append(f"- **{p}**: best MBS = **{b.get('mbs')}** "
                 f"({b['tflops']:.1f} TFLOP/s/GPU, {b['step_ms']:.0f} ms/step). "
                 f"Set arg 6 of job_ddl.sh to {b.get('mbs')} in the phase 1-4 submit scripts.")
    oom = [r for r in rows if r.get("status") == "OOM"]
    if oom:
        oom_s = ", ".join(f"{r.get('prec')}@MBS{r.get('mbs')}" for r in oom)
        L.append(f"- OOM (expected, memory ceiling): {oom_s}. If BF16 OOMs where FP8 "
                 f"survives, that is the FP8 activation-memory-headroom finding for Paper B.")
    L.append("- Keep one MBS=4 job per precision in phase 1 as the anchor to the paper.")
else:
    L.append("- No successful runs to rank — check logs in output/ and readme.md troubleshooting.")

L += ["", "Note: 20-iter smoke numbers (warmup-dominated), used only to RANK MBS,",
      "not as benchmark throughput. tflops = analytic FLOPs/step-time.",
      "Next: adopt the MBS above, then `bash submit_phase1_precision.sh output 1`.", ""]
open(md_path, "w").write("\n".join(L))
print("wrote", md_path)
EOF
