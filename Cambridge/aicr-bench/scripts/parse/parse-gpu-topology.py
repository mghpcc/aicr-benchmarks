#!/usr/bin/env python3
import csv, json, pathlib, re, sys

def parse_kv(path):
    data = {}
    for line in pathlib.Path(path).read_text().splitlines():
        if '=' in line:
            k, v = line.split('=', 1)
            data[k.strip()] = v.strip()
    return data

def parse_gpu_inventory(path):
    p = pathlib.Path(path)
    if not p.exists():
        return {"visible_gpu_lines": 0, "gpu_models": [], "gpu_count_from_inventory": 0}
    lines = p.read_text().splitlines()
    models = []
    for line in lines:
        m = re.match(r'^GPU\s+(\d+):\s+(.+?)\s+\(UUID:', line)
        if m:
            models.append(m.group(2))
    return {"visible_gpu_lines": sum(1 for line in lines if line.startswith('GPU ')), "gpu_models": sorted(set(models)), "gpu_count_from_inventory": len(models)}

def classify(summary, inv):
    declared = int(summary.get('gpu_count', '0') or 0)
    found = int(inv.get('gpu_count_from_inventory', 0) or 0)
    if summary.get('nvidia_smi_l_status') == 'Pass' and summary.get('nvidia_smi_topo_status') == 'Pass' and summary.get('lscpu_status') == 'Pass' and declared > 0 and found == declared:
        return 'passed'
    if found == 0 and declared == 0:
        return 'failed'
    return 'degraded'

def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: parse-gpu-topology.py <summary.txt>')
    summary_path = pathlib.Path(sys.argv[1])
    summary = parse_kv(summary_path)
    inv = parse_gpu_inventory(summary.get('nvidia_smi_l_file', ''))
    derived = {**summary, **inv, 'node_health': classify(summary, inv)}
    out_json = summary_path.with_suffix('.json')
    out_csv = summary_path.with_suffix('.csv')
    out_json.write_text(json.dumps(derived, indent=2) + '\n')
    with out_csv.open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(derived.keys()))
        w.writeheader(); w.writerow(derived)
    print(out_json)
    print(out_csv)

if __name__ == '__main__':
    main()
