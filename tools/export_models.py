"""Versioned five-style bundle; preserve and regression-check the stable two-style pack."""
from pathlib import Path
import sys,struct,json,hashlib
import numpy as np
from sketch_compatibility import adapt
R=Path(__file__).resolve().parents[1]
base=R/'model-source/half-frame'
sys.path.insert(0,str(base))
src=(base/'run.py').read_text(encoding='utf-8').split('\nfor st in styles:')[0]
ns={'__file__':str(base/'run.py')};exec(compile(src,str(base/'run.py'),'exec'),ns)
styles=['Lu-Xun-woodcut','Portrait-de-Metzinger(part)','Leonardo-da-Vinci-Helicopter','Matisse-Woman-with-a-Hat','Van-Gogh-The-Starry-Night']
# 64-byte versioned header: magic,count,desc[5],lut[5],descriptor_words,version,reserved[2].
blob=bytearray(64+5*15*48)
struct.pack_into('<16I',blob,0,0x50324739,5,*[64+i*720 for i in range(5)],*([0]*5),12,1,0,0)
old=(R/'models/models.bin').read_bytes();oh=struct.unpack_from('<8I',old)
def append(data):
 while len(blob)%16:blob.append(0)
 off=len(blob);blob.extend(data);return off
records=[]
template=[];lines=iter((R/'model-source/config.txt').read_text().splitlines())
for i in range(15):
 h=list(map(int,next(lines).split()));template.append(h)
 for _ in range(h[3]):next(lines)
for stidx,st in enumerate(styles):
 cfg,bias,re,sha=ns['config'](st)
 if stidx==2:adapt(cfg,re)
 raw=np.arange(256,dtype=np.uint8).view(np.int8).astype(np.int64)
 lut=np.zeros((4,256),np.uint8)
 for ch in range(3):
  e=np.broadcast_to(cfg[-1]['er'],(3,))[ch]
  lut[ch]=ns['lut'][np.clip(ns['rnd'](ns['deq'](raw,e)+bias[ch],256),-2048,2048)+2048]
 lo=append(lut.tobytes());struct.pack_into('<I',blob,28+stidx*4,lo)
 if stidx<2:assert lut.tobytes()==old[oh[4+stidx]:oh[4+stidx]+1024],('lut',st)
 prev=None;encoder={};iw,ih=320,480
 for i,c in enumerate(cfg):
  h,w,ci,co,k,s,u,*_=template[i]
  assert c['w'].shape[2]==ci and c['stride'][1]==s
  mode=2 if i==14 else 1 if k==3 else 0
  weights=c['w'].astype(np.int8).view(np.uint8)
  if mode==0:packed=weights.reshape(ci,co//16,16).transpose(1,0,2).copy()
  elif mode==2:
   packed=np.zeros((9,ci,4),np.uint8);packed[:,:,:3]=weights.reshape(9,ci,3)
  else:
   padded=np.zeros((9,((ci+15)//16)*16),np.uint8);padded[:,:ci]=weights.reshape(9,ci)
   packed=padded.reshape(9,-1,16).transpose(1,0,2).copy()
  wo=append(packed.tobytes());params=bytearray()
  er=np.broadcast_to(c['er'],(co,));sh=np.broadcast_to(c['ei']+c['ew']-c['er'],(co,))
  for ch in range(co):
   g,b,ep=(int(c['g'][ch]),int(c['b'][ch]),int(c['eps'][ch])) if i<14 else (0,int(bias[ch]),0)
   assert -31<=sh[ch]<=31
   params.extend(struct.pack('<6I',*[int(x)&0xffffffff for x in [sh[ch],er[ch],g,b,ep,ep>>32]]))
  po=append(params)
  relu=int(i<=7 or i in [9,11,13]);ne=int(cfg[min(i+1,14)]['ei']);resid={7:2,9:1,11:0}.get(i,-1)
  skip=prev[2] if prev else -1;inputrel,inputexp=prev[:2] if prev else (0,-5)
  sr,se=encoder[skip] if skip>=0 else (0,-3)
  assert -8<=inputexp<=7 and -8<=se<=7
  flags=mode|((s==2)<<2)|((u==2)<<3)|((skip>=0)<<4)|(inputrel<<5)|(sr<<6)|((skip+1 if skip>=0 else 0)<<7)|(({1:1,3:2,5:3}.get(i,0))<<9)
  d=[iw,ih,w,h,ci,co,flags,(inputexp&15)|((se&15)<<4),wo,po,h*w*co,skip&0xffffffff]
  struct.pack_into('<12I',blob,64+stidx*720+i*48,*d)
  if stidx<2:
   od=struct.unpack_from('<12I',old,oh[2+stidx]+i*48)
   assert d[:8]==list(od[:8]) and d[10:]==list(od[10:]),('descriptor',st,i)
   assert packed.tobytes()==old[od[8]:od[8]+packed.size],('weights',st,i)
   assert params==old[od[9]:od[9]+len(params)],('params',st,i)
  if i in (1,3,5):encoder[{1:0,3:1,5:2}[i]]=(relu,ne)
  prev=(relu,ne,resid);iw,ih=w,h
 records.append({'index':stidx,'style':st,'weight_sha256':sha})
 print('Packed and checked',st,flush=True)
assert len(blob)<0x100000
assert blob == (R/'models/models-five-fit24-compat.bin').read_bytes(), 'Rebuilt model differs from preserved bundle'
(R/'build').mkdir(exist_ok=True)
(R/'build/models-five-fit24-compat.bin').write_bytes(blob)
(R/'build/models-five-fit24-compat.json').write_text(json.dumps({'styles':records,'bytes':len(blob),'sha256':hashlib.sha256(blob).hexdigest(),'old_two_payloads_exact':True,'header_bytes':64,'magic':'0x50324739'},indent=2),encoding='utf-8')
print('SUCCESS',len(blob),flush=True)
