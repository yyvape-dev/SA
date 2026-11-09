"""Deterministic split/key of generated static street bars; no resizing or repainting."""
from pathlib import Path
import json,hashlib
import numpy as np
from scipy import ndimage
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
src=ROOT/'art/painted_bt_src/street_bars_generated_20261109.png'
im=Image.open(src).convert('RGB');w,h=im.size;report=[]
for i,name in enumerate(['sbar_a','sbar_b','sbar_c','sbar_d']):
 x0=(i%2)*w//2;y0=(i//2)*h//2;x1=((i%2)+1)*w//2;y1=((i//2)+1)*h//2
 rgb=np.asarray(im.crop((x0,y0,x1,y1)));r,g,b=(rgb[:,:,j].astype(np.int16) for j in range(3))
 key=(r>180)&(b>180)&(g<100)&(r-g>110)&(b-g>110)
 labels,_=ndimage.label(key);edges=np.unique(np.concatenate([labels[0],labels[-1],labels[:,0],labels[:,-1]]));remove=np.isin(labels,edges[edges!=0])
 alpha=np.where(remove,0,255).astype(np.uint8);ys,xs=np.where(alpha>0)
 box=(max(0,int(xs.min())-2),max(0,int(ys.min())-2),min(rgb.shape[1],int(xs.max())+3),min(rgb.shape[0],int(ys.max())+3))
 out=Image.fromarray(np.dstack([rgb,alpha])).crop(box);dst=ROOT/'art/painted_bt'/f'{name}.png';out.save(dst,optimize=True)
 report.append({'asset':name,'source_cell':[x0,y0,x1,y1],'crop':box,'size':list(out.size),'resized':False,'sha256':hashlib.sha256(dst.read_bytes()).hexdigest()})
print(json.dumps({'source_size':[w,h],'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'assets':report},indent=2))

# Reuse a clean painted cloth patch for the small remaining hanging cloth.
cloth=Image.open(ROOT/"art/painted_bt/sbar_a.png");cw,ch=cloth.size
cloth.crop((int(cw*.25),int(ch*.045),int(cw*.72),int(ch*.17))).convert("RGB").save(ROOT/"art/painted_bt/tex_cloth.png")
