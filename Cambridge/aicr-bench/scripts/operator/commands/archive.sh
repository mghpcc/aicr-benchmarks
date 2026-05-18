#!/usr/bin/env bash
set -euo pipefail

aicr_operator_archive_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr archive list [--date <YYYY-MM-DD|today|yesterday>] [--cluster <b200|rtxpro6000>] [--scope <verify|all>] [--json]
  scripts/operator/aicr archive show --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> --scope verify [--manifest <path>] [--contents] [--json]
  scripts/operator/aicr archive verify --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> --scope verify [--manifest <path>]
  scripts/operator/aicr archive extract --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> --scope verify [--manifest <path>] --dest <path> [--include <archive-member-prefix>]...

Defaults:
  list defaults to --scope all.
  show, verify, and extract use the selector triple by default; --manifest bypasses selector resolution.

Notes:
  The archive helper treats results/archives/<date>/*.json manifests as the source of truth.
  show --contents lists archive members without extracting.
  verify checks the archive file at archive_path against the manifest SHA-256.
  extract requires an explicit --dest and can optionally limit extraction with repeated --include prefixes.
EOF
}

aicr_operator_archive_list_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr archive list [--date <YYYY-MM-DD|today|yesterday>] [--cluster <b200|rtxpro6000>] [--scope <verify|all>] [--json]

Lists known retained archives by reading results/archives/*/*.json manifests.
EOF
}

aicr_operator_archive_show_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr archive show --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> --scope verify [--manifest <path>] [--contents] [--json]

Shows archive manifest metadata and optional archive contents.
EOF
}

aicr_operator_archive_verify_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr archive verify --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> --scope verify [--manifest <path>]

Verifies the archive file at archive_path against the manifest SHA-256.
EOF
}

aicr_operator_archive_extract_usage() {
  cat <<'EOF'
Usage:
  scripts/operator/aicr archive extract --date <YYYY-MM-DD|today|yesterday> --cluster <b200|rtxpro6000> --scope verify [--manifest <path>] --dest <path> [--include <archive-member-prefix>]...

Extracts an archive to an explicit destination path. Repeated --include prefixes limit extraction to matching archive members.
EOF
}

aicr_operator_archive_require_scope() {
  local scope="$1"
  local allow_all="${2:-0}"

  case "$scope" in
    verify)
      ;;
    all)
      [[ "$allow_all" == "1" ]] || aicr_operator_usage_error "--scope all is supported only for archive list"
      ;;
    *)
      if [[ "$allow_all" == "1" ]]; then
        aicr_operator_usage_error "--scope must be one of: verify, all"
      fi
      aicr_operator_usage_error "--scope must be verify"
      ;;
  esac
}

aicr_operator_archive_resolve_manifest_arg() {
  local manifest_arg="$1"
  local candidate

  if [[ -f "$manifest_arg" ]]; then
    printf '%s\n' "$manifest_arg"
    return 0
  fi

  candidate="${AICR_BMARK_DIR}/${manifest_arg}"
  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  aicr_operator_die "manifest not found: ${manifest_arg}"
}

aicr_operator_archive_manifest_from_selector() {
  local date_value="$1"
  local cluster="$2"
  local scope="$3"
  local manifest="${AICR_BMARK_DIR}/results/archives/${date_value}/aicr-results-${date_value}-${cluster}-${scope}.json"

  [[ -f "$manifest" ]] || aicr_operator_die "no ${scope} archive manifest found for date=${date_value} cluster=${cluster}: $(aicr_operator_relpath "$manifest")"
  printf '%s\n' "$manifest"
}

aicr_operator_archive_manifest_value() {
  local manifest_path="$1"
  local key="$2"
  aicr_python - "$manifest_path" "$key" <<'PY'
import json
import sys
from pathlib import Path

manifest_path, key = sys.argv[1:]
obj = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
value = obj
for part in key.split("."):
    if isinstance(value, dict):
        value = value.get(part)
    else:
        value = None
        break

if value is None:
    print("")
elif isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
}

aicr_operator_archive_list() {
  local date_value=""
  local cluster=""
  local scope="all"
  local json_output=0

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
      --scope)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--scope requires a value"
        scope="$2"
        shift 2
        ;;
      --scope=*)
        scope="${1#--scope=}"
        shift
        ;;
      --json)
        json_output=1
        shift
        ;;
      -h|--help)
        aicr_operator_archive_list_usage
        exit 0
        ;;
      *)
        aicr_operator_usage_error "unknown archive list argument: $1"
        ;;
    esac
  done

  if [[ -n "$date_value" ]]; then
    date_value="$(aicr_operator_resolve_date "$date_value")"
  fi
  if [[ -n "$cluster" ]]; then
    aicr_operator_require_cluster "$cluster"
  fi
  aicr_operator_archive_require_scope "$scope" 1
  aicr_operator_require_repo_root

  aicr_python - "$AICR_BMARK_DIR" "$date_value" "$cluster" "$scope" "$json_output" <<'PY'
import json
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
date_filter = sys.argv[2] or None
cluster_filter = sys.argv[3] or None
scope_filter = sys.argv[4]
json_output = sys.argv[5] == "1"

entries = []
archives_dir = repo_root / "results" / "archives"
if archives_dir.exists():
    for path in sorted(archives_dir.glob("*/*.json")):
        try:
            obj = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if obj.get("kind") != "aicr-results-archive":
            continue
        if date_filter and obj.get("date") != date_filter:
            continue
        if cluster_filter and obj.get("cluster") != cluster_filter:
            continue
        if scope_filter != "all" and obj.get("scope") != scope_filter:
            continue
        archive_path = obj.get("archive_path")
        entries.append({
            "manifest_path": str(path.relative_to(repo_root)),
            "date": obj.get("date") or path.parent.name,
            "cluster": obj.get("cluster") or "-",
            "scope": obj.get("scope") or "-",
            "compression": obj.get("compression") or "-",
            "byte_size": obj.get("byte_size") if obj.get("byte_size") is not None else "-",
            "archive_exists": bool(archive_path and Path(archive_path).exists()),
            "archive_path": archive_path,
            "created_at_utc": obj.get("created_at_utc"),
        })

entries.sort(key=lambda item: (item["date"], item["cluster"], item["scope"], item["manifest_path"]))

if json_output:
    print(json.dumps(entries, indent=2))
    raise SystemExit(0)

if not entries:
    print("No archive manifests matched.")
    raise SystemExit(0)

columns = [
    ("date", "Date"),
    ("cluster", "Cluster"),
    ("scope", "Scope"),
    ("compression", "Compression"),
    ("byte_size", "Bytes"),
    ("archive_exists", "Exists"),
    ("manifest_path", "Manifest"),
]

rows = []
for item in entries:
    row = dict(item)
    row["archive_exists"] = "yes" if item["archive_exists"] else "no"
    row["byte_size"] = str(item["byte_size"])
    rows.append(row)

widths = {
    key: max(len(label), *(len(str(row.get(key, ""))) for row in rows)) if rows else len(label)
    for key, label in columns
}

print(f"AICR Archive Inventory   Matches: {len(rows)}")
print()
print("  ".join(label.ljust(widths[key]) for key, label in columns))
print("  ".join("-" * widths[key] for key, _ in columns))
for row in rows:
    print("  ".join(str(row.get(key, "")).ljust(widths[key]) for key, _ in columns))
PY
}

aicr_operator_archive_show() {
  local date_value=""
  local cluster=""
  local scope=""
  local manifest_arg=""
  local contents=0
  local json_output=0
  local manifest_path
  local archive_path=""
  local contents_file=""

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
      --scope)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--scope requires a value"
        scope="$2"
        shift 2
        ;;
      --scope=*)
        scope="${1#--scope=}"
        shift
        ;;
      --manifest)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--manifest requires a value"
        manifest_arg="$2"
        shift 2
        ;;
      --manifest=*)
        manifest_arg="${1#--manifest=}"
        shift
        ;;
      --contents)
        contents=1
        shift
        ;;
      --json)
        json_output=1
        shift
        ;;
      -h|--help)
        aicr_operator_archive_show_usage
        exit 0
        ;;
      *)
        aicr_operator_usage_error "unknown archive show argument: $1"
        ;;
    esac
  done

  aicr_operator_require_repo_root
  if [[ -n "$manifest_arg" ]]; then
    manifest_path="$(aicr_operator_archive_resolve_manifest_arg "$manifest_arg")"
  else
    [[ -n "$date_value" ]] || aicr_operator_usage_error "missing required --date <YYYY-MM-DD|today|yesterday>"
    [[ -n "$cluster" ]] || aicr_operator_usage_error "missing required --cluster <b200|rtxpro6000>"
    [[ -n "$scope" ]] || aicr_operator_usage_error "missing required --scope verify"
    date_value="$(aicr_operator_resolve_date "$date_value")"
    aicr_operator_require_cluster "$cluster"
    aicr_operator_archive_require_scope "$scope" 0
    manifest_path="$(aicr_operator_archive_manifest_from_selector "$date_value" "$cluster" "$scope")"
  fi

  if [[ "$contents" == "1" ]]; then
    archive_path="$(aicr_operator_archive_manifest_value "$manifest_path" "archive_path")"
    [[ -n "$archive_path" ]] || aicr_operator_die "manifest is missing archive_path: $(aicr_operator_relpath "$manifest_path")"
    [[ -f "$archive_path" ]] || aicr_operator_die "archive file does not exist: ${archive_path}"
    contents_file="$(mktemp)"
    aicr_operator_archive_list_members "$archive_path" >"$contents_file"
  fi

  aicr_python - "$AICR_BMARK_DIR" "$manifest_path" "$json_output" "$contents_file" <<'PY'
import json
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
json_output = sys.argv[3] == "1"
contents_file = sys.argv[4]

obj = json.loads(manifest_path.read_text(encoding="utf-8"))
try:
    manifest_rel = str(manifest_path.resolve().relative_to(repo_root.resolve()))
except ValueError:
    manifest_rel = str(manifest_path)
archive_path = obj.get("archive_path")
archive_exists = bool(archive_path and Path(archive_path).exists())
missing_paths = obj.get("missing_optional_paths")
if missing_paths is None:
    missing_paths = obj.get("missing_source_paths") or []
contents = []
if contents_file:
    contents = Path(contents_file).read_text(encoding="utf-8").splitlines()

if json_output:
    out = dict(obj)
    out["manifest_path"] = manifest_rel
    out["archive_exists"] = archive_exists
    if contents_file:
      out["archive_contents"] = contents
    print(json.dumps(out, indent=2))
    raise SystemExit(0)

print("AICR Archive Manifest")
print(f"Manifest      : {manifest_rel}")
print(f"Date          : {obj.get('date', '-')}")
print(f"Cluster       : {obj.get('cluster', '-')}")
print(f"Scope         : {obj.get('scope', '-')}")
print(f"Created at    : {obj.get('created_at_utc', '-')}")
print(f"Archive path  : {archive_path or '-'}")
print(f"Archive exists: {'yes' if archive_exists else 'no'}")
print(f"Compression   : {obj.get('compression', '-')}")
print(f"Byte size     : {obj.get('byte_size', '-')}")
print(f"SHA256        : {obj.get('sha256', '-')}")
print(f"Repo commit   : {obj.get('repo_commit', '-')}")
print(f"Repo dirty    : {'true' if obj.get('repo_dirty') else 'false'}")
print()
print("Source paths:")
for item in obj.get("source_paths") or []:
    print(f"  {item}")
if missing_paths:
    print()
    print("Missing paths:")
    for item in missing_paths:
        print(f"  {item}")
if contents_file:
    print()
    print("Archive contents:")
    for item in contents:
        print(f"  {item}")
PY

  if [[ -n "$contents_file" ]]; then
    rm -f "$contents_file"
  fi
}

aicr_operator_archive_verify() {
  local date_value=""
  local cluster=""
  local scope=""
  local manifest_arg=""
  local manifest_path
  local archive_path=""
  local expected_sha=""
  local actual_sha=""

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
      --scope)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--scope requires a value"
        scope="$2"
        shift 2
        ;;
      --scope=*)
        scope="${1#--scope=}"
        shift
        ;;
      --manifest)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--manifest requires a value"
        manifest_arg="$2"
        shift 2
        ;;
      --manifest=*)
        manifest_arg="${1#--manifest=}"
        shift
        ;;
      -h|--help)
        aicr_operator_archive_verify_usage
        exit 0
        ;;
      *)
        aicr_operator_usage_error "unknown archive verify argument: $1"
        ;;
    esac
  done

  aicr_operator_require_repo_root
  if [[ -n "$manifest_arg" ]]; then
    manifest_path="$(aicr_operator_archive_resolve_manifest_arg "$manifest_arg")"
  else
    [[ -n "$date_value" ]] || aicr_operator_usage_error "missing required --date <YYYY-MM-DD|today|yesterday>"
    [[ -n "$cluster" ]] || aicr_operator_usage_error "missing required --cluster <b200|rtxpro6000>"
    [[ -n "$scope" ]] || aicr_operator_usage_error "missing required --scope verify"
    date_value="$(aicr_operator_resolve_date "$date_value")"
    aicr_operator_require_cluster "$cluster"
    aicr_operator_archive_require_scope "$scope" 0
    manifest_path="$(aicr_operator_archive_manifest_from_selector "$date_value" "$cluster" "$scope")"
  fi

  archive_path="$(aicr_operator_archive_manifest_value "$manifest_path" "archive_path")"
  expected_sha="$(aicr_operator_archive_manifest_value "$manifest_path" "sha256")"
  [[ -n "$archive_path" ]] || aicr_operator_die "manifest is missing archive_path: $(aicr_operator_relpath "$manifest_path")"
  [[ -n "$expected_sha" ]] || aicr_operator_die "manifest is missing sha256: $(aicr_operator_relpath "$manifest_path")"
  [[ -f "$archive_path" ]] || aicr_operator_die "archive file does not exist: ${archive_path}"

  actual_sha="$(aicr_operator_sha256_file "$archive_path")"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "Archive checksum verification failed" >&2
    echo "Manifest    : $(aicr_operator_relpath "$manifest_path")" >&2
    echo "Archive path: ${archive_path}" >&2
    echo "Expected    : ${expected_sha}" >&2
    echo "Actual      : ${actual_sha}" >&2
    exit 1
  fi

  echo "Archive checksum verified"
  echo "Manifest    : $(aicr_operator_relpath "$manifest_path")"
  echo "Archive path: ${archive_path}"
  echo "SHA256      : ${actual_sha}"
}

aicr_operator_archive_extract() {
  local date_value=""
  local cluster=""
  local scope=""
  local manifest_arg=""
  local dest_path=""
  local manifest_path
  local archive_path=""
  local include_prefixes=()
  local members_file=""
  local matched_file=""
  local member
  local matched_count=0
  local matched_members=()

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
      --scope)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--scope requires a value"
        scope="$2"
        shift 2
        ;;
      --scope=*)
        scope="${1#--scope=}"
        shift
        ;;
      --manifest)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--manifest requires a value"
        manifest_arg="$2"
        shift 2
        ;;
      --manifest=*)
        manifest_arg="${1#--manifest=}"
        shift
        ;;
      --dest)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--dest requires a value"
        dest_path="$2"
        shift 2
        ;;
      --dest=*)
        dest_path="${1#--dest=}"
        shift
        ;;
      --include)
        [[ -n "${2:-}" ]] || aicr_operator_usage_error "--include requires a value"
        include_prefixes+=("$2")
        shift 2
        ;;
      --include=*)
        include_prefixes+=("${1#--include=}")
        shift
        ;;
      -h|--help)
        aicr_operator_archive_extract_usage
        exit 0
        ;;
      *)
        aicr_operator_usage_error "unknown archive extract argument: $1"
        ;;
    esac
  done

  [[ -n "$dest_path" ]] || aicr_operator_usage_error "missing required --dest <path>"
  aicr_operator_require_repo_root
  if [[ -n "$manifest_arg" ]]; then
    manifest_path="$(aicr_operator_archive_resolve_manifest_arg "$manifest_arg")"
  else
    [[ -n "$date_value" ]] || aicr_operator_usage_error "missing required --date <YYYY-MM-DD|today|yesterday>"
    [[ -n "$cluster" ]] || aicr_operator_usage_error "missing required --cluster <b200|rtxpro6000>"
    [[ -n "$scope" ]] || aicr_operator_usage_error "missing required --scope verify"
    date_value="$(aicr_operator_resolve_date "$date_value")"
    aicr_operator_require_cluster "$cluster"
    aicr_operator_archive_require_scope "$scope" 0
    manifest_path="$(aicr_operator_archive_manifest_from_selector "$date_value" "$cluster" "$scope")"
  fi

  archive_path="$(aicr_operator_archive_manifest_value "$manifest_path" "archive_path")"
  [[ -n "$archive_path" ]] || aicr_operator_die "manifest is missing archive_path: $(aicr_operator_relpath "$manifest_path")"
  [[ -f "$archive_path" ]] || aicr_operator_die "archive file does not exist: ${archive_path}"

  if [[ -e "$dest_path" && ! -d "$dest_path" ]]; then
    aicr_operator_die "--dest must be a directory path: ${dest_path}"
  fi

  if [[ "${#include_prefixes[@]}" -eq 0 ]]; then
    aicr_operator_archive_extract_members "$archive_path" "$dest_path"
    echo "Extracted full archive"
    echo "Manifest    : $(aicr_operator_relpath "$manifest_path")"
    echo "Archive path: ${archive_path}"
    echo "Destination : ${dest_path}"
    return 0
  fi

  members_file="$(mktemp)"
  matched_file="$(mktemp)"
  aicr_operator_archive_list_members "$archive_path" >"$members_file"
  if ! aicr_python - "$members_file" "$matched_file" "${include_prefixes[@]}" <<'PY'
import sys
from pathlib import Path

members_path = Path(sys.argv[1])
matched_path = Path(sys.argv[2])
prefixes = []
for raw in sys.argv[3:]:
    value = raw.strip().lstrip("./").rstrip("/")
    if value:
        prefixes.append(value)

members = members_path.read_text(encoding="utf-8").splitlines()
matched = []
seen = set()
for member in members:
    candidate = member.strip().lstrip("./").rstrip("/")
    if not candidate:
        continue
    if member.endswith("/"):
        continue
    for prefix in prefixes:
        if candidate == prefix or candidate.startswith(prefix + "/"):
            if member not in seen:
                matched.append(member)
                seen.add(member)
            break

matched_path.write_text("\n".join(matched) + ("\n" if matched else ""), encoding="utf-8")
if not matched:
    raise SystemExit(3)
PY
  then
    rm -f "$members_file" "$matched_file"
    aicr_operator_die "no archive members matched the requested --include prefixes"
  fi

  while IFS= read -r member; do
    [[ -n "$member" ]] || continue
    matched_members+=("$member")
  done <"$matched_file"
  matched_count="${#matched_members[@]}"

  aicr_operator_archive_extract_members "$archive_path" "$dest_path" "${matched_members[@]}"

  rm -f "$members_file" "$matched_file"

  echo "Extracted filtered archive members"
  echo "Manifest    : $(aicr_operator_relpath "$manifest_path")"
  echo "Archive path: ${archive_path}"
  echo "Destination : ${dest_path}"
  echo "Members     : ${matched_count}"
}

aicr_operator_archive() {
  local subcommand="${1:-}"

  case "$subcommand" in
    -h|--help)
      aicr_operator_archive_usage
      exit 0
      ;;
    "")
      aicr_operator_archive_usage >&2
      exit 2
      ;;
    list)
      shift
      aicr_operator_archive_list "$@"
      ;;
    show)
      shift
      aicr_operator_archive_show "$@"
      ;;
    verify)
      shift
      aicr_operator_archive_verify "$@"
      ;;
    extract)
      shift
      aicr_operator_archive_extract "$@"
      ;;
    *)
      echo "ERROR: unknown archive subcommand: ${subcommand}" >&2
      aicr_operator_archive_usage >&2
      exit 2
      ;;
  esac
}
