# submit-hpl-mxp.sh

## Purpose

Resolve and optionally submit a Slurm job for an NVIDIA HPL-MxP row.

## Usage

```bash
scripts/benchmark/submit-hpl-mxp.sh \
  --cluster <b200|rtxpro6000> \
  --nodes <1|2|4|8|16> \
  --preset <smoke|staged|campaign-candidate> \
  --nodelist <node[,node...]> \
  [--apply]
```

Default behavior is dry-run. The script prints the resolved matrix size, block
size, processor grid policy, image path, Slurm partition, explicit node list,
and `sbatch` command. Add `--apply` only after reviewing the plan.

## Important Options

| Option | Meaning |
| --- | --- |
| `--cluster` | Cluster family, `b200` or `rtxpro6000`. |
| `--nodes` | Slurm node count. |
| `--preset` | `smoke`, `staged`, or `campaign-candidate`. |
| `--matrix-size` | Matrix size `N`, or `auto`. |
| `--nb` | Block size `NB`, or `auto`. |
| `--nprow`, `--npcol` | Processor-grid override, or `auto`. |
| `--nodelist` | Explicit comma-separated node list. |
| `--time` | Slurm time limit. |
| `--test-loop` | HPL-MxP loop count. |
| `--apply` | Submit the Slurm job. |

## Example

```bash
scripts/benchmark/submit-hpl-mxp.sh \
  --cluster b200 \
  --nodes 1 \
  --preset smoke \
  --nodelist b0001
```

## Output

Applied jobs write Slurm output under `results/slurm/` and run artifacts under
`results/by-date/<date>/raw/<cluster>/multi-node/hpl-mxp/<run_id>/`.
