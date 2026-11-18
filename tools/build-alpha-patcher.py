"""Build the alpha patcher offline with portable paths in diagnostics."""

import argparse
import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--target-dir", type=Path, default=root / "build/patcher-target")
parser.add_argument("--debug", action="store_true")
args = parser.parse_args()

env = os.environ.copy()
flags = ["-Clink-arg=/PDBALTPATH:%_PDB%"]
for directory, label in [(Path.home(), "/build-user"), (root, "/source")]:
    flags.extend(
        f"--remap-path-prefix={prefix}={label}"
        for prefix in dict.fromkeys((str(directory), directory.as_posix()))
    )
env["CARGO_ENCODED_RUSTFLAGS"] = "\x1f".join(flags)
vendor_dir = root / "patcher/vendor"
if not vendor_dir.is_dir():
    vendor_dir = root / "build/patcher-deps"
vendor = json.dumps(vendor_dir.as_posix())
command = [
    "cargo", "build", "--locked", "--offline",
    "--target-dir", str(args.target_dir.resolve()),
    "--config", 'source.crates-io.replace-with="local-vendor"',
    "--config", f"source.local-vendor.directory={vendor}",
]
if not args.debug:
    command.append("--release")
subprocess.run(command, cwd=root / "patcher", env=env, check=True)
