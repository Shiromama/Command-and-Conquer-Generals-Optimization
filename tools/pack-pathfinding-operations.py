"""Pack completed diagnostic queue requests into a portable offline replay stream."""
import argparse
import csv
import hashlib
import json
import io
import struct
from collections import defaultdict
from pathlib import Path

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('source',type=Path)
parser.add_argument('output',type=Path)
args=parser.parse_args()
requests=defaultdict(list)
ended=set()
raw=args.source.read_bytes()
trailing_bytes=0
if raw and not raw.endswith(b'\n'):
    cut=raw.rfind(b'\n')+1
    trailing_bytes=len(raw)-cut
    raw=raw[:cut]
with io.StringIO(raw.decode('ascii'),newline='') as f:
    for row in csv.DictReader(f):
        if any(row.get(key) in (None,'') for key in ['request','op','cell','cost']) or None in row:
            raise ValueError(f'Malformed interior record: {row}')
        request=int(row['request']); op=row['op']; cell=int(row['cell']); cost=int(row['cost'])
        if op not in 'BIRHE': raise ValueError(f'Unknown operation {op}')
        if op in 'IRH' and not cell: raise ValueError('Missing cell identity in queue trace')
        requests[request].append((op,cell,cost))
        if op=='E': ended.add(request)
node_ids={}
events=[]
counts=defaultdict(int)
for request in sorted(ended):
    rows=requests[request]
    if rows[0][0]!='B' or rows[-1][0]!='E': raise ValueError(f'Incomplete scope {request}')
    for op,cell,cost in rows:
        if cell: node=node_ids.setdefault(cell,len(node_ids))
        else: node=0
        events.append(('BIRHE'.index(op),node,cost))
        counts[op]+=1
with args.output.open('wb') as f:
    f.write(struct.pack('<4sIII',b'PFQ1',len(node_ids),len(events),len(ended)))
    for event in events: f.write(struct.pack('<III',*event))
report=dict(source=str(args.source),sha256=hashlib.sha256(args.source.read_bytes()).hexdigest(),
            truncated_tail_bytes=trailing_bytes,completed_requests=len(ended),incomplete_requests=len(requests)-len(ended),
            nodes=len(node_ids),events=len(events),operations=dict(counts),
            semantics='Requests grouped independently; stable FIFO ties; R is arbitrary removal, H is observed head, B/E scope boundaries. No game algorithm changes.')
args.output.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report))
