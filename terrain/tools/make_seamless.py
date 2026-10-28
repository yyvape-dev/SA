# 継ぎ目の目立つタイルを、ずらして重ねる方式で繰り返し可能にする（端どうしが連続する）。
import sys, glob, numpy as np
from PIL import Image
def seamless(a):
    h,w=a.shape[:2]
    ys=np.sin(np.linspace(0,np.pi,h,endpoint=False))[:,None]; xs=np.sin(np.linspace(0,np.pi,w,endpoint=False))[None,:]
    wgt=(ys**2)*(xs**2)                      # 中心=1、端=0
    wgt=np.clip(wgt*1.0,0,1)[...,None]
    r=np.roll(a,(h//2,w//2),axis=(0,1))
    return a*wgt+r*(1-wgt)
for f in sorted(glob.glob('assets/ground/orig/g*.png')):
    a=np.asarray(Image.open(f).convert('RGB')).astype(float)
    o=seamless(a)
    ex=np.abs(o[:,0]-o[:,-1]).mean(); ey=np.abs(o[0]-o[-1]).mean(); bx=np.abs(o[:,100]-o[:,101]).mean()
    Image.fromarray(o.clip(0,255).astype(np.uint8)).save(f.replace('/orig',''))
    print(f.split('/')[-1],'edge',round(ex,1),round(ey,1),'base',round(bx,1))
