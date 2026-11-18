"""Record exact local compatibility profiles; hashes only, never package game data."""
import hashlib,json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()
def scan(base):
    result={}
    for p in sorted(base.rglob('*')):
        if not p.is_file():continue
        rel=p.relative_to(base).as_posix().lower()
        if rel.startswith(('data/','maps/')) or p.suffix.lower() in ['.big','.gib','.scb','.dll','.exe','.asi'] or rel in ['game.dat','shockwave_lnchr.dat']:result[rel]=sha(p)
    return result
stock=root/'game/baseline-pristine'
shock=root/'Command and Conquer Generals Zero Hour - Shockwave'
profiles=[dict(id='zh104-local-reference-20261114',description='Exact local Zero Hour 1.04 reference including its existing UI archives; not every vanilla retail distribution.',files=scan(stock),materialize=[])]
files=scan(shock);mapping=[]
for line in (shock/'Shockwave_Lnchr.dat').read_text(encoding='utf-8-sig').splitlines():
    m=re.fullmatch(r'\s*(\S.*?)\s+>\s+(\S.*?)\s*',line)
    if not m:continue
    original_source,original_target=[s.strip().replace('\\','/') for s in m.groups()]
    source,target=original_source.lower(),original_target.lower()
    if source in ['install_final.bmp','install_final_shw.bmp']:continue
    archive='/' not in source+target and source.endswith('.gib') and target.endswith('.big')
    script=source in ['data/scripts/multiplayerscripts.scb','data/scripts/scripts.ini','data/scripts/skirmishscripts.scb'] and target==source.rsplit('.',1)[0]+'.bcs'
    if not archive and not script:raise ValueError('Unsupported launcher mapping')
    if source not in files:raise ValueError('Missing mod source: '+source)
    mapping.append({'from':original_source,'to':original_target,'remove_source':script})
profiles.append(dict(id='shockwave-local-reference-20261115-raw',description='Exact tested local ShockWave snapshot, launcher archives not materialized.',files=files,materialize=mapping))
for profile,base in zip(profiles,[stock,shock]):
    names={p.name.lower():p.name for p in base.iterdir() if p.is_file()}
    profile['engine_path']=names['generals.exe'];profile['proxy_path']=names.get('d3d8.dll','d3d8.dll')
output=root/'patcher/catalog.json';output.write_text(json.dumps(profiles,indent=2)+'\n',encoding='utf-8')
print(f'Cataloged {len(profiles)} exact snapshots, {len(mapping)} mod mappings; no assets copied')
