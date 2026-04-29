import os
import re
import csv
from collections import defaultdict

def parse_hpl_file(file_path):
    try:
        with open(file_path, 'r') as f:
            content = f.read()
    except Exception:
        return None

    # Extract Job ID and Hostname from filename
    filename = os.path.basename(file_path)
    # Pattern: slurm-job_test.job_id.hostname.out or slurm-job_test.job_id.out
    match = re.match(r'slurm-([^\.]+)\.(\d+)\.([^\.]+)\.out', filename)
    if not match:
        match = re.match(r'slurm-([^\.]+)\.(\d+)\.out', filename)
        if match:
            job_test = match.group(1)
            slurm_job_id = match.group(2)
            hostname = "unknown"
        else:
            return None
    else:
        job_test = match.group(1)
        slurm_job_id = match.group(2)
        hostname = match.group(3)

    # Extract Gflops
    # Table line example: WRC11C2R4o 002       184900   384     1     1          475.68         8.8596e+03
    gflops_match = re.search(r'WR[^\s]+\s+[^\s]+\s+\d+\s+\d+\s+\d+\s+\d+\s+[\d\.]+\s+([0-9\.e\+\-]+)', content)
    if not gflops_match:
        return None
    gflops = float(gflops_match.group(1))

    # Extract result
    result = "FAILED"
    if "PASSED" in content:
        result = "PASSED"
    
    # Extract cores info
    # For individual runs NP=1, OMP_NUM_THREADS=128
    # For cluster runs total ranks * OMP_NUM_THREADS
    ranks_match = re.search(r'TOTAL_RANKS=(\d+)', content)
    ntasks_match = re.search(r'--ntasks=(\d+)', content)
    
    ranks = 1
    if ranks_match:
        ranks = int(ranks_match.group(1))
    elif ntasks_match:
        ranks = int(ntasks_match.group(1))
        
    threads_match = re.search(r'OMP_NUM_THREADS=(\d+)', content)
    threads = 128 # Default based on logs
    if threads_match:
        threads = int(threads_match.group(1))
        
    total_cores = ranks * threads

    return {
        'job_test': job_test,
        'slurm_job_id': slurm_job_id,
        'hostname': hostname,
        'gflops': gflops,
        'total_cores': total_cores,
        'gflops_per_core': gflops / total_cores if total_cores > 0 else 0,
        'result': result
    }

def main():
    search_dirs = ['.', 'amd_hpl', 'amd_hpl_cluster']
    results = []

    for d in search_dirs:
        if not os.path.exists(d):
            continue
        for f in os.listdir(d):
            if f.endswith('.out') and f.startswith('slurm-'):
                res = parse_hpl_file(os.path.join(d, f))
                if res:
                    results.append(res)

    if not results:
        print("No results found.")
        return

    # Group by (job_test, hostname) and take the best gflops
    best_results = {}
    for res in results:
        key = (res['job_test'], res['hostname'])
        if key not in best_results or res['gflops'] > best_results[key]['gflops']:
            best_results[key] = res

    # Sort results: Cluster runs first, then individual runs by hostname
    sorted_keys = sorted(best_results.keys(), key=lambda x: ('cluster' not in x[0], x[1]))
    
    output_file = 'hpl_results.csv'
    headers = ['job_test', 'slurm_job_id', 'hostname', 'gflops', 'gflops_per_core', 'total_cores', 'result']
    
    with open(output_file, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=headers)
        writer.writeheader()
        for key in sorted_keys:
            writer.writerow(best_results[key])

    print(f"CSV generated: {output_file}")
    
    # Also print to stdout for easy copy-pasting
    print("\nCSV Content:\n")
    print(",".join(headers))
    for key in sorted_keys:
        row = best_results[key]
        print(f"{row['job_test']},{row['slurm_job_id']},{row['hostname']},{row['gflops']:.4e},{row['gflops_per_core']:.4f},{row['total_cores']},{row['result']}")

if __name__ == "__main__":
    main()
