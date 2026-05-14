#!/usr/bin/env python3
import json
import re
import shlex
from collections import Counter
from pathlib import Path


ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
TOPOLOGY_LINK_ORDER = {
    "NV": 0,
    "PIX": 1,
    "PXB": 2,
    "PHB": 3,
    "NODE": 4,
    "SYS": 5,
}

B200_EXPECTED_GPU_NUMA_AFFINITY = {
    "GPU0": "1",
    "GPU1": "2",
    "GPU2": "3",
    "GPU3": "0",
    "GPU4": "5",
    "GPU5": "6",
    "GPU6": "7",
    "GPU7": "4",
}

B200_EXPECTED_GPU_CPU_AFFINITY = {
    "GPU0": "16-31",
    "GPU1": "32-47",
    "GPU2": "48-63",
    "GPU3": "0-15",
    "GPU4": "80-95",
    "GPU5": "96-111",
    "GPU6": "112-127",
    "GPU7": "64-79",
}

B200_EXPECTED_GPU_PIX_NICS = {
    "GPU0": ["mlx5_0"],
    "GPU1": ["mlx5_1"],
    "GPU2": ["mlx5_2"],
    "GPU3": ["mlx5_3"],
    "GPU4": ["mlx5_4"],
    "GPU5": ["mlx5_5"],
    "GPU6": ["mlx5_6"],
    "GPU7": ["mlx5_11", "mlx5_12"],
}

B200_EXPECTED_LSCPU_NUMA_CPU_AFFINITY = {
    "0": "0-15",
    "1": "16-31",
    "2": "32-47",
    "3": "48-63",
    "4": "64-79",
    "5": "80-95",
    "6": "96-111",
    "7": "112-127",
}


def strip_ansi(text):
    return ANSI_RE.sub("", text)


def normalize_topology_row_values(header, values):
    values = [value.strip() for value in values]
    if len(values) == len(header) + 1 and values[-2] == "":
        values = values[:-2] + [values[-1]]
    if len(values) < len(header):
        values = values + [""] * (len(header) - len(values))
    return values[:len(header)]


def parse_topology_text(text):
    header = []
    rows = {}
    nic_legend = {}
    in_nic_legend = False

    for raw_line in strip_ansi(text).splitlines():
        if not raw_line.strip():
            continue
        cells = [cell.strip() for cell in raw_line.split("\t")]
        if cells and cells[0] == "" and any(cell == "GPU0" for cell in cells):
            header = cells[1:]
            continue

        row_name = cells[0] if cells else ""
        if header and re.match(r"^(GPU|NIC)\d+$", row_name):
            values = normalize_topology_row_values(header, cells[1:])
            rows[row_name] = dict(zip(header, values))
            continue

        if raw_line.startswith("NIC Legend:"):
            in_nic_legend = True
            continue

        if in_nic_legend:
            match = re.match(r"\s+(NIC\d+):\s+(mlx5_\d+)\s*$", raw_line)
            if match:
                nic_legend[match.group(1)] = match.group(2)

    nic_columns = [column for column in header if re.match(r"^NIC\d+$", column)]
    gpu_rows = sorted((name for name in rows if name.startswith("GPU")), key=lambda item: int(item[3:]))

    gpu_cpu_affinity = {}
    gpu_numa_affinity = {}
    gpu_numa_id = {}
    gpu_pix_nics = {}
    gpu_pix_nic_labels = {}
    gpu_nearest_nics = {}
    nic_cpu_affinity = {}
    nic_numa_affinity = {}
    nic_gpu_links = {}

    for gpu in gpu_rows:
        row = rows[gpu]
        gpu_cpu_affinity[gpu] = row.get("CPU Affinity", "")
        gpu_numa_affinity[gpu] = row.get("NUMA Affinity", "")
        gpu_numa_id[gpu] = row.get("GPU NUMA ID", "")
        pix_nics = []
        pix_labels = []
        gpu_links = {}
        for nic in nic_columns:
            link = row.get(nic, "")
            if link:
                gpu_links[nic_legend.get(nic, nic)] = link
            if row.get(nic) == "PIX":
                device = nic_legend.get(nic, nic)
                pix_nics.append(device)
                pix_labels.append(f"{nic}:{device}")
        gpu_pix_nics[gpu] = pix_nics
        gpu_pix_nic_labels[gpu] = pix_labels
        best_rank = None
        best_link = ""
        best_nics = []
        for device, link in gpu_links.items():
            rank = TOPOLOGY_LINK_ORDER.get(link)
            if rank is None:
                continue
            if best_rank is None or rank < best_rank:
                best_rank = rank
                best_link = link
                best_nics = [device]
            elif rank == best_rank:
                best_nics.append(device)
        gpu_nearest_nics[gpu] = {
            "link": best_link,
            "nics": sorted(best_nics, key=natural_mlx5_key),
        }

    for nic in sorted((name for name in rows if name.startswith("NIC")), key=lambda item: int(item[3:])):
        row = rows[nic]
        device = nic_legend.get(nic, nic)
        nic_cpu_affinity[device] = row.get("CPU Affinity", "")
        nic_numa_affinity[device] = row.get("NUMA Affinity", "")
        nic_gpu_links[device] = {
            gpu: row.get(gpu, "")
            for gpu in gpu_rows
            if row.get(gpu)
        }

    return {
        "gpu_cpu_affinity": gpu_cpu_affinity,
        "gpu_numa_affinity": gpu_numa_affinity,
        "gpu_numa_id": gpu_numa_id,
        "nic_legend": dict(sorted(nic_legend.items(), key=lambda item: int(item[0][3:]))),
        "nic_cpu_affinity": dict(sorted(nic_cpu_affinity.items(), key=lambda item: natural_mlx5_key(item[0]))),
        "nic_numa_affinity": dict(sorted(nic_numa_affinity.items(), key=lambda item: natural_mlx5_key(item[0]))),
        "nic_gpu_links": dict(sorted(nic_gpu_links.items(), key=lambda item: natural_mlx5_key(item[0]))),
        "gpu_pix_nics": gpu_pix_nics,
        "gpu_pix_nic_labels": gpu_pix_nic_labels,
        "gpu_nearest_nics": gpu_nearest_nics,
    }


def parse_topology_file(path):
    topo_path = Path(path)
    if not topo_path.exists():
        return parse_topology_text("")
    return parse_topology_text(topo_path.read_text(encoding="utf-8", errors="replace"))


def parse_lscpu_text(text):
    fields = {}
    numa_cpu_affinity = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        fields[key] = value
        match = re.match(r"NUMA node(\d+) CPU\(s\)", key)
        if match:
            numa_cpu_affinity[match.group(1)] = value

    node_count = None
    try:
        node_count = int(fields.get("NUMA node(s)", ""))
    except ValueError:
        node_count = None

    return {
        "lscpu_cpu_count": fields.get("CPU(s)", ""),
        "lscpu_socket_count": fields.get("Socket(s)", ""),
        "lscpu_core_count_per_socket": fields.get("Core(s) per socket", ""),
        "lscpu_thread_count_per_core": fields.get("Thread(s) per core", ""),
        "lscpu_numa_node_count": node_count,
        "lscpu_numa_cpu_affinity": dict(sorted(numa_cpu_affinity.items(), key=lambda item: int(item[0]))),
    }


def parse_lscpu_file(path):
    lscpu_path = Path(path)
    if not lscpu_path.exists():
        return parse_lscpu_text("")
    return parse_lscpu_text(lscpu_path.read_text(encoding="utf-8", errors="replace"))


def natural_mlx5_key(value):
    match = re.search(r"mlx5_(\d+)$", str(value))
    if match:
        return int(match.group(1))
    match = re.search(r"NIC(\d+)$", str(value))
    if match:
        return int(match.group(1))
    return 10_000


def parse_shell_assignments(text):
    out = {}
    try:
        for token in shlex.split(text):
            if "=" not in token:
                continue
            key, value = token.split("=", 1)
            out[key] = value
    except ValueError:
        return out
    return out


def parse_storage_text(text):
    fields = {
        "gds_scratch_dir": "",
        "gds_storage_target": "",
        "gds_storage_source": "",
        "gds_storage_fstype": "",
        "gds_storage_options": "",
        "gds_storage_route_target": "",
        "gds_storage_route_dev": "",
        "gds_storage_route_src": "",
        "gds_storage_route_mlx5": "",
        "ib_device_numa_affinity": {},
        "ib_device_cpu_affinity": {},
        "ib_device_netdevs": {},
    }
    route_line = ""

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("gds_scratch_dir="):
            fields["gds_scratch_dir"] = line.split("=", 1)[1]
        elif line.startswith("findmnt "):
            values = parse_shell_assignments(line[len("findmnt "):])
            fields["gds_storage_target"] = values.get("TARGET", "")
            fields["gds_storage_source"] = values.get("SOURCE", "")
            fields["gds_storage_fstype"] = values.get("FSTYPE", "")
            fields["gds_storage_options"] = values.get("OPTIONS", "")
        elif line.startswith("storage_route_target="):
            fields["gds_storage_route_target"] = line.split("=", 1)[1]
        elif line.startswith("storage_route_line="):
            route_line = line.split("=", 1)[1]
        elif line.startswith("storage_route_dev="):
            fields["gds_storage_route_dev"] = line.split("=", 1)[1]
        elif line.startswith("storage_route_src="):
            fields["gds_storage_route_src"] = line.split("=", 1)[1]
        elif line.startswith("storage_route_mlx5="):
            fields["gds_storage_route_mlx5"] = line.split("=", 1)[1]
        elif line.startswith("ib_device "):
            match = re.match(r"^ib_device\s+(\S+)\s+numa_node=(\S*)\s+local_cpulist=(\S*)\s+netdevs=(.*)$", line)
            if not match:
                continue
            device, numa_node, local_cpulist, netdevs = match.groups()
            fields["ib_device_numa_affinity"][device] = numa_node
            fields["ib_device_cpu_affinity"][device] = local_cpulist
            fields["ib_device_netdevs"][device] = [item for item in netdevs.split(",") if item]

    if route_line and not fields["gds_storage_route_dev"]:
        parts = route_line.split()
        if "dev" in parts:
            fields["gds_storage_route_dev"] = parts[parts.index("dev") + 1]
        if "src" in parts:
            fields["gds_storage_route_src"] = parts[parts.index("src") + 1]

    if fields["gds_storage_route_dev"] and not fields["gds_storage_route_mlx5"]:
        route_dev = fields["gds_storage_route_dev"]
        for device, netdevs in fields["ib_device_netdevs"].items():
            if route_dev in netdevs:
                fields["gds_storage_route_mlx5"] = device
                break

    fields["ib_device_numa_affinity"] = dict(
        sorted(fields["ib_device_numa_affinity"].items(), key=lambda item: natural_mlx5_key(item[0]))
    )
    fields["ib_device_cpu_affinity"] = dict(
        sorted(fields["ib_device_cpu_affinity"].items(), key=lambda item: natural_mlx5_key(item[0]))
    )
    fields["ib_device_netdevs"] = dict(
        sorted(fields["ib_device_netdevs"].items(), key=lambda item: natural_mlx5_key(item[0]))
    )
    return fields


def parse_storage_file(path):
    if not path:
        return parse_storage_text("")
    storage_path = Path(path)
    if not storage_path.exists():
        return parse_storage_text("")
    return parse_storage_text(storage_path.read_text(encoding="utf-8", errors="replace"))


def parse_mlx5_file(path):
    parsed = parse_storage_text("")
    if not path:
        return {
            "ib_device_numa_affinity": parsed["ib_device_numa_affinity"],
            "ib_device_cpu_affinity": parsed["ib_device_cpu_affinity"],
            "ib_device_netdevs": parsed["ib_device_netdevs"],
        }
    mlx5_path = Path(path)
    if not mlx5_path.exists():
        return {
            "ib_device_numa_affinity": parsed["ib_device_numa_affinity"],
            "ib_device_cpu_affinity": parsed["ib_device_cpu_affinity"],
            "ib_device_netdevs": parsed["ib_device_netdevs"],
        }
    parsed = parse_storage_text(mlx5_path.read_text(encoding="utf-8", errors="replace"))
    return {
        "ib_device_numa_affinity": parsed["ib_device_numa_affinity"],
        "ib_device_cpu_affinity": parsed["ib_device_cpu_affinity"],
        "ib_device_netdevs": parsed["ib_device_netdevs"],
    }


def topology_signature(fields):
    gpu_numa = fields.get("gpu_numa_affinity") or {}
    gpu_cpu = fields.get("gpu_cpu_affinity") or {}
    gpu_pix = fields.get("gpu_pix_nics") or {}
    nic_numa = fields.get("nic_numa_affinity") or {}
    nic_cpu = fields.get("nic_cpu_affinity") or {}
    ib_numa = fields.get("ib_device_numa_affinity") or {}
    ib_cpu = fields.get("ib_device_cpu_affinity") or {}

    numa_part = ",".join(f"{gpu}:{gpu_numa.get(gpu, '')}" for gpu in sorted(gpu_numa))
    cpu_part = ",".join(f"{gpu}:{gpu_cpu.get(gpu, '')}" for gpu in sorted(gpu_cpu))
    pix_part = ",".join(f"{gpu}:{'+'.join(gpu_pix.get(gpu, []))}" for gpu in sorted(gpu_pix))
    nic_numa_part = ",".join(f"{nic}:{nic_numa.get(nic, '')}" for nic in sorted(nic_numa, key=natural_mlx5_key))
    nic_cpu_part = ",".join(f"{nic}:{nic_cpu.get(nic, '')}" for nic in sorted(nic_cpu, key=natural_mlx5_key))
    ib_numa_part = ",".join(f"{dev}:{ib_numa.get(dev, '')}" for dev in sorted(ib_numa, key=natural_mlx5_key))
    ib_cpu_part = ",".join(f"{dev}:{ib_cpu.get(dev, '')}" for dev in sorted(ib_cpu, key=natural_mlx5_key))
    storage_part = ",".join([
        f"source={fields.get('gds_storage_source', '')}",
        f"fstype={fields.get('gds_storage_fstype', '')}",
        f"route_dev={fields.get('gds_storage_route_dev', '')}",
        f"route_mlx5={fields.get('gds_storage_route_mlx5', '')}",
    ])
    return (
        f"gpu_numa={numa_part}|gpu_cpu={cpu_part}|gpu_pix={pix_part}|"
        f"nic_numa={nic_numa_part}|nic_cpu={nic_cpu_part}|"
        f"ib_numa={ib_numa_part}|ib_cpu={ib_cpu_part}|storage={storage_part}"
    )


def compare_map(name, actual, expected, notes):
    for key, expected_value in expected.items():
        actual_value = actual.get(key)
        if isinstance(expected_value, list):
            if sorted(actual_value or []) != sorted(expected_value):
                notes.append(f"{name} {key} expected {','.join(expected_value)} found {','.join(actual_value or [])}")
        elif str(actual_value) != str(expected_value):
            notes.append(f"{name} {key} expected {expected_value} found {actual_value or '-'}")


def b200_profile_assessment(fields):
    notes = []
    compare_map("GPU NUMA affinity", fields.get("gpu_numa_affinity") or {}, B200_EXPECTED_GPU_NUMA_AFFINITY, notes)
    compare_map("GPU CPU affinity", fields.get("gpu_cpu_affinity") or {}, B200_EXPECTED_GPU_CPU_AFFINITY, notes)
    compare_map("GPU PIX NICs", fields.get("gpu_pix_nics") or {}, B200_EXPECTED_GPU_PIX_NICS, notes)
    compare_map(
        "lscpu NUMA CPU affinity",
        fields.get("lscpu_numa_cpu_affinity") or {},
        B200_EXPECTED_LSCPU_NUMA_CPU_AFFINITY,
        notes,
    )
    if fields.get("lscpu_numa_node_count") != 8:
        notes.append(f"expected 8 NUMA nodes, found {fields.get('lscpu_numa_node_count') or '-'}")
    generic_notes = generic_profile_assessment(fields, "b200").get("topology_profile_notes")
    if generic_notes:
        notes.extend(generic_notes.split("; "))
    return {
        "topology_profile_status": "Warn" if notes else "Pass",
        "topology_profile_notes": "; ".join(notes),
    }


def generic_profile_assessment(fields, cluster):
    notes = []
    gpu_numa = fields.get("gpu_numa_affinity") or {}
    nic_numa = fields.get("nic_numa_affinity") or {}
    ib_numa = fields.get("ib_device_numa_affinity") or {}

    if len(gpu_numa) < 8:
        notes.append(f"expected structured NUMA affinity for 8 GPUs, found {len(gpu_numa)}")
    if not nic_numa:
        notes.append("no mlx5/NIC NUMA affinity parsed from nvidia-smi topology")
    if not ib_numa:
        notes.append("no mlx5 device NUMA affinity parsed from sysfs")
    if cluster == "b200":
        if not fields.get("gds_storage_source"):
            notes.append("GDS scratch storage source not resolved")
        elif fields.get("gds_storage_fstype") not in {"nfs", "nfs4", "lustre", "beegfs", "gpfs", "xfs", "ext2/ext3", "ext4"}:
            notes.append(f"recorded GDS scratch filesystem type {fields.get('gds_storage_fstype') or '-'}")
        if fields.get("gds_storage_route_dev") and not fields.get("gds_storage_route_mlx5"):
            notes.append(f"storage route dev {fields.get('gds_storage_route_dev')} did not map to an mlx5 device")

    return {
        "topology_profile_status": "Warn" if notes else "Pass",
        "topology_profile_notes": "; ".join(notes),
    }


def nearest_nic_text(gpu_nearest_nics, gpu):
    item = gpu_nearest_nics.get(gpu) or {}
    link = item.get("link") or "-"
    nics = item.get("nics") or []
    return f"{link}:{', '.join(nics) if nics else '-'}"


def topology_observations(fields):
    gpu_pix = fields.get("gpu_pix_nics") or {}
    gpu_cpu = fields.get("gpu_cpu_affinity") or {}
    gpu_numa = fields.get("gpu_numa_affinity") or {}
    gpu_nearest = fields.get("gpu_nearest_nics") or {}
    lscpu_numa = fields.get("lscpu_numa_cpu_affinity") or {}
    observations = []
    if "GPU7" in gpu_pix:
        observations.append(
            f"GPU7 PIX local NICs: {', '.join(gpu_pix.get('GPU7') or [])}; "
            f"nearest NICs: {nearest_nic_text(gpu_nearest, 'GPU7')}"
        )
    if "7" in lscpu_numa or "GPU6" in gpu_cpu or "GPU6" in gpu_pix:
        observations.append(
            "NUMA node 7 CPU(s): "
            f"{lscpu_numa.get('7', '-')}; "
            f"GPU6 CPU Affinity: {gpu_cpu.get('GPU6', '-')}; "
            f"GPU6 NUMA Affinity: {gpu_numa.get('GPU6', '-')}; "
            f"GPU6 PIX local NICs: {', '.join(gpu_pix.get('GPU6') or [])}; "
            f"nearest NICs: {nearest_nic_text(gpu_nearest, 'GPU6')}"
        )
    if fields.get("gds_storage_source") or fields.get("gds_storage_route_dev"):
        observations.append(
            "GDS scratch storage: "
            f"{fields.get('gds_storage_source') or '-'} "
            f"({fields.get('gds_storage_fstype') or '-'}); "
            f"route dev {fields.get('gds_storage_route_dev') or '-'}; "
            f"route mlx5 {fields.get('gds_storage_route_mlx5') or '-'}"
        )
    if "GPU0" in gpu_nearest:
        observations.append(f"GPU0 nearest NICs: {nearest_nic_text(gpu_nearest, 'GPU0')}")
    return observations


def topology_intelligence_from_files(topo_path, lscpu_path, cluster, storage_path=None, mlx5_path=None):
    fields = {}
    fields.update(parse_topology_file(topo_path))
    fields.update(parse_lscpu_file(lscpu_path))
    fields.update(parse_storage_file(storage_path))
    fields.update(parse_mlx5_file(mlx5_path))
    fields["topology_signature"] = topology_signature(fields)
    if cluster == "b200":
        fields.update(b200_profile_assessment(fields))
    else:
        fields.update(generic_profile_assessment(fields, cluster))
    fields["topology_observations"] = topology_observations(fields)
    return fields


def majority_signature(rows):
    signatures = [row.get("topology_signature") for row in rows if row.get("topology_signature")]
    if not signatures:
        return None, 0
    return Counter(signatures).most_common(1)[0]


def as_json(obj):
    return json.dumps(obj, sort_keys=True)
