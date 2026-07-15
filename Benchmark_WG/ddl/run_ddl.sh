#!/bin/bash
# run_ddl.sh -- runs INSIDE the container. FP8 + model-parallelism benchmark runner.
# Extends megatron-lm/Megatron-LM/run.sh with precision (BF16/FP8 recipes),
# tensor/pipeline parallelism, seed control, and an optional SHARP toggle.
#
# Arguments (positional):
#   $1 = N_NODES
#   $2 = N_GPUS (per node)
#   $3 = master_node_ip
#   $4 = MODEL   : 1.3b | 7b | 13b
#   $5 = PREC    : bf16 | fp8ds | fp8cs | mxfp8
#   $6 = TP      : tensor-model-parallel size
#   $7 = PP      : pipeline-model-parallel size
#   $8 = GBS     : global batch size
#   $9 = MBS     : micro batch size            (optional, default 4)
#  $10 = ITERS   : train iterations            (optional, default 100)
#  $11 = SEED    : random seed                 (optional, default 1234)
#  $12 = SHARP   : 0|1 enable SHARP CollNet    (optional, default 0)
#
# Precision presets:
#   bf16  : BF16 baseline (paper configuration)
#   fp8ds : FP8 hybrid (E4M3 fwd / E5M2 bwd), delayed scaling, amax history 1024
#   fp8cs : FP8 hybrid, tensorwise current scaling
#   mxfp8 : MXFP8 block scaling (Blackwell 5th-gen tensor cores, E4M3)

export work_path="/home/shaohao_mit/benchmarks"
export megatron_path="$work_path/megatron-lm/Megatron-LM"
export ddl_path="$work_path/ddl"

# Set path to cuda driver libs for compiling PyTorchInductor and TRITON.
export TRITON_LIBCUDA_PATH=/.singularity.d/libs
export LD_LIBRARY_PATH=/.singularity.d/libs:$LD_LIBRARY_PATH
export TORCH_EXTENSIONS_DIR=$ddl_path/torch_extensions
export XDG_CACHE_HOME=$ddl_path/xdg_cache

# Force NCCL to use InfiniBand for inter-node communication.
# NCCL_IB_HCA uses exact-match EXCLUSION of the mgmt NICs (mlx5_7..10): the old
# inclusion list mlx5_0..8 wrongly included two mgmt NICs and missed the NDR
# NICs mlx5_11/12 (see Megatron-LM/notes-sharp.md, Gotcha 2). The exclusion
# form is correct for both plain-IB and SHARP runs.
export NCCL_IB_DISABLE=0
export NCCL_NET_GDR_LEVEL=2
export NCCL_IB_HCA="^mlx5_7,mlx5_8,mlx5_9,mlx5_10"
export NCCL_SOCKET_IFNAME=^lo,docker
export NCCL_DEBUG=INFO

N_NODES=$1
N_GPUS=$2
MASTER_IP=$3
MODEL=${4:?ERROR: MODEL (1.3b|7b|13b) required}
PREC=${5:?ERROR: PREC (bf16|fp8ds|fp8cs|mxfp8) required}
TP=${6:?ERROR: TP required}
PP=${7:?ERROR: PP required}
GBS=${8:?ERROR: GBS required}
MBS=${9:-4}
ITERS=${10:-100}
SEED=${11:-1234}
SHARP=${12:-0}

TOTAL_GPUS=$(( N_NODES * N_GPUS ))
if (( TOTAL_GPUS % (TP * PP) != 0 )); then
    echo "ERROR: total GPUs ($TOTAL_GPUS) not divisible by TP*PP ($TP*$PP)"; exit 1
fi
DP=$(( TOTAL_GPUS / (TP * PP) ))
if (( GBS % (MBS * DP) != 0 )); then
    echo "ERROR: GBS ($GBS) not divisible by MBS*DP ($MBS*$DP)"; exit 1
fi
N_MICROBATCH=$(( GBS / (MBS * DP) ))

# ---- Model presets (seq length 2048 throughout, as in the paper) ----
case "$MODEL" in
  1.3b)  # paper model, 1.31 B params
    model_par="--num-layers 24 --hidden-size 2048 --ffn-hidden-size 8192 \
               --num-attention-heads 16 --seq-length 2048 --max-position-embeddings 2048" ;;
  7b)    # 6.85 B params (current run.sh B200 model)
    model_par="--num-layers 36 --hidden-size 4096 --ffn-hidden-size 14336 \
               --num-attention-heads 32 --seq-length 2048 --max-position-embeddings 2048" ;;
  13b)   # 12.8 B params. Does NOT fit DP-only (18 B/param x 12.8B = 230 GB > 193 GB
         # HBM with unsharded Adam) -- requires TP >= 2.
    model_par="--num-layers 40 --hidden-size 5120 --ffn-hidden-size 20480 \
               --num-attention-heads 40 --seq-length 2048 --max-position-embeddings 2048"
    if (( TP < 2 )); then echo "ERROR: 13b requires TP >= 2 (optimizer state exceeds HBM)"; exit 1; fi ;;
  *) echo "ERROR: unknown MODEL '$MODEL'"; exit 1 ;;
esac

# ---- Precision presets ----
case "$PREC" in
  bf16)  prec_par="--bf16" ;;
  fp8ds) prec_par="--bf16 --fp8-format hybrid --fp8-recipe delayed \
                   --fp8-amax-history-len 1024 --fp8-amax-compute-algo max" ;;
  fp8cs) prec_par="--bf16 --fp8-format hybrid --fp8-recipe tensorwise" ;;
  mxfp8) prec_par="--bf16 --fp8-format e4m3 --fp8-recipe mxfp8" ;;
  *) echo "ERROR: unknown PREC '$PREC'"; exit 1 ;;
esac

# ---- Parallelism ----
par_par="--tensor-model-parallel-size $TP --pipeline-model-parallel-size $PP \
         --data-parallel-sharding-strategy no_shard"
# Sequence parallelism is standard practice with TP>1 (spreads the norm/dropout
# work; turns the per-layer AllReduce into AllGather+ReduceScatter).
if (( TP > 1 )); then par_par="$par_par --sequence-parallel"; fi

# ---- SHARP (CollNet) for the DP gradient AllReduce; see notes-sharp.md ----
# Only meaningful for N_NODES >= 2 with 8 GPUs (=NICs) per node and DP > 1.
if [ "$SHARP" = "1" ]; then
    export NCCL_COLLNET_ENABLE=1
    export SHARP_COLL_LOCK_ON_COMM_INIT=1
    export NCCL_PROTO=Simple            # LL/LL128 are not CollNet-compatible
    export NCCL_ALGO="allreduce:collnetchain,collnetdirect"
    export LD_PRELOAD=/lib64/libnuma.so.1${LD_PRELOAD:+:$LD_PRELOAD}
fi

# ---- Data: mock by default; phase-5 convergence runs drop a data_args.sh here ----
data_par="--mock-data --tokenizer-type NullTokenizer --vocab-size 50304"
if [ -f "$ddl_path/data_args.sh" ]; then
    source "$ddl_path/data_args.sh"    # must set data_par (and may extend binds via job_ddl.sh)
fi

# LR schedule scales with run length (matches paper values at ITERS=100).
WARMUP=$(( ITERS / 10 )); (( WARMUP < 10 )) && WARMUP=10
DECAY=$(( ITERS ))

if [ "$N_NODES" = "1" ]; then
    rdzv_info="--standalone"
else
    rdzv_info="--rdzv-id=101 --rdzv-backend=c10d --rdzv-endpoint=${MASTER_IP}:1234"
fi

# Parseable one-line config banner for parse_results.py
echo "DDL_CONFIG nodes=$N_NODES gpus_per_node=$N_GPUS model=$MODEL prec=$PREC tp=$TP pp=$PP dp=$DP gbs=$GBS mbs=$MBS microbatches=$N_MICROBATCH iters=$ITERS seed=$SEED sharp=$SHARP"
echo "Model parameters: $model_par"
echo "Precision: $prec_par"
echo "Parallelism: $par_par"
echo "Network info: $rdzv_info"

torchrun $rdzv_info \
        --nnodes=$N_NODES --nproc_per_node=$N_GPUS \
        ${megatron_path}/pretrain_gpt.py \
        $data_par \
        \
        $par_par \
        \
        --micro-batch-size $MBS \
        --global-batch-size $GBS \
        \
        $model_par \
        \
        --transformer-impl transformer_engine \
        $prec_par \
        \
        --train-iters $ITERS \
        --lr 3e-4 \
        --min-lr 3e-5 \
        --lr-decay-style cosine \
        --lr-warmup-iters $WARMUP \
        --lr-decay-iters $DECAY \
        \
        --weight-decay 0.1 \
        --adam-beta1 0.9 \
        --adam-beta2 0.95 \
        --clip-grad 1.0 \
        \
        --seed $SEED \
        \
        --eval-interval 1000000 \
        --save-interval 1000000 \
        --log-interval 10 \
        --log-throughput \
        --timing-log-level 2 \
        --timing-log-option all
