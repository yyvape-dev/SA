# 街の配置をコードの直線データで作る（基準画像の画素）。辺の向きは等角 (2,1) と (-2,1)
# 交差点 C を基準に、(u,v) の格子で区画を並べる：画面 x=Cx+170(u-v), y=Cy+85(u+v)
import json
W,H=5640,1672
C1=(470,1000); C2=(1400,1000); C3=(2330,1000); C4=(3260,1000); C5=(4190,1000); C6=(5120,1000)
def P(c,u,v): return (c[0]+170*(u-v), c[1]+85*(u+v))
CELLS=[(1.5,.5),(1.5,-.5),(-1.5,.5),(-1.5,-.5),(.5,1.5),(-.5,1.5),(.5,-1.5),(-.5,-1.5)]
plots=[]
for c,area in ((C1,'home'),(C2,'east'),(C3,'lake'),(C4,'forest'),(C5,'pass2'),(C6,'capital')):
    for u,v in CELLS:
        x,y=P(c,u,v); plots.append({'id':f'P{len(plots)+1}','area':area,'poly':[[x,y-50],[x+100,y],[x,y+50],[x-100,y]]})
def plaza(c,k=.85): return [[c[0],c[1]-135*k],[c[0]+270*k,c[1]],[c[0],c[1]+135*k],[c[0]-270*k,c[1]]]
plazas=[{'center':list(C1),'kind':'fountain','poly':plaza(C1)},{'center':list(C2),'kind':'well','poly':plaza(C2)},{'center':list(C3),'kind':'well','poly':plaza(C3)},{'center':list(C4),'kind':'fountain','poly':plaza(C4)},{'center':list(C5),'kind':'well','poly':plaza(C5)},{'center':list(C6),'kind':'fountain','poly':plaza(C6)}]
# 大通り2本：どちらも、街(C1)→東の入口の角→東の街(C2)→東の端へ。ひし形の環ができる
roads=[
 {'w':40,'pts':[[20,775],[935,1232.5],list(C2),[1865,767.5],list(C3),[2795,1232.5],list(C4),[3725,767.5],list(C5),[4655,1232.5],list(C6),[W,740]]},
 {'w':40,'pts':[[20,1225],[935,767.5],list(C2),[1865,1232.5],list(C3),[2795,767.5],list(C4),[3725,1232.5],list(C5),[4655,767.5],list(C6),[W,1260]]},
 {'w':34,'pts':[[300,716],[300,745],list(P(C1,-1,-1)),list(P(C1,-1,0))]},
]
lakes=[[[640,520],[700,480],[800,455],[941,440],[941,610],[860,600],[780,585],[700,560]],
       [[1560,520],[1640,470],[1780,450],[1900,470],[1930,560],[1840,650],[1700,620],[1590,590]],
       [[2060,560],[2160,470],[2330,430],[2520,450],[2640,520],[2620,690],[2470,720],[2300,700],[2150,690],[2080,640]],
       [[2240,1330],[2330,1300],[2450,1320],[2500,1400],[2420,1460],[2290,1450],[2230,1400]]]
signs=[{'id':'N','x':60,'y':748,'label':'山道'},{'id':'W','x':62,'y':1195,'label':'西の川'},
       {'id':'gate','x':896,'y':734,'label':'東の地','area':'east'},
       {'id':'lakegate','x':1826,'y':734,'label':'湖畔','area':'lake'},
       {'id':'forestgate','x':2756,'y':734,'label':'東の森','area':'forest'},
       {'id':'passgate','x':3686,'y':734,'label':'峠の砦','area':'pass2'},
       {'id':'capgate','x':4616,'y':734,'label':'王都の城門','area':'capital'},
       {'id':'NE','x':W-45,'y':705,'label':'北の峠'},{'id':'SE','x':W-45,'y':1232,'label':'南の街道'}]
# 区域：x の範囲。cost=開拓の物資、income=開拓後の毎週の物資、theme=木の密度
areas=[{'id':'east','name':'東の地','x0':950,'x1':1880,'locked':True,'cost':6,'income':2,'forest':.35},
       {'id':'lake','name':'湖畔','x0':1880,'x1':2810,'locked':True,'cost':10,'income':3,'forest':.7},
       {'id':'forest','name':'東の森','x0':2810,'x1':3740,'locked':True,'cost':14,'income':4,'forest':1.35},
       {'id':'pass2','name':'峠の砦','x0':3740,'x1':4670,'locked':True,'cost':18,'income':5,'forest':.5},
       {'id':'capital','name':'王都の城門','x0':4670,'locked':True,'cost':22,'income':6,'forest':.2}]
d=json.load(open('data/layout.json'))
d.update(world={'w':W,'h':H},plots=plots,roads=roads,plazas=plazas,lakes=lakes,signs=signs,areas=areas)
for k in ('plaza','fountain','exits'): d.pop(k,None)
json.dump(d,open('data/layout.json','w'),indent=1); print(len(plots),'plots')
