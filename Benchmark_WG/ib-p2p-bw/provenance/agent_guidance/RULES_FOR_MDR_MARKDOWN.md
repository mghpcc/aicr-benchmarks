# Rules for Writing Markdown That Renders Correctly in mdr

This document defines rules for generating markdown files that render
correctly in **mdr** (v0.2.8+), a lightweight Markdown viewer built on
comrak (GFM parser) and syntect (syntax highlighting).

These rules exist because mdr has a confirmed rendering bug
(CleverCloud/mdr issue 30) and certain structural patterns that
cause fenced code blocks to collapse or leak into surrounding prose.
Follow every rule below and the output will render cleanly.


## The mdr Bug You Must Work Around

Lines that start with `#` inside a fenced code block are rendered as
markdown headings instead of literal code. This is mdr issue 30. It
means that Python comments, shell comments, YAML keys, and any other
line beginning with `#` will break out of the code block and corrupt
the document layout.


## Rule 1: No Lines Starting With # Inside Code Fences

Never write a line that starts with `#` inside a fenced code block.

**What to do instead:**

- Remove `# comment` lines entirely. Put the explanation in prose
  above the fence.
- If a file path would normally appear as `# orcd_billing/db.py`,
  move it to a bold label above the fence:

**orcd_billing/db.py:**

~~~
def connect(db_path):
    return duckdb.connect(str(db_path))
~~~

- If you need section separators inside a long code block, split it
  into multiple fences with prose headings between them instead of
  using `# -- Section --` comment lines.


## Rule 2: Use Tilde Fences, Not Backtick Fences

Write `~~~` to open and close code blocks. Do not write triple
backticks.

**Why:** When code inside a backtick fence contains Python triple-quote
strings (`"""`), some renderers lose track of which delimiter closes
the fence. Tilde characters never appear in Python, SQL, JSON, or
TOML, so there is zero ambiguity.

Good:

~~~
def hello():
    return "world"
~~~

Bad -- do not do this:

    ```python
    DDL = triple-quote
        CREATE TABLE foo (id INTEGER)
    triple-quote
    ```


## Rule 3: No Language Hints on Fences

Write `~~~` not `~~~python` or `~~~sql` or `~~~json`.

**Why:** mdr's syntect integration sometimes misinterprets language-hinted
fences, especially when fences follow each other rapidly. The language
hint adds no visible benefit in mdr (it does not change the color
scheme in a useful way) but introduces a failure mode.


## Rule 4: Always Put Prose Between Code Fences

Never place two fenced code blocks back-to-back with only a blank line
between them. Always have at least one line of visible prose (a bold
label, a sentence, a heading) between any two fences.

Good:

**connect function:**

~~~
def connect(db_path):
    return duckdb.connect(str(db_path))
~~~

The init_schema function creates all tables:

~~~
def init_schema(con):
    for ddl in ALL_DDL:
        con.execute(ddl)
~~~

Bad (fences back-to-back) -- do not do this:

    ~~~
    def connect(db_path):
        return duckdb.connect(str(db_path))
    ~~~

    ~~~
    def init_schema(con):
        for ddl in ALL_DDL:
            con.execute(ddl)
    ~~~


## Rule 5: Keep Code Blocks Under 60 Lines

If a code block would exceed roughly 60 lines, split it into smaller
blocks with a prose sentence or heading between each piece. Large
blocks are harder to read and more likely to trigger rendering
edge cases.


## Rule 6: Use 4-Space Indented Blocks for Non-Python Content

For SQL DDL, JSON examples, file trees, shell command listings, and
other content that is not Python code, use 4-space indented blocks
instead of fences. In CommonMark, any line indented by 4 or more
spaces (after a blank line) renders as a preformatted code block.
No opening or closing delimiter is needed, so there is nothing for
the renderer to get wrong.

Good:

**rate table DDL:**

    CREATE TABLE IF NOT EXISTS rate (
        rate_code    VARCHAR PRIMARY KEY,
        display_name VARCHAR NOT NULL,
        category     VARCHAR NOT NULL
    )

Good (file tree):

    orcd_billing/
        __init__.py
        db.py
        models.py
        ingest/
            __init__.py
            rates.py

Good (shell commands):

    orcd-billing init-db
    orcd-billing load-config
    orcd-billing load-project data/projects/jhm_p1.json

**Important:** There must be a blank line before the first indented
line. Without it, the indented text is treated as a continuation of
the preceding paragraph, not as a code block.


## Rule 7: No Horizontal Rules

Do not use `---`, `***`, or `___` as horizontal rules. Some renderers
interpret `---` as a YAML front-matter delimiter (if near the top of
the file) or as a setext-style heading underline (if immediately after
a line of text). Use numbered `##` headings for visual separation
between sections instead.


## Rule 8: Bold Labels Above Fences

When a code block needs a label (file name, function name, description),
put it as a bold line on its own, with a blank line between the label
and the fence.

Good:

**ingest/rates.py -- sync_rates function:**

~~~
def sync_rates(con, rates):
    con.execute("DELETE FROM rate")
    for r in rates:
        con.execute("INSERT INTO rate ...")
~~~

Bad (label on same line as fence) -- do not do this:

    **sync_rates:** ~~~
    def sync_rates(con, rates):
    ~~~

Bad (no blank line between label and fence) -- do not do this:

    **sync_rates:**
    ~~~
    def sync_rates(con, rates):
    ~~~


## Rule 9: Avoid Triple-Quote Strings Inside Fences

Python docstrings and multi-line SQL strings with triple quotes
inside fenced blocks can confuse the renderer. When possible:

- Move docstring text into the prose above the fence.
- For SQL strings embedded in Python, show just the SQL in a
  4-space indented block, then show the Python that uses it in
  a separate tilde fence.

If you must include triple-quote strings, use tilde fences (Rule 2),
which eliminates the backtick/triple-quote collision.


## Quick Checklist

Before finalizing a markdown document, verify:

- [ ] Zero lines starting with `#` inside any fenced block
- [ ] All fences use `~~~` (no backticks anywhere)
- [ ] No fence has a language hint (`~~~python`, `~~~sql`, etc.)
- [ ] Every pair of fences has at least one prose line between them
- [ ] No code block exceeds ~60 lines
- [ ] SQL, JSON, file trees, and shell examples use 4-space indentation
- [ ] No `---` horizontal rules anywhere in the document
- [ ] Bold labels are on their own line with a blank line before the fence
- [ ] No triple-quote strings inside fenced blocks (or tilde fences if unavoidable)
