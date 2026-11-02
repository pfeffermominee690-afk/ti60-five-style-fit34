"""Explicit fit24 sketch quantization variant; never overwrite original calibration."""
import numpy as np
def adapt(cfg,re):
 changes=[]
 for i,c in enumerate(cfg):
  if int(c['ei'])==0:c['ei']=np.asarray(-1);changes.append({'layer':i,'input_exponent':[0,-1]})
  if i==14:continue
  # Enforce the existing hardware's theoretical adjust<=10 for constant input.
  # ceil(|gamma|*1024/(2^28-1)) is sufficient even after nearest-even division.
  roots=(np.abs(c['g'])*1024+(2**28-2))//(2**28-1)
  eps=np.maximum(c['eps'],roots*roots)
  channels=np.nonzero(eps!=c['eps'])[0].tolist()
  if channels:changes.append({'layer':i,'epsilon_raised_channels':channels})
  c['eps']=eps
 for key,value in list(re.items()):
  if value==0:re[key]=-1
 return changes
