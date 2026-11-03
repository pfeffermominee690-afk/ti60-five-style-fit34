"""Offline checks for payload layout and programming order; no hardware access."""
from pathlib import Path
import importlib.util,json,struct,sys,tempfile,unittest,zlib
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('boot_flash_tool',Path(__file__).parents[1]/'flash.py')
flash=importlib.util.module_from_spec(spec);spec.loader.exec_module(flash)
class FlashTests(unittest.TestCase):
    def test_payload_and_partition_layout(self):
        model=(flash.ROOT/'models/models-five-fit24-compat.bin').read_bytes()
        with tempfile.TemporaryDirectory() as d:
            config,payload=flash.prepare(Path(d))
            self.assertLess(len(config),flash.MODEL_OFFSET)
            self.assertLessEqual(flash.MODEL_OFFSET+len(payload),flash.CAPACITY)
            self.assertEqual(struct.unpack('<4I',payload[:16]),(0x50324254,len(model),zlib.crc32(model),1))
            self.assertEqual(payload[16:256],b'\xff'*240)
            self.assertEqual(payload[256:],model)
            self.assertEqual(flash.read_hex(Path(d)/'models.hex'),payload)
            self.assertEqual(flash.read_hex(Path(d)/'configuration.hex'),config)
        with self.assertRaises(ValueError):flash.make_payload(b'abc')
    def test_fit37_configuration_keeps_shared_model_payload(self):
        with tempfile.TemporaryDirectory() as d:
            config,payload=flash.prepare(Path(d),'main')
            self.assertEqual(config,flash.read_hex(flash.ROOT/'prebuilt/fit37.hex'))
            self.assertNotEqual(config,flash.read_hex(flash.ROOT/'autoboot/prebuilt/autoboot.hex'))
            self.assertEqual(payload,(flash.ROOT/'autoboot/prebuilt/models-flash.bin').read_bytes())
            self.assertEqual(json.loads((Path(d)/'layout.json').read_text())['target'],'main')
    def test_program_backs_up_before_two_partition_writes(self):
        events=[];memory=bytearray(b'\xff'*flash.CAPACITY)
        class Fake:
            def __init__(self,*args):pass
            def connect(self):events.append('connect')
            def backup(self):events.append('backup');return bytes(memory)
            def write(self,name,path,offset):
                events.append((name,offset));data=flash.read_hex(path);memory[offset:offset+len(data)]=data
            def read(self,name,offset,length):events.append(name);return bytes(memory[offset:offset+length])
            def run(self,name,args,marker):events.append(('run',args[0]))
        for target,bit in [('autoboot','autoboot/prebuilt/autoboot.bit'),('main','prebuilt/fit37.bit')]:
            with self.subTest(target=target):
                events.clear()
                with patch.object(flash,'Programmer',Fake),patch.object(flash.subprocess,'run'),patch.object(sys,'argv',['flash.py','program','--target',target]):flash.main()
                self.assertEqual(events,['connect','backup',('models-write',0x400000),('configuration-write',0),'configuration-readback','models-readback',('run',flash.ROOT/bit)])
                self.assertEqual(memory[:len(flash.read_hex(flash.ROOT/flash.CONFIGURATIONS[target][0]))],flash.read_hex(flash.ROOT/flash.CONFIGURATIONS[target][0]))
    def test_invalid_restore_rejected_before_connect(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);(p/'backup.json').write_text(json.dumps({'bytes':flash.CAPACITY,'sha256':'0'*64}));(p/'flash-before.bin').write_bytes(b'bad')
            with patch.object(flash,'Programmer') as pgm,patch.object(sys,'argv',['flash.py','restore','--backup-dir',d]):
                with self.assertRaises(ValueError):flash.main()
                pgm.assert_not_called()
if __name__=='__main__':unittest.main()
