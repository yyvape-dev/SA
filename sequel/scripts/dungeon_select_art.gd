extends RefCounted
## Expedition instrument: presentation only; all tap bounds share rects().
const MAP=preload("res://assets/ui/dungeon_select/map_bg.webp")
const NODES=[preload("res://assets/ui/dungeon_select/node_t1.webp"),preload("res://assets/ui/dungeon_select/node_t2.webp"),preload("res://assets/ui/dungeon_select/node_t3.webp"),preload("res://assets/ui/dungeon_select/node_t4.webp")]
const THEMES=preload("res://scripts/dungeon_themes.gd")
const HUD_ART=preload("res://scripts/t6_hud_art.gd")
const M=preload("res://scripts/dungeon_select_materials.gd")
const GOLD=Color("e7bd72")
const BLUE=Color("55b5ff")
const RED=Color("ef666b")
const INK=Color("080e18")
const BRASS=Color("8e7450")
# Informational only. Values remain pending user confirmation; never consulted by progression.
const RECOMMENDED=[0,0,0,0]

static func rects(sz:Vector2,stage:String,t:float,shake_i:int=-1,shake_t:float=0.0)->Dictionary:
 var u=sz.y/720.0
 var r={"ox":0.0,"close":Rect2(Vector2(sz.x-108*u,23*u),Vector2(84,84)*u)}
 for i in 4:
  r["node%d"%i]=Rect2(Vector2(sz.x*(0.18+i*0.205)-92*u,sz.y*(0.69-i*0.16)-95*u),Vector2(184,184)*u) if stage=="theme" else Rect2()
  r["badge%d"%i]=Rect2(Vector2(sz.x*(0.18+i*0.205)+20*u,sz.y*(0.69-i*0.16)+36*u),Vector2(206,126)*u) if stage=="theme" else Rect2()
 var slide=(1.0-smoothstep(0.0,0.18,t))*10*u
 r.panel=Rect2(Vector2(sz.x*0.40+slide,sz.y*0.17),Vector2(sz.x*0.54,sz.y*0.58))
 r.hero=Rect2(Vector2(sz.x*0.055,sz.y*0.10),Vector2(sz.x*0.305,sz.y*0.79))
 for i in 3:r["diff%d"%i]=Rect2(Vector2(sz.x*0.405+slide,sz.y*(0.18+i*0.193)),Vector2(sz.x*0.52,sz.y*0.18))
 r.go=Rect2(Vector2(sz.x*0.65,sz.y*0.775),Vector2(sz.x*0.29,sz.y*0.15))
 if stage=="party":
  r.ppanel=Rect2(Vector2(sz.x*0.30,sz.y*0.13),Vector2(sz.x*0.64,sz.y*0.77))
  r.hero=Rect2(Vector2(sz.x*0.045,sz.y*0.105),Vector2(sz.x*0.245,sz.y*0.79))
  r.rana=Rect2(Vector2(sz.x*0.315,sz.y*0.16),Vector2(sz.x*0.13,sz.y*0.47))
  r.ally0=Rect2(Vector2(sz.x*0.46,sz.y*0.16),r.rana.size)
  r.ally1=Rect2(Vector2(sz.x*0.605,sz.y*0.16),r.rana.size)
  for i in 2:r["ally%d"%(i+2)]=Rect2(Vector2(sz.x*(0.755+i*0.107),sz.y*0.22),Vector2(sz.x*0.087,sz.y*0.38))
  r.go=Rect2(Vector2(sz.x*0.59,sz.y*0.70),Vector2(sz.x*0.35,sz.y*0.235))
  r.count=Rect2(Vector2(sz.x*0.335,sz.y*0.72),Vector2(sz.x*0.19,sz.y*0.18))
 if shake_t>0.0:
  var key="node%d"%(shake_i-10) if shake_i>=10 and shake_i<14 else "ally%d"%(shake_i-20) if shake_i>=20 and shake_i<24 else "diff%d"%shake_i
  if r.has(key):r[key].position.x+=sin(shake_t*60)*7*u
  if shake_i>=10 and shake_i<14:r["badge%d"%(shake_i-10)].position.x+=sin(shake_t*60)*7*u
 return r

static func fitted(tex:Texture2D,rc:Rect2)->Rect2:
 var extent=tex.get_size()*minf(rc.size.x/tex.get_width(),rc.size.y/tex.get_height())
 return Rect2(rc.get_center()-extent*0.5,extent)

static func fit(v,tex:Texture2D,rc:Rect2,tint=Color.WHITE)->void:
 v.draw_texture_rect(tex,fitted(tex,rc),false,tint)

static func cover(v,tex:Texture2D,rc:Rect2,tint=Color.WHITE)->void:
 var scale_=maxf(rc.size.x/tex.get_width(),rc.size.y/tex.get_height())
 var extent=rc.size/scale_
 v.draw_texture_rect_region(tex,rc,Rect2((tex.get_size()-extent)*0.5,extent),tint)

static func paper(v,rc:Rect2,tint=Color.WHITE)->void:
 fit(v,M.PAPER,rc,tint)

static func background(v,sz:Vector2,tint=Color.WHITE)->void:
 cover(v,MAP,Rect2(Vector2.ZERO,sz),tint)

static func backing(v,sz:Vector2,interior:bool=true)->void:
 var tex=M.BACKING
 if interior:cover(v,tex,Rect2(Vector2.ZERO,sz))
 # Keep hardware corners and source pixels proportional when aspect changes.
 var st=StyleBoxTexture.new();st.texture=tex;st.draw_center=false
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:st.set_texture_margin(side,55.0)
 v.draw_style_box(st,Rect2(Vector2.ZERO,sz))

static func number(v,rc:Rect2,text:String,col:Color,size_:float)->void:
 var font=HUD_ART.FONT
 var fs=maxi(int(22*v.size.y/720.0),int(size_))
 var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
 v.draw_string(font,Vector2(rc.get_center().x-width*0.5,rc.get_center().y+fs*0.32),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,col)

static func halo(v,c:Vector2,radius:float,col:Color,strength:float=1.0)->void:
 for i in range(3,0,-1):v.draw_arc(c,radius+i*1.2,0,TAU,48,Color(col,0.10*strength/i),i*2.0,true)

static func close(v,rc:Rect2,u:float,back:bool)->void:
 fit(v,M.CLOCK,rc,Color(0.58,0.53,0.45))
 var c=rc.get_center()
 if back:v.draw_polyline(PackedVector2Array([c+Vector2(7,-13)*u,c+Vector2(-7,0)*u,c+Vector2(7,13)*u]),GOLD,2.5*u,true)
 else:
  for side in [-1,1]:v.draw_line(c+Vector2(-10,-10*side)*u,c+Vector2(10,10*side)*u,GOLD,2*u,true)

static func path(v,a:Vector2,b:Vector2,opened:bool,u:float)->void:
 var points=PackedVector2Array()
 for i in 25:points.append(a.lerp(b,float(i)/24)+Vector2(0,sin(float(i)/24*PI)*12*u))
 if opened:
  v.draw_polyline(points,Color(GOLD,0.10),9*u,true)
  v.draw_polyline(points,Color(GOLD,0.90),2*u,true)
 else:
  for i in range(0,24,3):v.draw_line(points[i],points[i+1],Color(0.5,0.5,0.6,0.3),2*u,true)

static func chained(v,rc:Rect2)->void:
 fit(v,M.SHUT_MOUNT,rc)

static func map(v,h,sz:Vector2)->void:
 var u=sz.y/720.0
 var r=rects(sz,h.menu_stage,h.menu_t,h.shake_i,h.shake_hard)
 if h.menu_stage=="theme":
  background(v,sz,Color(0.82,0.86,0.93))
  backing(v,sz,false)
  var gate_rc=Rect2(Vector2(sz.x*0.025,sz.y*0.76),Vector2(122,122)*u)
  var gate_center=gate_rc.get_center()
  v.draw_circle(gate_center,gate_rc.size.x*0.28,Color("371763"))
  fit(v,M.LENS,gate_rc)
  var last=gate_rc.get_center()
  for i in 4:
   var rc:Rect2=r["node%d"%i]
   var open_:bool=h.main.progress.theme_open(i)
   path(v,last,rc.get_center()+Vector2(0,42*u),open_,u);last=rc.get_center()+Vector2(0,42*u)
   if h.menu_theme==i:halo(v,last,47*u,GOLD,3)
   fit(v,NODES[i],rc,Color.WHITE if open_ else Color(0.26,0.26,0.30))
   var badge:Rect2=fitted(M.PAPER,r["badge%d"%i])
   paper(v,badge,Color.WHITE if open_ else Color(0.4,0.4,0.45))
   fit(v,M.ENEMIES[i],Rect2(badge.position+Vector2(badge.size.x*0.10,badge.size.y*0.17),badge.size*Vector2(0.48,0.65)),Color.WHITE if open_ else Color(0.4,0.4,0.45))
   recommendation(v,Rect2(badge.position+badge.size*Vector2(0.56,0.20),badge.size*Vector2(0.30,0.56)),i,h.main.progress.lv,35*u)
   if h.menu_theme==i:halo(v,badge.end-Vector2(15,15)*u,10*u,GOLD,2)
   if not open_:chained(v,Rect2(rc.get_center()-Vector2(30,20)*u,Vector2(60,90)*u))
   # A worn wax-like rim records a cleared theme without abstract difficulty pips.
   if h.main.progress.cleared(THEMES.THEMES[i].id,"normal"):v.draw_arc(badge.end-Vector2(20,20)*u,9*u,0,TAU,24,GOLD,3*u,true)
  var current=Rect2(Vector2(sz.x*0.85,sz.y*0.045),Vector2(150,70)*u)
  paper(v,current)
  fit(v,HUD_ART.RANA,Rect2(current.position+Vector2(12,13)*u,Vector2(45,45)*u))
  number(v,Rect2(current.position+Vector2(66,6)*u,Vector2(62,59)*u),str(h.main.progress.lv),INK,32*u)
 elif h.menu_stage=="diff":
  backing(v,sz);panel(v,h,r,sz)
 else:
  backing(v,sz);party(v,h,r,sz)
 close(v,r.close,u,h.menu_stage!="theme")
 if h.menu_feedback_t>0:halo(v,h.menu_feedback_pos,18*u,GOLD,h.menu_feedback_t*9)

static func recommendation(v,rc:Rect2,theme:int,current_lv:int,fs:float)->void:
 var level_:int=RECOMMENDED[theme]
 if level_>0:number(v,rc,str(level_),Color("9b4024") if current_lv<level_ else INK,fs)

static func mission(v,h,rc:Rect2,compact:bool=false)->void:
 fit(v,M.PORTRAIT_PAPER,rc)
 var actual=fitted(M.PORTRAIT_PAPER,rc)
 var inset=actual.grow(-actual.size.x*0.10)
 if compact:
  fit(v,NODES[h.menu_theme],Rect2(inset.position,inset.size*Vector2(1,0.28)))
  fit(v,M.ENEMIES[h.menu_theme],Rect2(inset.position+Vector2(0,inset.size.y*0.28),inset.size*Vector2(1,0.43)))
  risk(v,Rect2(inset.position+Vector2(0,inset.size.y*0.72),inset.size*Vector2(1,0.18)),h.menu_sel,true,true)
 else:
  fit(v,M.ENEMIES[h.menu_theme],Rect2(inset.position+Vector2(0,inset.size.y*0.03),inset.size*Vector2(1,0.77)))
  fit(v,NODES[h.menu_theme],Rect2(inset.position+Vector2(0,inset.size.y*0.74),inset.size*Vector2(0.40,0.22)))
 recommendation(v,Rect2(inset.position+inset.size*Vector2(0.44,0.87),inset.size*Vector2(0.50,0.12)),h.menu_theme,h.main.progress.lv,rc.size.y*0.07)

static func risk(v,rc:Rect2,i:int,on:bool,opened:bool)->void:
 var col=BLUE if i==0 else RED
 # Illustrated field reports replace abstract diamonds. Opening and border are painted assets.
 var art_rc=fitted(M.RISK_FRAME,rc)
 var inside=Rect2(art_rc.position+art_rc.size*Vector2(0.12,0.24),art_rc.size*Vector2(0.73,0.48))
 cover(v,M.RISKS[i],inside,Color.WHITE if opened else Color(0.25,0.25,0.28))
 fit(v,M.RISK_FRAME,rc,Color.WHITE if opened else Color(0.42,0.42,0.47))
 if on and opened:
  v.draw_line(inside.position,Vector2(inside.end.x,inside.position.y),col,2.0,true)
  halo(v,Vector2(inside.position.x,inside.get_center().y),inside.size.y*0.37,col,2)
 if i==2 and opened:v.draw_line(Vector2(inside.position.x,inside.end.y),inside.end,GOLD,2,true)
 if not opened:chained(v,Rect2(inside.get_center()-Vector2(inside.size.y*0.24,inside.size.y*0.36),Vector2(inside.size.y*0.48,inside.size.y*0.72)))

static func medallion(v,tex:Texture2D,rc:Rect2,col:Color=BLUE)->void:
 v.draw_circle(rc.get_center(),rc.size.x*0.48,INK)
 fit(v,tex,rc.grow(-2))
 v.draw_arc(rc.get_center(),rc.size.x*0.48,0,TAU,36,col,1.4,true)

static func panel(v,h,r:Dictionary,sz:Vector2)->void:
 var u=sz.y/720.0
 mission(v,h,r.hero)
 for i in 3:
  var rc:Rect2=r["diff%d"%i]
  var opened:bool=h.main.progress.diff_open(THEMES.THEMES[h.menu_theme].id,THEMES.DIFF_ORDER[i])
  # A single report sleeve encloses the scene, portrait capacity and actual numeric record.
  var sleeve=StyleBoxTexture.new();sleeve.texture=M.REPORT
  sleeve.texture_margin_left=85;sleeve.texture_margin_right=90;sleeve.texture_margin_top=32;sleeve.texture_margin_bottom=32
  sleeve.modulate_color=Color.WHITE if opened else Color(0.45,0.45,0.48)
  var paper_scale=rc.size.y/M.REPORT.get_height()
  v.draw_set_transform(rc.position,0,Vector2(paper_scale,paper_scale))
  v.draw_style_box(sleeve,Rect2(Vector2.ZERO,Vector2(rc.size.x/paper_scale,M.REPORT.get_height())))
  v.draw_set_transform(Vector2.ZERO)
  var scene=Rect2(rc.position+rc.size*Vector2(0.06,0.18),rc.size*Vector2(0.51,0.64))
  cover(v,M.RISKS[i],scene,Color.WHITE if opened else Color(0.25,0.25,0.30))
  var col=BLUE if i==0 else RED
  if h.menu_sel==i and opened:
   v.draw_rect(scene,Color(col,0.85),false,2*u)
   halo(v,Vector2(scene.position.x,scene.get_center().y),scene.size.y*0.40,col,2)
  if i==2:v.draw_line(scene.end,Vector2(scene.position.x,scene.end.y),GOLD,2*u,true)
  var count=2 if i==0 else 3
  for j in count:
   var face:Texture2D=[HUD_ART.RANA,HUD_ART.LILY,HUD_ART.RANKA][j]
   medallion(v,face,Rect2(rc.position+Vector2(rc.size.x*(0.60+j*0.075),rc.size.y*0.20),Vector2(25,25)*u),BRASS)
  number(v,Rect2(rc.position+rc.size*Vector2(0.65,0.50),rc.size*Vector2(0.12,0.42)),str(count),INK,30*u)
  var key=THEMES.key(THEMES.THEMES[h.menu_theme].id,THEMES.DIFF_ORDER[i])
  var best=float(h.main.progress.best.get(key,0))
  var text=("%d:%02d"%[int(best/60),int(best)%60]) if h.main.progress.best.has(key) else "-"
  var clock_rc=Rect2(rc.position+rc.size*Vector2(0.80,0.05),rc.size*Vector2(0.16,0.90))
  fit(v,M.CLOCK,clock_rc,Color(0.7,0.65,0.55))
  number(v,clock_rc,text,GOLD,19*u)
  if not opened:chained(v,Rect2(scene.get_center()-Vector2(20,28)*u,Vector2(40,56)*u))
 # Next is a portrait dispatch tab, distinct from the mechanical departure activation.
 fit(v,M.DISPATCH,r.go)
 var dispatch=fitted(M.DISPATCH,r.go)
 for j in 2:
  var tex:Texture2D=[HUD_ART.RANA,HUD_ART.LILY][j]
  medallion(v,tex,Rect2(dispatch.position+dispatch.size*Vector2(0.33+j*0.19,0.18),Vector2(dispatch.size.y*0.64,dispatch.size.y*0.64)),GOLD)

static func face_card(v,rc:Rect2,tex,col:Color,on:bool,locked_:bool,u:float,fixed_:bool=false)->void:
 if locked_:
  chained(v,rc);return
 var frame= M.GOLD_MOUNT if fixed_ else M.BLUE_MOUNT
 var drawn=fitted(frame,rc)
 var inner=Rect2(drawn.position+drawn.size*Vector2(0.17,0.19),drawn.size*Vector2(0.65,0.60))
 v.draw_style_box(_style(Color("0a1725"),Color("213344"),inner.size.x*0.2),inner)
 if tex!=null:fit(v,tex,inner,Color.WHITE if on else Color(0.55,0.57,0.62))
 fit(v,frame,rc,Color.WHITE if on else Color(0.40,0.44,0.49))
 if on:halo(v,drawn.get_center(),drawn.size.x*0.41,col,1)

static func party(v,h,r:Dictionary,sz:Vector2)->void:
 var u=sz.y/720.0
 mission(v,h,r.hero,true)
 face_card(v,r.rana,M.BUSTS[0],GOLD,true,false,u,true)
 for i in 4:
  var id:String=h.ALLY_IDS[i]
  var rc:Rect2=r["ally%d"%i]
  var available:bool=id!="" and h.main.ally_ready(id)
  face_card(v,rc,M.BUSTS[i+1] if i<2 else null,BLUE,id in h.pick,not available,u)
  # Availability of a real ally loading is distinct from future locked mounts.
  if i<2 and not available:
   var at=rc.get_center()
   v.draw_arc(at,14*u,h.menu_t*2,h.menu_t*2+4.0,24,BLUE,2*u,true)
 var count_rc:Rect2=r.count
 if h.shake_i==30 and h.shake_hard>0:count_rc.position.x+=sin(h.shake_hard*60)*6*u
 fit(v,M.CLOCK,count_rc,Color(0.72,0.65,0.51))
 number(v,count_rc,"%d/%d"%[1+h.pick.size(),h.party_cap()],GOLD,32*u)
 go_button(v,r.go,u,h.menu_t)

static func go_button(v,rc:Rect2,u:float,t:float)->void:
 var dst=fitted(M.ACTIVATION,rc)
 fit(v,M.ACTIVATION,rc)
 halo(v,dst.position+dst.size*Vector2(0.43,0.49),dst.size.y*0.19,GOLD,1.2+sin(t*3)*0.35)

static func _style(bg:Color,border:Color,radius:float)->StyleBoxFlat:
 var st=StyleBoxFlat.new();st.bg_color=bg;st.border_color=border;st.set_border_width_all(1);st.set_corner_radius_all(int(radius));return st

static func loading(v,sz:Vector2,theme:int,diff:int,chosen:Array,t:float,progress:float)->void:
 var u=sz.y/720.0
 backing(v,sz)
 if theme<0:
  # Boot has no selected expedition; don't invent a dungeon context.
  var lens=Rect2(sz*Vector2(0.40,0.16),Vector2(280,280)*u)
  fit(v,M.LENS,lens)
 else:
  fit(v,M.ENEMIES[theme],Rect2(sz*Vector2(0.055,0.14),Vector2(sz.x*0.29,sz.y*0.65)))
  var lens=Rect2(sz*Vector2(0.39,0.07),Vector2(sz.x*0.30,sz.y*0.59))
  var lens_rect=fitted(M.LENS,lens)
  fit(v,NODES[theme],lens_rect.grow(-lens_rect.size.x*0.18))
  fit(v,M.LENS,lens)
  var c=lens_rect.get_center()
  v.draw_arc(c,lens_rect.size.x*0.31,t*0.8,t*0.8+3.0,48,Color(GOLD,0.55),1.5*u,true)
  risk(v,Rect2(sz*Vector2(0.74,0.18),Vector2(sz.x*0.20,sz.y*0.25)),diff,true,true)
  var recommended: int=RECOMMENDED[theme]
  if recommended>0:
   var rec=Rect2(sz*Vector2(0.78,0.47),Vector2(sz.x*0.12,sz.y*0.13))
   paper(v,rec);number(v,rec,str(recommended),INK,34*u)
  var faces=[HUD_ART.RANA]
  for id in chosen:
   if id=="lily":faces.append(HUD_ART.LILY)
   elif id=="ranka":faces.append(HUD_ART.RANKA)
  for i in faces.size():
   var rc=Rect2(Vector2(sz.x*(0.48+(i-(faces.size()-1)*0.5)*0.075),sz.y*0.63),Vector2(65,65)*u)
   medallion(v,faces[i],rc,GOLD if i==0 else BLUE)
 var tube=Rect2(sz*Vector2(0.14,0.80),Vector2(sz.x*0.72,sz.y*0.12))
 var glass=StyleBoxTexture.new();glass.texture=M.TUBE
 glass.texture_margin_left=90;glass.texture_margin_right=90;glass.texture_margin_top=12;glass.texture_margin_bottom=12
 v.draw_style_box(glass,tube)
 var inner=Rect2(tube.position+tube.size*Vector2(0.12,0.28),tube.size*Vector2(0.76,0.39))
 var start=0.0 if progress>=0 else fmod(t*0.20,0.75)
 var width=clampf(progress,0,1) if progress>=0 else 0.25
 var energy=Rect2(inner.position+Vector2(inner.size.x*start,0),Vector2(inner.size.x*width,inner.size.y))
 if energy.size.x>1:
  v.draw_style_box(_style(Color(1,0.59,0.08,0.42),Color(1,0.75,0.35,0.15),inner.size.y*0.45),energy)
  var filament=PackedVector2Array()
  for i in 25:filament.append(Vector2(energy.position.x+energy.size.x*i/24.0,inner.get_center().y+sin(t*12+i*1.5)*inner.size.y*0.21))
  v.draw_polyline(filament,Color(1,0.55,0.05,0.20),10*u,true)
  v.draw_polyline(filament,Color(1,0.80,0.28,0.65),3*u,true)
  v.draw_polyline(filament,Color(1,0.97,0.77,0.95),u,true)
