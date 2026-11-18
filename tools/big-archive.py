#!/usr/bin/env python3
"""Minimal EA BIG archive reader for Zero Hour / ShockWave.

The `!Shw*.gib` files shipped by the ShockWave launcher are ordinary EA BIG
archives under a different extension (the launcher renames `.gib` -> `.big`
before starting `generals.exe`).  This tool reads that container format
without touching the installation:

    header  : "BIGF" | u32 total_size | u32 entry_count | u32 header_size
    entry   : u32 offset | u32 size | zero-terminated name

Field endianness is not uniform in the wild: every archive in this project stores
the total size as little-endian while the entry count and header size are
big-endian, so the reader auto-detects the size field against the real file
length instead of assuming one convention.

Commands
    info  <archive> [--json]          header + entry statistics
    list  <archive> [--filter GLOB]   one line per entry
    extract <archive> <outdir> [--filter GLOB] [--overwrite]
    cat   <archive> <name>            write one entry to stdout (binary-safe-ish)

Read-only by default: extraction only ever writes below <outdir>.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import struct
import sys
from dataclasses import dataclass
from pathlib import Path

MAGIC = b"BIGF"
MAX_ENTRIES = 1_000_000


@dataclass(frozen=True)
class Entry:
    name: str
    offset: int
    size: int


class BigError(RuntimeError):
    pass


def read_index(path: Path) -> tuple[int, list[Entry]]:
    with path.open("rb") as fh:
        header = fh.read(16)
        if len(header) != 16:
            raise BigError(f"{path}: file shorter than a BIG header")
        magic, raw_size, count, header_size = struct.unpack(">4sIII", header)
        if magic != MAGIC:
            raise BigError(f"{path}: bad magic {magic!r} (expected {MAGIC!r})")
        file_size = path.stat().st_size
        be_size = struct.unpack(">I", header[4:8])[0]
        le_size = struct.unpack("<I", header[4:8])[0]
        if be_size == file_size:
            total_size = be_size
        elif le_size == file_size:
            total_size = le_size
        else:
            raise BigError(
                f"{path}: header size {be_size} (BE) / {le_size} (LE) "
                f"matches neither actual {file_size}"
            )
        if count > MAX_ENTRIES:
            raise BigError(f"{path}: implausible entry count {count}")
        if header_size < 16 or header_size > file_size:
            raise BigError(f"{path}: implausible header size {header_size}")
        if header_size < 16 + 8 * count:
            raise BigError(
                f"{path}: header {header_size} cannot hold {count} directory entries"
            )

        table = fh.read(header_size - 16)
        if len(table) != header_size - 16:
            raise BigError(f"{path}: truncated directory")

    entries: list[Entry] = []
    pos = 0
    for i in range(count):
        if pos + 8 > len(table):
            raise BigError(f"{path}: directory ends inside entry {i}")
        offset, size = struct.unpack_from(">II", table, pos)
        pos += 8
        end = table.find(b"\x00", pos)
        if end < 0:
            raise BigError(f"{path}: unterminated name at entry {i}")
        try:
            name = table[pos:end].decode("latin-1")
        except UnicodeDecodeError:  # latin-1 never raises; kept for clarity
            name = table[pos:end].decode("latin-1", "replace")
        pos = end + 1
        entries.append(Entry(name.replace("\\", "/"), offset, size))

    # Integrity checks: entries must live inside the file and not overlap the header.
    for entry in entries:
        # PatchZH includes zero-byte marker records (e.g. Data/*) with no payload offset.
        # They do not reference the header; nonempty records must still pass all bounds checks.
        if entry.size == 0 and entry.offset == 0:
            continue
        if entry.offset + entry.size > file_size or entry.offset < header_size:
            raise BigError(
                f"{path}: entry {entry.name!r} out of range "
                f"(off={entry.offset}, size={entry.size}, file={file_size})"
            )

    declared = total_size
    del declared  # validated against the real file length above
    return header_size, entries


def match(entries: list[Entry], pattern: str | None) -> list[Entry]:
    if not pattern:
        return entries
    return [e for e in entries if fnmatch.fnmatch(e.name.lower(), pattern.lower())]


def cmd_info(args: argparse.Namespace) -> int:
    path = Path(args.archive)
    header_size, entries = read_index(path)
    total = sum(e.size for e in entries)
    data: dict[str, object] = {
        "archive": str(path),
        "bytes": path.stat().st_size,
        "header_bytes": header_size,
        "entries": len(entries),
        "payload_bytes": total,
        "payload_ratio": round(total / max(path.stat().st_size, 1), 4),
    }
    if args.json:
        print(json.dumps(data, indent=2))
        return 0
    for key, value in data.items():
        print(f"{key:16} {value}")

    dirs: dict[str, int] = {}
    for entry in entries:
        top = entry.name.split("/", 1)[0] if "/" in entry.name else "(root)"
        dirs[top] = dirs.get(top, 0) + 1
    print("\ntop-level directories:")
    for name, count in sorted(dirs.items(), key=lambda kv: (-kv[1], kv[0]))[:20]:
        print(f"  {count:6}  {name}")
    return 0


def cmd_list(args: argparse.Namespace) -> int:
    _, entries = read_index(Path(args.archive))
    for entry in match(entries, args.filter):
        print(f"{entry.size:10}  {entry.offset:10}  {entry.name}")
    return 0


def cmd_extract(args: argparse.Namespace) -> int:
    path = Path(args.archive)
    header_size, entries = read_index(path)
    selected = match(entries, args.filter)
    if not selected:
        print("no entries matched", file=sys.stderr)
        return 1
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    root = outdir.resolve()
    written = 0
    with path.open("rb") as fh:
        for entry in selected:
            target = (outdir / entry.name).resolve()
            if root not in target.parents and target != root:
                raise BigError(f"refusing to write outside {root}: {entry.name}")
            if target.exists() and not args.overwrite:
                print(f"skip (exists) {entry.name}", file=sys.stderr)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            fh.seek(entry.offset)
            remaining = entry.size
            with target.open("wb") as out:
                while remaining:
                    chunk = fh.read(min(remaining, 1 << 20))
                    if not chunk:
                        raise BigError(f"short read on {entry.name}")
                    out.write(chunk)
                    remaining -= len(chunk)
            written += 1
    print(f"wrote {written} file(s) to {outdir}")
    return 0


def cmd_cat(args: argparse.Namespace) -> int:
    path = Path(args.archive)
    _, entries = read_index(path)
    wanted = [e for e in entries if e.name.lower() == args.name.lower()]
    if not wanted:
        print(f"{args.name}: not in {path}", file=sys.stderr)
        return 1
    entry = wanted[0]
    with path.open("rb") as fh:
        fh.seek(entry.offset)
        sys.stdout.buffer.write(fh.read(entry.size))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p_info = sub.add_parser("info", help="header and entry statistics")
    p_info.add_argument("archive")
    p_info.add_argument("--json", action="store_true")
    p_info.set_defaults(func=cmd_info)

    p_list = sub.add_parser("list", help="list entries")
    p_list.add_argument("archive")
    p_list.add_argument("--filter", help="glob on the archive path, e.g. 'data/ini/*.ini'")
    p_list.set_defaults(func=cmd_list)

    p_extract = sub.add_parser("extract", help="extract entries")
    p_extract.add_argument("archive")
    p_extract.add_argument("outdir")
    p_extract.add_argument("--filter")
    p_extract.add_argument("--overwrite", action="store_true")
    p_extract.set_defaults(func=cmd_extract)

    p_cat = sub.add_parser("cat", help="write one entry to stdout")
    p_cat.add_argument("archive")
    p_cat.add_argument("name")
    p_cat.set_defaults(func=cmd_cat)

    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        return int(args.func(args))
    except (BigError, OSError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
