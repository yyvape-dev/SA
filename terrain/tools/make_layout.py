# 街の配置をコードの直線データで作る（基準画像の画素）。辺の向きは等角 (2,1) と (-2,1)
# 中心の交差点 X を基準に、(u,v) の格子で並べる：画面 x=X0+170(u-v), y=Y0+85(u+v)
import json
X0,Y0=470,1000
def P(u,v): return (X0+170*(u-v), Y0+85*(u+v))
cells=[(1.5,.5),(1.5,-.5),(-1.5,.5),(-1.5,-.5),(.5,1.5),(-.5,1.5),(.5,-1.5),(-.5,-1.5)]
plots=[]
for n,(u,v) in enumerate(cells,1):
    x,y=P(u,v); plots.append({'id':f'P{n}','poly':[[x,y-50],[x+100,y],[x,y+50],[x-100,y]]})
k=.85  # 広場：中央の2×2の街区を少し縮めたひし形
plaza=[[X0,Y0-135*k],[X0+270*k,Y0],[X0,Y0+135*k],[X0-270*k,Y0]]
exits=[{'id':'N','x':20,'y':775,'label':'山道'},{'id':'E','x':941,'y':765,'label':'湖へ'},{'id':'S','x':941,'y':1235,'label':'東の森'},{'id':'W','x':20,'y':1225,'label':'川の向こう'}]
roads=[
 {'w':40,'pts':[[20,775],[941,1235]]},          # 大通り（山道〜東の森）
 {'w':40,'pts':[[941,765],[20,1225]]},          # 交差する通り（湖〜川）
 {'w':34,'pts':[[300,716],[300,745],list(P(-1,-1)),list(P(-1,0))]},  # 城から降りる道
]
d=json.load(open('data/layout.json')); d['plots']=plots; d['roads']=roads; d['plaza']=plaza; d['exits']=exits; d['fountain']=[X0,Y0]
json.dump(d,open('data/layout.json','w'),indent=1); print(len(plots),plaza)
