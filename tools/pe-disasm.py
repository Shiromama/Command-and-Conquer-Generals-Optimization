#!/usr/bin/env python3
"""Small PE disassembly helper for crash-address triage.

Reads a 32-bit PE image (e.g. the retail `game.dat`), maps virtual addresses to
file offsets via the section table, and disassembles a window around an address
with Capstone. Also scans .text for relative CALL/JMP references so a crash site
can be attributed to the function that owns it and to its callers.

Examples
    python tools/pe-disasm.py around "Command and Conquer Generals Zero Hour/game.dat" 0x81A7A5
    python tools/pe-disasm.py xref  "Command and Conquer Generals Zero Hour/game.dat" 0x81A780
    python tools/pe-disasm.py func  "Command and Conquer Generals Zero Hour/game.dat" 0x81A7A5
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

try:
    from capstone import CS_ARCH_X86, CS_MODE_32, Cs
except ImportError:  # pragma: no cover
    print("error: install capstone (python -m pip install --user capstone)", file=sys.stderr)
    raise SystemExit(2)

IMAGE_SCN_CNT_CODE = 0x00000020
IMAGE_SCN_MEM_EXECUTE = 0x20000000


class Pe:
    def __init__(self, path: Path):
        self.path = path
        self.data = path.read_bytes()
        if self.data[:2] != b"MZ":
            raise ValueError("not an MZ/PE file")
        e_lfanew = struct.unpack_from("<I", self.data, 0x3C)[0]
        if self.data[e_lfanew:e_lfanew + 4] != b"PE\0\0":
            raise ValueError("missing PE signature")
        coff = e_lfanew + 4
        machine, nsections, _, _, _, opt_size, _ = struct.unpack_from("<HHIIIHH", self.data, coff)
        opt = coff + 20
        magic = struct.unpack_from("<H", self.data, opt)[0]
        if magic == 0x10B:
            self.is64 = False
            self.image_base = struct.unpack_from("<I", self.data, opt + 28)[0]
        elif magic == 0x20B:
            self.is64 = True
            self.image_base = struct.unpack_from("<Q", self.data, opt + 24)[0]
        else:
            raise ValueError(f"unknown optional header magic 0x{magic:X}")
        self.machine = machine
        self.sections = []
        sec = opt + opt_size
        for i in range(nsections):
            raw = self.data[sec + i * 40: sec + (i + 1) * 40]
            name = raw[:8].rstrip(b"\0").decode("latin-1")
            vsize, vaddr, rsize, roff = struct.unpack_from("<IIII", raw, 8)
            chars = struct.unpack_from("<I", raw, 36)[0]
            self.sections.append({
                "name": name, "vaddr": vaddr, "vsize": vsize,
                "raw_offset": roff, "raw_size": rsize, "chars": chars,
            })

    def rva_to_off(self, rva: int) -> int | None:
        for s in self.sections:
            span = max(s["vsize"], s["raw_size"])
            if s["vaddr"] <= rva < s["vaddr"] + span:
                delta = rva - s["vaddr"]
                if delta >= s["raw_size"]:
                    return None
                return s["raw_offset"] + delta
        return None

    def va_to_off(self, va: int) -> int | None:
        return self.rva_to_off(va - self.image_base)

    def off_to_va(self, off: int) -> int | None:
        for s in self.sections:
            if s["raw_offset"] <= off < s["raw_offset"] + s["raw_size"]:
                return self.image_base + s["vaddr"] + (off - s["raw_offset"])
        return None

    def text(self):
        for s in self.sections:
            if s["chars"] & IMAGE_SCN_CNT_CODE or s["name"] == ".text":
                return s
        raise ValueError("no .text section")


def disassembler() -> Cs:
    md = Cs(CS_ARCH_X86, CS_MODE_32)
    md.detail = False
    return md


def cmd_around(pe: Pe, args) -> int:
    va = args.address
    off = pe.va_to_off(va - args.before)
    if off is None:
        print(f"error: 0x{va:X} is not mapped", file=sys.stderr)
        return 2
    code = pe.data[off: off + args.before + args.after]
    md = disassembler()
    start = va - args.before
    print(f"; {pe.path.name} imagebase=0x{pe.image_base:X} va=0x{va:X} file_off=0x{off:X}")
    for insn in md.disasm(code, start):
        marker = ">>>" if insn.address == va else "   "
        print(f"{marker} 0x{insn.address:08X}  {insn.bytes.hex():<20} {insn.mnemonic:<8} {insn.op_str}")
    return 0


def cmd_xref(pe: Pe, args) -> int:
    target = args.target
    text = pe.text()
    blob = pe.data[text["raw_offset"]: text["raw_offset"] + text["raw_size"]]
    base_va = pe.image_base + text["vaddr"]
    hits = []
    for i in range(len(blob) - 5):
        if blob[i] in (0xE8, 0xE9):
            rel = struct.unpack_from("<i", blob, i + 1)[0]
            src = base_va + i
            dst = src + 5 + rel
            if dst == target:
                hits.append((src, blob[i]))
    print(f"; {len(hits)} direct reference(s) to 0x{target:X}")
    for src, opcode in hits:
        print(f"  call_from=0x{src:08X} opcode=0x{opcode:02X}")
    if not hits:
        # also look for absolute addresses used as data (vtables, pointers)
        needle = struct.pack("<I", target)
        idx = 0
        found = 0
        while True:
            idx = pe.data.find(needle, idx)
            if idx < 0:
                break
            va = pe.off_to_va(idx)
            if va is not None:
                print(f"  data_ptr_at=0x{va:08X}")
                found += 1
                if found >= 20:
                    break
            idx += 4
    return 0


def cmd_func(pe: Pe, args) -> int:
    """Heuristic: walk back for alignment padding / prologue to find function start."""
    va = args.address
    off = pe.va_to_off(va)
    if off is None:
        print("error: unmapped address", file=sys.stderr)
        return 2
    start = off
    lo = max(0, off - args.max_back)
    # classic MSVC prologues
    prologues = (b"\x55\x8b\xec", b"\x53\x8b\xdc", b"\x56\x8b\xf4", b"\x6a\xff")
    best = None
    for i in range(off - 3, lo - 1, -1):
        if any(pe.data.startswith(p, i) for p in prologues):
            best = i
            break
    if best is None:
        print("; no prologue found; falling back to padding scan")
        for i in range(off-1, lo-1, -1):
            if pe.data[i] in (0xCC, 0x90):
                best = i + 1
                break
    if best is None:
        print("; function start not found")
        return 1
    fva = pe.off_to_va(best)
    print(f"; candidate function start 0x{fva:08X} (file 0x{best:X})")
    md = disassembler()
    for insn in md.disasm(pe.data[best: off + 64], fva):
        marker = ">>>" if insn.address == va else "   "
        print(f"{marker} 0x{insn.address:08X}  {insn.bytes.hex():<20} {insn.mnemonic:<8} {insn.op_str}")
        if insn.mnemonic == "ret":
            break
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("around", help="disassemble around an address")
    p.add_argument("pe")
    p.add_argument("address", type=lambda s: int(s, 0))
    p.add_argument("--before", type=int, default=96)
    p.add_argument("--after", type=int, default=160)
    p.set_defaults(func=cmd_around)

    p = sub.add_parser("xref", help="find code/data references to an address")
    p.add_argument("pe")
    p.add_argument("target", type=lambda s: int(s, 0))
    p.set_defaults(func=cmd_xref)

    p = sub.add_parser("func", help="guess containing function and disassemble it")
    p.add_argument("pe")
    p.add_argument("address", type=lambda s: int(s, 0))
    p.add_argument("--max-back", type=int, default=0x400)
    p.set_defaults(func=cmd_func)

    args = parser.parse_args(argv)
    pe = Pe(Path(args.pe))
    return int(args.func(pe, args))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
