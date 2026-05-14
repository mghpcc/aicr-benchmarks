#!/usr/bin/env python3
"""Shared repeat-sample aggregation helpers for AICR dashboards."""

from __future__ import annotations

import math
import statistics
from typing import Iterable


VALID_REPEAT_AGGREGATIONS = ("standard", "olympic")
OLYMPIC_MIN_SAMPLES = 5


def normalize_repeat_aggregation(value: str | None) -> str:
    mode = (value or "standard").strip().lower()
    if mode not in VALID_REPEAT_AGGREGATIONS:
        raise ValueError(f"unsupported repeat aggregation: {value}")
    return mode


def numeric_values(values: Iterable[object]) -> list[float]:
    out: list[float] = []
    for value in values:
        if value is None:
            continue
        try:
            number = float(value)
        except (TypeError, ValueError):
            continue
        if math.isnan(number) or math.isinf(number):
            continue
        out.append(number)
    return out


def aggregate_values(
    values: Iterable[object],
    mode: str = "standard",
    *,
    standard_center: str = "median",
) -> dict[str, object]:
    """Aggregate numeric values with optional olympic trimming.

    Olympic aggregation uses passed numeric samples supplied by callers, drops
    one lowest and one highest value when at least five samples exist, and
    averages the remaining values. When unavailable, the returned center falls
    back to the requested standard center and marks the fallback explicitly.
    """

    aggregation = normalize_repeat_aggregation(mode)
    numeric = numeric_values(values)
    count = len(numeric)
    ordered = sorted(numeric)
    result: dict[str, object] = {
        "mode": aggregation,
        "count": count,
        "mean": statistics.mean(numeric) if numeric else None,
        "median": statistics.median(numeric) if numeric else None,
        "stdev": statistics.stdev(numeric) if len(numeric) > 1 else 0.0 if numeric else None,
        "min": min(numeric) if numeric else None,
        "max": max(numeric) if numeric else None,
        "raw_values": numeric,
        "dropped_low": None,
        "dropped_high": None,
        "included_count": count,
        "olympic_available": False,
        "fallback_used": False,
        "note": "",
    }

    if standard_center == "mean":
        standard_value = result["mean"]
        standard_label = "mean"
    elif standard_center == "median":
        standard_value = result["median"]
        standard_label = "median"
    else:
        raise ValueError(f"unsupported standard center: {standard_center}")

    if aggregation == "olympic":
        if count >= OLYMPIC_MIN_SAMPLES:
            included = ordered[1:-1]
            result.update(
                {
                    "center": statistics.mean(included),
                    "center_label": "olympic avg",
                    "dropped_low": ordered[0],
                    "dropped_high": ordered[-1],
                    "included_count": len(included),
                    "olympic_available": True,
                    "note": f"olympic avg from {len(included)}/{count}; dropped min/max",
                }
            )
            return result
        result.update(
            {
                "center": standard_value,
                "center_label": f"{standard_label} fallback",
                "fallback_used": True,
                "note": f"olympic unavailable: need >= {OLYMPIC_MIN_SAMPLES} passed numeric samples",
            }
        )
        return result

    result.update(
        {
            "center": standard_value,
            "center_label": standard_label,
            "note": standard_label,
        }
    )
    return result
