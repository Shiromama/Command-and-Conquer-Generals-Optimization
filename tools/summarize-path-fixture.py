"""Summarize a T-120 path_bench artifact directory (read-only)."""
import argparse
import csv
import json
import statistics
from pathlib import Path


def read_csv(path: Path):
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8", errors="replace") as handle:
        return list(csv.DictReader(handle))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifact", type=Path)
    args = parser.parse_args()
    root = args.artifact.resolve()
    frames = read_csv(root / "pf-frame.csv")
    requests = read_csv(root / "requests.csv")
    result = json.loads((root / "result.json").read_text(encoding="utf-8")) if (root / "result.json").exists() else None
    run = json.loads((root / "run.json").read_text(encoding="utf-8-sig")) if (root / "run.json").exists() else None
    usec = [float(row["usec_total"]) for row in frames if row.get("usec_total")]
    expansions = [int(row["expansions_total"]) for row in frames if row.get("expansions_total")]
    summary = {
        "artifact": str(root),
        "status": result.get("status") if result else None,
        "cache_mismatches": result.get("cache_mismatches") if result else None,
        "frames": len(frames),
        "frame_first": int(frames[0]["frame"]) if frames else None,
        "frame_last": int(frames[-1]["frame"]) if frames else None,
        "requests_total": sum(int(row.get("requests", 0)) for row in frames),
        "request_rows": len(requests),
        "request_found": sum(1 for row in requests if row.get("found") == "1"),
        "expansions_total": sum(expansions),
        "usec_total_sum": round(sum(usec), 3),
        "usec_total_median": round(statistics.median(usec), 3) if usec else None,
        "usec_total_mean": round(statistics.mean(usec), 3) if usec else None,
        "usec_total_p95": round(sorted(usec)[int(len(usec) * 0.95) - 1], 3) if usec else None,
        "run_elapsed_seconds": run.get("elapsed_seconds") if run else None,
    }
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
