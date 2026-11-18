"""Regression checks for recognized queue metadata, strict rows and retained engine logs."""
import importlib.util,json,tempfile
from pathlib import Path
from pathfinding_csv import read,rows
root=Path(__file__).resolve().parents[1]
checks=0
with tempfile.TemporaryDirectory() as temp:
    path=Path(temp)/'requests.csv'
    for metadata in ['', '# queue=heap\n', '# queue=list\r\n']:
        path.write_bytes(('frame,kind\n'+metadata+'90,search\n').encode())
        data,info=read(path);assert data==[{'frame':'90','kind':'search'}]
        assert info==({'queue':metadata.split('=')[1].strip()} if metadata else {});checks+=1
    path.write_bytes(b'frame,kind\n# queue=heap\n90,search\n91,par')
    assert rows(path)==[{'frame':'90','kind':'search'}];checks+=1
    for invalid in ['# unknown=value\n90,search\n','# queue=other\n90,search\n','# queue=heap\n# queue=list\n90,search\n','90\n91,search\n','90,search,extra\n','90,search\n# queue=heap\n']:
        path.write_text('frame,kind\n'+invalid,encoding='ascii')
        try:rows(path)
        except ValueError:checks+=1
        else:raise AssertionError(invalid)
for name in ['analyze-pathfinding','compare-pathfinding']:
    spec=importlib.util.spec_from_file_location(name,root/'tools'/f'{name}.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    for log in (root/'artifacts/2026-11-17-heap-default').glob('**/requests.csv'):
        data=module.rows(log);assert data and all(int(row['frame'])>=0 for row in data);checks+=1
# Exercise comparison contracts with controlled metadata while preserving strict evidence checks.
spec=importlib.util.spec_from_file_location('comparison_contract',root/'tools/compare-pathfinding.py')
comparison=importlib.util.module_from_spec(spec);spec.loader.exec_module(comparison)
with tempfile.TemporaryDirectory() as temp:
    left,right=[Path(temp)/name for name in ['list','heap']]
    for folder,mode in [(left,'List'),(right,'Heap')]:
        folder.mkdir();(folder/'parameters.json').write_text(json.dumps(dict(exe_sha256='same',groups=1,group_size=1,interval=90,seed=1,width=1920,height=1080,blockers=[5],queue_mode=mode)))
        scenario=folder/'blockers-5-run-1';scenario.mkdir()
        (scenario/'requests.csv').write_text('frame,usec,kind\n# queue='+mode.lower()+'\n90,1,search\n')
        (scenario/'pathfinding-frames.csv').write_text('frame,usec_total,update_usec\n90,1,2\n')
        (scenario/'crc.csv').write_text('frame,crc\n90,1\n')
        (scenario/'commands.csv').write_text('frame,phase\n90,0\n')
    assert comparison.compare(left,right)['parity'];checks+=1
    meta=json.loads((right/'parameters.json').read_text());meta['queue_mode']='Default';(right/'parameters.json').write_text(json.dumps(meta))
    assert comparison.compare(left,right)['parity'];checks+=1
    (right/'blockers-5-run-1/requests.csv').write_text('frame,usec,kind\n90,1,search\n')
    try:comparison.compare(left,right)
    except ValueError:checks+=1
    else:raise AssertionError('Default must not silently guess its actual queue')
    meta['queue_mode']='Heap';(right/'parameters.json').write_text(json.dumps(meta))
    (right/'blockers-5-run-1/requests.csv').write_text('frame,usec,kind\n# queue=list\n90,1,search\n')
    try:comparison.compare(left,right)
    except ValueError:checks+=1
    else:raise AssertionError('Mismatched annotation must not become a valid A/B pair')
print(f'PASS: {checks} CSV format, rejection and retained-log checks')
