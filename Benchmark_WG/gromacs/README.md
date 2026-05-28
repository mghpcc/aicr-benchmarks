# GROMACS Benchmarks

## GROMACS installation

[GROMACS](https://www.gromacs.org/) is a free and open-source software suite for high-performance molecular dynamics simulations. At Yale, we install this software as a module using [EasyBuild](https://easybuild.io/). For this benchmark, I used GROMACS 2024.6 version with CUDA 12.8.

## Benchmark Details

I used the same model as the [GROMACS benchmark provided by United European Application Benchmark Suite (UEABS)](https://repository.prace-ri.eu/git/UEABS/ueabs/-/tree/master/gromacs?ref_type=heads). Specifically I'm using the Lignocellulose system, which can be downloaded [here](https://repository.prace-ri.eu/ueabs/GROMACS/2.2/GROMACS_TestCaseB.tar.xz). 

`gromacs_lig.sh` is the main submission script. 

```
gmx mdrun \
    -s lignocellulose.tpr \
    -deffnm ${BENCHDIR}/gromacs_$SLURM_JOBID \
    -cpt 10000 \
    -maxh 1.0 \
    -nsteps 400000 \
    -nb gpu \
    -bonded gpu \
    -ntmpi 8 \
    -ntomp 16

```

This uses eight thread-MPI ranks(`-ntmpi 8`) that will use 8 GPUs. Each thread-MPI task will have 16 OpenMP threads (`-ntomp 16`). Short-range non-bonded interactions (`-nb`) and bonded interactions (`-bonded`) will be calculated using GPUs. Explanation of other parameters can be referred [here](https://repository.prace-ri.eu/git/UEABS/ueabs/-/tree/master/gromacs?ref_type=heads). Please note, this configuration may not be optimal and not necessarily gives the best performance. 

## Results
For the RTX Pro 6000 Blackwell, the average performance was 72.7 ns/day with a standard deviation of 0.3 ns/day. 
For the B200, the average performance was 64.2 ns/day with a standard deviation of 0.7 ns/day. 

These results are comparable to those I obtained on the same GPU types at Yale. 
