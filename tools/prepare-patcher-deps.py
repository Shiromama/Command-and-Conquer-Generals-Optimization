"""Restore a pinned offline directory source from an existing Cargo source cache (no network)."""
import argparse,hashlib,json,re,shutil
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--cache',type=Path,default=Path.home()/'.cargo/registry/src/index.crates.io-1949cf8c6b5b557f');parser.add_argument('--output',type=Path,default=root/'build/patcher-deps');args=parser.parse_args()
output=args.output.resolve()
if not output.is_relative_to((root/'build').resolve()):raise ValueError('Use a build/ subdirectory for dependency staging')
lock=(root/'patcher/Cargo.lock').read_text(encoding='utf-8')
checksums={}
for block in lock.split('[[package]]')[1:]:
    name=re.search(r'^name = "([^"]+)"',block,re.M);version=re.search(r'^version = "([^"]+)"',block,re.M);checksum=re.search(r'^checksum = "([0-9a-f]+)"',block,re.M)
    if name and version and checksum:checksums[f'{name.group(1)}-{version.group(1)}']=checksum.group(1)
for name,expected in json.loads((root/'patcher/dependencies.json').read_text(encoding='utf-8')).items():
    source=args.cache/name
    files={p.relative_to(source).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source.rglob('*')) if p.is_file() and p.name!='.cargo-checksum.json'}
    actual=hashlib.sha256(json.dumps(files,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    if actual!=expected:raise ValueError(f'Cached source differs: {name}')
    target=output/name;shutil.copytree(source,target,dirs_exist_ok=True)
    (target/'.cargo-checksum.json').write_text(json.dumps(dict(files=files,package=checksums.get(name)),separators=(',',':')),encoding='utf-8')
print('PASS: pinned offline Cargo directory source prepared')
