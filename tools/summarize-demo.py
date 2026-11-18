"""Summarize the 2026-11-17 demo: retail-equivalent vs shipping, stock and nuke scenes.

Usage: python tools/summarize-demo.py <root>

Expects stock-<cfg>-<i>/frames-run1.csv (benchmark-entity-heavy) and
nuke-<cfg>-<i>/perf.csv (benchmark-shockwave-attrib), cfg in {retail, ship}.
"""
import csv
import glob
import json
import math
import os
import statistics
import sys

root = sys.argv[1] if len(sys.argv) > 1 else r'artifacts\2026-11-17-demo-1000'


def pct(v, q):
    s = sorted(v)
    k = (len(s) - 1) * q
    lo, hi = int(math.floor(k)), int(math.ceil(k))
    return s[lo] if lo == hi else s[lo] + (s[hi] - s[lo]) * (k - lo)


def fps(ms):
    return 1000.0 / ms if ms else float('inf')


def read_frames(path):
    vals = []
    with open(path) as f:
        for r in csv.DictReader(f):
            try:
                v = float(r['frame_ms'])
            except (KeyError, ValueError):
                continue
            if v > 0:
                vals.append(v)
    return vals[30:]


def stats(v):
    med = pct(v, .5)
    return {'n': len(v), 'median': med, 'fps': fps(med),
            'p95': pct(v, .95), 'p95_fps': fps(pct(v, .95)),
            'p99': pct(v, .99), 'p99_fps': fps(pct(v, .99)), 'max': max(v)}


out = {}
for scene, pattern, filename in (
    ('stock', 'stock-*', 'frames-run1.csv'),
    ('nuke', 'nuke-*', 'perf.csv'),
):
    out[scene] = {}
    for cfg in ('retail', 'ship'):
        runs = {}
        for d in sorted(glob.glob(os.path.join(root, f'{pattern.split("*")[0]}{cfg}-*'))):
            p = os.path.join(d, filename)
            if not os.path.exists(p):
                continue
            v = read_frames(p)
            if v:
                runs[os.path.basename(d)] = stats(v)
        if runs:
            agg = {}
            for key in ('median', 'p95', 'p99'):
                agg[key] = statistics.mean(r[key] for r in runs.values())
                agg[key + '_fps'] = fps(agg[key])
            agg['runs'] = runs
            out[scene][cfg] = agg

print(f'{"scene":<7}{"config":<9}{"median":>9}{"FPS":>8}{"p95":>9}{"FPS":>8}{"p99":>9}{"FPS":>8}')
for scene in ('stock', 'nuke'):
    for cfg in ('retail', 'ship'):
        a = out[scene].get(cfg)
        if not a:
            print(f'{scene:<7}{cfg:<9}   (no data)')
            continue
        print(f'{scene:<7}{cfg:<9}{a["median"]:>9.2f}{a["median_fps"]:>8.1f}'
              f'{a["p95"]:>9.2f}{a["p95_fps"]:>8.1f}{a["p99"]:>9.2f}{a["p99_fps"]:>8.1f}')

print()
for scene in ('stock', 'nuke'):
    r, s = out[scene].get('retail'), out[scene].get('ship')
    if not r or not s:
        continue
    print(f'{scene}: median {r["median"]:.2f} -> {s["median"]:.2f} ms '
          f'({r["median_fps"]:.1f} -> {s["median_fps"]:.1f} FPS, {s["median_fps"] / r["median_fps"]:.2f}x), '
          f'p95 {r["p95"]:.2f} -> {s["p95"]:.2f} ms '
          f'({r["p95_fps"]:.1f} -> {s["p95_fps"]:.1f} FPS, {s["p95_fps"] / r["p95_fps"]:.2f}x)')

with open(os.path.join(root, 'summary.json'), 'w') as f:
    json.dump(out, f, indent=2)
print(f'\nwrote {os.path.join(root, "summary.json")}')
