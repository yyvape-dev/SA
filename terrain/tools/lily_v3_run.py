import sys, json, numpy as np
sys.argv=['x']; exec(open('/home/claude/lkp/build.py').read().split('meta={}')[0])
from PIL import Image
import matplotlib.colors as mc
def pinkfix(r):
    r=r.copy(); hs=mc.rgb_to_hsv(r[...,:3]/255.); h=hs[...,0]*360; S=hs[...,1]
    yy=np.where(r[...,3].any(1))[0]; low=np.zeros(h.shape,bool); low[yy.min()+150:]=True
    p=low&(r[...,3]>0)&(S>0.12)&((h>=280)|(h<=14))
    hs[...,1]=np.where(p,S*0.25,S); hs[...,0]=np.where(p,25/360,hs[...,0])
    r[...,:3]=np.clip(mc.hsv_to_rgb(hs)*255,0,255).astype(np.uint8); return r
idx=list(range(34,50))
fr=[pinkfix(clean2(despark(key_soft(np.array(Image.open(f'f/{i+1:03d}.png').convert('RGB')).astype(np.float32))))) for i in idx]
ys=[];xs=[];cx=[];gy=[]
for r in fr:
    yy,xx=np.where(r[...,3]>8); ys+=[yy.min(),yy.max()]; xs+=[xx.min(),xx.max()]; gy.append(yy.max())
    y2,x2=np.where(r[...,3]>128); top=y2<y2.min()+200; cx.append(np.median(x2[top]))  # 上半身の中心
P=8; x0,y0,x1,y1=max(0,min(xs)-P),max(0,min(ys)-P),min(1280,max(xs)+P+1),min(720,max(ys)+P+1)
cw,ch=int(x1-x0),int(y1-y0); cols=6; rows=-(-len(fr)//cols)
sh=Image.new('RGBA',(cw*cols,ch*rows))
for k,r in enumerate(fr): sh.paste(Image.fromarray(rim(r[y0:y1,x0:x1])),((k%cols)*cw,(k//cols)*ch))
sh.save('/tmp/sa_ro/ally/side_run_lily_v3.webp','WEBP',lossless=True,method=4)
m={'f':'side_run_lily_v3.webp','cols':cols,'cw':cw,'ch':ch,'n':len(fr),'durs':[42]*len(fr),'ph':590.0,'ax':round(float(np.median(cx)-x0),1),'ay':int(np.median(gy)-y0)}
print(m)
d=json.load(open('/tmp/sa_ro/ally/side_meta.json')); d['run_lily']=m; json.dump(d,open('/tmp/sa_ro/ally/side_meta.json','w'),ensure_ascii=False)
s=0.3; prev=Image.new('RGBA',(int(cw*s)*8,int(ch*s)*2),(200,180,140,255))
for k,r in enumerate(fr): prev.alpha_composite(Image.fromarray(r[y0:y1,x0:x1]).resize((int(cw*s),int(ch*s))),((k%8)*int(cw*s),(k//8)*int(ch*s)))
prev.convert('RGB').save('prev.png')
