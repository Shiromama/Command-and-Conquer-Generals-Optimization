"""Run one announced development-only guard experiment in a verified mutable stock copy."""
import argparse,hashlib,json,os,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--label',choices=['control','fixed'],required=True);parser.add_argument('--run',default='2');parser.add_argument('--package',type=Path,required=True);args=parser.parse_args()
game=(root/'game/alpha-stock-v010b').resolve();assert game.parent==(root/'game').resolve() and game.name=='alpha-stock-v010b'
exe=game/'generals.exe';fixture=root/'build/alpha-engine-release/GeneralsMD/Release/generalszh.exe'
if not args.run.isdigit():raise ValueError('Numeric run label required')
out=root/'artifacts/2026-11-18-guard-range'/f'{args.label}-{args.run}';out.mkdir(parents=True,exist_ok=False)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def call(action):
    result=subprocess.run([str(args.package.resolve()/'zh-patcher.exe'),action,'--game-dir',str(game)],capture_output=True,text=True)
    (out/f'{action}.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    if result.returncode:raise RuntimeError(result.stdout+result.stderr)
call('verify')
before=exe.read_bytes();(out/'managed-engine-before.exe').write_bytes(before)
test_bytes=fixture.read_bytes();test_hash=hashlib.sha256(test_bytes).hexdigest()
def write(data):
    temporary=game/'guard-fixture-engine.tmp'
    if temporary.exists():raise ValueError('Reserved fixture temporary file already exists')
    with temporary.open('xb') as f:f.write(data);f.flush();os.fsync(f.fileno())
    os.replace(temporary,exe)
(out/'parameters.json').write_text(json.dumps(dict(label=args.label,fixture_sha256=test_hash,managed_engine_before_sha256=hashlib.sha256(before).hexdigest(),width=1920,height=1080,map='barrenbadlands',duration_after_window_seconds=80,source_mode=json.loads((root/'artifacts/2026-11-18-guard-range/fixture-source/current.json').read_text(encoding='utf-8'))),indent=2)+'\n',encoding='utf-8')
try:
    write(test_bytes)
    with (out/'launch.log').open('w',encoding='utf-8') as log:
        result=subprocess.run([str(root/'build/guard-fixture-launcher.exe'),str(game),str((out/'guard.csv').resolve())],stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:raise RuntimeError('Fixture failed; see launch.log')
finally:
    if sha(exe)!=test_hash:raise RuntimeError('Fixture executable changed unexpectedly; preserved for review')
    write(before)
    call('verify')
print('PASS: fixture finished; managed alpha executable restored and package verification passed')
