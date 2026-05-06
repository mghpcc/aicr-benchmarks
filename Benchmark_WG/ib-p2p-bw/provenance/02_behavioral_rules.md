# 02 — Behavioral rules that shaped this code

The user pinned two sets of rules at the top of
[`AGENT_PROMPT.md`](../AGENT_PROMPT.md). Future agents/humans should treat
both as load-bearing — they explain why the code looks the way it does.

## A. Keep it simple (Karpathy meta-rules)

Source of truth:
`/Users/cnh/projects/agent_general_rules/karpathy_keep_it_simple.md`.
The four rules, with how each one materialized in this codebase:

### A1. Think before coding

> *State assumptions explicitly. If uncertain, ask. If multiple
> interpretations exist, present them — don't pick silently.*

Concretely: the very first turn produced a written design surfacing
**8 assumptions** (perftest tool choice, unidirectional vs. bidirectional,
`--use_cuda` semantics, one pair per job, rail-correct NIC selection,
etc.) and **5 explicit open questions** (defaults vs. env vars, NUMA
pinning yes/no, hostname resolution, direction-per-job, parallel multi-GPU)
**before any script was written**. Five short answers from the user
disambiguated everything; only then did files get created.

If you're tempted to start coding before you can name your assumptions —
stop, write them down, and ask.

### A2. Simplicity first

> *Minimum code that solves the problem. Nothing speculative.*

Concretely:

- **Bash only.** No Python, no Go, no abstraction layers. Each script in
  [`bin/`](../bin/) is under ~150 lines of bash + a small awk block where
  parsing demands it.
- **No JSON/CSV/Parquet output.** The aggregation primitive is one
  `summary.txt` per run with a self-describing prefix (see
  [`03_decisions.md`](03_decisions.md), "Self-describing summary lines").
- **No retries, no test harness, no Grafana hooks, no DB.** Each
  failure mode that *did* show up in the wild was patched surgically;
  most never showed up and were rightly never built.

If you're about to add "flexibility" or "configurability" the user
didn't ask for, that's a smell. Build the smallest thing that closes
the loop, then re-evaluate.

### A3. Surgical changes

> *Touch only what you must. Match existing style. Don't refactor what
> isn't broken.*

Concretely:

- The four top-level docs the user provided
  ([`AGENT_PROMPT.md`](../AGENT_PROMPT.md),
  [`read_command_example.md`](../read_command_example.md),
  [`write_command_example.md`](../write_command_example.md),
  [`salloc_example.md`](../salloc_example.md)) were edited only when the
  user **explicitly** asked (the `ib_readbw` → `ib_read_bw` typo fix in
  the example file). They were never "improved" or "modernized" in
  passing.
- Each later feature request (sampler, exclude-nodes, jobid bucketing,
  output-tree restructure, summary prefix) added one new file or
  modified one existing file, never a sweep.

If a change you're about to make doesn't trace back to something the
user asked for, drop it.

### A4. Goal-driven execution

> *Define success criteria. Loop until verified.*

Concretely: every iteration here had a verifier. The plan turn ended
with success criteria. The mixed-tool failure was diagnosed by an
explicit manual perftest + log inspection, not by guessing. The
random-sampler refactor was followed by an in-shell test matrix
(rail/arbitrary, seeded/unseeded, with/without exclusion) before
declaring done.

If you can't say what "done" looks like, you're not done thinking.

## B. HPC-cluster courtesy and security

Source: the admonition added later to
[`AGENT_PROMPT.md`](../AGENT_PROMPT.md):

> *The script will run on a shared HPC cluster with regular account
> privileges. If something is not available to an unprivileged account,
> don't do stupid tests like "can yum install work" or "does su work".
> That will just waste everyone's time with irritating security alerts
> and is rude — be polite and act like a respectful human would, not
> like a blundering fool.*

What this means in practice for this codebase:

- **No `sudo`, `su`, `runuser`, PAM probes**, anywhere. Confirm with
  `rg '\b(sudo|su|runuser|pam_)\b' bin/` — should be no matches.
- **No package-install attempts** (`yum install`, `apt-get install`,
  `pip install --user`, `dnf`, `rpm`, etc.). If a tool isn't on PATH,
  use `command -v` to detect, and skip cleanly with a short message.
- **No speculative cross-node retries** for diagnostic commands. If
  `command -v ibtracert` says no on the local node, don't go fishing
  via `srun` on the other node "just to see". One probe is a check;
  many probes is a probe.
  - This rule produced one concrete fix:
    [`bin/record_switch_path.sh`](../bin/record_switch_path.sh) used
    to fall back to `srun -w nodeA ibtracert ...` when not found
    locally. Removed.
- **`auid=4294967295` in audit log entries** is the daemon-spawned-by-
  root signature. SLURM job-step spawn (slurmd → su -l user → exec
  slurmstepd) generates this for every `srun` step on every job for
  every user on this cluster. Don't try to silence it — it's not from
  this code, it's how SLURM works. See
  [`04_pitfalls.md`](04_pitfalls.md) item 5.

The general principle: if the cluster's not configured for your test,
**fail polite, don't probe**.
