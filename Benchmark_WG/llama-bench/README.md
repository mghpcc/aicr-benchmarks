# Inference Benchmark with llama-bench

## Installation
[llama-bench](https://github.com/ggml-org/llama.cpp/blob/master/tools/llama-bench/README.md#examples) is part of [llama.cpp](https://github.com/ggml-org/llama.cpp). llama.cpp is a tool that runs LLM inference using C/C++. For this benchmark, I installed llama.cpp from source as a software module (version b8083, 2024a toolchain, and CUDA 12.8.0) using [EasyBuild](https://easybuild.io/). You can also install llama.cpp with [conda](https://anaconda.org/channels/conda-forge/packages/llama.cpp/overview):

```
conda create -n llama_cpp_env llama.cpp --yes 
```   

Here, I'm using Meta LLama 3.1 70B Instruct Model with Q4_K_M quantization. To download this model directly with llama.cpp in your current directory, you can run:
```
export XDG_CACHE_HOME=$PWD
llama-cli -hf bartowski/Meta-Llama-3.1-70B-Instruct-GGUF:Q4_K_M
```

This will download the model in the directory called `llama.cpp`. 

## Benchmark Details

```
export modp=llama.cpp/bartowski_Meta-Llama-3.1-70B-Instruct-GGUF_Meta-Llama-3.1-70B-Instruct-Q4_K_M.gguf
llama-bench -m $modp -pg 512,128 -t $(($SLURM_CPUS_ON_NODE/$SLURM_GPUS_ON_NODE))
```

`$modp` points the location of the GGUF file. `-pg` represents prompt processing + text generation. This setting will perform prompt processing of 512 tokens followed by generation of 128 tokens. 

The output looks like this:
```
ggml_cuda_init: found 1 CUDA devices:
  Device 0: NVIDIA RTX PRO 6000 Blackwell Server Edition, compute capability 12.0, VMM: yes
| model                          |       size |     params | backend    | ngl | threads |            test |                  t/s |
| ------------------------------ | ---------: | ---------: | ---------- | --: | ------: | --------------: | -------------------: |
| llama 70B Q4_K - Medium        |  39.59 GiB |    70.55 B | CUDA       |  99 |      16 |           pp512 |       1750.53 ± 1.92 |
| llama 70B Q4_K - Medium        |  39.59 GiB |    70.55 B | CUDA       |  99 |      16 |           tg128 |         30.71 ± 0.00 |
| llama 70B Q4_K - Medium        |  39.59 GiB |    70.55 B | CUDA       |  99 |      16 |     pp512+tg128 |        136.26 ± 0.05 |

build: unknown (0)
```
The combined performance is 136.26 ± 0.05 tokens/second. The test is repeated 5 times. 

## Results

llama-bench was run on one GPU with 16 threads. 

RTX Pro 6000 Blackwell: Average Performance was 136.3 t/s
B200: Average Performance was 165.5 t/s
 
These results are comparable to the performances we got at Yale on the same types of GPUs. 
