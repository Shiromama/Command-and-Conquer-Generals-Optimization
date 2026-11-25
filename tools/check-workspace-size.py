#!/usr/bin/env python3
"""Report workspace growth. Read-only and informational; no cap or gate.

The workspace is mostly ignored build trees, game copies and artifacts. This
checker makes growth visible so duplicate trees, copies and artifact runs are
easy to spot. It never fails or blocks work, and there is no fixed size limit.
"""

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GIB = 1024 ** 3


def scan(top):
    areas = {}
    area_files = {}
    subareas = {}
    files = 0
    total = 0
    skipped = 0
    largest = []
    for dirpath, dirnames, filenames in os.walk(ROOT, followlinks=False):
        dirnames.sort()
        for name in filenames:
            path = Path(dirpath, name)
            try:
                size = path.stat().st_size
            except OSError:
                skipped += 1
                continue
            try:
                parts = path.relative_to(ROOT).parts
            except ValueError:
                skipped += 1
                continue
            area = parts[0]
            sub = "/".join(parts[:2]) if len(parts) > 1 else area
            areas[area] = areas.get(area, 0) + size
            area_files[area] = area_files.get(area, 0) + 1
            subareas[sub] = subareas.get(sub, 0) + size
            files += 1
            total += size
            largest.append((size, str(path.relative_to(ROOT))))
    largest.sort(reverse=True)
    return {
        "root": str(ROOT),
        "total_bytes": total,
        "total_gib": total / GIB,
        "files": files,
        "skipped": skipped,
        "areas": [{"name": k, "bytes": v, "gib": v / GIB, "files": area_files[k]}
                  for k, v in sorted(areas.items(), key=lambda item: -item[1])],
        "subareas": [{"path": k, "bytes": v, "gib": v / GIB}
                     for k, v in sorted(subareas.items(), key=lambda item: -item[1])[:top]],
        "largest": [{"path": path, "bytes": size, "gib": size / GIB}
                    for size, path in largest[:top]],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--top", type=int, default=10, help="detail rows")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--warn-above", type=float, default=None,
                        help="optional visibility note in GiB; never fails")
    args = parser.parse_args()

    result = scan(args.top)
    result["warn_above_gib"] = args.warn_above
    note = bool(args.warn_above is not None and result["total_gib"] > args.warn_above)
    result["status"] = "NOTE" if note else "OK"

    if args.json:
        print(json.dumps(result, indent=2))
        return 0

    print(f"Workspace: {result['total_gib']:.2f} GiB "
          f"({result['files']:,} files, {result['skipped']} skipped) -> {result['status']}")
    print()
    print(f"{'area':<32} {'GiB':>9} {'files':>9}")
    for value in result["areas"]:
        print(f"{value['name']:<32} {value['gib']:>9.2f} {value['files']:>9}")
    print()
    print("Largest subareas:")
    for value in result["subareas"]:
        print(f"  {value['gib']:>8.2f} GiB  {value['path']}")
    print()
    print("Largest files:")
    for value in result["largest"]:
        print(f"  {value['gib']:>8.2f} GiB  {value['path']}")
    if note:
        print()
        print(f"Note: above the optional {args.warn_above:.2f} GiB visibility "
              "threshold. No cap is enforced; this is only a hint to look for "
              "duplicate trees, copies or artifact runs.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
