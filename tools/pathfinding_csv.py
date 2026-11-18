"""Strict pathfinding CSV reader with recognized queue metadata and crash-tail recovery."""
import csv
import io
import re


def read(path):
    data=path.read_bytes()
    if data and not data.endswith(b'\n'):
        data=data[:data.rfind(b'\n')+1]
    lines=[]
    metadata={}
    for line in data.decode('ascii').splitlines(keepends=True):
        if line.startswith('#'):
            match=re.fullmatch(r'# queue=(heap|list)\r?\n',line)
            if not match or len(lines)!=1 or 'queue' in metadata:
                raise ValueError(f'Invalid CSV metadata: {path}')
            metadata['queue']=match.group(1)
        else:
            lines.append(line)
    result=list(csv.DictReader(io.StringIO(''.join(lines),newline='')))
    if any(None in row or any(value is None for value in row.values()) for row in result):
        raise ValueError(f'Malformed interior CSV: {path}')
    return result,metadata


def rows(path):
    return read(path)[0]
