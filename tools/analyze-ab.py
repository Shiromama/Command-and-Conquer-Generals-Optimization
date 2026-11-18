"""Analyse a two-variant, alternating A/B artifact set.

Usage: python analyze-ab.py <root> <label>

Expects subfolders named A-1, B-1, A-2, B-2, ... each holding frames-run1.csv
(written by tools/benchmark-entity-heavy.ps1). Drops the first 30 frames of each
run, then reports median/p95/p99 in ms and FPS for each variant and the delta.
"""
import csv, glob, json, math, os, statistics, sys

root = sys.argv[1]
label = sys.argv[2] if len(sys.argv) > 2 else ""


def pct(v, q):
    s = sorted(v)
    k = (len(s) - 1) * q
    lo, hi = int(math.floor(k)), int(math.ceil(k))
    return s[lo] if lo == hi else s[lo] + (s[hi] - s[lo]) * (k - lo)


def fps(ms):
    return 1000.0 / ms if ms else float("inf")


def read_ms(path):
    vals = []
    with open(path) as f:
        for r in csv.DictReader(f):
            try:
                v = float(r["frame_ms"])
            except (KeyError, ValueError):
                continue
            if v > 0:
                vals.append(v)
    return vals[30:]


def stats(v):
    if not v:
        return None
    med = pct(v, .5)
    return {"n": len(v), "median": med, "fps": fps(med),
            "p95": pct(v, .95), "p95_fps": fps(pct(v, .95)),
            "p99": pct(v, .99), "p99_fps": fps(pct(v, .99)),
            "max": max(v)}


runs = {}
for d in sorted(glob.glob(os.path.join(root, "*"))):
    p = os.path.join(d, "frames-run1.csv")
    if not os.path.isdir(d) or not os.path.exists(p):
        continue
    runs[os.path.basename(d)] = stats(read_ms(p))

print(f"{'run':<7}{'n':>6}{'median':>9}{'FPS':>8}{'p95':>9}{'p95FPS':>8}{'p99':>9}{'p99FPS':>8}{'max':>9}")
for tag, s in runs.items():
    print(f"{tag:<7}{s['n']:>6}{s['median']:>9.2f}{s['fps']:>8.1f}{s['p95']:>9.2f}"
          f"{s['p95_fps']:>8.1f}{s['p99']:>9.2f}{s['p99_fps']:>8.1f}{s['max']:>9.1f}")


def group(prefix):
    tags = [t for t in runs if t.startswith(prefix)]
    if not tags:
        return None
    out = {}
    for k in ("median", "p95", "p99", "max"):
        out[k] = round(statistics.mean(runs[t][k] for t in tags), 3)
    out["median_fps"] = fps(out["median"])
    out["p95_fps"] = fps(out["p95"])
    out["p99_fps"] = fps(out["p99"])
    out["runs"] = tags
    return out


a, b = group("A-"), group("B-")
print("\n== A/B (mean of per-run statistics) ==")
if a and b:
    for key, name in (("median", "median"), ("p95", "p95"), ("p99", "p99"), ("max", "max")):
        av, bv = a[key], b[key]
        note = f"  ({fps(av):.1f} -> {fps(bv):.1f} FPS)" if key != "max" else ""
        print(f"{name:<8}{av:>9.2f} -> {bv:>9.2f} ms   {100.0 * (bv - av) / av:+6.1f}%{note}")
else:
    print("incomplete")

with open(os.path.join(root, "summary.json"), "w") as f:
    json.dump({"label": label, "runs": runs, "A": a, "B": b}, f, indent=2)
print(f"\nwrote {os.path.join(root, 'summary.json')}")
