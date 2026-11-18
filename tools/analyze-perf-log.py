#!/usr/bin/env python3
"""Summarize a ZH_PERF_LOG CSV (frame,frame_ms).

Prints mean/median/p95/p99 frame time, derived FPS, the share of frames over the
33.3 ms (30 FPS) and 16.7 ms (60 FPS) budgets, and the worst frames. Supports
trimming the start (menu/loading) and analysing only a tail window.

Examples:
    python tools/analyze-perf-log.py artifacts/.../perf.csv --skip 900
    python tools/analyze-perf-log.py perf.csv --skip 900 --tail 1200 --json
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from pathlib import Path


def percentile(sorted_values: list[float], pct: float) -> float:
    if not sorted_values:
        return float("nan")
    k = (len(sorted_values) - 1) * (pct / 100.0)
    lo = int(k)
    hi = min(lo + 1, len(sorted_values) - 1)
    frac = k - lo
    return sorted_values[lo] * (1 - frac) + sorted_values[hi] * frac


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--skip", type=int, default=0, help="drop this many leading frames (menu/load)")
    ap.add_argument("--tail", type=int, default=0, help="keep only this many trailing frames after --skip")
    ap.add_argument("--label", default=None)
    ap.add_argument("--budget", type=float, default=33.34, help="frame budget in ms (30 FPS default)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)

    rows: list[tuple[int, float]] = []
    with Path(args.csv).open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("frame"):
                continue
            parts = line.split(",")
            if len(parts) != 2:
                continue
            try:
                rows.append((int(parts[0]), float(parts[1])))
            except ValueError:
                continue

    if not rows:
        print("no frame rows", file=sys.stderr)
        return 2

    values = [ms for _, ms in rows]
    values = values[args.skip:]
    if args.tail > 0:
        values = values[-args.tail:]
    if not values:
        print("empty window", file=sys.stderr)
        return 2

    ordered = sorted(values)
    mean = statistics.fmean(values)
    median = statistics.median(values)
    p95 = percentile(ordered, 95)
    p99 = percentile(ordered, 99)
    over30 = sum(1 for v in values if v > args.budget) / len(values) * 100.0
    over16 = sum(1 for v in values if v > 16.67) / len(values) * 100.0

    summary = {
        "label": args.label or Path(args.csv).name,
        "frames": len(values),
        "mean_ms": round(mean, 3),
        "median_ms": round(median, 3),
        "p95_ms": round(p95, 3),
        "p99_ms": round(p99, 3),
        "mean_fps": round(1000.0 / mean, 2),
        "median_fps": round(1000.0 / median, 2),
        "over_30fps_budget_pct": round(over30, 2),
        "over_60fps_budget_pct": round(over16, 2),
        "worst_ms": round(max(values), 3),
    }

    if args.json:
        print(json.dumps(summary, indent=2))
        return 0

    print(f"{summary['label']}: frames={summary['frames']}")
    print(f"  mean   {summary['mean_ms']:8.2f} ms  ({summary['mean_fps']:6.2f} FPS)")
    print(f"  median {summary['median_ms']:8.2f} ms  ({summary['median_fps']:6.2f} FPS)")
    print(f"  p95    {summary['p95_ms']:8.2f} ms")
    print(f"  p99    {summary['p99_ms']:8.2f} ms")
    print(f"  worst  {summary['worst_ms']:8.2f} ms")
    print(f"  > 33.3 ms: {summary['over_30fps_budget_pct']:5.1f}%   > 16.7 ms: {summary['over_60fps_budget_pct']:5.1f}%")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
