# b200-ib-cuda-point-to-point

Tools for measuring point-to-point GPU↔GPU bandwidth between B200 nodes over a
rail-optimized NDR InfiniBand fabric, via CUDA-aware `perftest`.

## What this does (v1)

One SLURM job tests **one direction** between **one pair of GPUs**:

- `nodeA` runs `ib_write_bw -d <nicA> --use_cuda=<gpuA> -q 8 -a --report_gbits`         (server)
- `nodeB` runs `ib_write_bw -d <nicB> --use_cuda=<gpuB> -q 8 -a --report_gbits <nodeA>` (client)

The client writes to the server, so this measures RDMA-WRITE bandwidth in
the direction **`nodeB` → `nodeA`**. To test the reverse direction, submit a
second job with the node arguments swapped.

Per side, the rail-correct `mlx5_*` device is auto-selected from
`nvidia-smi topo -m` (closest PCIe affinity to the requested GPU), the NUMA
node is read from `/sys/class/infiniband/<dev>/device/numa_node`, and the
perftest process is NUMA-pinned (`numactl --cpunodebind --membind`).
The IB switch path between the two HCAs is recorded best-effort via
`ibtracert`.

## Layout

```
bin/
  submit_p2p_pair.sh      wrapper: sets account/partition/nodelist, calls sbatch
  p2p_pair.sbatch         the SLURM driver (the main deliverable)
  select_nic_for_gpu.sh   parse `nvidia-smi topo -m`, pick rail-correct mlx5 + NUMA
  run_perftest.sh         NUMA-pinned wrapper around ib_read_bw / ib_write_bw
  record_switch_path.sh   best-effort `ibtracert` between two HCAs
results/
  <nodeA>-gpu<N>/                                # server endpoint
    <nodeB>/                                     # client node
      <nodeA>-gpu<N>__<nodeB>-gpu<M>/            # full pair name
        <YYYY-MM-DD_HHMMSS>/                     # one dir per run
  .slurm/                                        # raw sbatch stdout
    <jobid_lo>-<jobid_hi>/                       # bucketed 2000 ids per dir
      p2p-<jobid>.out
```

## Usage

```bash
# Defaults: --account=test --partition=GPU2 (override via env)
bin/submit_p2p_pair.sh b0025 b0026 0 0

# Override account / partition:
SBATCH_ACCOUNT=myproj SBATCH_PARTITION=GPU2 \
  bin/submit_p2p_pair.sh b0025 b0026 0 0

# Or invoke sbatch directly:
sbatch --account=test --partition=GPU2 --nodelist=b0025,b0026 \
       bin/p2p_pair.sbatch b0025 b0026 0 0
```

Each run produces a dated subdirectory under
`<submit_dir>/results/<nodeA>-gpu<N>/<nodeB>/<nodeA>-gpu<N>__<nodeB>-gpu<M>/`,
where `<submit_dir>` is the directory you ran `submit_p2p_pair.sh` from
(i.e. SLURM's `$SLURM_SUBMIT_DIR`). The extra nesting (server endpoint /
client node / pair name) keeps the top-level `results/` listing small even
across thousands of runs. Multiple runs of the same pair never overwrite.

Direct `sbatch` invocations: pass
`--chdir=$PWD --export=ALL,P2P_SCRIPT_DIR=/abs/path/to/bin` so the script can
locate its helpers and write outputs into your submit directory rather than
the slurmd spool directory.

## Output files (per run)

| file                                  | contents                                                     |
| ------------------------------------- | ------------------------------------------------------------ |
| `params.txt`                          | the four CLI args, timestamp, SLURM job id, nodelist         |
| `nic_selection.txt`                   | resolved `(nic, numa)` for each (node, gpu)                  |
| `topo.<nodeA>.txt`, `topo.<nodeB>.txt`| `nvidia-smi topo -m` snapshot from each node                 |
| `switch_path.txt`                     | LIDs and `ibtracert` hop list (or failure note)              |
| `server.<nodeA>.ib_write_bw.log`      | full server-side perftest output                             |
| `client.<nodeB>.ib_write_bw.log`      | full client-side perftest output (the bandwidth table)       |
| `summary.txt`                         | one-line headline: last data row from the client log         |

## Assumptions / caveats

- **Same tool on both sides (`ib_write_bw`/`ib_write_bw`).** Mixing
  `ib_read_bw` server with `ib_write_bw` client passes the Ethernet handshake
  but fails at the first packet with `IBV_WC_REM_OP_ERR` / syndrome 0x8a:
  the read-side server registers its memory region with READ-only access, so
  the client's RDMA_WRITE is rejected. To measure read-bandwidth instead,
  change *both* sides in `bin/p2p_pair.sbatch` to `ib_read_bw`.
- **Bare hostnames work for the client connect target.** `ib_write_bw b0025`
  resolves the host's IP and lets RDMA-CM negotiate the IB connection.
- **`numactl` is available on compute nodes.** If absent, the wrapper
  silently runs without pinning.
- **`ibtracert` is best-effort.** Some clusters' subnet managers restrict it;
  failures are logged but don't fail the bandwidth test.
- **Nodelist must be passed at submit time.** The sbatch script re-uses the
  job's allocated nodes via `srun -w`; it does not fan out beyond them.
- **CPU frequency.** perftest may print `Conflicting CPU frequency values
  detected: ... CPU Frequency is not max.` This is informational; on this
  cluster you still hit ~387 / 400 Gb/s line rate, so it's not worth chasing
  unless you're investigating a slower-than-expected pair.

## Not included in v1 (deliberately)

- No outer driver enumerating all pairs across the cluster (next step).
- No bidirectional / reverse-direction automation in a single job.
- No CSV/JSON aggregation across runs (`summary.txt` is grep-friendly).
- No retries on perftest failure.
- No same-node (NVLink) tests — out of scope for IB P2P.
