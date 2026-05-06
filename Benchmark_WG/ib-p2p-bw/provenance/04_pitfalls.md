# 04 — Pitfalls and debugging lessons

The wrong turns we've already taken. **If you're modifying the code,
read this file before you change anything in [`bin/`](../bin/).**

Each entry: *Symptom* → *Cause* → *Fix* → *Where it lives*.

## 1. Cross-tool perftest pairing fails at the first packet

**Symptom.** Server `ib_read_bw` and client `ib_write_bw` happily
exchange QPN/LID/RKey/VAddr lines (the Ethernet handshake), then the
client immediately reports:

```
 Completion with error at client
 Failed status 9: wr_id 0 syndrom 0x8a
```

and the server reports `Couldn't read remote address` /
`Failed to exchange data between server and clients`. No data row
ever appears.

**Cause.** Status 9 = `IBV_WC_REM_OP_ERR`; Mellanox syndrome
**0x8a = remote access error**. The `ib_read_bw` server registers
its memory region with **READ-only** access flags. When the
`ib_write_bw` client posts an RDMA WRITE, the HCA tries to land
the payload into that MR, the remote rejects it because the region
isn't WRITE-accessible, and the QP transitions to error state. The
perftest handshake doesn't validate test-type compatibility, so
both sides happily set up and *then* fail.

**Fix.** Use the **same tool on both sides**. Default in this repo:
`ib_write_bw` server + `ib_write_bw` client (write-bw). Read-bw
variant: change both sides to `ib_read_bw`. Cross-tool combinations
are protocol-incompatible; don't try to "make them work."

**Where.** Server and client invocations near the bottom of
[`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch); explanatory
comment block at the top of the same file.

## 2. Parsing `nvidia-smi topo -m` for NUMA is fragile

**Symptom.** `nic_selection.txt` reported `numa=16-31`. That's a CPU
affinity range, not a NUMA index. `numactl --cpunodebind=16-31` is
wrong (and may even succeed silently while pinning to the wrong
CPUs).

**Cause.** The matrix's column header line includes multi-word
labels (`CPU Affinity`, `NUMA Affinity`, `GPU NUMA ID`) that get
split into separate fields by awk's default whitespace FS. The
field-position arithmetic that worked on a synthetic format
doesn't survive small per-cluster differences in column count or
the presence/absence of the `GPU NUMA ID` column.

**Fix.** Stop computing NUMA from the matrix. Read it directly
from sysfs:

```
cat /sys/class/infiniband/<dev>/device/numa_node
```

Single integer (or `-1` meaning "no affinity"). The matrix is still
parsed, but only for the **NIC PCIe-distance ranking**
(`PIX < PXB < PHB < NODE < SYS`), where awk's whitespace splitting
is correct enough.

**Where.** [`bin/select_nic_for_gpu.sh`](../bin/select_nic_for_gpu.sh) —
the bash trailer after the awk block reads sysfs.

**General lesson.** Prefer single-fact sources (sysfs, `ibstat`,
`scontrol show hostnames`) over column-position parsing of human-
formatted CLI output.

## 3. SLURM job cwd is *not* the submit directory on this cluster

**Symptom.** First successful submission reported (in
`results/.slurm/p2p-<jobid>.out`):

```
mkdir: cannot create directory '/var/spool/slurm/slurmd/results': Permission denied
mkdir: cannot create directory '/var/spool/slurm/slurmd/results': Permission denied
```

Nothing else got written.

**Cause.** On this cluster, the SLURM job's working directory
defaults to the slurmd spool (`/var/spool/slurm/slurmd/`), not the
directory `sbatch` was run from. A relative `mkdir -p results/...`
inside the script therefore tries to create the dir under
`/var/spool/...`, which the unprivileged user cannot write.

**Fix.** Wrapper passes `--chdir="$PWD"` to sbatch, and the sbatch
script also `cd`s into `${SLURM_SUBMIT_DIR:-$PWD}` early. Both
belt and suspenders, since some sites' SLURM configurations
ignore one or the other.

**Where.** `--chdir="$PWD"` in the `exec sbatch ...` block of
[`bin/submit_p2p_pair.sh`](../bin/submit_p2p_pair.sh); the `cd
"$ROOT"` near the top of
[`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch).

## 4. SLURM copies the sbatch script to the spool before exec

**Symptom.** The script at runtime computed
`SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` and
ended up with `SCRIPT_DIR=/var/spool/slurm/slurmd/job<id>`, so
`source $SCRIPT_DIR/select_nic_for_gpu.sh` (and similar) failed.

**Cause.** When you `sbatch /path/to/p2p_pair.sbatch`, slurmctld
*copies the script body* to the slurmd spool dir on the head node
of the job and runs that copy. The original path is gone from
`${BASH_SOURCE[0]}`'s perspective.

**Fix.** The wrapper exports the canonical install dir as an env
var:

```
sbatch ... --export="ALL,P2P_SCRIPT_DIR=$SCRIPT_DIR" ...
```

Inside the sbatch, look up helpers via `$P2P_SCRIPT_DIR` first,
falling back to `BASH_SOURCE`-based detection only for direct
(non-wrapper) sbatch invocations.

**Where.** Top of
[`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch) (the
`P2P_SCRIPT_DIR` resolution block); `--export=` flag in
[`bin/submit_p2p_pair.sh`](../bin/submit_p2p_pair.sh).

## 5. `su` audit events from compute nodes are normal SLURM internals

**Symptom.** auditd on `b0005` (or any compute node) emits:

```
b0005 su[<pid>]: (to <user>) root on none
... grantors=pam_rootok acct="<user>" exe="/usr/bin/su" ...
... pam_unix(su-l:session): session opened for user <user>(uid=...) by (uid=0)
```

Looks alarming. Looks like something in the test pipeline is
escalating.

**Cause.** It is **not** from this code. The signature
(`uid=0` caller, `auid=4294967295` = "audit-uid unset",
`grantors=pam_rootok`, `(to <user>) root on none`, no tty,
`su -l`) is the textbook fingerprint of `slurmd` (which runs as
root) dropping privileges to the job owner via `su -l <user>` to
launch `slurmstepd` for each `srun` step. This happens on every
compute node for every `srun` step of every job for every user on
this cluster.

The driver issues approximately **8 srun steps per submitted
job** (NIC pick × 2 nodes, topo capture × 2, `ibstat` × 2,
perftest server + client). So a `submit_random_pairs.sh 50`
generates ~400 such audit events spread across the sampled
nodes. That's expected, not a bug.

**Fix.** None warranted. Don't try to "silence" these — they're
telling you SLURM is doing its job. If audit volume becomes a
real concern, the per-side info-gathering can be coalesced into
a single `srun` per side (drops per-job count from ~8 to ~4),
but **discuss with the user before changing**: it's a structural
refactor, not a one-liner.

**Where.** N/A — no code change. See
[`02_behavioral_rules.md`](02_behavioral_rules.md) section B for
the principle.

## 6. Don't probe across nodes speculatively

**Symptom.** N/A — caught in self-audit before causing visible
trouble.

**Cause.** A previous version of
[`bin/record_switch_path.sh`](../bin/record_switch_path.sh)
had this fallback:

```bash
if ! command -v ibtracert >/dev/null 2>&1; then
  echo "(skipping ibtracert: not installed on submit host; trying via srun on $nodeA)"
  srun -N1 -w "$nodeA" --ntasks=1 bash -c "ibtracert ${lidA} ${lidB} 2>&1" || \
    echo "(ibtracert failed; ...)"
  exit 0
fi
```

That's exploratory probing across nodes — exactly what the
HPC-courtesy admonition forbids. It's also dead code in
practice (any IB-capable compute node has `ibtracert` from the
OFED stack).

**Fix.** Capability check + clean skip. One probe, one decision,
no fishing on other nodes.

**Where.**
[`bin/record_switch_path.sh`](../bin/record_switch_path.sh) —
the `if ! command -v ibtracert ...` block.

**General lesson.** `command -v` *once* is a check; a series of
`command -v` + cross-node retries is a probe. Resist the urge
to add the second one.

## 7. CPU-frequency warnings interleave with perftest data rows

**Symptom.** The client log contains lines like:

```
Conflicting CPU frequency values detected: 3295.612000 != 5031.014000. CPU Frequency is not max.
 8388608    40000            387.16             387.16             0.005769
```

interleaved freely between data rows.

**Cause.** perftest's CPU-frequency check fires whenever it sees
inconsistent governor states across cores during the test. On
this cluster the governor isn't pinned to performance mode, so
the warning is informative but harmless — actual measured BW is
still ~387 Gb/s on a 400 Gb/s NDR link (~97% line rate).

**Fix.** None. The summary parser intentionally tolerates these
lines: the regex requires the line to begin with
`[whitespace]*<digits>[whitespace]+<digits>[whitespace]+<numeric>`,
which the warning lines don't match.

**Caution.** If you ever change the summary regex (e.g. to a
different output format), regenerate it against a real client
log including these warning lines, not just clean output.

**Where.** Awk block in the `summarizing` step of
[`bin/p2p_pair.sbatch`](../bin/p2p_pair.sbatch).

## 8. Hostlist parsing relies on `scontrol show hostnames`

**Symptom.** Trying to use bracketed ranges (`b[0001-0003,0010]`)
on a host where `scontrol` isn't on PATH gives:

```
ERROR: --exclude-nodes value 'b[0001-0003,0010]' uses bracketed
       hostlist syntax which requires 'scontrol' (not on PATH).
```

**Cause / Fix.** The script delegates hostlist expansion to
`scontrol show hostnames "$hostlist"` so we get Slurm's exact
syntax for free. The fallback (no `scontrol`) only handles
literal comma-separated names, by design — anything more would
mean re-implementing Slurm's hostlist grammar, which is
fiddly and unnecessary.

**Where.** Hostlist-expansion block in
[`bin/submit_random_pairs.sh`](../bin/submit_random_pairs.sh).

**General lesson.** Don't reimplement Slurm's hostlist syntax.
If a user environment lacks `scontrol`, you're not running on a
Slurm cluster anyway.

## 9. Concurrent perftest pairs collide on the default port (preemptive)

**Symptom (would-be).** Two or more `ib_write_bw` processes start on
the same node with no `-p` flag. perftest defaults to TCP `18515` for
its handshake; only the first listener binds, the rest fail with
`bind() failed` / `Address already in use`, or worse, the clients
non-deterministically pair up with the wrong server.

**Cause.** The single-pair tools never had to think about this --
each `bin/p2p_pair.sbatch` job owns its allocation and runs exactly
one server and one client. The concurrent driver runs `K` of each on
(potentially) the same two nodes, e.g. use case 1 with eight pairs
between `b0025` and `b0026`.

**Fix.** Pre-assign a unique port per pair in the submitter:
`port_i = 18515 + i`, recorded as column 2 of the materialized
`pairs.tsv` (`idx port nodeA nodeB gpuA gpuB`). Both server and
client invocations in
[`bin/concurrent/p2p_concurrent.sbatch`](../bin/concurrent/p2p_concurrent.sbatch)
pass `-p $port`. There is no port reuse across concurrent pairs in a
single allocation.

**Where.** Port assignment in the materialization block of
[`bin/concurrent/submit_concurrent.sh`](../bin/concurrent/submit_concurrent.sh);
inline `ib_write_bw -p $port` at `[4/6]` and `[5/6]` of
[`bin/concurrent/p2p_concurrent.sbatch`](../bin/concurrent/p2p_concurrent.sbatch).

**General lesson.** When fan-out goes from 1 to K on the same node,
default ports are no longer adequate. Centralize the port assignment
in the driver/submitter rather than letting each pair pick.

## 10. Per-pair bandwidth below line rate in concurrent runs is the test, not a bug

**Symptom.** `summary.txt` for a use-case-1 run between two nodes
shows each of 8 pairs at ~50 Gb/s instead of the ~387 Gb/s a
single-pair run posts. Looks like every pair got slow.

**Cause.** It is **not slow.** Eight rails each pushing ~50 Gb/s into
the same pair of nodes lands the *aggregate* at ~387 Gb/s -- which is
the per-NIC line rate. A single pair has the whole NIC's egress to
itself; eight pairs share it (and possibly share leaf-switch ports).
The aggregate sum at the bottom of `summary.txt` is the real
headline.

**Fix.** None. Read `summary.txt` for the aggregate; per-pair rows
are diagnostic, showing how the load distributes.

**Where.** Aggregate computation at the end of
[`bin/concurrent/p2p_concurrent.sbatch`](../bin/concurrent/p2p_concurrent.sbatch).
The
[`bin/concurrent/README.md`](../bin/concurrent/README.md) calls this
out explicitly under "Per-pair bandwidth below line rate is expected."

**General lesson.** When the test is "what does the fabric do under
load," per-stream BW dropping is the signal, not noise. Don't try to
explain it away.

## 11. srun-step audit volume scales with K in concurrent runs

**Symptom (preemptive).** A single concurrent submission with `K=8`
generates ~25 srun steps in one allocation:

- 1 NIC pick per unique `(node, gpu)` (cached; usually `~2K` calls
  worst case, less if pairs share endpoints),
- 1 `nvidia-smi topo -m` per unique node (~`2K` calls worst case),
- 1 `record_switch_path.sh` per pair (`K` calls -- internally each
  one issues 2 `ibstat` srun calls + 1 `ibtracert` locally),
- 1 server srun per pair (`K`),
- 1 client srun per pair (`K`).

Each srun step generates the standard `slurmd -> su -l user -> exec
slurmstepd` audit signature on its node (see pitfall 5).

**Cause.** Same as pitfall 5 -- this is how SLURM works on this
cluster, not something the code is doing.

**Fix.** None warranted by default. The srun-step count is bounded
and proportional to `K`; the audit events are expected. If a future
operator complains about absolute volume, the
`record_switch_path.sh` per-pair calls are the obvious place to
batch (one ibstat call per unique `(node, nic)` instead of two per
pair) -- but **discuss before changing**, because that's a structural
refactor and switch-path recording is best-effort/secondary anyway.

**Where.** N/A -- structural property of the driver. See pitfall 5
and [`02_behavioral_rules.md`](02_behavioral_rules.md) section B for
the principle.

## 12. Concurrent driver: numactl check must run on the compute node

**Symptom.** First real-cluster run of the concurrent driver
produced "(no data row found)" for every pair. Each per-pair log
contained:

```
srun: error: bN: task 0: Exited with exit code 127
/usr/bin/bash: line 1: numactl: command not found
```

**Cause.** The first cut of
[`bin/concurrent/p2p_concurrent.sbatch`](../bin/concurrent/p2p_concurrent.sbatch)
unconditionally embedded `numactl --cpunodebind=$numa ...` in the
bash command sent to the compute node:

```bash
cmd="numactl --cpunodebind=$numa --membind=$numa ib_write_bw ..."
srun -N1 -w "${A[i]}" --ntasks=1 bash -c "$cmd" > "$log" 2>&1 &
```

On clusters where `numactl` isn't on the default PATH for srun-spawned
shells (it is for interactive logins; not always for srun), every
perftest invocation died at `numactl` lookup with exit 127. The
single-pair driver doesn't have this bug because it goes through
[`bin/run_perftest.sh`](../bin/run_perftest.sh), which runs `command -v
numactl` *on the compute node* (inside the `bash run_perftest.sh ...`
that srun executes there) and falls back gracefully.

**Fix.** Move the `command -v numactl` check into the bash -c string
so it runs on the compute node, with the same falls-back-cleanly
semantics as `run_perftest.sh`:

```bash
perftest="ib_write_bw -d $nic --use_cuda=$gpu -q 8 -a --report_gbits -p $port"
if [[ -n "$numa" && "$numa" != "N/A" ]]; then
  cmd="if command -v numactl >/dev/null 2>&1; then exec numactl --cpunodebind=$numa --membind=$numa $perftest; else exec $perftest; fi"
else
  cmd="exec $perftest"
fi
```

**Where.** Phases [4/6] and [5/6] of
[`bin/concurrent/p2p_concurrent.sbatch`](../bin/concurrent/p2p_concurrent.sbatch).

**General lesson.** When deciding "is tool X available?", run the
check **where the tool will actually be invoked** -- not on the
submit/head node, which has different PATH and different mounts.
[`bin/run_perftest.sh`](../bin/run_perftest.sh) gets this right by
construction; inline-perftest paths must replicate it.

## 13. Concurrent driver: --ntasks-per-node must equal max pairs per node

**Symptom (preemptive; uncovered the same run as pitfall 12).** After
fixing the numactl path, the next failure mode is more subtle: with
the wrong `--ntasks-per-node`, the K parallel server (and client)
sruns silently serialize. The first server srun on `nodeA` takes the
single task slot; the others queue waiting for it; the first one's
`ib_write_bw` blocks waiting for a client that hasn't started yet
(because the client sruns are also queued); after walltime, the
driver wakes up and reports nothing measured.

**Cause.** A bare `#SBATCH --ntasks-per-node=1` (or the sbatch
default) gives the job exactly one task slot per node. SLURM
serializes step requests beyond that. The single-pair driver works
fine at `1` because it uses one srun per node at a time; the
concurrent driver runs `K` per node simultaneously.

**Fix.** [`bin/concurrent/submit_concurrent.sh`](../bin/concurrent/submit_concurrent.sh)
counts how often each node appears across both the `nodeA` and
`nodeB` columns of the materialized TSV, takes the max, and passes
that as `--ntasks-per-node` on the `sbatch` command line. For
example:

- Use case 1, 8 pairs between two nodes -> 8.
- Use case 2, spray of count 8 from one source -> 8 (source carries 8
  steps; each random target carries at most a handful).
- Use case 3, K disjoint pairs with M GPU pairings each -> M.

The driver's `srun` calls also pass `--overlap` as defense-in-depth
so a future operator who tweaks `--ntasks-per-node` doesn't accidentally
trigger this exact failure again.

**Where.** `max_per_node` computation in
[`bin/concurrent/submit_concurrent.sh`](../bin/concurrent/submit_concurrent.sh)
(after the unique-nodes block); the `--ntasks-per-node="$max_per_node"`
flag in the same file's `exec sbatch ...` block; the `srun --overlap`
calls in phases [4/6] and [5/6] of
[`bin/concurrent/p2p_concurrent.sbatch`](../bin/concurrent/p2p_concurrent.sbatch).

**General lesson.** When a driver fans out K parallel `srun` steps
onto the same node, the job's task-slot allocation has to fan out
too. SLURM doesn't warn; it just queues. Compute the requirement
from the workload and pass it explicitly at submit time.
