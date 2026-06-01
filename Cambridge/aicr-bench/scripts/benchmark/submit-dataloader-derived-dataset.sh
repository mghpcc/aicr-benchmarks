#!/usr/bin/env bash
set -euo pipefail

BENCHMARK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${BENCHMARK_DIR}/../verify/_common.sh"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/benchmark/submit-dataloader-derived-dataset.sh [--dataset-root <path>] --derived-root <path> [--split <train|val>] [--samples-per-class <n>] [--seed <n>] [--image-size-list <csv>] [--formats <csv>] [--numpy-block-size <n>] [--jpeg-quality <n>] [--partition <name>] [--time <HH:MM:SS>] [--cpus-per-task <n>] [--mem <size>] [--nodelist <node>] [--write] [--overwrite] [--apply]

Default behavior is a dry run: print the CPU Slurm command that would run the
derived-dataset planner. Passing --apply submits the CPU Slurm job. Passing
--write also forwards --apply to prepare-dataloader-derived-dataset.py, so it
writes derived datasets. Without --write, even a submitted job remains a dry-run
planner and writes no derived dataset outputs.
The Slurm memory request defaults to --mem=0 so the job receives the node
memory cgroup.
EOF
}

validate_positive_int() {
  local label="$1"
  local value="$2"
  [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 ]] || aicr_die "${label} must be a positive integer"
}

aicr_require_repo_root
aicr_mkdirs

dataset_root="${AICR_IMAGENET_DIR:-}"
derived_root="${AICR_DATALOADER_DERIVED_ROOT:-}"
split="train"
samples_per_class="16"
seed="1234"
image_size_list="224,384,512"
formats="jpeg,numpy-uint8,numpy-fp16"
numpy_block_size="128"
jpeg_quality="95"
partition="cpu"
time_limit="04:00:00"
cpus_per_task="16"
mem="${DATALOADER_PREP_MEM:-0}"
nodelist=""
write_outputs=0
overwrite=0
apply=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dataset-root)
      dataset_root="${2:-}"
      shift 2
      ;;
    --derived-root)
      derived_root="${2:-}"
      shift 2
      ;;
    --split)
      split="${2:-}"
      shift 2
      ;;
    --samples-per-class)
      samples_per_class="${2:-}"
      shift 2
      ;;
    --seed)
      seed="${2:-}"
      shift 2
      ;;
    --image-size-list)
      image_size_list="${2:-}"
      shift 2
      ;;
    --formats)
      formats="${2:-}"
      shift 2
      ;;
    --numpy-block-size)
      numpy_block_size="${2:-}"
      shift 2
      ;;
    --jpeg-quality)
      jpeg_quality="${2:-}"
      shift 2
      ;;
    --partition)
      partition="${2:-}"
      shift 2
      ;;
    --time)
      time_limit="${2:-}"
      shift 2
      ;;
    --cpus-per-task)
      cpus_per_task="${2:-}"
      shift 2
      ;;
    --mem)
      mem="${2:-}"
      shift 2
      ;;
    --nodelist|--node)
      nodelist="${2:-}"
      shift 2
      ;;
    --write)
      write_outputs=1
      shift
      ;;
    --overwrite)
      overwrite=1
      shift
      ;;
    --apply)
      apply=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

[[ -n "$dataset_root" ]] || aicr_die "--dataset-root or AICR_IMAGENET_DIR is required"
[[ -n "$derived_root" ]] || aicr_die "--derived-root or AICR_DATALOADER_DERIVED_ROOT is required"
case "$split" in
  train|val) ;;
  *) aicr_die "--split must be train or val" ;;
esac
validate_positive_int "--samples-per-class" "$samples_per_class"
validate_positive_int "--numpy-block-size" "$numpy_block_size"
[[ "$seed" =~ ^[0-9]+$ ]] || aicr_die "--seed must be a non-negative integer"
validate_positive_int "--jpeg-quality" "$jpeg_quality"
[[ "$time_limit" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] || aicr_die "--time must be HH:MM:SS"
validate_positive_int "--cpus-per-task" "$cpus_per_task"
[[ -n "$partition" ]] || aicr_die "--partition must not be empty"
[[ -n "$mem" ]] || aicr_die "--mem must not be empty"
[[ "$mem" =~ ^[0-9]+([KMGTP])?$ ]] || aicr_die "--mem must be a Slurm memory value such as 0, 512G, or 1T"
sbatch_script="slurm/benchmark/dataloader-derived-dataset-cpu.sbatch"
[[ -f "$sbatch_script" ]] || aicr_die "missing Slurm script: ${sbatch_script}"

helper_args=(
  --dataset-root "$dataset_root"
  --split "$split"
  --derived-root "$derived_root"
  --samples-per-class "$samples_per_class"
  --seed "$seed"
  --image-size-list "$image_size_list"
  --formats "$formats"
  --numpy-block-size "$numpy_block_size"
  --jpeg-quality "$jpeg_quality"
)
if [[ "$write_outputs" -eq 1 ]]; then
  helper_args+=(--apply)
fi
if [[ "$overwrite" -eq 1 ]]; then
  helper_args+=(--overwrite)
fi

sbatch_cmd=(
  sbatch
  --parsable
  --partition "$partition"
  --time "$time_limit"
  --nodes 1
  --ntasks 1
  --cpus-per-task "$cpus_per_task"
  --mem "$mem"
  --output "results/setup/dataloader-derived-dataset-%j.out"
  --error "results/setup/dataloader-derived-dataset-%j.err"
)
if [[ -n "$nodelist" ]]; then
  sbatch_cmd+=(--nodelist "$nodelist")
fi
sbatch_cmd+=("$sbatch_script")
sbatch_cmd+=("${helper_args[@]}")

echo "DataLoader derived dataset CPU submission"
echo "  Partition   : ${partition}"
echo "  Time limit  : ${time_limit}"
echo "  CPUs/task   : ${cpus_per_task}"
echo "  Memory      : ${mem}"
echo "  Dataset root: ${dataset_root}"
echo "  Derived root: ${derived_root}"
echo "  Split       : ${split}"
echo "  Samples/cls : ${samples_per_class}"
echo "  Seed        : ${seed}"
echo "  Image sizes : ${image_size_list}"
echo "  Formats     : ${formats}"
echo "  Prep write  : ${write_outputs}"
echo "  Overwrite   : ${overwrite}"
if [[ -n "$nodelist" ]]; then
  echo "  Node list   : ${nodelist}"
fi
printf '  Command     : '
printf '%q ' "${sbatch_cmd[@]}"
echo

if [[ "$apply" -eq 0 ]]; then
  echo "Dry run only. Pass --apply to submit the CPU Slurm job."
  echo "Planner mode. Add --write with --apply only after reviewing storage estimates."
  exit 0
fi

aicr_require_settings_file
mkdir -p results/setup
job_id="$("${sbatch_cmd[@]}")"
job_id="${job_id%%;*}"
echo "Submitted DataLoader derived dataset prep job ${job_id}"
echo "stdout: results/setup/dataloader-derived-dataset-${job_id}.out"
echo "stderr: results/setup/dataloader-derived-dataset-${job_id}.err"
