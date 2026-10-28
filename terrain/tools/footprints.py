# 建物の切り抜きから、土台（地面に接する平行四辺形）の角を取り出して data/bld.json に足す。
import json, numpy as np
from PIL import Image
meta=json.load(open('data/bld.json'))
for fn,m in meta.items():
    if 'castle' in fn: continue
    a=np.asarray(Image.open(fn))[...,3]>128; h,w=a.shape
    bot=np.array([(np.where(a[:,x])[0].max() if a[:,x].any() else -1) for x in range(w)],float)
    xb=int(np.argmax(bot)); yb=bot[xb]
    def edge(side):
        x1=xb+side*int(.10*w); x2=xb+side*int(.28*w); x1=min(max(x1,0),w-1); x2=min(max(x2,0),w-1)
        k=(bot[x2]-bot[x1])/(x2-x1)
        x=xb; last=xb
        while 0<=x+side<w:
            x+=side
            if abs(bot[x]-(yb+k*(x-xb)))<=7 and bot[x]>0: last=x
            elif abs(x-last)>int(.08*w): break
        return last,yb+k*(last-xb)
    (lx,ly),(rx,ry)=edge(-1),edge(1)
    tx,ty=lx+rx-xb,ly+ry-yb
    m['fp']=[[round(tx,1),round(ty,1)],[round(rx,1),round(ry,1)],[round(xb,1),round(yb,1)],[round(lx,1),round(ly,1)]]  # T,R,B,L
    print(fn.split('/')[-1],m['fp'])
json.dump(meta,open('data/bld.json','w'),indent=1)
