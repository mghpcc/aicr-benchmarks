# render-topology-map.py

## Purpose

Render a single-node GPU topology map from existing AICR GPU topology evidence.

The renderer writes static HTML/SVG plus a graph JSON sidecar from existing
GPU topology captures.

## Usage

```bash
scripts/lib/run-repo-python.sh scripts/report/render-topology-map.py \
  --summary results/by-date/<date>/parsed/<cluster>/nodes/<node>/gpu-topology/<run_id>/summary.json \
  --output-dir results/reports/<date>/topology-map \
  --format both
```

Lookup mode selects the latest parsed topology run for one node:

```bash
scripts/lib/run-repo-python.sh scripts/report/render-topology-map.py \
  --date <date> \
  --cluster <b200|rtxpro6000> \
  --node <node>
```

## Options

- `--summary <path>`: Parsed GPU topology `summary.json`.
- `--results-root <path>`: Results root for lookup mode. Default: `results`.
- `--date <YYYY-MM-DD>`: Date for lookup mode.
- `--cluster <b200|rtxpro6000>`: Cluster for lookup mode.
- `--node <name>`: Node for lookup mode.
- `--output-dir <path>`: Output directory. Default:
  `results/reports/topology-map`.
- `--format <html|svg|both>`: Output format. Default: `html`.
- `--help`: Print help.

## Output

The renderer writes:

```text
topology-map-<cluster>-<node>-<run_id>.html
topology-map-<cluster>-<node>-<run_id>.svg
topology-map-<cluster>-<node>-<run_id>.json
```

The JSON sidecar uses schema `aicr.topology_graph.v1` and records source
artifacts, graph nodes, graph edges, parser warnings, and source summary
metadata.
