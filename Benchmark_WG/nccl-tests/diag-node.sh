#!/bin/bash
# Per-node PCIe / IOMMU / ACS / rail-affinity dump for the inter-node NCCL investigation.
# Run:  srun -p b200-devel -N1 --gpus-per-node=1 -t 10 bash diag-node.sh

echo "##### HOST: $(hostname)  $(date) #####"

echo; echo "===== 1. kernel cmdline (iommu / acs) ====="
cat /proc/cmdline

echo; echo "===== 2. IOMMU state ====="
if [ -d /sys/class/iommu ] && [ -n "$(ls -A /sys/class/iommu 2>/dev/null)" ]; then
  echo "IOMMU groups active: $(ls /sys/class/iommu)"
  echo "num groups: $(ls /sys/kernel/iommu_groups 2>/dev/null | wc -l)"
else
  echo "no /sys/class/iommu entries (IOMMU appears off)"
fi
dmesg 2>/dev/null | grep -iE "DMAR|IOMMU|AMD-Vi" | head -8 || echo "(dmesg not readable as user)"

echo; echo "===== 3. nvidia_peermem / dmabuf ====="
lsmod | grep -iE "peermem|nvidia_p2p|nv_peer" || echo "nvidia_peermem NOT loaded"

echo; echo "===== 4. GPU PCIe link (negotiated vs max) ====="
nvidia-smi --query-gpu=index,pci.bus_id,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max \
           --format=csv 2>/dev/null

echo; echo "===== 5. Mellanox NIC PCIe link + ACS ====="
for bdf in $(lspci -D 2>/dev/null | grep -i mellanox | awk '{print $1}'); do
  name=$(lspci -s "$bdf" 2>/dev/null | cut -d' ' -f2-)
  cap=$(lspci -vv -s "$bdf" 2>/dev/null | grep -m1 "LnkCap:" | sed 's/^[[:space:]]*//')
  sta=$(lspci -vv -s "$bdf" 2>/dev/null | grep -m1 "LnkSta:" | sed 's/^[[:space:]]*//')
  echo "--- $bdf $name"
  echo "    $cap"
  echo "    $sta"
done

echo; echo "===== 6. ACS control on ALL bridges/switches (the key check) ====="
echo "ACSCtl with SrcValid+ or RequestRedirect+ forces P2P through the root complex."
found=0
while read -r bdf rest; do
  acs=$(lspci -vv -s "$bdf" 2>/dev/null | grep -m1 "ACSCtl:" | sed 's/^[[:space:]]*//')
  if [ -n "$acs" ]; then
    found=1
    flag=""
    echo "$acs" | grep -qE "SrcValid\+|RequestRedirect\+" && flag="   <== REDIRECTING"
    echo "  $bdf  $acs$flag"
  fi
done < <(lspci -D 2>/dev/null | grep -iE "PCI bridge|Upstream|Downstream")
[ "$found" -eq 0 ] && echo "  (no ACSCtl readable -- may need root)"

echo; echo "===== 7. GPU <-> NIC topology (want PIX/PXB, never SYS) ====="
nvidia-smi topo -m 2>/dev/null

echo; echo "===== 8. IB rails and rates ====="
ibstat 2>/dev/null | grep -E "^CA |Rate:|State:|Physical state:" | paste - - - - 2>/dev/null || ibstat -l 2>/dev/null

echo; echo "##### END $(hostname) #####"
