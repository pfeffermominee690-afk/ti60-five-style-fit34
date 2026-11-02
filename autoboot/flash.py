"""Prepare, back up, program and restore the Ti60 8 MiB boot Flash."""
from pathlib import Path
import argparse,hashlib,json,os,struct,subprocess,time,zlib

ROOT=Path(__file__).resolve().parents[1]
CAPACITY=8*1024*1024
MODEL_OFFSET=0x400000
def digest(data):return hashlib.sha256(data).hexdigest()
def read_hex(path):return bytes.fromhex(Path(path).read_text(encoding='ascii'))
def write_hex(path,data):Path(path).write_text(''.join(f'{v:02x}\n' for v in data),encoding='ascii')
def make_payload(model):
    if not model or len(model)%4:raise ValueError('Model size must be nonzero and word-aligned')
    return struct.pack('<4I',0x50324254,len(model),zlib.crc32(model),1).ljust(256,b'\xff')+model
def prepare(directory):
    directory.mkdir(parents=True,exist_ok=True)
    model=(ROOT/'models/models-five-fit24-compat.bin').read_bytes()
    payload=make_payload(model)
    if payload!=(ROOT/'autoboot/prebuilt/models-flash.bin').read_bytes():raise ValueError('Model package does not match this firmware boot header')
    config=read_hex(ROOT/'autoboot/prebuilt/autoboot.hex')
    if not 0<len(config)<MODEL_OFFSET or MODEL_OFFSET+len(payload)>CAPACITY:raise ValueError('Flash layout exceeds partition bounds')
    write_hex(directory/'configuration.hex',config);write_hex(directory/'models.hex',payload)
    (directory/'models.bin').write_bytes(payload)
    plan={'flash_bytes':CAPACITY,'configuration':{'offset':0,'bytes':len(config),'sha256':digest(config)},'models':{'offset':MODEL_OFFSET,'bytes':len(payload),'sha256':digest(payload),'model_crc32':f'{zlib.crc32(model):08x}'}}
    (directory/'layout.json').write_text(json.dumps(plan,indent=2)+'\n')
    return config,payload
class Programmer:
    def __init__(self,efinity,output):
        self.home=Path(efinity);self.output=output;self.output.mkdir(parents=True,exist_ok=True)
        self.python=self.home/'python311/bin/python.exe'
        self.script=self.home/'pgm/bin/efx_pgm/ftdi_program.py'
        self.bridge=self.home/'pgm/fli/titanium/u10660A79.bit'
        for p in [self.python,self.script,self.bridge]:
            if not p.is_file():raise FileNotFoundError(p)
    def run(self,name,args,marker):
        env=os.environ.copy();env['EFINITY_HOME']=str(self.home)
        env['PYTHONPATH']=os.pathsep.join([str(self.home/'debugger/bin'),str(self.home/'pgm/bin'),env.get('PYTHONPATH','')])
        result=subprocess.run([str(self.python),str(self.script),*map(str,args)],env=env,cwd=ROOT,capture_output=True,timeout=600)
        log=result.stdout+result.stderr;(self.output/(name+'.log')).write_bytes(log)
        if result.returncode or marker.encode() not in log:raise RuntimeError(f'{name} failed; see {self.output/name}.log')
    def connect(self):
        self.run('bridge',[self.bridge,'--mode','jtag'],'finished with JTAG programming');time.sleep(1)
    def read(self,name,offset,length):
        path=self.output/(name+'.hex')
        self.run(name,['--mode','jtag_bridge','--jtag_bridge_mode','read','--address',offset,'--num_bytes',length,'--output_file',path],'Finished read')
        data=read_hex(path)
        if len(data)!=length:raise ValueError('Flash read length mismatch')
        return data
    def write(self,name,path,offset):
        self.run(name,[path,'--mode','jtag_bridge','--jtag_bridge_mode','all','--address',offset,'--verify_method','hostx1'],'Flash verify successful')
    def backup(self):
        data=self.read('flash-before',0,CAPACITY)
        (self.output/'flash-before.bin').write_bytes(data)
        (self.output/'backup.json').write_text(json.dumps({'bytes':len(data),'sha256':digest(data)},indent=2)+'\n')
        return data
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=['prepare','backup','program','restore'])
    p.add_argument('--efinity-home',default=os.environ.get('EFINITY_HOME','D:/FPGA/Efinity/2025.1'))
    p.add_argument('--backup-dir',type=Path,help='Directory containing backup.json and flash-before.bin for restore')
    a=p.parse_args();out=ROOT/'build/autoboot-flash';config,payload=prepare(out)
    if a.action=='prepare':print('Prepared configuration, model header and CRC at '+str(out));return
    restore_data=None
    if a.action=='restore':
        if not a.backup_dir:p.error('restore requires --backup-dir')
        meta=json.loads((a.backup_dir/'backup.json').read_text())
        restore_data=(a.backup_dir/'flash-before.bin').read_bytes()
        if len(restore_data)!=CAPACITY or meta['bytes']!=CAPACITY or digest(restore_data)!=meta['sha256']:raise ValueError('Invalid backup')
    subprocess.run([os.sys.executable,str(ROOT/'tools/verify.py')],check=True)
    session=out/('session-'+time.strftime('%Y%m%d-%H%M%S')+'-'+str(os.getpid()))
    pgm=Programmer(a.efinity_home,session);pgm.connect();pgm.backup()
    if a.action=='backup':print('Backup: '+str(session));return
    if a.action=='restore':
        path=session/'restore.hex';write_hex(path,restore_data);pgm.write('restore',path,0)
        if pgm.read('restore-readback',0,CAPACITY)!=restore_data:raise ValueError('Restore readback mismatch')
        print('Restored backup and verified all bytes.');return
    pgm.write('models-write',out/'models.hex',MODEL_OFFSET)
    pgm.write('configuration-write',out/'configuration.hex',0)
    if pgm.read('configuration-readback',0,len(config))!=config:raise ValueError('Configuration readback mismatch')
    if pgm.read('models-readback',MODEL_OFFSET,len(payload))!=payload:raise ValueError('Model readback mismatch')
    pgm.run('run',[ROOT/'autoboot/prebuilt/autoboot.bit','--mode','jtag'],'finished with JTAG programming')
    print('Boot configuration and model package programmed and verified. Backup: '+str(session))
if __name__=='__main__':main()
