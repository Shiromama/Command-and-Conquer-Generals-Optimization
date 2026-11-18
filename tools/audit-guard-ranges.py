"""Read-only stock guard-unit INI census; static base-range screening, not runtime certification."""
import argparse,copy,hashlib,importlib.util,json,re,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--game-dir',type=Path,default=root/'game/baseline-pristine');parser.add_argument('--output',type=Path,default=root/'artifacts/2026-11-18-guard-range');args=parser.parse_args()
out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
spec=importlib.util.spec_from_file_location('big_reader',root/'tools/big-archive.py');big=importlib.util.module_from_spec(spec);sys.modules[spec.name]=big;spec.loader.exec_module(big)
files={};provenance={}
for archive in sorted(args.game_dir.glob('*.big'),key=lambda p:p.name.lower()):
    _,entries=big.read_index(archive)
    with archive.open('rb') as f:
        for e in entries:
            name=e.name.lower()
            if not name.startswith('data/ini/') or not name.endswith('.ini') or name in files:continue
            f.seek(e.offset);data=f.read(e.size);files[name]=data.decode('latin-1');provenance[name]=dict(archive=archive.name,sha256=hashlib.sha256(data).hexdigest())
def clean(s):return '\n'.join(line.split(';',1)[0] for line in s.splitlines())
def named_blocks(text,kind):
    matches=list(re.finditer(r'(?im)^'+kind+r'\s+([^\s;]+)[^\r\n]*',text))
    for i,m in enumerate(matches):yield m.group(1),text[m.end():matches[i+1].start() if i+1<len(matches) else len(text)]
def properties(text,indent=None):
    pattern=(r'^'+(' '*indent if indent is not None else r'\s*')+r'([\w]+)\s*=\s*([^\r\n]+)')
    result={}
    for key,value in re.findall(pattern,text,re.M):result[key.lower()]=value.strip()
    return result
def number(value):
    match=re.match(r'[-+\d.]+',str(value))
    return float(match.group()) if match else None
weapons={};commandsets={};buttons={};objects={}
for name,text in files.items():
    text=clean(text)
    if name.endswith('/weapon.ini'):
        for key,body in named_blocks(text,'Weapon'):weapons[key.lower()]=properties(body)
    if name.endswith('/commandbutton.ini'):
        for key,body in named_blocks(text,'CommandButton'):buttons[key.lower()]=properties(body).get('command','').upper()
    if name.endswith('/commandset.ini'):
        for key,body in named_blocks(text,'CommandSet'):commandsets[key.lower()]=[v.lower() for v in re.findall(r'^\s*\d+\s*=\s*(\S+)',body,re.M)]
    if '/object/' not in name:continue
    headers=list(re.finditer(r'(?im)^(Object|ChildObject|ObjectReskin)[ \t]+(\S+)(?:[ \t]*:?[ \t]+([^\s;]+))?[^\r\n]*',text))
    for i,m in enumerate(headers):
        body=text[m.end():headers[i+1].start() if i+1<len(headers) else len(text)]
        sets=[]
        for ws in re.finditer(r'(?ms)^  WeaponSet\s*\n(.*?)^  End\s*$',body):
            fields=properties(ws.group(1));conditions=tuple(sorted(fields.get('conditions','none').upper().split()))
            slots={};automatic={}
            for slot,weapon in re.findall(r'^\s*Weapon\s*=\s*(PRIMARY|SECONDARY|TERTIARY)\s+(\S+)',ws.group(1),re.M|re.I):slots[slot.upper()]=weapon.lower()
            for slot,mask in re.findall(r'^\s*AutoChooseSources\s*=\s*(PRIMARY|SECONDARY|TERTIARY)\s+([^\r\n]+)',ws.group(1),re.M|re.I):
                words=mask.upper().split();automatic[slot.upper()]=('ALL' in words or 'FROM_AI' in words) and '-FROM_AI' not in words
            sets.append(dict(conditions=conditions,weapons=slots,automatic=automatic))
        objects[m.group(2).lower()]=dict(name=m.group(2),parent=m.group(3).lower() if m.group(3) else None,fields=properties(body,2),sets=sets,source=name)
resolved={}
def resolve(name,stack=()):
    if name in resolved:return resolved[name]
    if name in stack:raise ValueError('Object inheritance cycle: '+name)
    obj=objects[name];parent=obj['parent'];data=copy.deepcopy(resolve(parent,stack+(name,))) if parent in objects else dict(fields={},sets={})
    data['fields'].update(obj['fields'])
    for ws in obj['sets']:
        key=' '.join(ws['conditions']);existing=data['sets'].setdefault(key,dict(weapons={},automatic={}))
        existing['weapons'].update(ws['weapons']);existing['automatic'].update(ws['automatic'])
    resolved[name]=data;return data
ai=clean(files['data/ini/default/aidata.ini'])
ai_values=properties(ai);modifier=number(ai_values.get('guardinnermodifierhuman'))
override=properties(clean(files.get('data/ini/aidata.ini','')))
if 'guardinnermodifierhuman' in override:modifier=number(override['guardinnermodifierhuman'])
assert modifier is not None
rows=[]
for name,obj in sorted(objects.items()):
    data=resolve(name);fields=data['fields'];commands=commandsets.get(fields.get('commandset','').lower(),[])
    guards=[c for c in commands if buttons.get(c) in ['GUARD','GUARD_WITHOUT_PURSUIT','GUARD_FLYING_UNITS_ONLY']]
    if not guards:continue
    kind=fields.get('kindof','').upper().split()
    if not any(k in kind for k in ['INFANTRY','VEHICLE','AIRCRAFT']):continue
    vision=number(fields.get('visionrange'));legacy=vision*modifier if vision is not None else None
    enter=fields.get('isenteringguard','').lower()=='yes' or fields.get('enteringguard','').lower()=='yes'
    states=[]
    for conditions,ws in data['sets'].items():
        eligible=[];unknown=[]
        for slot,weapon in ws['weapons'].items():
            if weapon=='none' or not ws['automatic'].get(slot,True):continue
            w=weapons.get(weapon)
            if w is None:unknown.append(weapon);continue
            damage=number(w.get('primarydamage','0')) or 0;secondary=number(w.get('secondarydamage','0')) or 0
            damage_type=w.get('damagetype','').upper()
            if damage_type=='HACK' or (max(damage,secondary)<=0 and damage_type not in ['DEPLOY','DISARM']):continue
            attack=number(w.get('attackrange'))
            if attack is None:unknown.append(weapon);continue
            eligible.append(dict(slot=slot,weapon=weapon,base_attack_range=attack))
        maximum=max((w['base_attack_range'] for w in eligible),default=0)
        states.append(dict(conditions=conditions,eligible_base_weapons=eligible,unknown_range_weapons=unknown,base_weapon_range=maximum,screened_radius=max(legacy,maximum) if legacy is not None else None,base_floor_needed=legacy is not None and maximum>legacy))
    rows.append(dict(object=obj['name'],source=obj['source'],commandset=fields.get('commandset'),guard_buttons=guards,vision_range=vision,loaded_guard_modifier=modifier,legacy_guard_radius=legacy,kindof=kind,states=states,scope='Static nominal base ranges. Runtime helper additionally checks mode, enter/hijack, locks, ammo, anti masks and current bonuses.'))
summary=dict(object_definitions=len(objects),guard_unit_variants=len(rows),loaded_human_guard_modifier=modifier,base_floor_candidates=[r['object'] for r in rows if any(s['base_floor_needed'] for s in r['states'])],known_no_base_floor_needed=sum(r['vision_range'] is not None and not any(s['base_floor_needed'] for s in r['states']) for r in rows),unknown_vision=[r['object'] for r in rows if r['vision_range'] is None],unknown_weapon_ranges=sorted(set(w for r in rows for s in r['states'] for w in s['unknown_range_weapons'])),limitations='Static data screen, not a claim that every variant/upgrade was spawned or gameplay-certified; hidden/helper anti masks and runtime bonuses are enforced by actual engine resolver.')
(out/'stock-guard-audit.json').write_text(json.dumps(dict(summary=summary,units=rows,ini_provenance=provenance),indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,indent=2))
