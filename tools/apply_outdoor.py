"""Apply the shared fit34/fit37 runtime AE settings; no firmware or Flash write."""
from pathlib import Path
import argparse,os,socket,subprocess,time,json

R=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--sdk',default=os.environ.get('RISCV_SDK','D:/FPGA/Efinity/riscv-ide-2025.1'));a=p.parse_args()
SDK=Path(a.sdk);O=R/'build/runtime';O.mkdir(parents=True,exist_ok=True)
for port in [3333,6666]:
    with socket.socket() as s:
        if s.connect_ex(('127.0.0.1',port))==0:raise RuntimeError(f'Debugger port {port} is occupied. Close the other debug session first.')
profile=json.loads((R/'profiles/outdoor-pink.json').read_text())
def tcl(command):
    with socket.create_connection(('127.0.0.1',6666),2) as s:
        s.sendall(command.encode()+b'\x1a');return s.recv(8192)
script=O/'outdoor.gdb'
script.write_text('set pagination off\nset confirm off\nset architecture riscv:rv32\nset remotetimeout 30\ntarget remote localhost:3333\nmonitor halt\nif boot_stage != 4 || board_error != 0 || sensor_init_done != 1\nquit 1\nend\n'+
    f"set ae_mean_low = {profile['ae_mean_low']}\nset ae_mean_high = {profile['ae_mean_high']}\nset ae_settling = {profile['ae_settling']}\nset gesture.seeded = 0\n"+
    'printf "AE_TARGET %u %u\\n", ae_mean_low, ae_mean_high\nmonitor resume\ndisconnect\nquit\n')
with (O/'openocd.log').open('wb') as log:
    server=subprocess.Popen([str(SDK/'openocd/bin/openocd.exe'),'-f','tools/debug/ftdi_ti.cfg','-f','tools/debug/debug_ti.cfg'],cwd=R,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
    try:
        for _ in range(60):
            if server.poll() is not None:raise RuntimeError('OpenOCD failed; see build/runtime/openocd.log')
            try:tcl('halt');break
            except OSError:time.sleep(.2)
        else:raise TimeoutError('OpenOCD startup timed out')
        result=subprocess.run([str(SDK/'toolchain/bin/riscv-none-embed-gdb.exe'),'--batch','-x',str(script),str(R/'prebuilt/network_camera.elf')],cwd=R,capture_output=True,text=True,timeout=60)
        (O/'outdoor.log').write_text(result.stdout+result.stderr)
        if result.returncode:raise RuntimeError('AE restore failed; see build/runtime/outdoor.log')
        assert 'AE_TARGET 148 168' in result.stdout
        print('Outdoor exposure profile applied: 148..168.')
    finally:
        if server.poll() is None:
            try:tcl('resume');tcl('shutdown')
            except OSError:pass
            try:server.wait(timeout=5)
            except subprocess.TimeoutExpired:server.terminate()
