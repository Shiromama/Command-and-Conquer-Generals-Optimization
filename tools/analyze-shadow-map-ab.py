"""Analyze an alternating Stencil/ShadowMap A/B artifact set for T-035.

Usage: python tools/analyze-shadow-map-ab.py <root> [--warmup 300] [--output summary.json]

Expects A-1, B-1, A-2, B-2, ... directories, each containing frames.csv
(frame,frame_ms) written by tools/benchmark-shadow-map.ps1. Drops the first
`warmup` frames (scene spawn/warmup), then reports median/p95/p99 in ms and FPS
per run, the per-pair delta, and the aggregate delta over all pairs.
"""
import csv
import glob
import json
import os
import statistics
import sys


def quantile(values, q):
    s = sorted(values)
    k = (len(s) - 1) * q
    lo = int(k)
    hi = min(lo + 1, len(s) - 1)
    return s[lo] + (s[hi] - s[lo]) * (k - lo)


def read_frames(path, warmup):
    values = []
    with open(path) as f:
        for row in csv.DictReader(f):
            try:
                values.append(float(row["frame_ms"]))
            except (KeyError, TypeError, ValueError):
                continue
    return values[warmup:], len(values)


def summarize(values, total):
    return {
        "frames": total,
        "samples": len(values),
        "median_ms": round(statistics.median(values), 4),
        "p95_ms": round(quantile(values, 0.95), 4),
        "p99_ms": round(quantile(values, 0.99), 4),
        "fps_median": round(1000.0 / statistics.median(values), 2),
    }


def main():
    root = sys.argv[1]
    warmup = 300
    output = None
    args = sys.argv[2:]
    if "--warmup" in args:
        warmup = int(args[args.index("--warmup") + 1])
    if "--output" in args:
        output = args[args.index("--output") + 1]

    result = {"root": root, "warmup_frames": warmup, "runs": {}, "pairs": [], "aggregate": {}}
    for arm in ("A", "B"):
        for path in sorted(glob.glob(os.path.join(root, f"{arm}-*", "frames.csv"))):
            values, total = read_frames(path, warmup)
            if not values:
                raise SystemExit(f"no usable frames in {path}")
            result["runs"][os.path.basename(os.path.dirname(path))] = summarize(values, total)

    indexes = sorted(
        int(name.split("-")[1])
        for name in result["runs"]
        if name.startswith("A-")
        and os.path.basename(name).replace("A-", "B-") in result["runs"]
    )
    ratios = []
    for i in indexes:
        a = result["runs"][f"A-{i}"]["median_ms"]
        b = result["runs"][f"B-{i}"]["median_ms"]
        ratios.append(b / a)
        result["pairs"].append(
            {
                "pair": i,
                "stencil_median_ms": a,
                "shadowmap_median_ms": b,
                "shadowmap_over_stencil": round(b / a, 4),
            }
        )
    if ratios:
        result["aggregate"] = {
            "pairs": len(ratios),
            "shadowmap_over_stencil_mean": round(statistics.mean(ratios), 4),
            "shadowmap_over_stencil_min": round(min(ratios), 4),
            "shadowmap_over_stencil_max": round(max(ratios), 4),
        }

    text = json.dumps(result, indent=2)
    print(text)
    if output:
        with open(output, "w") as f:
            f.write(text + "\n")


if __name__ == "__main__":
    main()
