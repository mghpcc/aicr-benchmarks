#!/bin/bash
#SBATCH -p b200-batch
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=1
#SBATCH --mem=64G
#SBATCH -t 15
#SBATCH -J gdr-root
#SBATCH -o out-diag/%x-%N-%J

# Root-cause hunt for the AICR inter-node GDRDMA defect.
#   part A: PCIe full-duplex test with plain cudaMemcpy -- no IB, no RDMA, no P2P
#   part B: every ordering / PCIe knob readable without root

module load nvhpc/26.3
mkdir -p out-diag

echo "##### $(hostname)  $(date) #####"

echo; echo "=========== A. PCIe full-duplex test (cudaMemcpyAsync) ==========="
nvcc -O2 -o /tmp/pcie_duplex.$$ pcie_duplex.cu 2>&1 | tail -5 \
  && /tmp/pcie_duplex.$$ 256 16
rm -f /tmp/pcie_duplex.$$

echo; echo "=========== B1. NVIDIA driver params (relaxed ordering etc) ==========="
if [ -r /proc/driver/nvidia/params ]; then
  grep -iE "relax|order|p2p|pcie|bar|aspm|mrrs|payload" /proc/driver/nvidia/params
  echo "--- (full param list saved below) ---"
  cat /proc/driver/nvidia/params
else
  echo "/proc/driver/nvidia/params not readable"
fi

echo; echo "=========== B2. nvidia-smi PCIe + BAR1 ==========="
nvidia-smi -q | grep -iE -A2 "relaxed|bar1|pci|link width|link speed|atomic" | head -60

echo; echo "=========== B3. sysfs PCIe state, GPU and NICs ==========="
printf "%-14s %-8s %-8s %-10s %-10s %s\n" BDF cur_w max_w cur_speed max_speed device
for d in /sys/bus/pci/devices/*; do
  b=$(basename "$d")
  cls=$(cat "$d/class" 2>/dev/null)
  # 0x030200/0x030000 = GPU, 0x020700/0x0c0600 = IB
  case "$cls" in
    0x0302*|0x0300*|0x0207*|0x0c06*) ;;
    *) continue ;;
  esac
  printf "%-14s %-8s %-8s %-10s %-10s %s\n" "$b" \
    "$(cat $d/current_link_width 2>/dev/null)" "$(cat $d/max_link_width 2>/dev/null)" \
    "$(cat $d/current_link_speed 2>/dev/null | cut -d' ' -f1)" \
    "$(cat $d/max_link_speed 2>/dev/null | cut -d' ' -f1)" \
    "$(lspci -s ${b#0000:} 2>/dev/null | cut -d' ' -f2- | cut -c1-46)"
done

echo; echo "=========== B4. What lspci gives us unprivileged ==========="
echo "(DevCtl carries MaxPayload / MaxReadRequest / RelaxOrd; ACSCtl needs root)"
gpu=$(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader | head -1 | tr 'A-Z' 'a-z' | sed 's/^0000\{1,\}:/0000:/')
echo "--- GPU $gpu ---"
lspci -vv -s "${gpu#0000:}" 2>/dev/null | grep -iE "DevCtl|MaxPayload|MaxReadReq|RlxdOrd|LnkCap|LnkSta|ACSCtl|Region" | head -20
echo "--- first ConnectX-7 ---"
nic=$(lspci -D | grep -i mellanox | head -1 | awk '{print $1}')
lspci -vv -s "$nic" 2>/dev/null | grep -iE "DevCtl|MaxPayload|MaxReadReq|RlxdOrd|LnkCap|LnkSta|ACSCtl" | head -20

echo; echo "=========== B5. PCIe bridges above the GPU (the PIX path) ==========="
gpubdf=$(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader | head -1 | tr 'A-Z' 'a-z' | sed 's/^0000\{1,\}:/0000:/')
echo "GPU full BDF: $gpubdf"
cur="/sys/bus/pci/devices/$gpubdf"
for i in 1 2 3 4; do
  par=$(readlink -f "$cur/.." 2>/dev/null)
  bn=$(basename "$par")
  [[ "$bn" =~ ^[0-9a-f]{4}: ]] || break
  echo "--- level $i: $bn  $(lspci -s ${bn#0000:} 2>/dev/null | cut -d' ' -f2- | cut -c1-60)"
  lspci -vv -s "${bn#0000:}" 2>/dev/null | grep -iE "MaxPayload|MaxReadReq|RlxdOrd|ACSCtl|LnkSta:" | sed 's/^/      /'
  cur="$par"
done

echo; echo "=========== B6. kernel cmdline / IOMMU (re-confirm on THIS node) ==========="
cat /proc/cmdline
echo "iommu dirs: $(ls /sys/class/iommu 2>/dev/null | tr '\n' ' ')"

echo; echo "##### END $(hostname) #####"

echo; echo "=========== B7. NIC firmware ordering config + verbs caps ==========="
nic0=$(ibstat -l 2>/dev/null | head -1)
echo "--- mlxconfig (usually root-only) ---"
for d in $(lspci -D | grep -i mellanox | awk '{print $1}' | head -1); do
  mlxconfig -d "$d" q 2>&1 | grep -iE "ORDERING|RELAX|ADVANCED_PCI|MAX_ACC|Device #|^Configurations" | head -20 \
    || echo "mlxconfig unavailable/denied"
done
echo "--- ibv_devinfo ---"
ibv_devinfo -d "$nic0" -v 2>/dev/null | grep -iE "relax|order|atomic|fw_ver|max_mr|hca_core" | head -20

echo; echo "=========== B8. raw PCIe config space readability ==========="
gb=$(nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader | head -1 | tr 'A-Z' 'a-z' | sed 's/^0000\{1,\}:/0000:/')
echo "GPU $gb config bytes readable: $(dd if=/sys/bus/pci/devices/$gb/config bs=1 count=4096 2>/dev/null | wc -c) of 4096"
echo "(64 => unprivileged; 256/4096 => we can decode DevCtl/ACS ourselves)"
