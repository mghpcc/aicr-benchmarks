# agent_guidance/

External behavioral-rule files imported into this repo as snapshots, so
the rules an agent was supposed to follow are pinned to the version
that shaped this codebase rather than whatever upstream looks like
today.

These files are read-only references. Do not edit them locally -- if a
rule needs to change, update the upstream and re-import.

## Files

- [`karpathy_keep_it_simple.md`](karpathy_keep_it_simple.md)
  - Source (local):
    `/Users/cnh/projects/agent_general_rules/karpathy_keep_it_simple.md`
  - Source (upstream, byte-identical):

    ```
    curl -O https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md
    ```

  - Referenced from: [`AGENT_PROMPT.md`](../../AGENT_PROMPT.md),
    [`provenance/02_behavioral_rules.md`](../02_behavioral_rules.md).

- [`MERMAID_DIAGRAM_RULES.md`](MERMAID_DIAGRAM_RULES.md)
  - Source (local):
    `/Users/cnh/projects/agent_general_rules/MERMAID_DIAGRAM_RULES.md`
  - Use when adding mermaid diagrams to README / provenance docs.

- [`RULES_FOR_MDR_MARKDOWN.md`](RULES_FOR_MDR_MARKDOWN.md)
  - Source (local):
    `/Users/cnh/projects/agent_general_rules/RULES_FOR_MDR_MARKDOWN.md`
  - Use when authoring markdown intended to render in `mdr`.

## Re-syncing

To refresh a snapshot from a known-good upstream URL:

```bash
curl -fsSL <url> -o provenance/agent_guidance/<file>
git diff provenance/agent_guidance/<file>
```

Review the diff before committing -- a behavioral-rule change is a real
change, not a chore.
