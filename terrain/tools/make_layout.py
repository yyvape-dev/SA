# 道と区画をコードの直線データで作る（基準画像の画素）。等角の軸 a=(2,1) b=(-2,1) にそろえる
import json
O=(470,800); A=(170,85); B=(-170,85)
def C(i,j): return (O[0]+i*A[0]+j*B[0], O[1]+i*A[1]+j*B[1])
cells=[(0,0),(1,0),(2,0),(0,1),(1,1),(2,1),(3,1)]
plots=[]
for n,(i,j) in enumerate(cells,1):
    x,y=C(i,j); plots.append({'id':f'P{n}','poly':[[x,y-50],[x+100,y],[x,y+50],[x-100,y]]})
m=(O[0]+.5*B[0], O[1]+.5*B[1]); c=(O[0]+1.5*A[0], O[1]+1.5*A[1])
roads=[
 {'w':40,'pts':[[m[0]+t*A[0],m[1]+t*A[1]] for t in(-.5,3.0)]},
 {'w':40,'pts':[[c[0]+s*B[0],c[1]+s*B[1]] for s in(-.7,1.9)]},
 {'w':40,'pts':[[300,716],[300,760],[m[0]-.5*A[0],m[1]-.5*A[1]]]},
]
d=json.load(open('data/layout.json')); d['plots']=plots; d['roads']=roads
json.dump(d,open('data/layout.json','w'),indent=1); print(plots[2],roads[0])
