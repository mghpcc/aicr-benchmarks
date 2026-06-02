#!/usr/bin/env python3
import argparse
import importlib.util
import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REGISTRY = REPO_ROOT / "docs" / "benchmarks" / "campaign-requirements.json"
RENDERER = REPO_ROOT / "scripts" / "report" / "render-benchmark-campaign.py"
ALLOWED_SCOPES = {"required", "optional"}
ALLOWED_CLUSTERS = {"all", "b200", "rtxpro6000"}
RTX_DATALOADER_SCALES = {1, 2, 4}
HPL_CAMPAIGN_TARGETS = {
    ("b200", 1): 379904,
    ("b200", 2): 530432,
    ("b200", 4): 749568,
    ("b200", 8): 1049600,
    ("b200", 16): 1500160,
}
HPL_NB = 2048
HPL_BANNED_TERMS = (
    "theoretical",
    r"hardware\s+peak",
    r"efficiency\s+denominator",
    r"percent[- ]of[- ]peak",
)
HPL_BANNED_LANGUAGE = re.compile("(" + "|".join(HPL_BANNED_TERMS) + ")", re.IGNORECASE)
TEXT_FIELDS = (
    "requirement",
    "note",
    "complete_note",
    "staged_note",
    "missing_note",
    "gap_note",
    "surrogate_note",
)


def build_parser():
    parser = argparse.ArgumentParser(description="Validate benchmark campaign requirements registry.")
    parser.add_argument("--registry", default=str(DEFAULT_REGISTRY))
    return parser


def load_renderer():
    spec = importlib.util.spec_from_file_location("render_benchmark_campaign", RENDERER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load renderer module: {RENDERER}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def as_int(value):
    if isinstance(value, bool) or value in (None, ""):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def add(errors, row, message):
    row_id = row.get("id", "<missing id>") if isinstance(row, dict) else "<invalid row>"
    errors.append(f"{row_id}: {message}")


def validate_row_shape(row, index, seen, detectors, statuses, errors):
    if not isinstance(row, dict):
        errors.append(f"row {index}: expected object")
        return
    required = ("id", "benchmark", "memo_scope", "cluster", "requirement", "detector")
    for field in required:
        if field not in row:
            add(errors, row, f"missing required field {field!r}")
    row_id = row.get("id")
    if row_id:
        if row_id in seen:
            add(errors, row, "duplicate id")
        seen.add(row_id)
    if row.get("memo_scope") not in ALLOWED_SCOPES:
        add(errors, row, f"memo_scope must be one of {sorted(ALLOWED_SCOPES)}")
    if row.get("cluster") not in ALLOWED_CLUSTERS:
        add(errors, row, f"cluster must be one of {sorted(ALLOWED_CLUSTERS)}")
    if row.get("detector") not in detectors:
        add(errors, row, f"unknown detector {row.get('detector')!r}")
    if "status" in row and row.get("status") not in statuses:
        add(errors, row, f"status must be one of {sorted(statuses)}")
    if row.get("detector") == "static_status" and "status" not in row:
        add(errors, row, "static_status rows must include status")


def validate_campaign_policy(row, errors):
    benchmark = str(row.get("benchmark", ""))
    cluster = row.get("cluster")
    memo_scope = row.get("memo_scope")
    detector = row.get("detector")
    row_id = str(row.get("id", ""))

    if "HPL" in benchmark:
        text = " ".join(str(row.get(field, "")) for field in TEXT_FIELDS)
        match = HPL_BANNED_LANGUAGE.search(text)
        if match:
            add(errors, row, f"HPL text uses banned hardware-peak framing: {match.group(0)!r}")

    if benchmark == "Benchmark 1 DataLoader" and cluster == "rtxpro6000" and memo_scope == "required":
        if detector == "dataloader_scale" and as_int(row.get("nodes")) not in RTX_DATALOADER_SCALES:
            add(errors, row, "RTX DataLoader required scale rows must be limited to 1, 2, and 4 nodes")

    if "ResNet-50 DDP" in benchmark and memo_scope == "required" and row.get("launcher") == "srun":
        add(errors, row, "DDP srun rows must be optional supplemental evidence")

    if "HPL-MxP" in benchmark and cluster == "b200" and memo_scope == "required":
        nodes = as_int(row.get("nodes"))
        target = HPL_CAMPAIGN_TARGETS.get((cluster, nodes))
        if target is None:
            add(errors, row, "HPL required rows must use the weak-study campaign node ladder")
        if as_int(row.get("target_matrix_size")) != target:
            add(errors, row, f"HPL required rows must use target_matrix_size={target}")
        if as_int(row.get("target_nb")) != HPL_NB:
            add(errors, row, f"HPL required rows must use target_nb={HPL_NB}")
        if row.get("scaling_study") != "weak":
            add(errors, row, "HPL required rows must use scaling_study='weak'")


def main():
    args = build_parser().parse_args()
    renderer = load_renderer()
    detectors = set(renderer.DETECTORS)
    statuses = set(renderer.STATUS_VOCABULARY)
    path = Path(args.registry)
    errors = []

    try:
        registry = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: unable to load {path}: {exc}", file=sys.stderr)
        return 1

    if not isinstance(registry, dict):
        print("ERROR: registry must be a JSON object", file=sys.stderr)
        return 1
    if registry.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    rows = registry.get("rows")
    if not isinstance(rows, list):
        errors.append("registry must contain a rows list")
        rows = []

    seen = set()
    for index, row in enumerate(rows, start=1):
        validate_row_shape(row, index, seen, detectors, statuses, errors)
        if isinstance(row, dict):
            validate_campaign_policy(row, errors)

    if errors:
        print("Benchmark campaign registry validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"Benchmark campaign registry validation passed: {len(rows)} rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
