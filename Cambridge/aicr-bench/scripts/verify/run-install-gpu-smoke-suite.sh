#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/verify/run-install-gpu-smoke-suite.sh --rtx-nodes <node[,node...]> --b200-nodes <node[,node...]> [options]

Validate an installed AICR-Bench tree across the GPU Topology, GDS, NCCL,
HPL-MxP, DataLoader, and DDP public surfaces. Optional Elbencho storage smoke
coverage is disabled by default. The default mode is local checks plus Slurm
dry-runs only. Add --apply to run tiny node-scoped smoke jobs.

Required node arguments:
  --rtx-nodes <list>       RTX candidate nodes. First node is used for 1-node jobs;
                           first two nodes are used for RDMA unless --skip-rdma.
  --b200-nodes <list>      B200 candidate nodes. Same selection policy as RTX.

Options:
  --audit-root <path>      Evidence directory. Default:
                           /scratch/csim/validate/install-gpu-smoke-audit-<UTC>
  --date <YYYY-MM-DD>      Report date. Default: current UTC date.
  --apply                  Submit smoke jobs after dry-runs and GPU probes pass.
  --resume-from-audit-root <path>
                           Resume an interrupted apply run from an existing
                           audit root. Reuses recorded job IDs, skips local
                           checks, skips dry-runs, skips sbatch --test-only,
                           and continues with apply/report phases.
  --skip-local-checks      Skip docs/link/help/syntax checks.
  --skip-dry-runs          Skip Make/script dry-runs. Intended for resume only.
  --skip-explicit-sbatch   Skip sbatch --test-only coverage for Slurm templates.
  --skip-topology          Skip GPU Topology dry-run and apply coverage.
  --skip-gds               Skip GDS dry-run and apply coverage.
  --skip-nccl              Skip NCCL local/RDMA dry-run and apply coverage.
  --skip-rdma              Skip two-node NCCL RDMA dry-runs and apply jobs.
  --skip-hpl-mxp           Skip HPL-MxP dry-run and apply coverage.
  --skip-dataloader        Skip DataLoader dry-run and apply coverage.
  --skip-ddp               Skip DDP dry-run and apply coverage.
  --only-elbencho          Run only Elbencho plus required node preflight.
                           Implies --include-elbencho and skips other modules.
  --hpl-mxp-b200-node <n>  B200 node for HPL-MxP one-node smoke. Default:
                           first --b200-nodes entry.
  --hpl-mxp-rtx-node <n>   RTX node for HPL-MxP dry-run and optional apply.
                           Default: first --rtx-nodes entry.
  --hpl-mxp-apply-rtx      Include RTX HPL-MxP in --apply mode after RTX
                           preflight passes. B200 HPL-MxP apply is default.
  --hpl-mxp-time <HH:MM:SS>
                           HPL-MxP smoke time limit. Default: 00:10:00.
  --hpl-mxp-preset <name>  HPL-MxP preset. Default: smoke.
  --hpl-mxp-sloppy-type <precision>
                           HPL-MxP sloppy type. Default: FP16.
  --dataloader-time <HH:MM:SS>
                           DataLoader smoke time limit. Default: 00:10:00.
  --ddp-time <HH:MM:SS>    DDP smoke time limit. Default: 00:10:00.
  --include-elbencho       Include optional Elbencho runtime and tiny storage
                           smoke coverage. Requires the Elbencho image.
  --elbencho-b200-node <n> B200 node for Elbencho smoke. Default:
                           first --b200-nodes entry.
  --elbencho-rtx-node <n>  RTX node for Elbencho smoke. Default:
                           first --rtx-nodes entry.
  --elbencho-target-root <path>
                           Scratch target root. Default:
                           /scratch/$USER/elbencho/install-smoke-<UTC>
  --elbencho-time <HH:MM:SS>
                           Elbencho smoke time limit. Default: 00:10:00.
  --skip-rtx               Skip RTX coverage.
  --skip-b200              Skip B200 coverage.
  --no-render              Skip final report render commands.
  --render-only            Render reports from existing evidence and exit.
  -h, --help               Show this help.

Examples:
  # Dry-run and local-safe validation only.
  scripts/verify/run-install-gpu-smoke-suite.sh \
    --rtx-nodes a0002,a0003 --b200-nodes b0001,b0002

  # Apply tiny smoke jobs after the dry-run layer passes.
  scripts/verify/run-install-gpu-smoke-suite.sh \
    --rtx-nodes a0002,a0003 --b200-nodes b0001,b0002 --apply
EOF
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

rtx_nodes=""
b200_nodes=""
audit_root=""
report_date="$(date -u +%F)"
apply=0
resume=0
run_local_checks=1
run_dryruns=1
run_explicit_sbatch=1
run_topology=1
run_gds=1
run_nccl=1
run_rdm=1
run_hpl_mxp=1
run_dataloader=1
run_ddp=1
hpl_mxp_b200_node=""
hpl_mxp_rtx_node=""
hpl_mxp_apply_rtx=0
hpl_mxp_time="00:10:00"
hpl_mxp_preset="smoke"
hpl_mxp_sloppy_type="FP16"
dataloader_time="00:10:00"
ddp_time="00:10:00"
run_elbencho=0
elbencho_b200_node=""
elbencho_rtx_node=""
elbencho_target_root=""
elbencho_time="00:10:00"
run_rtx=1
run_b200=1
run_render=1
render_only=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rtx-nodes|--rtx-nodelist)
      rtx_nodes="${2:-}"
      shift 2
      ;;
    --b200-nodes|--b200-nodelist)
      b200_nodes="${2:-}"
      shift 2
      ;;
    --audit-root)
      audit_root="${2:-}"
      shift 2
      ;;
    --date)
      report_date="${2:-}"
      shift 2
      ;;
    --apply)
      apply=1
      shift
      ;;
    --resume-from-audit-root)
      audit_root="${2:-}"
      resume=1
      apply=1
      run_local_checks=0
      run_dryruns=0
      run_explicit_sbatch=0
      shift 2
      ;;
    --skip-local-checks)
      run_local_checks=0
      shift
      ;;
    --skip-dry-runs)
      run_dryruns=0
      shift
      ;;
    --skip-explicit-sbatch)
      run_explicit_sbatch=0
      shift
      ;;
    --skip-topology)
      run_topology=0
      shift
      ;;
    --skip-gds)
      run_gds=0
      shift
      ;;
    --skip-nccl)
      run_nccl=0
      shift
      ;;
    --skip-rdma)
      run_rdm=0
      shift
      ;;
    --skip-hpl-mxp)
      run_hpl_mxp=0
      shift
      ;;
    --skip-dataloader)
      run_dataloader=0
      shift
      ;;
    --skip-ddp)
      run_ddp=0
      shift
      ;;
    --only-elbencho)
      run_elbencho=1
      run_topology=0
      run_gds=0
      run_nccl=0
      run_rdm=0
      run_hpl_mxp=0
      run_dataloader=0
      run_ddp=0
      shift
      ;;
    --hpl-mxp-b200-node)
      hpl_mxp_b200_node="${2:-}"
      shift 2
      ;;
    --hpl-mxp-rtx-node)
      hpl_mxp_rtx_node="${2:-}"
      shift 2
      ;;
    --hpl-mxp-apply-rtx)
      hpl_mxp_apply_rtx=1
      shift
      ;;
    --hpl-mxp-time)
      hpl_mxp_time="${2:-}"
      shift 2
      ;;
    --hpl-mxp-preset)
      hpl_mxp_preset="${2:-}"
      shift 2
      ;;
    --hpl-mxp-sloppy-type)
      hpl_mxp_sloppy_type="${2:-}"
      shift 2
      ;;
    --dataloader-time)
      dataloader_time="${2:-}"
      shift 2
      ;;
    --ddp-time)
      ddp_time="${2:-}"
      shift 2
      ;;
    --include-elbencho)
      run_elbencho=1
      shift
      ;;
    --elbencho-b200-node)
      elbencho_b200_node="${2:-}"
      shift 2
      ;;
    --elbencho-rtx-node)
      elbencho_rtx_node="${2:-}"
      shift 2
      ;;
    --elbencho-target-root)
      elbencho_target_root="${2:-}"
      shift 2
      ;;
    --elbencho-time)
      elbencho_time="${2:-}"
      shift 2
      ;;
    --skip-rtx)
      run_rtx=0
      shift
      ;;
    --skip-b200)
      run_b200=0
      shift
      ;;
    --no-render)
      run_render=0
      shift
      ;;
    --render-only)
      render_only=1
      run_local_checks=0
      run_dryruns=0
      run_explicit_sbatch=0
      apply=0
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

if [[ "${run_rtx}" == "1" && -z "${rtx_nodes}" ]]; then
  echo "ERROR: --rtx-nodes is required unless --skip-rtx is used" >&2
  exit 2
fi
if [[ "${run_b200}" == "1" && -z "${b200_nodes}" ]]; then
  echo "ERROR: --b200-nodes is required unless --skip-b200 is used" >&2
  exit 2
fi
if [[ ! "${hpl_mxp_time}" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
  echo "ERROR: --hpl-mxp-time must be HH:MM:SS" >&2
  exit 2
fi
if [[ ! "${dataloader_time}" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
  echo "ERROR: --dataloader-time must be HH:MM:SS" >&2
  exit 2
fi
if [[ ! "${ddp_time}" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
  echo "ERROR: --ddp-time must be HH:MM:SS" >&2
  exit 2
fi
if [[ ! "${elbencho_time}" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
  echo "ERROR: --elbencho-time must be HH:MM:SS" >&2
  exit 2
fi
case "${hpl_mxp_preset}" in
  smoke) ;;
  *) echo "ERROR: install-smoke only supports --hpl-mxp-preset smoke" >&2; exit 2 ;;
esac
case "$(printf '%s' "${hpl_mxp_sloppy_type}" | tr '[:lower:]' '[:upper:]')" in
  FP16|FP8|FP4) ;;
  *) echo "ERROR: --hpl-mxp-sloppy-type must be FP16, FP8, or FP4" >&2; exit 2 ;;
esac
hpl_mxp_sloppy_type="$(printf '%s' "${hpl_mxp_sloppy_type}" | tr '[:lower:]' '[:upper:]')"
if [[ "${run_hpl_mxp}" == "1" ]]; then
  if [[ "${run_b200}" == "1" && -z "${hpl_mxp_b200_node}" ]]; then
    hpl_mxp_b200_node="$(printf '%s\n' "${b200_nodes}" | tr ',' '\n' | sed '/^$/d' | head -n 1)"
  fi
  if [[ "${run_rtx}" == "1" && -z "${hpl_mxp_rtx_node}" ]]; then
    hpl_mxp_rtx_node="$(printf '%s\n' "${rtx_nodes}" | tr ',' '\n' | sed '/^$/d' | head -n 1)"
  fi
fi
if [[ "${run_elbencho}" == "1" ]]; then
  if [[ "${run_b200}" == "1" && -z "${elbencho_b200_node}" ]]; then
    elbencho_b200_node="$(printf '%s\n' "${b200_nodes}" | tr ',' '\n' | sed '/^$/d' | head -n 1)"
  fi
  if [[ "${run_rtx}" == "1" && -z "${elbencho_rtx_node}" ]]; then
    elbencho_rtx_node="$(printf '%s\n' "${rtx_nodes}" | tr ',' '\n' | sed '/^$/d' | head -n 1)"
  fi
fi
case "${report_date}" in
  today)
    report_date="$(date -u +%F)"
    ;;
  yesterday)
    report_date="$(date -u -v-1d +%F 2>/dev/null || date -u -d yesterday +%F)"
    ;;
esac

if [[ -z "${audit_root}" ]]; then
  audit_root="/scratch/csim/validate/install-gpu-smoke-audit-$(date -u +%Y%m%d-%H%M%S)"
fi
if [[ "${resume}" == "1" && -z "${audit_root}" ]]; then
  echo "ERROR: --resume-from-audit-root requires a path" >&2
  exit 2
fi
if [[ "${run_elbencho}" == "1" && -z "${elbencho_target_root}" ]]; then
  user_name="${USER:-$(id -un)}"
  elbencho_target_root="/scratch/${user_name}/elbencho/install-smoke-$(date -u +%Y%m%d-%H%M%S)"
fi

mkdir -p \
  "${audit_root}/logs" \
  "${audit_root}/dryruns" \
  "${audit_root}/preflight" \
  "${audit_root}/sbatch-test" \
  "${audit_root}/reports"

log_cmd() {
  local log_path="$1"
  shift
  {
    printf 'cwd=%s\n' "${PWD}"
    printf 'cmd='
    printf '%q ' "$@"
    printf '\n'
  } | tee "${log_path}"
  (set -o pipefail; "$@" 2>&1 | tee -a "${log_path}")
}

normalize_job_ids() {
  tr '[:space:]' ',' | tr -s ',' | sed 's/^,//; s/,$//' | awk -F',' '
    {
      for (i = 1; i <= NF; i++) {
        if ($i != "" && !seen[$i]++) {
          out = out ? out "," $i : $i
        }
      }
    }
    END { print out }
  '
}

extract_job_ids_from_log() {
  local log_path="$1"
  [[ -s "${log_path}" ]] || return 1
  sed -nE \
    -e 's/.* as job ([0-9]+).*/\1/p' \
    -e 's/^Submitted .* job ids: ([0-9, ]+).*/\1/p' \
    -e 's/^Submitted .* job ([0-9]+).*/\1/p' \
    -e 's/^job_id=([0-9]+).*/\1/p' \
    "${log_path}" | normalize_job_ids
}

slurm_jobs_completed() {
  local job_ids_csv="$1"
  local rows
  [[ -n "${job_ids_csv}" ]] || return 1
  rows="$(sacct -X -n -P -j "${job_ids_csv}" --format=JobID,State,ExitCode 2>/dev/null || true)"
  [[ -n "${rows}" ]] || return 1
  printf '%s\n' "${rows}" | awk -F'|' '
    NF >= 3 {
      seen = 1
      split($2, state, " ")
      if (state[1] != "COMPLETED" || $3 != "0:0") {
        bad = 1
      }
    }
    END {
      exit (seen && !bad) ? 0 : 1
    }
  '
}

run_logged() {
  local dir="$1"
  local name="$2"
  shift 2
  echo "== ${name} =="
  log_cmd "${audit_root}/${dir}/${name}.log" "$@"
}

first_node() {
  printf '%s\n' "$1" | tr ',' '\n' | sed '/^$/d' | head -n 1
}

first_two_nodes_csv() {
  printf '%s\n' "$1" | tr ',' '\n' | sed '/^$/d' | head -n 2 | paste -sd, -
}

node_count() {
  printf '%s\n' "$1" | tr ',' '\n' | sed '/^$/d' | wc -l | tr -d ' '
}

require_installed_tree() {
  [[ -f Makefile ]] || { echo "ERROR: run from an AICR-Bench tree" >&2; exit 2; }
  [[ -f benchmark-settings.env ]] || {
    echo "ERROR: benchmark-settings.env is required in the installed tree" >&2
    exit 2
  }
}

write_context() {
  {
    echo "date_utc=$(date -u +%FT%TZ)"
    echo "repo_root=${repo_root}"
    echo "audit_root=${audit_root}"
    echo "report_date=${report_date}"
    echo "mode=$([[ "${apply}" == "1" ]] && echo apply || echo dry-run)"
    echo "resume=$([[ "${resume}" == "1" ]] && echo enabled || echo disabled)"
    echo "rtx_nodes=${rtx_nodes}"
    echo "b200_nodes=${b200_nodes}"
    echo "topology=$([[ "${run_topology}" == "1" ]] && echo enabled || echo skipped)"
    echo "gds=$([[ "${run_gds}" == "1" ]] && echo enabled || echo skipped)"
    echo "nccl=$([[ "${run_nccl}" == "1" ]] && echo enabled || echo skipped)"
    echo "rdma=$([[ "${run_rdm}" == "1" ]] && echo enabled || echo skipped)"
    echo "hpl_mxp=$([[ "${run_hpl_mxp}" == "1" ]] && echo enabled || echo skipped)"
    echo "hpl_mxp_b200_node=${hpl_mxp_b200_node:-}"
    echo "hpl_mxp_rtx_node=${hpl_mxp_rtx_node:-}"
    echo "hpl_mxp_apply_rtx=${hpl_mxp_apply_rtx}"
    echo "hpl_mxp_time=${hpl_mxp_time}"
    echo "hpl_mxp_preset=${hpl_mxp_preset}"
    echo "hpl_mxp_sloppy_type=${hpl_mxp_sloppy_type}"
    echo "dataloader=$([[ "${run_dataloader}" == "1" ]] && echo enabled || echo skipped)"
    echo "dataloader_time=${dataloader_time}"
    echo "ddp=$([[ "${run_ddp}" == "1" ]] && echo enabled || echo skipped)"
    echo "ddp_time=${ddp_time}"
    echo "elbencho=$([[ "${run_elbencho}" == "1" ]] && echo enabled || echo skipped)"
    echo "elbencho_b200_node=${elbencho_b200_node:-}"
    echo "elbencho_rtx_node=${elbencho_rtx_node:-}"
    echo "elbencho_target_root=${elbencho_target_root:-}"
    echo "elbencho_time=${elbencho_time}"
    grep -E '^(AICR_RUNTIME_ROOT|AICR_APPTAINER_IMAGE_DIR|AICR_UV_ROOT|AICR_UV_ENVS_DIR|AICR_UV_ENV_PREFIX)=' benchmark-settings.env || true
  } | tee "${audit_root}/context.txt"
}

run_local_surface_checks() {
  run_logged logs bash-n bash -lc \
    'bash -n scripts/verify/run-gpu-topology.sh scripts/verify/run-gpu-topology-fleet.sh scripts/verify/run-gds.sh scripts/verify/run-gds-fleet.sh scripts/verify/submit-gds-fleet.sh scripts/verify/run-nccl-suite.sh scripts/verify/submit-nccl-suite.sh scripts/benchmark/run-hpl-mxp.sh scripts/benchmark/submit-hpl-mxp.sh scripts/benchmark/run-dataloader.sh scripts/benchmark/submit-dataloader.sh scripts/benchmark/sweep-dataloader.sh scripts/benchmark/run-ddp-resnet50.sh scripts/benchmark/submit-ddp-resnet50.sh scripts/operator/commands/render.sh slurm/verify/*gpu-topology*.sbatch slurm/verify/*gds*.sbatch slurm/verify/*nccl-suite*.sbatch slurm/benchmark/hpl-mxp-nvidia-sample-1n.sbatch slurm/benchmark/*dataloader*.sbatch slurm/benchmark/*ddp-resnet50*.sbatch docs/modules/gds/slurm-gds.sbatch docs/modules/nccl/slurm-nccl.sbatch docs/modules/hpl-mxp/slurm-hpl-mxp.sbatch docs/modules/dataloader/slurm-dataloader.sbatch'
  run_logged logs docs-link-check make docs-link-check
  run_logged logs docs-test-gpu-topology bash -lc 'make docs-test-plan-gpu-topology && make docs-test-gpu-topology'
  run_logged logs docs-test-gds bash -lc 'make docs-test-plan-gds && make docs-test-gds'
  run_logged logs docs-test-nccl bash -lc 'make docs-test-plan-nccl && make docs-test-nccl'
  run_logged logs docs-test-hpl-mxp bash -lc 'make docs-test-plan-hpl-mxp && make docs-test-hpl-mxp'
  run_logged logs docs-test-dataloader bash -lc 'make docs-test-plan-dataloader && make docs-test-dataloader'
  run_logged logs docs-test-ddp bash -lc 'make docs-test-plan-ddp && make docs-test-ddp'
  if [[ "${run_elbencho}" == "1" ]]; then
    run_logged logs elbencho-bash-n bash -lc \
      'bash -n scripts/benchmark/install-elbencho-runtime.sh scripts/benchmark/run-elbencho.sh scripts/benchmark/submit-elbencho.sh scripts/verify/smoke-test-elbencho.sh slurm/verify/*elbencho*.sbatch docs/modules/elbencho/slurm-elbencho.sbatch'
    run_logged logs docs-test-elbencho bash -lc 'make docs-test-plan-elbencho && make docs-test-elbencho'
  fi
  run_logged logs help-surfaces bash -lc \
    'bash scripts/verify/run-gpu-topology.sh --help
     bash scripts/verify/run-gpu-topology-fleet.sh --help
     bash scripts/verify/run-gds.sh --help
     bash scripts/verify/run-gds-fleet.sh --help
     bash scripts/verify/submit-gds-fleet.sh --help
     bash scripts/verify/run-nccl-suite.sh --help
     bash scripts/verify/submit-nccl-suite.sh --help
     bash scripts/benchmark/run-hpl-mxp.sh --help
     bash scripts/benchmark/submit-hpl-mxp.sh --help
     bash scripts/benchmark/run-dataloader.sh --help
     bash scripts/benchmark/submit-dataloader.sh --help
     bash scripts/benchmark/sweep-dataloader.sh --help
     bash scripts/benchmark/run-ddp-resnet50.sh --help
     bash scripts/benchmark/submit-ddp-resnet50.sh --help
     scripts/lib/run-repo-python.sh scripts/report/render-verify-dashboard.py --help
     scripts/lib/run-repo-python.sh scripts/report/render-nccl-suite-report.py --help
     scripts/lib/run-repo-python.sh scripts/report/render-hpl-mxp-report.py --help
     scripts/lib/run-repo-python.sh scripts/report/render-dataloader-report.py --help
     scripts/lib/run-repo-python.sh scripts/report/render-ddp-resnet50-report.py --help'
  if [[ "${run_elbencho}" == "1" ]]; then
    run_logged logs help-elbencho bash -lc \
      'bash scripts/benchmark/install-elbencho-runtime.sh --help
       bash scripts/benchmark/run-elbencho.sh --help
       bash scripts/benchmark/submit-elbencho.sh --help
       scripts/lib/run-repo-python.sh scripts/report/render-elbencho-report.py --help'
  fi
}

dry_run_cluster() {
  local cluster="$1"
  local nodes="$2"
  local one two hpl_node elbencho_node local_suite_class
  one="$(first_node "${nodes}")"
  two="$(first_two_nodes_csv "${nodes}")"

  if [[ "${run_topology}" == "1" ]]; then
    run_logged dryruns "make-verify-topology-${cluster}" make verify-topology CLUSTER="${cluster}" NODELIST="${one}" APPLY=0
  fi
  if [[ "${run_gds}" == "1" ]]; then
    run_logged dryruns "make-verify-gds-${cluster}-smoke" make verify-gds CLUSTER="${cluster}" PROFILE=smoke NODELIST="${one}" APPLY=0
  fi
  case "${cluster}" in
    rtxpro6000) local_suite_class="rtx_8rank_1g" ;;
    b200) local_suite_class="b200_8rank_1g" ;;
    *) echo "ERROR: unsupported cluster ${cluster}" >&2; exit 2 ;;
  esac
  if [[ "${run_nccl}" == "1" ]]; then
    run_logged dryruns "make-verify-nccl-local-${cluster}-smoke" make verify-nccl-suite NCCL_SCOPE=local CLUSTER="${cluster}" PROFILE=smoke NODELIST="${one}" NCCL_SUITE_CLASS="${local_suite_class}" NCCL_SUITE_OPS=allreduce APPLY=0
    if [[ "${run_rdm}" == "1" && "$(node_count "${two}")" -ge 2 ]]; then
      run_logged dryruns "make-verify-nccl-rdma-${cluster}-smoke" make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER="${cluster}" PROFILE=smoke NODELIST="${two}" NCCL_NODES_PER_JOB=2 NCCL_SUITE_OPS=allreduce APPLY=0
    fi
  fi
  if [[ "${run_hpl_mxp}" == "1" ]]; then
    case "${cluster}" in
      rtxpro6000) hpl_node="${hpl_mxp_rtx_node:-${one}}" ;;
      b200) hpl_node="${hpl_mxp_b200_node:-${one}}" ;;
      *) echo "ERROR: unsupported cluster ${cluster}" >&2; exit 2 ;;
    esac
    run_logged dryruns "make-hpl-mxp-${cluster}-smoke" make benchmark-hpl-mxp CLUSTER="${cluster}" NODES=1 NODELIST="${hpl_node}" HPL_MXP_PRESET="${hpl_mxp_preset}" HPL_MXP_TIME="${hpl_mxp_time}" HPL_MXP_MEM=0 HPL_MXP_TEST_LOOP=1 HPL_MXP_AFFINITY_PROFILE=derived-nps4 HPL_MXP_SLOPPY_TYPE="${hpl_mxp_sloppy_type}" NODE_REPORT_DATE="${report_date}" APPLY=0
  fi
  if [[ "${run_dataloader}" == "1" ]]; then
    run_logged dryruns "make-dataloader-${cluster}-smoke" make benchmark-dataloader CLUSTER="${cluster}" DATALOADER_NODES=1 GPU_COUNT=1 MODE=single NODELIST="${one}" DATALOADER_INPUT_BACKENDS=pytorch-cpu-dataloader DATALOADER_BATCH_SIZES=8 DATALOADER_NUM_WORKERS=1 DATALOADER_PREFETCH_FACTORS=2 DATALOADER_PIN_MEMORY=0 DATALOADER_PERSISTENT_WORKERS=0 DATALOADER_CPUS_PER_TASK=4 DATALOADER_TIME="${dataloader_time}" DATALOADER_MEM=0 DATALOADER_RUN_ARGS="--warmup-batches 1 --measured-batches 1 --byte-estimate-sample-count 0" NODE_REPORT_DATE="${report_date}" APPLY=0
  fi
  if [[ "${run_ddp}" == "1" ]]; then
    run_logged dryruns "make-ddp-${cluster}-smoke" make benchmark-ddp-resnet50 CLUSTER="${cluster}" NODES=1 NODELIST="${one}" LAUNCHER=torchrun DDP_TIME="${ddp_time}" DDP_MEM=0 DDP_RUN_ARGS="--input-backend synthetic-gpu --warmup-iters 1 --measured-iters 1 --batch-size 8 --num-workers 0 --persistent-workers 0 --pin-memory 0 --channels-last 0" NODE_REPORT_DATE="${report_date}" APPLY=0
  fi

  if [[ "${run_topology}" == "1" ]]; then
    run_logged dryruns "script-topology-${cluster}" bash scripts/verify/run-gpu-topology-fleet.sh --cluster "${cluster}" --nodes "${one}"
  fi
  if [[ "${run_gds}" == "1" ]]; then
    run_logged dryruns "script-gds-${cluster}-smoke" bash scripts/verify/run-gds-fleet.sh --cluster "${cluster}" --profile smoke --nodes "${one}"
  fi
  if [[ "${run_nccl}" == "1" ]]; then
    run_logged dryruns "script-nccl-local-${cluster}-smoke" bash scripts/verify/submit-nccl-suite.sh --scope local --cluster "${cluster}" --profile smoke --nodes "${one}" --suite-class "${local_suite_class}" --ops allreduce
    if [[ "${run_rdm}" == "1" && "$(node_count "${two}")" -ge 2 ]]; then
      run_logged dryruns "script-nccl-rdma-${cluster}-smoke" bash scripts/verify/submit-nccl-suite.sh --scope rdma --cluster "${cluster}" --profile smoke --nodes "${two}" --nodes-per-job 2 --ops allreduce
    fi
  fi
  if [[ "${run_hpl_mxp}" == "1" ]]; then
    run_logged dryruns "script-hpl-mxp-${cluster}-smoke" bash scripts/benchmark/submit-hpl-mxp.sh --cluster "${cluster}" --nodes 1 --nodelist "${hpl_node}" --preset "${hpl_mxp_preset}" --time "${hpl_mxp_time}" --mem 0 --test-loop 1 --affinity-profile derived-nps4 --sloppy-type "${hpl_mxp_sloppy_type}" --date "${report_date}"
  fi
  if [[ "${run_dataloader}" == "1" ]]; then
    run_logged dryruns "script-dataloader-${cluster}-smoke" bash scripts/benchmark/submit-dataloader.sh --cluster "${cluster}" --nodes 1 --gpu-count 1 --mode single --nodelist "${one}" --time "${dataloader_time}" --cpus-per-task 4 --mem 0 --date "${report_date}" -- --input-backend pytorch-cpu-dataloader --batch-size 8 --num-workers 1 --prefetch-factor 2 --pin-memory 0 --persistent-workers 0 --warmup-batches 1 --measured-batches 1 --byte-estimate-sample-count 0
  fi
  if [[ "${run_ddp}" == "1" ]]; then
    run_logged dryruns "script-ddp-${cluster}-smoke" bash scripts/benchmark/submit-ddp-resnet50.sh --cluster "${cluster}" --nodes 1 --launcher torchrun --nodelist "${one}" --time "${ddp_time}" --mem 0 --date "${report_date}" -- --input-backend synthetic-gpu --warmup-iters 1 --measured-iters 1 --batch-size 8 --num-workers 0 --persistent-workers 0 --pin-memory 0 --channels-last 0
  fi
  if [[ "${run_elbencho}" == "1" ]]; then
    case "${cluster}" in
      rtxpro6000) elbencho_node="${elbencho_rtx_node:-${one}}" ;;
      b200) elbencho_node="${elbencho_b200_node:-${one}}" ;;
      *) echo "ERROR: unsupported cluster ${cluster}" >&2; exit 2 ;;
    esac
    run_logged dryruns "make-elbencho-${cluster}-smoke" env ELBENCHO_TARGET_ROOT="${elbencho_target_root}" make benchmark-elbencho CLUSTER="${cluster}" WORKLOAD=small-block NODES=1 NODELIST="${elbencho_node}" ELBENCHO_PROFILE=smoke ELBENCHO_CPUS_PER_TASK=8 ELBENCHO_MEM=0 ELBENCHO_TIME="${elbencho_time}" APPLY=0
    run_logged dryruns "script-elbencho-${cluster}-smoke" env ELBENCHO_TARGET_ROOT="${elbencho_target_root}" bash scripts/benchmark/submit-elbencho.sh --cluster "${cluster}" --workload small-block --profile smoke --nodes 1 --nodelist "${elbencho_node}" --cpus-per-task 8 --mem 0 --time "${elbencho_time}"
  fi
}

sbatch_test_cluster() {
  local cluster="$1"
  local nodes="$2"
  local one two prefix hpl_node local_suite_class
  one="$(first_node "${nodes}")"
  two="$(first_two_nodes_csv "${nodes}")"
  case "${cluster}" in
    rtxpro6000) prefix="rtxpro6000" ;;
    b200) prefix="b200" ;;
    *) echo "ERROR: unsupported cluster ${cluster}" >&2; exit 2 ;;
  esac

  if [[ "${run_topology}" == "1" ]]; then
    run_logged sbatch-test "${cluster}-gpu-topology" sbatch --test-only --nodelist="${one}" "slurm/verify/${prefix}-gpu-topology-1n-8g.sbatch"
  fi
  if [[ "${run_gds}" == "1" ]]; then
    run_logged sbatch-test "${cluster}-gds" sbatch --test-only --nodelist="${one}" "slurm/verify/${prefix}-gds-1n-8g.sbatch"
  fi
  case "${cluster}" in
    rtxpro6000) local_suite_class="rtx_8rank_1g" ;;
    b200) local_suite_class="b200_8rank_1g" ;;
    *) echo "ERROR: unsupported cluster ${cluster}" >&2; exit 2 ;;
  esac
  if [[ "${run_nccl}" == "1" ]]; then
    run_logged sbatch-test "${cluster}-nccl-local" sbatch --test-only --nodelist="${one}" "slurm/verify/${prefix}-nccl-suite-local-1n-8g.sbatch" --profile smoke --suite-class "${local_suite_class}" --ops allreduce
    if [[ "${run_rdm}" == "1" && "$(node_count "${two}")" -ge 2 ]]; then
      run_logged sbatch-test "${cluster}-nccl-rdma" sbatch --test-only --nodelist="${two}" "slurm/verify/${prefix}-nccl-suite-rdma.sbatch" --profile smoke --nodes-per-job 2 --ops allreduce
    fi
  fi
  if [[ "${run_hpl_mxp}" == "1" ]]; then
    case "${cluster}" in
      rtxpro6000)
        hpl_node="${hpl_mxp_rtx_node:-${one}}"
        run_logged sbatch-test "${cluster}-hpl-mxp" sbatch --test-only --partition=rtx-batch --nodelist="${hpl_node}" --nodes=1 --gres=gpu:rtx_pro_6000:8 --mem=0 "slurm/benchmark/hpl-mxp-nvidia-sample-1n.sbatch"
        ;;
      b200)
        hpl_node="${hpl_mxp_b200_node:-${one}}"
        run_logged sbatch-test "${cluster}-hpl-mxp" sbatch --test-only --partition=b200-batch --nodelist="${hpl_node}" --nodes=1 --gres=gpu:b200:8 --mem=0 "slurm/benchmark/hpl-mxp-nvidia-sample-1n.sbatch"
      ;;
    esac
  fi
  if [[ "${run_dataloader}" == "1" ]]; then
    run_logged sbatch-test "${cluster}-dataloader" sbatch --test-only --nodelist="${one}" "slurm/benchmark/${prefix}-dataloader-1n-1g.sbatch" --cluster "${cluster}" --mode single --nodes 1 --requested-gpu-count 1 --input-backend pytorch-cpu-dataloader --batch-size 8 --num-workers 1 --prefetch-factor 2 --pin-memory 0 --persistent-workers 0 --warmup-batches 1 --measured-batches 1 --byte-estimate-sample-count 0
  fi
  if [[ "${run_ddp}" == "1" ]]; then
    run_logged sbatch-test "${cluster}-ddp" sbatch --test-only --nodelist="${one}" --time="${ddp_time}" "slurm/benchmark/${prefix}-ddp-resnet50-torchrun.sbatch" --input-backend synthetic-gpu --warmup-iters 1 --measured-iters 1 --batch-size 8 --num-workers 0 --persistent-workers 0 --pin-memory 0 --channels-last 0
  fi
  if [[ "${run_elbencho}" == "1" ]]; then
    case "${cluster}" in
      rtxpro6000) run_logged sbatch-test "${cluster}-elbencho-smoke" sbatch --test-only --nodelist="${elbencho_rtx_node:-${one}}" "slurm/verify/${prefix}-elbencho-smoke.sbatch" ;;
      b200) run_logged sbatch-test "${cluster}-elbencho-smoke" sbatch --test-only --nodelist="${elbencho_b200_node:-${one}}" "slurm/verify/${prefix}-elbencho-smoke.sbatch" ;;
    esac
  fi
}

submit_gpu_probe() {
  local name="$1"
  local partition="$2"
  local node="$3"
  local gres="$4"
  local log_path="${audit_root}/preflight/${name}.log"
  local job_id gpu_count

  echo "== ${name} =="
  if [[ "${resume}" == "1" && -s "${log_path}" ]]; then
    job_id="$(sed -n 's/^job_id=//p' "${log_path}" | tail -n 1)"
    gpu_count="$(sed -n 's/^gpu_count=//p' "${log_path}" | tail -n 1)"
    if [[ -n "${job_id}" && "${gpu_count}" == "8" ]] && slurm_jobs_completed "${job_id}"; then
      echo "Resuming ${name}; existing GPU probe ${job_id} already passed." | tee -a "${log_path}"
      return 0
    fi
  fi
  {
    echo "partition=${partition}"
    echo "node=${node}"
    echo "gres=${gres}"
  } | tee "${log_path}"

  job_id="$(sbatch --parsable --wait \
    --partition="${partition}" \
    --nodelist="${node}" \
    --nodes=1 \
    --ntasks=1 \
    --gres="${gres}" \
    --mem=0 \
    --time=00:05:00 \
    --output="${audit_root}/preflight/${name}-%j.out" \
    --error="${audit_root}/preflight/${name}-%j.err" \
    --wrap 'hostname; nvidia-smi -L')"

  echo "job_id=${job_id}" | tee -a "${log_path}"
  sacct -j "${job_id}" --format=JobID,JobName,Partition,State,ExitCode,Elapsed,NodeList -P | tee -a "${log_path}"
  cat "${audit_root}/preflight/${name}-${job_id}.out" | tee -a "${log_path}"
  if [[ -s "${audit_root}/preflight/${name}-${job_id}.err" ]]; then
    cat "${audit_root}/preflight/${name}-${job_id}.err" | tee -a "${log_path}"
  fi
  gpu_count="$(grep -c '^GPU ' "${audit_root}/preflight/${name}-${job_id}.out" || true)"
  echo "gpu_count=${gpu_count}" | tee -a "${log_path}"
  [[ "${gpu_count}" == "8" ]] || {
    echo "ERROR: expected 8 visible GPUs for ${name}, found ${gpu_count}" >&2
    exit 1
  }
}

wait_for_slurm_jobs() {
  local name="$1"
  local job_ids_csv="$2"
  local log_path="${audit_root}/logs/wait-${name}.log"
  local deadline=$((SECONDS + 1800))
  local queue_rows

  echo "== wait-${name} =="
  echo "job_ids=${job_ids_csv}" | tee "${log_path}"
  if slurm_jobs_completed "${job_ids_csv}"; then
    sacct -j "${job_ids_csv}" --format=JobID,JobName,Partition,State,ExitCode,Elapsed,NodeList -P | tee -a "${log_path}"
    return 0
  fi

  while true; do
    queue_rows="$(squeue -h -j "${job_ids_csv}" -o '%i|%T|%M|%N|%R' || true)"
    if [[ -z "${queue_rows}" ]]; then
      break
    fi
    printf '%s\n' "${queue_rows}" | tee -a "${log_path}"
    if (( SECONDS > deadline )); then
      echo "ERROR: timed out waiting for ${name}: ${job_ids_csv}" | tee -a "${log_path}" >&2
      exit 1
    fi
    sleep 15
  done

  sacct -j "${job_ids_csv}" --format=JobID,JobName,Partition,State,ExitCode,Elapsed,NodeList -P | tee -a "${log_path}"
  if sacct -X -n -j "${job_ids_csv}" --format=State,ExitCode -P | awk -F'|' 'NF { split($1, state, " "); if (state[1] != "COMPLETED" || $2 != "0:0") bad=1 } END { exit bad ? 0 : 1 }'; then
    echo "ERROR: one or more ${name} jobs did not complete cleanly" | tee -a "${log_path}" >&2
    exit 1
  fi
}

resume_or_wait_recorded_phase() {
  local name="$1"
  local job_file="$2"
  local log_path="$3"
  local job_ids=""

  if [[ -s "${job_file}" ]]; then
    job_ids="$(cat "${job_file}" | normalize_job_ids)"
  elif [[ "${resume}" == "1" && -s "${log_path}" ]]; then
    job_ids="$(extract_job_ids_from_log "${log_path}" || true)"
    if [[ -n "${job_ids}" ]]; then
      printf '%s\n' "${job_ids}" >"${job_file}"
    fi
  fi

  [[ -n "${job_ids}" ]] || return 1
  echo "Resuming ${name} with recorded job ids: ${job_ids}" | tee -a "${log_path}"
  wait_for_slurm_jobs "${name}" "${job_ids}"
  return 0
}

run_apply_job_phase() {
  local name="$1"
  local job_file="$2"
  shift 2
  local log_path="${audit_root}/logs/${name}.log"
  local job_ids

  if [[ "${resume}" == "1" ]] && resume_or_wait_recorded_phase "${name}" "${job_file}" "${log_path}"; then
    return 0
  fi

  run_logged logs "${name}" "$@"
  job_ids="$(extract_job_ids_from_log "${log_path}" || true)"
  if [[ -z "${job_ids}" ]]; then
    echo "ERROR: could not parse job ids from ${log_path}" >&2
    exit 1
  fi
  printf '%s\n' "${job_ids}" >"${job_file}"
  wait_for_slurm_jobs "${name}" "${job_ids}"
}

preflight_cluster() {
  local cluster="$1"
  local nodes="$2"
  local one two partition gres
  one="$(first_node "${nodes}")"
  two="$(first_two_nodes_csv "${nodes}")"
  case "${cluster}" in
    rtxpro6000)
      partition="rtx-batch"
      gres="gpu:rtx_pro_6000:8"
      ;;
    b200)
      partition="b200-batch"
      gres="gpu:b200:8"
      ;;
    *) echo "ERROR: unsupported cluster ${cluster}" >&2; exit 2 ;;
  esac

  for node in $(printf '%s\n' "${two}" | tr ',' ' '); do
    scontrol show node "${node}" >"${audit_root}/preflight/${cluster}-${node}-scontrol.txt"
    submit_gpu_probe "nvidia-${cluster}-${node}" "${partition}" "${node}" "${gres}"
  done
}

apply_cluster() {
  local cluster="$1"
  local nodes="$2"
  local one two local_suite_class
  one="$(first_node "${nodes}")"
  two="$(first_two_nodes_csv "${nodes}")"
  case "${cluster}" in
    rtxpro6000) local_suite_class="rtx_8rank_1g" ;;
    b200) local_suite_class="b200_8rank_1g" ;;
    *) echo "ERROR: unsupported cluster ${cluster}" >&2; exit 2 ;;
  esac

  if [[ "${run_topology}" == "1" ]]; then
    run_apply_job_phase "apply-topology-${cluster}" "${audit_root}/logs/topology-${cluster}-job-ids.txt" \
      make verify-topology CLUSTER="${cluster}" NODELIST="${one}" APPLY=1
  fi
  if [[ "${run_gds}" == "1" ]]; then
    run_apply_job_phase "apply-gds-${cluster}-smoke" "${audit_root}/logs/gds-${cluster}-job-ids.txt" \
      make verify-gds CLUSTER="${cluster}" PROFILE=smoke NODELIST="${one}" APPLY=1
  fi
  if [[ "${run_nccl}" == "1" ]]; then
    run_apply_job_phase "apply-nccl-local-${cluster}-smoke" "${audit_root}/logs/nccl-local-${cluster}-job-ids.txt" \
      make verify-nccl-suite NCCL_SCOPE=local CLUSTER="${cluster}" PROFILE=smoke NODELIST="${one}" NCCL_SUITE_CLASS="${local_suite_class}" NCCL_SUITE_OPS=allreduce APPLY=1
    if [[ "${run_rdm}" == "1" && "$(node_count "${two}")" -ge 2 ]]; then
      run_apply_job_phase "apply-nccl-rdma-${cluster}-smoke" "${audit_root}/logs/nccl-rdma-${cluster}-job-ids.txt" \
        make verify-nccl-suite NCCL_SCOPE=rdma CLUSTER="${cluster}" PROFILE=smoke NODELIST="${two}" NCCL_NODES_PER_JOB=2 NCCL_SUITE_OPS=allreduce APPLY=1
    fi
  fi
}

apply_hpl_mxp_cluster() {
  local cluster="$1"
  local nodes="$2"
  local one hpl_node log_name
  one="$(first_node "${nodes}")"

  [[ "${run_hpl_mxp}" == "1" ]] || return 0
  if [[ "${cluster}" == "rtxpro6000" && "${hpl_mxp_apply_rtx}" != "1" ]]; then
    echo "Skipped RTX HPL-MxP apply; pass --hpl-mxp-apply-rtx to enable it." \
      | tee "${audit_root}/logs/apply-hpl-mxp-${cluster}-skipped.log"
    return 0
  fi

  case "${cluster}" in
    rtxpro6000) hpl_node="${hpl_mxp_rtx_node:-${one}}" ;;
    b200) hpl_node="${hpl_mxp_b200_node:-${one}}" ;;
    *) echo "ERROR: unsupported cluster ${cluster}" >&2; exit 2 ;;
  esac

  log_name="apply-hpl-mxp-${cluster}-smoke"
  run_apply_job_phase "${log_name}" "${audit_root}/logs/hpl-mxp-${cluster}-job-ids.txt" \
    make benchmark-hpl-mxp CLUSTER="${cluster}" NODES=1 NODELIST="${hpl_node}" HPL_MXP_PRESET="${hpl_mxp_preset}" HPL_MXP_TIME="${hpl_mxp_time}" HPL_MXP_MEM=0 HPL_MXP_TEST_LOOP=1 HPL_MXP_AFFINITY_PROFILE=derived-nps4 HPL_MXP_SLOPPY_TYPE="${hpl_mxp_sloppy_type}" NODE_REPORT_DATE="${report_date}" APPLY=1
}

apply_dataloader_cluster() {
  local cluster="$1"
  local nodes="$2"
  local one log_name
  one="$(first_node "${nodes}")"

  [[ "${run_dataloader}" == "1" ]] || return 0

  log_name="apply-dataloader-${cluster}-smoke"
  run_apply_job_phase "${log_name}" "${audit_root}/logs/dataloader-${cluster}-job-ids.txt" \
    make benchmark-dataloader CLUSTER="${cluster}" DATALOADER_NODES=1 GPU_COUNT=1 MODE=single NODELIST="${one}" DATALOADER_INPUT_BACKENDS=pytorch-cpu-dataloader DATALOADER_BATCH_SIZES=8 DATALOADER_NUM_WORKERS=1 DATALOADER_PREFETCH_FACTORS=2 DATALOADER_PIN_MEMORY=0 DATALOADER_PERSISTENT_WORKERS=0 DATALOADER_CPUS_PER_TASK=4 DATALOADER_TIME="${dataloader_time}" DATALOADER_MEM=0 DATALOADER_RUN_ARGS="--warmup-batches 1 --measured-batches 1 --byte-estimate-sample-count 0" NODE_REPORT_DATE="${report_date}" APPLY=1
}

apply_ddp_cluster() {
  local cluster="$1"
  local nodes="$2"
  local one log_name
  one="$(first_node "${nodes}")"

  [[ "${run_ddp}" == "1" ]] || return 0

  log_name="apply-ddp-${cluster}-smoke"
  run_apply_job_phase "${log_name}" "${audit_root}/logs/ddp-${cluster}-job-ids.txt" \
    make benchmark-ddp-resnet50 CLUSTER="${cluster}" NODES=1 NODELIST="${one}" LAUNCHER=torchrun DDP_TIME="${ddp_time}" DDP_MEM=0 DDP_RUN_ARGS="--input-backend synthetic-gpu --warmup-iters 1 --measured-iters 1 --batch-size 8 --num-workers 0 --persistent-workers 0 --pin-memory 0 --channels-last 0" NODE_REPORT_DATE="${report_date}" APPLY=1
}

apply_elbencho_cluster() {
  local cluster="$1"
  local nodes="$2"
  local one elbencho_node log_name
  one="$(first_node "${nodes}")"

  [[ "${run_elbencho}" == "1" ]] || return 0
  case "${cluster}" in
    rtxpro6000) elbencho_node="${elbencho_rtx_node:-${one}}" ;;
    b200) elbencho_node="${elbencho_b200_node:-${one}}" ;;
    *) echo "ERROR: unsupported cluster ${cluster}" >&2; exit 2 ;;
  esac

  log_name="apply-elbencho-${cluster}-smoke"
  run_apply_job_phase "${log_name}" "${audit_root}/logs/elbencho-${cluster}-job-ids.txt" \
    env AICR_ELBENCHO_B200_APPLY_ALLOW=1 ELBENCHO_TARGET_ROOT="${elbencho_target_root}" make benchmark-elbencho CLUSTER="${cluster}" WORKLOAD=small-block NODES=1 NODELIST="${elbencho_node}" ELBENCHO_PROFILE=smoke ELBENCHO_CPUS_PER_TASK=8 ELBENCHO_MEM=0 ELBENCHO_TIME="${elbencho_time}" NODE_REPORT_DATE="${report_date}" APPLY=1
}

render_cluster() {
  local cluster="$1"
  local hpl_job_ids elbencho_job_ids nccl_local_output nccl_rdma_output
  if [[ "${run_topology}" == "1" ]]; then
    run_logged reports "render-topology-${cluster}" scripts/lib/run-repo-python.sh scripts/report/render-verify-dashboard.py --results-root results --date "${report_date}" --cluster "${cluster}" --check gpu-topology --both --write
  fi
  if [[ "${run_gds}" == "1" ]]; then
    run_logged reports "render-gds-${cluster}" scripts/lib/run-repo-python.sh scripts/report/render-verify-dashboard.py --results-root results --date "${report_date}" --cluster "${cluster}" --check gds --both --write
  fi
  if [[ "${run_nccl}" == "1" ]]; then
    nccl_local_output="results/reports/${report_date}/nccl-suite-local-${cluster}.md"
    run_logged reports "render-nccl-local-${cluster}" scripts/lib/run-repo-python.sh scripts/report/render-nccl-suite-report.py --date "${report_date}" --cluster "${cluster}" --scope local --results-root results --output "${nccl_local_output}"
    if [[ "${run_rdm}" == "1" ]]; then
      nccl_rdma_output="results/reports/${report_date}/nccl-suite-rdma-${cluster}-2n.md"
      run_logged reports "render-nccl-rdma-${cluster}" scripts/lib/run-repo-python.sh scripts/report/render-nccl-suite-report.py --date "${report_date}" --cluster "${cluster}" --scope rdma --nodes-per-job 2 --results-root results --output "${nccl_rdma_output}"
    fi
  fi
  if [[ -s "${audit_root}/logs/hpl-mxp-${cluster}-job-ids.txt" ]]; then
    hpl_job_ids="$(cat "${audit_root}/logs/hpl-mxp-${cluster}-job-ids.txt")"
    run_logged reports "render-hpl-mxp-${cluster}" make render-hpl-mxp CLUSTER="${cluster}" DATE="${report_date}" REPEAT_AGGREGATION=standard HPL_MXP_RENDER_JOB_ID_LIST="${hpl_job_ids}"
  fi
  if [[ "${run_dataloader}" == "1" ]]; then
    run_logged reports "render-dataloader-${cluster}" make render-dataloader CLUSTER="${cluster}" DATE="${report_date}" DATALOADER_REPEAT_AGGREGATION=standard
  fi
  if [[ "${run_ddp}" == "1" ]]; then
    run_logged reports "render-ddp-${cluster}" make render-ddp-resnet50 CLUSTER="${cluster}" DATE="${report_date}"
  fi
  if [[ -s "${audit_root}/logs/elbencho-${cluster}-job-ids.txt" ]]; then
    elbencho_job_ids="$(cat "${audit_root}/logs/elbencho-${cluster}-job-ids.txt")"
    run_logged reports "render-elbencho-${cluster}" scripts/lib/run-repo-python.sh scripts/report/render-elbencho-report.py --date "${report_date}" --cluster "${cluster}" --both --write
    printf '%s\n' "${elbencho_job_ids}" >"${audit_root}/reports/elbencho-${cluster}-job-ids.txt"
  fi
}

write_summary() {
  {
    echo "# Install GPU Smoke Suite"
    echo
    echo "- Date UTC: $(date -u +%FT%TZ)"
    echo "- Installed tree: ${repo_root}"
    echo "- Audit root: ${audit_root}"
    echo "- Mode: $([[ "${apply}" == "1" ]] && echo apply || echo dry-run)"
    echo "- Resume: $([[ "${resume}" == "1" ]] && echo enabled || echo disabled)"
    echo "- Dry-runs: $([[ "${run_dryruns}" == "1" ]] && echo enabled || echo skipped)"
    echo "- RTX nodes: ${rtx_nodes:-skipped}"
    echo "- B200 nodes: ${b200_nodes:-skipped}"
    echo "- GPU Topology: $([[ "${run_topology}" == "1" ]] && echo enabled || echo skipped)"
    echo "- GDS: $([[ "${run_gds}" == "1" ]] && echo enabled || echo skipped)"
    echo "- NCCL: $([[ "${run_nccl}" == "1" ]] && echo enabled || echo skipped)"
    echo "- RDMA: $([[ "${run_rdm}" == "1" ]] && echo enabled || echo skipped)"
    echo "- HPL-MxP: $([[ "${run_hpl_mxp}" == "1" ]] && echo enabled || echo skipped)"
    echo "- HPL-MxP B200 node: ${hpl_mxp_b200_node:-skipped}"
    echo "- HPL-MxP RTX node: ${hpl_mxp_rtx_node:-skipped}"
    echo "- HPL-MxP RTX apply: $([[ "${hpl_mxp_apply_rtx}" == "1" ]] && echo enabled || echo skipped)"
    echo "- HPL-MxP preset: ${hpl_mxp_preset}"
    echo "- HPL-MxP sloppy type: ${hpl_mxp_sloppy_type}"
    echo "- HPL-MxP time: ${hpl_mxp_time}"
    echo "- DataLoader: $([[ "${run_dataloader}" == "1" ]] && echo enabled || echo skipped)"
    echo "- DataLoader time: ${dataloader_time}"
    echo "- DDP: $([[ "${run_ddp}" == "1" ]] && echo enabled || echo skipped)"
    echo "- DDP time: ${ddp_time}"
    echo "- Elbencho: $([[ "${run_elbencho}" == "1" ]] && echo enabled || echo skipped)"
    echo "- Elbencho B200 node: ${elbencho_b200_node:-skipped}"
    echo "- Elbencho RTX node: ${elbencho_rtx_node:-skipped}"
    echo "- Elbencho target root: ${elbencho_target_root:-skipped}"
    echo "- Elbencho time: ${elbencho_time}"
    echo
    echo "## Evidence"
    echo
    echo "- Context: context.txt"
    echo "- Local checks: logs/"
    echo "- Dry-runs: dryruns/"
    echo "- Explicit Slurm template tests: sbatch-test/"
    echo "- GPU probes: preflight/"
    echo "- Renders: reports/"
    echo
    echo "## Recorded Jobs"
    echo
    shopt -s nullglob
    local job_file
    local found_jobs=0
    for job_file in "${audit_root}"/logs/*job-ids.txt; do
      found_jobs=1
      echo "- $(basename "${job_file}" .txt): $(cat "${job_file}")"
    done
    shopt -u nullglob
    if [[ "${found_jobs}" == "0" ]]; then
      echo "- none recorded"
    fi
    echo
    echo "## Intentional Gaps"
    echo
    echo "- RTX HPL-MxP apply is skipped unless --hpl-mxp-apply-rtx is set."
    echo "- Elbencho apply is skipped unless --include-elbencho is set."
    echo "- Broad campaigns, full NCCL operation matrices, HPL-MxP FP4/FP8 rows,"
    echo "  and multi-node DataLoader/DDP scaling are outside install-smoke scope."
  } >"${audit_root}/SUMMARY.md"
  echo "Wrote ${audit_root}/SUMMARY.md"
}

require_installed_tree
write_context

if [[ "${render_only}" == "1" ]]; then
  if [[ "${run_rtx}" == "1" ]]; then
    render_cluster rtxpro6000
  fi
  if [[ "${run_b200}" == "1" ]]; then
    render_cluster b200
  fi
  write_summary
  exit 0
fi

if [[ "${run_local_checks}" == "1" ]]; then
  run_local_surface_checks
fi

if [[ "${run_dryruns}" == "1" ]]; then
  if [[ "${run_rtx}" == "1" ]]; then
    dry_run_cluster rtxpro6000 "${rtx_nodes}"
  fi
  if [[ "${run_b200}" == "1" ]]; then
    dry_run_cluster b200 "${b200_nodes}"
  fi
  grep -R -L -- '--mem=0' "${audit_root}/dryruns"/*.log >"${audit_root}/dryruns-without-mem0.txt" || true
else
  echo "Skipped dry-runs." >"${audit_root}/dryruns/skipped.txt"
fi

if [[ "${run_explicit_sbatch}" == "1" ]]; then
  if [[ "${run_rtx}" == "1" ]]; then
    sbatch_test_cluster rtxpro6000 "${rtx_nodes}"
  fi
  if [[ "${run_b200}" == "1" ]]; then
    sbatch_test_cluster b200 "${b200_nodes}"
  fi
fi

if [[ "${apply}" == "1" ]]; then
  if [[ "${run_rtx}" == "1" ]]; then
    preflight_cluster rtxpro6000 "${rtx_nodes}"
    apply_cluster rtxpro6000 "${rtx_nodes}"
    apply_hpl_mxp_cluster rtxpro6000 "${rtx_nodes}"
    apply_dataloader_cluster rtxpro6000 "${rtx_nodes}"
    apply_ddp_cluster rtxpro6000 "${rtx_nodes}"
    apply_elbencho_cluster rtxpro6000 "${rtx_nodes}"
    [[ "${run_render}" == "1" ]] && render_cluster rtxpro6000
  fi
  if [[ "${run_b200}" == "1" ]]; then
    preflight_cluster b200 "${b200_nodes}"
    apply_cluster b200 "${b200_nodes}"
    apply_hpl_mxp_cluster b200 "${b200_nodes}"
    apply_dataloader_cluster b200 "${b200_nodes}"
    apply_ddp_cluster b200 "${b200_nodes}"
    apply_elbencho_cluster b200 "${b200_nodes}"
    [[ "${run_render}" == "1" ]] && render_cluster b200
  fi
fi

write_summary
