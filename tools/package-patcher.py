"""Build a singleplayer alpha package and its corresponding-source archive."""
import argparse,hashlib,json,re,shutil,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,default=root/'artifacts/2026-11-26-patcher-alpha-2/candidate-18/zh-patcher-0.1.0-alpha.2');parser.add_argument('--engine',type=Path,default=root/'build/t130-alpha-release/GeneralsMD/Release/generalszh.exe');parser.add_argument('--patcher',type=Path,default=root/'build/patcher-target/release/zh-patcher.exe');parser.add_argument('--source',type=Path,default=root/'build/t130-alpha-source');args=parser.parse_args()
output=args.output.resolve()
if not output.is_relative_to((root/'artifacts').resolve()) or output.exists():raise ValueError('Package output must be a fresh artifacts/ subdirectory')
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for data in iter(lambda:f.read(1024*1024),b''):h.update(data)
    return h.hexdigest()
engine=args.engine.resolve()
cli=args.patcher.resolve()
source=args.source.resolve()
feature_patches=['T-130-ally-cost-33.patch']
for required in [engine,cli,source/'alpha-source.json',root/'engine/patches/current-engine.patch',*(root/'engine/patches'/name for name in feature_patches)]:
    if not required.exists():raise ValueError(f'Missing packaging input: {required}')
source_manifest = json.loads((source/'alpha-source.json').read_text(encoding='utf-8'))
if source_manifest['patches'] != [
    dict(name=name, sha256=sha(root/'engine/patches'/name)) for name in feature_patches
]:
    raise ValueError('Prepared engine source does not match the feature patches')
resource_path = 'GeneralsMD/Code/Main/RTS.rc'
resource = source / resource_path
if source_manifest.get('public_resource_sha256') != {resource_path: sha(resource)}:
    raise ValueError('Prepare the alpha engine source with the public resource changes')

def check_binary_paths(path):
    data = path.read_bytes().lower()
    user_profile = re.compile(rb'[a-z]:[\\/]+(?:Users|Documents and Settings)[\\/]+', re.I)
    private_prefixes = {
        prefix.lower()
        for directory in (root, Path.home())
        for prefix in (str(directory), directory.as_posix())
    }
    for encoding in ('utf-8', 'utf-16le'):
        prefixes = [prefix.encode(encoding) for prefix in private_prefixes]
        if any(prefix in data for prefix in prefixes):
            raise ValueError(f'{path.name} contains private build paths. Rebuild with path remapping.')
    # Check both UTF-16 alignments even when a section begins at an odd offset.
    if any(user_profile.search(view) for view in (data, data[::2], data[1::2])):
        raise ValueError(f'{path.name} contains a user-profile path. Rebuild with path remapping.')

for binary in (engine, cli):
    check_binary_paths(binary)
output.mkdir(parents=True)
for src,name in [(engine,'engine.exe'),(cli,'zh-patcher.exe'),(root/'patcher/Menu.ps1','Menu.ps1'),(root/'patcher/Patcher.cmd','Patcher.cmd'),(root/'patcher/README.md','README.md'),(root/'ENGINE-LICENSE.md','ENGINE-LICENSE.md')]:shutil.copy2(src,output/name)
manifest=dict(schema=1,version='0.1.0-alpha.2',scope='Singleplayer alpha for recognized Zero Hour engine builds. Ships the 33% ally-cost pathfinding profile (gameplay trade); multiplayer uncertified.',compatible_runtime=True,engine_source='corresponding-source.zip',payload={'engine.exe':sha(output/'engine.exe')},profiles=json.loads((root/'patcher/catalog.json').read_text(encoding='utf-8')))
(output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
notices='''Zero Hour Patcher 0.1.0-alpha.2 — WINDOWS SINGLEPLAYER ALPHA

Patcher source: GPL-3.0-only (see PATCHER-LICENSE.txt).
Engine source: TheSuperHackers/GeneralsGameCode, pinned upstream commit in source/engine/alpha-source.json, with this project's patches and alpha preparation changes.
Electronic Arts' engine license is included verbatim as ENGINE-LICENSE.md, including its additional terms and attribution notices.
EA has not endorsed and does not support this product.
Corresponding patcher and prepared engine sources are in corresponding-source.zip.
Rust dependencies: serde/serde_core/serde_derive, serde_json, itoa, memchr, zmij, proc-macro2, quote, syn, unicode-ident. Their exact versions, sources and individual license/notice files are included under source/patcher/vendor/.
Engine dependency notices are collected in THIRD-PARTY-NOTICES.txt. Corresponding dependency source is included under source/engine-dependencies/. The pinned DirectX SDK subset is a separately supplied build prerequisite identified in SOURCE-BUILD.md.
Use your own compatible game installation. The package excludes retail game data, original executables, EA application artwork, Bink/Miles runtime DLLs, DirectX redistributables, GenTool and d3d8to9.
This build ships the 33% ally-congestion pathfinding profile. It changes group movement and battle outcomes versus the retail price. The 66% benchmark profile and the visual-trade switches are not included.
This alpha is unsigned. Multiplayer, existing saves and replays, individual community mods, and long-session compatibility still need validation.
'''
(output/'NOTICES.txt').write_text(notices,encoding='utf-8')
deps = root/'build/engine-vs-community/_deps'
zlib = root/'build/engine-vs-community/Core/Libraries/Source/Compression/_deps/zlib-1.1.4-src'
license_sections = [
    ('GameMath', (deps/'gamemath-src/LICENSE.md').read_bytes()),
    ('GameSpy', (deps/'gamespy-src/LICENSE').read_bytes()),
    ('stb', (deps/'stb-src/LICENSE').read_bytes()),
    ('LZHL', (deps/'lzhl-src/CompLibHeader/Lzhl.cpp').read_bytes().split(b'*/', 1)[0]+b'*/'),
    ('zlib', (zlib/'ZLib/zlib.h').read_bytes().split(b'*/', 1)[0]+b'*/'),
]
(output/'THIRD-PARTY-NOTICES.txt').write_bytes(
    b'\n\n'.join(name.encode('ascii')+b'\n\n'+license for name,license in license_sections)+b'\n'
)
(output/'PATCHER-LICENSE.txt').write_text('SPDX-License-Identifier: GPL-3.0-only\n\nThis patcher is licensed under version 3 of the GNU General Public License.\nThe GPL version 3 text appears in ENGINE-LICENSE.md; the engine additional terms apply to the engine.\n',encoding='utf-8')
source_build='''# Corresponding-source build

The archive preserves the prepared engine and patcher source for this alpha, pinned Cargo directory-source dependencies and engine dependency sources and notices. The build target is z_generals. Optional artwork, auxiliary media and proprietary runtime DLLs are excluded. Engine source is pinned by alpha-source.json, engine/patches/current-engine.patch and the feature patches applied by prepare-alpha-engine.py. The prepared engine bakes the 33% ally-cost default; the 66% benchmark profile and visual-trade switches are not shipped.

## Patcher (Windows x64, Rust 1.82)

From source/, with the bundled vendor directory:

    python tools/build-alpha-patcher.py

The build remaps the checkout and user profile and sets a filename-only PDB reference.
The binary appears at build/patcher-target/release/zh-patcher.exe. Debug builds alone contain transaction-interruption test hooks. Production builds ignore ZHPATCH_TEST_INTERRUPT.

## Engine (Windows x86)

Install Visual Studio 2022 Community with C++/ATL, CMake 3.31 and Windows SDK. Use the DirectX subset pinned in engine/cmake/dx8.cmake (7bddff8c01f5fb931c3cb73d4aa8e66d303d97bc from TheSuperHackers/min-dx8-sdk) as a separately supplied build dependency. It is not bundled. No source downloads happen when all source overrides are supplied.

Seed build/_deps/lzhl-src from engine-dependencies/lzhl-src and build/Core/Libraries/Source/Compression/_deps/zlib-1.1.4-src from engine-dependencies/zlib-1.1.4-src, preserving their subdirectories. Configure engine/ using Visual Studio 17 2022, Win32/v143 and the Community instance; set CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON, RTS_BUILD_OPTION_PROFILE=OFF, RTS_BUILD_OPTION_PROFILE_TRACY=OFF, FETCHCONTENT_FULLY_DISCONNECTED=ON. Set FETCHCONTENT_SOURCE_DIR_DX8 to your pinned SDK subset and FETCHCONTENT_SOURCE_DIR_GAMEMATH/GAMESPY/STB to the corresponding bundled engine-dependencies directories. Use /d1trimfile with the absolute engine source prefix and /PDBALTPATH:generalszh.pdb for the link. Build target z_generals, configuration Release, with one MSBuild worker (/m:1 /nodeReuse:false). The tracked tools/build-alpha-engine.ps1 gives the exact configure/build sequence used locally.

Rebuilt executable hashes can differ because of linker metadata and date macros (ISSUE-0020). The prepared alpha engine removes development-only diagnostic entry points and the upstream application icon. See alpha-source.json for the recorded source hashes.
'''
excluded_suffixes = {
    '.exe', '.dll', '.lib', '.obj', '.pdb', '.big', '.gib', '.bik', '.w3d',
    '.ico', '.cur', '.bmp', '.png', '.tga', '.jpg', '.jpeg', '.gif', '.wav',
    '.mp3', '.ogg', '.pgm', '.ppm', '.psd',
}
def archive_tree(z,base,prefix):
    for path in sorted(base.rglob('*')):
        if not path.is_file():continue
        rel=path.relative_to(base)
        if '.git' in rel.parts or '__pycache__' in rel.parts or 'target' in rel.parts:continue
        if path.suffix.lower() in excluded_suffixes:continue
        z.write(path,prefix+'/'+rel.as_posix())
with zipfile.ZipFile(output/'corresponding-source.zip','w',zipfile.ZIP_DEFLATED) as z:
    z.writestr('source/SOURCE-BUILD.md',source_build)
    archive_tree(z,root/'patcher','source/patcher')
    archive_tree(z,root/'build/patcher-deps','source/patcher/vendor')
    archive_tree(z,args.source.resolve(),'source/engine')
    for name in ['gamemath','gamespy','stb','lzhl']:
        archive_tree(z,deps/f'{name}-src',f'source/engine-dependencies/{name}-src')
    archive_tree(z,zlib,'source/engine-dependencies/zlib-1.1.4-src')
    for name in ['prepare-alpha-engine.py','prepare-patcher-deps.py','build-alpha-engine.ps1','build-alpha-patcher.py','catalog-patcher.py','package-patcher.py','test-patcher.py','test-skirmish-speed.py']:
        z.write(root/'tools'/name,'source/tools/'+name)
    z.write(root/'engine/patches/current-engine.patch','source/engine/patches/current-engine.patch')
    for name in feature_patches:
        z.write(root/'engine/patches'/name,'source/engine/patches/'+name)
    z.write(root/'vendor/sources.lock','source/vendor/sources.lock')
    z.write(output/'ENGINE-LICENSE.md','source/ENGINE-LICENSE.md')
    z.write(output/'PATCHER-LICENSE.txt','source/PATCHER-LICENSE.txt')
    z.write(output/'THIRD-PARTY-NOTICES.txt','source/THIRD-PARTY-NOTICES.txt')
(output/'SHA256SUMS.txt').write_text(''.join(sha(p)+'  '+p.name+'\n' for p in sorted(output.iterdir()) if p.is_file()),encoding='utf-8')
with zipfile.ZipFile(Path(str(output)+'.zip'),'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(output.iterdir()):z.write(p,output.name+'/'+p.name)
print(f'Packaged {output}; engine SHA256 {sha(output/"engine.exe")}')
