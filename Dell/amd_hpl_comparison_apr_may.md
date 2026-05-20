# AMD HPL Benchmark Comparison (April vs May)

This report compares previous AMD HPL benchmark results from April 2026 to current results from May 2026. All March results have been excluded as requested.

## Results Table (Individual Nodes)

The current run (May 19, 2026) included a limited subset of nodes. These are compared against the results from the April 17, 2026 run.

| Node | Previous Gflops (Apr 17) | Current Gflops (May 19) | % Difference | Status |
| :--- | :---: | :---: | :---: | :--- |
| w0001 | 8849.0 | 8824.5 | -0.28% | PASSED |
| w0002 | 8836.4 | 8841.5 | +0.06% | PASSED |
| w0003 | 8763.5 | 8727.3 | -0.41% | PASSED |
| w0004 | 8719.4 | 8700.6 | -0.22% | PASSED |
| w0005 | 8541.6 | 8469.2 | -0.85% | PASSED |

## Summary of Observations

- **Performance Stability:** The Gflops results for the nodes tested in May are within 1% of their April performance, indicating high consistency.
- **Run Scope:** The May 19 run (`r6715-20260509T105359`) was limited to nodes w0001 through w0005.
- **Bad Node Analysis:** 
    - No nodes were classified as "bad" according to the defined criteria.
    - Initial attempts for nodes w0001-w0005 on May 19 (Jobs 24167-24171) encountered errors (likely OOM), but subsequent runs later the same day (Jobs 24172-24176) were successful and yielded valid results.
- **Data Sources:**
    - **Previous:** Jobs 2553-2557 from `compute/amd_hpl_r6715-20260509T105359/` (April 17, 2026).
    - **Current:** Jobs 24172-24176 from `compute/amd_hpl_r6715-20260509T105359/` (May 19, 2026).
    - All results from March 31 (Jobs 873-900) were ignored.
