# 街の配置をコードの直線データで作る（基準画像の画素）。辺の向きは等角 (2,1) と (-2,1)
# 交差点 C を基準に、(u,v) の格子で区画を並べる：画面 x=Cx+170(u-v), y=Cy+85(u+v)
import json
W,H=1960,1672
C1=(470,1000); C2=(1400,1000)
def P(c,u,v): return (c[0]+170*(u-v), c[1]+85*(u+v))
CELLS=[(1.5,.5),(1.5,-.5),(-1.5,.5),(-1.5,-.5),(.5,1.5),(-.5,1.5),(.5,-1.5),(-.5,-1.5)]
plots=[]
for c,area in ((C1,'home'),(C2,'east')):
    for u,v in CELLS:
        x,y=P(c,u,v); plots.append({'id':f'P{len(plots)+1}','area':area,'poly':[[x,y-50],[x+100,y],[x,y+50],[x-100,y]]})
def plaza(c,k=.85): return [[c[0],c[1]-135*k],[c[0]+270*k,c[1]],[c[0],c[1]+135*k],[c[0]-270*k,c[1]]]
plazas=[{'center':list(C1),'kind':'fountain','poly':plaza(C1)},{'center':list(C2),'kind':'well','poly':plaza(C2)}]
# 大通り2本：どちらも、街(C1)→東の入口の角→東の街(C2)→東の端へ。ひし形の環ができる
roads=[
 {'w':40,'pts':[[20,775],[935,1232.5],list(C2),[W,720]]},
 {'w':40,'pts':[[20,1225],[935,767.5],list(C2),[W,1280]]},
 {'w':34,'pts':[[300,716],[300,745],list(P(C1,-1,-1)),list(P(C1,-1,0))]},
]
lakes=[[[640,520],[700,480],[800,455],[941,440],[941,610],[860,600],[780,585],[700,560]],
       [[1560,520],[1640,470],[1780,450],[1960,470],[1960,640],[1840,650],[1700,620],[1590,590]]]
signs=[{'id':'N','x':60,'y':748,'label':'山道'},{'id':'W','x':62,'y':1195,'label':'西の川'},
       {'id':'gate','x':896,'y':734,'label':'東の地','area':'east'},
       {'id':'NE','x':1915,'y':690,'label':'湖へ'},{'id':'SE','x':1915,'y':1252,'label':'東の森'}]
areas=[{'id':'east','name':'東の地','x0':950,'locked':True}]
d=json.load(open('data/layout.json'))
d.update(world={'w':W,'h':H},plots=plots,roads=roads,plazas=plazas,lakes=lakes,signs=signs,areas=areas)
for k in ('plaza','fountain','exits'): d.pop(k,None)
json.dump(d,open('data/layout.json','w'),indent=1); print(len(plots),'plots')
