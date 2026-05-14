# run-hpl-mxp.sh

## Purpose

Run one guarded HPL-MxP row inside a Slurm allocation and write canonical
AICR-Bench artifacts.

Operators usually call this through `scripts/benchmark/submit-hpl-mxp.sh` or
`make benchmark-hpl-mxp`; direct use is for debugging an existing allocation.

## Usage

```bash
scripts/benchmark/run-hpl-mxp.sh \
  --cluster <b200|rtxpro6000> \
  --nodes <count> \
  --preset <smoke|staged|campaign-candidate> \
  --matrix-size <N> \
  --nb <NB> \
  --nprow <auto|rows> \
  --npcol <auto|cols>
```

## Captured Artifacts

- resolved HPL-MxP command;
- stdout and stderr;
- cross-node `nvidia-smi -L` preflight;
- parsed `summary.json`, `status.json`, and `record.json`;
- by-date index row for report discovery.

## Runtime

The runner uses `${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif` unless
an image override is supplied. It launches one MPI rank per GPU through Slurm
and records the processor grid used for the run.
