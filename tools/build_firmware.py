"""Build firmware and optionally update the selected FPGA RAM initialization."""
from pathlib import Path
import argparse,os,subprocess,hashlib,json
R=Path(__file__).resolve().parents[1]
TARGETS={
 'main':('firmware/src','network_camera','prebuilt','fpga',2048),
 'line':('line-demo/firmware','capture_demo','line-demo/prebuilt','line-demo/fpga',None),
 'autoboot':('autoboot/firmware','network_autoboot','autoboot/prebuilt','autoboot/fpga',None),
}
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--target',choices=TARGETS,default='main')
 p.add_argument('--toolchain',default=os.environ.get('RISCV_TOOLCHAIN','D:/FPGA/Efinity/riscv-ide-2025.1/toolchain/bin'))
 p.add_argument('--check-reference',action='store_true')
 p.add_argument('--update-ram',action='store_true')
 a=p.parse_args();source,app,reference,fpga,stack=TARGETS[a.target]
 T=Path(a.toolchain);O=R/'build'/a.target;O.mkdir(parents=True,exist_ok=True)
 suffix='.exe' if os.name=='nt' else ''
 gcc=T/('riscv-none-embed-gcc'+suffix);objcopy=T/('riscv-none-embed-objcopy'+suffix)
 flags=['-march=rv32i','-mabi=ilp32','-std=gnu11','-Os','-g3','-Wall','-Wextra','-ffreestanding','-DUSE_GP']
 if a.target=='main':flags+=['-fstack-usage']
 includes=[R/source]+[R/'firmware'/d for d in ['include','project-bsp/efinix/EfxSapphireSoc/include','vendor/bsp','vendor/include','vendor/driver']]
 for d in includes:flags+=['-I',str(d)]
 objects=[]
 for src in [R/source/(app+'.c'),R/'firmware/vendor/common/start.S',R/'firmware/vendor/common/trap.S']:
  obj=O/(src.stem+'.o');objects.append(str(obj))
  subprocess.run([str(gcc),*flags,'-c',str(src),'-o',str(obj)],check=True)
 elf=O/(app+'.elf')
 link='-Wl,'+(f'--defsym=__stack_size={stack},' if stack else '')+'-Bstatic,-T,'+str(R/'firmware/include/onchip.ld')+',-Map,'+str(O/(app+'.map'))+',--print-memory-usage'
 subprocess.run([str(gcc),*flags,*objects,'-o',str(elf),'-nostartfiles','-specs=nosys.specs',link,'-lc','-lgcc']+(['-lm'] if a.target=='autoboot' else []),check=True)
 binary=elf.with_suffix('.bin');subprocess.run([str(objcopy),'-O','binary',str(elf),str(binary)],check=True)
 data=binary.read_bytes()
 if len(data)>15*1024:raise RuntimeError('Firmware exceeds on-chip RAM capacity')
 if a.check_reference and data!=(R/reference/(app+'.bin')).read_bytes():raise RuntimeError('Firmware differs from the packaged reference')
 if a.update_ram:
  padded=data.ljust(16384,b'\0')
  for i in range(4):
   text=''.join(f'{v:08b}\n' for v in padded[i::4])
   for folder in [R/fpga,R/fpga/'ip/soc',R/fpga/'ip/soc/source/hardware/netlist']:
    (folder/f'EfxSapphireSoc.v_toplevel_system_ramA_logic_ram_symbol{i}.bin').write_text(text,encoding='ascii')
 result={'target':a.target,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'reference_checked':a.check_reference}
 (O/'build.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
