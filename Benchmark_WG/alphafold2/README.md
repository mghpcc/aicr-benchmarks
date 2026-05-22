# Alphafold2 inference

This benchmark runs Alphafold2 on a single GPUs, as it does not support multiple GPUs. The specific 
version of Alphafold2 is 2.3.8 and it comes from Colabfold 1.6.0. The database search step was pre-computed
and there are 100 proteins to fold. The proteins come from the RCS PDB from the mouse genome.

The Alphafold2 program is called from the colabfold_batch script. The benchmark script pulls
the Colabfold 1.6.0 Docker container and converts it to Singularity so that the 3.7GB container
is not added to the git repo.


## Results

This benchmark is intended to verify that a popular GPU inference model, designed for an A100 GPU, works without
issues on the AICR GPUs. The version of Jax used in Colabfold 1.6.0 is 0.5.3 compiled for CUDA 12.9. This has 
no compatibility issues on the B200 or RTX Pro 6000 GPUs.

Timing results:
* B200: 56m 17s
* RTX:  56m 42s
* H200: 80m 3s (from the BU SCC, AMD EPYC 9135 CPU)




