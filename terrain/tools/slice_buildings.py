# 建物の素材シート（マゼンタ背景）を切り出す。smithy/tavern：左から3段階、castle：1つ。
import sys, json, numpy as np, cv2
from PIL import Image
def key(path):
    p=cv2.imread(path); b,g,r=[p[...,i].astype(float) for i in range(3)]
    mag=np.minimum(r,b)-g
    alpha=np.clip((130-mag)/70,0,1)
    spill=np.clip((mag-10)/120,0,1)
    r2=r-(r-g)*spill*0.9; b2=b-(b-g)*spill*0.9
    pink=((r2>g+10)&(b2>g+10)&(alpha<0.999))|((r2>g+25)&(b2>g+25))
    r2=np.where(pink,g,r2); b2=np.where(pink,g*0.7,b2)
    rgba=np.dstack([b2,g,r2,alpha*255]).clip(0,255).astype(np.uint8)
    return rgba,(alpha>0.35).astype(np.uint8)
def cut(rgba,m,minarea=3000):
    m2=cv2.morphologyEx(m,cv2.MORPH_CLOSE,np.ones((15,15),np.uint8))
    n,lab,st,cen=cv2.connectedComponentsWithStats(m2)
    comps=[i for i in range(1,n) if st[i,4]>minarea]; comps.sort(key=lambda i:cen[i][0])
    outs=[]
    for i in comps:
        x,y,w,h=st[i,:4]; pad=4; x0,y0,x1,y1=max(0,x-pad),max(0,y-pad),min(rgba.shape[1],x+w+pad),min(rgba.shape[0],y+h+pad)
        sub=rgba[y0:y1,x0:x1].copy(); mk=cv2.dilate((lab[y0:y1,x0:x1]==i).astype(np.uint8),np.ones((5,5),np.uint8))>0
        sub[...,3]=np.where(mk,sub[...,3],0); outs.append(cv2.cvtColor(sub,cv2.COLOR_BGRA2RGBA))
    return outs
def footprint(a):
    # 土台の4隅（手前B・左L・右R・奥T）。手前Bは下端の最も低い点、左Lと右Rは、下端の高さの帯の左右の端（柱や屋根の張り出しを避け、6px内側）。奥Tは平行四辺形として求める。
    al=a[...,3]>128; h,w=al.shape
    by=np.array([(np.where(al[:,x])[0].max() if al[:,x].any() else -1) for x in range(w)],float)
    x0=int(np.argmax(by)); yb=by[x0]; xs=np.where(by>yb-0.30*h)[0]; xl,xr=int(xs.min())+6,int(xs.max())-6
    return {'B':[float(x0),float(yb)],'L':[float(xl),float(by[xl])],'R':[float(xr),float(by[xr])]}
meta={}
for name,path in (('smithy',sys.argv[1]),('tavern',sys.argv[2]),('castle',sys.argv[3])):
    rgba,m=key(path); parts=cut(rgba,m); print(name,'parts',len(parts),[p.shape[:2] for p in parts])
    for k,a in enumerate(parts):
        fn=f'assets/bld/{name}_{k+1}.png' if name!='castle' else 'assets/bld/castle.png'
        Image.fromarray(a).save(fn)
        al=a[...,3]>128; ys,xs=np.where(al); yb=ys.max(); band=al[max(0,yb-int(0.04*a.shape[0])):yb+1]; bx=np.where(band.any(axis=0))[0]
        meta[fn]={'w':int(a.shape[1]),'h':int(a.shape[0]),'ax':round(float((bx.min()+bx.max())/2/a.shape[1]),3),'ay':round(float((yb+1)/a.shape[0]),3)}
        if name!='castle': meta[fn]['fp']={k:[round(v[0],1),round(v[1],1)] for k,v in footprint(a).items()}
json.dump(meta,open('data/bld.json','w'),indent=1); print(json.dumps(meta))
