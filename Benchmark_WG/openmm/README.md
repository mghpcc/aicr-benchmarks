# OpenMM Benchmark
Aya Nawano, Yale University

## OpenMM installation
[OpenMM](https://openmm.org/) is a high-performance molecular simulation toolset that is highly optimized for GPUs. At Yale, we install this software as a module using [EasyBuild](https://easybuild.io/), but it can also be installed with conda(`conda install -c conda-forge openmm`) or pip (`pip install openmm`). For this benchmark, we installed it as a module using OpenMM v8.4.0 with the 2024a toolchain and CUDA 12.8.0.

## System and Expected Performance
The benchmark suite is provided with the software (`examples/benchmarks`). There are several systems available for benchmarking. For this benchmark, I chose Apolipoprotein A1 (ApoA1) with the Particle Mesh Ewald (PME) method to calculate the effect of solvent. More details of the system can be found [here](https://openmm.org/benchmarks). The official benchmark results are `948.02 ns/day` for the RTX Pro 6000 and `875.937 ns/day` for the B200.

## Benchmark Details
`openmm.sh` is the main submission script. Each simulation runs on 1 GPU for 200 seconds. 

## Results
Outputs from RTX Pro 6000 Blackwell GPUs are located in the `rtx_output` directory, and outputs from B200 GPUs are located in the `b200_output` directory. Each file contains results from 8 simulations (8 GPUs). The relevant performance metric is `ns/day`. This represents how many nanoseconds of simulation time can be achieved per day of wall-clock time. 

RTX Pro 6000 Blackwell: Average Performance `1000.0 ns/day` with standard deviation of `2.14 ns/day` 
B200: Average Performance `869.0 ns/day` with standard deviation of `2.41 ns/day`

These values are also similar to what I obtained on RTX Pro 6000 Blackwell nodes and B200 nodes at Yale (`986.9 ns/day` for RTX 6000 and `854 ns/day` for B200).      
