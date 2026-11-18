"""Verify the rejected renderer archive in an isolated tree; never mutate active vendor files."""
import argparse,hashlib,json,re,subprocess
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
archive=root/'engine/rejected/T-035'
metadata=json.loads((archive/'source.json').read_text())
output=args.output.resolve()
if not output.is_relative_to((root/'artifacts').resolve()) or output==(root/'artifacts').resolve():
    raise ValueError('Output must be a fresh subdirectory of artifacts')
output.mkdir(parents=True,exist_ok=False)
stage=output/'source';stage.mkdir()
for name,digest in metadata['files'].items():
    assert hashlib.sha256((archive/name).read_bytes()).hexdigest()==digest,name
vendor=root/'vendor/GeneralsGameCode'
patches=[archive/'base-engine.patch',archive/'renderer-hooks.patch']
paths=set()
for patch in patches:
    paths.update(re.findall(r'^--- a/(.+)$',patch.read_text(encoding='utf-8'),re.M))
for name in paths:
    target=(stage/name).resolve()
    if not target.is_relative_to(stage):raise ValueError('Unsafe patch path')
    target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(subprocess.check_output(['git','show',metadata['vendor_base_commit']+':'+name],cwd=vendor))
commands=[]
git=['git','--git-dir='+str(vendor/'.git'),'--work-tree='+str(stage)]
for patch in patches:
    exclusions=['--exclude='+name for name in metadata['hook_paths']] if patch.name=='base-engine.patch' else []
    for check in [True,False]:
        cmd=git+['apply','--ignore-space-change']+(['--check'] if check else [])+exclusions+[str(patch)]
        result=subprocess.run(cmd,cwd=stage,capture_output=True,text=True)
        commands.append(dict(command=cmd,exit_code=result.returncode,output=result.stdout+result.stderr))
        if result.returncode:
            (output/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
            raise RuntimeError('Archive patch verification failed; see commands.json')
target=stage/metadata['prototype_path'];target.parent.mkdir(parents=True,exist_ok=True)
target.write_bytes((archive/'ShadowMapPrototype.inc').read_bytes())
files=[dict(path=f.relative_to(stage).as_posix(),sha256=hashlib.sha256(f.read_bytes()).hexdigest()) for f in sorted(stage.rglob('*')) if f.is_file()]
(output/'commands.json').write_text(json.dumps(commands,indent=2)+'\n',encoding='utf-8')
(output/'files.json').write_text(json.dumps(files,indent=2)+'\n',encoding='utf-8')
print(f'PASS: archived renderer reconstructed; {len(files)} affected files verified')
