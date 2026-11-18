#!/usr/bin/env python3
"""Summarize an engine frame-attribution CSV (T-051, ZH_ATTR_LOG).

Columns (see PerfAttrib.h / GameEngine::zhAttrWriteFrame):
  frame, interval, pre, audio, client, msg, net, logic, pacer, gap,
  shell, draw, particles, displaystr, ingameui,
  l_updates, l_ai, l_build, l_partition, l_destroy, l_rest,
  slowest_update_us, slowest_update, slowest_update_obj,
  destroyed, slowest_destroy_us, slowest_destroy,
  spawned, spawn_ms, nukes

Usage:
  python tools/analyze-attr-log.py artifacts/<run>/attr.csv [--top 10] [--json out.json]
"""
import argparse
import csv
import json
import math
import sys

BUCKETS = ["pre", "audio", "client", "msg", "net", "logic", "pacer", "gap"]
CLIENT_PARTS = ["shell", "draw", "particles", "displaystr", "ingameui"]
LOGIC_PARTS = ["l_updates", "l_ai", "l_build", "l_partition", "l_destroy", "l_rest"]
NUMERIC = BUCKETS + CLIENT_PARTS + LOGIC_PARTS + [
    "row", "frame", "interval", "slowest_update_us", "destroyed", "slowest_destroy_us",
    "spawned", "spawn_ms", "nukes",
]


def pct(values, q):
    if not values:
        return None
    s = sorted(values)
    if len(s) == 1:
        return s[0]
    k = (len(s) - 1) * q
    lo = math.floor(k)
    hi = math.ceil(k)
    if lo == hi:
        return s[int(k)]
    return s[lo] + (s[hi] - s[lo]) * (k - lo)


def summarize(values):
    values = [v for v in values if v is not None]
    if not values:
        return {}
    return {
        "n": len(values),
        "median": round(pct(values, 0.5), 3),
        "mean": round(sum(values) / len(values), 3),
        "p95": round(pct(values, 0.95), 3),
        "p99": round(pct(values, 0.99), 3),
        "max": round(max(values), 3),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--top", type=int, default=8)
    ap.add_argument("--json")
    ap.add_argument("--skip", type=int, default=0, help="skip the first N rows (loading frames)")
    args = ap.parse_args()

    rows = []
    with open(args.path, newline="") as f:
        for row in csv.DictReader(f):
            try:
                conv = {k: (float(row[k]) if k in NUMERIC else row[k]) for k in row}
            except (TypeError, ValueError):
                continue
            if conv.get("interval") is None or conv["interval"] <= 0:
                continue
            rows.append(conv)

    rows = rows[args.skip:]
    if not rows:
        print("no usable rows", file=sys.stderr)
        return 1

    print(f"file: {args.path}")
    print(f"rows: {len(rows)}  frames: {int(rows[0]['frame'])}..{int(rows[-1]['frame'])}")
    intervals = [r["interval"] for r in rows]
    print(f"interval ms: median {pct(intervals,0.5):.2f}  p95 {pct(intervals,0.95):.2f}  "
          f"p99 {pct(intervals,0.99):.2f}  max {max(intervals):.2f}")

    print("\n== bucket summary (ms) ==")
    print(f"{'bucket':<14}{'median':>9}{'mean':>9}{'p95':>9}{'p99':>9}{'max':>10}{'share%':>8}")
    total_mean = sum(intervals) / len(intervals)
    stats = {}
    for b in BUCKETS:
        s = summarize([r[b] for r in rows])
        stats[b] = s
        print(f"{b:<14}{s['median']:>9.2f}{s['mean']:>9.2f}{s['p95']:>9.2f}{s['p99']:>9.2f}"
              f"{s['max']:>10.2f}{100.0*s['mean']/total_mean:>8.1f}")

    print("\n== client parts (median ms) ==")
    for b in CLIENT_PARTS:
        s = summarize([r[b] for r in rows])
        print(f"{b:<14}{s['median']:>9.2f}  p95 {s['p95']:>7.2f}  max {s['max']:>8.2f}")

    print("\n== logic parts (ms) ==")
    for b in LOGIC_PARTS:
        s = summarize([r[b] for r in rows])
        print(f"{b:<14}{s['median']:>9.2f}  p95 {s['p95']:>7.2f}  p99 {s['p99']:>7.2f}  max {s['max']:>8.2f}")

    print(f"\n== slowest {args.top} frames ==")
    worst = sorted(rows, key=lambda r: -r["interval"])[: args.top]
    for r in worst:
        parts = ", ".join(f"{b}={r[b]:.1f}" for b in BUCKETS if r[b] >= 1.0)
        extra = []
        if r.get("slowest_update"):
            extra.append(f"slowUpdate={r['slowest_update']}/{r.get('slowest_update_obj','')} "
                         f"{r.get('slowest_update_us',0)/1000.0:.1f}ms")
        if r.get("destroyed"):
            extra.append(f"destroyed={int(r['destroyed'])}")
        if r.get("slowest_destroy"):
            extra.append(f"slowDestroy={r['slowest_destroy']} {r.get('slowest_destroy_us',0)/1000.0:.1f}ms")
        if r.get("spawned"):
            extra.append(f"spawned={int(r['spawned'])} spawn={r.get('spawn_ms',0):.1f}ms")
        if r.get("nukes"):
            extra.append(f"nukes={int(r['nukes'])}")
        print(f"  f{int(r['frame']):<6} interval={r['interval']:8.2f} | {parts}")
        if extra:
            print(f"         {'; '.join(extra)}")

    gaps = [r["gap"] for r in rows]
    print(f"\n== accounting ==")
    print(f"gap (interval - measured buckets): median {pct(gaps,0.5):.2f}  "
          f"p95 {pct(gaps,0.95):.2f}  max {max(gaps):.2f}")
    print(f"negative-gap frames (measurement overlap): {sum(1 for g in gaps if g < -0.5)}")

    if args.json:
        out = {
            "file": args.path,
            "rows": len(rows),
            "interval": summarize(intervals),
            "buckets": stats,
            "client_parts": {b: summarize([r[b] for r in rows]) for b in CLIENT_PARTS},
            "logic_parts": {b: summarize([r[b] for r in rows]) for b in LOGIC_PARTS},
            "gap": summarize(gaps),
            "slowest": [
                {k: r[k] for k in ["frame", "interval"] + BUCKETS if k in r}
                for r in worst
            ],
        }
        with open(args.json, "w") as f:
            json.dump(out, f, indent=2)
        print(f"\nwrote {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
