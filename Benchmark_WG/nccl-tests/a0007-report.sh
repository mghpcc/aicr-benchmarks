#!/bin/bash
# Regenerate the auto-generated section of results_a0007_postfw.md once the
# a0007 jobs have finished. Submitted with --dependency=afterany so it runs
# whether the upstream jobs succeed, fail, or are cancelled.
#
# This runs as a SLURM job on purpose: a backgrounded shell waiter dies with the
# login session, a SLURM dependency does not. It needs no GPU.
#SBATCH -p rtx-batch
#SBATCH -w a0007
#SBATCH -t 15
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1   # rtx-batch requires a GPU allocation even for a CPU-only task
#SBATCH --mem=8GB
#SBATCH -J a0007-report
#SBATCH -o out-1node-a0007/%x-%N-%J

cd "$SLURM_SUBMIT_DIR" || exit 1

echo "=============================================================="
echo "auto-report starting $(date -Is)"
echo "=============================================================="

# Be explicit about the interpreter: the batch environment may not inherit the
# submit shell's PATH, and this job is the only thing that updates the summary.
PY=$(command -v python3 || echo /apps/aicr/packages/miniforge3/25.3.0-3/3fiwftn/bin/python3)
echo "using interpreter: $PY"
"$PY" ./a0007_autoreport.py
rc=$?
echo "autoreport exit=$rc"

echo "--- job outcomes in this batch ---"
sacct -j $(awk '{printf "%s%s", sep, $1; sep=","}' out-1node-a0007/JOBIDS) --format=JobID%12,JobName%18,State%14,Elapsed,ExitCode -X 2>/dev/null
echo "--- summary file now ends with ---"
tail -20 results_a0007_postfw.md

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
