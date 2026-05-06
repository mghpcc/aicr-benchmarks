#!/usr/bin/env bash
# Submit N randomly-chosen p2p_pair sbatch jobs from the population of all
# ordered (nodeA, nodeB, gpuA, gpuB) tuples across the cluster.
#
# Usage:    submit_random_pairs.sh <count> [rail|arbitrary]
#
#   <count>      number of pairings to sample and submit
#   <mode>       which population to sample from:
#                  rail       (default) -- gpuA == gpuB; tests the GPU's
#                              own rail.  |population| = 31*30*8       =  7440
#                  arbitrary  -- gpuA, gpuB independent; includes
#                              cross-rail pairs that traverse spine.
#                              |population| = 31*30*8*8                = 59520
#
#   In both modes A != B (no same-node pairs) and (A,B,...) and (B,A,...)
#   are distinct samples (each tests one direction).
#
# Reproducibility:
#   - If env var P2P_SEED is set, it is used as the PRNG seed.
#   - If P2P_SEED is unset, a fresh random seed is used per invocation, so
#     two calls with the same arguments produce different samples.
#   - The seed used is always printed so you can re-run with
#       P2P_SEED=<seed> submit_random_pairs.sh <count> <mode>
#     to reproduce the exact same set of pairings.
#
# Each sampled pairing is submitted via bin/submit_p2p_pair.sh, so the
# usual SBATCH_ACCOUNT / SBATCH_PARTITION env overrides apply.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [--exclude-nodes HOSTLIST] <count> [rail|arbitrary]

Submit <count> randomly-chosen point-to-point bandwidth tests, each as a
separate sbatch job (via submit_p2p_pair.sh).

Arguments:
  <count>     Number of pairings to sample and submit. Non-negative integer.
              If <count> exceeds the population size it is capped, with a
              warning to stderr.

  <mode>      Which population to sample from. Default: rail.
                rail        gpuA == gpuB; tests each GPU's own rail.
                            |population| = 31 * 30 * 8 = 7440
                arbitrary   gpuA, gpuB independent; includes cross-rail
                            pairs that traverse spine switches.
                            |population| = 31 * 30 * 8 * 8 = 59520
              In both modes nodeA != nodeB, and (A,B,...) and (B,A,...)
              are distinct samples (each tests one direction).

Options:
  --exclude-nodes HOSTLIST
              Skip these nodes; any pairing whose nodeA or nodeB is in
              HOSTLIST is dropped before sampling. HOSTLIST may be:
                - a comma-separated list of names:  b0005,b0010,b0011
                - a Slurm bracketed hostlist:       b[0005,0010-0012]
                - any mix of the two:               b0005,b[0010-0012]
              Expansion uses 'scontrol show hostnames'.

  -h, --help  Show this help and exit.

Environment variables:
  P2P_SEED            If set, used as the PRNG seed (reproducible). If
                      unset, a fresh seed is used per invocation. The seed
                      actually used is always echoed so you can re-run with
                      that exact sample.

  SBATCH_ACCOUNT      Forwarded to submit_p2p_pair.sh (default: test).
  SBATCH_PARTITION    Forwarded to submit_p2p_pair.sh (default: GPU2).

Examples:
  # Submit 5 random rail-aligned pairs (different sample each call):
  $(basename "$0") 5

  # Reproduce a previous random sample:
  P2P_SEED=12345 $(basename "$0") 5 rail

  # Sample 20 cross-rail pairs, excluding three nodes:
  $(basename "$0") --exclude-nodes b0005,b0017,b0023 20 arbitrary

  # Same, with Slurm-style range:
  $(basename "$0") --exclude-nodes 'b[0005,0017-0019]' 20 arbitrary

  # Override account/partition:
  SBATCH_ACCOUNT=myproj $(basename "$0") 10
EOF
}

exclude_input=""
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage; exit 0 ;;
    --exclude-nodes)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --exclude-nodes requires an argument" >&2
        echo "       run with --help for usage." >&2
        exit 1
      fi
      exclude_input="$2"
      shift 2
      ;;
    --exclude-nodes=*)
      exclude_input="${1#--exclude-nodes=}"
      shift
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do positional+=("$1"); shift; done
      ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2
      echo "       run with --help for usage." >&2
      exit 1
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done

if [[ ${#positional[@]} -lt 1 || ${#positional[@]} -gt 2 ]]; then
  usage >&2
  exit 1
fi

count="${positional[0]}"
mode="${positional[1]:-rail}"

if ! [[ "$count" =~ ^[0-9]+$ ]]; then
  echo "ERROR: count must be a non-negative integer (got '$count')" >&2
  echo "       run with --help for usage." >&2
  exit 1
fi

case "$mode" in
  rail|arbitrary) ;;
  *)
    echo "ERROR: mode must be 'rail' or 'arbitrary' (got '$mode')" >&2
    echo "       run with --help for usage." >&2
    exit 1
    ;;
esac

NODE_LO=1
NODE_HI=31
GPU_LO=0
GPU_HI=7

excluded=()
if [[ -n "$exclude_input" ]]; then
  if command -v scontrol >/dev/null 2>&1; then
    while IFS= read -r host; do
      [[ -n "$host" ]] && excluded+=("$host")
    done < <(scontrol show hostnames "$exclude_input")
  elif [[ "$exclude_input" == *"["* ]]; then
    echo "ERROR: --exclude-nodes value '$exclude_input' uses bracketed" >&2
    echo "       hostlist syntax which requires 'scontrol' (not on PATH)." >&2
    exit 1
  else
    IFS=',' read -ra excluded <<<"$exclude_input"
  fi
fi
exclude_csv=""
if [[ ${#excluded[@]} -gt 0 ]]; then
  exclude_csv="$(IFS=','; echo "${excluded[*]}")"
fi

seed="${P2P_SEED:-${RANDOM}${RANDOM}${RANDOM}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "# population: ordered (nodeA, nodeB, gpuA, gpuB) tuples in mode '${mode}'"
echo "#   nodes b$(printf '%04d' "$NODE_LO")..b$(printf '%04d' "$NODE_HI"), gpu ${GPU_LO}..${GPU_HI}"
if [[ ${#excluded[@]} -gt 0 ]]; then
  echo "# excluded nodes (${#excluded[@]}): ${excluded[*]}"
fi
echo "# count requested: ${count}"
echo "# seed used:       ${seed}"
exclude_arg=""
[[ -n "$exclude_csv" ]] && exclude_arg=" --exclude-nodes ${exclude_csv}"
echo "#   (re-run with: P2P_SEED=${seed} $(basename "$0")${exclude_arg} ${count} ${mode})"

if [[ "$count" -eq 0 ]]; then
  echo "# count=0; nothing to submit." >&2
  exit 0
fi

i=0
while read -r nA nB gA gB; do
  i=$((i + 1))
  echo "[${i}] submitting: ${nA} ${nB} ${gA} ${gB}"
  "$SCRIPT_DIR/submit_p2p_pair.sh" "$nA" "$nB" "$gA" "$gB"
done < <(
  awk -v seed="$seed" -v count="$count" -v mode="$mode" \
      -v lo="$NODE_LO" -v hi="$NODE_HI" \
      -v glo="$GPU_LO" -v ghi="$GPU_HI" \
      -v exclude_csv="$exclude_csv" '
    BEGIN {
      srand(seed + 0)
      if (exclude_csv != "") {
        n_ex = split(exclude_csv, ex_arr, ",")
        for (i = 1; i <= n_ex; i++) excluded[ex_arr[i]] = 1
      }
      n = 0
      for (a = lo; a <= hi; a++) {
        sa = sprintf("b%04d", a)
        if (sa in excluded) continue
        for (b = lo; b <= hi; b++) {
          if (a == b) continue
          sb = sprintf("b%04d", b)
          if (sb in excluded) continue
          if (mode == "rail") {
            for (g = glo; g <= ghi; g++) {
              n++
              A[n] = sa
              B[n] = sb
              GA[n] = g
              GB[n] = g
            }
          } else {
            for (ga = glo; ga <= ghi; ga++) {
              for (gb = glo; gb <= ghi; gb++) {
                n++
                A[n] = sa
                B[n] = sb
                GA[n] = ga
                GB[n] = gb
              }
            }
          }
        }
      }
      # Fisher-Yates shuffle.
      for (i = n; i >= 2; i--) {
        j = int(rand() * i) + 1
        t = A[i];  A[i]  = A[j];  A[j]  = t
        t = B[i];  B[i]  = B[j];  B[j]  = t
        t = GA[i]; GA[i] = GA[j]; GA[j] = t
        t = GB[i]; GB[i] = GB[j]; GB[j] = t
      }
      k = (count > n) ? n : count
      if (count > n) {
        print "# WARNING: requested " count " > population " n "; capping at " n \
              > "/dev/stderr"
      }
      for (i = 1; i <= k; i++) {
        print A[i], B[i], GA[i], GB[i]
      }
    }
  '
)
