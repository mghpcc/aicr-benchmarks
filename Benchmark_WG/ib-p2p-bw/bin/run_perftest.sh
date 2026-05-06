#!/usr/bin/env bash
# Run a single perftest invocation with NUMA pinning.
#
# Usage:
#   run_perftest.sh <tool> <nic> <gpu> <numa> [server_host]
#
# - <tool>        e.g. ib_read_bw or ib_write_bw
# - <nic>         e.g. mlx5_0
# - <gpu>         CUDA device index used by --use_cuda
# - <numa>        NUMA node to bind cpu+memory to ("" or "N/A" disables pinning)
# - <server_host> if provided, run as client connecting to that host;
#                 otherwise run as server (no host arg).

set -euo pipefail

tool="${1:?missing tool}"
nic="${2:?missing nic}"
gpu="${3:?missing gpu}"
numa="${4-}"
host="${5-}"

args=(-d "$nic" --use_cuda="$gpu" -q 8 -a --report_gbits)
[[ -n "$host" ]] && args+=("$host")

if command -v numactl >/dev/null 2>&1 \
   && [[ -n "$numa" && "$numa" != "N/A" ]]; then
  exec numactl --cpunodebind="$numa" --membind="$numa" "$tool" "${args[@]}"
else
  exec "$tool" "${args[@]}"
fi
