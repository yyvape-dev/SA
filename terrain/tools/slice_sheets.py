# GPTの素材シート2枚を切り出す。ground: 3×2の正方形 / props: マゼンタ背景の切り抜き10個。
import sys, numpy as np, cv2, json
from PIL import Image
gsheet, psheet = sys.argv[1], sys.argv[2]
kinds=['grass','forest','road','plot','rock','water']
g=Image.open(gsheet).convert('RGB'); W,H=g.size; print('ground sheet',g.size)
cw,ch=W//3,H//2; rep={}
for i,k in enumerate(kinds):
    r,c=divmod(i,3); t=g.crop((c*cw,r*ch,(c+1)*cw,(r+1)*ch))
    a=np.asarray(t).astype(float)
    # つなぎ目の測定：左右・上下の端どうしの差 / 隣り合う列の差
    ex=np.abs(a[:,0]-a[:,-1]).mean(); ey=np.abs(a[0]-a[-1]).mean()
    bx=np.abs(a[:,100]-a[:,101]).mean(); by=np.abs(a[100]-a[101]).mean()
    rep[k]={'edgeX':round(ex,1),'edgeY':round(ey,1),'baseX':round(bx,1),'baseY':round(by,1)}
    t.save(f'assets/ground/g{i+1}_{k}.png')
print(json.dumps(rep,ensure_ascii=False))
names=['pineL','pineM','pineS','pineT','bush','rockM','rockS','boulder','fence','marker']
p=cv2.imread(psheet); H,W=p.shape[:2]; print('props sheet',(W,H))
b,gc,r=[p[...,i].astype(float) for i in range(3)]
mag=np.minimum(r,b)-gc                    # マゼンタらしさ
alpha=np.clip((130-mag)/70,0,1)            # mag>130で透明、<60で不透明
# にじみ除去：縁の画素のR/BをGへ寄せる
spill=np.clip((mag-10)/120,0,1)
r2=r-(r-gc)*spill*0.9; b2=b-(b-gc)*spill*0.9
pink=(r2>gc+10)&(b2>gc+10)&(alpha<0.999)|((r2>gc+25)&(b2>gc+25))
r2=np.where(pink,gc*1.0,r2); b2=np.where(pink,gc*0.7,b2)
rgba=np.dstack([b2,gc,r2,alpha*255]).clip(0,255).astype(np.uint8)
m=(alpha>0.5).astype(np.uint8); m=cv2.morphologyEx(m,cv2.MORPH_CLOSE,np.ones((9,9),np.uint8))
n,lab,st,cen=cv2.connectedComponentsWithStats(m)
comps=[i for i in range(1,n) if st[i,4]>800]
# 左上→右へ（行ごと）に並べる：重心で並べ替え（2行）
comps.sort(key=lambda i:(0 if cen[i][1]<H/2 else 1, cen[i][0]))
print('components',len(comps))
meta={}
for k,i in enumerate(comps[:10]):
    x,y,w,h=st[i,:4]; pad=4
    x0,y0,x1,y1=max(0,x-pad),max(0,y-pad),min(W,x+w+pad),min(H,y+h+pad)
    sub=rgba[y0:y1,x0:x1].copy(); mk=(lab[y0:y1,x0:x1]==i)
    mk=cv2.dilate(mk.astype(np.uint8),np.ones((5,5),np.uint8))>0
    sub[...,3]=np.where(mk,sub[...,3],0)
    out=cv2.cvtColor(sub,cv2.COLOR_BGRA2RGBA); fn=f'assets/props/p{k+1:02d}_{names[k]}.png'
    Image.fromarray(out).save(fn); meta[names[k]]={'file':fn,'w':int(x1-x0),'h':int(y1-y0)}
print(json.dumps(meta,ensure_ascii=False))
