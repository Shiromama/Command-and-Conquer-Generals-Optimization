"""Copy current patched engine source; eliminate test-environment entrypoints for the alpha build."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=root/'build/alpha-engine-source');args=parser.parse_args()
output=args.output.resolve()
if not output.is_relative_to((root/'build').resolve()) or output.exists():raise ValueError('Use a fresh build/ subdirectory')
source=root/'vendor/GeneralsGameCode'
subprocess.run(['git','apply','--reverse','--check',str(root/'engine/patches/current-engine.patch')],cwd=source,check=True)
shutil.copytree(source,output,ignore=shutil.ignore_patterns('.git','__pycache__'))
feature_patches=[root/'engine/patches'/name for name in ('guard-range.patch','model-fire-fx-recoil.patch','skirmish-speed-windowed.patch')]
patch_command=['git','--git-dir='+str(source/'.git'),'--work-tree='+str(output),'apply']
for feature_patch in feature_patches:
    subprocess.run(patch_command+['--check',str(feature_patch)],cwd=output,check=True)
    subprocess.run(patch_command+[str(feature_patch)],cwd=output,check=True)
lzhl=output/'cmake/lzhl.cmake'
lzhl.write_text(lzhl.read_text(encoding='utf-8').replace('FetchContent_Populate(lzhl DOWNLOAD_EXTRACT_TIMESTAMP','if(NOT EXISTS "${LZHL_DIR}/Lz.cpp")\nFetchContent_Populate(lzhl DOWNLOAD_EXTRACT_TIMESTAMP').replace('\nadd_library(liblzhl STATIC)','\nendif()\n\nadd_library(liblzhl STATIC)'),encoding='utf-8')
zlib=output/'cmake/zlib.cmake'
zlib.write_text(zlib.read_text(encoding='utf-8').replace('FetchContent_Populate(zlib DOWNLOAD_EXTRACT_TIMESTAMP','if(NOT EXISTS "${ZLIB_DIR}/zlib.h")\nFetchContent_Populate(zlib DOWNLOAD_EXTRACT_TIMESTAMP').replace('\nadd_library(libzlib STATIC)','\nendif()\n\nadd_library(libzlib STATIC)'),encoding='utf-8')
changes=[]
for p in sorted(output.rglob('*')):
    if not p.is_file() or p.suffix not in ['.cpp','.h','.inc']:continue
    content=p.read_bytes()
    # Only ZH_PF_HEAP troubleshooting remains; all diagnostics/spawners/experimental simulation toggles are inert.
    count=[0]
    def replace(m):
        if m.group(1)==b'ZH_PF_HEAP':return m.group(0)
        count[0]+=1;return b'static_cast<const char*>(nullptr)'
    updated=re.sub(rb'getenv\("(ZH_[A-Z0-9_]+)"\)',replace,content)
    updated=updated.replace(b'#include "PathfindHarness.inc"',b'// Alpha: synthetic pathfinding harness excluded.\n#include "Common/OptimizationPolicy.h"\nstatic void zhPathfindHarness(GameLogic*) {}\nstatic void zhPfCompleteObject(Object*) {}\nstatic void zhPfLogCrc(GameLogic*) {}')
    if updated!=content:
        p.write_bytes(updated);changes.append(dict(path=p.relative_to(output).as_posix(),disabled_environment_reads=count[0],sha256=hashlib.sha256(updated).hexdigest()))
manifest=dict(base_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip(),patch_sha256=hashlib.sha256((root/'engine/patches/current-engine.patch').read_bytes()).hexdigest(),changes=changes,policy='Only ZH_PF_HEAP remains readable; pathfinding harness include replaced by no-op. Release optimization eliminates constant-inactive diagnostic branches. Active development tree unchanged.')
manifest['cmake_sha256']={name:hashlib.sha256((output/'cmake'/name).read_bytes()).hexdigest() for name in ['lzhl.cmake','zlib.cmake']}
manifest['guard_patch_sha256']=hashlib.sha256(feature_patches[0].read_bytes()).hexdigest()
manifest['model_patch_sha256']=hashlib.sha256(feature_patches[1].read_bytes()).hexdigest()
manifest['patches']=[dict(name=p.name,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in feature_patches]
feature_files=[]
for feature_patch in feature_patches:
    feature_files+=re.findall(r'^\+\+\+ b/(.+)$',feature_patch.read_text(encoding='utf-8'),re.M)
manifest['feature_source_sha256']={name:hashlib.sha256((output/name).read_bytes()).hexdigest() for name in feature_files}
(output/'alpha-source.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(f'PASS: isolated alpha source; {len(changes)} files, {sum(x["disabled_environment_reads"] for x in changes)} diagnostic reads disabled')
