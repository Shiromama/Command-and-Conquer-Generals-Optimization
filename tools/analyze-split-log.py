#!/usr/bin/env python3
"""Summarize a ZH_PERF_SPLIT CSV (phase,ms) written by the project harness.

Phases are `draw` (TheDisplay->DRAW), `client` (TheGameClient->UPDATE) and
`logic` (TheGameLogic->UPDATE). Prints median/p95 per phase for the whole file
and for a trailing window, which is how render cost and simulation cost are
attributed between frames.

Usage:
    python tools/analyze-split-log.py split.csv --skip-lines 2000 --tail 600
"""
from __future__ import annotations

import argparse
import statistics
import sys
from collections import defaultdict
from pathlib import Path


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return float("nan")
    ordered = sorted(values)
    k = (len(ordered) - 1) * (pct / 100.0)
    lo = int(k)
    hi = min(lo + 1, len(ordered) - 1)
    return ordered[lo] * (1 - (k - lo)) + ordered[hi] * (k - lo)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("csv")
    ap.add_argument("--skip-lines", type=int, default=0)
    ap.add_argument("--tail", type=int, default=0, help="keep the last N lines per phase")
    ap.add_argument("--label", default=None)
    args = ap.parse_args(argv)

    phases: dict[str, list[float]] = defaultdict(list)
    with Path(args.csv).open("r", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            parts = line.strip().split(",")
            if len(parts) != 2:
                continue
            try:
                phases[parts[0]].append(float(parts[1]))
            except ValueError:
                continue

    print(f"{args.label or Path(args.csv).name}")
    for phase in ("draw", "client", "logic"):
        values = phases.get(phase, [])
        if args.skip_lines:
            values = values[args.skip_lines:]
        if args.tail:
            values = values[-args.tail:]
        if not values:
            continue
        print(f"  {phase:6} n={len(values):5}  median={statistics.median(values):7.2f} ms  "
              f"mean={statistics.fmean(values):7.2f}  p95={percentile(values, 95):7.2f}  "
              f"max={max(values):8.2f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
