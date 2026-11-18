"""Summarize the T-068 lock-profiling CSV written by the instrumented engine.

Usage: python tools/analyze-lock-log.py <zhlocks.csv>

Columns: row,elapsed_ms,pool_calls,pool_ms,str_calls,str_ms[,qpc_pair_us]
The QPC column is the measured cost of one timing pair; it is subtracted from each measured total
so the reported lock time is the lock, not the stopwatch. All values are cumulative.
"""
import csv
import sys


def main():
    path = sys.argv[1]
    rows = []
    with open(path) as f:
        reader = csv.DictReader(f)
        has_qpc = 'qpc_pair_us' in (reader.fieldnames or [])
        for r in reader:
            try:
                rec = {k: float(v) for k, v in r.items()}
            except (TypeError, ValueError):
                continue
            rows.append(rec)
    if len(rows) < 2:
        print('not enough rows')
        return 1

    a, b = rows[0], rows[-1]
    elapsed = b['elapsed_ms'] - a['elapsed_ms']
    frames = b['row'] - a['row']
    pool_calls = b['pool_calls'] - a['pool_calls']
    pool_ms = b['pool_ms'] - a['pool_ms']
    str_calls = b['str_calls'] - a['str_calls']
    str_ms = b['str_ms'] - a['str_ms']
    pair_us = b.get('qpc_pair_us', 0.0) if has_qpc else 0.0

    pool_over = pool_calls * pair_us / 1000.0
    str_over = str_calls * pair_us / 1000.0
    pool_true = max(0.0, pool_ms - pool_over)
    str_true = max(0.0, str_ms - str_over)

    fps = 1000.0 * frames / elapsed if elapsed else 0.0

    def share(x):
        return 100.0 * x / elapsed if elapsed else 0.0

    print(f'rows                 {len(rows)}  (frames {a["row"]:.0f}..{b["row"]:.0f})')
    print(f'elapsed              {elapsed:.1f} ms  ({fps:.1f} FPS over the window)')
    print(f'QPC pair cost        {pair_us:.4f} us  (measured in-process'
          + ('' if has_qpc else ', column absent') + ')')
    print(f'pool lock   measured {pool_ms:8.1f} ms = {share(pool_ms):5.2f}%   '
          f'minus overhead {pool_over:6.1f} ms -> {pool_true:6.1f} ms = {share(pool_true):5.2f}%   '
          f'{pool_calls / frames:6.1f} calls/frame')
    print(f'string lock measured {str_ms:8.1f} ms = {share(str_ms):5.2f}%   '
          f'minus overhead {str_over:6.1f} ms -> {str_true:6.1f} ms = {share(str_true):5.2f}%   '
          f'{str_calls / frames:6.1f} calls/frame')
    print(f'combined true        {pool_true + str_true:8.1f} ms = {share(pool_true + str_true):5.2f}% of elapsed')
    per_frame = (pool_true + str_true) * 1000.0 / frames if frames else 0.0
    print(f'combined per frame   {per_frame:.1f} us  ({100.0 * per_frame / (elapsed * 1000.0 / frames):.1f}% of a frame)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
