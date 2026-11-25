"""Black-box the actual Windows patcher. Synthetic fixtures never launch the game."""
import argparse, hashlib, json, os, pathlib, stat, subprocess, tempfile, unittest, zipfile

ROOT=pathlib.Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--exe',type=pathlib.Path,default=ROOT/'build/patcher-target/debug/zh-patcher.exe')
parser.add_argument('--production',action='store_true',help='Skip debug-only interruption hooks; verify they are absent instead')
args,remaining=parser.parse_known_args()
EXE=args.exe.resolve()
def digest(data):return hashlib.sha256(data).hexdigest()

class Transactions(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='t080-tests-',dir=ROOT/'game')
        self.base=pathlib.Path(self.temp.name);self.game=self.base
        self.package_temp=tempfile.TemporaryDirectory(prefix='t080-package-',dir=ROOT/'build')
        self.pkg=pathlib.Path(self.package_temp.name)
        self.original={'Generals.exe':b'inert retail executable','d3d8.dll':b'inert known proxy','INIZH.big':b'inert game data','!mod.gib':b'inert mod data'}
        for name,data in self.original.items():(self.game/name).write_bytes(data)
        (self.pkg/'engine.exe').write_bytes(b'inert replacement executable')
        self.manifest=dict(schema=1,version='0.1.0-alpha.2',payload={'engine.exe':digest(b'inert replacement executable')},profiles=[dict(id='synthetic-only',files={k.lower():digest(v) for k,v in self.original.items()},materialize=[{'from':'!mod.gib','to':'!mod.big'}])])
        self.save_manifest()
    def save_manifest(self):(self.pkg/'manifest.json').write_text(json.dumps(self.manifest),encoding='utf-8')
    def tearDown(self):self.temp.cleanup();self.package_temp.cleanup()
    def call(self,action,expected=0,interrupt=None,game=None,auto_recover=False,progress=False):
        env=os.environ.copy();env.pop('ZHPATCH_TEST_INTERRUPT',None)
        if interrupt is not None:env['ZHPATCH_TEST_INTERRUPT']=str(interrupt)
        command=[str(EXE),action,'--game-dir',str(game or self.game),'--package',str(self.pkg)]
        if auto_recover:command.append('--recover-interrupted')
        if progress:command.append('--progress')
        p=subprocess.run(command,env=env,capture_output=True,text=True)
        self.assertEqual(p.returncode,expected,p.stdout+p.stderr)
        return p
    def modcall(self,action,*extra,expected=0,interrupt=None):
        env=os.environ.copy();env.pop('ZHPATCH_TEST_INTERRUPT',None)
        if interrupt is not None:env['ZHPATCH_TEST_INTERRUPT']=str(interrupt)
        p=subprocess.run([str(EXE),'mods',action,'--game-dir',str(self.game),'--package',str(self.pkg),*map(str,extra)],env=env,capture_output=True,text=True)
        self.assertEqual(p.returncode,expected,p.stdout+p.stderr)
        return p
    def mod_source(self,files):
        directory=tempfile.TemporaryDirectory(prefix='t082-mod-',dir=ROOT/'build')
        self.addCleanup(directory.cleanup)
        base=pathlib.Path(directory.name)
        for name,data in files.items():
            path=base/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
        return base
    def base_installed(self):
        self.assertEqual((self.game/'Generals.exe').read_bytes(),b'inert replacement executable')
        self.assertFalse((self.game/'d3d8.dll').exists())
        self.assertEqual((self.game/'!mod.big').read_bytes(),self.original['!mod.gib'])
    def restored(self):
        for name,data in self.original.items():self.assertEqual((self.game/name).read_bytes(),data)
        self.assertFalse((self.game/'!mod.big').exists())
    def test_round_trip_reinstall_idempotency(self):
        self.call('inspect');self.assertFalse((self.game/'.zhpatch-alpha').exists())
        for _ in range(2):
            self.call('install');self.call('install');self.call('inspect');self.call('verify')
            self.assertEqual((self.game/'!mod.big').read_bytes(),self.original['!mod.gib'])
            self.assertFalse((self.game/'d3d8.dll').exists())
            self.call('uninstall');self.call('uninstall');self.restored()
    def test_console_progress_reports_only_verified_work(self):
        install=self.call('install',auto_recover=True,progress=True).stdout
        expected=[
            'Checking the package and selected folder',
            'Saving and checking original backups',
            'Applying the patch',
            '[############] Paths checked 3/3',
            'Verifying installed files and backups',
            'Installed and verified',
        ]
        offsets=[install.index(message) for message in expected]
        self.assertEqual(offsets,sorted(offsets))
        backup=self.game/'.zhpatch-alpha/original-0.bin'
        original=backup.read_bytes()
        backup.write_bytes(b'damaged backup')
        failed=self.call('uninstall',1,progress=True)
        self.assertIn('Checking backups and current files',failed.stdout)
        self.assertNotIn('Restoring and verifying original files',failed.stdout)
        self.assertNotIn('Paths checked',failed.stdout)
        self.base_installed()
        backup.write_bytes(original)
        restored=self.call('uninstall',progress=True).stdout
        self.assertIn('[############] Paths checked 3/3',restored)
        self.assertIn('Original managed files restored and verified',restored)
        self.restored()
        self.assertNotIn('Checking',self.call('install').stdout)
    def test_install_interruption_every_boundary(self):
        if args.production:self.skipTest('Debug fault injection is excluded from production')
        for boundary in range(4):
            with self.subTest(boundary=boundary):
                self.call('install',86,interrupt=boundary);self.call('verify',1)
                self.call('recover');self.restored();self.call('install');self.call('uninstall');self.restored()
    def test_uninstall_interruption_every_boundary(self):
        if args.production:self.skipTest('Debug fault injection is excluded from production')
        for boundary in range(1,4):
            with self.subTest(boundary=boundary):
                self.call('install');self.call('uninstall',86,interrupt=boundary)
                self.call('recover');self.restored()
    def test_console_install_and_uninstall_recover_incomplete_transactions(self):
        if args.production:self.skipTest('Debug fault injection is excluded from production')
        self.call('install',86,interrupt=1)
        (self.game/'.zhpatch-alpha/journal.json.zhpatch-tmp').write_bytes(b'interrupted journal')
        self.call('install',auto_recover=True)
        self.base_installed()
        self.call('uninstall',86,interrupt=1)
        self.call('uninstall',auto_recover=True)
        self.restored()
    def test_console_recovery_preparation_and_clean_uninstall(self):
        self.assertIn('already uninstalled',self.call('uninstall',auto_recover=True).stdout)
        state=self.game/'.zhpatch-alpha'
        self.assertFalse(state.exists())
        state.mkdir()
        (state/'original-0.bin.zhpatch-tmp').write_bytes(b'interrupted backup')
        self.call('install',auto_recover=True)
        self.base_installed()
        self.assertEqual(len(list(state.glob('recovered-*.bin'))),1)
        self.call('uninstall',auto_recover=True)
        self.restored()
    def test_console_uninstall_restores_leftover_overlay(self):
        self.call('install')
        source=self.mod_source({'INIZH.big':b'overlay'})
        self.modcall('add','--source',source,'--id','test')
        self.modcall('activate','--mod','test')
        self.call('uninstall',auto_recover=True)
        self.restored()
        self.assertIn('test',self.modcall('list').stdout)
    def test_unknown_build_refused_without_state(self):
        (self.game/'INIZH.big').write_bytes(b'unknown version')
        self.call('install',1);self.assertFalse((self.game/'.zhpatch-alpha').exists())
        self.assertEqual((self.game/'Generals.exe').read_bytes(),self.original['Generals.exe'])
    def test_unknown_mod_and_loose_override_refused(self):
        for name in ['other.big','unknown.dll','Data/INI/GameData.ini']:
            p=self.game/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'unknown mod')
            self.call('inspect',1);self.call('install',1);self.assertFalse((self.game/'.zhpatch-alpha').exists());p.unlink()
    def test_compatible_runtime_preserves_local_mod_data(self):
        self.manifest['compatible_runtime']=True
        self.save_manifest()
        files={'W3DZH.big':b'core data','ActiveMod.big':b'mod data','Data/INI/Mod.ini':b'local override'}
        for name,data in files.items():
            path=self.game/name;path.parent.mkdir(exist_ok=True,parents=True);path.write_bytes(data)
        self.assertIn('compatible-local-zero-hour',self.call('install',auto_recover=True).stdout)
        self.call('verify')
        self.assertFalse((self.game/'!mod.big').exists())
        for name,data in files.items():self.assertEqual((self.game/name).read_bytes(),data)
        (self.game/'ActiveMod.big').write_bytes(b'updated mod')
        self.call('verify',1)
        self.call('uninstall',auto_recover=True)
        self.restored()
        self.assertEqual((self.game/'ActiveMod.big').read_bytes(),b'updated mod')
        self.assertEqual((self.game/'Data/INI/Mod.ini').read_bytes(),b'local override')
    def test_compatible_runtime_refuses_unknown_binary_or_proxy(self):
        self.manifest['compatible_runtime']=True
        self.save_manifest()
        (self.game/'W3DZH.big').write_bytes(b'core data')
        for name in ('Generals.exe','d3d8.dll'):
            with self.subTest(name=name):
                path=self.game/name
                path.write_bytes(b'unsupported replacement')
                self.assertIn('Unsupported',self.call('install',1,auto_recover=True).stderr)
                self.assertFalse((self.game/'.zhpatch-alpha').exists())
                self.assertEqual(path.read_bytes(),b'unsupported replacement')
                path.write_bytes(self.original[name])
        (self.game/'game.dat').write_bytes(b'unknown game.dat')
        self.assertIn('Unsupported Zero Hour engine build',self.call('install',1,auto_recover=True).stderr)
    def test_changed_managed_file_preserved_no_partial_restore(self):
        self.call('install');(self.game/'!mod.big').write_bytes(b'new user mod')
        self.call('uninstall',1);self.assertEqual((self.game/'!mod.big').read_bytes(),b'new user mod')
        self.assertEqual((self.game/'Generals.exe').read_bytes(),b'inert replacement executable')
        self.assertFalse((self.game/'d3d8.dll').exists())
    def test_unrelated_user_changes_preserved(self):
        self.call('install');(self.game/'notes.txt').write_bytes(b'personal notes')
        self.call('verify');self.call('uninstall');self.restored();self.assertEqual((self.game/'notes.txt').read_bytes(),b'personal notes')
    def test_changed_unmanaged_asset_verification_fails_uninstall_preserves(self):
        self.call('install');(self.game/'INIZH.big').write_bytes(b'user changed data');self.call('verify',1)
        self.call('uninstall');self.assertEqual((self.game/'INIZH.big').read_bytes(),b'user changed data')
    def test_backup_corruption_refused(self):
        self.call('install');p=self.game/'.zhpatch-alpha/original-0.bin';p.write_bytes(b'corrupted backup')
        self.call('verify',1);self.call('uninstall',1)
        self.assertEqual((self.game/'Generals.exe').read_bytes(),b'inert replacement executable')
    def test_package_tamper_refused(self):
        (self.pkg/'engine.exe').write_bytes(b'corrupt download');self.call('install',1)
        self.assertFalse((self.game/'.zhpatch-alpha').exists())
    def test_journal_tamper_refused(self):
        self.call('install');p=self.game/'.zhpatch-alpha/journal.json';j=json.loads(p.read_text());j['entries'][0]['path']='INIZH.big';p.write_text(json.dumps(j))
        self.call('uninstall',1);self.assertEqual((self.game/'INIZH.big').read_bytes(),self.original['INIZH.big'])
    def test_protected_reference_and_path_alias_refused(self):
        baseline=self.base/'baseline-pristine';baseline.mkdir()
        self.call('install',1,game=baseline)
        self.call('install',1,game=str(self.game)+'.')
        self.assertFalse((self.game/'.zhpatch-alpha').exists())
    def test_hardlink_refused(self):
        os.link(self.game/'INIZH.big',self.base/'linked.big');self.call('install',1)
        self.assertFalse((self.game/'.zhpatch-alpha').exists())
    def test_lock_contention_refused(self):
        import ctypes
        self.call('install');lock=self.game/'.zhpatch-alpha/lock'
        kernel=ctypes.WinDLL('kernel32',use_last_error=True)
        kernel.CreateFileW.restype=ctypes.c_void_p
        handle=kernel.CreateFileW(str(lock),0x80000000,0,None,3,0,None)
        self.assertNotEqual(handle,ctypes.c_void_p(-1).value)
        try:self.call('uninstall',1)
        finally:kernel.CloseHandle(ctypes.c_void_p(handle))
        self.call('uninstall');self.restored()
    def test_partial_atomic_write_recoverable(self):
        if args.production:self.skipTest('Debug fault injection is excluded from production')
        self.call('install',86,interrupt=1)
        (self.game/'d3d8.dll.zhpatch-tmp').write_bytes(b'partial scratch')
        (self.game/'.zhpatch-alpha/journal.json.zhpatch-tmp').write_bytes(b'{partial journal')
        self.call('recover');self.restored()
        self.assertEqual(len(list((self.game/'.zhpatch-alpha').glob('recovered-*.bin'))),2)
    def test_partial_preparation_recoverable(self):
        state=self.game/'.zhpatch-alpha';state.mkdir();(state/'original-0.bin.zhpatch-tmp').write_bytes(b'partial backup')
        self.call('recover');self.call('install');self.call('uninstall');self.restored()
    def test_real_write_failure_rolls_back(self):
        scratch=self.game/'!mod.big.zhpatch-tmp';scratch.write_bytes(b'existing scratch preserved')
        self.call('install',1);self.restored();self.assertEqual(scratch.read_bytes(),b'existing scratch preserved')
        self.call('recover');self.call('install');self.call('uninstall');self.restored()
    def test_directory_junction_refused(self):
        link=self.game/'Data'
        env=os.environ.copy();env['ZHPATCH_LINK']=str(link);env['ZHPATCH_LINK_TARGET']=str(self.pkg)
        p=subprocess.run(['powershell','-NoProfile','-Command','New-Item -ItemType Junction -Path $env:ZHPATCH_LINK -Target $env:ZHPATCH_LINK_TARGET | Out-Null'],env=env,capture_output=True,text=True)
        self.assertEqual(p.returncode,0,p.stderr)
        self.call('install',1);self.assertFalse((self.game/'.zhpatch-alpha').exists())
        link.rmdir()
    def test_running_process_refused(self):
        # This is an inert Rust sleeper named Generals.exe, never a game binary.
        source=self.pkg/'sleeper.rs';source.write_text('fn main(){std::thread::sleep(std::time::Duration::from_secs(30));}')
        mock=self.pkg/'Generals.exe'
        subprocess.run(['rustc',str(source),'-o',str(mock)],check=True,capture_output=True)
        p=subprocess.Popen([str(mock)],creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            result=self.call('install',1)
            self.assertIn('Close all Generals',result.stderr)
            self.assertFalse((self.game/'.zhpatch-alpha').exists())
        finally:p.terminate();p.wait()
    def test_production_ignores_debug_interrupt(self):
        if not args.production:self.skipTest('Production binary only')
        self.call('install',interrupt=0);self.call('verify');self.call('uninstall');self.restored()
    def test_known_loose_script_routing_and_recovery(self):
        name='Data/scripts/Scripts.ini';data=b'original stock scripts'
        (self.game/name).parent.mkdir(parents=True);(self.game/name).write_bytes(data)
        self.original[name]=data
        self.manifest['profiles'][0]['files'][name.lower()]=digest(data)
        self.manifest['profiles'][0]['materialize'].append({'from':name,'to':'Data/scripts/Scripts.bcs','remove_source':True});self.save_manifest()
        if not args.production:
            for boundary in [4,5]:
                self.call('install',86,interrupt=boundary);self.call('recover');self.restored()
                self.assertFalse((self.game/'data/scripts/scripts.bcs').exists())
        self.call('install');self.call('verify');self.assertFalse((self.game/name).exists())
        self.assertEqual((self.game/'data/scripts/scripts.bcs').read_bytes(),data)
        self.call('uninstall');self.restored();self.assertFalse((self.game/'data/scripts/scripts.bcs').exists())
    def test_original_filename_case_preserved(self):
        old=self.game/'Generals.exe';temporary=self.game/'case-temp.bin';old.rename(temporary);temporary.rename(self.game/'generals.exe')
        self.original['generals.exe']=self.original.pop('Generals.exe')
        old=self.game/'d3d8.dll';temporary=self.game/'proxy-temp.bin';old.rename(temporary);temporary.rename(self.game/'D3D8.dll')
        self.original['D3D8.dll']=self.original.pop('d3d8.dll')
        self.manifest['profiles'][0]['engine_path']='Generals.exe';self.save_manifest()
        self.call('install');self.call('uninstall');self.restored()
        self.assertIn('generals.exe',[p.name for p in self.game.iterdir()])
        self.assertNotIn('Generals.exe',[p.name for p in self.game.iterdir()])
        self.assertIn('D3D8.dll',[p.name for p in self.game.iterdir()])
    def test_mod_import_activate_restore(self):
        self.call('install')
        source=self.mod_source({
            '!mod.gib':b'gib overlay',
            'Data/Test.ini':b'test=1',
            'INIZH.big':b'replacement',
            'nested/Sub.txt':b'sub',
            'evil.exe':b'never run',
            'evil.dll':b'never load',
        })
        preview=self.modcall('inspect','--source',source)
        self.assertIn('!mod.gib -> !mod.big',preview.stdout)
        self.assertIn('SKIP evil.exe',preview.stdout)
        self.modcall('add','--source',source,'--id','test-mod')
        self.assertIn('test-mod',self.modcall('list').stdout)
        self.modcall('enable','--mod','test-mod')
        self.modcall('activate')
        self.assertEqual((self.game/'!mod.big').read_bytes(),b'gib overlay')
        self.assertEqual((self.game/'INIZH.big').read_bytes(),b'replacement')
        self.assertEqual((self.game/'Data/Test.ini').read_bytes(),b'test=1')
        self.assertEqual((self.game/'nested/Sub.txt').read_bytes(),b'sub')
        self.assertFalse((self.game/'evil.exe').exists())
        self.assertFalse((self.game/'evil.dll').exists())
        self.modcall('verify')
        result=self.call('uninstall',1)
        self.assertIn('active mod overlay',result.stderr)
        self.modcall('restore')
        self.base_installed()
        self.assertFalse((self.game/'Data/Test.ini').exists())
        self.assertFalse((self.game/'nested').exists())
        self.assertIn('"status": "restored"',(self.game/'.zhpatch-alpha/mod-journal.json').read_text())
        self.modcall('remove','--mod','test-mod')
        self.assertNotIn('test-mod',self.modcall('list').stdout)

    def test_mod_switch_and_order(self):
        self.call('install')
        a=self.mod_source({'Data/Shared.ini':b'A'})
        b=self.mod_source({'Data/Shared.ini':b'B'})
        self.modcall('add','--source',a,'--id','mod-a')
        self.modcall('add','--source',b,'--id','mod-b')
        self.modcall('enable','--mod','mod-a,mod-b')
        self.modcall('activate')
        self.assertEqual((self.game/'Data/Shared.ini').read_bytes(),b'B')
        self.modcall('restore')
        self.modcall('enable','--mod','mod-a')
        self.modcall('activate')
        self.assertEqual((self.game/'Data/Shared.ini').read_bytes(),b'A')
        self.modcall('restore')
        self.base_installed()
        self.assertFalse((self.game/'Data/Shared.ini').exists())

    def test_mod_windows_case_alias_and_identical_original(self):
        self.call('install')
        first=self.mod_source({'INIZH.BIG':b'different overlay','DATA/Shared.ini':b'first'})
        second=self.mod_source({'INIzh.big':self.original['INIZH.big'],'data/shared.ini':b'second'})
        self.modcall('add','--source',first,'--id','first')
        self.modcall('add','--source',second,'--id','second')
        self.modcall('activate','--mod','first,second')
        journal=json.loads((self.game/'.zhpatch-alpha/mod-journal.json').read_text())
        self.assertEqual(len(journal['entries']),2)
        self.assertEqual((self.game/'Data/Shared.ini').read_bytes(),b'second')
        self.call('verify')
        self.modcall('restore')
        self.assertEqual((self.game/'INIZH.big').read_bytes(),self.original['INIZH.big'])
        self.assertIn('INIZH.big',os.listdir(self.game))
        self.assertFalse((self.game/'Data').exists())
        self.call('verify')

    def test_mod_exact_base_gate_and_active_verification(self):
        self.call('install')
        source=self.mod_source({'New.big':b'overlay'})
        self.modcall('add','--source',source,'--id','test')
        base=self.game/'INIZH.big'
        base.write_bytes(b'changed base')
        result=self.modcall('activate','--mod','test',expected=1)
        self.assertIn('Runtime assets changed',result.stderr)
        self.assertFalse((self.game/'New.big').exists())
        base.write_bytes(self.original['INIZH.big'])
        self.modcall('activate','--mod','test')
        base.write_bytes(b'changed during play')
        self.assertIn('Runtime assets changed',self.call('verify',1).stderr)
        self.modcall('restore')
        self.assertEqual(base.read_bytes(),b'changed during play')

    def test_mod_preserves_readonly_in_restore_and_backup_recovery(self):
        self.call('install')
        target=self.game/'INIZH.big'
        source=self.mod_source({'INIZH.big':self.original['INIZH.big']})
        self.modcall('add','--source',source,'--id','same')
        try:
            for boundary in [None] if args.production else [None,2000,2001,3000]:
                with self.subTest(boundary=boundary):
                    target.chmod(stat.S_IREAD)
                    self.modcall('activate','--mod','same',expected=0 if boundary is None else 86,interrupt=boundary)
                    self.call('recover')
                    self.assertEqual(target.read_bytes(),self.original['INIZH.big'])
                    self.assertTrue(target.stat().st_file_attributes & stat.FILE_ATTRIBUTE_READONLY)
        finally:
            if target.exists():target.chmod(stat.S_IWRITE)

    def test_mod_restore_preflights_all_backups(self):
        self.call('install')
        source=self.mod_source({'AAA.big':b'added','INIZH.big':b'replacement'})
        self.modcall('add','--source',source,'--id','test')
        self.modcall('activate','--mod','test')
        backup=self.game/'.zhpatch-alpha/mod-backups/0001.bin'
        original=backup.read_bytes()
        backup.write_bytes(b'damaged')
        self.assertIn('corrupt mod backup',self.modcall('restore',expected=1).stderr)
        self.assertEqual((self.game/'AAA.big').read_bytes(),b'added')
        self.assertEqual((self.game/'INIZH.big').read_bytes(),b'replacement')
        backup.write_bytes(original)
        self.modcall('restore')
        self.call('verify')

    def test_mod_recover_interrupted_journal_write(self):
        self.call('install')
        source=self.mod_source({'INIZH.big':b'overlay'})
        self.modcall('add','--source',source,'--id','test')
        state=self.game/'.zhpatch-alpha'
        scratch=state/'mod-journal.json.zhpatch-tmp'
        scratch.write_bytes(b'partial journal before activation')
        self.call('recover')
        self.modcall('activate','--mod','test')
        scratch.write_bytes(b'partial journal during restore')
        self.call('recover')
        self.assertEqual(len(list(state.glob('recovered-mod-journal-*.json'))),2)
        self.assertEqual((self.game/'INIZH.big').read_bytes(),self.original['INIZH.big'])
        self.call('verify')

    def test_mod_play_launch_failure_restores_overlay(self):
        self.call('install')
        source=self.mod_source({'INIZH.big':b'overlay'})
        self.modcall('add','--source',source,'--id','test')
        self.modcall('enable','--mod','test')
        self.assertIn('Mod launch failed',self.call('play',1).stderr)
        self.assertEqual((self.game/'INIZH.big').read_bytes(),self.original['INIZH.big'])
        self.call('verify')

    def test_mod_inputs_require_prepared_data(self):
        self.call('install')
        directory=tempfile.TemporaryDirectory(prefix='t095-mod-input-',dir=ROOT/'build')
        self.addCleanup(directory.cleanup)
        base=pathlib.Path(directory.name)
        safe=base/'mod.ZIP'
        with zipfile.ZipFile(safe,'w') as archive:
            archive.writestr('Data/Mod.ini','mod-data')
        for ext in ('7z','rar'):
            (base/f'mod.{ext}').write_bytes(b'compressed package placeholder')
        for archive in (safe,base/'mod.7z',base/'mod.rar'):
            with self.subTest(archive=archive.name):
                for action in ('inspect','add'):
                    result=self.modcall(action,'--source',archive,expected=1)
                    self.assertIn('Pass the prepared folder',result.stderr)
        self.assertFalse((self.game/'.zhpatch-alpha'/'mods').exists())

        prepared=base/'prepared.zip'
        (prepared/'Data').mkdir(parents=True)
        (prepared/'Data/Mod.ini').write_bytes(b'mod-data')
        self.assertIn('Data/Mod.ini',self.modcall('inspect','--source',prepared).stdout)
        self.modcall('add','--source',prepared,'--id','prepared')
        self.modcall('enable','--mod','prepared')
        self.modcall('activate')
        self.assertEqual((self.game/'Data/Mod.ini').read_bytes(),b'mod-data')
        self.modcall('restore')
        self.base_installed()

        single=base/'Single.big'
        single.write_bytes(b'single-big')
        self.assertIn('Single.big',self.modcall('inspect','--source',single).stdout)
        self.modcall('add','--source',single,'--id','single-big')
        self.modcall('enable','--mod','single-big')
        self.modcall('activate')
        self.assertEqual((self.game/'Single.big').read_bytes(),b'single-big')
        self.modcall('restore')
        self.base_installed()

        installer=base/'mod-installer.exe'
        installer.write_bytes(b'not executed')
        self.assertIn(
            'Installer/script packages are not executed',
            self.modcall('add','--source',installer,expected=1).stderr,
        )

    def test_mod_interruption_and_recovery(self):
        if args.production:self.skipTest('Debug fault injection is excluded from production')
        for boundary in [3000,3001]:
            with self.subTest(boundary=boundary):
                modid=f'interrupt-mod-{boundary}'
                self.call('install')
                source=self.mod_source({'!mod.gib':b'overlay','Data/Test.ini':b'test'})
                self.modcall('add','--source',source,'--id',modid)
                self.modcall('enable','--mod',modid)
                self.modcall('activate',expected=86,interrupt=boundary)
                self.call('recover')
                self.base_installed()
                self.assertFalse((self.game/'Data/Test.ini').exists())
                self.call('uninstall')
                self.restored()
        self.call('install')
        source=self.mod_source({'!mod.gib':b'overlay','Data/Test.ini':b'test'})
        self.modcall('add','--source',source,'--id','restore-interrupt')
        self.modcall('enable','--mod','restore-interrupt')
        self.modcall('activate')
        self.modcall('restore',expected=86,interrupt=4001)
        self.modcall('restore')
        self.base_installed()
        self.assertFalse((self.game/'Data/Test.ini').exists())
        self.call('uninstall')
        self.restored()

    def test_mod_source_safety_and_remove(self):
        self.call('install')
        inside=self.game/'mod-source'
        inside.mkdir()
        (inside/'Data.ini').write_bytes(b'x')
        self.assertIn(
            'outside the game copy',
            self.modcall('add','--source',inside,expected=1).stderr,
        )
        source=self.mod_source({'Data/Test.ini':b'test'})
        self.modcall('add','--source',source,'--id','remove-mod')
        self.modcall('enable','--mod','remove-mod')
        self.modcall('activate')
        self.assertIn(
            'Restore the active mod overlay',
            self.modcall('remove','--mod','remove-mod',expected=1).stderr,
        )
        self.modcall('restore')
        self.modcall('remove','--mod','remove-mod')
        self.assertNotIn('remove-mod',self.modcall('list').stdout)

    def test_mod_inspect_does_not_mutate(self):
        source=self.mod_source({'Data/Test.ini':b'test'})
        self.assertFalse((self.game/'.zhpatch-alpha').exists())
        self.assertIn('Data/Test.ini',self.modcall('inspect','--source',source).stdout)
        self.assertFalse((self.game/'.zhpatch-alpha').exists())

    def test_mod_journal_tamper_and_linked_parent_refused(self):
        self.call('install')
        source=self.mod_source({'Data/Test.ini':b'test'})
        self.modcall('add','--source',source,'--id','tamper-mod')
        self.modcall('enable','--mod','tamper-mod')
        self.modcall('activate')
        journal=self.game/'.zhpatch-alpha/mod-journal.json'
        saved=journal.read_bytes()
        j=json.loads(saved);j['entries'][0]['path']='../evil.txt';journal.write_text(json.dumps(j))
        self.assertIn('Unsafe relative path',self.modcall('restore',expected=1).stderr)
        self.assertFalse((self.game.parent/'evil.txt').exists())
        journal.write_bytes(saved)
        self.modcall('restore')
        self.base_installed()
        link=self.game/'Data'
        env=os.environ.copy();env['ZHPATCH_LINK']=str(link);env['ZHPATCH_LINK_TARGET']=str(self.pkg)
        p=subprocess.run(['powershell','-NoProfile','-Command','New-Item -ItemType Junction -Path $env:ZHPATCH_LINK -Target $env:ZHPATCH_LINK_TARGET | Out-Null'],env=env,capture_output=True,text=True)
        self.assertEqual(p.returncode,0,p.stderr)
        try:
            self.modcall('add','--source',source,'--id','linked-parent')
            self.modcall('enable','--mod','linked-parent')
            self.assertIn('Linked path refused',self.modcall('activate',expected=1).stderr)
        finally:
            link.rmdir()
        self.call('uninstall')
        self.restored()

        self.call('install');self.call('uninstall')
        old=(self.game/'.zhpatch-alpha/journal.json').read_bytes()
        (self.pkg/'engine.exe').write_bytes(b'inert updated engine')
        self.manifest['payload']['engine.exe']=digest(b'inert updated engine');self.save_manifest()
        return old
    def upgrade_package(self):
        self.call('install');self.call('uninstall')
        old=(self.game/'.zhpatch-alpha/journal.json').read_bytes()
        (self.pkg/'engine.exe').write_bytes(b'inert updated engine')
        self.manifest['payload']['engine.exe']=digest(b'inert updated engine');self.save_manifest()
        return old
    def test_upgrade_after_uninstall_retains_previous_backups(self):
        old=self.upgrade_package();self.call('install');self.call('verify')
        history=list((self.game/'.zhpatch-alpha/history').glob('*/journal.json'))
        self.assertEqual(len(history),1);self.assertEqual(history[0].read_bytes(),old)
        self.assertEqual((history[0].parent/'original-0.bin').read_bytes(),self.original['Generals.exe'])
        self.assertEqual((self.game/'Generals.exe').read_bytes(),b'inert updated engine')
        self.call('uninstall');self.restored()
    def test_upgrade_metadata_archive_interruption_recoverable(self):
        if args.production:self.skipTest('Debug fault injection is excluded from production')
        for boundary in [1000,1001,1002,1003]:
            with self.subTest(boundary=boundary):
                old=self.upgrade_package();self.call('install',86,interrupt=boundary)
                self.restored();self.call('recover');self.restored()
                self.call('install');self.call('uninstall');self.restored()
                # Change the next payload so each iteration creates another metadata migration.
                data=(self.pkg/'engine.exe').read_bytes()+b' next';(self.pkg/'engine.exe').write_bytes(data)
                self.manifest['payload']['engine.exe']=digest(data);self.save_manifest()

if __name__=='__main__':unittest.main(argv=[__file__]+remaining,verbosity=2)
