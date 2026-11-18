#!/usr/bin/env python3
"""Self-contained Windows minidump triage (exception, modules, stack scan).

Parses the MINIDUMP structures directly - no third-party dependency - because
the engine writes its own minidumps on crash and those are the primary evidence
for the alt-tab fault. Prints:

  * the exception code/address and the faulting thread,
  * the module list (base, size, name),
  * for each thread, dwords on the stack that point into an executable module,
    i.e. candidate return addresses to resolve with a linker map.

Usage:
    python tools/minidump-triage.py <file.dmp> [--thread ID] [--depth N] [--module exe]
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

MDMP_SIGNATURE = 0x504D444D  # 'MDMP'

THREAD_LIST = 3
MODULE_LIST = 4
MEMORY_LIST = 5
EXCEPTION_STREAM = 6
MEMORY64_LIST = 9


class Dump:
    def __init__(self, path: Path):
        self.path = path
        self.data = path.read_bytes()
        if len(self.data) < 32:
            raise ValueError("file too small for a minidump header")
        sig, version, nstreams, dir_rva, _, _, _, _ = struct.unpack_from("<IIIIIIII", self.data, 0)
        if sig != MDMP_SIGNATURE:
            raise ValueError(f"bad minidump signature 0x{sig:08X}")
        self.streams: dict[int, tuple[int, int]] = {}
        for i in range(nstreams):
            stype, size, rva = struct.unpack_from("<III", self.data, dir_rva + i * 12)
            self.streams[stype] = (rva, size)
        self.memory64: list[tuple[int, int, int]] = []
        if MEMORY64_LIST in self.streams:
            rva, _ = self.streams[MEMORY64_LIST]
            count, base_rva = struct.unpack_from("<QQ", self.data, rva)
            off = base_rva
            for i in range(count):
                start, size = struct.unpack_from("<QQ", self.data, rva + 16 + i * 16)
                self.memory64.append((start, size, off))
                off += size
        self.memory_list: list[tuple[int, int, int]] = []
        if MEMORY_LIST in self.streams:
            rva, _ = self.streams[MEMORY_LIST]
            count = struct.unpack_from("<I", self.data, rva)[0]
            for i in range(count):
                start, size, drva = struct.unpack_from("<QII", self.data, rva + 4 + i * 16)
                self.memory_list.append((start, size, drva))

    def read_memory(self, start: int, size: int) -> bytes | None:
        for mstart, msize, moff in self.memory64:
            if mstart <= start and start + size <= mstart + msize:
                return self.data[moff + (start - mstart): moff + (start - mstart) + size]
        for mstart, msize, moff in self.memory_list:
            if mstart <= start and start + size <= mstart + msize:
                return self.data[moff + (start - mstart): moff + (start - mstart) + size]
        return None

    # -- streams ---------------------------------------------------------
    def modules(self) -> list[tuple[int, int, str]]:
        out = []
        if MODULE_LIST not in self.streams:
            return out
        rva, _ = self.streams[MODULE_LIST]
        count = struct.unpack_from("<I", self.data, rva)[0]
        for i in range(count):
            base, size, _checksum, _ts, name_rva = struct.unpack_from("<QIIII", self.data, rva + 4 + i * 108)
            nlen = struct.unpack_from("<I", self.data, name_rva)[0]
            name = self.data[name_rva + 4: name_rva + 4 + nlen].decode("utf-16-le", "replace")
            out.append((base, size, name))
        return out

    def threads(self):
        if THREAD_LIST not in self.streams:
            return []
        rva, _ = self.streams[THREAD_LIST]
        count = struct.unpack_from("<I", self.data, rva)[0]
        for i in range(count):
            base = rva + 4 + i * 48
            tid = struct.unpack_from("<I", self.data, base)[0]
            teb = struct.unpack_from("<Q", self.data, base + 16)[0]
            stack_start, stack_size, stack_rva = struct.unpack_from("<QII", self.data, base + 24)
            ctx_size, ctx_rva = struct.unpack_from("<II", self.data, base + 40)
            yield tid, teb, stack_start, stack_size, stack_rva, ctx_size, ctx_rva

    def exception(self):
        if EXCEPTION_STREAM not in self.streams:
            return None
        rva, _ = self.streams[EXCEPTION_STREAM]
        tid = struct.unpack_from("<I", self.data, rva)[0]
        er = rva + 8
        code, flags, _record, address, nparams = struct.unpack_from("<IIQQI", self.data, er)
        info = struct.unpack_from("<15Q", self.data, er + 32)
        return tid, code, flags, address, nparams, info


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("dump")
    ap.add_argument("--thread", type=int, default=None)
    ap.add_argument("--depth", type=int, default=1536, help="stack dwords to scan")
    ap.add_argument("--module", default=None, help="only report addresses in modules whose name contains this")
    args = ap.parse_args(argv)

    dump = Dump(Path(args.dump))
    modules = dump.modules()
    mods_by_base = sorted(modules)

    def locate(value: int):
        for base, size, name in mods_by_base:
            if base <= value < base + size:
                return base, size, name
        return None

    print(f"dump: {args.dump}")
    exc = dump.exception()
    if exc:
        tid, code, flags, address, nparams, info = exc
        print(f"exception: thread={tid} code=0x{code:08X} flags=0x{flags:X} address=0x{address:08X} params={nparams}")
        for i in range(min(nparams, 15)):
            print(f"  info[{i}] = 0x{info[i]:X}")
        hit = locate(address)
        if hit:
            print(f"  faulting module: {Path(hit[2]).name}+0x{address - hit[0]:X}")
        if code == 0xC0000005 and nparams >= 2:
            rw = "read" if info[0] == 0 else ("write" if info[0] == 1 else "execute")
            print(f"  access violation: {rw} at 0x{info[1]:X}")

    print("\nmodules:")
    for base, size, name in mods_by_base:
        print(f"  0x{base:08X}  0x{size:08X}  {name}")

    print("\nstack scan (candidate return addresses):")
    for tid, teb, start, size, rva, ctx_size, ctx_rva in dump.threads():
        if args.thread is not None and tid != args.thread:
            continue
        data = dump.read_memory(start, size)
        if data is None:
            if rva and rva + size <= len(dump.data):
                data = dump.data[rva:rva + size]
            else:
                print(f"\nthread {tid}: stack 0x{start:08X} size=0x{size:X} (not captured)")
                continue

        esp = None
        if ctx_rva and ctx_rva + 0xCC <= len(dump.data):
            ctx = dump.data[ctx_rva:ctx_rva + 0xCC]
            regs = struct.unpack_from("<8I", ctx, 0x9C)  # Edi,Esi,Ebx,Edx,Ecx,Eax,Ebp,Eip
            esp = struct.unpack_from("<I", ctx, 0xC4)[0]
            edi, esi, ebx, edx, ecx, eax, ebp, eip = regs
            print(f"\nthread {tid}: stack 0x{start:08X} size=0x{size:X} teb=0x{teb:08X}")
            print(f"  context: eip=0x{eip:08X} esp=0x{esp:08X} ebp=0x{ebp:08X} "
                  f"eax=0x{eax:08X} ebx=0x{ebx:08X} ecx=0x{ecx:08X} edx=0x{edx:08X} "
                  f"esi=0x{esi:08X} edi=0x{edi:08X}")
            hit = locate(eip)
            if hit and eip >= hit[0]:
                print(f"  eip module: {Path(hit[2]).name}+0x{eip - hit[0]:X}")
                try:
                    from capstone import CS_ARCH_X86, CS_MODE_32, Cs
                    module_path = Path(hit[2])
                    if module_path.exists():
                        blob = module_path.read_bytes()
                        # translate RVA -> file offset with the on-disk PE
                        import struct as _s
                        e_lfanew = _s.unpack_from("<I", blob, 0x3C)[0]
                        coff = e_lfanew + 4
                        nsec = _s.unpack_from("<H", blob, coff + 2)[0]
                        optsz = _s.unpack_from("<H", blob, coff + 16)[0]
                        opt = coff + 20
                        sec = opt + optsz
                        target = eip - hit[0]
                        off = None
                        for i in range(nsec):
                            raw = blob[sec + i * 40: sec + (i + 1) * 40]
                            vs, va, rs, ro = _s.unpack_from("<IIII", raw, 8)
                            if va <= target < va + max(vs, rs):
                                off = ro + (target - va)
                                break
                        if off is not None:
                            md = Cs(CS_ARCH_X86, CS_MODE_32)
                            print("  disassembly at eip:")
                            for insn in md.disasm(blob[off:off + 24], eip):
                                print(f"    0x{insn.address:08X}  {insn.bytes.hex():<18} {insn.mnemonic} {insn.op_str}")
                except Exception as exc:  # noqa: BLE001
                    print(f"  (disassembly unavailable: {exc})")
        else:
            print(f"\nthread {tid}: stack 0x{start:08X} size=0x{size:X} teb=0x{teb:08X}")

        if esp is not None and start <= esp < start + size:
            data = data[esp - start:]
        depth = min(args.depth, len(data) // 4)
        for i in range(depth):
            val = struct.unpack_from("<I", data, i * 4)[0]
            hit = locate(val)
            if not hit:
                continue
            base, msize, name = hit
            if not name.lower().endswith((".exe", ".dll")):
                continue
            if args.module and args.module.lower() not in name.lower():
                continue
            print(f"  esp+0x{i*4:04X}  0x{val:08X}  {Path(name).name}+0x{val-base:X}")
        if args.thread is not None:
            break
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
