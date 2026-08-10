#!/bin/bash
# Record the post-firmware PCIe / GPU / NIC state of a0007 so the NCCL numbers
# in this batch can be tied to a specific firmware level.
#SBATCH -p rtx-batch
#SBATCH --reservation=shaohao_a0007
#SBATCH -w a0007
#SBATCH -t 20
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:8
#SBATCH --mem=64GB
#SBATCH -J a0007-topo
#SBATCH -o out-1node-a0007/%x-%N-%J
#SBATCH --exclusive

cd "$SLURM_SUBMIT_DIR" || exit 1
source ./a0007-env.sh
banner

echo "%%%%%%%%% driver / nvidia-smi %%%%%%%%%%"
cat /proc/driver/nvidia/version
nvidia-smi

echo "%%%%%%%%% nvidia-smi topo -m %%%%%%%%%%"
nvidia-smi topo -m

echo "%%%%%%%%% GPU PCIe link status %%%%%%%%%%"
nvidia-smi --query-gpu=index,name,pci.bus_id,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max --format=csv

echo "%%%%%%%%% lspci tree %%%%%%%%%%"
lspci -tv 2>/dev/null

echo "%%%%%%%%% PCIe bridges / switches (firmware evidence) %%%%%%%%%%"
lspci -nn -d ::0604 2>/dev/null
echo "--- Broadcom / PLX / PEX devices ---"
lspci -nn 2>/dev/null | grep -Ei 'broadcom|plx|pex'

echo "%%%%%%%%% per-device MaxPayload / MaxReadReq / RlxdOrd / ACS %%%%%%%%%%"
for bdf in $(lspci -D 2>/dev/null | grep -Ei '3d controller|vga compatible|infiniband|bridge' | awk '{print $1}'); do
   echo "### $bdf : $(lspci -D -s "$bdf" 2>/dev/null | cut -d' ' -f2-)"
   lspci -vvv -s "$bdf" 2>/dev/null | grep -E 'LnkCap:|LnkSta:|DevCtl:|MaxPayload|MaxReadReq|RlxdOrd|ACSCtl' | sed 's/^/    /'
done

echo "%%%%%%%%% NUMA layout %%%%%%%%%%"
numactl --hardware 2>/dev/null
lscpu 2>/dev/null | head -30

echo "%%%%%%%%% IB / NIC firmware %%%%%%%%%%"
ibstat 2>/dev/null
for d in /sys/class/infiniband/*; do
   [ -e "$d" ] || continue
   echo "$(basename "$d") fw=$(cat "$d/fw_ver" 2>/dev/null) board=$(cat "$d/board_id" 2>/dev/null)"
done

echo "%%%%%%%%% DONE $SLURM_JOB_ID %%%%%%%%%%"
