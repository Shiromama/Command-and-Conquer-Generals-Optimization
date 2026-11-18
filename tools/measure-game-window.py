"""Read-only native-window assertions for the alpha smoke test; does not send UI input."""
import argparse,ctypes,json
from ctypes import wintypes as w
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--exe',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
u=ctypes.WinDLL('user32',use_last_error=True);k=ctypes.WinDLL('kernel32',use_last_error=True)
u.SetProcessDPIAware()
k.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD];k.OpenProcess.restype=w.HANDLE
k.QueryFullProcessImageNameW.argtypes=[w.HANDLE,w.DWORD,w.LPWSTR,ctypes.POINTER(w.DWORD)]
k.CloseHandle.argtypes=[w.HANDLE]
u.GetClassNameW.argtypes=[w.HWND,w.LPWSTR,ctypes.c_int]
u.GetWindowThreadProcessId.argtypes=[w.HWND,ctypes.POINTER(w.DWORD)]
u.GetClientRect.argtypes=[w.HWND,ctypes.POINTER(w.RECT)]
u.GetWindowRect.argtypes=[w.HWND,ctypes.POINTER(w.RECT)]
u.GetWindowLongW.argtypes=[w.HWND,ctypes.c_int]
u.GetDpiForWindow.argtypes=[w.HWND];u.GetDpiForWindow.restype=w.UINT
def normal(p):return str(p).removeprefix('\\\\?\\').lower()
found=[]
@ctypes.WINFUNCTYPE(w.BOOL,w.HWND,w.LPARAM)
def visit(hwnd,_):
    cls=ctypes.create_unicode_buffer(64);u.GetClassNameW(hwnd,cls,64)
    if cls.value!='Game Window':return True
    pid=w.DWORD();u.GetWindowThreadProcessId(hwnd,ctypes.byref(pid));process=k.OpenProcess(0x1000,False,pid.value)
    if not process:return True
    buf=ctypes.create_unicode_buffer(32768);size=w.DWORD(len(buf))
    ok=k.QueryFullProcessImageNameW(process,0,buf,ctypes.byref(size));k.CloseHandle(process)
    if ok and normal(buf.value)==normal(args.exe.resolve()):
        client=w.RECT();outer=w.RECT();assert u.GetClientRect(hwnd,ctypes.byref(client));assert u.GetWindowRect(hwnd,ctypes.byref(outer))
        found.append(dict(pid=pid.value,exe=buf.value,client_width=client.right-client.left,client_height=client.bottom-client.top,outer=[outer.left,outer.top,outer.right,outer.bottom],dpi=u.GetDpiForWindow(hwnd),caption=bool(u.GetWindowLongW(hwnd,-16)&0x00c00000)))
    return True
u.EnumWindows(visit,0)
assert len(found)==1,found
record=found[0];assert (record['client_width'],record['client_height'])==(1920,1080),record
assert record['outer']==[0,0,1920,1080] and not record['caption'],record
args.output.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print('PASS: exact alpha process, physical client 1920x1080, borderless outer [0,0,1920,1080]')
