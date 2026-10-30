# 新リリィの攻撃3本：元mp4のコマ → key_soft → 細い光の線を消す → 共通枠で切る → シート → 縁(RIM5/0.32/RIMC0)
import sys, json, numpy as np
sys.path.insert(0,'/tmp/sa_ro/terrain/tools')
from key_soft import key_soft
from PIL import Image
from scipy import ndimage as ndi
import matplotlib.colors as mc
SEL={1:[0,10,14,28,31,32,33,34,36,40,44,48,52,56,62,68],
     2:[0,20,25,31,37,41,43,47,49,51,53,55,57,59,62,68],
     3:[0,10,16,22,33,38,40,43,47,51,54,56,58,60,63,68]}
NAME={3:'duel_lily_1_v3.webp',2:'duel_lily_2_v3.webp',1:'duel_lily_3_v3.webp'}
def despark(r):
    al=r[...,3]/255.; m=al>0.3
    body=ndi.binary_dilation(ndi.binary_opening(m,structure=np.ones((7,7))),iterations=3)
    hs=mc.rgb_to_hsv(r[...,:3]/255.); light=(hs[...,2]>0.7)&(hs[...,1]<0.35) | ((hs[...,0]*360>250)&(hs[...,1]>0.2))
    kill=(al>0)&~body&light
    kill=ndi.binary_dilation(kill,iterations=1)&~body
    r=r.copy(); r[...,3]=np.where(kill,0,r[...,3])
    # 体から離れた残りかす
    m=r[...,3]>8; lab,n=ndi.label(m,structure=np.ones((3,3)))
    if n>1:
        sz=ndi.sum(m,lab,range(1,n+1)); big=np.argmax(sz)+1; keep=np.isin(lab,[k+1 for k,z in enumerate(sz) if z>800 or k+1==big])
        r[...,3]=np.where(keep,r[...,3],0)
    return r
def clean2(r):
    r=r.copy(); al=r[...,3]>40
    hs=mc.rgb_to_hsv(r[...,:3]/255.); h=hs[...,0]*360; S=hs[...,1]; V=hs[...,2]
    g=(h>=58)&(h<=170)&(S>0.06)&(r[...,3]>0)   # 緑・オリーブかぶり（元の服に緑は無い）
    hs[...,1]=np.where(g,S*0.12,S); hs[...,0]=np.where(g,30/360,hs[...,0])
    r[...,:3]=np.clip(mc.hsv_to_rgb(hs)*255,0,255).astype(np.uint8)
    wh=al&(((V>0.72)&(S<0.3))|((V>0.6)&(h>250)&(h<330))); solid=al&~wh
    lab,n=ndi.label(wh,structure=np.ones((3,3)))
    if n:
        sz=ndi.sum(wh,lab,range(1,n+1)); top=np.where(al.any(1))[0].min(); tops=np.array(ndi.minimum(np.indices(wh.shape)[0],lab,range(1,n+1))); cand=np.where(tops<top+60)[0]; hair=(cand[np.argmax(sz[cand])]+1) if len(cand) else -1  # 頭の高さにある一番大きい白＝髪
        far=ndi.distance_transform_edt(~solid)>3
        kill=wh&(lab!=hair)&far
        kill=ndi.binary_dilation(kill,iterations=2)&wh&(lab!=hair)
        r[...,3]=np.where(kill,0,r[...,3])
    core=r[...,3]>200; r[...,3]=np.where((r[...,3]<160)&(ndi.distance_transform_edt(~core)>4),0,r[...,3])  # 体から離れた薄い線
    m=r[...,3]>8; lab,n=ndi.label(m,structure=np.ones((3,3)))
    if n>1:
        sz=ndi.sum(m,lab,range(1,n+1)); big=np.argmax(sz)+1
        r[...,3]=np.where((lab==big)|(lab==0),r[...,3],0)
    return r
def rim(o,SZ=5,A=0.32):
    a=o.astype(np.float32); al=a[...,3]/255; rgb=a[...,:3]
    d=ndi.grey_dilation(al,size=(SZ,SZ)); d=ndi.gaussian_filter(d,1.2*SZ/7)
    rm=np.clip(d-al,0,1)*A; oa=al+rm*(1-al)
    col=(rgb*al[...,None]+np.array([28,20,16])*rm[...,None]*(1-al[...,None]))/np.maximum(oa[...,None],1e-6)
    return np.dstack([np.clip(col,0,255),oa*255]).astype(np.uint8)
meta={}
for v,idx in SEL.items():
    fr=[clean2(despark(key_soft(np.array(Image.open(f'/home/claude/lv/f{v}/{i+1:03d}.png').convert('RGB')).astype(np.float32)))) for i in idx]
    ys=[];xs=[]
    for r in fr:
        yy,xx=np.where(r[...,3]>8); ys+=[yy.min(),yy.max()]; xs+=[xx.min(),xx.max()]
    P=10; x0,y0,x1,y1=min(xs)-P,min(ys)-P,max(xs)+P+1,max(ys)+P+1
    x0,y0=max(0,x0),max(0,y0); x1,y1=min(1280,x1),min(720,y1)
    cw,ch=x1-x0,y1-y0; cols=6; rows=-(-16//cols)
    sh=Image.new('RGBA',(cw*cols,ch*rows))
    for k,r in enumerate(fr): sh.paste(Image.fromarray(rim(r[y0:y1,x0:x1])),((k%cols)*cw,(k//cols)*ch))
    sh.save(f'/tmp/sa_ro/ally/{NAME[v]}','WEBP',lossless=True,method=4)
    yy,xx=np.where(fr[0][y0:y1,x0:x1,3]>128)
    meta[NAME[v]]={'cw':int(cw),'ch':int(ch),'idle':{'x':float(xx.min()),'w':float(xx.max()-xx.min()+1),'h':float(yy.max()-yy.min()+1)},'pad':float(ch-1-yy.max()),'src':idx}
    for k in (0,7): Image.fromarray(fr[k][y0:y1,x0:x1]).save(f'/home/claude/lkp/chk_{v}_{k}.png')
json.dump(meta,open('/home/claude/lkp/meta_new.json','w'),indent=1); print(json.dumps({k:{a:b for a,b in m.items() if a!='src'} for k,m in meta.items()}))
