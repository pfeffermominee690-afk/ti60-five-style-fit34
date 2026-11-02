import os
os.environ['TF_CPP_MIN_LOG_LEVEL']='3'
import json, math, time, hashlib
from pathlib import Path
import numpy as np
import cv2
import tensorflow.compat.v1 as tf
from integer_ops import rnd,shift,exp,q16,deq,conv
d=Path(__file__).resolve().parent;r=d.parent;p=r.parent
styles=['Lu-Xun-woodcut','Leonardo-da-Vinci-Helicopter','Portrait-de-Metzinger(part)','Matisse-Woman-with-a-Hat','Van-Gogh-The-Starry-Night']
layers=json.loads((r/'integer/layers.json').read_text())
meta={**json.loads((r/'int8/quantization.json').read_text()),**json.loads((r/'int8-extra/quantization.json').read_text())}
lut=np.load(r/'integer/tanh-q8-u8.npy')
rows=[]
def config(st):
    ckpt=next((r/'p2gan/available_models'/st).glob('*.index')).with_suffix('')
    reader=tf.train.load_checkpoint(str(ckpt))
    pars={k:reader.get_tensor(k) for k in reader.get_variable_to_shape_map() if k.startswith('generator/') and 'Adam' not in k}
    wd=r/('int8-extra' if st in styles[3:] else 'int8')
    wpath=wd/(st+'--w8a8-raw-channel-pow2-weights.npz')
    weights=np.load(wpath);sc=meta[st]['modes']['w8a8-raw-channel-pow2']['activation_scales'];cfg=[]
    for l in layers:
        base=l['name'].rsplit('/',1)[0];wn=l['name'].replace('/','_');er=exp(sc[l['output']]);ei=exp(sc[l['input']]);ew=exp(weights[wn+'_scale']).reshape(-1)
        c={**l,'w':weights[wn+'_q'].astype(np.int32),'ei':ei,'ew':ew,'er':er,'base':base}
        if 'output/' not in l['name']:
            c['g']=np.rint(pars[base+'/InstanceNorm/gamma']*2**20).astype(np.int64)
            c['b']=np.rint(pars[base+'/InstanceNorm/beta']*2**18).astype(np.int64)
            c['eps']=np.rint(1e-6/np.power(2.,er*2)*2**24).astype(np.int64)
        cfg.append(c)
    return cfg,np.rint(pars['generator/output/biases']*65536).astype(np.int64),{k:int(exp(v)) for k,v in sc.items() if 'Relu' in k},hashlib.sha256(wpath.read_bytes()).hexdigest()
def infer(img,cfg,bias,re):
    a=rnd((img.astype(np.int64)*2-255)*65536,255);skips=[];macs=0;raw_elements=0
    for i,c in enumerate(cfg):
        if i in [8,10,12]:a=a.repeat(2,0).repeat(2,1)
        z=conv(q16(a,c['ei']),c['w'],c['stride'][1],c['kind']=='DepthwiseConv2dNative')
        macs+=int(z.shape[0]*z.shape[1]*c['w'].size);raw_elements+=z.size
        raw=np.clip(shift(z.astype(np.int64),c['ei']+c['ew']-c['er']),-127,127).astype(np.int64)
        if i==14:
            a=deq(raw,c['er'])+bias
            return lut[np.clip(rnd(a,256),-2048,2048)+2048],dict(conv_MACs=macs,raw_output_elements=raw_elements)
        n=raw.shape[0]*raw.shape[1];s=raw.sum((0,1));ss=(raw*raw).sum((0,1))
        variance=np.array([((int(v)*n-int(u)**2)<<24)//(n*n)+int(e) for u,v,e in zip(s,ss,c['eps'])],dtype=np.int64)
        root=np.array([max(1,math.isqrt(int(v))) for v in variance],dtype=np.int64)
        coef=rnd(c['g']*1024,root);adj=np.asarray([max(0,int(abs(v)).bit_length()-18) for v in coef],dtype=np.int64)
        coef=rnd(coef,1<<adj);offset=rnd(c['b'],1<<adj)-rnd(s*coef,n);a=shift(raw*coef+offset,adj-2)
        if i<=6:
            a=np.maximum(a,0);e=re[c['base']+'/Relu:0'];a=deq(q16(a,e),e)
            if i in [1,3,5]:skips.append(a.copy())
        if i in [7,9,11,13]:
            if i==7:a=a+skips[2]
            if i==9:a=a+skips[1]
            if i==11:a=a+skips[0]
            a=np.maximum(a,0);e=re['generator/Relu'+('' if i==7 else '_'+str((i-7)//2))+':0'];a=deq(q16(a,e),e)
for st in styles:
    cfg,bias,re,wh=config(st)
    for f in sorted((p/'artistic-review/results').glob('*-original.png')):
        scene=f.stem.replace('-original','');img=cv2.imread(str(f));assert img.shape==(480,640,3)
        t=time.perf_counter();full,bf=infer(img,cfg,bias,re);half,bh=infer(img[:,320:].copy(),cfg,bias,re)
        old=r/'integer'/(scene+'--'+st+'--integer.png')
        if old.exists():assert np.array_equal(full,cv2.imread(str(old))),('reference regression',scene,st)
        split=img.copy();split[:,320:]=half;control=img.copy();control[:,320:]=full[:,320:]
        assert np.array_equal(split[:,:320],img[:,:320])
        key=scene+'--'+st
        for suffix,a in [('split',split),('full-context-split',control),('full',full),('right-only',half)]:
            assert cv2.imwrite(str(d/(key+'--'+suffix+'.png')),a)
        err=half.astype(float)-full[:,320:].astype(float)
        rows.append(dict(scene=scene,style=st,weight_sha256=wh,full=bf,right_half=bh,crop_vs_full_right_MAE=float(np.abs(err).mean()),left_unchanged=True,software_seconds=time.perf_counter()-t))
        (d/'results.json').write_text(json.dumps(rows,indent=2),encoding='utf8');print(json.dumps(rows[-1]),flush=True)
assert len(rows)==30
(d/'complete.json').write_text(json.dumps(dict(complete=True,comparisons=30,styles=styles,board_touched=False,implementation='Full-integer software reference; fixed existing quantization scales; right 320x480 separately inferred, not cropped full inference',hardware_fps_verified=False),indent=2))
