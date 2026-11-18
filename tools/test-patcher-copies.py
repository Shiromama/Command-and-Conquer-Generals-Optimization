"""Full-copy install/uninstall validation using real local data; this script never launches games."""
import argparse,hashlib,json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--package',type=Path,required=True);parser.add_argument('--prepare-only',action='store_true');parser.add_argument('--existing',action='store_true');parser.add_argument('--leave-installed',action='store_true');parser.add_argument('--suffix',choices=['v010','v010b'],default='v010b');args=parser.parse_args()
package=args.package.resolve();exe=package/'zh-patcher.exe'
output=root/'artifacts/2026-11-18-patcher-alpha';output.mkdir(parents=True,exist_ok=True)
def snapshot(base):
    result={}
    for p in sorted(base.rglob('*')):
        if not p.is_file() or '.zhpatch-alpha' in p.relative_to(base).parts:continue
        h=hashlib.sha256()
        with p.open('rb') as f:
            for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
        result[p.relative_to(base).as_posix()]=h.hexdigest()
    return result
receipts=[]
for name,source in [('stock',root/'game/baseline-pristine'),('shockwave',root/'Command and Conquer Generals Zero Hour - Shockwave')]:
    target=(root/f'game/alpha-{name}-{args.suffix}').resolve()
    if target.parent!=(root/'game').resolve() or target.name not in [f'alpha-stock-{args.suffix}',f'alpha-shockwave-{args.suffix}']:raise ValueError('Unsafe copy destination')
    if not args.existing:
        if target.exists():raise ValueError('Disposable target already exists; use --existing only after reviewing it')
        result=subprocess.run(['robocopy',str(source),str(target),'/E','/COPY:DAT','/DCOPY:T','/R:1','/W:1','/MT:8','/NFL','/NDL','/NP','/NJH','/NJS'],capture_output=True,text=True)
        if result.returncode>=8:raise RuntimeError(result.stdout+result.stderr)
        subprocess.run(['attrib','-R',str(target/'*'),'/S','/D'],check=True,capture_output=True)
        (output/f'{name}-before.json').write_text(json.dumps(snapshot(target),indent=2)+'\n',encoding='utf-8')
    if args.prepare_only:continue
    before=json.loads((output/f'{name}-before.json').read_text(encoding='utf-8'))
    commands=[]
    for action in ['inspect','install','verify','install','uninstall','uninstall']:
        command=[str(exe),action,'--game-dir',str(target)]
        result=subprocess.run(command,capture_output=True,text=True)
        commands.append(dict(action=action,exit_code=result.returncode,stdout=result.stdout,stderr=result.stderr))
        if result.returncode:
            (output/f'{name}-roundtrip-failure.json').write_text(json.dumps(commands,indent=2),encoding='utf-8')
            raise RuntimeError(result.stdout+result.stderr)
    after=snapshot(target)
    if before!=after:raise AssertionError(f'{name}: full-copy hashes differ after uninstall')
    receipts.append(dict(profile=name,original_files=len(before),full_tree_restored=True,commands=commands))
    print(f'PASS: {name}, all {len(before)} original file hashes restored',flush=True)
    if args.leave_installed:subprocess.run([str(exe),'install','--game-dir',str(target)],check=True)
(output/'real-copy-roundtrips.json').write_text(json.dumps(receipts,indent=2)+'\n',encoding='utf-8')
