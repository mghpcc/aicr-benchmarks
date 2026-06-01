# Elbencho Studies

Purpose: index Elbencho storage studies and collection guidance.

Elbencho studies report filesystem-observed storage behavior for small-block,
small-file, metadata, and peak-cluster workloads. Study rows include the target
root, node list, CPU allocation, workload shape, repeat count, and artifact
provenance needed to interpret the measurement.

## Studies

| Study | Platform | Workloads | Result Type | Results |
| --- | --- | --- | --- | --- |
| [B200 Elbencho storage study](studies/b200-storage-2026-05-17.md) | B200 | One-node small-block, small-file, metadata; supplemental 31-node historical peaks | Study result, with memo status `Met` | [Results](studies/b200-storage-2026-05-17.md#result-summary) |

## Study Scope

The B200 storage study includes:

- one-node parameter sweeps for `small-block`, `small-file`, and `metadata`;
- five-sample confirmation repeats for selected one-node candidates;
- supplemental 31-node historical peak read/write points;
- artifact bundles, provenance JSON, and checksum files.

The peak-cluster memo requirement is met by later supplemental 31-node historical peak
evidence. Those rows are peak points, not medians.

## Collection Guidance

Use [submit-elbencho.sh](../../../man/submit-elbencho.md) or
`make benchmark-elbencho` for study rows. Keep `ELBENCHO_TARGET_ROOT` explicit
so scratch path and cleanup behavior are visible in rendered reports.

Recommended collection shape:

- `small` profile for study rows.
- One-node `small-block`, `small-file`, and `metadata` calibration rows.
- Confirmation repeats for selected one-node parameters.
- B200 `peak-cluster` row across the selected peak node set.
- Serialized repeats through Slurm dependencies.
- Explicit `NODELIST` for applied examples unless the command is explicitly
  testing `FROM_NODE_REPORT=1`.

## Storage Pressure Policy

Elbencho measurements change with concurrency against VAST or scratch storage.
Repeat samples should run serially through
[submit-elbencho.sh](../../../man/submit-elbencho.md)'s dependency chain unless
the study is intentionally measuring concurrent pressure.

## Related Evidence

Elbencho records filesystem-observed benchmark behavior. Node-local GPU Direct
Storage readiness is covered by the [GDS module](../gds/).
