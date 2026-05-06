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
