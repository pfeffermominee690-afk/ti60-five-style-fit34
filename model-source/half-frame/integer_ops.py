import numpy as np
def rnd(a,b):
 a=np.asarray(a,dtype=np.int64);b=np.asarray(b,dtype=np.int64);q=a//b;v=a%b
 return q+((2*v>b)|((2*v==b)&((q&1)!=0)))

def shift(a,b):
 # signed shifts: positive multiply, negative round-to-nearest-even divide
 b=np.asarray(b);return np.where(b>=0,a*np.left_shift(np.int64(1),np.maximum(b,0)),rnd(a,np.left_shift(np.int64(1),np.maximum(-b,0))))

def exp(s):return np.rint(np.log2(s)).astype(np.int64)

def q16(a,e):return np.clip(shift(a,-16-e),-127,127).astype(np.int32)

def deq(a,e):return shift(a.astype(np.int64),e+16)

def conv(a,w,stride,dw):
 assert a.dtype==np.int32 and w.dtype==np.int32
 if w.shape[0]==1:return a@w[0,0]
 a=np.pad(a,((1,1),(1,1),(0,0)),mode='symmetric');h=(a.shape[0]-3)//stride+1;wid=(a.shape[1]-3)//stride+1
 z=np.zeros((h,wid,a.shape[2] if dw else w.shape[-1]),np.int32)
 for j in range(3):
  for k in range(3):
   v=a[j:j+h*stride:stride,k:k+wid*stride:stride]
   z+=v*w[j,k,:,0] if dw else v@w[j,k]
 return z