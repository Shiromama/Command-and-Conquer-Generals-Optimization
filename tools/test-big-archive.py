"""Check BIG zero-length markers without accepting invalid nonempty payloads."""
import importlib.util,struct,sys,tempfile,unittest
from pathlib import Path
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('big_reader',root/'tools/big-archive.py');reader=importlib.util.module_from_spec(spec);sys.modules[spec.name]=reader;spec.loader.exec_module(reader)
class Bounds(unittest.TestCase):
    def fixture(self,offset,size,payload=b'x',name=b'Data/test.ini'):
        table=struct.pack('>II',offset,size)+name+b'\0';length=16+len(table)+len(payload)
        return b'BIGF'+struct.pack('<I',length)+struct.pack('>II',1,16+len(table))+table+payload
    def test_zero_offset_empty_marker(self):
        self.path.write_bytes(self.fixture(0,0,name=b'Data/*'))
        _,entries=reader.read_index(self.path);self.assertEqual((entries[0].offset,entries[0].size),(0,0))
    def test_nonempty_payload_header_overlap_rejected(self):
        for offset,size in [(0,1),(1,0),(1,1),(999,0),(999,1)]:
            with self.subTest(offset=offset,size=size):
                self.path.write_bytes(self.fixture(offset,size))
                with self.assertRaises(reader.BigError):reader.read_index(self.path)
    def test_valid_payload_after_header(self):
        offset=16+8+len(b'Data/test.ini')+1;self.path.write_bytes(self.fixture(offset,1))
        _,entries=reader.read_index(self.path);self.assertEqual(entries[0].size,1)
    def test_real_patch_archive_markers(self):
        _,entries=reader.read_index(root/'game/baseline-pristine/PatchZH.big')
        self.assertTrue(any(e.name=='Data/*' and e.offset==0 and e.size==0 for e in entries))
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.path=Path(self.temp.name)/'test.big'
    def tearDown(self):self.temp.cleanup()
if __name__=='__main__':unittest.main(verbosity=2)
