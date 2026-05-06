# provenance/

Curated guide for **future agents and humans** modifying or maintaining this
codebase. Read top-to-bottom in roughly ten minutes before making changes.

## Reading order

1. [`01_original_prompt.md`](01_original_prompt.md) — what was originally
   asked, what was added later, and the cluster context the work assumes.
2. [`02_behavioral_rules.md`](02_behavioral_rules.md) — the rules that shaped
   how the code was written (simplicity-first, surgical changes, HPC
   courtesy/security).
3. [`03_decisions.md`](03_decisions.md) — the explicit design choices made
   along the way, each tied to the file/function that reflects it.
4. [`04_pitfalls.md`](04_pitfalls.md) — wrong turns, debugging lessons, and
   anti-patterns. The highest-value file if you're picking up the project.

Optional reference (not narrative; consult as needed):
[`agent_guidance/`](agent_guidance/README.md) — pinned snapshots of the
external behavioral-rule files this codebase was written under
(Karpathy's "keep it simple" rules, mermaid rendering rules, mdr
markdown rules), with the upstream URL for the Karpathy file recorded
for re-sync.

## Top-level entry points

- [`AGENT_PROMPT.md`](../AGENT_PROMPT.md) — the as-given task description and
  meta-rules. Authoritative for **what the project is for**.
- [`README.md`](../README.md) — user-facing usage and output layout.
  Authoritative for **how to run it**.
- [`bin/`](../bin/) — the actual code. Authoritative for **what it does**.

## Status

This directory is **descriptive, not authoritative**. If a `provenance/` file
disagrees with what `bin/` actually does, the code is right and the
provenance file is stale; please update it in the same change that updates
the code.

This directory is **not consumed by any script** — it exists purely to
shorten the ramp-up time for the next person (or agent) to touch this
codebase.
