#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/dry-run-suite.sh --cluster <b200|rtxpro6000> --date <YYYY-MM-DD|today|yesterday> [--include-elbencho]

Runs the benchmark submission preflight from the acceptable-candidates node report.
No jobs are submitted. Scale points that need more acceptable candidates than
the report currently exposes are printed as availability-gated and skipped.
EOF
}

run_step() {
  local label="$1"
  shift
  echo
  echo "## ${label}"
  printf '+ '
  printf '%q ' "$@"
  echo
  "$@"
}

run_step_if_available() {
  local required_count="$1"
  local label="$2"
  shift 2
  if (( candidate_count < required_count )); then
    echo
    echo "## ${label}"
    echo "availability-gated: requested ${required_count} acceptable candidate nodes, found ${candidate_count}"
    return 0
  fi
  run_step "$label" "$@"
}

select_candidates() {
  local count="${1:-}"
  local cmd=(
    aicr_python "${BENCHMARK_DIR}/select-benchmark-nodes.py"
    --date "$date_arg"
    --cluster "$cluster"
    --format lines
  )
  if [[ -n "$count" ]]; then
    cmd+=(--count "$count")
  fi
  "${cmd[@]}"
}

aicr_require_repo_root
aicr_mkdirs

cluster=""
date_arg="today"
include_elbencho=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster)
      cluster="${2:-}"
      shift 2
      ;;
    --date)
      date_arg="${2:-}"
      shift 2
      ;;
    --include-elbencho)
      include_elbencho=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      aicr_die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$cluster" ]] || {
  usage
  exit 2
}
aicr_assert_supported_cluster "$cluster"

case "$cluster" in
  rtxpro6000)
    dataloader_scales=(2 4)
    ddp_torchrun_scales=(1 4)
    ddp_scales=(1 4)
    hpl_scales=(1 4)
    hpl_weak_study_scales=(1 2 4)
    ;;
  b200)
    dataloader_scales=(2 4 8 16)
    ddp_torchrun_scales=(1 4 8 16)
    ddp_scales=(1 4 8 16)
    hpl_scales=(1 4 16)
    hpl_weak_study_scales=(1 2 4 8 16)
    ;;
esac

echo "Benchmark submission preflight"
echo "  Cluster          : ${cluster}"
echo "  Node report date : ${date_arg}"
echo "  Source           : acceptable candidates from by-node report"
echo
echo "Acceptable candidates:"
candidate_lines="$(select_candidates)"
candidate_count="$(printf '%s\n' "$candidate_lines" | sed '/^$/d' | wc -l | tr -d ' ')"
if (( candidate_count < 1 )); then
  aicr_die "no acceptable candidate nodes found for cluster=${cluster} date=${date_arg}"
fi
printf '%s\n' "$candidate_lines" | sed 's/^/  - /'

dataloader_smoke_args=(--warmup-batches 5 --measured-batches 10 --h2d 1 --transfer-labels 1)
ddp_smoke_args=(--warmup-iters 2 --measured-iters 2)

run_step_if_available 1 "DataLoader 1n single 1 GPU" \
  bash "${BENCHMARK_DIR}/submit-dataloader.sh" \
    --cluster "$cluster" \
    --nodes 1 \
    --gpu-count 1 \
    --mode single \
    --from-node-report \
    --date "$date_arg" \
    -- "${dataloader_smoke_args[@]}"

run_step_if_available 1 "DataLoader 1n replicated 8 GPU" \
  bash "${BENCHMARK_DIR}/submit-dataloader.sh" \
    --cluster "$cluster" \
    --nodes 1 \
    --gpu-count 8 \
    --mode replicated \
    --from-node-report \
    --date "$date_arg" \
    -- "${dataloader_smoke_args[@]}"

for nodes in "${dataloader_scales[@]}"; do
  run_step_if_available "$nodes" "DataLoader ${nodes}n distributed-sharded" \
    bash "${BENCHMARK_DIR}/submit-dataloader.sh" \
      --cluster "$cluster" \
      --nodes "$nodes" \
      --gpu-count 8 \
      --mode distributed-sharded \
      --from-node-report \
      --date "$date_arg" \
      -- "${dataloader_smoke_args[@]}"
done

for nodes in "${ddp_torchrun_scales[@]}"; do
  run_step_if_available "$nodes" "DDP ResNet-50 ${nodes}n torchrun smoke" \
    bash "${BENCHMARK_DIR}/submit-ddp-resnet50.sh" \
      --cluster "$cluster" \
      --nodes "$nodes" \
      --launcher torchrun \
      --from-node-report \
      --date "$date_arg" \
      -- "${ddp_smoke_args[@]}"
done

for nodes in "${ddp_scales[@]}"; do
  run_step_if_available "$nodes" "DDP ResNet-50 ${nodes}n srun smoke" \
    bash "${BENCHMARK_DIR}/submit-ddp-resnet50.sh" \
      --cluster "$cluster" \
      --nodes "$nodes" \
      --launcher srun \
      --from-node-report \
      --date "$date_arg" \
      -- "${ddp_smoke_args[@]}"
done

for nodes in "${hpl_scales[@]}"; do
  run_step_if_available "$nodes" "HPL-MxP ${nodes}n smoke" \
    bash "${BENCHMARK_DIR}/submit-hpl-mxp.sh" \
      --cluster "$cluster" \
      --nodes "$nodes" \
      --preset smoke \
      --from-node-report \
      --date "$date_arg"
done

for nodes in "${hpl_weak_study_scales[@]}"; do
  run_step_if_available "$nodes" "HPL-MxP ${nodes}n weak-study dry run" \
    bash "${BENCHMARK_DIR}/submit-hpl-mxp.sh" \
      --cluster "$cluster" \
      --nodes "$nodes" \
      --preset weak-study \
      --affinity-profile derived-nps4 \
      --scaling-study weak \
      --baseline-matrix-size 379904 \
      --time 01:00:00 \
      --repeat-count 5 \
      --repeat-stagger-seconds 5 \
      --from-node-report \
      --date "$date_arg"
done

if [[ "$include_elbencho" -eq 1 ]]; then
  if [[ -z "${ELBENCHO_CMD:-}" ]]; then
    run_step_if_available 1 "Elbencho command gate dry run" \
      bash "${BENCHMARK_DIR}/submit-elbencho.sh" \
        --cluster "$cluster" \
        --workload small-block \
        --nodes 1 \
        --from-node-report \
        --date "$date_arg"
  else
    for workload in small-block small-file metadata; do
      run_step_if_available 1 "Elbencho ${workload} surrogate dry run" \
        bash "${BENCHMARK_DIR}/submit-elbencho.sh" \
          --cluster "$cluster" \
          --workload "$workload" \
          --nodes 1 \
          --from-node-report \
          --date "$date_arg"
    done
  fi
else
  echo
  echo "## Elbencho"
  echo "Skipped by default. Use --include-elbencho after storage-plan review for this cluster."
fi

echo
echo "Benchmark dry-run suite complete. No jobs were submitted."
