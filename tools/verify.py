"""Read-only integrity and dependency checks for all three engineering targets."""
from pathlib import Path
import hashlib,json,struct,xml.etree.ElementTree as ET,zlib
R=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((R/'manifest.json').read_text(encoding='utf-8'))
for n,h in manifest['files'].items():
 assert (R/n).is_file(), 'Missing '+n
 assert sha(R/n)==h, 'Hash mismatch '+n
source_count=0;design_count=0
for prefix,app,bitname in [('', 'network_camera','fit37'),('line-demo','capture_demo','line-demo'),('autoboot','network_autoboot','autoboot')]:
 base=R/prefix;review=json.loads((base/'source-manifest.json').read_text())
 for n,h in review['sources'].items():assert sha(base/'fpga'/n)==h,prefix+'/'+n
 assert sha(base/'prebuilt'/(bitname+'.bit'))==review['bit_sha256']
 assert sha(base/'prebuilt'/(app+'.elf'))==review['elf_sha256']
 root=ET.parse(base/'fpga/ti60f225_oob.xml').getroot();designs=root.findall('.//{*}design_file')
 for e in designs:assert (base/'fpga'/e.attrib['name']).is_file(),prefix+'/'+e.attrib['name']
 binary=(base/'prebuilt'/(app+'.bin')).read_bytes().ljust(16384,b'\0')
 for i in range(4):
  name=f'EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol{i}.bin'
  for folder in ['fpga','fpga/ip/soc','fpga/ip/soc/source/hardware/netlist']:
   data=bytes(int(x,2) for x in (base/folder/name).read_text().split());assert data==binary[i::4],str(base/folder/name)
 source_count+=len(review['sources']);design_count+=len(designs)
recovery=R/'recovery/fit34'
old_review=json.loads((recovery/'source-manifest.json').read_text())
for n,h in old_review['sources'].items():
 archived=recovery/'fpga'/n
 assert sha(archived if archived.is_file() else R/'fpga'/n)==h,'fit34/'+n
assert sha(R/'prebuilt/fit34.bit')==old_review['bit_sha256']
assert sha(R/'prebuilt/network_camera.elf')==old_review['elf_sha256']
model_meta=json.loads((R/'models/models-five-fit24-compat.json').read_text())
model=(R/'models/models-five-fit24-compat.bin').read_bytes()
assert hashlib.sha256(model).hexdigest()==model_meta['sha256']
payload=(R/'autoboot/prebuilt/models-flash.bin').read_bytes()
assert struct.unpack('<4I',payload[:16])==(0x50324254,len(model),zlib.crc32(model),1)
assert payload[16:256]==b'\xff'*240 and payload[256:]==model
assert bytes.fromhex((R/'autoboot/prebuilt/models-flash.hex').read_text())==payload
styles=json.loads((R/'styles.json').read_text(encoding='utf-8'))
assert [s['display_name'] for s in styles]==['木刻','点彩','排线速写','鲜明色彩','蓝黄笔触']
assert [(s['index'],s['model']) for s in styles]==[(s['index'],s['style']) for s in model_meta['styles']]
rows=[int(v,16) for v in (R/'tests/display/title-rows.hex').read_text().split()]
expected=[(v>>(127-x))&1 for v in rows for x in range(128)]+[0]*(16384-len(rows)*128)
for prefix in ['', 'autoboot']:
 actual=[int(v,16) for v in (R/prefix/'fpga/title-font.hex').read_text().split()]
 assert actual==expected, 'OSD font mismatch'
print(f"PASS: {len(manifest['files'])} file hashes; 3 complete projects; fit34 recovery overlay; {source_count} source hashes; {design_count} project inputs; firmware RAM; model payload; OSD labels.")
