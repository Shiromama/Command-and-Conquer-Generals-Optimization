# ISSUE-0063: Diagnostic uses unavailable D3DX8 disassembly declaration

- **Status:** Fixed
- **Severity:** Low
- **Date found:** 2026-11-17
- **Task:** T-035

## Evidence

[VERIFIED] build-screen-debug.log fails C3861: D3DXDisassembleShader is not declared by the D3DX8 headers. This affects a new diagnostic only; the previous runnable engine remains staged.

## Resolution / verification

Replace the unsupported direct call with raw translated-bytecode export and optional lookup of the existing loaded D3DX9 disassembler. No dependency download/install. Pending successful build and diagnostic run.

[VERIFIED] build-screen-debug-fixed.log exits0. calibration-screen-debug exports both translated screen-ps.bin and screen-ps.asm using an already loaded D3DX9 module. No download/install. The disassembly retains the intended phase/register instructions; diagnostic images identify the separate constant-range bug.
