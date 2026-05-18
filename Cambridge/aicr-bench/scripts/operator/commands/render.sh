#!/usr/bin/env bash
set -euo pipefail

aicr_operator_render_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr render gds --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both] [--no-stats]
  scripts/operator/aicr render gpu-topology --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both]
  scripts/operator/aicr render nccl-suite --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both] [--write]
  scripts/operator/aicr render elbencho --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both] [--write]
  scripts/operator/aicr render nccl-local --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both] [--no-stats]
  scripts/operator/aicr render nccl-rdma --date <YYYY-MM-DD|today|yesterday> --cluster b200 [--nodes-per-job <2|4|8|16>] [--ascii|--markdown|--both] [--no-stats]
  scripts/operator/aicr render campaign --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--campaign-type verification] [--ascii|--markdown|--both] [--write]
  scripts/operator/aicr render nodes --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both] [--write]

Defaults:
  When no output mode is specified, render ASCII for terminal use.

Notes:
  The render command selects the newest matching fleet manifest under results/reports/<date>/<check>/.
  For NCCL suite, render uses the system verification rank-per-GPU scale manifest.
  Elbencho renders Benchmark 0 storage benchmark summaries and does not read GDS readiness artifacts.
  For NCCL RDMA, omitting --nodes-per-job selects the base 2-node manifest.
  The campaign render command summarizes committed dashboards/manifests and can write campaign Markdown/JSON.
  The nodes render command summarizes committed per-node evidence and can write by-node Markdown/JSON.
  The today and yesterday aliases resolve in UTC to match report directory dates.
  It does not submit jobs.
EOF
}

aicr_operator_render_gds_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr render gds --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both] [--no-stats]

Selects the newest results/reports/<date>/gds/*-gds-<cluster>.json manifest and renders profile/phase-aware GDS rows.
Date aliases today and yesterday resolve in UTC.
Default output mode: --ascii.
EOF
}

aicr_operator_render_gpu_topology_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr render gpu-topology --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both]

Selects the newest results/reports/<date>/gpu-topology/*-gpu-topology-<cluster>.json manifest.
Date aliases today and yesterday resolve in UTC.
Default output mode: --ascii.
EOF
}

aicr_operator_render_nccl_local_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr render nccl-local --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both] [--no-stats]

Selects the newest results/reports/<date>/nccl-local/*-nccl-local-<cluster>.json manifest.
Date aliases today and yesterday resolve in UTC.
Default output mode: --ascii.
Statistics and anomaly sections are shown by default; use --no-stats for the compact table.
EOF
}

aicr_operator_render_nccl_suite_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr render nccl-suite --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both] [--write]

Selects the newest results/reports/<date>/nccl-suite/*-nccl-suite-<cluster>.json manifest.
Date aliases today and yesterday resolve in UTC.
Default output mode: --ascii, printed as Markdown for terminal review.
When --write is used, writes results/reports/<date>/nccl-suite-<cluster>.md plus per-scale drilldown pages.
EOF
}

aicr_operator_render_elbencho_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr render elbencho --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both] [--write]

Renders Benchmark 0 elbencho storage benchmark summaries.
Date aliases today and yesterday resolve in UTC.
Default output mode: --ascii.
When --write is used, writes results/reports/<date>/elbencho-<cluster>.md.
EOF
}

aicr_operator_render_campaign_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr render campaign --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--campaign-type verification] [--ascii|--markdown|--both] [--write]

Summarizes committed per-check dashboards, fleet manifests, and the archive checksum manifest.
Default output mode: --ascii.
When --write is used with --markdown or --both, writes campaign Markdown and JSON under results/reports/<date>/.
EOF
}

aicr_operator_render_nodes_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr render nodes --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> [--ascii|--markdown|--both] [--write]

Summarizes committed per-node evidence from child dashboards and the campaign summary.
Default output mode: --ascii.
When --write is used with --markdown or --both, writes by-node Markdown and JSON under results/reports/<date>/.
EOF
}

aicr_operator_render_nccl_rdma_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr render nccl-rdma --date <YYYY-MM-DD|today|yesterday> --cluster b200 [--nodes-per-job <2|4|8|16>] [--ascii|--markdown|--both] [--no-stats]

Selects the newest matching results/reports/<date>/nccl-rdma/*-nccl-rdma-b200*.json manifest.
When --nodes-per-job is omitted, selects the base 2-node manifest to match the launcher default.
When --nodes-per-job is provided, selects the newest manifest for that scaled job size.
Date aliases today and yesterday resolve in UTC.
Default output mode: --ascii.
Statistics and anomaly sections are shown by default; use --no-stats for the compact table.
EOF
}

aicr_operator_render_set_mode() {
  local next_mode="$1"
  if [[ -n "${mode:-}" ]]; then
    aicr_operator_usage_error "choose only one output mode: --ascii, --markdown, or --both"
  fi
  mode="$next_mode"
}

aicr_operator_latest_manifest() {
  local check="$1"
  local date_value="$2"
  local cluster="$3"
  local nodes_per_job="${4:-}"
  local manifest_dir="${AICR_BMARK_DIR}/results/reports/${date_value}/${check}"
  local patterns=()
  local pattern
  local matches=()
  local latest

  if [[ ! -d "$manifest_dir" ]]; then
    aicr_operator_die "no ${check} fleet manifest directory for date=${date_value} cluster=${cluster}: $(aicr_operator_relpath "$manifest_dir")"
  fi

  if [[ "$check" == "nccl-rdma" ]]; then
    if [[ -n "$nodes_per_job" ]]; then
      patterns=("*-${check}-${cluster}-${nodes_per_job}n.json")
      if [[ "$nodes_per_job" == "2" ]]; then
        patterns+=("*-${check}-${cluster}.json")
      fi
    else
      patterns=("*-${check}-${cluster}.json")
    fi
  else
    patterns=("*-${check}-${cluster}.json")
  fi

  shopt -s nullglob
  for pattern in "${patterns[@]}"; do
    # shellcheck disable=SC2206
    matches+=("${manifest_dir}"/$pattern)
  done
  shopt -u nullglob

  if [[ "${#matches[@]}" -eq 0 ]]; then
    aicr_operator_die "no ${check} fleet manifest found for date=${date_value} cluster=${cluster} under $(aicr_operator_relpath "$manifest_dir")"
  fi

  latest="$(printf '%s\n' "${matches[@]}" | sort | tail -n 1)"
  printf '%s\n' "$latest"
}

aicr_operator_render_check() {
  local check="$1"
  shift

  local date_value=""
  local cluster=""
  local mode=""
  local no_stats=0
  local nodes_per_job=""
  local renderer="${AICR_BMARK_DIR}/scripts/report/render-verify-dashboard.py"
  local manifest
  local mode_arg

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --date)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--date requires a value"
        date_value="$2"
        shift 2
        ;;
      --date=*)
        date_value="${1#--date=}"
        shift
        ;;
      --cluster)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--cluster requires a value"
        cluster="$2"
        shift 2
        ;;
      --cluster=*)
        cluster="${1#--cluster=}"
        shift
        ;;
      --ascii)
        aicr_operator_render_set_mode "ascii"
        shift
        ;;
      --markdown)
        aicr_operator_render_set_mode "markdown"
        shift
        ;;
      --both)
        aicr_operator_render_set_mode "both"
        shift
        ;;
      --no-stats)
        if [[ "$check" != "gds" && "$check" != nccl-* ]]; then
          aicr_operator_usage_error "--no-stats is supported only for render gds or render nccl-*"
        fi
        no_stats=1
        shift
        ;;
      --nodes-per-job)
        if [[ "$check" != "nccl-rdma" ]]; then
          aicr_operator_usage_error "--nodes-per-job is supported only for render nccl-rdma"
        fi
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--nodes-per-job requires a value"
        nodes_per_job="$2"
        shift 2
        ;;
      --nodes-per-job=*)
        if [[ "$check" != "nccl-rdma" ]]; then
          aicr_operator_usage_error "--nodes-per-job is supported only for render nccl-rdma"
        fi
        nodes_per_job="${1#--nodes-per-job=}"
        shift
        ;;
      -h|--help)
        case "$check" in
          gds) aicr_operator_render_gds_usage ;;
          gpu-topology) aicr_operator_render_gpu_topology_usage ;;
          nccl-local) aicr_operator_render_nccl_local_usage ;;
          nccl-rdma) aicr_operator_render_nccl_rdma_usage ;;
        esac
        exit 0
        ;;
      *)
        aicr_operator_usage_error "unknown render ${check} argument: $1"
        ;;
    esac
  done

  [[ -n "$date_value" ]] || aicr_operator_usage_error "missing required --date <YYYY-MM-DD|today|yesterday>"
  [[ -n "$cluster" ]] || aicr_operator_usage_error "missing required --cluster <b200|rtxpro6000>"
  date_value="$(aicr_operator_resolve_date "$date_value")"
  aicr_operator_require_cluster "$cluster"
  if [[ "$check" == "nccl-rdma" && "$cluster" != "b200" ]]; then
    aicr_operator_usage_error "NCCL RDMA render is B200-only for this slice"
  fi
  if [[ -n "$nodes_per_job" ]]; then
    case "$nodes_per_job" in
      2|4|8|16) ;;
      *) aicr_operator_usage_error "--nodes-per-job must be one of: 2, 4, 8, 16" ;;
    esac
  fi
  aicr_operator_require_repo_root
  [[ -f "$renderer" ]] || aicr_operator_die "missing dashboard renderer: $(aicr_operator_relpath "$renderer")"

  mode="${mode:-ascii}"
  mode_arg="--${mode}"
  manifest="$(aicr_operator_latest_manifest "$check" "$date_value" "$cluster" "$nodes_per_job")"

  echo "Using fleet manifest: $(aicr_operator_relpath "$manifest")" >&2

  local cmd=(
    aicr_python "$renderer"
    --results-root "${AICR_BMARK_DIR}/results"
    --date "$date_value"
    --cluster "$cluster"
    --check "$check"
    "$mode_arg"
    --fleet-manifest "$manifest"
  )

  if [[ "$no_stats" == "1" ]]; then
    cmd+=(--no-stats)
  fi
  if [[ -n "$nodes_per_job" ]]; then
    cmd+=(--nodes-per-job "$nodes_per_job")
  fi

  "${cmd[@]}"
}

aicr_operator_render_nccl_suite() {
  local date_value=""
  local cluster=""
  local mode=""
  local write=0
  local renderer="${AICR_BMARK_DIR}/scripts/report/render-nccl-suite-report.py"
  local manifest
  local cmd

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --date)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--date requires a value"
        date_value="$2"
        shift 2
        ;;
      --date=*)
        date_value="${1#--date=}"
        shift
        ;;
      --cluster)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--cluster requires a value"
        cluster="$2"
        shift 2
        ;;
      --cluster=*)
        cluster="${1#--cluster=}"
        shift
        ;;
      --ascii)
        aicr_operator_render_set_mode "ascii"
        shift
        ;;
      --markdown)
        aicr_operator_render_set_mode "markdown"
        shift
        ;;
      --both)
        aicr_operator_render_set_mode "both"
        shift
        ;;
      --write)
        write=1
        shift
        ;;
      -h|--help)
        aicr_operator_render_nccl_suite_usage
        exit 0
        ;;
      *)
        aicr_operator_usage_error "unknown render nccl-suite argument: $1"
        ;;
    esac
  done

  [[ -n "$date_value" ]] || aicr_operator_usage_error "missing required --date <YYYY-MM-DD|today|yesterday>"
  [[ -n "$cluster" ]] || aicr_operator_usage_error "missing required --cluster <b200|rtxpro6000>"
  date_value="$(aicr_operator_resolve_date "$date_value")"
  aicr_operator_require_cluster "$cluster"
  aicr_operator_require_repo_root
  [[ -f "$renderer" ]] || aicr_operator_die "missing NCCL suite renderer: $(aicr_operator_relpath "$renderer")"

  mode="${mode:-ascii}"
  manifest="$(aicr_operator_latest_manifest "nccl-suite" "$date_value" "$cluster")"
  echo "Using fleet manifest: $(aicr_operator_relpath "$manifest")" >&2

  cmd=(
    aicr_python "$renderer"
    --date "$date_value" \
    --cluster "$cluster" \
    --scope scale \
    --results-root "${AICR_BMARK_DIR}/results" \
    --fleet-manifest "$manifest"
  )
  if [[ "$write" == "1" ]]; then
    cmd+=(--output "${AICR_BMARK_DIR}/results/reports/${date_value}/nccl-suite-${cluster}.md")
  fi

  "${cmd[@]}"
}

aicr_operator_render_elbencho() {
  local date_value=""
  local cluster=""
  local mode=""
  local write=0
  local renderer="${AICR_BMARK_DIR}/scripts/report/render-elbencho-report.py"
  local mode_arg

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --date)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--date requires a value"
        date_value="$2"
        shift 2
        ;;
      --date=*)
        date_value="${1#--date=}"
        shift
        ;;
      --cluster)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--cluster requires a value"
        cluster="$2"
        shift 2
        ;;
      --cluster=*)
        cluster="${1#--cluster=}"
        shift
        ;;
      --ascii)
        aicr_operator_render_set_mode "ascii"
        shift
        ;;
      --markdown)
        aicr_operator_render_set_mode "markdown"
        shift
        ;;
      --both)
        aicr_operator_render_set_mode "both"
        shift
        ;;
      --write)
        write=1
        shift
        ;;
      -h|--help)
        aicr_operator_render_elbencho_usage
        exit 0
        ;;
      *)
        aicr_operator_usage_error "unknown render elbencho argument: $1"
        ;;
    esac
  done

  [[ -n "$date_value" ]] || aicr_operator_usage_error "missing required --date <YYYY-MM-DD|today|yesterday>"
  [[ -n "$cluster" ]] || aicr_operator_usage_error "missing required --cluster <b200|rtxpro6000>"
  date_value="$(aicr_operator_resolve_date "$date_value")"
  aicr_operator_require_cluster "$cluster"
  aicr_operator_require_repo_root
  [[ -f "$renderer" ]] || aicr_operator_die "missing elbencho renderer: $(aicr_operator_relpath "$renderer")"

  mode="${mode:-ascii}"
  mode_arg="--${mode}"

  local cmd=(
    aicr_python "$renderer"
    --results-root "${AICR_BMARK_DIR}/results"
    --date "$date_value"
    --cluster "$cluster"
    "$mode_arg"
  )
  if [[ "$write" == "1" ]]; then
    cmd+=(--write)
  fi
  "${cmd[@]}"
}

aicr_operator_render_campaign() {
  local date_value=""
  local cluster=""
  local campaign_type="verification"
  local mode=""
  local write=0
  local renderer="${AICR_BMARK_DIR}/scripts/report/render-campaign-dashboard.py"
  local mode_arg

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --date)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--date requires a value"
        date_value="$2"
        shift 2
        ;;
      --date=*)
        date_value="${1#--date=}"
        shift
        ;;
      --cluster)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--cluster requires a value"
        cluster="$2"
        shift 2
        ;;
      --cluster=*)
        cluster="${1#--cluster=}"
        shift
        ;;
      --campaign-type)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--campaign-type requires a value"
        campaign_type="$2"
        shift 2
        ;;
      --campaign-type=*)
        campaign_type="${1#--campaign-type=}"
        shift
        ;;
      --ascii)
        aicr_operator_render_set_mode "ascii"
        shift
        ;;
      --markdown)
        aicr_operator_render_set_mode "markdown"
        shift
        ;;
      --both)
        aicr_operator_render_set_mode "both"
        shift
        ;;
      --write)
        write=1
        shift
        ;;
      -h|--help)
        aicr_operator_render_campaign_usage
        exit 0
        ;;
      *)
        aicr_operator_usage_error "unknown render campaign argument: $1"
        ;;
    esac
  done

  [[ -n "$date_value" ]] || aicr_operator_usage_error "missing required --date <YYYY-MM-DD|today|yesterday>"
  [[ -n "$cluster" ]] || aicr_operator_usage_error "missing required --cluster <b200|rtxpro6000>"
  date_value="$(aicr_operator_resolve_date "$date_value")"
  aicr_operator_require_cluster "$cluster"
  [[ "$campaign_type" == "verification" ]] || aicr_operator_usage_error "--campaign-type must be verification for this slice"
  aicr_operator_require_repo_root
  [[ -f "$renderer" ]] || aicr_operator_die "missing campaign renderer: $(aicr_operator_relpath "$renderer")"

  mode="${mode:-ascii}"
  mode_arg="--${mode}"

  local cmd=(
    aicr_python "$renderer"
    --results-root "${AICR_BMARK_DIR}/results"
    --date "$date_value"
    --cluster "$cluster"
    --campaign-type "$campaign_type"
    "$mode_arg"
  )

  if [[ "$write" == "1" ]]; then
    cmd+=(--write)
  fi

  "${cmd[@]}"
}

aicr_operator_render_nodes() {
  local date_value=""
  local cluster=""
  local mode=""
  local write=0
  local renderer="${AICR_BMARK_DIR}/scripts/report/render-node-dashboard.py"
  local mode_arg

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --date)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--date requires a value"
        date_value="$2"
        shift 2
        ;;
      --date=*)
        date_value="${1#--date=}"
        shift
        ;;
      --cluster)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--cluster requires a value"
        cluster="$2"
        shift 2
        ;;
      --cluster=*)
        cluster="${1#--cluster=}"
        shift
        ;;
      --ascii)
        aicr_operator_render_set_mode "ascii"
        shift
        ;;
      --markdown)
        aicr_operator_render_set_mode "markdown"
        shift
        ;;
      --both)
        aicr_operator_render_set_mode "both"
        shift
        ;;
      --write)
        write=1
        shift
        ;;
      -h|--help)
        aicr_operator_render_nodes_usage
        exit 0
        ;;
      *)
        aicr_operator_usage_error "unknown render nodes argument: $1"
        ;;
    esac
  done

  [[ -n "$date_value" ]] || aicr_operator_usage_error "missing required --date <YYYY-MM-DD|today|yesterday>"
  [[ -n "$cluster" ]] || aicr_operator_usage_error "missing required --cluster <b200|rtxpro6000>"
  date_value="$(aicr_operator_resolve_date "$date_value")"
  aicr_operator_require_cluster "$cluster"
  aicr_operator_require_repo_root
  [[ -f "$renderer" ]] || aicr_operator_die "missing node renderer: $(aicr_operator_relpath "$renderer")"

  mode="${mode:-ascii}"
  mode_arg="--${mode}"

  local cmd=(
    aicr_python "$renderer"
    --results-root "${AICR_BMARK_DIR}/results"
    --date "$date_value"
    --cluster "$cluster"
    "$mode_arg"
  )

  if [[ "$write" == "1" ]]; then
    cmd+=(--write)
  fi

  "${cmd[@]}"
}

aicr_operator_render() {
  local check="${1:-}"

  case "$check" in
    -h|--help)
      aicr_operator_render_usage
      exit 0
      ;;
    "")
      aicr_operator_render_usage >&2
      exit 2
      ;;
    gds|gpu-topology|nccl-local|nccl-rdma)
      shift
      aicr_operator_render_check "$check" "$@"
      ;;
    nccl-suite)
      shift
      aicr_operator_render_nccl_suite "$@"
      ;;
    elbencho)
      shift
      aicr_operator_render_elbencho "$@"
      ;;
    campaign)
      shift
      aicr_operator_render_campaign "$@"
      ;;
    nodes)
      shift
      aicr_operator_render_nodes "$@"
      ;;
    *)
      echo "ERROR: unknown render target: ${check}" >&2
      aicr_operator_render_usage >&2
      exit 2
      ;;
  esac
}
