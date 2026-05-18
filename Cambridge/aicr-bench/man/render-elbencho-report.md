# render-elbencho-report.py

## Purpose

Render Elbencho parsed rows into an ASCII or Markdown report.

## Usage

```text
scripts/report/render-elbencho-report.py --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--results-root <path>] [--ascii] [--markdown] [--both] [--write]
```

## Options

- `--date <value>`: UTC date to render.
- `--cluster <name>`: `b200` or `rtxpro6000`.
- `--results-root <path>`: Results root. Default: `results`.
- `--ascii`: Print the ASCII-style report.
- `--markdown`: Render Markdown.
- `--both`: Render both ASCII and Markdown.
- `--write`: Write Markdown under `results/reports/<date>/`.
- `--help`: Print help.

## Examples

Render and write a B200 report:

```bash
scripts/report/render-elbencho-report.py --date 2026-05-17 --cluster b200 --both --write
```

## Outputs

With `--write`, the renderer writes:

```text
results/reports/<date>/elbencho-<cluster>.md
```
