#!/usr/bin/env bash
# Emit a TSV pair-list for use case 3: K disjoint node pairs (so 2K
# distinct nodes participate), each pair carrying M concurrent GPU-GPU
# pairings.  All pairings are emitted as one TSV stream and run together
# in one SLURM allocation.
#
# Usage:
#   gen_random_pair_sets.sh <K> [M] [rail|arbitrary]
#                           [--balance | --no-balance]
#                           [--exclude-nodes HOSTLIST]
#
#     K              number of disjoint node pairs (uses 2*K distinct nodes)
#     M              GPU-GPU pairings per node pair
#                       default 8 in rail mode
#                       default 1 in arbitrary mode
#     rail           gpuA == gpuB (rail-aligned; default)
#     arbitrary      gpuA, gpuB independent
#     --balance      (default) every (node, gpu) appears in at most one
#                    row across the whole TSV.  Combined with the K
#                    disjoint node pairs, this means each used GPU has
#                    exactly one partner, on exactly one other node.
#                    Caps M at 8 in arbitrary mode (each side has 8 GPUs;
#                    can't draw more than 8 distinct values).  No effect
#                    in rail mode -- rail mode is structurally already
#                    balanced (M distinct GPU indices used the same on
#                    both sides).
#     --no-balance   opt out: in arbitrary mode, the same gpuA value may
#                    appear in multiple rows of one node pair (M up to
#                    64).  Use when you want to load a given source GPU
#                    against several remote GPUs.  --off-balance is
#                    accepted as a synonym.
#     --exclude-nodes HOSTLIST   drop these nodes from the population
#                                (comma list, Slurm bracketed hostlist,
#                                or mix; expansion via 'scontrol show
#                                hostnames')
#
# Reproducibility (matches submit_random_pairs.sh):
#   - If P2P_SEED is set, it's used as the awk PRNG seed.
#   - If unset, a fresh seed is generated per call and printed.
#   - The seed used is always echoed in a '# seed: ...' comment row.

set -euo pipefail

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") <K> [M] [rail|arbitrary]
                            [--balance | --no-balance]
                            [--exclude-nodes HOSTLIST]
  K               number of disjoint node pairs (>=1)
  M               GPU-GPU pairings per node pair
                  (default 8 rail, 1 arbitrary)
  rail|arbitrary  GPU-pairing mode (default rail)
  --balance       (default) each (node, gpu) appears in at most one row.
                  Caps M at 8 in arbitrary mode.  No effect in rail mode
                  (rail is structurally always balanced).
  --no-balance    opt out: arbitrary mode may reuse a side's GPU across
                  rows (M up to 64).  --off-balance accepted as synonym.
  --exclude-nodes HOSTLIST  comma list, Slurm bracketed, or mix

env:
  P2P_SEED        if set, used as PRNG seed for reproducibility
EOF
  exit 1
}

NODE_LO=1
NODE_HI=31
GPU_LO=0
GPU_HI=7

exclude_input=""
balance=1
positional=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    --balance) balance=1; shift ;;
    --no-balance|--off-balance) balance=0; shift ;;
    --exclude-nodes)
      [[ $# -ge 2 ]] || { echo "ERROR: --exclude-nodes requires an argument" >&2; exit 1; }
      exclude_input="$2"; shift 2 ;;
    --exclude-nodes=*)
      exclude_input="${1#--exclude-nodes=}"; shift ;;
    -*)
      echo "ERROR: unknown flag: $1" >&2; usage ;;
    *)
      positional+=("$1"); shift ;;
  esac
done

[[ ${#positional[@]} -ge 1 && ${#positional[@]} -le 3 ]] || usage

K="${positional[0]}"
arg2="${positional[1]:-}"
arg3="${positional[2]:-}"

mode="rail"
M=""
for a in "$arg2" "$arg3"; do
  [[ -z "$a" ]] && continue
  case "$a" in
    rail|arbitrary) mode="$a" ;;
    *)
      if [[ "$a" =~ ^[0-9]+$ ]]; then
        M="$a"
      else
        echo "ERROR: unrecognized positional arg '$a' (expected integer M or 'rail'/'arbitrary')" >&2
        exit 1
      fi
      ;;
  esac
done

if ! [[ "$K" =~ ^[0-9]+$ ]] || [[ "$K" -lt 1 ]]; then
  echo "ERROR: K must be a positive integer (got '$K')" >&2
  exit 1
fi

if [[ -z "$M" ]]; then
  if [[ "$mode" == "rail" ]]; then M=8; else M=1; fi
fi
if ! [[ "$M" =~ ^[0-9]+$ ]] || [[ "$M" -lt 1 ]]; then
  echo "ERROR: M must be a positive integer (got '$M')" >&2
  exit 1
fi
if [[ "$mode" == "rail" && "$M" -gt 8 ]]; then
  echo "ERROR: in rail mode M must be in 1..8 (got $M)" >&2
  exit 1
fi
if [[ "$mode" == "arbitrary" && "$balance" -eq 1 && "$M" -gt 8 ]]; then
  echo "ERROR: in arbitrary --balance mode M must be in 1..8 (got $M)" >&2
  echo "       (each side has 8 GPUs; can't draw more than 8 distinct values)" >&2
  echo "       pass --no-balance for M up to 64." >&2
  exit 1
fi
if [[ "$mode" == "arbitrary" && "$balance" -eq 0 && "$M" -gt 64 ]]; then
  echo "ERROR: in arbitrary --no-balance mode M must be in 1..64 (got $M)" >&2
  exit 1
fi

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
[[ ${#excluded[@]} -gt 0 ]] && exclude_csv="$(IFS=','; echo "${excluded[*]}")"

seed="${P2P_SEED:-${RANDOM}${RANDOM}${RANDOM}}"

avail=$(( NODE_HI - NODE_LO + 1 - ${#excluded[@]} ))
if [[ $(( 2 * K )) -gt "$avail" ]]; then
  echo "ERROR: need 2*K=$((2*K)) distinct nodes, but only $avail available after exclusions" >&2
  exit 1
fi

balance_flag="$( [[ "$balance" -eq 1 ]] && echo "--balance" || echo "--no-balance" )"
echo "# generator: gen_random_pair_sets.sh ${K} ${M} ${mode} ${balance_flag}$( [[ -n "$exclude_csv" ]] && echo " --exclude-nodes ${exclude_csv}" )"
echo "# seed: ${seed}"
echo "# pairs: $(( K * M ))  (K=${K} node-pairs x M=${M} gpu-pairings, mode=${mode}, balance=${balance})"
[[ ${#excluded[@]} -gt 0 ]] && echo "# excluded: ${excluded[*]}"

awk -v K="$K" -v M="$M" -v mode="$mode" -v balance="$balance" -v seed="$seed" \
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
      n++
      nodes[n] = sa
    }
    # Fisher-Yates shuffle the node list, then take 2K of them in order
    # and pair them up: (nodes[1], nodes[2]), (nodes[3], nodes[4]), ...
    for (i = n; i >= 2; i--) {
      j = int(rand() * i) + 1
      t = nodes[i]; nodes[i] = nodes[j]; nodes[j] = t
    }
    for (k = 1; k <= K; k++) {
      A = nodes[(k-1)*2 + 1]
      B = nodes[(k-1)*2 + 2]
      if (mode == "rail") {
        # Pick M distinct GPU indices (rail-aligned).  Rail mode is
        # structurally always balanced, so the --balance / --no-balance
        # flag does not change this branch.
        ng = ghi - glo + 1
        # Fisher-Yates over GPU indices.
        for (g = 0; g < ng; g++) gpus[g+1] = glo + g
        for (i = ng; i >= 2; i--) {
          j = int(rand() * i) + 1
          t = gpus[i]; gpus[i] = gpus[j]; gpus[j] = t
        }
        for (i = 1; i <= M; i++) {
          printf "%s\t%s\t%d\t%d\n", A, B, gpus[i], gpus[i]
        }
      } else if (balance == 1) {
        # arbitrary + --balance:  pick M distinct gpuA values and M
        # distinct gpuB values via two independent Fisher-Yates shuffles
        # of {0..7}, then pair them up.  Within each node pair this
        # gives a uniformly random matching of size M between two
        # uniformly random size-M subsets of {0..7}.  Combined with the
        # K-disjoint-node-pairs structure, every (node, gpu) appearing
        # in the output appears at most once globally.
        ng = ghi - glo + 1
        for (g = 0; g < ng; g++) { gA[g+1] = glo + g; gB[g+1] = glo + g }
        for (i = ng; i >= 2; i--) {
          j = int(rand() * i) + 1
          t = gA[i]; gA[i] = gA[j]; gA[j] = t
        }
        for (i = ng; i >= 2; i--) {
          j = int(rand() * i) + 1
          t = gB[i]; gB[i] = gB[j]; gB[j] = t
        }
        for (i = 1; i <= M; i++) {
          printf "%s\t%s\t%d\t%d\n", A, B, gA[i], gB[i]
        }
      } else {
        # arbitrary + --no-balance: M distinct (gpuA, gpuB) pairs drawn
        # without replacement from the 64-cell grid.  The same gpuA
        # value can appear in multiple rows of one node pair (loading
        # one source GPU against several remote GPUs).
        ngrid = (ghi - glo + 1) * (ghi - glo + 1)
        for (i = 0; i < ngrid; i++) {
          ga = glo + int(i / (ghi - glo + 1))
          gb = glo + (i % (ghi - glo + 1))
          gridA[i+1] = ga; gridB[i+1] = gb
        }
        for (i = ngrid; i >= 2; i--) {
          j = int(rand() * i) + 1
          t = gridA[i]; gridA[i] = gridA[j]; gridA[j] = t
          t = gridB[i]; gridB[i] = gridB[j]; gridB[j] = t
        }
        for (i = 1; i <= M; i++) {
          printf "%s\t%s\t%d\t%d\n", A, B, gridA[i], gridB[i]
        }
      }
    }
  }
'
