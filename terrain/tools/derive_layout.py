# ①の絵から、区画・道・川の配置を取り出して data/ に保存する（一度だけ使う。以降の配置はコードのデータが正）。
import cv2, numpy as np, json, sys
src=sys.argv[1]; out=sys.argv[2]
im=cv2.imread(src); H,W=im.shape[:2]
hsv=cv2.cvtColor(im,cv2.COLOR_BGR2HSV).astype(float)
h=hsv[...,0]*2; s=hsv[...,1]/255; v=hsv[...,2]/255
b,g,r=[im[...,i].astype(float) for i in range(3)]
yy=np.arange(H)[:,None]*np.ones((1,W))
ground=yy>560
plot=(h>10)&(h<32)&(s>.35)&(s<.75)&(v>.3)&(v<.7)
road=(h>=26)&(h<48)&(s>.22)&(s<.55)&(v>.62)
water=((b>r+20)&(b>=g-8)&(v>.45))|((v>.82)&(s<.25)&(b>=r))
def clean(m,k,minarea):
    m=m.astype(np.uint8)
    m=cv2.morphologyEx(m,cv2.MORPH_CLOSE,np.ones((k,k),np.uint8))
    m=cv2.morphologyEx(m,cv2.MORPH_OPEN,np.ones((k//2*2+1,k//2*2+1),np.uint8))
    n,lab,st,_=cv2.connectedComponentsWithStats(m)
    o=np.zeros_like(m)
    for i in range(1,n):
        if st[i,4]>=minarea: o[lab==i]=1
    return o
P=clean(plot&ground,9,2500); R=clean(road&ground,5,1500); Wt=clean(water&ground&(yy>900),7,3000)
# 区画：連結成分ごとに最小外接矩形
n,lab,st,cen=cv2.connectedComponentsWithStats(P)
plots=[]
for i in range(1,n):
    cnt=cv2.findContours((lab==i).astype(np.uint8),cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)[0][0]
    hull=cv2.convexHull(cnt)
    eps=0.04*cv2.arcLength(hull,True)
    ap=cv2.approxPolyDP(hull,eps,True).reshape(-1,2)
    if len(ap)!=4:
        ap=cv2.boxPoints(cv2.minAreaRect(hull)).astype(int)
    plots.append({'poly':[[int(x),int(y)] for x,y in ap],'cx':int(cen[i][0]),'cy':int(cen[i][1])})
plots.sort(key=lambda p:p['cy'])
for k,p in enumerate(plots): p['id']='P%d'%(k+1)
# スプラット（半解像度、R=道 G=区画 B=川）。縁をぼかす
sw,sh=W//2,H//2
def sm(m,k): 
    a=cv2.resize(m.astype(np.float32),(sw,sh),interpolation=cv2.INTER_AREA)
    return cv2.GaussianBlur(a,(0,0),k)
sp=np.zeros((sh,sw,4),np.uint8)
sp[...,2]=np.clip(sm(R,1.6)*255*1.3,0,255)   # BGRA: B=R(道)
sp[...,1]=np.clip(sm(P,1.2)*255*1.3,0,255)   # G=区画
sp[...,0]=np.clip(sm(Wt,2.0)*255*1.3,0,255)  # R=川
sp[...,3]=255
cv2.imwrite(out+'/splat.png',sp)
json.dump({'size':[W,H],'plots':plots},open(out+'/layout.json','w'),ensure_ascii=False)
print(len(plots),'plots',[p['id'] for p in plots])
