# SHARP 2-node debugging log

Goal: run `2nodes-2gpus-sharp.sh` (2 B200 GPUs/node × 2 nodes = 4 GPUs) with SHARP and
measure whether 2-node AllReduce bandwidth improves.

## Timeline

### Job 36273 / 36275 — pending forever
- Submitted 8-GPU (`2nodes-8gpus-sharp.sh`) and 2-GPU SHARP jobs.
- Both stuck `PD (Resources)` because `#SBATCH --exclusive` requests whole nodes.
- Also: scripts hardcode `#SBATCH -p GPU2`, which no longer exists. Current B200
  partition is `b200-batch`. Submit with `sbatch -p b200-batch <script>`.
- Action: cancelled both; removed `--exclusive` from `2nodes-2gpus-sharp.sh`.

### Job 36294 — FAILED in 11 s (exit 131), MPI binding error
- Symptom (every `mpirun`, all collectives): job aborts at launch with
  ```
  Open MPI tried to bind a new process, but something went wrong.
  Error message: hwloc_set_cpubind returned "Error" for bitmap "0"
  Location: orte/mca/rtc/hwloc/rtc_hwloc.c:382
  2 total processes failed to start
  ```
- No benchmark ran. NOT a SHARP problem (sharp_hello probe still showed all 9 NICs OK).
- Root cause: removing `--exclusive` placed the job on a **shared** node. Slurm then
  hands the job a restricted CPU cpuset. Open MPI's default binding policy
  (bind-to core, amplified by `--gpu-bind=closest`) tries to bind ranks to CPUs
  outside that cpuset → `hwloc_set_cpubind` fails before the app starts.
- Fix: add `--bind-to none` to every `mpirun` so Open MPI does not bind ranks to
  CPUs (Slurm/cgroup still constrains them). Applied to both the loop and the
  forced-CollNet all_reduce mpirun.
- Trade-off: `--bind-to none` removes CPU affinity → possibly slightly noisier
  numbers, acceptable for a SHARP bandwidth check. Alternative would be to restore
  `--exclusive` (but then back to long pending).

### Job 36295 — SUCCESS with `--bind-to none`
- Ran clean through all collectives in 5 min. Binding error gone.
- Forced all_reduce did NOT crash this time (unlike 8-GPU runs): at 4 GPUs (2/node)
  CollNet ran end-to-end `via COLLNET/SHARP/GDRDMA`, validation 0 wrong.
- 2 "Test failure" lines = hypercube validation (known nccl-tests 2.18.3 bug), not SHARP.
- Problem: NCCL_DEBUG=INFO produced a 1 GB log; per-call COLL debug interleaves into the
  perf table → per-size busbw columns unreadable. Only the clean `# Avg bus bandwidth`
  lines are usable.

### Job 36306 — clean A/B (NCCL_DEBUG off) — the authoritative numbers
- `2nodes-2gpus-sharp-ab.sh`: all_reduce twice, SHARP off (Ring) then SHARP on (forced
  CollNet), debug off → clean tables.
- Result: SHARP ~9 % SLOWER than Ring at large sizes (16 GB: 75.1 vs 82.1 GB/s busbw),
  only wins at 64 MB. See `results_sharp.md`.

## Resolution / lessons
1. Submit B200 jobs with `sbatch -p b200-batch` (GPU2 gone).
2. On a non-`--exclusive` (shared) allocation, add `--bind-to none` to every `mpirun` or
   Open MPI's core binding fails (`hwloc_set_cpubind ... bitmap "0"`).
3. For readable perf tables, turn NCCL_DEBUG OFF; only enable it to verify SHARP channels.
4. At 4 GPUs the forced-CollNet AllReduce works but gives no benefit; the 8-GPU crash
   (`no algorithm/protocol available`) remains the real blocker to SHARP paying off.

## 8-GPU/node CollNet crash — ROOT-CAUSED and FIXED (job 36311)

Symptom (prior 8-GPU runs 16185/16187/16188/16192/16209): forced all_reduce
(`NCCL_ALGO=CollNetChain,CollNetDirect`, `NCCL_PROTO=Simple`, Ring removed) crashes:
`no algorithm/protocol available for function AllReduce`.

Root cause (from log 16209): consistent failure on **rank 7** (the 8th GPU) only:
```
[7] sharp_plugin.c:400 NCCL WARN NET/IB : SHARP coll init error: Cannot create SHARP job(-11)
[7] ... Begin job id: ... failed with status: Unknown port
[7] NET/IB ... HCA 8 'mlx5_12'  LID 175
```
NCCL maps GPU 7 → **mlx5_12** (HCA 8). mlx5_12 is a valid IB NIC (GDRDMA works) but its
port is NOT on the SHARP tree, so sharpd rejects it ("Unknown port"). One missing rank →
CollNet can't form across all 16 ranks → AllReduce has no usable CollNet algo → crash
when Ring is removed. (`sharp_hello` probe missed this: it opens a context but never
creates a real SHARP job, so mlx5_12 falsely reported "OK".)

Fix: add mlx5_12 to the exclusion list:
`NCCL_IB_HCA="^mlx5_7,mlx5_8,mlx5_9,mlx5_10,mlx5_12"`
→ exactly 8 SHARP-good NICs (mlx5_0..6 + mlx5_11) for 8 GPUs; rank 7 uses mlx5_11.

Result (job 36311, clean A/B, nodes b0020+b0024): SUCCESS. No crash, validation 0 wrong.
AllReduce busbw 16 GB: **Ring 162.7 → SHARP 357.2 GB/s (2.2×)**; avg 81.1 → 160.6 (2.0×).
Peak exceeds the ~214 GB/s GDRDMA bidir ceiling. See `results_sharp.md`.

Note: NCCL's tuner still rates CollNet ~69 GB/s << Ring ~204, so SHARP must be **forced**
via `NCCL_ALGO=CollNetChain,CollNetDirect` + `NCCL_PROTO=Simple`; it is never auto-selected.
