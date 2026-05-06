#!/usr/bin/env bash
# Pick the rail-correct mlx5 device for a given GPU index, plus its NUMA node.
#
# Usage:  select_nic_for_gpu.sh <gpu_index>
# Output: "<mlx5_dev> <numa_node>"   e.g.   "mlx5_0 0"
#
# Strategy:
#   1. Parse `nvidia-smi topo -m` to pick the rail-correct mlx5 device
#      (closest PCIe distance: PIX < PXB < PHB < NODE < SYS; ties broken
#      by matching numeric suffix to the GPU index).
#   2. Read the NUMA node directly from sysfs:
#        /sys/class/infiniband/<dev>/device/numa_node
#      (single integer; avoids fragile multi-word column alignment in
#      nvidia-smi's matrix output).

set -euo pipefail

gpu="${1:?usage: $0 <gpu_index>}"

nic="$(nvidia-smi topo -m | awk -v gpu="$gpu" '
  function rank(v) {
    if (v == "PIX")  return 0
    if (v == "PXB")  return 1
    if (v == "PHB")  return 2
    if (v == "NODE") return 3
    if (v == "SYS")  return 4
    return 99
  }

  # ---- collect NIC<n> -> mlx5_X legend (newer nvidia-smi format) ----
  /^[[:space:]]*NIC[0-9]+:[[:space:]]+mlx5_[0-9]+/ {
    label = $1; sub(":", "", label)
    legend[label] = $2
    next
  }

  # ---- header row of the matrix ----
  NR == 1 {
    for (i = 1; i <= NF; i++) {
      h = $i
      if (h ~ /^mlx5_[0-9]+$/ || h ~ /^NIC[0-9]+$/) {
        nic_count++
        nic_field[nic_count] = i
        nic_name[nic_count]  = h
      }
    }
    next
  }

  # ---- the GPU<gpu> data row ----
  # Note: do not exit here -- the NIC<n> -> mlx5_X legend is printed AFTER
  # the matrix, so we have to keep reading until EOF before resolving names.
  $1 == "GPU" gpu && !found {
    best_score = 999
    best = ""
    for (k = 1; k <= nic_count; k++) {
      cell = $(nic_field[k] + 1)   # row has a leading label, so cells shift by 1
      r = rank(cell)
      n = nic_name[k]
      suf = n; gsub(/[^0-9]/, "", suf)
      same = (suf == gpu) ? 1 : 0
      score = r * 10 - same
      if (score < best_score) {
        best_score = score
        best       = n
      }
    }
    found = 1
    next
  }

  END {
    if (!found) {
      print "ERROR: no row for GPU" gpu " in nvidia-smi topo -m" > "/dev/stderr"
      exit 1
    }
    if (best == "") {
      print "ERROR: no mlx5_*/NIC* column found in nvidia-smi topo -m header" > "/dev/stderr"
      exit 2
    }
    if (best ~ /^NIC[0-9]+$/ && (best in legend)) best = legend[best]
    print best
  }
')"

# Read NUMA node from sysfs. -1 means "no affinity" (system has no NUMA);
# treat it as empty so run_perftest.sh skips numactl pinning.
numa_path="/sys/class/infiniband/${nic}/device/numa_node"
if [[ -r "$numa_path" ]]; then
  numa="$(<"$numa_path")"
  [[ "$numa" == "-1" ]] && numa=""
else
  numa=""
fi

echo "${nic} ${numa}"
