"""Read-only package, FPGA dependency, firmware RAM and reference checks."""
from pathlib import Path
import hashlib,json,xml.etree.ElementTree as ET

R=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((R/'manifest.json').read_text(encoding='utf-8'))
for n,h in manifest['files'].items():
    assert (R/n).is_file(), 'Missing '+n
    assert sha(R/n)==h, 'Hash mismatch '+n
review=json.loads((R/'source-manifest.json').read_text())
for n,h in review['sources'].items():assert sha(R/'fpga'/n)==h,n
assert sha(R/'prebuilt/fit34.bit')==review['bit_sha256']
assert sha(R/'prebuilt/network_camera.elf')==review['elf_sha256']
root=ET.parse(R/'fpga/ti60f225_oob.xml').getroot()
designs=root.findall('.//{*}design_file')
for e in designs:assert (R/'fpga'/e.attrib['name']).is_file(),e.attrib['name']
binary=(R/'prebuilt/network_camera.bin').read_bytes().ljust(16384,b'\0')
for i in range(4):
    name=f'EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol{i}.bin'
    for folder in ['fpga','fpga/ip/soc','fpga/ip/soc/source/hardware/netlist']:
        data=bytes(int(x,2) for x in (R/folder/name).read_text().split())
        assert data==binary[i::4],folder+'/'+name
model=json.loads((R/'models/models-five-fit24-compat.json').read_text())
assert sha(R/'models/models-five-fit24-compat.bin')==model['sha256']
print(f"PASS: {len(manifest['files'])} file hashes; {len(review['sources'])} historical source hashes; {len(designs)} project sources; 16 KiB firmware RAM; model hash.")
