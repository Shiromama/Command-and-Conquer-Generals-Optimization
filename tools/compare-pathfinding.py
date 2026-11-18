"""Compare list/heap runs on exactly matching logic frames, requests and engine CRC samples."""
import argparse
import json
import math
from pathlib import Path
from pathfinding_csv import rows, read as read_csv


def percentile(values,q):
    values=sorted(values)
    k=(len(values)-1)*q
    lo,hi=math.floor(k),math.ceil(k)
    return values[lo]+(values[hi]-values[lo])*(k-lo)


def first_difference(left,right,ignored=()):
    for index,(a,b) in enumerate(zip(left,right)):
        for column in a:
            if column not in ignored and a[column]!=b[column]:
                return dict(index=index,column=column,left=a[column],right=b[column])
    if len(left)!=len(right):return dict(column='row_count',left=len(left),right=len(right))
    return None


def compare(left,right,cutoff=None):
    parameters=[json.loads((folder/'parameters.json').read_text(encoding='utf-8-sig')) for folder in (left,right)]
    for key in ['exe_sha256','groups','group_size','interval','seed','width','height','blockers']:
        if parameters[0].get(key)!=parameters[1].get(key):raise ValueError(f'Unmatched input: {key}')
    data=[]
    queue_modes=[]
    for folder in (left,right):
        candidates=list(folder.glob('blockers-*-run-*'))
        if len(candidates)!=1:raise ValueError('Expected one scenario per comparison input')
        scenario=candidates[0]
        if (scenario/'operations.csv').exists():raise ValueError('Operation-heavy captures are not timing comparisons')
        requests,metadata=read_csv(scenario/'requests.csv')
        configured=parameters[len(data)].get('queue_mode','').lower()
        if configured=='default':
            if 'queue' not in metadata:raise ValueError('Default queue mode requires an actual queue annotation')
            actual=metadata['queue']
        else:
            actual=metadata.get('queue',configured)
            if actual!=configured:raise ValueError('Queue annotation disagrees with run parameters')
        queue_modes.append(actual)
        data.append(dict(frames=rows(scenario/'pathfinding-frames.csv'),requests=requests,crc=rows(scenario/'crc.csv'),commands=rows(scenario/'commands.csv')))
    if queue_modes!=['list','heap']:raise ValueError('Expected actual List then Heap queues')
    final=min(max(int(row['frame']) for row in item['frames']) for item in data)
    if cutoff is not None:final=min(final,cutoff)
    result=dict(through_frame=final,warmup_logic_frames=90,parameters=parameters)
    selected=[]
    for name,item in zip(['list','heap'],data):
        frames=[row for row in item['frames'] if 90<=int(row['frame'])<=final]
        req=[row for row in item['requests'] if 90<=int(row['frame'])<=final]
        crc=[row for row in item['crc'] if 90<=int(row['frame'])<=final]
        commands=[row for row in item['commands'] if 90<=int(row['frame'])<=final]
        if not frames or not req or not crc:raise ValueError('Insufficient matched evidence')
        updates=[float(row['update_usec']) for row in frames]
        pf=[float(row['usec_total']) for row in frames]
        result[name]=dict(frames=len(frames),requests=len(req),crc_samples=len(crc),
            pf_ms=sum(pf)/1000,update_ms=sum(updates)/1000,
            update_mean_usec=sum(updates)/len(updates),update_median_usec=percentile(updates,.5),
            update_p95_usec=percentile(updates,.95),update_p99_usec=percentile(updates,.99),
            pf_mean_usec=sum(pf)/len(pf),pf_p95_usec=percentile(pf,.95))
        selected.append(dict(frames=frames,requests=req,crc=crc,commands=commands))
    result['first_request_difference']=first_difference(selected[0]['requests'],selected[1]['requests'],['usec'])
    result['first_command_difference']=first_difference(selected[0]['commands'],selected[1]['commands'])
    result['first_crc_difference']=first_difference(selected[0]['crc'],selected[1]['crc'])
    result['first_frame_work_difference']=first_difference(selected[0]['frames'],selected[1]['frames'],['usec_total','usec_max','update_usec'])
    result['pf_ratio']=result['heap']['pf_ms']/result['list']['pf_ms']
    result['update_ratio']=result['heap']['update_ms']/result['list']['update_ms']
    result['parity']=not any(result[k] for k in ['first_request_difference','first_command_difference','first_crc_difference','first_frame_work_difference'])
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('list_run',type=Path)
    parser.add_argument('heap_run',type=Path)
    parser.add_argument('--through-frame',type=int)
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    result=compare(args.list_run,args.heap_run,args.through_frame)
    encoded=json.dumps(result,indent=2)+'\n'
    if args.output:args.output.write_text(encoded,encoding='utf-8')
    else:print(encoded,end='')
    if not result['parity']:raise SystemExit(2)
