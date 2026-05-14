# check-man-links.py

## Purpose

Check that prose documentation links public script names to their command
reference pages.

## Usage

```bash
python3 scripts/docs/check-man-links.py
```

## Checks

- Every public script listed in `man/README.md` links to an existing man page.
- Prose mentions of public scripts in Markdown docs link to the matching man page.
- Documented script paths refer only to public scripts listed in `man/README.md`.

Copy-paste command blocks and inline command snippets are ignored so examples
remain runnable without editing.
