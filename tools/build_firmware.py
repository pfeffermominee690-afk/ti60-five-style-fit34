"""Rebuild the preserved fit34 firmware without changing any FPGA or prebuilt file."""
from pathlib import Path
import argparse,os,subprocess,hashlib,json

R=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--toolchain',default=os.environ.get('RISCV_TOOLCHAIN','D:/FPGA/Efinity/riscv-ide-2025.1/toolchain/bin'));a=p.parse_args()
T=Path(a.toolchain);O=R/'build/firmware';O.mkdir(parents=True,exist_ok=True)
suffix='.exe' if os.name=='nt' else ''
gcc=T/('riscv-none-embed-gcc'+suffix);objcopy=T/('riscv-none-embed-objcopy'+suffix)
flags=['-march=rv32i','-mabi=ilp32','-std=gnu11','-Os','-g3','-Wall','-Wextra','-ffreestanding','-DUSE_GP','-fstack-usage']
for d in ['src','include','project-bsp/efinix/EfxSapphireSoc/include','vendor/bsp','vendor/include','vendor/driver']:
    flags+=['-I',str(R/'firmware'/d)]
objects=[]
for n in ['src/network_camera.c','vendor/common/start.S','vendor/common/trap.S']:
    src=R/'firmware'/n;obj=O/(src.stem+'.o');objects.append(str(obj))
    subprocess.run([str(gcc),*flags,'-c',str(src),'-o',str(obj)],check=True)
elf=O/'network_camera.elf'
subprocess.run([str(gcc),*flags,*objects,'-o',str(elf),'-nostartfiles','-specs=nosys.specs','-Wl,--defsym=__stack_size=2048,-Bstatic,-T,'+str(R/'firmware/include/onchip.ld')+',-Map,'+str(O/'network_camera.map')+',--print-memory-usage','-lc','-lgcc'],check=True)
binary=elf.with_suffix('.bin')
subprocess.run([str(objcopy),'-O','binary',str(elf),str(binary)],check=True)
assert binary.read_bytes()==(R/'prebuilt/network_camera.bin').read_bytes(), 'Firmware binary differs from archived fit34'
result={'binary_byte_exact':True,'bytes':binary.stat().st_size,'sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'note':'ELF debug paths differ; executable binary is compared byte for byte.'}
(O/'rebuild-check.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
