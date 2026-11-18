"""Validate T-022 workload evidence and compare deterministic prefixes across repetitions."""
import argparse
import collections
import json
import math
from pathlib import Path
from pathfinding_csv import rows


def percentile(values, q):
    values = sorted(values)
    if not values:
        return None
    k = (len(values)-1)*q
    lo, hi = math.floor(k), math.ceil(k)
    return values[lo]+(values[hi]-values[lo])*(k-lo)


def stats(values):
    return dict(n=len(values), median=percentile(values,.5), p95=percentile(values,.95),
                p99=percentile(values,.99), maximum=max(values) if values else None)


def first_difference(left, right, keys):
    for i, (a, b) in enumerate(zip(left, right)):
        for key in keys:
            if a[key] != b[key]:
                return dict(index=i, frame=a['frame'], column=key, left=a[key], right=b[key])
    if len(left) != len(right):
        return dict(index=min(len(left),len(right)), column='length', left=len(left), right=len(right))
    return None


def analyze(root):
    parameters=json.loads((root/'parameters.json').read_text(encoding='utf-8-sig'))
    expected=parameters['groups']*parameters['group_size']
    reports={}
    datasets={}
    for folder in sorted(root.glob('blockers-*-run-*')):
        spawn=rows(folder/'spawns.csv')
        units=[r for r in spawn if r['kind']=='unit']
        if len(units)!=expected:
            raise ValueError(f'{folder.name}: expected {expected} units, got {len(units)}')
        for row in units:
            if row['adjusted']!='1' or not (float(row['loX'])<=float(row['x'])<=float(row['hiX']) and float(row['loY'])<=float(row['y'])<=float(row['hiY'])):
                raise ValueError(f'{folder.name}: invalid spawn {row}')
        requests=rows(folder/'requests.csv')
        commands=rows(folder/'commands.csv')
        frames=rows(folder/'pathfinding-frames.csv')
        if set(r['phase'] for r in commands)!={'0','1','2','3'}:
            raise ValueError(f'{folder.name}: missing one of four command phases')
        # Compare only whole logic frames that occur in every repetition.
        last_frame=int(frames[-1]['frame'])
        active=[r for r in requests if int(r['frame'])>=90 and int(r['frame'])<=last_frame]
        logics={int(r['frame']):sum(float(v) for k,v in r.items() if k!='frame') for r in rows(folder/'logic.csv')}
        frame_steady=[r for r in frames if int(r['frame'])>=90]
        pf_us=sum(float(r['usec_total']) for r in frame_steady)
        pf_frames=[int(r['frame']) for r in frame_steady]
        logic_ms=sum(logics.get(f,0) for f in pf_frames)
        durations=rows(folder/'frames.csv')[300:]
        reports[folder.name]=dict(
            last_logic_frame=last_frame, spawned_units=len(units), requests=len(requests), steady_requests=len(active),
            kinds=dict(collections.Counter(r['kind'] for r in active)),
            fallback=dict(collections.Counter(r['fallback'] for r in active)),
            max_open=stats([int(r['maxOpen']) for r in active]),
            expansions=stats([int(r['expansions']) for r in active]),
            request_usec=stats([float(r['usec']) for r in active]),
            pathfinding_frame_usec=stats([float(r['usec_total']) for r in frame_steady]),
            render_frame_ms=stats([float(r['frame_ms']) for r in durations]),
            pf_usec_total=pf_us, recorded_logic_ms=logic_ms,
            whole_update_usec=sum(float(r.get('update_usec',0)) for r in frame_steady),
            whole_update_share=(pf_us/sum(float(r['update_usec']) for r in frame_steady)) if frame_steady and 'update_usec' in frame_steady[0] else None,
            pf_to_recorded_logic_ratio=pf_us/(logic_ms*1000) if logic_ms else None,
            queue_over_32=sum(int(r['maxOpen'])>32 for r in active),
            found=sum(int(r['found']) for r in active))
        datasets[folder.name]=(requests,commands,last_frame)
    comparisons=[]
    for blockers in parameters['blockers']:
        names=sorted(n for n in datasets if n.startswith(f'blockers-{blockers}-'))
        if len(names)!=parameters['runs']:
            raise ValueError(f'blockers {blockers}: expected {parameters["runs"]} runs, got {len(names)}')
        cutoff=min(datasets[n][2] for n in names)
        first=names[0]
        for name in names[1:]:
            a,b=datasets[first],datasets[name]
            req_a=[r for r in a[0] if int(r['frame'])<=cutoff]
            req_b=[r for r in b[0] if int(r['frame'])<=cutoff]
            cmd_a=[r for r in a[1] if int(r['frame'])<=cutoff]
            cmd_b=[r for r in b[1] if int(r['frame'])<=cutoff]
            comparisons.append(dict(left=first,right=name,through_frame=cutoff,
                commands_compared=len(cmd_a),requests_compared=len(req_a),
                first_command_difference=first_difference(cmd_a,cmd_b,list(cmd_a[0])),
                first_request_difference=first_difference(req_a,req_b,[k for k in req_a[0] if k!='usec'])))
    return dict(parameters=parameters,runs=reports,comparisons=comparisons,
        limits=['Raw usec includes observer overhead; no speedup is inferred from baseline runs.',
                'The legacy logic phase CSV excludes harness command issuance and outer update overhead; its ratio is not whole-update CPU share.',
                'Four command phases are exercised, but phase 1 is a convergence target, not a geometrically certified choke. Phase 2 is a structure-footprint target only with blockers enabled.'])


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    report=analyze(args.root)
    output=json.dumps(report,indent=2)+'\n'
    if args.output: args.output.write_text(output,encoding='utf-8')
    else: print(output,end='')
