# AMD HPL Cluster Benchmark Comparison (April vs May)

This report compares the AMD HPL Cluster benchmark results from April 2026 and May 2026. Results from March have been excluded.

## Results Table

The "Previous" runs in April utilized a 28-node cluster, while the "Current" successful run in May utilized a 5-node subset.

| Date | Job ID | Nodes | Problem Size (N) | Total Gflops | Gflops/Node | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| Apr 1 | 2051 | 28 | 978,432 | 1.8740e+05 | 6,692.9 | PASSED |
| Apr 6 | 2073 | 28 | 1,385,329 | 1.9196e+05 | 6,855.7 | PASSED |
| May 19 | 24204 | 5 | 413,952 | 3.0102e+04 | 6,020.4 | PASSED |

## Analysis of Bad Runs and Failed Nodes

For the cluster benchmarks, "Bad Runs" were identified as those failing due to configuration or resource limits. No specific nodes were identified as "bad" (hardware failure) because subsequent successful runs were achieved on the same hardware.

### Failed Jobs
- **Job 2072 (Apr 6):** Cancelled due to time limit. Superseded by Job 2073 on the same day.
- **Job 2580 (Apr 17):** Failed with illegal input (Need at least 28 processes).
- **Job 24198 (May 19):** Failed with illegal input (Need at least 28 processes).
- **Job 24203 (May 19):** Failed due to memory allocation error (N too large for 5 nodes).

### Successful Recovery
- **Job 24204 (May 19):** Successfully completed on 5 nodes after adjusting the problem size (N) and process grid (P x Q).

## Performance Comparison Summary

- **Scaling Consistency:** The Gflops per node for the 28-node cluster (avg ~6,774) is higher than the 5-node cluster (~6,020). This is expected as the larger runs used significantly larger problem sizes (N), which typically improves HPL efficiency.
- **Range Check:** The results are within a reasonable range considering the change in cluster scale and problem size. The 5-node results show stable performance per node relative to the overhead expected for multi-node HPL.
- **Node Health:** All nodes involved in the May 19 run (w0001–w0005) are verified as functional.
