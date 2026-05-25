#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/submit-hpl-mxp.sh --cluster <b200|rtxpro6000> --nodes <1|2|4|8|16> [--preset <smoke|staged|campaign-candidate|weak-study>] [--matrix-size <N|auto>] [--nb <N|auto>] [--nprow <auto|N>] [--npcol <auto|N>] [--from-node-report] [--date <YYYY-MM-DD|today|yesterday>] [--nodelist <csv>] [--partition <name>] [--time <HH:MM:SS>] [--mem <size>] [--image <path>] [--sloppy-type <precision>] [--test-loop <n>] [--repeat-count <n>] [--repeat-stagger-seconds <n>] [--cpus-per-task <n>] [--affinity-profile <none|derived-nps4>] [--ompi-coll <value|none>] [--ompi-pml <value|none>] [--ompi-btl <value|none>] [--ompi-btl-tcp-if-include <value|none>] [--ompi-oob-tcp-if-include <value|none>] [--ucx-tls <value|none>] [--ucx-net-devices <value|none>] [--pmix-mca-gds <value|none>] [--mpi-use-mpi <0|1>] [--use-mpi-panel-broadcast <0-100>] [--prioritize-trsm <0|1>] [--prioritize-factorization <0|1>] [--anq-device <columns>] [--fill-device <0|1>] [--fill-device-buffer-size <MB>] [--call-dgemv-with-multiple-threads <threads>] [--preset-gemm-kernel <n>] [--cpu-affinity <map>] [--mem-affinity <map>] [--ucx-affinity <map>] [--u-panel-chunk-nbs <N>] [--scaling-study <exploratory|strong|weak>] [--baseline-matrix-size <N>] [--apply]

Default behavior is a dry run. Apply mode submits a guarded HPL-MxP smoke,
staged, campaign-candidate, or weak-study row. The weak-study preset
uses the reviewed weak-scaling matrix ladder with the derived NPS4 affinity
profile.
Precision values are FP16, FP8, or B200-only FP4.
Full-node submissions default to --mem=0 so Slurm grants the node memory
cgroup; override --mem only for reviewed diagnostics.
EOF
}

validate_memory_request() {
  local value="$1"
  [[ -n "$value" ]] || aicr_die "--mem must not be empty"
  [[ "$value" =~ ^[0-9]+([KMGTP])?$ ]] || aicr_die "--mem must be a Slurm memory value such as 0, 512G, or 1T"
}

default_partition() {
  case "$1" in
    b200) printf 'b200-batch\n' ;;
    rtxpro6000) printf 'rtx-batch\n' ;;
    *) aicr_die "unsupported cluster: $1" ;;
  esac
}

default_matrix_size() {
  case "$3:$1:$2" in
    smoke:rtxpro6000:1|smoke:rtxpro6000:2|smoke:rtxpro6000:4) printf '8192\n' ;;
    smoke:b200:1|smoke:b200:2|smoke:b200:4|smoke:b200:8|smoke:b200:16) printf '8192\n' ;;
    staged:rtxpro6000:1) printf '65536\n' ;;
    staged:rtxpro6000:2) printf '98304\n' ;;
    staged:rtxpro6000:4) printf '131072\n' ;;
    staged:b200:1) printf '65536\n' ;;
    staged:b200:2) printf '98304\n' ;;
    staged:b200:4) printf '131072\n' ;;
    staged:b200:8) printf '185344\n' ;;
    staged:b200:16) printf '262144\n' ;;
    campaign-candidate:b200:1) printf '417000\n' ;;
    campaign-candidate:b200:4) printf '834000\n' ;;
    campaign-candidate:b200:16) printf '1668000\n' ;;
    campaign-candidate:rtxpro6000:1) printf '409600\n' ;;
    campaign-candidate:rtxpro6000:4) printf '409600\n' ;;
    weak-study:b200:1|weak-study:rtxpro6000:1) printf '379904\n' ;;
    weak-study:b200:2|weak-study:rtxpro6000:2) printf '530432\n' ;;
    weak-study:b200:4|weak-study:rtxpro6000:4) printf '749568\n' ;;
    weak-study:b200:8) printf '1049600\n' ;;
    weak-study:b200:16) printf '1500160\n' ;;
    *) aicr_die "no reviewed HPL-MxP matrix-size target for cluster=$1 nodes=$2 preset=$3" ;;
  esac
}

default_nb() {
  case "$1:$2" in
    smoke:*) printf '1024\n' ;;
    staged:*) printf '2048\n' ;;
    campaign-candidate:*) printf '2048\n' ;;
    weak-study:*) printf '2048\n' ;;
    *) aicr_die "unsupported HPL-MxP preset: $1" ;;
  esac
}

weak_study_grid() {
  case "$1" in
    1) printf '4 2\n' ;;
    2) printf '4 4\n' ;;
    4) printf '4 8\n' ;;
    8) printf '8 8\n' ;;
    16) printf '16 8\n' ;;
    *) aicr_die "no weak-study processor-grid policy for nodes=$1" ;;
  esac
}

derived_nps4_ucx_affinity() {
  case "$1" in
    b200) printf 'mlx5_0:mlx5_1:mlx5_2:mlx5_3:mlx5_4:mlx5_5:mlx5_6:mlx5_11\n' ;;
    rtxpro6000) printf 'mlx5_0:mlx5_0:mlx5_0:mlx5_0:mlx5_3:mlx5_3:mlx5_3:mlx5_3\n' ;;
    *) aicr_die "unsupported cluster for derived-nps4 affinity: $1" ;;
  esac
}

quote_args() {
  local out=""
  local item
  for item in "$@"; do
    if [[ -z "$out" ]]; then
      printf -v out '%q' "$item"
    else
      printf -v out '%s %q' "$out" "$item"
    fi
  done
  printf '%s\n' "$out"
}

aicr_require_repo_root
aicr_mkdirs

repo_python=(aicr_python)

cluster=""
nodes=""
matrix_size="auto"
nb="auto"
nprow="auto"
npcol="auto"
preset="${HPL_MXP_PRESET:-smoke}"
partition=""
time_limit="${HPL_MXP_TIME:-00:30:00}"
memory_request="${HPL_MXP_MEM:-0}"
image="${HPL_MXP_IMAGE:-${AICR_APPTAINER_IMAGE_DIR}/hpc-benchmarks-26.02.sif}"
sloppy_type="${HPL_MXP_SLOPPY_TYPE:-FP16}"
test_loop="${HPL_MXP_TEST_LOOP:-1}"
repeat_count="${HPL_MXP_REPEAT_COUNT:-1}"
repeat_stagger_seconds="${HPL_MXP_REPEAT_STAGGER_SECONDS:-30}"
cpus_per_task="${HPL_MXP_CPUS_PER_TASK:-16}"
ompi_coll="${HPL_MXP_OMPI_COLL:-^ucc}"
ompi_pml="${HPL_MXP_OMPI_PML:-}"
ompi_btl="${HPL_MXP_OMPI_BTL:-}"
ompi_btl_tcp_if_include="${HPL_MXP_OMPI_BTL_TCP_IF_INCLUDE:-}"
ompi_oob_tcp_if_include="${HPL_MXP_OMPI_OOB_TCP_IF_INCLUDE:-}"
ucx_tls="${HPL_MXP_UCX_TLS:-}"
ucx_net_devices="${HPL_MXP_UCX_NET_DEVICES:-}"
pmix_mca_gds="${HPL_MXP_PMIX_MCA_GDS:-^ds12}"
mpi_use_mpi="${HPL_MXP_MPI_USE_MPI:-0}"
mpi_panel_broadcast="${HPL_MXP_MPI_PANEL_BROADCAST:-1}"
prioritize_trsm="${HPL_MXP_PRIORITIZE_TRSM:-0}"
prioritize_factorization="${HPL_MXP_PRIORITIZE_FACTORIZATION:-0}"
anq_device="${HPL_MXP_ANQ_DEVICE:-}"
fill_device="${HPL_MXP_FILL_DEVICE:-}"
fill_device_buffer_size="${HPL_MXP_FILL_DEVICE_BUFFER_SIZE:-}"
call_dgemv_threads="${HPL_MXP_CALL_DGEMV_THREADS:-}"
preset_gemm_kernel="${HPL_MXP_PRESET_GEMM_KERNEL:-}"
affinity_profile="${HPL_MXP_AFFINITY_PROFILE:-derived-nps4}"
cpu_affinity="${HPL_MXP_CPU_AFFINITY:-}"
mem_affinity="${HPL_MXP_MEM_AFFINITY:-}"
ucx_affinity="${HPL_MXP_UCX_AFFINITY:-}"
u_panel_chunk_nbs="${HPL_MXP_U_PANEL_CHUNK_NBS:-8}"
scaling_study="${HPL_MXP_SCALING_STUDY:-exploratory}"
baseline_matrix_size="${HPL_MXP_BASELINE_MATRIX_SIZE:-}"
nodelist=""
from_node_report=0
date_arg="today"
apply=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) cluster="${2:-}"; shift 2 ;;
    --nodes) nodes="${2:-}"; shift 2 ;;
    --preset) preset="${2:-}"; shift 2 ;;
    --matrix-size) matrix_size="${2:-}"; shift 2 ;;
    --nb) nb="${2:-}"; shift 2 ;;
    --nprow) nprow="${2:-}"; shift 2 ;;
    --npcol) npcol="${2:-}"; shift 2 ;;
    --partition) partition="${2:-}"; shift 2 ;;
    --time) time_limit="${2:-}"; shift 2 ;;
    --mem) memory_request="${2:-}"; shift 2 ;;
    --image) image="${2:-}"; shift 2 ;;
    --sloppy-type) sloppy_type="${2:-}"; shift 2 ;;
    --test-loop) test_loop="${2:-}"; shift 2 ;;
    --repeat-count) repeat_count="${2:-}"; shift 2 ;;
    --repeat-stagger-seconds) repeat_stagger_seconds="${2:-}"; shift 2 ;;
    --cpus-per-task) cpus_per_task="${2:-}"; shift 2 ;;
    --ompi-coll) ompi_coll="${2:-}"; shift 2 ;;
    --ompi-pml) ompi_pml="${2:-}"; shift 2 ;;
    --ompi-btl) ompi_btl="${2:-}"; shift 2 ;;
    --ompi-btl-tcp-if-include) ompi_btl_tcp_if_include="${2:-}"; shift 2 ;;
    --ompi-oob-tcp-if-include) ompi_oob_tcp_if_include="${2:-}"; shift 2 ;;
    --ucx-tls) ucx_tls="${2:-}"; shift 2 ;;
    --ucx-net-devices) ucx_net_devices="${2:-}"; shift 2 ;;
    --pmix-mca-gds) pmix_mca_gds="${2:-}"; shift 2 ;;
    --mpi-use-mpi) mpi_use_mpi="${2:-}"; shift 2 ;;
    --use-mpi-panel-broadcast) mpi_panel_broadcast="${2:-}"; shift 2 ;;
    --prioritize-trsm) prioritize_trsm="${2:-}"; shift 2 ;;
    --prioritize-factorization) prioritize_factorization="${2:-}"; shift 2 ;;
    --anq-device) anq_device="${2:-}"; shift 2 ;;
    --fill-device) fill_device="${2:-}"; shift 2 ;;
    --fill-device-buffer-size) fill_device_buffer_size="${2:-}"; shift 2 ;;
    --call-dgemv-with-multiple-threads) call_dgemv_threads="${2:-}"; shift 2 ;;
    --preset-gemm-kernel) preset_gemm_kernel="${2:-}"; shift 2 ;;
    --affinity-profile) affinity_profile="${2:-}"; shift 2 ;;
    --cpu-affinity) cpu_affinity="${2:-}"; shift 2 ;;
    --mem-affinity) mem_affinity="${2:-}"; shift 2 ;;
    --ucx-affinity) ucx_affinity="${2:-}"; shift 2 ;;
    --u-panel-chunk-nbs) u_panel_chunk_nbs="${2:-}"; shift 2 ;;
    --scaling-study) scaling_study="${2:-}"; shift 2 ;;
    --baseline-matrix-size) baseline_matrix_size="${2:-}"; shift 2 ;;
    --nodelist) nodelist="${2:-}"; shift 2 ;;
    --from-node-report) from_node_report=1; shift ;;
    --date) date_arg="${2:-}"; shift 2 ;;
    --apply) apply=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) aicr_die "unknown argument: $1" ;;
  esac
done

[[ -n "$cluster" ]] || { usage; exit 2; }
[[ -n "$nodes" ]] || { usage; exit 2; }
aicr_assert_supported_cluster "$cluster"
if [[ "$preset" == "campaign" ]]; then
  echo "HPL_MXP_PRESET=campaign is a compatibility alias; recording as campaign-candidate." >&2
  preset="campaign-candidate"
fi

case "$cluster:$nodes" in
  b200:1|b200:2|b200:4|b200:8|b200:16|rtxpro6000:1|rtxpro6000:2|rtxpro6000:4) ;;
  *) aicr_die "unsupported HPL-MxP node shape: cluster=${cluster} nodes=${nodes}" ;;
esac
if [[ "$cluster" == "$AICR_CLUSTER_B200" && "$preset" == "campaign-candidate" ]]; then
  case "$nodes" in
    1|4|16) ;;
    *) aicr_die "b200:${nodes} has no reviewed campaign-candidate matrix-size target; use --matrix-size with smoke or staged" ;;
  esac
fi
if [[ "$cluster:$nodes" == "rtxpro6000:2" && "$preset" == "campaign-candidate" ]]; then
  aicr_die "rtxpro6000:2 has no campaign-candidate target; use HPL_MXP_PRESET=smoke or staged"
fi
case "$preset" in smoke|staged|campaign-candidate|weak-study) ;; *) aicr_die "--preset must be smoke, staged, campaign-candidate, or weak-study" ;; esac
case "$affinity_profile" in ""|none|derived-nps4) ;; *) aicr_die "--affinity-profile must be none or derived-nps4" ;; esac
if [[ "$preset" == "weak-study" ]]; then
  if [[ -z "$affinity_profile" ]]; then
    affinity_profile="derived-nps4"
  elif [[ "$affinity_profile" == "none" ]]; then
    aicr_die "weak-study rows must use --affinity-profile derived-nps4"
  fi
  if [[ "$scaling_study" == "exploratory" ]]; then
    scaling_study="weak"
  elif [[ "$scaling_study" != "weak" ]]; then
    aicr_die "weak-study rows must use --scaling-study weak"
  fi
  read -r weak_study_nprow weak_study_npcol < <(weak_study_grid "$nodes")
  if [[ "$nprow" == "auto" ]]; then
    nprow="$weak_study_nprow"
  fi
  if [[ "$npcol" == "auto" ]]; then
    npcol="$weak_study_npcol"
  fi
  mpi_use_mpi=1
  mpi_panel_broadcast=50
  prioritize_trsm=0
  prioritize_factorization=1
  anq_device="${anq_device:-0}"
  call_dgemv_threads="${call_dgemv_threads:-0}"
  preset_gemm_kernel="${preset_gemm_kernel:-0}"
  u_panel_chunk_nbs=16
fi
if [[ "$affinity_profile" == "derived-nps4" ]]; then
  cpu_affinity="16-31:32-47:48-63:0-15:80-95:96-111:112-127:64-79"
  mem_affinity="1:2:3:0:5:6:7:4"
  ucx_affinity="$(derived_nps4_ucx_affinity "$cluster")"
fi
[[ "$time_limit" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || aicr_die "--time must be HH:MM:SS"
validate_memory_request "$memory_request"
sloppy_type="$(printf '%s' "$sloppy_type" | tr '[:lower:]' '[:upper:]')"
case "$sloppy_type" in FP4|FP8|FP16) ;; *) aicr_die "--sloppy-type must be FP4, FP8, or FP16" ;; esac
if [[ "$sloppy_type" == "FP4" && "$cluster" != "$AICR_CLUSTER_B200" ]]; then
  aicr_die "--sloppy-type FP4 is supported by this public wrapper only for cluster=b200"
fi
[[ "$test_loop" =~ ^[0-9]+$ && "$test_loop" -gt 0 ]] || aicr_die "--test-loop must be a positive integer"
[[ "$repeat_count" =~ ^[0-9]+$ && "$repeat_count" -gt 0 ]] || aicr_die "--repeat-count must be a positive integer"
[[ "$repeat_stagger_seconds" =~ ^[0-9]+$ ]] || aicr_die "--repeat-stagger-seconds must be a nonnegative integer"
[[ "$nprow" == "auto" || "$nprow" =~ ^[0-9]+$ ]] || aicr_die "--nprow must be auto or a positive integer"
[[ "$npcol" == "auto" || "$npcol" =~ ^[0-9]+$ ]] || aicr_die "--npcol must be auto or a positive integer"
[[ "$nprow" == "auto" || "$nprow" -gt 0 ]] || aicr_die "--nprow must be auto or a positive integer"
[[ "$npcol" == "auto" || "$npcol" -gt 0 ]] || aicr_die "--npcol must be auto or a positive integer"
[[ "$mpi_use_mpi" =~ ^[01]$ ]] || aicr_die "--mpi-use-mpi must be 0 or 1"
[[ "$mpi_panel_broadcast" =~ ^[0-9]+$ && "$mpi_panel_broadcast" -le 100 ]] || aicr_die "--use-mpi-panel-broadcast must be 0..100"
[[ "$prioritize_trsm" =~ ^[01]$ ]] || aicr_die "--prioritize-trsm must be 0 or 1"
[[ "$prioritize_factorization" =~ ^[01]$ ]] || aicr_die "--prioritize-factorization must be 0 or 1"
[[ -z "$cpus_per_task" || "$cpus_per_task" =~ ^[0-9]+$ ]] || aicr_die "--cpus-per-task must be a positive integer"
[[ -z "$cpus_per_task" || "$cpus_per_task" -gt 0 ]] || aicr_die "--cpus-per-task must be a positive integer"
[[ -z "$anq_device" || "$anq_device" =~ ^[0-9]+$ ]] || aicr_die "--anq-device must be a nonnegative integer"
[[ -z "$fill_device" || "$fill_device" =~ ^[01]$ ]] || aicr_die "--fill-device must be 0 or 1"
[[ -z "$fill_device_buffer_size" || "$fill_device_buffer_size" =~ ^[0-9]+$ ]] || aicr_die "--fill-device-buffer-size must be a nonnegative integer"
[[ -z "$call_dgemv_threads" || "$call_dgemv_threads" =~ ^[0-9]+$ ]] || aicr_die "--call-dgemv-with-multiple-threads must be a nonnegative integer"
[[ -z "$preset_gemm_kernel" || "$preset_gemm_kernel" =~ ^[0-9]+$ ]] || aicr_die "--preset-gemm-kernel must be a nonnegative integer"
[[ "$u_panel_chunk_nbs" =~ ^[0-9]+$ && "$u_panel_chunk_nbs" -gt 0 ]] || aicr_die "--u-panel-chunk-nbs must be a positive integer"
case "$scaling_study" in exploratory|strong|weak) ;; *) aicr_die "--scaling-study must be exploratory, strong, or weak" ;; esac
[[ -z "$baseline_matrix_size" || "$baseline_matrix_size" =~ ^[0-9]+$ ]] || aicr_die "--baseline-matrix-size must be a positive integer"
[[ -z "$baseline_matrix_size" || "$baseline_matrix_size" -gt 0 ]] || aicr_die "--baseline-matrix-size must be a positive integer"
if [[ "$from_node_report" -eq 1 ]]; then
  [[ -z "$nodelist" ]] || aicr_die "--from-node-report and --nodelist cannot be combined"
  nodelist="$("${repo_python[@]}" "${BENCHMARK_DIR}/select-benchmark-nodes.py" --date "$date_arg" --cluster "$cluster" --count "$nodes")"
fi
partition="${partition:-$(default_partition "$cluster")}"
if [[ "$matrix_size" == "auto" ]]; then
  matrix_size="$(default_matrix_size "$cluster" "$nodes" "$preset")"
fi
[[ "$matrix_size" =~ ^[0-9]+$ && "$matrix_size" -gt 0 ]] || aicr_die "--matrix-size must be auto or a positive integer"
if [[ "$nb" == "auto" ]]; then
  nb="$(default_nb "$preset" "$cluster")"
fi
[[ "$nb" =~ ^[0-9]+$ && "$nb" -gt 0 ]] || aicr_die "--nb must be auto or a positive integer"

sloppy_slug="$(printf '%s' "$sloppy_type" | tr '[:upper:]' '[:lower:]')"
job_name="${cluster}-hpl-mxp-${preset}-${sloppy_slug}-${scaling_study}-${nodes}n"
runner_cmd=(
  ./scripts/benchmark/run-hpl-mxp.sh
  --cluster "$cluster"
  --nodes "$nodes"
  --preset "$preset"
  --matrix-size "$matrix_size"
  --nb "$nb"
  --nprow "$nprow"
  --npcol "$npcol"
  --image "$image"
  --sloppy-type "$sloppy_type"
  --test-loop "$test_loop"
  --ompi-coll "$ompi_coll"
  --ompi-pml "$ompi_pml"
  --ompi-btl "$ompi_btl"
  --ompi-btl-tcp-if-include "$ompi_btl_tcp_if_include"
  --ompi-oob-tcp-if-include "$ompi_oob_tcp_if_include"
  --ucx-tls "$ucx_tls"
  --ucx-net-devices "$ucx_net_devices"
  --pmix-mca-gds "$pmix_mca_gds"
  --mpi-use-mpi "$mpi_use_mpi"
  --use-mpi-panel-broadcast "$mpi_panel_broadcast"
  --prioritize-trsm "$prioritize_trsm"
  --prioritize-factorization "$prioritize_factorization"
  --u-panel-chunk-nbs "$u_panel_chunk_nbs"
  --scaling-study "$scaling_study"
)
if [[ -n "$baseline_matrix_size" ]]; then
  runner_cmd+=(--baseline-matrix-size "$baseline_matrix_size")
fi
if [[ -n "$anq_device" ]]; then
  runner_cmd+=(--anq-device "$anq_device")
fi
if [[ -n "$fill_device" ]]; then
  runner_cmd+=(--fill-device "$fill_device")
fi
if [[ -n "$fill_device_buffer_size" ]]; then
  runner_cmd+=(--fill-device-buffer-size "$fill_device_buffer_size")
fi
if [[ -n "$call_dgemv_threads" ]]; then
  runner_cmd+=(--call-dgemv-with-multiple-threads "$call_dgemv_threads")
fi
if [[ -n "$preset_gemm_kernel" ]]; then
  runner_cmd+=(--preset-gemm-kernel "$preset_gemm_kernel")
fi
if [[ -n "$cpu_affinity" ]]; then
  runner_cmd+=(--cpu-affinity "$cpu_affinity")
fi
if [[ -n "$mem_affinity" ]]; then
  runner_cmd+=(--mem-affinity "$mem_affinity")
fi
if [[ -n "$ucx_affinity" ]]; then
  runner_cmd+=(--ucx-affinity "$ucx_affinity")
fi
wrap_cmd="cd $(quote_args "$AICR_BMARK_DIR") && $(quote_args "${runner_cmd[@]}")"
sbatch_cmd=(
  sbatch
  --parsable
  --partition="$partition"
  --nodes="$nodes"
  --ntasks-per-node=8
  --gres="$([[ "$cluster" == "b200" ]] && printf 'gpu:b200:8' || printf 'gpu:8')"
  --time="$time_limit"
  --mem="$memory_request"
  --job-name="$job_name"
  --output="results/slurm/%x-%j.out"
  --error="results/slurm/%x-%j.err"
)
if [[ -n "$cpus_per_task" ]]; then
  sbatch_cmd+=(--cpus-per-task="$cpus_per_task")
fi
if [[ -n "$nodelist" ]]; then
  sbatch_cmd+=(--nodelist="$nodelist")
fi
sbatch_cmd+=(--wrap="$wrap_cmd")

if [[ "$apply" -eq 1 ]]; then
  echo "HPL-MxP submit"
else
  echo "HPL-MxP dry run"
fi
echo "  Cluster     : ${cluster}"
echo "  Nodes       : ${nodes}"
echo "  Preset      : ${preset}"
echo "  Matrix N    : ${matrix_size}"
echo "  NB          : ${nb}"
echo "  NPROW       : ${nprow}"
echo "  NPCOL       : ${npcol}"
echo "  Sloppy type : ${sloppy_type}"
echo "  Test loop   : ${test_loop}"
echo "  Repeats     : ${repeat_count}"
echo "  Stagger sec : ${repeat_stagger_seconds}"
echo "  OMPI coll   : ${ompi_coll}"
echo "  OMPI pml    : ${ompi_pml:-default}"
echo "  OMPI btl    : ${ompi_btl:-default}"
echo "  BTL iface   : ${ompi_btl_tcp_if_include:-default}"
echo "  OOB iface   : ${ompi_oob_tcp_if_include:-default}"
echo "  UCX TLS     : ${ucx_tls:-default}"
echo "  UCX devices : ${ucx_net_devices:-default}"
echo "  PMIx GDS    : ${pmix_mca_gds}"
echo "  MPI use MPI : ${mpi_use_mpi}"
echo "  MPI panel % : ${mpi_panel_broadcast}"
echo "  Prior TRSM  : ${prioritize_trsm}"
echo "  Prior fact  : ${prioritize_factorization}"
echo "  U-panel NBs : ${u_panel_chunk_nbs}"
echo "  Aff profile : ${affinity_profile:-none}"
echo "  Scaling     : ${scaling_study}"
if [[ -n "$baseline_matrix_size" ]]; then
  echo "  Baseline N  : ${baseline_matrix_size}"
fi
if [[ -n "$anq_device" ]]; then
  echo "  Anq device  : ${anq_device}"
fi
if [[ -n "$fill_device" ]]; then
  echo "  Fill device : ${fill_device}"
fi
if [[ -n "$fill_device_buffer_size" ]]; then
  echo "  Fill buffer : ${fill_device_buffer_size} MB"
fi
if [[ -n "$call_dgemv_threads" ]]; then
  echo "  DGEMV thrds : ${call_dgemv_threads}"
fi
if [[ -n "$preset_gemm_kernel" ]]; then
  echo "  GEMM kernel : ${preset_gemm_kernel}"
fi
if [[ -n "$cpus_per_task" ]]; then
  echo "  CPUs/task   : ${cpus_per_task}"
fi
if [[ -n "$cpu_affinity" ]]; then
  echo "  CPU affinity: ${cpu_affinity}"
fi
if [[ -n "$mem_affinity" ]]; then
  echo "  Mem affinity: ${mem_affinity}"
fi
if [[ -n "$ucx_affinity" ]]; then
  echo "  UCX affinity: ${ucx_affinity}"
fi
echo "  Image       : ${image}"
echo "  Partition   : ${partition}"
echo "  Slurm mem   : ${memory_request}"
if [[ -n "$nodelist" ]]; then
  echo "  Node list   : ${nodelist}"
fi
printf '  Would submit: '
printf '%q ' "${sbatch_cmd[@]}"
echo

if [[ "$apply" -eq 1 ]]; then
  submitted=()
  for repeat_index in $(seq 1 "$repeat_count"); do
    job_id="$("${sbatch_cmd[@]}")"
    submitted+=("$job_id")
    echo "Submitted HPL-MxP ${preset} repeat ${repeat_index}/${repeat_count} job ${job_id}"
    if [[ "$repeat_index" -lt "$repeat_count" && "$repeat_stagger_seconds" -gt 0 ]]; then
      sleep "$repeat_stagger_seconds"
    fi
  done
  printf 'Submitted HPL-MxP job ids: %s\n' "$(IFS=,; printf '%s' "${submitted[*]}")"
  exit 0
fi

echo "Dry run only. Re-run with --apply to submit ${repeat_count} HPL-MxP ${preset} row(s)."
