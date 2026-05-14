#!/usr/bin/env python3
"""Check public docs link prose mentions of public scripts to man pages."""

from __future__ import annotations

import re
import sys
from pathlib import Path


FENCE_RE = re.compile(r"(?ms)^(`{3,}|~{3,}).*?^\1[ \t]*$")
INLINE_CODE_RE = re.compile(r"`[^`\n]+`")
LINK_RE = re.compile(r"\[[^\]]+\]\([^)]+\)")
MAN_LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
SCRIPT_PATH_RE = re.compile(r"(?:^|[\s`])(?:\./)?(?:scripts|Cambridge)/[^\s`]+/([A-Za-z0-9_.-]+\.(?:sh|py))")


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def load_public_commands(root: Path) -> dict[str, str]:
    readme = root / "man" / "README.md"
    commands: dict[str, str] = {}
    for match in MAN_LINK_RE.finditer(readme.read_text(encoding="utf-8")):
        name, href = match.groups()
        if name.endswith((".sh", ".py")):
            commands[name] = href
    return commands


def strip_fenced_blocks(text: str) -> str:
    return FENCE_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)


def strip_inline_code_and_links(line: str) -> str:
    line = LINK_RE.sub("", line)
    return INLINE_CODE_RE.sub("", line)


def markdown_files(root: Path) -> list[Path]:
    skip_dirs = {"graphify-out", ".git", "results"}
    files: list[Path] = []
    for path in root.rglob("*.md"):
        rel_parts = set(path.relative_to(root).parts)
        if rel_parts & skip_dirs:
            continue
        if path.relative_to(root).parts[0] == "man":
            continue
        files.append(path)
    return sorted(files)


def check_docs(root: Path, commands: dict[str, str]) -> list[str]:
    failures: list[str] = []
    names = sorted(commands, key=len, reverse=True)
    for path in markdown_files(root):
        text = strip_fenced_blocks(path.read_text(encoding="utf-8"))
        for line_number, line in enumerate(text.splitlines(), start=1):
            prose = strip_inline_code_and_links(line)
            for name in names:
                if re.search(rf"(?<![A-Za-z0-9_.-]){re.escape(name)}(?![A-Za-z0-9_.-])", prose):
                    failures.append(
                        f"{path.relative_to(root)}:{line_number}: prose mention of {name} must link to man/{commands[name]}"
                    )
    return failures


def check_man_inventory(root: Path, commands: dict[str, str]) -> list[str]:
    failures: list[str] = []
    for name, href in commands.items():
        if not (root / "man" / href).is_file():
            failures.append(f"man/README.md: {name} links to missing man/{href}")
    return failures


def check_documented_scripts_have_man_pages(root: Path, commands: dict[str, str]) -> list[str]:
    failures: list[str] = []
    public_names = set(commands)
    for path in markdown_files(root):
        text = path.read_text(encoding="utf-8")
        for match in SCRIPT_PATH_RE.finditer(text):
            name = match.group(1)
            if name not in public_names:
                failures.append(
                    f"{path.relative_to(root)}: documented script path {name} is not listed in man/README.md"
                )
    return sorted(set(failures))


def main() -> int:
    root = repo_root()
    commands = load_public_commands(root)
    failures = []
    failures.extend(check_man_inventory(root, commands))
    failures.extend(check_docs(root, commands))
    failures.extend(check_documented_scripts_have_man_pages(root, commands))
    if failures:
        print("Man-link check failed:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print("Man-link check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
