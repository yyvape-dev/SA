extends RefCounted
## Presentation only. Rectangles are the single source for drawing and hit testing.
const MAP = preload("res://assets/ui/dungeon_select/map_bg.webp")
const NODES = [preload("res://assets/ui/dungeon_select/node_t1.webp"), preload("res://assets/ui/dungeon_select/node_t2.webp"), preload("res://assets/ui/dungeon_select/node_t3.webp"), preload("res://assets/ui/dungeon_select/node_t4.webp")]
const THEMES = preload("res://scripts/dungeon_themes.gd")
const HUD_ART = preload("res://scripts/t6_hud_art.gd")
const GOLD = Color("e7bd72")
const BLUE = Color("55b5ff")
const RED = Color("ef666b")
const INK = Color("080e18")
const BRASS = Color("8e7450")
const POS = [Vector2(240, 510), Vector2(430, 395), Vector2(620, 280), Vector2(805, 165)]

static func rects(sz: Vector2, stage: String, t: float, shake_i: int = -1, shake_t: float = 0.0) -> Dictionary:
 var u = sz.y / 720.0
 var ox = (sz.x - 1280.0 * u) * 0.5
 var r = {"ox":ox, "close":Rect2(Vector2(sz.x-100*u,12*u),Vector2(88,88)*u)}
 for i in 4:r["node%d"%i]=Rect2(Vector2(ox,0)+(POS[i]-Vector2(96,96))*u,Vector2(192,192)*u)
 var shift = (1.0 - smoothstep(0.0,0.18,t))*16.0
 r.panel=Rect2(Vector2(ox+(930+shift)*u,108*u),Vector2(330,584)*u)
 for i in 3:r["diff%d"%i]=Rect2(r.panel.position+Vector2(18,114+i*118)*u,Vector2(294,104)*u)
 r.go=Rect2(r.panel.position+Vector2(18,482)*u,Vector2(294,88)*u)
 if stage=="party":
  var dy=(1.0-smoothstep(0.0,0.18,t))*12.0
  r.ppanel=Rect2(Vector2(ox+60*u,(76+dy)*u),Vector2(1160,600)*u)
  r.rana=Rect2(r.ppanel.position+Vector2(34,156)*u,Vector2(196,282)*u)
  for i in 4:r["ally%d"%i]=Rect2(r.ppanel.position+Vector2(258+i*220,156)*u,Vector2(196,282)*u)
  r.go=Rect2(r.ppanel.position+Vector2(804,480)*u,Vector2(320,90)*u)
  r.close=Rect2(r.ppanel.position+Vector2(1060,10)*u,Vector2(88,88)*u)
 if shake_t > 0.0:
  var key = "node%d" % (shake_i-10) if shake_i >= 10 and shake_i < 14 else "ally%d" % (shake_i-20) if shake_i >= 20 and shake_i < 24 else "diff%d" % shake_i
  if r.has(key):r[key].position.x += sin(shake_t*60)*7*u
 return r

static func fit(v, tex: Texture2D, rc: Rect2, tint=Color.WHITE) -> void:
 var s=tex.get_size()
 var k=minf(rc.size.x/s.x,rc.size.y/s.y)
 var extent=s*k
 v.draw_texture_rect(tex,Rect2(rc.get_center()-extent*0.5,extent),false,tint)

static func background(v,sz: Vector2,tint=Color.WHITE) -> void:
 # Keep the entire composition and aspect. Fill any extra margins with ink.
 v.draw_rect(Rect2(Vector2.ZERO,sz),INK)
 var scale_=maxf(sz.x/MAP.get_width(),sz.y/MAP.get_height())
 var extent=MAP.get_size()*scale_
 v.draw_texture_rect(MAP,Rect2((sz-extent)*0.5,extent),false,tint)

static func plate(v,rc: Rect2,col: Color,u: float,on=false) -> void:
 var cut=10*u
 var p=rc.position
 var e=rc.end
 var pts=PackedVector2Array([p+Vector2(cut,0),Vector2(e.x-cut,p.y),Vector2(e.x,p.y+cut),e-Vector2(0,cut),e-Vector2(cut,0),Vector2(p.x+cut,e.y),Vector2(p.x,e.y-cut),p+Vector2(0,cut)])
 v.draw_colored_polygon(pts,Color(0.027,0.042,0.061,0.97))
 pts.append(pts[0])
 v.draw_polyline(pts,BRASS if not on else col,2*u,true)
 v.draw_line(p+Vector2(12,5)*u,Vector2(e.x-12*u,p.y+5*u),Color(col,0.45 if on else 0.13),2*u,true)
 v.draw_line(p+Vector2(12,9)*u,Vector2(e.x-12*u,p.y+9*u),Color(col,0.1),3*u,true)
 for x in [p.x+10*u,e.x-10*u]:
  for y in [p.y+15*u,e.y-15*u]:
   v.draw_circle(Vector2(x,y),2.3*u,Color("171921"))
   v.draw_arc(Vector2(x,y),2.3*u,PI,TAU,8,Color(BRASS,0.8),u,true)
 if on:
  v.draw_line(p+Vector2(4,20)*u,Vector2(p.x+4*u,e.y-20*u),Color(col,0.8),3*u,true)

static func diamond(v,c: Vector2,s: float,col: Color,filled=true) -> void:
 var pts=PackedVector2Array([c+Vector2(0,-s),c+Vector2(s*0.68,0),c+Vector2(0,s),c+Vector2(-s*0.68,0)])
 if filled:
  v.draw_colored_polygon(pts,col.darkened(0.28))
  v.draw_colored_polygon(PackedVector2Array([pts[0],pts[1],c,pts[3]]),col)
 pts.append(pts[0]);v.draw_polyline(pts,Color(col,0.9),maxf(1,s*0.08),true)

static func close(v,rc: Rect2,u: float,back: bool) -> void:
 var c=rc.get_center()
 v.draw_circle(c,28*u,Color(INK,0.9))
 v.draw_arc(c,28*u,0,TAU,40,BRASS,1.5*u,true)
 if back:
  v.draw_polyline(PackedVector2Array([c+Vector2(6,-13)*u,c+Vector2(-8,0)*u,c+Vector2(6,13)*u]),GOLD,3*u,true)
 else:
  for direction in [-1,1]:v.draw_line(c+Vector2(-10,-10*direction)*u,c+Vector2(10,10*direction)*u,GOLD,2.5*u,true)

static func gate(v,c: Vector2,s: float) -> void:
 v.draw_circle(c,s*0.65,Color(0.025,0.035,0.055,0.9))
 for i in 3:
  v.draw_arc(c,s*(0.68-i*0.08),PI,TAU,24,BRASS.darkened(i*0.16),s*0.08,true)
 for side in [-1,1]:
  var p=c+Vector2(side*s*0.58,0)
  v.draw_line(p,p+Vector2(0,s*0.6),Color("26282e"),s*0.2,true)
  v.draw_line(p+Vector2(side*s*0.05,0),p+Vector2(side*s*0.05,s*0.6),BRASS,s*0.035,true)
 v.draw_line(c+Vector2(-s*0.72,s*0.6),c+Vector2(s*0.72,s*0.6),GOLD,s*0.07,true)
 diamond(v,c+Vector2(0,-s*0.62),s*0.16,GOLD)
 v.draw_polyline(PackedVector2Array([c+Vector2(-s*0.15,-s*0.2),c+Vector2(s*0.15,0),c+Vector2(-s*0.15,s*0.2)]),GOLD,s*0.065,true)

static func lock(v,c: Vector2,s: float) -> void:
 v.draw_circle(c,s*1.17,Color(INK,0.95))
 v.draw_arc(c+Vector2(0,-s*0.28),s*0.43,PI,TAU,18,Color("9b9fa3"),s*0.15,true)
 var box=Rect2(c+Vector2(-s*0.62,-s*0.22),Vector2(s*1.24,s*0.92))
 v.draw_style_box(_style(Color("606873"),Color("abb0b3"),s*0.12),box)
 v.draw_circle(c+Vector2(0,s*0.14),s*0.12,INK)
 v.draw_line(c+Vector2(0,s*0.14),c+Vector2(0,s*0.4),INK,s*0.1,true)

static func _style(bg: Color,border: Color,radius: float) -> StyleBoxFlat:
 var st=StyleBoxFlat.new();st.bg_color=bg;st.border_color=border;st.set_border_width_all(1);st.set_corner_radius_all(int(radius));return st

static func path(v,a: Vector2,b: Vector2,opened: bool,u: float) -> void:
 var steps=24
 for j in steps:
  if not opened and j%3!=0:continue
  var x=float(j)/steps
  var y=float(j+1)/steps
  var p=a.lerp(b,x)+Vector2(0,sin(x*PI)*18*u)
  var q=a.lerp(b,y)+Vector2(0,sin(y*PI)*18*u)
  v.draw_line(p,q,Color(0.015,0.02,0.025,0.85),7*u,true)
  v.draw_line(p,q,Color(GOLD,0.8) if opened else Color(0.54,0.57,0.63,0.32),2.3*u,true)

static func map(v,h,sz: Vector2) -> void:
 var u=sz.y/720.0
 var r=rects(sz,h.menu_stage,h.menu_t,h.shake_i,h.shake_hard)
 var pr=h.main.progress
 var reveal=smoothstep(0.0,0.22,h.menu_t) if h.menu_stage=="theme" else 1.0
 background(v,sz,Color(0.76,0.82,0.91,1))
 v.draw_rect(Rect2(Vector2.ZERO,sz),Color(0.015,0.025,0.04,0.12+(1-reveal)*0.65))
 # Thin atlas frame, corner hardware; no instructional bands.
 var edge=Rect2(Vector2(16,16)*u,sz-Vector2(32,32)*u)
 v.draw_rect(edge,Color(BRASS,0.3),false,u)
 for p in [edge.position,Vector2(edge.end.x,edge.position.y),edge.end,Vector2(edge.position.x,edge.end.y)]:diamond(v,p,4*u,BRASS)
 var gc=Vector2(r.ox+82*u,626*u)
 var last=gc
 for i in 4:
  var c: Vector2=r["node%d"%i].get_center()
  path(v,last,c,i==0 or pr.theme_open(i),u)
  last=c
 gate(v,gc,38*u)
 for i in 4:
  var rc: Rect2=r["node%d"%i]
  var c=rc.get_center()
  var col: Color=THEMES.THEMES[i].col
  var opened: bool=pr.theme_open(i)
  var selected: bool=h.menu_theme==i
  var base=c+Vector2(0,65*u)
  for radius in [67,72]:v.draw_arc(base,float(radius)*u,0,TAU,48,Color(col,0.32 if opened else 0.08),u,true)
  if selected:
   for ring in 3:v.draw_arc(base,(76+ring*3)*u,0,TAU,60,Color(GOLD,0.7/(ring+1)),2*u,true)
   diamond(v,c+Vector2(0,-104*u),10*u,GOLD)
  fit(v,NODES[i],rc,Color.WHITE if opened else Color(0.25,0.29,0.34,0.8))
  if not opened:
   v.draw_line(c+Vector2(-58,28)*u,c+Vector2(58,60)*u,Color("535969"),4*u,true)
   v.draw_line(c+Vector2(-58,60)*u,c+Vector2(58,28)*u,Color("535969"),4*u,true)
   lock(v,c+Vector2(0,40*u),23*u)
  for k in i+1:v.draw_circle(c+Vector2((k-i*0.5)*12,103)*u,3*u,Color(col,0.85 if opened else 0.25))
  for k in 3:
   if pr.cleared(THEMES.THEMES[i].id,THEMES.DIFF_ORDER[k]):diamond(v,c+Vector2((k-1)*24,122)*u,7*u,[BLUE,RED,GOLD][k])
 close(v,r.close,u,h.menu_stage!="theme")
 if h.menu_stage=="diff":panel(v,h,r,sz)
 elif h.menu_stage=="party":party(v,h,r,sz)
 if h.menu_feedback_t>0:
  v.draw_arc(h.menu_feedback_pos,(18+(0.14-h.menu_feedback_t)*95)*u,0,TAU,32,Color(GOLD,h.menu_feedback_t*5),2*u,true)

static func panel(v,h,r: Dictionary,sz: Vector2) -> void:
 var u=sz.y/720.0
 var pn: Rect2=r.panel
 var th: Dictionary=THEMES.THEMES[h.menu_theme]
 plate(v,pn,GOLD,u)
 fit(v,NODES[h.menu_theme],Rect2(pn.position+Vector2(17,4)*u,Vector2(100,100)*u))
 for k in h.menu_theme+1:diamond(v,pn.position+Vector2(145+k*25,52)*u,8*u,th.col)
 var pr=h.main.progress
 for i in 3:
  var rc: Rect2=r["diff%d"%i]
  var selected: bool=h.menu_sel==i
  var opened: bool=pr.diff_open(th.id,THEMES.DIFF_ORDER[i])
  var col: Color=BLUE if i==0 else RED
  plate(v,rc,col if opened else Color("5e6570"),u,selected and opened)
  if selected and opened:v.draw_rect(rc.grow(-6*u),Color(col,0.11))
  if i==2 and opened:v.draw_rect(rc.grow(-7*u),Color(GOLD,0.65),false,u)
  for k in i+1:diamond(v,rc.position+Vector2(30+k*31,36)*u,14*u,col if opened else Color("58616c"))
  for k in (2 if i==0 else 3):person(v,rc.position+Vector2(212+k*24,31)*u,8*u,Color("a8b3bf") if opened else Color("4d535b"))
  var key=THEMES.key(th.id,THEMES.DIFF_ORDER[i])
  v._clock(rc.position+Vector2(28,77)*u,9*u,GOLD if pr.best.has(key) else Color("505b69"))
  v._num(rc.position+Vector2(45,85)*u,v._time_str(float(pr.best[key])) if pr.best.has(key) else "—",23,GOLD if pr.best.has(key) else Color("657080"))
  if selected and opened:check(v,rc.position+Vector2(266,77)*u,10*u,col)
  if not opened:lock(v,rc.get_center()+Vector2(30*u,0),19*u)
 go_button(v,r.go,u,h.menu_t)

static func go_button(v,rc: Rect2,u: float,t: float) -> void:
 plate(v,rc,GOLD,u,true)
 var inner=rc.grow(-6*u)
 v.draw_style_box(_style(Color("9a6a2c"),GOLD,3*u),inner)
 v.draw_rect(Rect2(inner.position,Vector2(inner.size.x,inner.size.y*0.45)),Color(1,0.85,0.5,0.16))
 var c=rc.get_center()
 for side in [-1,1]:v.draw_line(c+Vector2(side*61,-18)*u,c+Vector2(side*61,18)*u,Color(GOLD,0.45),u,true)
 v.draw_colored_polygon(PackedVector2Array([c+Vector2(-12,-22)*u,c+Vector2(21,0)*u,c+Vector2(-12,22)*u]),Color("fff0c2"))
 v.draw_arc(c,32*u,-0.35,0.35,10,Color(GOLD,0.25+sin(t*3)*0.12),u,true)

static func person(v,c: Vector2,s: float,col: Color) -> void:
 v.draw_circle(c+Vector2(0,-s*0.65),s*0.4,col)
 v.draw_arc(c+Vector2(0,s*0.9),s*0.8,PI,TAU,18,col,s*0.45,true)

static func check(v,c: Vector2,s: float,col: Color) -> void:
 v.draw_polyline(PackedVector2Array([c+Vector2(-s*0.65,0),c+Vector2(-s*0.15,s*0.5),c+Vector2(s*0.8,-s*0.6)]),col,maxf(2,s*0.2),true)

static func party(v,h,r: Dictionary,sz: Vector2) -> void:
 var u=sz.y/720.0
 var pp: Rect2=r.ppanel
 v.draw_rect(Rect2(Vector2.ZERO,sz),Color(0.005,0.009,0.02,0.72))
 plate(v,pp,GOLD,u)
 fit(v,NODES[h.menu_theme],Rect2(pp.position+Vector2(26,14)*u,Vector2(110,110)*u))
 for k in h.menu_sel+1:diamond(v,pp.position+Vector2(170+k*30,65)*u,13*u,BLUE if h.menu_sel==0 else RED)
 if h.menu_sel==2:v.draw_arc(pp.position+Vector2(200,65)*u,57*u,0,TAU,48,Color(GOLD,0.6),u,true)
 var cap: int=h.party_cap()
 var used: int=1+h.pick.size()
 for k in cap:
  var c=pp.position+Vector2(570+(k-(cap-1)*0.5)*52,65)*u
  if h.shake_i==30 and h.shake_hard>0:c.x+=sin(h.shake_hard*60)*7*u
  v.draw_circle(c,21*u,Color(BLUE,0.14 if k<used else 0.04))
  person(v,c,13*u,GOLD if k==0 else BLUE if k<used else Color("3f4a58"))
 face_card(v,r.rana,HUD_ART.RANA,GOLD,true,false,u,true)
 var faces={"lily":HUD_ART.LILY,"ranka":HUD_ART.RANKA}
 for i in 4:
  var id: String=h.ALLY_IDS[i]
  var rc: Rect2=r["ally%d"%i]
  var available: bool=id!="" and h.main.ally_ready(id)
  face_card(v,rc,faces.get(id),BLUE if id in h.pick else Color("71808f"),id in h.pick,not available,u)
 go_button(v,r.go,u,h.menu_t)
 # A compact chosen-party preview replaces explanatory text.
 var x=pp.position.x+54*u
 for id in ["rana"]+h.pick:
  var tex: Texture2D=HUD_ART.RANA if id=="rana" else faces[id]
  fit(v,tex,Rect2(Vector2(x,pp.position.y+489*u),Vector2(70,70)*u))
  x+=78*u
 close(v,r.close,u,true)

static func face_card(v,rc: Rect2,tex,col: Color,on: bool,locked_: bool,u: float,fixed_=false) -> void:
 plate(v,rc,col,u,on)
 var c=rc.get_center()+Vector2(0,-18*u)
 for k in 2:v.draw_arc(c,(72+k*5)*u,0,TAU,56,Color(col,0.5 if on else 0.16),1.6*u,true)
 if tex!=null:fit(v,tex,Rect2(c-Vector2(67,67)*u,Vector2(134,134)*u),Color(1,1,1,0.28 if locked_ else 1))
 else:
  person(v,c+Vector2(0,6)*u,40*u,Color("242f40"))
  v.draw_arc(c,62*u,0,TAU,40,Color("384352"),u,true)
 if locked_:lock(v,c+Vector2(0,12)*u,20*u)
 var mark=Vector2(rc.get_center().x,rc.end.y-34*u)
 if fixed_:diamond(v,mark,12*u,GOLD)
 elif on:check(v,mark,14*u,BLUE)
 elif not locked_:v.draw_circle(mark,12*u,Color(col,0.13));v.draw_line(mark-Vector2(6,0)*u,mark+Vector2(6,0)*u,col,2*u);v.draw_line(mark-Vector2(0,6)*u,mark+Vector2(0,6)*u,col,2*u)
